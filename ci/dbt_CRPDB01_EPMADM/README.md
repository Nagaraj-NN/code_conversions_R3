# dbt_CRPDB01_EPMADM_CI

dbt conversion of the CI workflows `wkf_LOAD_CI_ATOMIC` and
`wkf_LOAD_CI_ATOMIC_AUDIT`.

Input: the two workflow-level scripts in `ci/CI mappings/RESULT/`, and
per-session scripts for the rest of `wkf_LOAD_CI_ATOMIC` - seven uploaded to
`ci/` on 2026-09-12 and `s_m_ps_z_cpp_d00_ins_upd.sql` in
`ci/CI mappings/RESULT/`. Output: 16 models, one per mapping.
`inventory.md` gives each model's source lines, reads, writes, run order and
guard; `missing_objects.md` lists every object the script headers name.

The models write `CRPDB01.EPMADM`, read PeopleSoft from
`BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`, and keep their load windows in
`PS_Z_JOB_CONTROL_CI`, the application's own copy of PeopleSoft's job-control
table.

The pattern is the FEL project's, which follows `dp-cust-cxnext`: folder-level
`+database` / `+schema`, sources declared once, `log_model_start` /
`log_model_end` on every model, `mark_failed_jobs` on `on-run-end`, and DML that
writes a table other than the model's own relation carried in hooks.

## Read this first - two things about the input

**1. The scripts did not execute cleanly.** Their own error blocks report six
PeopleSoft views and `PS_Z_JOB_CONTROL` as "does not exist or not authorized" in
`CRPDB01_DEV_SANDBOX.EPMADM` (`missing_objects.md` has the list). The scripts
name every PeopleSoft object in EPMADM; the project reads them from
`BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`, where PeopleSoft is replicated. Unlike
FEL, where every script had run and been compared, "validated" here means
converted. Nothing in this project has been checked against real CI data.

**2. Five scripts read their own target.** Informatica read these tables through
the PeopleSoft connection and wrote them through the warehouse connection; the
conversion gave both the same EPMADM name. Run as written,
`PS_Z_JTP_RELATE_CI` would truncate its table and reload it from itself, and the
PMRG and GEN_STAT MERGEs would rewrite their own rows and bring in nothing new.
The models read the PeopleSoft side from bronze, so each reads PeopleSoft again;
`assert_psft_source` stays to stop a model if its source is ever pointed back at
its own target - see *Guards*.

## Layout

```
dbt_project.yml             folder-level +database / +schema, vars, on-run-start, on-run-end
profiles.yml                dev / qa / uat / prod / ci
packages.yml                empty on purpose - no third-party dependencies
macros/                     log_model_start, log_model_end, mark_failed_jobs,
                            generate_schema_name, assert_psft_source,
                            ci_ps_z_job_control
models/epmadm_schema.yml    3 source groups
models/EPMADM/ATOMIC/       14 models, wkf_LOAD_CI_ATOMIC
models/EPMADM/AUDIT/        2 models, wkf_LOAD_CI_ATOMIC_AUDIT
seeds/                      empty - no model uses the dbt run window
analyses/                   check_bronze_peoplesoft.sql - bronze names, column case, Iceberg
inventory.md                per model: source lines, reads, writes, run order, guard
missing_objects.md          every object the script headers name, and which are missing
.github/workflows/          ci.yml, cd.yml - the admin team's CI/CD, as supplied
```

## Conversion decisions

**One model per mapping.** The workflow scripts do not label their statements,
so each of their statements is assigned to a mapping by target table and JOBID.
Each session script holds one mapping. Every model's header gives the exact
source file and lines.

**Database follows the target, app name is `EPMADM_CI`.** The scripts name
`CRPDB01_DEV_SANDBOX` because that is where they were executed. The models, the
EPMADM and METADATA sources and the audit rows' `TARGET_OBJECT` all use
`target.database`: `CRPDB01` on dev, qa, uat and prod (every such target in
`profiles.yml`), `CRPDB01_CI` on ci, and the sandbox when a developer's run
targets it. `dp-corp-ar80` fixes `+database: CRPDB01` instead; on the first live
run that sent a sandbox run's writes to `CRPDB01` - see *Live runs*. `app_name_by_schema` maps `EPMADM` to
`EPMADM_CI`, so this application's run log and control tables are
`METADATA.EPMADM_CI_JOB_CONTROL`, `EPMADM_CI_JOB_EXECUTION` and
`EPMADM_CI_JOB_PARAMETERS` - kept apart from the other applications that also
write schema `EPMADM`, such as `dp-corp-ar80`. The EPMADM source group keeps the
team skill's name, `CRPDB01_EPMADM`.

