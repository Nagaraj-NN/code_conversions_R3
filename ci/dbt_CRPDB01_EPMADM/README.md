# dbt_CRPDB01_EPMADM

dbt conversion of the CI workflows `wkf_LOAD_CI_ATOMIC` and
`wkf_LOAD_CI_ATOMIC_AUDIT`.

Input: the two workflow-level scripts in `ci/CI mappings/RESULT/`, and
per-session scripts for the rest of `wkf_LOAD_CI_ATOMIC` - seven uploaded to
`ci/` on 2026-09-12 and `s_m_ps_z_cpp_d00_ins_upd.sql` in
`ci/CI mappings/RESULT/`. Output: 16 models, one per mapping.
`inventory.md` gives each model's source lines, reads, writes, run order and
guard; `missing_objects.md` lists every object the script headers name.

The pattern is the FEL project's, which follows `dp-cust-cxnext`: folder-level
`+database` / `+schema`, sources declared once, `log_model_start` /
`log_model_end` on every model, `mark_failed_jobs` on `on-run-end`, and DML that
writes a table other than the model's own relation carried in hooks.

## Read this first - two things about the input

**1. The scripts did not execute cleanly.** Their own error blocks report six
PeopleSoft views and `PS_Z_JOB_CONTROL` as "does not exist or not authorized" in
`CRPDB01_DEV_SANDBOX.EPMADM` (`missing_objects.md` has the list). Unlike FEL,
where every script had run and been compared, "validated" here means converted.
Nothing in this project has been checked against real CI data.

**2. Five loads read their own target.** Informatica read these tables through
the PeopleSoft connection and wrote them through the warehouse connection; the
conversion gave both the same EPMADM name. `PS_Z_JTP_RELATE_CI` would truncate
its table and reload it from itself, leaving it empty; the PMRG and GEN_STAT
MERGEs would rewrite their own rows and bring in nothing new. All five read the
PeopleSoft side through `CI_PSFT_SOURCE` and refuse to compile until it points
somewhere else - see *Guards*.

## Layout

```
dbt_project.yml             folder-level +database / +schema, vars, on-run-end
profiles.yml                dev / qa / uat / prod / ci
packages.yml                empty on purpose - no third-party dependencies
macros/                     log_model_start, log_model_end, mark_failed_jobs,
                            generate_schema_name, assert_psft_source
models/epmadm_schema.yml    3 source groups
models/EPMADM/ATOMIC/       14 models, wkf_LOAD_CI_ATOMIC
models/EPMADM/AUDIT/        2 models, wkf_LOAD_CI_ATOMIC_AUDIT
seeds/                      empty - no model uses the dbt run window
inventory.md                per model: source lines, reads, writes, run order, guard
missing_objects.md          every object the script headers name, and which are missing
.github/workflows/          ci.yml, cd.yml - the admin team's CI/CD, as supplied
```

## Conversion decisions

**One model per mapping.** The workflow scripts do not label their statements,
so each of their statements is assigned to a mapping by target table and JOBID.
Each session script holds one mapping. Every model's header gives the exact
source file and lines.

**Database is `CRPDB01`, app name is `EPMADM`.** The scripts name
`CRPDB01_DEV_SANDBOX` because that is where they were executed; the models
write `CRPDB01.EPMADM`, the same way the reference writes `UTLDB01` although its
scripts named `UTLDB01_DEV_SANDBOX`. `EPMADM` is the application name the log
macros need: the shared METADATA schema already holds `EPMADM_JOB_CONTROL`,
`EPMADM_JOB_EXECUTION` and `EPMADM_JOB_PARAMETERS`, and the team's conversion
skill names this source group `CRPDB01_EPMADM`.

**PeopleSoft sources have their own group.** `CI_PSFT_SOURCE` holds the 13
objects the mappings read from PeopleSoft. It points at `EPMADM` because that is
what the scripts say, but points 1 and 2 above show that is not where they
live. Repoint the group once the replicated schema is known; no model changes.
`PS_Z_IR_DETAIL_TBL` is placed there as a PeopleSoft lookup - nothing in the
input confirms where it lives.

**No frozen parameters, no seed.** CI's load window lives in
`EPMADM.PS_Z_JOB_CONTROL`, maintained by two of the converted mappings exactly
as Informatica did. In `dp-cust-cxnext` a model has a seed row only if it reads
its window from the dbt job-control table (27 of its 81 models do), and no CI
model does - so there is no seed and no `EPMADM_JOB_CONTROL` model.

