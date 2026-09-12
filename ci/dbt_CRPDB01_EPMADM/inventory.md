# Inventory — dbt_CRPDB01_EPMADM

One model per mapping. The input is the two workflow-level scripts in
`ci/CI mappings/RESULT/` (`wkf_LOAD_CI_ATOMIC`, `wkf_LOAD_CI_ATOMIC_AUDIT`) plus
per-session scripts for the other `wkf_LOAD_CI_ATOMIC` mappings: seven in `ci/`
(uploaded 2026-09-12) and `s_m_ps_z_cpp_d00_ins_upd.sql` in
`ci/CI mappings/RESULT/`. The workflow scripts do not label their statements, so
each of their statements is assigned to a mapping by target table and JOBID.

## Run order

Autosys enforces order, as for FEL. These are the orderings the data depends on:

| Must run | Why |
|---|---|
| `PS_Z_JOB_CONTROL_UPD_DTTM` **before** `PS_Z_CPP_D00_DEL`, `PS_Z_CI_EST_F00_DEL` | they read the CPP_D00 / CI_EST_F00 windows it opens |
| `PS_Z_CI_D00_DEL` **before** `PS_Z_CI_D00_INS_UPD` | the delete removes changed keys, the load merges them back; reversed, the delete would remove freshly loaded rows |
| `PS_Z_CPP_D00_DEL` **before** `PS_Z_CPP_D00` | the delete writes the delete log from the change log; the reload then truncates and refills PS_Z_CPP_D00 |
| `PS_Z_CI_EST_F00_DEL` **before** the CI_EST_F00 load | that load, `m_ps_z_ci_est_f00_ins_upd`, has not been uploaded |
| the loads **before** `PS_Z_JOB_CONTROL_UPD_STATUS` (last) | it marks the windows complete |
| `PS_Z_CI_REV_DTLVW_AUDIT` **before** `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | the second finds the first's row by `MAX(RUN_DT)` |
| `PS_Z_JTP_RELATE_CI`, the PDS, PMRG and GEN_STAT loads | no dependency on the job-control windows |

## Models

| # | Model | Mapping | Source SQL | Materialization | Reads | Writes | RECORDS_PROCESSED |
|---|---|---|---|---|---|---|---|
| 1 | `PS_Z_JOB_CONTROL_UPD_DTTM` | m_ps_z_job_control_upd_dttm | RESULT/wkf_LOAD_CI_ATOMIC.sql 25–37 | table `_SRC` | PS_Z_JOB_CONTROL | UPDATE PS_Z_JOB_CONTROL ×2 | job-control rows moved (2) |
| 2 | `PS_Z_JTP_RELATE_CI` | m_ps_z_jtp_relate_ci_ins | RESULT/wkf_LOAD_CI_ATOMIC.sql 39–55 | incremental / append, `full_refresh=false` | PS_Z_JTP_RELATE_CI (PeopleSoft) | TRUNCATE + load of itself | rows loaded |
| 3 | `PS_Z_CI_D00_DEL` | m_ps_z_ci_d00_del | RESULT/wkf_LOAD_CI_ATOMIC.sql 57–84 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CI_CHG_LOG_VW | INSERT PS_Z_CI_DELETE_LOG; DELETE PS_Z_CI_D00 | change-log rows = delete-log rows |
| 4 | `PS_Z_CPP_D00_DEL` | m_ps_z_cpp_d00_del | RESULT/wkf_LOAD_CI_ATOMIC.sql 86–111 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CPP_CH_LOG_VW | INSERT PS_Z_CPP_DELETE_LOG; DELETE PS_Z_CPP_D00 | change-log rows = delete-log rows |
| 5 | `PS_Z_CI_EST_F00_DEL` | m_ps_z_ci_est_f00_del | RESULT/wkf_LOAD_CI_ATOMIC.sql 113–124 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CI_CHG_LOG_VW | DELETE PS_Z_CI_EST_F00 | distinct changed keys (not fact rows) |
| 6 | `PS_Z_JOB_CONTROL_UPD_STATUS` | m_ps_z_job_control_upd_status | RESULT/wkf_LOAD_CI_ATOMIC.sql 126–132 | table `_SRC` | PS_Z_JOB_CONTROL | UPDATE PS_Z_JOB_CONTROL ×2 | job-control rows closed (2) |
| 7 | `PS_Z_CI_REV_DTLVW_AUDIT` | m_ps_z_ci_rev_dtlvw_audit | RESULT/wkf_LOAD_CI_ATOMIC_AUDIT.sql 21–61 | table `_SRC` | PS_Z_CI_REV_DTLVW | MERGE PS_Z_EPM_AUDIT | 1 audit row |
| 8 | `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | m_ps_z_ci_est_f00_atomic_audit | RESULT/wkf_LOAD_CI_ATOMIC_AUDIT.sql 63–103 | table `_SRC` | PS_Z_CI_EST_F00, PS_Z_EPM_AUDIT | MERGE PS_Z_EPM_AUDIT | 1 audit row, or 0 if the fact is empty |
| 9 | `PS_Z_CI_D00_INS_UPD` | m_ps_z_ci_d00_ins_upd | ci/s_m_ps_z_ci_d00_ins_upd_apple_to_apple.sql 19–542 | table `_SRC` | PS_Z_CI_DTL_VW, PS_Z_IR_DETAIL_TBL (PeopleSoft) | MERGE PS_Z_CI_D00 | source rows read |
| 10 | `PS_Z_CPP_D00` | m_ps_z_cpp_d00_ins_upd | RESULT/s_m_ps_z_cpp_d00_ins_upd.sql 21–82 | incremental / append, `full_refresh=false` | PS_Z_CPP_DTL_VW (PeopleSoft) | TRUNCATE + load of itself | rows loaded |
| 11 | `PS_Z_PDS_CI_DTL_INS` | m_ps_z_pds_ci_dtl_ins | ci/s_m_ps_z_pds_ci_dtl_ins.sql 18–104 | table `_SRC` | PS_Z_PDS_CI_VW (PeopleSoft); PS_Z_PDS_CI_DTL (router lookup) | MERGE PS_Z_PDS_CI_DTL | source rows read |
| 12 | `PS_Z_PDS_CPP_DTL_INS` | m_ps_z_pds_cpp_dtl_ins | ci/s_m_ps_z_pds_cpp_dtl_ins.sql 18–99 | table `_SRC` | PS_Z_PDS_CPP_VW (PeopleSoft); PS_Z_PDS_CPP_DTL (router lookup) | MERGE PS_Z_PDS_CPP_DTL | source rows read |
| 13 | `PS_Z_CI_PMRG_ANLS_TBL_INS` | m_ps_z_ci_pmrg_anls_tbl_ins | ci/s_m_ps_z_pmrg_anls_tbl_ins.sql 16–73 | table `_SRC` | PS_Z_PMRG_ANLS_TBL (PeopleSoft; and EPMADM as router lookup) | MERGE PS_Z_PMRG_ANLS_TBL | source rows read |
| 14 | `PS_Z_PMRG_CPP_TBL_INS` | m_ps_z_pmrg_cpp_tbl_ins | ci/s_m_ps_z_pmrg_cpp_tbl_ins.sql 18–150 | table `_SRC` | PS_Z_PMRG_CPP_TBL (PeopleSoft; and EPMADM as router lookup) | MERGE PS_Z_PMRG_CPP_TBL | source rows read |
| 15 | `PS_Z_CI_GEN_STAT_INS` | m_ps_z_ci_gen_stat_ins | ci/s_m_ps_z_ci_gen_stat_ins.sql 18–245 | table `_SRC` | PS_Z_CI_GEN_STAT (PeopleSoft; and EPMADM as router lookup), PS_PERSONAL_D00 ×3 | MERGE PS_Z_CI_GEN_STAT | source rows read |
| 16 | `PS_Z_CPP_GEN_STAT_INS` | m_ps_z_cpp_gen_stat_ins | ci/s_m_ps_z_cpp_gen_stat_ins.sql 18–238 | table `_SRC` | PS_Z_CPP_GEN_STAT (PeopleSoft; and EPMADM as router lookup), PS_PERSONAL_D00 ×3 | MERGE PS_Z_CPP_GEN_STAT | source rows read |

