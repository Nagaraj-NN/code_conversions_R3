-- ==========================================================================
-- Model      : PS_Z_CPP_D00_DEL
-- Mapping    : m_ps_z_cpp_d00_del
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 86-111 (INSERT + DELETE)
-- Target     : CRPDB01.EPMADM.PS_Z_CPP_D00, and PS_Z_CPP_DELETE_LOG
-- Load type  : table + INSERT and DELETE post-hooks
-- --------------------------------------------------------------------------
-- Every CPP change-log row inside the CPP_D00 window is written to the
-- delete log, and every PS_Z_CPP_D00 row whose key appears in that window is
-- deleted, so the changed rows can be reloaded by the load that follows.
--
-- Same shape as PS_Z_CI_D00_DEL: one row set read once by both hooks, in the
-- original order. The validated DELETE has no DISTINCT in its IN list and
-- none is added; IN is unaffected either way.
--
-- The workflow header also lists TRUNCATE TABLE PS_Z_CPP_D00 as PRE SQL, but
-- the workflow script never runs it, so it is not added here - truncating
-- first would also make this delete meaningless.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_CPP_D00_DEL_SRC',
    meta={"mapping_name": "m_ps_z_cpp_d00_del", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CPP_D00_DEL', target_object='CRPDB01.EPMADM.PS_Z_CPP_D00')
    ],
    post_hook=[
        "INSERT INTO {{ source('CRPDB01_EPMADM','PS_Z_CPP_DELETE_LOG') }}
     (Z_CPP_ID, REVISION_NUMBER, SEQ_NUM, Z_CPP_STATUS, LAST_MAINT_DTTM, LAST_UPDT_TS)
     SELECT Z_CPP_ID, REVISION_NUMBER, SEQ_NUM, Z_CPP_STATUS, LAST_MAINT_DTTM, LAST_UPDT_TS
     FROM {{ this }}",
        "DELETE FROM {{ source('CRPDB01_EPMADM','PS_Z_CPP_D00') }}
     WHERE (Z_CPP_ID, REVISION_NUMBER) IN (
         SELECT Z_CPP_ID, REVISION_NUMBER
         FROM {{ this }}
     )",
        log_model_end(this, 'TBD_PS_Z_CPP_D00_DEL', target_object='CRPDB01.EPMADM.PS_Z_CPP_D00')
    ]
) }}

SELECT
    PS_Z_CPP_CH_LOG_VW.Z_CPP_ID,
    PS_Z_CPP_CH_LOG_VW.REVISION_NUMBER,
    PS_Z_CPP_CH_LOG_VW.SEQ_NUM,
    PS_Z_CPP_CH_LOG_VW.Z_CPP_STATUS,
    PS_Z_CPP_CH_LOG_VW.LAST_MAINT_DTTM,
    CURRENT_TIMESTAMP() AS LAST_UPDT_TS
FROM {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL') }} PS_Z_JOB_CONTROL,
     {{ source('CI_PSFT_SOURCE','PS_Z_CPP_CH_LOG_VW') }} PS_Z_CPP_CH_LOG_VW
WHERE PS_Z_CPP_CH_LOG_VW.LAST_MAINT_DTTM >= PS_Z_JOB_CONTROL.LAST_RUN_FROM_DTTM
  AND PS_Z_CPP_CH_LOG_VW.LAST_MAINT_DTTM < PS_Z_JOB_CONTROL.LAST_RUN_TO_DTTM
  AND PS_Z_JOB_CONTROL.JOBID = 'CPP_D00'
