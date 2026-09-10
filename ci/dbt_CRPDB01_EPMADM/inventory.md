# Inventory — dbt_CRPDB01_EPMADM

One model per mapping. The two validated scripts are workflow-level and do not
label their statements, so each statement is assigned to a mapping from the
script header's mapping list by its target table and JOBID.

## Run order

Autosys enforces order, as for FEL. These are the orderings the data depends on:

| Workflow | Must run | Why |
|---|---|---|
| wkf_LOAD_CI_ATOMIC | `PS_Z_JOB_CONTROL_UPD_DTTM` **before** `PS_Z_CPP_D00_DEL`, `PS_Z_CI_EST_F00_DEL` | they read the CPP_D00 / CI_EST_F00 windows it opens |
| wkf_LOAD_CI_ATOMIC | `PS_Z_JOB_CONTROL_UPD_STATUS` **last** | it marks those windows complete |
| wkf_LOAD_CI_ATOMIC | `PS_Z_JTP_RELATE_CI`, `PS_Z_CI_D00_DEL` | no dependency on this workflow's windows |
| wkf_LOAD_CI_ATOMIC_AUDIT | `PS_Z_CI_REV_DTLVW_AUDIT` **before** `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | the second finds the first's row by `MAX(RUN_DT)` |

The script's own statement order is: UPD_DTTM, JTP, CI_D00_DEL, CPP_D00_DEL,
CI_EST_F00_DEL, UPD_STATUS.

## Models

| # | Model | Mapping | Source SQL | Materialization | Reads | Writes (hooks) | RECORDS_PROCESSED |
|---|---|---|---|---|---|---|---|
| 1 | `PS_Z_JOB_CONTROL_UPD_DTTM` | m_ps_z_job_control_upd_dttm | ATOMIC 25–37 | table `_SRC` | PS_Z_JOB_CONTROL | UPDATE PS_Z_JOB_CONTROL ×2 | job-control rows moved (2) |
| 2 | `PS_Z_JTP_RELATE_CI` | m_ps_z_jtp_relate_ci_ins | ATOMIC 39–55 | incremental / append, `full_refresh=false` | CI_PSFT_SOURCE.PS_Z_JTP_RELATE_CI | TRUNCATE + load of itself | rows loaded |
| 3 | `PS_Z_CI_D00_DEL` | m_ps_z_ci_d00_del | ATOMIC 57–84 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CI_CHG_LOG_VW | INSERT PS_Z_CI_DELETE_LOG; DELETE PS_Z_CI_D00 | change-log rows = delete-log rows |
| 4 | `PS_Z_CPP_D00_DEL` | m_ps_z_cpp_d00_del | ATOMIC 86–111 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CPP_CH_LOG_VW | INSERT PS_Z_CPP_DELETE_LOG; DELETE PS_Z_CPP_D00 | change-log rows = delete-log rows |
| 5 | `PS_Z_CI_EST_F00_DEL` | m_ps_z_ci_est_f00_del | ATOMIC 113–124 | table `_SRC` | PS_Z_JOB_CONTROL, PS_Z_CI_CHG_LOG_VW | DELETE PS_Z_CI_EST_F00 | distinct changed keys (not fact rows) |
| 6 | `PS_Z_JOB_CONTROL_UPD_STATUS` | m_ps_z_job_control_upd_status | ATOMIC 126–132 | table `_SRC` | PS_Z_JOB_CONTROL | UPDATE PS_Z_JOB_CONTROL ×2 | job-control rows closed (2) |
| 7 | `PS_Z_CI_REV_DTLVW_AUDIT` | m_ps_z_ci_rev_dtlvw_audit | AUDIT 21–61 | table `_SRC` | PS_Z_CI_REV_DTLVW | MERGE PS_Z_EPM_AUDIT | 1 audit row |
| 8 | `PS_Z_CI_EST_F00_ATOMIC_AUDIT` | m_ps_z_ci_est_f00_atomic_audit | AUDIT 63–103 | table `_SRC` | PS_Z_CI_EST_F00, PS_Z_EPM_AUDIT | MERGE PS_Z_EPM_AUDIT | 1 audit row, or 0 if the fact is empty |

## Header mappings with no statement

The workflow script is the complete code for `wkf_LOAD_CI_ATOMIC`. Its header
lists fifteen mappings; the eleven statements belong to six of them. The other
nine have no statement in the workflow, so there is nothing to convert and no
model:

| Mapping | Target (from the header's target list) |
|---|---|
| m_ps_z_ci_d00_ins_upd | PS_Z_CI_D00 |
| m_ps_z_cpp_d00_ins_upd | PS_Z_CPP_D00 |
| m_ps_z_ci_est_f00_ins_upd | PS_Z_CI_EST_F00 |
| m_ps_z_pds_ci_dtl_ins | PS_Z_PDS_CI_DTL |
| m_ps_z_pds_cpp_dtl_ins | PS_Z_PDS_CPP_DTL |
| m_ps_z_ci_pmrg_anls_tbl_ins | PS_Z_PMRG_ANLS_TBL |
| m_ps_z_pmrg_cpp_tbl_ins | PS_Z_PMRG_CPP_TBL |
| m_ps_z_ci_gen_stat_ins | PS_Z_CI_GEN_STAT |
| m_ps_z_cpp_gen_stat_ins | PS_Z_CPP_GEN_STAT |


## Tables written that the header does not list

`PS_Z_CI_DELETE_LOG` and `PS_Z_CPP_DELETE_LOG` are written by the two D00
delete models but are missing from the header's `TARGET TABLE` line.
