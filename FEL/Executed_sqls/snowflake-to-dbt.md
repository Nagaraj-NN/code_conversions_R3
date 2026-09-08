---
name: snowflake-to-dbt
description: Convert working Snowflake SQL code into fully functional DBT models that run on Snowflake. Preserves logic apple-to-apple (identical results). Handles single or multiple .sql files as input. If a single .sql file contains multiple independent queries/statements, each becomes its OWN DBT model file — never clubbed together. Follows the reference pattern seen at C:/Users/s390221/Downloads/ODS_TRI_CST_DCMNTM_DTO_INPUT (INPUT vs OUTPUT pairs): header block, pre/post hooks, JOB_PARAM/JOB_CONTROL CTEs, incremental+merge with unique_key, {{ this }} LEFT JOIN + DECODE change-detect, explicit CASTs from $DESC_TABLE. Triggers on: "snowflake to dbt", "convert to dbt", "dbt model from sql", "migrate snowflake to dbt", "dbtify".
---

# Snowflake → DBT Conversion Skill (Reference-Pattern Aligned)

You are converting **working Snowflake SQL** into **production-ready DBT models** that run on Snowflake as the underlying warehouse. The output must produce **byte-identical results** to the source Snowflake query when materialized. The output should also match the reference pattern under `C:/Users/s390221/Downloads/ODS_TRI_CST_DCMNTM_DTO_INPUT/*_OUTPUT.sql` — read those files if you have any doubt about what a "correct" output looks like.

## Non-Negotiable Rules

1. **One statement → one model.** N independent queries in a `.sql` file produce N model files. Never merge.
2. **Preserve logic exactly.** Do not "improve," reorder columns, rename aliases, change join types, or alter filter conditions.
3. **DBT must actually run.** Every model must pass `dbt parse` and `dbt compile` without errors.
4. **No new dependencies.** No `dbt_utils`, `dbt_expectations`, etc. — only what the reference pattern uses.
5. **Ask before assuming.** If sources vs refs, unique_key, or types can't be determined, ASK.

## Input formats

### Format A — Metadata-annotated (preferred; matches reference pattern)

Input files carry `$` directives:

```
$TYPE: INSERT,UPDATE;
$AUTOSYS_JOB_NAME: <autosys job>;
$TARGET_TABLE: <db.schema.table>;
$TARGET_TABLE_COLUMNS: col1, col2, ...;
$SPLIT_CTE: <cte name where the split happens, e.g. FINAL_SOURCE>;
$UPDATE_COLUMNS:
  tgt.X = src.Y,
  ...;
$PRE_HOOK1: ...;
$PRIMARY_KEY: <pk_col>;
$SOURCE_CODE: <the actual Snowflake SQL body>;
$POST_HOOK1: ...;
$DESC_TABLE:
name<TAB>type<TAB>kind<TAB>null?<TAB>default
COL_A<TAB>NUMBER(38,18)<TAB>COLUMN<TAB>N
...
```

When these directives are present, they drive everything:
- `$PRIMARY_KEY` → `unique_key` in config
- `$AUTOSYS_JOB_NAME` → pre/post hook macro args
- `$DESC_TABLE` → explicit `CAST(...)` for every column in the final SELECT
- `$UPDATE_COLUMNS` → column rename map (src column → tgt column)
- `$SPLIT_CTE` → the CTE name that the final SELECT reads from (via LEFT JOIN `{{ this }}`)
- `$TARGET_TABLE_COLUMNS` → column order in the final SELECT

### Format B — Bare Snowflake SQL (no directives)

Pure `INSERT INTO ... SELECT` or `MERGE INTO ... USING (...) WHEN MATCHED ...` statements. Fall back to deriving what you can:
- MERGE ON clause → `unique_key`
- INSERT column list → target column order
- Explicit CAST layer and DECODE change-detect **require types** — if there's no `$DESC_TABLE` and no target DDL provided, SKIP those two layers rather than fabricate types.
- Autosys job name → **derive as `<TARGET_TABLE_UPPERCASE>_ASYS`** unless the user provides an explicit `$AUTOSYS_JOB_NAME` directive or overrides the convention. Example: target `DOVS_WORK_CREW_DIM` → autosys job `DOVS_WORK_CREW_DIM_ASYS`.