**PeopleSoft is read from bronze.** The source group `CI_PSFT_SOURCE` points at
`BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`, the replicated PeopleSoft schema - where
the sibling EPMADM project `dp-corp-ar80` reads PeopleSoft too. Its database is
pinned rather than following the target, as the reference project pins its
`BRONZE_*` sources, so every target, CI included, reads the same bronze
objects. It declares the 14 objects the mappings read from PeopleSoft. Bronze
holds 7 of them - the tables - as lower-case Iceberg tables with lower-case
columns, which Snowflake resolves from the unquoted upper-case names used here,
so nothing is quoted. The other 7 are PeopleSoft views, which bronze does not
replicate; see *Live runs*.

**Job control lives in `PS_Z_JOB_CONTROL_CI`.** The workflow opens the
`CPP_D00` and `CI_EST_F00` windows, the deletes read them, and the last model
closes them - all on `PS_Z_JOB_CONTROL`. PeopleSoft's `PS_Z_JOB_CONTROL` is in
bronze, where it cannot be updated, and EPMADM has none of its own. So the
application keeps its own copy, `CRPDB01.EPMADM.PS_Z_JOB_CONTROL_CI`, following
`dp-corp-ar80`'s `PS_Z_JOB_CONTROL_AR80` naming. `on-run-start` calls
`macros/ci_ps_z_job_control.sql`, which creates the table from bronze only if it
does not exist and adds any JOBID it lacks - it never replaces a row. That is a
deliberate difference from `dp-corp-ar80`, whose `on-run-start` re-creates its
copy on every run, discarding the windows its hooks opened and closed, and
whose loads read the bronze original rather than the copy. Here the five
job-control models open, read and close the window on one table that keeps its
state between runs, as Informatica did.

**No frozen parameters, no seed.** CI's load window is `PS_Z_JOB_CONTROL_CI`,
maintained by the converted mappings exactly as Informatica maintained
`PS_Z_JOB_CONTROL`. In `dp-cust-cxnext` a model has a seed row only if it reads
its window from the dbt job-control table (27 of its 81 models do), and no CI
model does - so there is no seed and no `EPMADM_CI_JOB_CONTROL` model.

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
| `PS_Z_JOB_CONTROL_UPD_DTTM`, `_UPD_STATUS` | `table`, `_SRC` | the job-control rows about to move | the two validated UPDATEs, on `PS_Z_JOB_CONTROL_CI` |
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
  it - only `CI_EST_F00` and `CPP_D00` are moved. Its row in
  `PS_Z_JOB_CONTROL_CI` is copied from bronze and then stays as it is, so
  `CI_D00` re-reads the same window every run unless something outside this
  workflow advances it.

## Guards

**`assert_psft_source`** (`macros/assert_psft_source.sql`) is called at the top
of the model body, so it runs at compile time, before any hook:

- **source is the target** - `PS_Z_JTP_RELATE_CI`, `PS_Z_CI_PMRG_ANLS_TBL_INS`,
  `PS_Z_PMRG_CPP_TBL_INS`, `PS_Z_CI_GEN_STAT_INS`, `PS_Z_CPP_GEN_STAT_INS`.
  With `CI_PSFT_SOURCE` on bronze this passes everywhere; it stays so that a
  source pointed back into EPMADM stops the model instead of reading its own
  target. On the `ci` target it would only warn.
- **source does not exist** - `PS_Z_JTP_RELATE_CI` and `PS_Z_CPP_D00`, the two
  truncate-and-reload models, so a TRUNCATE is never sent ahead of a read that
  will fail. Fatal on every target. The lookup is `show objects like`, compared
  without regard to case: dbt's own `adapter.get_relation` raises on bronze's
  lower-case names instead of finding them.

**Promotion guard.** Carried from FEL: `log_model_start` refuses to compile on
`qa`, `uat` and `prod` while a model's Autosys job name starts with `TBD`. All
16 models use `TBD_<MODEL>`. Replace the name in `log_model_start` and
`log_model_end` together.

## CI / CD

`.github/workflows/ci.yml` and `cd.yml` are the admin team's workflows, kept
exactly as supplied - identical to the ones in `dp-corp-ar80`. Both read
`dbt_project.yml` and `profiles.yml` from the checkout root, so they belong to
this folder as a repository of its own - the layout of `dp-cust-cxnext` and
`dp-corp-ar80`. GitHub only runs workflows from a repository's root
`.github/workflows/`, so inside `code_conversions_R3` they are stored, not run.

