# dbt_CRPDB01_EPMADM

dbt conversion of the CI workflows `wkf_LOAD_CI_ATOMIC` and
`wkf_LOAD_CI_ATOMIC_AUDIT`.

Input: the two workflow-level scripts in `ci/CI mappings/RESULT/`, which hold
the complete code for both workflows. Output: 8 models covering all 13
statements, one per mapping that owns them. The pattern is the FEL project's, which follows
`dp-cust-cxnext`: folder-level `+database` / `+schema`, sources declared once,
`log_model_start` / `log_model_end` on every model, `mark_failed_jobs` on
`on-run-end`, and DML that writes a table other than the model's own relation
carried in hooks.

## Read this first — two things about the input

**1. The scripts did not execute cleanly.** Each carries its own error log:
`PS_Z_JOB_CONTROL`, `PS_Z_CPP_CH_LOG_VW` and `PS_Z_CI_REV_DTLVW` were
"does not exist or not authorized" in `CRPDB01_DEV_SANDBOX.EPMADM`. Unlike FEL,
where every script had run and been compared, "validated" here means converted.
Nothing in this project has been checked against real CI data.

**2. One statement empties its own table.** The JTP load truncates
`EPMADM.PS_Z_JTP_RELATE_CI` and then inserts `SELECT ... FROM
EPMADM.PS_Z_JTP_RELATE_CI` — the table it has just emptied. In Informatica the
reader and the writer were different connections; the conversion gave both the
same name. The model `PS_Z_JTP_RELATE_CI` refuses to compile until its source is
pointed somewhere else. See *Guards* below.

## Layout

```
dbt_project.yml             folder-level +database / +schema, vars, on-run-end
profiles.yml                dev / qa / uat / prod / ci
packages.yml                empty on purpose - no third-party dependencies
macros/                     log_model_start, log_model_end, mark_failed_jobs,
                            generate_schema_name - FEL's, unchanged in logic
models/epmadm_schema.yml    3 source groups
models/EPMADM/ATOMIC/       6 models, wkf_LOAD_CI_ATOMIC
models/EPMADM/AUDIT/        2 models, wkf_LOAD_CI_ATOMIC_AUDIT
seeds/                      empty - no model uses the dbt run window
inventory.md                per model: source lines, reads, writes, run order
```

## Conversion decisions

**One model per mapping.** The scripts are per workflow and do not label their
statements, so each statement is assigned to a mapping from the header's mapping
list by target table and JOBID. Each model's header gives the exact source lines.
The header lists 15 mappings; the statements belong to 6 of them. The other 9
have no statement in the workflow, so there is nothing to convert for them -
`inventory.md` lists them.

**Database is `CRPDB01`, app name is `EPMADM`.** The scripts name
`CRPDB01_DEV_SANDBOX` because that is where they were executed; the models
write `CRPDB01.EPMADM`, the same way the reference writes `UTLDB01` although its
scripts named `UTLDB01_DEV_SANDBOX`. `EPMADM` is the application name the log
macros need: the shared METADATA schema already holds `EPMADM_JOB_CONTROL`,
`EPMADM_JOB_EXECUTION` and `EPMADM_JOB_PARAMETERS`, and the team's conversion
skill names this source group `CRPDB01_EPMADM`.

**PeopleSoft sources have their own group.** `CI_PSFT_SOURCE` holds the four
objects the mappings read from PeopleSoft — the two change-log views,
`PS_Z_CI_REV_DTLVW` and `PS_Z_JTP_RELATE_CI`. It points at `EPMADM` because
that is what the scripts say, but points 1 and 2 above both show that is
not where they live. Repoint the group once the replicated schema is known; no
model changes.

**No frozen parameters.** Unlike FEL, CI's load window is not a resolved
literal: it lives in `EPMADM.PS_Z_JOB_CONTROL`, and two of the converted
mappings maintain it exactly as Informatica did. So there is no
`parameters.text`, and no seed: in `dp-cust-cxnext` a model has a seed row
only if it reads its load window from the dbt job-control table (27 of its 81
models do), and no CI model does. For the same reason there is no
`EPMADM_JOB_CONTROL` model - that METADATA table belongs to the EPMADM
application as a whole, and nothing here needs to write it.

**The shapes.**