## Output template (the reference pattern)

Every DBT model file follows this shape:

```jinja
-- ============================================================
-- CONVERSION SUMMARY
-- ============================================================
-- SOURCE FILE       : <original filename>
-- TARGET TABLE      : <original FQN>
-- AUTOSYS_JOB_NAME  : <name or placeholder>
-- MATERIALIZATION   : <type|view|incremental>
-- ============================================================

{{ config(
    database='<TARGET_DB>',
    schema='<TARGET_SCHEMA>',
    materialized='incremental',
    unique_key='<pk>',              -- or a list for composite keys
    incremental_strategy='merge',
    full_refresh=false,             -- MERGE upsert models: default false
    pre_hook=[
        log_model_start(this, '<AUTOSYS_JOB_NAME>'),
        "TRUNCATE TABLE IF EXISTS {{this}}"  -- OPTIONAL: only for models that explicitly truncate before load
    ],
    post_hook=[
        log_model_end(this, '<AUTOSYS_JOB_NAME>')
    ]
) }}

WITH
JOB_PARAM AS (
    SELECT PARAM_ID, PARAM_NAME, PARAM_VALUE
    FROM {{ source('<metadata_src>','JOB_PARAMETERS') }}
    WHERE JOB_NAME='<TARGET>' AND AUTOSYS_JOB_NAME='<AUTOSYS>' AND ACTIVE_IND='Y'
),
JOB_CONTROL AS (
    SELECT JOB_ID, START_DATE, END_DATE
    FROM {{ source('<metadata_src>','JOB_CONTROL') }}
    WHERE JOB_NAME='<TARGET>' AND AUTOSYS_JOB_NAME='<AUTOSYS>'
),

<all original CTEs from $SOURCE_CODE preserved verbatim>
-- rules:
--   * FQN in FROM → replace with {{ ref('...') }} or {{ source('...','...') }} or {{ this }}
--   * KEEP the original FQN as an inline comment: `{{ ref('X') }}  --DB.SCHEMA.X`
--   * self-reference to target → {{ this }}

FINAL_SOURCE AS ( <optional; when the source SQL has an explicit rtr_insupd/final CTE> )

SELECT
    -- CAST layer from $DESC_TABLE (numbers → CAST(TRIM(x) AS NUMBER(p,s)); varchars → CAST(LEFT(TRIM(x), N) AS VARCHAR(N)))
    CAST(TRIM(SRC.<src_col>) AS <TGT_TYPE>) AS <TGT_COL>,
    ...
    -- audit columns get COALESCE so the original insert timestamp is preserved on unchanged rows:
    CAST(TRIM(COALESCE(TGT.EDW_LAST_UPDT_DTM, SRC.EDW_LAST_UPDT_DTM)) AS TIMESTAMP_NTZ(6)) AS EDW_LAST_UPDT_DTM
FROM FINAL_SOURCE SRC
LEFT JOIN {{ this }} TGT
    ON SRC.<pk> = TGT.<pk>
WHERE (
    -- change-data-detect: only rows where ANY non-key column differs
    DECODE(CAST(TRIM(tgt.<col>) AS <T>), CAST(TRIM(src.<col>) AS <T>), 1, 0) = 0 OR
    DECODE(...) = 0 OR
    ...
)
```

## Layer-by-layer rules

### Header comment block
Always include. Five lines: SOURCE FILE, TARGET TABLE, AUTOSYS_JOB_NAME, MATERIALIZATION. Bracketed by `=` bars.

### `config()` block

Every model **must explicitly declare `database` and `schema`** in its config so writes always land in the correct target regardless of what the DBT profile says:

```jinja
{{ config(
    database='<TARGET_DB>',
    schema='<TARGET_SCHEMA>',
    materialized='...',
    ...
) }}
```

This requires two macros in `macros/` — `generate_schema_name.sql` and `generate_database_name.sql` — that make the `schema` and `database` config values absolute (DBT's default `generate_schema_name` concatenates `<profile_schema>_<custom_schema>`, which we don't want). If those macros aren't in the project, generate them.