**What CI does** (on a pull request into `dev`, `qa`, `uat` or `main`): reads the
dev target's database and schema (`CRPDB01` / `EPMADM`) and the ci target's
database (`CRPDB01_CI`, as in `dp-corp-ar80`); takes the app name from
`app_name_by_schema` (`EPMADM_CI`); creates `CRPDB01_CI.METADATA.EPMADM_CI_JOB_CONTROL`
/ `_EXECUTION` / `_PARAMETERS` if missing; copies the project and points its `ci`
target at `CRPDB01_CI.EPMADM`; checks that a macro reads `var('ci_schema')`;
deploys it as the Snowflake dbt project `CRPDB01_CI.EPMADM.DBT_CI_EPMADM_CI`; then
runs `compile` and `build --target ci --vars {"ci_schema": "EPMADM"}`.

**How the project meets it.**

- `generate_database_name` / `generate_schema_name` send every model to
  `target.database` / `var('ci_schema')` on the `ci` target, so the build lands
  in `CRPDB01_CI.EPMADM`; the EPMADM and METADATA sources follow
  `target.database` too.
- PeopleSoft is read from `BRONZE_CORP_CONF.BRONZE_PEOPLESOFT` on every target,
  CI included, and `on-run-start` creates `CRPDB01_CI.EPMADM.PS_Z_JOB_CONTROL_CI`
  from it on the first CI run.
- `app_name_by_schema` maps `EPMADM` to `EPMADM_CI`, so the log macros and `mark_failed_jobs`
  write `CRPDB01_CI.METADATA.EPMADM_CI_JOB_EXECUTION`, with exactly the columns the
  workflow creates.

**Verified offline** by running the workflow's own code against this folder -
its Resolve and Configure python blocks and its Validate bash, unmodified - and
then dbt 1.10.15 `compile` and `build --target ci --vars '{"ci_schema":"EPMADM"}'`
on the rewritten profile, against a stubbed Snowflake connection:

| step | result |
|---|---|
| Resolve / Configure / Validate | pass - `CRPDB01`, `EPMADM`, app `EPMADM_CI`, CI `CRPDB01_CI.EPMADM`, project `DBT_CI_EPMADM_CI` |
| compile + build, every object present | compile passes; build `PASS=18 ERROR=0`, no warnings |
| compile + build, objects missing | fails: JTP and `PS_Z_CPP_D00` stop on their missing bronze source |
| what the build touches | writes only `CRPDB01_CI.EPMADM` and `CRPDB01_CI.METADATA`; reads PeopleSoft from `BRONZE_CORP_CONF.BRONZE_PEOPLESOFT` |

`snow dbt deploy` and `EXECUTE DBT PROJECT` themselves were not run.

**What CI needs from the admins.** The workflow does not clone schemas, so:

- `CRPDB01_CI.EPMADM` must exist and hold the 13 EPMADM tables the models read
  or write: `PS_Z_CI_D00`, `PS_Z_CPP_D00`, `PS_Z_CI_EST_F00`,
  `PS_Z_CI_DELETE_LOG`, `PS_Z_CPP_DELETE_LOG`, `PS_Z_EPM_AUDIT`,
  `PS_Z_PDS_CI_DTL`, `PS_Z_PDS_CPP_DTL`, `PS_Z_PMRG_ANLS_TBL`,
  `PS_Z_PMRG_CPP_TBL`, `PS_Z_CI_GEN_STAT`, `PS_Z_CPP_GEN_STAT`,
  `PS_PERSONAL_D00`. `PS_Z_JOB_CONTROL_CI` is created by the project itself.
- the CI role must read `BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`: `PS_Z_JOB_CONTROL`,
  `PS_Z_JTP_RELATE_CI`, `PS_Z_IR_DETAIL_TBL`, `PS_Z_PMRG_ANLS_TBL`,
  `PS_Z_PMRG_CPP_TBL`, `PS_Z_CI_GEN_STAT`, `PS_Z_CPP_GEN_STAT`.
- CI cannot pass until the 7 PeopleSoft views exist and the two GEN_STAT
  tables are readable - see *Live runs*. It fails as early as the `compile`
  step: `PS_Z_CPP_D00`'s existence check runs at compile time and stops on
  `PS_Z_CPP_DTL_VW`. Offline, with every object present, compile and build both
  pass.

Two behaviours of the workflow as supplied: `CI_SCHEMA` is the source schema
itself (`EPMADM`), not a per-PR schema, so concurrent pull requests share it;
and `snow dbt deploy --force` replaces the one `DBT_CI_EPMADM_CI` project each run.

