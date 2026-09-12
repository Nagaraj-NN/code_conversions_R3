-- ==========================================================================
-- Model      : PS_Z_CI_D00_DEL
-- Mapping    : m_ps_z_ci_d00_del
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 57-84 (INSERT + DELETE)
-- Target     : CRPDB01.EPMADM.PS_Z_CI_D00, and PS_Z_CI_DELETE_LOG
-- Load type  : table + INSERT and DELETE post-hooks
-- --------------------------------------------------------------------------
-- Every CI change-log row inside the CI_D00 window is written to the delete
-- log, and every PS_Z_CI_D00 row whose key appears in that window is deleted,
-- so the changed rows can be reloaded by the load that follows.
--
-- Both validated statements read the same join with the same predicate: the
-- INSERT takes every column, the DELETE the distinct keys. The model is that
-- row set, read once, and both hooks read it in the original order. The
-- DELETE keeps its IN form over the model's keys, so its NULL behaviour is
-- the original's: a row with a NULL key part is not deleted.
--
-- LAST_UPDT_TS is taken when the model materialises rather than when the
-- INSERT runs - one value for the batch, seconds earlier. RECORDS_PROCESSED
-- is the change-log rows read, which is the rows written to the delete log.
--
-- PS_Z_JOB_CONTROL_CI is this application's own copy of PeopleSoft's
-- PS_Z_JOB_CONTROL, which is replicated to bronze and cannot be updated.
-- on-run-start creates it from bronze and adds missing JOBIDs; see
-- macros/ci_ps_z_job_control.sql. The validated script names PS_Z_JOB_CONTROL.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_CI_D00_DEL_SRC',
    meta={"mapping_name": "m_ps_z_ci_d00_del", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CI_D00_DEL', target_object=target.database ~ '.EPMADM.PS_Z_CI_D00')
    ],
    post_hook=[
        "INSERT INTO {{ source('CRPDB01_EPMADM','PS_Z_CI_DELETE_LOG') }}
     (BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER, SEQ_NUM, Z_CI_STATUS, LAST_MAINT_DTTM, LAST_UPDT_TS)
     SELECT BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER, SEQ_NUM, Z_CI_STATUS, LAST_MAINT_DTTM, LAST_UPDT_TS
     FROM {{ this }}",
        "DELETE FROM {{ source('CRPDB01_EPMADM','PS_Z_CI_D00') }}
     WHERE (BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER) IN (
         SELECT DISTINCT BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER
         FROM {{ this }}
     )",
        log_model_end(this, 'TBD_PS_Z_CI_D00_DEL', target_object=target.database ~ '.EPMADM.PS_Z_CI_D00')
    ]
) }}

SELECT
    PS_Z_CI_CHG_LOG_VW.BUSINESS_UNIT,
    PS_Z_CI_CHG_LOG_VW.PROJECT_ID,
    PS_Z_CI_CHG_LOG_VW.REVISION_NUMBER,
    PS_Z_CI_CHG_LOG_VW.SEQ_NUM,
    PS_Z_CI_CHG_LOG_VW.Z_CI_STATUS,
    PS_Z_CI_CHG_LOG_VW.LAST_MAINT_DTTM,
    CURRENT_TIMESTAMP() AS LAST_UPDT_TS
FROM {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }} PS_Z_JOB_CONTROL,
     {{ source('CI_PSFT_SOURCE','PS_Z_CI_CHG_LOG_VW') }} PS_Z_CI_CHG_LOG_VW
WHERE PS_Z_CI_CHG_LOG_VW.LAST_MAINT_DTTM >= PS_Z_JOB_CONTROL.LAST_RUN_FROM_DTTM
  AND PS_Z_CI_CHG_LOG_VW.LAST_MAINT_DTTM < PS_Z_JOB_CONTROL.LAST_RUN_TO_DTTM
  AND PS_Z_JOB_CONTROL.JOBID = 'CI_D00'
