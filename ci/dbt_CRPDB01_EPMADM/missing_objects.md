# Objects named in the CI script headers

Built from the `SOURCE Tables` / `TARGET TABLE` header lines and the error block
of every CI script: the workflow and session scripts in `ci/CI mappings/RESULT/`
and the session scripts uploaded to `ci/`. "Missing" means the script's own
error block reports `does not exist or not authorized` in
`CRPDB01_DEV_SANDBOX.EPMADM`.

## Reported missing (7)

| Object | Reported by | Declared in the dbt project |
|---|---|---|
| `PS_Z_CI_DTL_VW` | `s_m_ps_z_ci_d00_ins_upd.sql` | `CI_PSFT_SOURCE` |
| `PS_Z_CI_REV_DTLVW` | `wkf_LOAD_CI_ATOMIC_AUDIT.sql` | `CI_PSFT_SOURCE` |
| `PS_Z_CPP_CH_LOG_VW` | `wkf_LOAD_CI_ATOMIC.sql` | `CI_PSFT_SOURCE` |
| `PS_Z_CPP_DTL_VW` | `s_m_ps_z_cpp_d00_ins_upd.sql` | `CI_PSFT_SOURCE` |
| `PS_Z_JOB_CONTROL` | `wkf_LOAD_CI_ATOMIC.sql` | `CRPDB01_EPMADM` |
| `PS_Z_PDS_CI_VW` | `s_m_ps_z_pds_ci_dtl_ins.sql` | `CI_PSFT_SOURCE` |
| `PS_Z_PDS_CPP_VW` | `s_m_ps_z_pds_cpp_dtl_ins.sql` | `CI_PSFT_SOURCE` |

## Named in a header but never reported missing (15)

Either present in EPMADM, or never reached because the script stopped at an
earlier error.

| Object | Role in the headers | Declared in the dbt project |
|---|---|---|
| `PS_PERSONAL_D00` | source | `CRPDB01_EPMADM` |
| `PS_Z_CI_CHG_LOG_VW` | source | `CI_PSFT_SOURCE` |
| `PS_Z_CI_D00` | source + target | `CRPDB01_EPMADM` |
| `PS_Z_CI_EST_F00` | source + target | `CRPDB01_EPMADM` |
| `PS_Z_CI_GEN_STAT` | source + target | `CRPDB01_EPMADM`, `CI_PSFT_SOURCE` |
| `PS_Z_CPP_D00` | target | `CRPDB01_EPMADM` |
| `PS_Z_CPP_GEN_STAT` | source + target | `CRPDB01_EPMADM`, `CI_PSFT_SOURCE` |
| `PS_Z_CPP_IR_TBL` | source | **not declared** |
| `PS_Z_EPM_AUDIT` | source + target | `CRPDB01_EPMADM` |
| `PS_Z_IR_DETAIL_TBL` | source | `CI_PSFT_SOURCE` |
| `PS_Z_JTP_RELATE_CI` | source + target | `CI_PSFT_SOURCE` |
| `PS_Z_PDS_CI_DTL` | target | `CRPDB01_EPMADM` |
| `PS_Z_PDS_CPP_DTL` | target | `CRPDB01_EPMADM` |
| `PS_Z_PMRG_ANLS_TBL` | source + target | `CRPDB01_EPMADM`, `CI_PSFT_SOURCE` |
| `PS_Z_PMRG_CPP_TBL` | source + target | `CRPDB01_EPMADM`, `CI_PSFT_SOURCE` |

## Per script