| Model type | materialized | unique_key | incremental_strategy | full_refresh | hooks |
|---|---|---|---|---|---|
| `$TYPE: INSERT,UPDATE` (upsert) | `incremental` | from `$PRIMARY_KEY` | `merge` | `false` | yes |
| `MERGE INTO ...` (Format B upsert) | `incremental` | from MERGE ON clause | `merge` | `false` | yes |
| `INSERT INTO ... SELECT` (staging, no upsert) | `table` | — | — | — | yes |
| `CREATE OR REPLACE VIEW` | `view` | — | — | — | yes |

**Hooks are MANDATORY on every model.** No exceptions — staging, dim, fact, view, error tables, all of them:

```jinja
pre_hook=[
    log_model_start(this, '<AUTOSYS_JOB_NAME>'),
    "TRUNCATE TABLE IF EXISTS {{this}}"   -- OPTIONAL: see below
],
post_hook=[
    log_model_end(this, '<AUTOSYS_JOB_NAME>')
]
```

Rules for the hook lists:
- `log_model_start` is **always the first** entry in `pre_hook`.
- `log_model_end` is **always the last** entry in `post_hook`.
- Any other work the source SQL required (control-table UPDATEs, TRUNCATE, follow-up UPDATE statements) slots **between** them, in original execution order.
- `TRUNCATE TABLE IF EXISTS {{this}}` is **conditional**: include it only when the source SQL explicitly truncates the target before loading. Never add it to an `incremental` + `merge` model, and never add it to an append-only incremental — truncating would defeat the load pattern. If there is no TRUNCATE in the source, omit the line entirely.

Both log calls are project-level macros that must exist in `macros/`. If they don't, generate the full implementations from the Macros section below.

### Where hook SQL lives — single-use stays in the model

**Do not create a macro file for DML that only one model ever calls.** A `macros/` file
is for SQL that is genuinely shared. One-model DML belongs in that model's own file, so
the whole statement chain is readable in one place.

Decide with this table:

| Situation | Where the SQL goes |
|---|---|
| Called by **2+ models** | macro file in `macros/` |
| Same SQL, only a literal differs (JOB_ID, table) | **one parameterised** macro file |
| Called by **1 model**, single short statement | **inline string** in the hook list |
| Called by **1 model**, long or multi-line | **`{% set %}` block** at the top of that model file |
| `log_model_start` / `log_model_end` | always macro files (used by every model) |

**Form A — inline string.** For a one-liner. Hook strings are rendered as Jinja, so
`{{ this }}`, `{{ source() }}` and `{{ ref() }}` all work inside them. Single quotes in
SQL literals are fine inside a double-quoted string:

```jinja
{{ config(
    pre_hook=[
        log_model_start(this, 'M_X_ASYS'),
        "TRUNCATE TABLE IF EXISTS {{this}}",
        "UPDATE {{ source('CRPDB01_EPMADM','PS_Z_ETL_JOBS') }} SET STATUS='R' WHERE JOB_ID='CI_FACT' AND STATUS='C'"
    ],
    post_hook=[ log_model_end(this, 'M_X_ASYS') ]
) }}
```

**Form B — `{% set %}` block.** Use this as soon as the statement is more than one
line. It keeps the SQL in the same model file with no quote escaping and no loss of
formatting, and it is what makes the single-use rule practical for a 40-line MERGE.
Declare the blocks **above** `config()` and reference them by name:

```jinja
-- ============================================================
-- CONVERSION SUMMARY  ... (header as usual)
-- ============================================================

{#- statement 1 of 5: m_ps_z_etl_jobs_upd_parms - opens the CI_FACT window -#}
{%- set open_ci_fact_window -%}
UPDATE {{ source('CRPDB01_EPMADM', 'PS_Z_ETL_JOBS') }}
SET Z_RUN_PARM1 = Z_RUN_PARM2,
    Z_RUN_PARM2 = TO_VARCHAR(CURRENT_TIMESTAMP(),'YYYY-MM-DD-HH24.MI.SS'),
    STATUS='R'
WHERE JOB_ID='CI_FACT'
  AND STATUS='C'
{%- endset -%}

{#- statement 5 of 5: m_ps_z_etl_jobs_upd_status - closes the CI_FACT window -#}
{%- set close_ci_fact_window -%}
UPDATE {{ source('CRPDB01_EPMADM', 'PS_Z_ETL_JOBS') }}
SET STATUS='C'
WHERE JOB_ID='CI_FACT'
  AND STATUS='R'
{%- endset -%}

{{ config(
    database='...', schema='...',
    materialized='incremental',
    unique_key=[...],
    incremental_strategy='merge',
    full_refresh=false,
    pre_hook=[
        log_model_start(this, 'M_X_ASYS'),
        open_ci_fact_window
    ],
    post_hook=[
        close_ci_fact_window,
        log_model_end(this, 'M_X_ASYS')
    ]
) }}

WITH ... -- model body
```

