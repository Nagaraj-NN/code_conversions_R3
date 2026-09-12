-- ==========================================================================
-- Model      : PS_Z_CI_EST_F00_DEL
-- Mapping    : m_ps_z_ci_est_f00_del
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 113-124 (DELETE)
-- Target     : CRPDB01.EPMADM.PS_Z_CI_EST_F00
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- Deletes every PS_Z_CI_EST_F00 row whose CI key appears in the CI change log
-- inside the CI_EST_F00 window. Unlike the D00 deletes, nothing is written
-- to a delete log.
--
-- The model is the validated IN subquery, DISTINCT included, and the DELETE
-- keeps its IN form over the model, so a row with a NULL key part is not
-- deleted - as before. RECORDS_PROCESSED is the number of distinct changed
-- keys, not the number of fact rows removed: one key can match many rows.
--
-- PS_Z_JOB_CONTROL_CI is this application's own copy of PeopleSoft's
-- PS_Z_JOB_CONTROL, which is replicated to bronze and cannot be updated.
-- on-run-start creates it from bronze and adds missing JOBIDs; see
-- macros/ci_ps_z_job_control.sql. The validated script names PS_Z_JOB_CONTROL.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_CI_EST_F00_DEL_SRC',
    meta={"mapping_name": "m_ps_z_ci_est_f00_del", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CI_EST_F00_DEL', target_object=target.database ~ '.EPMADM.PS_Z_CI_EST_F00')
    ],
    post_hook=[
        "DELETE FROM {{ source('CRPDB01_EPMADM','PS_Z_CI_EST_F00') }}
     WHERE (BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER) IN (
         SELECT BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER
         FROM {{ this }}
     )",
        log_model_end(this, 'TBD_PS_Z_CI_EST_F00_DEL', target_object=target.database ~ '.EPMADM.PS_Z_CI_EST_F00')
    ]
) }}

SELECT DISTINCT
    PS_Z_CI_CHG_LOG_VW.BUSINESS_UNIT,
    PS_Z_CI_CHG_LOG_VW.PROJECT_ID,
    PS_Z_CI_CHG_LOG_VW.REVISION_NUMBER
FROM {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }} PS_Z_JOB_CONTROL,
     {{ source('CI_PSFT_SOURCE','PS_Z_CI_CHG_LOG_VW') }} PS_Z_CI_CHG_LOG_VW
WHERE PS_Z_CI_CHG_LOG_VW.LAST_MAINT_DTTM >= PS_Z_JOB_CONTROL.LAST_RUN_FROM_DTTM
  AND PS_Z_CI_CHG_LOG_VW.LAST_MAINT_DTTM < PS_Z_JOB_CONTROL.LAST_RUN_TO_DTTM
  AND PS_Z_JOB_CONTROL.JOBID = 'CI_EST_F00'
