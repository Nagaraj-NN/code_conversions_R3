# dbt_GENDB01_FELADM

dbt conversion of the FEL Informatica PowerCenter application.

Input: the 46 validated Snowflake scripts in `FEL/Executed_sqls/`, one per
PowerCenter mapping across six workflows. Output: 47 models — one per mapping,
except `m_FEL_COMTRAC_CONTRACT_DIM_ins_upd`, which carries two target load
orders and becomes two models.

The pattern follows `dp-cust-cxnext`, the production dbt project for the CXNEXT
application: database and schema set per folder in `dbt_project.yml`, sources
declared once in `models/feladm_schema.yml`, `log_model_start` / `log_model_end`
on every model, `mark_failed_jobs` on `on-run-end`, and DML that writes a table
other than the model's own relation carried in hooks.

## Layout

```
dbt_project.yml            folder-level +database / +schema, vars, on-run-end
profiles.yml               dev / qa / uat / prod / ci
packages.yml               empty on purpose - no third-party dependencies
macros/                    6 macros, all copied from the reference project
models/feladm_schema.yml   80 source tables in 3 source groups
models/FELADM/FDR/         20 feeder models
models/FELADM/DIM/         15 dimension models
models/FELADM/FACT/        10 fact models
models/FELADM/BRDG/         2 bridge models
models/METADATA/            1 job-control model
seeds/                     FEL_JOB_CONTROL_SEEDS.csv, one row per model
inventory.md               per model: sources, lookups, hook tables, target
parameters.text            the frozen date parameters and how to unfreeze them
```

## The five model shapes

Informatica writes one target from several instances in one session. dbt gives
a model exactly one relation, so the shape depends on what the mapping does.

| Shape | Count | Materialization | Where the DML lives |
|---|---|---|---|
| UPDATE + INSERT | 28 | `table`, aliased `<TARGET>_SRC` | both branches in `post_hook` |
| DELETE | 9 | `table`, aliased `<TARGET>_DEL_SRC` | `DELETE ... USING {{ this }}` in `post_hook` |
| TRUNCATE + INSERT | 7 | `incremental` / `append`, `full_refresh=false` | model IS the target; `TRUNCATE` in `pre_hook` |
| INSERT only | 2 | `table`, aliased `<TARGET>_SRC` | `INSERT` in `post_hook` |
| second UPDATE pass | 1 | `table`, aliased `<TARGET>_..._SRC` | `UPDATE` in `post_hook`, ordered by `depends_on` |

No model is a view. A delete model materialises its key set as a table so the
keys are snapshotted before the `DELETE` runs and can be counted after it.

### Does `materialized='table'` destroy the target every run?

No — because **no `table` model points at a real target table**. dbt does issue
`create or replace transient table` for every `table` model, but the relation it
replaces is the model's own aliased `<TARGET>_SRC` scratch relation, which holds
only the transformed source row set and is fully derived. The real table is
never touched by dbt's materialization; it is written solely by the hooks,
through `{{ source(...) }}`, with the validated `UPDATE` / `INSERT` / `DELETE`.

The 8 models that *do* own their target are `incremental` with
`full_refresh=false`. In steady state each one issues `TRUNCATE` + `INSERT`,
which is exactly the Informatica "Truncate target table option = YES" behaviour
they were converted from, and `full_refresh=false` means `dbt run --full-refresh`
cannot rebuild them either.

Measured on dbt 1.10.15 / dbt-snowflake 1.10.8 by capturing every statement dbt
would send:

| run | `create or replace` on a real target |
|---|---|
| `dbt run` (targets exist) | none — 40 `_SRC` relations only |
| `dbt run --full-refresh` | none — blocked by `full_refresh=false` |

Snowflake's `create or replace` is atomic, so there is also no window in which a
`_SRC` relation is missing while a hook reads it.

Only the truncate-and-reload models materialize their own target. Everywhere
else the model is the transformed source row set and the hooks write the real
table through `{{ source(...) }}`, which is how the reference project handles
the same Informatica router pattern.

## Conversion decisions worth knowing

**Session variables are inlined.** `$V_SESSSTARTTIME` becomes
`CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)` in the model body, so it is
computed once when the table materializes and both hooks read the same value —
the same one-value-per-session behaviour SESSSTARTTIME had. The rest become
their literals. See `parameters.text`.

**Date windows stay frozen.** 22 models filter on a `$$START_TIME` /
`$$END_TIME` that Informatica had already resolved to a literal before the
script was validated. Those literals are reproduced exactly, so each of those
models reloads the same window on every run. `parameters.text` lists all 22 with
their filter columns and the exact steps to move them onto the job-control
window. The scaffolding for that swap ships here but is deliberately not wired.

**Autosys job names are placeholders.** Every model uses `TBD_<MODEL_NAME>` in
`log_model_start` / `log_model_end` and in the seed. Replace both, plus the
seed row, together — the four must agree or the control row never matches.