Keep the same provenance comment you would have put in the macro's docstring — source
file, line range, mapping/session name, and *why* it is a hook rather than a model —
as a `{#- ... -#}` comment immediately above each `set` block.

A `{% set %}` block that grows past ~60 lines, or one whose SQL you find yourself
wanting to reuse, is the signal to promote it to a macro file after all.

### JOB_PARAM + JOB_CONTROL CTEs
Every model includes these two CTEs at the very top of the WITH block, even if the model doesn't reference them. Consistency > brevity.
- `JOB_NAME` filter value = target table name (unqualified, uppercase).
- `AUTOSYS_JOB_NAME` filter value = the model's autosys job name.
- Source name for the metadata tables: use whatever the project uses (e.g. `CRPDB01_METADATA` for TRIRA, `dovs_metadata` for DOVS). Ask if unclear.

### Body CTEs
Preserve every CTE from the source SQL verbatim. Rules:
- **Table references**: replace with `{{ ref() }}`, `{{ source() }}`, or `{{ this }}`. Keep the original FQN as an inline comment: `FROM {{ ref('STG_X') }}  --DB.SCHEMA.STG_X`
- **Snowflake native functions** (QUALIFY, LATERAL FLATTEN, IFF, TRY_CAST, ARRAY_AGG WITHIN GROUP, DATEADD, DATEDIFF, ROW_NUMBER, RANK, etc.): pass through unchanged.
- **`${VAR}` Snowflake variables**: replace with `{{ var('var_name') }}` if the project uses DBT vars, OR replace with a lookup from JOB_PARAM CTE if the project passes params through the JOB_PARAMETERS table.
- **CTE names, aliases, indentation**: keep as-is. Only change what must change.

### Final SELECT
Two cases:

**Upsert (incremental+merge):**
1. `SELECT` clause: one entry per target column, in the exact `$TARGET_TABLE_COLUMNS` order. Each column wrapped in `CAST(...)` using types from `$DESC_TABLE`:
   - `NUMBER(p,s)` → `CAST(TRIM(SRC.<src>) AS NUMBER(p,s)) AS <tgt>`
   - `VARCHAR(n)` → `CAST(LEFT(TRIM(SRC.<src>), n) AS VARCHAR(n)) AS <tgt>`
   - `TIMESTAMP_NTZ(k)` → `CAST(TRIM(SRC.<src>) AS TIMESTAMP_NTZ(k)) AS <tgt>`
   - Audit column (usually the last one, e.g. `EDW_LAST_UPDT_DTM`): `CAST(TRIM(COALESCE(TGT.<same>, SRC.<same>)) AS <T>) AS <same>` — preserves original ts when nothing changed
2. `FROM $SPLIT_CTE SRC LEFT JOIN {{ this }} TGT ON SRC.<pk>=TGT.<pk>`
3. `WHERE ( DECODE(...) = 0 OR DECODE(...) = 0 OR ... )` — one DECODE per non-key column, both sides wrapped in the SAME cast expression used in the SELECT. Only rows where at least one non-key column differs flow into the merge.

**Non-upsert (staging INSERT, view, etc.):**
Just the original SELECT with `ref()`/`source()` substitutions. No CAST layer, no DECODE, no LEFT JOIN to `{{ this }}`.

## Macros required in `macros/`

Only two macro files are unconditionally required — `log_model_start` and
`log_model_end` — plus `generate_schema_name` / `generate_database_name`. Everything
else earns a macro file only by being **shared or parameterised**; see
"Where hook SQL lives" above before creating any other file here.