**What CD does** (on a push to `dev`, `qa`, `uat` or `main`): resolves that
branch's target from `profiles.yml`, creates the METADATA tables in its
database, and deploys the project as `<database>.EPMADM.dbt_CRPDB01_EPMADM_CI`. It
deploys only; running the models is left to the scheduler, where the promotion
guard stops any model still carrying a `TBD_` Autosys name on qa, uat or prod.

## Run auditing

Same macros as FEL, so `METADATA.EPMADM_CI_JOB_EXECUTION` in the target's database gets a full row
per model - `SOURCE_OBJECT`, `TARGET_OBJECT` and `RECORDS_PROCESSED` included.
What `RECORDS_PROCESSED` means differs by model; `inventory.md` says which.

## Prerequisites

`METADATA.EPMADM_CI_JOB_EXECUTION` must exist in the target's database - the log
macros write it, and CD and CI create it - and the dbt role must read
`BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`.
`PS_Z_JOB_CONTROL_CI` is created on the first run.

## Verification

Run on what dbt actually compiled - model body plus hooks, with `source()` and
`this` resolved from the manifest.

**The 8 models from the workflow scripts.** All 13 statements are assigned to a
model and no executable line is left over. Every literal, identifier, number,
qualified column reference and comparison predicate survives: 0 lost. Strict
equality, 36 of 36, reading `PS_Z_JOB_CONTROL_CI` as the script's
`PS_Z_JOB_CONTROL`: the four UPDATEs are hooks character for character, in the
original order; both audit MERGEs' `USING` subqueries equal the model bodies and
their `ON` / `WHEN` clauses equal the hooks; for each delete model the select
list, column names, FROM/WHERE, DELETE key tuple and `DISTINCT` match; the JTP
model's columns match the original SELECT and INSERT lists, in order.

**The 8 models from the session scripts.** Each is cut mechanically from its
script, which is refused if its table references differ from the spec. Strict
equality, 48 of 48: every `USING` subquery equals the model body and every
`ON` / `WHEN MATCHED` / `WHEN NOT MATCHED` clause equals the hook, with the same
target and aliases; every table reference compiles where the spec says -
PeopleSoft reads to `BRONZE_CORP_CONF.BRONZE_PEOPLESOFT`, router lookups to
`CRPDB01.EPMADM`; `PS_Z_CPP_D00` outputs exactly its 49 INSERT columns, in order.

**All 16.** Every table the compiled SQL touches is a declared source or a model.

dbt 1.10.15 / dbt-snowflake 1.10.8, against a stubbed Snowflake connection -
the real dbt Jinja pipeline, only the warehouse round trip faked:

| run | result |
|---|---|
| `dbt build --target dev`, every object present | `PASS=18 ERROR=0` - `on-run-start` creates and tops up `PS_Z_JOB_CONTROL_CI`; the stub reports names in lower case, as bronze does, and the existence guards still find them |
| `dbt build --target dev`, objects missing | `PASS=16 ERROR=2` - JTP and `PS_Z_CPP_D00` stop on their missing source; no TRUNCATE sent |
| `dbt build`, target database `CRPDB01_DEV_SANDBOX` | `PASS=18 ERROR=0`; every write, METADATA row and `TARGET_OBJECT` is in the sandbox - no `CRPDB01` outside comments |
| `dbt compile --target qa`, per model | the TBD guard stops all 16 |
| the admin CI workflow | see *CI / CD* |

The runs against Snowflake itself are under *Live runs*.

## Live runs - 2026-09-12

Three runs in `CRPDB01_DEV_SANDBOX` - Snowflake-native dbt 1.9.4, role
`DP_DW_IT_DEVELOPER` - and `analyses/check_bronze_peoplesoft.sql`, whose results
are summarised at its top. The third run's log, committed 2026-09-13, is
`ci/f.txt`. It repeats the second exactly - same project checksum, same 16
errors - because the fixes below had not been deployed yet.

**What bronze is.** 210 unmanaged Iceberg tables (catalog `GLUE_REST_BRONZE`)
and no views. Schema, table and column names are all stored in lower case, and
Snowflake resolves unquoted upper-case names to them: `on-run-start` read
`PS_Z_JOB_CONTROL`'s columns unquoted, and the GEN_STAT loads got as far as the
Iceberg scan. Of the 14 PeopleSoft objects the mappings read, bronze has the 7
tables and none of the 7 views.