**`m_ps_z_ci_d00_ins_upd` came in two versions.** The model is cut from
`ci/s_m_ps_z_ci_d00_ins_upd_apple_to_apple.sql`. The other upload has the same
119 insert and 116 update columns but joins `PS_Z_IR_DETAIL_TBL` without
de-duplicating it, so a key with two IR rows would put two source rows on one
target row and the MERGE would fail. The `_apple_to_apple` version keeps one IR
row per key, as an Informatica lookup returns one row.

**The router MERGEs.** Six session scripts reproduce the mapping's router: the
source rows are left-joined to a lookup on the target's key, `ROUTER_ACTION` is
UPDATE when the key exists and INSERT when it does not, and the MERGE acts on
it. The lookup is the target on the MERGE's own keys, so this matches on exactly
those keys. The lookup sits in the model body, so its snapshot of the target is
taken as the model materialises, immediately before the MERGE runs.

**The shapes.**

| Models | Materialization | What the model holds | Hooks |
|---|---|---|---|
| `PS_Z_JOB_CONTROL_UPD_DTTM`, `_UPD_STATUS` | `table`, `_SRC` | the job-control rows about to move | the two validated UPDATEs, verbatim |
| `PS_Z_CI_D00_DEL`, `PS_Z_CPP_D00_DEL` | `table`, `_SRC` | change-log rows in the window | delete-log INSERT, then DELETE ... IN |
| `PS_Z_CI_EST_F00_DEL` | `table`, `_SRC` | distinct changed keys in the window | DELETE ... IN |
| `PS_Z_CI_REV_DTLVW_AUDIT`, `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | `table`, `_SRC` | the MERGE's USING subquery | the MERGE, reading the model |
| `PS_Z_CI_D00_INS_UPD`, `PS_Z_PDS_CI_DTL_INS`, `PS_Z_PDS_CPP_DTL_INS`, `PS_Z_CI_PMRG_ANLS_TBL_INS`, `PS_Z_PMRG_CPP_TBL_INS`, `PS_Z_CI_GEN_STAT_INS`, `PS_Z_CPP_GEN_STAT_INS` | `table`, `_SRC` | the MERGE's USING subquery, router lookup included | the MERGE, reading the model |
| `PS_Z_JTP_RELATE_CI`, `PS_Z_CPP_D00` | `incremental` / `append`, `full_refresh=false` | the target itself | TRUNCATE pre-hook |

As in FEL, no `table` model points at a real table: dbt's `create or replace`
only ever replaces a `_SRC` relation, and the two models that own their target
cannot be rebuilt by `--full-refresh`.

The MERGE hooks are inline strings, not `{% set %}` blocks. A `{{ this }}`
inside a `{% set %}` block renders at parse time, before the model's alias is
applied, and would name the target instead of the `_SRC` relation; a hook
string is rendered later, with the alias in effect.

The delete models keep the original `(key, ...) IN (SELECT ...)` form rather
than FEL's `EQUAL_NULL` join, because that is what these scripts wrote: a row
with a NULL key part is not deleted, as before. The audit MERGEs stay hooks
rather than `incremental` models because `PS_Z_EPM_AUDIT` has two writers here
and, by its name, others outside this project.

**Two things worth knowing about the order.**

- The workflow header's `TRUNCATE TABLE PS_Z_CPP_D00` PRE SQL belongs to
  `s_m_ps_z_cpp_d00_ins_upd` and is the pre-hook of `PS_Z_CPP_D00`. Run after
  `PS_Z_CPP_D00_DEL`, it leaves that model's DELETE with nothing to do; its
  delete-log insert is the part that matters.
- `PS_Z_CI_D00_DEL` reads the `CI_D00` window, but no statement opens or closes
  it - only `CI_EST_F00` and `CPP_D00` are moved. Converted as written, `CI_D00`
  re-reads the same window every run unless something outside this workflow
  advances it.

## Guards

**`assert_psft_source`** (`macros/assert_psft_source.sql`) is called at the top
of the model body, so it runs at compile time, before any hook:

- **source is the target** - `PS_Z_JTP_RELATE_CI`, `PS_Z_CI_PMRG_ANLS_TBL_INS`,
  `PS_Z_PMRG_CPP_TBL_INS`, `PS_Z_CI_GEN_STAT_INS`, `PS_Z_CPP_GEN_STAT_INS`;
- **source does not exist** - `PS_Z_JTP_RELATE_CI` and `PS_Z_CPP_D00`, the two
  truncate-and-reload models, so a TRUNCATE is never sent ahead of a read that
  will fail. `PS_Z_CPP_DTL_VW` is reported missing today.

It applies on dev, qa, uat and prod - an empty dev table is still data loss.
On the `ci` target the source-is-target check only warns; see *CI / CD*.
Repointing `CI_PSFT_SOURCE` clears it.

**Promotion guard.** Carried from FEL: `log_model_start` refuses to compile on
`qa`, `uat` and `prod` while a model's Autosys job name starts with `TBD`. All
16 models use `TBD_<MODEL>`. Replace the name in `log_model_start` and
`log_model_end` together.

## CI / CD

`.github/workflows/ci.yml` and `cd.yml` are the admin team's workflows, kept
exactly as supplied. Both read `dbt_project.yml` and `profiles.yml` from the
checkout root, so they belong to this folder as a repository of its own - the
layout of `dp-cust-cxnext`. GitHub only runs workflows from a repository's root
`.github/workflows/`, so inside `code_conversions_R3` they are stored, not run.

**What CI does** (on a pull request into `dev`, `qa`, `uat` or `main`): reads the
dev target's database and schema (`CRPDB01` / `EPMADM`) and the ci target's
database (`TEST_DBT_DB`); takes the app name from `app_name_by_schema`
(`EPMADM`); creates `TEST_DBT_DB.METADATA.EPMADM_JOB_CONTROL` / `_EXECUTION` /
`_PARAMETERS` if missing; copies the project, points its `ci` target at
`TEST_DBT_DB.EPMADM`; checks that a macro reads `var('ci_schema')`; deploys it as
the Snowflake dbt project `TEST_DBT_DB.EPMADM.DBT_CI_EPMADM`; then runs
`compile` and `build --target ci --vars {"ci_schema": "EPMADM"}`.

**How the project meets it.**

- `generate_database_name` / `generate_schema_name` send every model to
  `target.database` / `var('ci_schema')` on the `ci` target, so the whole build
  lands in `TEST_DBT_DB.EPMADM`; sources follow `target.database` too.
- `app_name_by_schema` maps `EPMADM`, so the log macros and `mark_failed_jobs`
  write `TEST_DBT_DB.METADATA.EPMADM_JOB_EXECUTION`, with exactly the columns the
  workflow creates.
- `assert_psft_source` only **warns** about a source that is its own target on
  the `ci` target. CI puts every source and target in one schema, so for the
  five PeopleSoft reads that share a name with an EPMADM table this is true by
  construction there; failing would fail every run. On CI, JTP therefore
  reloads its test copy from itself (leaving it empty) and the PMRG / GEN_STAT
  MERGEs rewrite their own test rows. The missing-source check stays fatal.

**Verified offline** by running the workflow's own code against this folder -
its Resolve and Configure python blocks and its Validate bash, unmodified - and
then dbt 1.10.15 `compile` and `build --target ci --vars '{"ci_schema":"EPMADM"}'`
on the rewritten profile, against a stubbed Snowflake connection:

| step | result |
|---|---|
| Resolve / Configure / Validate | pass - `CRPDB01`, `EPMADM`, app `EPMADM`, CI `TEST_DBT_DB.EPMADM`, project `DBT_CI_EPMADM` |
| compile + build, `TEST_DBT_DB.EPMADM` holding the objects below | compile passes; build `PASS=17 ERROR=0`, 5 self-source warnings |
| compile + build, objects missing | fails: JTP and `PS_Z_CPP_D00` stop on their missing source |
| what the build writes | only `TEST_DBT_DB.EPMADM` and `TEST_DBT_DB.METADATA` |

`snow dbt deploy` and `EXECUTE DBT PROJECT` themselves were not run.

**What CI needs from the admins.** Unlike the prod workflow, this one does not
clone the source schema, so `TEST_DBT_DB.EPMADM` must already exist and hold
the 23 objects the models read (both source groups resolve there on CI):

- EPMADM tables: `PS_Z_JOB_CONTROL`, `PS_Z_CI_D00`, `PS_Z_CPP_D00`,
  `PS_Z_CI_EST_F00`, `PS_Z_CI_DELETE_LOG`, `PS_Z_CPP_DELETE_LOG`,
  `PS_Z_EPM_AUDIT`, `PS_Z_PDS_CI_DTL`, `PS_Z_PDS_CPP_DTL`,
  `PS_Z_PMRG_ANLS_TBL`, `PS_Z_PMRG_CPP_TBL`, `PS_Z_CI_GEN_STAT`,
  `PS_Z_CPP_GEN_STAT`, `PS_PERSONAL_D00`
- PeopleSoft objects: `PS_Z_CI_CHG_LOG_VW`, `PS_Z_CPP_CH_LOG_VW`,
  `PS_Z_CI_REV_DTLVW`, `PS_Z_JTP_RELATE_CI`, `PS_Z_CI_DTL_VW`,
  `PS_Z_CPP_DTL_VW`, `PS_Z_PDS_CI_VW`, `PS_Z_PDS_CPP_VW`, `PS_Z_IR_DETAIL_TBL`

Two behaviours of the workflow as supplied: `CI_SCHEMA` is the source schema
itself (`EPMADM`), not a per-PR schema, so concurrent pull requests share it;
and `snow dbt deploy --force` replaces the one `DBT_CI_EPMADM` project each run.

**What CD does** (on a push to `dev`, `qa`, `uat` or `main`): resolves that
branch's target from `profiles.yml`, creates the METADATA tables in its
database, and deploys the project as `<database>.EPMADM.dbt_CRPDB01_EPMADM`. It
deploys only; running the models is left to the scheduler, where the promotion
guard stops any model still carrying a `TBD_` Autosys name on qa, uat or prod.

## Run auditing

Same macros as FEL, so `CRPDB01.METADATA.EPMADM_JOB_EXECUTION` gets a full row
per model - `SOURCE_OBJECT`, `TARGET_OBJECT` and `RECORDS_PROCESSED` included.
What `RECORDS_PROCESSED` means differs by model; `inventory.md` says which.

## Prerequisites

`CRPDB01.METADATA` must hold `EPMADM_JOB_EXECUTION`, which the log macros
write. It is present in the CI test database's METADATA schema; it has not been
checked in `CRPDB01`.

## Verification

Run on what dbt actually compiled - model body plus hooks, with `source()` and
`this` resolved from the manifest.

**The 8 models from the workflow scripts.** All 13 statements are assigned to a
model and no executable line is left over. Every literal, identifier, number,
qualified column reference and comparison predicate survives: 0 lost. Strict
equality, 36 of 36: the four UPDATEs are hooks character for character, in the
original order; both audit MERGEs' `USING` subqueries equal the model bodies and
their `ON` / `WHEN` clauses equal the hooks; for each delete model the select
list, column names, FROM/WHERE, DELETE key tuple and `DISTINCT` match; the JTP
model's columns match the original SELECT and INSERT lists, in order.

**The 8 models from the session scripts.** Each is cut mechanically from its
script, which is refused if its table references differ from the spec. Strict
equality, 48 of 48: every `USING` subquery equals the model body and every
`ON` / `WHEN MATCHED` / `WHEN NOT MATCHED` clause equals the hook, with the same
target and aliases; every table reference compiles to the source group the spec
names - PeopleSoft reads to `CI_PSFT_SOURCE`, router lookups to `EPMADM`;
`PS_Z_CPP_D00` outputs exactly its 49 INSERT columns, in order.

**All 16.** Every table the compiled SQL touches is a declared source or a model.

dbt 1.10.15 / dbt-snowflake 1.10.8, against a stubbed Snowflake connection -
the real dbt Jinja pipeline, only the warehouse round trip faked:

| run | result |
|---|---|
| `dbt build --target dev` | `PASS=11 ERROR=6` - the six are the guards: `PS_Z_CPP_D00` and JTP (no TRUNCATE sent) and the four self-sourced MERGEs |
| same, `CI_PSFT_SOURCE` repointed | `PASS=17 ERROR=0` |
| `dbt compile --target qa`, per model, repointed | the TBD guard stops all 16 |

Nothing here has been run against a live Snowflake account.

## Open items

1. The replicated PeopleSoft schema for `CI_PSFT_SOURCE`, and where
   `PS_Z_IR_DETAIL_TBL` lives.
2. `m_ps_z_ci_est_f00_ins_upd` has no SQL yet - it is the only
   `wkf_LOAD_CI_ATOMIC` mapping without a model.
3. What advances the `CI_D00` window.
4. Real Autosys job names for all 16 models.