If the project already has these macros, **use the existing ones — do not overwrite**. Otherwise generate them exactly as below.

### `macros/log_model_start.sql`

```jinja
{% macro log_model_start(model_name, autosys_job_name) %}

    {# stop the run if not provided #}
    {% if not autosys_job_name  or (autosys_job_name | trim) == '' %}
        {{exceptions.raise_compiler_error(
            "Missing required autosys_job_name for this model"
        )
        }}
    {% endif %}

    {# app_name for table name (from folder +vars fallback)#}
    {{ log("app_name= " ~ var('app_name_by_schema').get(model.config.schema) , info= True)}}
    {% set app_name= var('app_name_by_schema').get(model.config.schema | upper) %}

    {% if app_name is none %}
         {{exceptions.raise_compiler_error(
            "Missing required app_name for this model"
        )
        }}
    {% endif %}

    {% set exec_table = model.database ~ '.METADATA.' ~ app_name ~ '_JOB_EXECUTION'%}


    insert into {{exec_table}} (
        JOB_NAME,
        AUTOSYS_JOB_NAME,
        JOB_STATUS,
        START_TIMESTAMP,
        END_TIMESTAMP,
        ROW_CREATE_TIMESTAMP,
        ROW_UPDATE_TIMESTAMP,
        SOURCE_OBJECT,
        TARGET_OBJECT,
        RECORDS_PROCESSED,
        ERROR_MESSAGE
        )

    values (
        '{{model_name.name}}',
        '{{autosys_job_name}}',
        'STARTED',
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        NULL,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
        NULL,
        NULL,
        NULL,
        NULL);


{% endmacro %}
```

### `macros/log_model_end.sql`

```jinja
{% macro log_model_end(model_name, autosys_job_name) %}

    {% set app_name = var('app_name_by_schema').get(model.config.schema | upper) %}
    {% set exec_table = model.database ~ '.METADATA.' ~ app_name ~ '_JOB_EXECUTION' %}


    update {{ exec_table }}
    set
        JOB_STATUS = 'COMPLETED',
        END_TIMESTAMP = current_timestamp()::timestamp_ntz,
        ROW_UPDATE_TIMESTAMP = current_timestamp()::timestamp_ntz
    WHERE
        job_name = '{{ model_name.name }}'
        AND autosys_job_name = '{{ autosys_job_name }}'
        AND job_status = 'STARTED'
        AND END_TIMESTAMP IS NULL;

{% endmacro %}
```

### Two hard prerequisites

These macros will **raise a compiler error** unless both are in place.

**1. `vars.app_name_by_schema` in `dbt_project.yml`.** The macros look up `model.config.schema | upper` in this map to build the metadata table name. Every schema any model writes to must have an entry:

```yaml
vars:
  app_name_by_schema:
    <TARGET_SCHEMA_UPPERCASE>: '<APP_NAME>'
    # e.g.
    # EPMADM:  'BI80'
    # DOVSADM: 'DOVS'
```

Resolved table name: `{model.database}.METADATA.{app_name}_JOB_EXECUTION`.

Note this is also why **`schema` must be set explicitly in every model's `config()`** — the lookup key comes from `model.config.schema`, which is null if the model relies on the profile default.

Ask the user for the `app_name` if you can't infer it. Reasonable inference: the application/project prefix (folder name, workflow prefix, or target-table prefix). State the assumption in the report.

**2. The metadata table must exist before the first `dbt run`.** DBT will not create it. Emit this DDL in the conversion report:

```sql
CREATE TABLE IF NOT EXISTS <DATABASE>.METADATA.<APP_NAME>_JOB_EXECUTION (
    JOB_NAME             VARCHAR,
    AUTOSYS_JOB_NAME     VARCHAR,
    JOB_STATUS           VARCHAR,
    START_TIMESTAMP      TIMESTAMP_NTZ,
    END_TIMESTAMP        TIMESTAMP_NTZ,
    ROW_CREATE_TIMESTAMP TIMESTAMP_NTZ,
    ROW_UPDATE_TIMESTAMP TIMESTAMP_NTZ,
    SOURCE_OBJECT        VARCHAR,
    TARGET_OBJECT        VARCHAR,
    RECORDS_PROCESSED    NUMBER,
    ERROR_MESSAGE        VARCHAR
);
```