## Guards

`macros/assert_psft_source.sql`, called at the top of the model body so it runs
before any hook:

| Model | Stops compilation when |
|---|---|
| `PS_Z_JTP_RELATE_CI` | its PeopleSoft source is its own target, or does not exist |
| `PS_Z_CPP_D00` | its source view does not exist (the TRUNCATE would empty the table before the read failed) |
| `PS_Z_CI_PMRG_ANLS_TBL_INS`, `PS_Z_PMRG_CPP_TBL_INS`, `PS_Z_CI_GEN_STAT_INS`, `PS_Z_CPP_GEN_STAT_INS` | their PeopleSoft source is their own target |

All of them clear once `CI_PSFT_SOURCE` points at the replicated PeopleSoft
schema.

## Not converted

| File / mapping | Why |
|---|---|
| `m_ps_z_ci_est_f00_ins_upd` | no SQL has been uploaded; PS_Z_CI_EST_F00 is only deleted from here, and the audit workflow compares against it |
| `ci/s_m_ps_z_ci_d00_ins_upd.sql` | superseded by the `_apple_to_apple` upload: same 119 insert and 116 update columns, but its PS_Z_IR_DETAIL_TBL lookup is not de-duplicated, so a key with two IR rows would make the MERGE fail |
| the first versions of the seven re-uploaded sessions in `ci/CI mappings/RESULT/` | superseded by the `ci/` uploads |

## Tables written that the header does not list

`PS_Z_CI_DELETE_LOG` and `PS_Z_CPP_DELETE_LOG` are written by the two D00
delete models but are missing from the workflow header's `TARGET TABLE` line.
