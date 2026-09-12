-- ==========================================================================
-- Model      : PS_Z_JOB_CONTROL_UPD_STATUS
-- Mapping    : m_ps_z_job_control_upd_status
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 126-132 (2 UPDATEs)
-- Target     : CRPDB01.EPMADM.PS_Z_JOB_CONTROL_CI
-- Load type  : table + UPDATE post-hooks
-- --------------------------------------------------------------------------
-- Closes the CPP_D00 and CI_EST_F00 windows by setting STATUS to 'C'. It is
-- the last job in the workflow: run earlier, it marks a window complete
-- while its deletes and loads are still to come.
--
-- The two UPDATEs are the validated statements unchanged, in their original
-- order. The model snapshots the two rows so RECORDS_PROCESSED counts them.
--
-- PS_Z_JOB_CONTROL_CI is this application's own copy of PeopleSoft's
-- PS_Z_JOB_CONTROL, which is replicated to bronze and cannot be updated.
-- on-run-start creates it from bronze and adds missing JOBIDs; see
-- macros/ci_ps_z_job_control.sql. The validated script names PS_Z_JOB_CONTROL.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_JOB_CONTROL_UPD_STATUS_SRC',
    meta={"mapping_name": "m_ps_z_job_control_upd_status", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_JOB_CONTROL_UPD_STATUS', target_object=target.database ~ '.EPMADM.PS_Z_JOB_CONTROL_CI')
    ],
    post_hook=[
        "UPDATE {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }}
     SET STATUS = 'C'
     WHERE JOBID = 'CPP_D00'",
        "UPDATE {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }}
     SET STATUS = 'C'
     WHERE JOBID = 'CI_EST_F00'",
        log_model_end(this, 'TBD_PS_Z_JOB_CONTROL_UPD_STATUS', target_object=target.database ~ '.EPMADM.PS_Z_JOB_CONTROL_CI')
    ]
) }}

SELECT
    PS_Z_JOB_CONTROL.JOBID,
    PS_Z_JOB_CONTROL.TABLE_NAME,
    PS_Z_JOB_CONTROL.LAST_RUN_FROM_DTTM,
    PS_Z_JOB_CONTROL.LAST_RUN_TO_DTTM,
    PS_Z_JOB_CONTROL.STATUS
FROM {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }} PS_Z_JOB_CONTROL
WHERE PS_Z_JOB_CONTROL.JOBID IN ('CPP_D00', 'CI_EST_F00')