### Behavioural notes

- `log_model_end` matches on `job_status = 'STARTED' AND END_TIMESTAMP IS NULL`, so a model that fails mid-run leaves a STARTED row with a null `END_TIMESTAMP` — that is the intended failure signal. Don't "fix" it.
- `post_hook` does not run when the model errors, which is what makes the above work.
- `SOURCE_OBJECT`, `TARGET_OBJECT`, `RECORDS_PROCESSED` and `ERROR_MESSAGE` are inserted NULL by design. Leave them NULL unless the user asks for them to be populated.

## Sources.yml

Group source tables by source-name (a logical group), then database + schema:

```yaml
sources:
  - name: <logical_name>
    database: <DB>
    schema: <SCHEMA>
    tables:
      - name: <TBL>
```

**Always include a metadata source** (`dovs_metadata`, `crpdb01_metadata`, etc.) with tables `JOB_PARAMETERS`, `JOB_CONTROL`, and `JOB_RUN_LOG` — the JOB_PARAM/JOB_CONTROL CTEs and the log macros reference them.

## Workflow

1. **Read all input files.** Detect Format A vs Format B by presence of `$` directives.
2. **Split each file** into independent statements. One statement → one model.
3. **Extract or ask** for: refs vs sources, `$PRIMARY_KEY`, `$AUTOSYS_JOB_NAME`, `$DESC_TABLE`, `$SPLIT_CTE`, and the **`app_name` for every target schema** (needed by the log macros).
4. **Classify** every table reference as `ref()`, `source()`, or `{{ this }}`.
5. **Scaffold** the project:
   - `dbt_project.yml` — including `vars.app_name_by_schema`
   - `sources.yml`
   - `macros/log_model_start.sql`, `macros/log_model_end.sql`
   - `macros/generate_schema_name.sql`, `macros/generate_database_name.sql` (so explicit `schema=`/`database=` are absolute)
6. **Decide model vs hook** for every statement, then **count callers per hook statement**. Single-caller → inline string or `{% set %}` block in that model. Multi-caller or parameterised → macro file. Do this *before* writing files, so you don't create macro files you then have to fold back in.
7. **Emit one model per statement** using the template above. Every model gets `database`, `schema`, `pre_hook` and `post_hook`.
8. **VERIFY THE CONVERSION — MANDATORY, NOT OPTIONAL.** Run the two mechanical checks in the "Mandatory verification" section below and fix everything they surface. A conversion is not finished until both pass. Never report a conversion complete on the strength of having read the SQL carefully.
9. **Print report** with: files created, assumptions (including the inferred `app_name`), **the verification output**, the `<APP_NAME>_JOB_EXECUTION` DDL that must be run first, and attention items (external refs not in batch, missing DDLs, ambiguous unique_keys, stored proc calls).

## Mandatory verification

Reading the SQL carefully is not verification. Transcribing a 900-token `MD5(...)`
expression or a 126-column projection by eye **will** produce silent errors: they
compile fine and quietly return wrong data. Two scripted checks catch that class of
bug without needing a Snowflake connection. **Both are mandatory on every conversion.**

Write them into `<output>/verification/` and run them. Keep them — they are the
regression gate for any later edit.

### Check 1 — expression identity

For every long expression that was transcribed rather than derived — `MD5(...)`,
checksum concatenations, `ARRAY_CONSTRUCT(...)`, big `CASE` chains — extract it from
both the original and the converted model, normalise (strip comments, collapse
whitespace, uppercase), and compare **token by token**. Report the first differing
token index and its neighbours, so a one-token slip is instantly locatable.

Expected result: identical, with the token count printed as evidence.

### Check 2 — literal and identifier survival

Every string literal and every name-like identifier present in the original must
still be present in the converted model. This catches a mistyped code in a long
`IN (...)` list (`'RKP'` → `'RPK'`), a dropped column, a lost DQ block, a changed
date-format mask, an altered numeric threshold.

Compare as multisets and report anything missing. Then whitelist — **explicitly, by
name** — only what conversion legitimately removes:

