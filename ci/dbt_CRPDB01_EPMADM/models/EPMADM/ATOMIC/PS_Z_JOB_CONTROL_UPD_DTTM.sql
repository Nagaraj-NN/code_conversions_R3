-- ==========================================================================
-- Model      : PS_Z_JOB_CONTROL_UPD_DTTM
-- Mapping    : m_ps_z_job_control_upd_dttm
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 25-37 (2 UPDATEs)
-- Target     : CRPDB01.EPMADM.PS_Z_JOB_CONTROL_CI
-- Load type  : table + UPDATE post-hooks
-- --------------------------------------------------------------------------
-- Opens the load window for CI_EST_F00 and CPP_D00: the old TO becomes the
-- new FROM, TO moves to now, and STATUS goes to 'R'. The deletes that follow
-- read their window from these rows, so this job runs first in the workflow
-- and PS_Z_JOB_CONTROL_UPD_STATUS runs last.
--
-- The two UPDATEs are the validated statements unchanged, including the
-- no-op TABLE_NAME = TABLE_NAME carried from the update strategy. They are
-- self-contained and do not read this model. The model snapshots the two
-- job-control rows before they move, so RECORDS_PROCESSED counts them and
-- the _SRC table keeps the previous window.
--
-- CI_D00 is not opened here, although PS_Z_CI_D00_DEL reads the CI_D00
-- window: no statement in the workflow moves it. See the README.
--
-- PS_Z_JOB_CONTROL_CI is this application's own copy of PeopleSoft's
-- PS_Z_JOB_CONTROL, which is replicated to bronze and cannot be updated.
-- on-run-start creates it from bronze and adds missing JOBIDs; see
-- macros/ci_ps_z_job_control.sql. The validated script names PS_Z_JOB_CONTROL.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_JOB_CONTROL_UPD_DTTM_SRC',
    meta={"mapping_name": "m_ps_z_job_control_upd_dttm", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_JOB_CONTROL_UPD_DTTM', target_object='CRPDB01.EPMADM.PS_Z_JOB_CONTROL_CI')
    ],
    post_hook=[
        "UPDATE {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }}
     SET TABLE_NAME = TABLE_NAME,
         LAST_RUN_FROM_DTTM = LAST_RUN_TO_DTTM,
         LAST_RUN_TO_DTTM = CURRENT_TIMESTAMP(),
         STATUS = 'R'
     WHERE JOBID = 'CI_EST_F00'",
        "UPDATE {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }}
     SET TABLE_NAME = TABLE_NAME,
         LAST_RUN_FROM_DTTM = LAST_RUN_TO_DTTM,
         LAST_RUN_TO_DTTM = CURRENT_TIMESTAMP(),
         STATUS = 'R'
     WHERE JOBID = 'CPP_D00'",
        log_model_end(this, 'TBD_PS_Z_JOB_CONTROL_UPD_DTTM', target_object='CRPDB01.EPMADM.PS_Z_JOB_CONTROL_CI')
    ]
) }}

SELECT
    PS_Z_JOB_CONTROL.JOBID,
    PS_Z_JOB_CONTROL.TABLE_NAME,
    PS_Z_JOB_CONTROL.LAST_RUN_FROM_DTTM,
    PS_Z_JOB_CONTROL.LAST_RUN_TO_DTTM,
    PS_Z_JOB_CONTROL.STATUS
FROM {{ source('CRPDB01_EPMADM','PS_Z_JOB_CONTROL_CI') }} PS_Z_JOB_CONTROL
WHERE PS_Z_JOB_CONTROL.JOBID IN ('CI_EST_F00', 'CPP_D00')