| Models | Materialization | What the model holds | Hooks |
|---|---|---|---|
| `PS_Z_JOB_CONTROL_UPD_DTTM`, `_UPD_STATUS` | `table`, `_SRC` | the job-control rows about to move | the two validated UPDATEs, verbatim |
| `PS_Z_CI_D00_DEL`, `PS_Z_CPP_D00_DEL` | `table`, `_SRC` | change-log rows in the window | delete-log INSERT, then DELETE ... IN |
| `PS_Z_CI_EST_F00_DEL` | `table`, `_SRC` | distinct changed keys in the window | DELETE ... IN |
| `PS_Z_CI_REV_DTLVW_AUDIT`, `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | `table`, `_SRC` | the MERGE's USING subquery | the MERGE, reading the model |
| `PS_Z_JTP_RELATE_CI` | `incremental` / `append`, `full_refresh=false` | the target itself | TRUNCATE pre-hook |

As in FEL, no `table` model points at a real table: dbt's
`create or replace` only ever replaces a `_SRC` relation, and the one model
that owns its target cannot be rebuilt by `--full-refresh`.

The delete models keep the original `(key, ...) IN (SELECT ...)` form rather
than FEL's `EQUAL_NULL` join, because that is what these scripts wrote: a row
with a NULL key part is not deleted, as before. The audit MERGEs stay hooks
rather than `incremental` models because `PS_Z_EPM_AUDIT` has two writers here
and, by its name, others outside this project.

**Two things in the scripts are deliberately not reproduced as extra work.**

- The workflow header lists `TRUNCATE TABLE PS_Z_CPP_D00` as PRE SQL, but the
  script body never runs it. It is not added — truncating before the delete
  would make the delete pointless.
- `PS_Z_CI_D00_DEL` reads the `CI_D00` window, but nothing in the scripts
  opens or closes it — only `CI_EST_F00` and `CPP_D00` are moved. Converted
  as written, `CI_D00` re-reads the same window every run unless something
  outside this workflow advances it.

## Guards

**JTP source guard.** `PS_Z_JTP_RELATE_CI` raises a compilation error while
`source('CI_PSFT_SOURCE', 'PS_Z_JTP_RELATE_CI')` resolves to the model's own
relation. Compilation happens before any hook runs, so the TRUNCATE is never
sent. It applies on every target, dev included — an empty dev table is still
data loss.

**Promotion guard.** Carried from FEL: `log_model_start` refuses to compile on
`qa`, `uat` and `prod` while a model's Autosys job name starts with `TBD`. All
8 models use `TBD_<MODEL>`. Replace the name in `log_model_start` and
`log_model_end` together.

## Run auditing

Same macros as FEL, so `CRPDB01.METADATA.EPMADM_JOB_EXECUTION` gets a full row
per model — `SOURCE_OBJECT`, `TARGET_OBJECT` and `RECORDS_PROCESSED` included.
What `RECORDS_PROCESSED` means differs by model; `inventory.md` says which.

## Prerequisites

`CRPDB01.METADATA` must hold `EPMADM_JOB_EXECUTION`, which the log macros
write. It is present in the CI test database's METADATA schema; it has not
been checked in `CRPDB01`.

## Verification

Run against the two scripts, on what dbt actually compiled — model body plus
hooks, with `source()` and `this` resolved from the manifest.

- **Coverage.** All 13 statements (11 + 2) are assigned to a model; no
  executable line of either script is left over.
- **Survival.** Every literal, identifier, number, qualified column reference
  and comparison predicate of every statement is present in its model: 0 lost.
- **Strict equality, 36 of 36.** The four UPDATEs are hooks character for
  character, in the original order. Both MERGEs' `USING` subqueries equal the
  model bodies and their `ON` / `WHEN` clauses equal the hooks. For each delete
  model, the select list, the column names, the FROM/WHERE of both statements,
  the DELETE key tuple and `DISTINCT` all match the original. The JTP model's
  columns match the original's SELECT list and INSERT column list, in order.

dbt 1.10.15 / dbt-snowflake 1.10.8, against a stubbed Snowflake connection —
the real dbt Jinja pipeline, only the warehouse round trip faked:

| run | result |
|---|---|
| `dbt build --target dev` | `PASS=8 ERROR=1` — the one error is the JTP guard; its TRUNCATE was never sent |
| same, `CI_PSFT_SOURCE` repointed | JTP builds: TRUNCATE of `EPMADM.PS_Z_JTP_RELATE_CI`, load from the new schema |
| `dbt compile --target qa`, per model | the TBD guard stops all 7 non-JTP models; JTP is stopped first by its source guard |

Nothing here has been run against a live Snowflake account.

## Open items

1. The replicated PeopleSoft schema for `CI_PSFT_SOURCE`.
2. Who maintains the `CI_D00` window.
3. Real Autosys job names for all 8 models.