| Legitimately gone | Why |
|---|---|
| target table names | became `{{ this }}` / `{{ ref() }}` |
| `MERGE`, `USING`, `WHEN MATCHED`, `VALUES`, `SET` | DBT generates the merge |
| `MERGE_ID` / `MATCH_ID` / `SOURCE_ID` / `TARGET_ID` | merge-key scaffolding |
| the `'D'` flag literal | delete became a `NOT EXISTS` pre_hook |
| subquery aliases (`AS SRC`, `AS CHG`) | the USING subquery *is* the model body |
| collapsed pass-through CTE names | only when the collapse was proven |
| pure SQL keywords | carry no business logic |

Filter SQL keywords out of the identifier comparison entirely, or the noise buries the
signal. Every whitelist entry must have a stated reason — if you cannot say why a name
disappeared, it is a defect, not an exemption.

Also surface known-unpreservable semantics as a standing `WARN` rather than silently
whitelisting them, e.g. a source `ON UPPER(a)=UPPER(b)` that DBT's `unique_key`
cannot express. It should print on every run so it never becomes invisible.

### Reference implementation

```python
import re, pathlib, collections

PAIRS = [("<original>.sql", "<model>.sql"), ...]
SRC_DIR, MOD_DIR = pathlib.Path("<input>"), pathlib.Path("<output>/models/<folder>")

def strip_comments(t):
    t = re.sub(r"/\*.*?\*/", " ", t, flags=re.S)
    return re.sub(r"--[^\n]*", " ", t)

def strip_jinja(t):                      # reduce a model to plain SQL
    t = re.sub(r"\{#.*?#\}", " ", t, flags=re.S)
    t = re.sub(r"\{%-?.*?-?%\}", " ", t, flags=re.S)
    t = re.sub(r"\{\{\s*config\(.*?\)\s*\}\}", " ", t, flags=re.S)
    t = re.sub(r"\{\{\s*source\(\s*'[^']*'\s*,\s*'([^']*)'\s*\)\s*\}\}", r"\1", t)
    t = re.sub(r"\{\{\s*ref\(\s*'([^']*)'\s*\)\s*\}\}", r"\1", t)
    return re.sub(r"\{\{.*?\}\}", " TARGETTBL ", t, flags=re.S)

def extract_calls(text, fn="MD5"):       # paren-balanced extraction
    out = []
    for m in re.finditer(rf"\b{fn}\s*\(", text, re.I):
        depth = 0
        for j in range(m.end() - 1, len(text)):
            if text[j] == "(": depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    out.append(re.sub(r"\s+", "", text[m.end():j]).upper()); break
    return out

def tokens(s):   return re.findall(r"[A-Z0-9_]+|'[^']*'|\|\||[(),~.]", s)
def literals(t): return collections.Counter(re.findall(r"'((?:[^']|'')*)'", t))
def idents(t):
    t = re.sub(r"'(?:[^']|'')*'", " ", t)
    return set(re.findall(r"\b[A-Z][A-Z0-9_]{1,}\b", t)) - SQL_KEYWORDS
```

Compare `extract_calls` output for Check 1; `literals` / `idents` for Check 2. Exit
non-zero on any unexplained difference so it can gate CI.

### Report the numbers

Quote the counts in the conversion report — they are the evidence:

```
OK   m_ods_p_work_order.sql    1 MD5 expr, 987 tokens each - identical
OK   m_ods_p_work_order.sql    literals 120  idents 123  CASE 1->1
checked 687 literal occurrences, 624 identifiers, 32 CASE blocks
PROBLEM FILES: none
```

### State plainly what is still unverified

These checks prove the SQL text was carried across faithfully. They do **not** prove
runtime equivalence. Say so explicitly, and name what is untested: no `dbt compile`,
no `dbt run`, no row-level comparison against the original. If runtime proof is
wanted, offer a row-count + checksum diff the user can run themselves.

## Verification checklist