**One INNER JOIN became a LEFT JOIN in 7 models.** Where the validated script
stated the router's matched branch with an inner join to a lookup and the
unmatched branch without it, the merged model body uses a left join so both
branches keep their rows. Each of those lookups is reduced to one row per key
by its own `QUALIFY`, and the UPDATE hook still filters on the lookup column,
so no row is updated that was not updated before. The affected models say so in
their header.

**Informatica quirks are preserved, not corrected.** Tautologies such as
`'C' = 'C'` (from `$$RUN_STATUS`), asymmetric column widths between the insert
and update writers, dead router branches and the `MAX(key) + ROW_NUMBER()`
surrogate keys with their gaps are all reproduced as authored.

## Run auditing

`GENDB01.METADATA.FEL_JOB_EXECUTION` gets a complete row per model, not just a
status. `log_model_start` and `log_model_end` here differ from the reference
project's in three ways:

- **`RECORDS_PROCESSED` is filled in.** The count comes from the model's own
  relation via a `FROM` subquery, because Snowflake's `UPDATE ... SET` does not
  accept a scalar subquery. What it means depends on the shape:
  truncate-and-reload models count **rows loaded**; delete models count **rows
  deleted**; the insert/update models count **rows read** — the figure directly
  comparable to Informatica's reader count (`BLKR_16019`) in the session logs,
  not rows applied per branch. Per-branch applied counts would need
  `RESULT_SCAN` on each hook, which is fragile; compare rows read first.
- **`SOURCE_OBJECT` and `TARGET_OBJECT` are populated at start**, so a model
  that fails and is marked `FAILED` by `mark_failed_jobs` still records what it
  was reading and what it was writing.
- **`log_model_end` guards `app_name`** the way `log_model_start` already did.
  Without it a missing mapping silently builds the table name
  `<DB>.METADATA.None_JOB_EXECUTION`.
- **`JOB_NAME` is `model.name`.** The reference project's `model_name.name` is
  equivalent and correct — see the note below — but `model.name` says plainly
  that this is the dbt model name, which is what the seed holds and what
  `mark_failed_jobs` keys on via `r.node.name`.

### Parse time vs run time, and why it matters here

A macro called inside `config()` is evaluated at **parse** time and its output
is stored as the hook text. At that point the model's own `alias` config has not
been applied, so a `this` passed in as a macro **argument** is the *un-aliased*
relation. A `{{ this }}` written inside a hook **string**, or emitted as literal
text by a macro, is rendered later and does carry the alias. Measured on
dbt 1.10.15 / dbt-snowflake 1.10.8 with model `MY_MODEL` aliased `MY_MODEL_SRC`:

| what | renders as |
|---|---|
| `pre_hook=[ my_macro(this) ]` | `GENDB01.FELADM.MY_MODEL` |
| macro emits a literal `{{ this }}` | `GENDB01.FELADM.MY_MODEL_SRC` |
| `pre_hook=[ "… {{ this }} …" ]` | `GENDB01.FELADM.MY_MODEL_SRC` |

Two consequences. First, `this.name` inside `config()` **is** the model name, so
the reference project has been recording `JOB_NAME` correctly all along.
Second, `RECORDS_PROCESSED` and `SOURCE_OBJECT` must emit a literal `{{ this }}`
rather than use the macro argument — otherwise, for the 40 aliased models here,
they would name the *target table* and the count would report the target's size
instead of the rows this model produced.

## Promotion guard

`log_model_start` calls `assert_ready_for_promotion`, which refuses to compile
on `qa`, `uat` and `prod` when either of two things is still true of a model:

- a frozen date literal is left in the body (`TO_TIMESTAMP_NTZ('<digits>…`), or
- its Autosys job name still starts with `TBD`.

`dev` and `ci` are untouched — building with frozen literals is exactly what you
want while converting and validating. Today the guard blocks all 22 models
listed in `parameters.text` on a promotion target, plus every model until the
real Autosys names land. That is the intended state: an unfinished conversion
should fail at compile time rather than quietly reload the same slice for ever.

To see what it would stop:

```
dbt compile --target qa
```

Both macros keep the original two-argument call signature, so they are drop-in
for `dp-cust-cxnext` if you want to upstream them.

## Prerequisites

Before the first run, `GENDB01.METADATA` must hold `FEL_JOB_EXECUTION`,
`FEL_JOB_CONTROL` and `FEL_JOB_PARAMETERS`. The DDL is the same as the
reference project's, with `FEL` in place of `CXNADM`.

## Verification

Each model was checked against its validated script for expression identity
(balanced-paren extraction of every `CASE` / `IFF` / `NVL` / `COALESCE` /
`DECODE` / `MD5` block, compared token by token) and for literal and identifier
survival. All 46 scripts pass with zero lost expressions, literals or
identifiers. Structural checks — paren balance, jinja balance, every `source()`
declared, no leftover session variable, no DML outside a hook, log hooks
present — pass on all 48 models.

`dbt parse`, `dbt compile` and `dbt build` all run clean against a stubbed
Snowflake connection (`PASS=50 WARN=0 ERROR=0 SKIP=0`), which exercises the real
dbt Jinja pipeline — only the warehouse round trip is faked. Nothing here has
been run against a live Snowflake account.