| Cause | Models | Status |
|---|---|---|
| A fixed `+database: CRPDB01` wrote the models to `CRPDB01.EPMADM` while the sources read the sandbox; the `_SRC` tables there already exist under another owner | OWNERSHIP error: `PS_Z_JOB_CONTROL_UPD_DTTM`, `_UPD_STATUS`, `PS_Z_CI_PMRG_ANLS_TBL_INS`, `PS_Z_PMRG_CPP_TBL_INS`, `PS_Z_CI_EST_F00_ATOMIC_AUDIT`; and `mark_failed_jobs` looked for `CRPDB01.METADATA` | fixed - models and audit rows follow `target.database` |
| dbt's `adapter.get_relation` found bronze's `"bronze_peoplesoft"."ps_z_jtp_relate_ci"` only as a case-insensitive match and raised instead of returning it | `PS_Z_JTP_RELATE_CI` | fixed - `assert_psft_source` checks existence with `show objects like`, ignoring case; the source is declared unquoted again |
| PeopleSoft views are not in bronze, and the scripts' own error headers show six of them missing in `CRPDB01_DEV_SANDBOX.EPMADM` too: `PS_Z_CI_CHG_LOG_VW`, `PS_Z_CPP_CH_LOG_VW`, `PS_Z_CI_REV_DTLVW`, `PS_Z_CI_DTL_VW`, `PS_Z_CPP_DTL_VW`, `PS_Z_PDS_CI_VW`, `PS_Z_PDS_CPP_VW` | `PS_Z_CI_D00_DEL`, `PS_Z_CPP_D00_DEL`, `PS_Z_CI_EST_F00_DEL`, `PS_Z_CI_D00_INS_UPD`, `PS_Z_CPP_D00` (stopped before its TRUNCATE), `PS_Z_PDS_CI_DTL_INS`, `PS_Z_PDS_CPP_DTL_INS`, `PS_Z_CI_REV_DTLVW_AUDIT` | open - each view has to be rebuilt from its PeopleSoft definition over the bronze tables |
| `Equality deletes on Iceberg tables are not supported` reading bronze `ps_z_ci_gen_stat` / `ps_z_cpp_gen_stat` | `PS_Z_CI_GEN_STAT_INS`, `PS_Z_CPP_GEN_STAT_INS` | platform - Snowflake cannot read an Iceberg table whose deletes are equality deletes; bronze has to be compacted or written with position deletes |

The first run's `PS_Z_JOB_CONTROL_CI does not exist` is gone: in the second,
`on-run-start` created the table and its INSERT from bronze succeeded. The
analysis's query 4 found no table - run it again as the role dbt runs with.

With both fixes, six models should now build in the sandbox -
`PS_Z_JOB_CONTROL_UPD_DTTM`, `_UPD_STATUS`, `PS_Z_JTP_RELATE_CI`, both PMRG loads
and `PS_Z_CI_EST_F00_ATOMIC_AUDIT` - unless their bronze tables use equality
deletes as well. The other ten wait on the views and on bronze GEN_STAT.

## Open items

1. **The 7 PeopleSoft views.** Their definitions are needed - from PeopleSoft
   (Application Designer, or the view text in the PeopleSoft database) - so each
   can be rebuilt as a dbt view over the bronze tables and the models repointed
   to it. Queries 5 and 6 of the analysis check whether any of them, or
   PeopleTools' `PSSQLTEXTDEFN`, which holds every view's SQL, exists elsewhere in
   the account. Bronze has likely base tables - `ps_z_ci_chng_log`,
   `ps_z_cpp_chng_log`, `ps_z_ci_rev_dtl`, `ps_z_ci_revision`, `ps_z_cpp_rev_dtl`,
   `ps_z_cpp_revision`, `ps_z_cpp_header`, `ps_z_cpp_ir_tbl`, `ps_project` - but a
   view's joins and filters cannot be guessed.
2. Bronze `ps_z_ci_gen_stat` and `ps_z_cpp_gen_stat` use Iceberg equality
   deletes - for the platform team.
3. **Run order.** A whole-project `dbt build` - as run on 2026-09-12, and as CI
   runs it - starts all 16 models at once: they have no refs between them, and
   the order in `inventory.md` is left to Autosys, as for FEL. On real data that
   would let `PS_Z_JOB_CONTROL_UPD_STATUS` close windows while the deletes still
   read them. A `-- depends_on: {{ ref(...) }}` line per model would make dbt
   keep that order without changing a single-model Autosys run.
4. `m_ps_z_ci_est_f00_ins_upd` has no SQL yet - it is the only
   `wkf_LOAD_CI_ATOMIC` mapping without a model.
5. What advances the `CI_D00` window.
6. `CRPDB01_CI.EPMADM` and bronze access for CI, as listed under *CI / CD*.
7. Real Autosys job names for all 16 models.