- [ ] N input statements → N output model files
- [ ] Every model has the CONVERSION SUMMARY header
- [ ] Every model declares `database=` and `schema=` explicitly in `config()`
- [ ] **Every model has `pre_hook` starting with `log_model_start(this, '<ASYS>')`**
- [ ] **Every model has `post_hook` ending with `log_model_end(this, '<ASYS>')`**
- [ ] `TRUNCATE TABLE IF EXISTS {{this}}` present **only** where the source SQL truncated — never on incremental/merge
- [ ] Any other source-required DML sits between the two log calls, in original order
- [ ] Every model starts its WITH block with `JOB_PARAM` + `JOB_CONTROL`
- [ ] Every table reference is `ref()`, `source()`, or `{{ this }}` — original FQN kept as inline comment
- [ ] Upsert models: `unique_key` matches `$PRIMARY_KEY` (or MERGE ON clause)
- [ ] Upsert models: `full_refresh=false`
- [ ] Upsert models: final SELECT has `LEFT JOIN {{ this }} TGT ON <pk>` and DECODE-based WHERE
- [ ] Explicit `CAST(...)` for every column when `$DESC_TABLE` is available
- [ ] Audit column uses `COALESCE(TGT, SRC)`
- [ ] Snowflake-native syntax untouched
- [ ] `${VAR}` replaced with `{{ var() }}` or JOB_PARAM lookup
- [ ] **Check 1 run and passing** — every transcribed `MD5(...)` / checksum / `ARRAY_CONSTRUCT` / long `CASE` is token-identical to the original
- [ ] **Check 2 run and passing** — every original string literal and identifier survives, with each whitelisted removal justified by name
- [ ] Verification scripts written to `<output>/verification/` and their output quoted in the report
- [ ] Report states plainly that nothing was executed (no `dbt compile`/`run`/row comparison)
- [ ] `dbt_project.yml` has a `vars.app_name_by_schema` entry for **every** schema written to
- [ ] `macros/log_model_start.sql` + `macros/log_model_end.sql` exist
- [ ] `macros/generate_schema_name.sql` + `macros/generate_database_name.sql` exist
- [ ] **No macro file has exactly one caller** — grep each macro name across `models/`; a single hit means it should have been an inline string or a `{% set %}` block in that model
- [ ] Every `{% set %}` hook block carries a `{#- ... -#}` provenance comment (source file + line range, mapping/session name, why it is a hook)
- [ ] Report includes the `<APP_NAME>_JOB_EXECUTION` create-table DDL

## Anti-patterns

- ❌ **Reporting a conversion complete without running both verification checks** — reading the SQL attentively is not verification
- ❌ Claiming "logic preserved" on the basis of review alone, or letting the user assume execution happened when it did not
- ❌ Whitelisting a missing identifier because it is inconvenient, rather than because you can say why conversion removed it
- ❌ Silently absorbing an unpreservable semantic (e.g. `ON UPPER(a)=UPPER(b)`) into the whitelist instead of printing it as a standing WARN
- ❌ Multiple statements → one model
- ❌ Auto-adding `unique`/`not_null` schema tests without user request
- ❌ Inventing types when `$DESC_TABLE` is missing — SKIP the CAST layer instead
- ❌ Dropping the original FQN comment
- ❌ Shipping a model without `log_model_start` / `log_model_end` hooks
- ❌ **Creating a macro file for DML only one model calls** — inline it, or use a `{% set %}` block in that model
- ❌ Splitting one model's statement chain across several single-use macro files, so a reader has to open five files to follow one workflow
- ❌ Cramming a 40-line MERGE into a quoted hook string — that is what the `{% set %}` form is for
- ❌ Adding `TRUNCATE` to a model whose source SQL had none — especially an incremental/merge model
- ❌ Wiring the log macros but forgetting `vars.app_name_by_schema` — the run fails with "Missing required app_name for this model"
- ❌ Omitting `schema=` from `config()` while using the log macros — `model.config.schema` comes back null and the app_name lookup fails
- ❌ Refactoring CTE names or restructuring the CTE tree
- ❌ Silent removal of `USE`/`SET`/`GRANT` — flag them

## When to stop and ask

- File has multiple statements — confirm they're independent
- Table ref could be ref or source
- No obvious `unique_key` for an upsert
- Stored proc / Task / Stream referenced
- Two statements in the same file target the same table
- No `$DESC_TABLE` and no DDL — skip CAST/DECODE or ask
- Autosys job name not given — default to `<TARGET_UPPERCASE>_ASYS`; ask only if user's convention differs