| Script | Converted to | Targets | Sources | Missing |
|---|---|---|---|---|
| `ci/CI mappings/RESULT/s_m_ps_z_ci_d00_ins_upd.sql` | superseded - not converted | PS_Z_CI_D00 | PS_Z_CI_DTL_VW | **PS_Z_CI_DTL_VW** |
| `ci/CI mappings/RESULT/s_m_ps_z_ci_gen_stat_ins.sql` | superseded - not converted | PS_Z_CI_GEN_STAT | PS_Z_CI_GEN_STAT | none reported |
| `ci/CI mappings/RESULT/s_m_ps_z_cpp_d00_ins_upd.sql` | PS_Z_CPP_D00 | PS_Z_CPP_D00 | PS_Z_CPP_DTL_VW | **PS_Z_CPP_DTL_VW** |
| `ci/CI mappings/RESULT/s_m_ps_z_cpp_gen_stat_ins.sql` | superseded - not converted | PS_Z_CPP_GEN_STAT | PS_Z_CPP_GEN_STAT | none reported |
| `ci/CI mappings/RESULT/s_m_ps_z_pds_ci_dtl_ins.sql` | superseded - not converted | PS_Z_PDS_CI_DTL | PS_Z_PDS_CI_VW | **PS_Z_PDS_CI_VW** |
| `ci/CI mappings/RESULT/s_m_ps_z_pds_cpp_dtl_ins.sql` | superseded - not converted | PS_Z_PDS_CPP_DTL | PS_Z_PDS_CPP_VW | **PS_Z_PDS_CPP_VW** |
| `ci/CI mappings/RESULT/s_m_ps_z_pmrg_anls_tbl_ins.sql` | superseded - not converted | PS_Z_PMRG_ANLS_TBL | PS_Z_PMRG_ANLS_TBL | none reported |
| `ci/CI mappings/RESULT/s_m_ps_z_pmrg_cpp_tbl_ins.sql` | superseded - not converted | PS_Z_PMRG_CPP_TBL | PS_Z_PMRG_CPP_TBL | none reported |
| `ci/CI mappings/RESULT/wkf_LOAD_CI_ATOMIC.sql` | 6 models (see inventory.md) | PS_Z_JOB_CONTROL, PS_Z_CI_D00, PS_Z_CPP_D00, PS_Z_CI_EST_F00, PS_Z_PDS_CPP_DTL, PS_Z_PDS_CI_DTL, PS_Z_PMRG_ANLS_TBL, PS_Z_PMRG_CPP_TBL, PS_Z_CPP_GEN_STAT, PS_Z_CI_GEN_STAT, PS_Z_JTP_RELATE_CI | PS_Z_JOB_CONTROL, PS_Z_CI_CHG_LOG_VW, PS_Z_CPP_CH_LOG_VW, PS_Z_CI_DTL_VW, PS_Z_CPP_DTL_VW, PS_Z_CI_REV_DTLVW, PS_Z_PDS_CPP_VW, PS_Z_PDS_CI_VW, PS_Z_PMRG_ANLS_TBL, PS_Z_PMRG_CPP_TBL, PS_Z_CPP_GEN_STAT, PS_Z_CI_GEN_STAT, PS_Z_JTP_RELATE_CI, PS_PERSONAL_D00, PS_Z_IR_DETAIL_TBL, PS_Z_CPP_IR_TBL | **PS_Z_CPP_CH_LOG_VW**, **PS_Z_JOB_CONTROL** |
| `ci/CI mappings/RESULT/wkf_LOAD_CI_ATOMIC_AUDIT.sql` | PS_Z_CI_REV_DTLVW_AUDIT, PS_Z_CI_EST_F00_ATOMIC_AUDIT | PS_Z_EPM_AUDIT | PS_Z_CI_REV_DTLVW, PS_Z_CI_EST_F00, PS_Z_EPM_AUDIT | **PS_Z_CI_REV_DTLVW** |
| `ci/s_m_ps_z_ci_d00_ins_upd.sql` | superseded - not converted | PS_Z_CI_D00 | PS_Z_CI_DTL_VW, PS_Z_IR_DETAIL_TBL, PS_Z_CI_D00 | **PS_Z_CI_DTL_VW** |
| `ci/s_m_ps_z_ci_d00_ins_upd_apple_to_apple.sql` | PS_Z_CI_D00_INS_UPD | PS_Z_CI_D00 | PS_Z_CI_DTL_VW, PS_Z_IR_DETAIL_TBL, PS_Z_CI_D00 | none reported |
| `ci/s_m_ps_z_ci_gen_stat_ins.sql` | PS_Z_CI_GEN_STAT_INS | PS_Z_CI_GEN_STAT | PS_Z_CI_GEN_STAT, PS_PERSONAL_D00 | none reported |
| `ci/s_m_ps_z_cpp_gen_stat_ins.sql` | PS_Z_CPP_GEN_STAT_INS | PS_Z_CPP_GEN_STAT | PS_Z_CPP_GEN_STAT, PS_PERSONAL_D00 | none reported |
| `ci/s_m_ps_z_pds_ci_dtl_ins.sql` | PS_Z_PDS_CI_DTL_INS | PS_Z_PDS_CI_DTL | PS_Z_PDS_CI_VW | **PS_Z_PDS_CI_VW** |
| `ci/s_m_ps_z_pds_cpp_dtl_ins.sql` | PS_Z_PDS_CPP_DTL_INS | PS_Z_PDS_CPP_DTL | PS_Z_PDS_CPP_VW | **PS_Z_PDS_CPP_VW** |
| `ci/s_m_ps_z_pmrg_anls_tbl_ins.sql` | PS_Z_CI_PMRG_ANLS_TBL_INS | PS_Z_PMRG_ANLS_TBL | PS_Z_PMRG_ANLS_TBL | none reported |
| `ci/s_m_ps_z_pmrg_cpp_tbl_ins.sql` | PS_Z_PMRG_CPP_TBL_INS | PS_Z_PMRG_CPP_TBL | PS_Z_PMRG_CPP_TBL | none reported |
