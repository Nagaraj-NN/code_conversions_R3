-- ==========================================================================
-- Model      : PS_Z_CPP_D00
-- Mapping    : m_ps_z_cpp_d00_ins_upd
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Session    : s_m_ps_z_cpp_d00_ins_upd
-- Source SQL : ci/CI mappings/RESULT/s_m_ps_z_cpp_d00_ins_upd.sql, lines 21-82 (TRUNCATE + INSERT)
-- Target     : CRPDB01.EPMADM.PS_Z_CPP_D00
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- Full reload of the CPP detail dimension from PS_Z_CPP_DTL_VW. The session's
-- PRE SQL truncates the table and the load inserts every row, so the model
-- is the target and the truncate is a pre-hook, as for PS_Z_JTP_RELATE_CI.
-- This is the TRUNCATE the workflow header lists as PRE SQL; it also leaves
-- PS_Z_CPP_D00_DEL's DELETE with nothing to do, while its delete-log insert
-- still matters.
--
-- The script reads SELECT * from the view, so its columns can only be
-- checked against the view's DDL. The model outputs exactly the script's
-- INSERT columns, in order, and dbt inserts by name.
--
-- Converted from ci/CI mappings/RESULT/ - the later upload in ci/ has no
-- new version of this session. assert_psft_source stops compilation if the
-- view does not exist: its execution log reports PS_Z_CPP_DTL_VW missing,
-- and without the check the TRUNCATE would empty PS_Z_CPP_D00 before the
-- read failed.
-- ==========================================================================

{{ assert_psft_source(source('CI_PSFT_SOURCE', 'PS_Z_CPP_DTL_VW'), this, must_exist=true) }}

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_ps_z_cpp_d00_ins_upd", "workflow_name": "wkf_LOAD_CI_ATOMIC", "session_name": "s_m_ps_z_cpp_d00_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CPP_D00', target_object=target.database ~ '.EPMADM.PS_Z_CPP_D00'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_PS_Z_CPP_D00', target_object=target.database ~ '.EPMADM.PS_Z_CPP_D00')
    ]
) }}

SELECT
    SRC.Z_CPP_ID, SRC.REVISION_NUMBER, SRC.BUSINESS_UNIT, SRC.PROJECT_ID, SRC.Z_CI_REVISION, SRC.BUSINESS_UNIT_GL, SRC.DESCR, SRC.Z_CPP_TYPE, SRC.DESCR254, SRC.Z_CPP_STATUS, SRC.Z_APPROVER, SRC.Z_APPROVAL_DT, SRC.IN_SERVICE_DT, SRC.Z_CREATED_BY, SRC.Z_CREATED_BY_DTTM, SRC.Z_APPROVED_BY, SRC.Z_APPROVED_BY_DTTM, SRC.Z_REJECTED_BY, SRC.Z_REJECTED_BY_DTTM, SRC.HDR_LAST_MAINT_OPRID, SRC.HDR_LAST_MAINT_DTTM, SRC.REV_LAST_MAINT_OPRID, SRC.REV_LAST_MAINT_DTTM, SRC.CLOSE_STATUS, SRC.Z_COMP_INTENT_TYPE, SRC.Z_LOB, SRC.COMPLETION_DATE, SRC.IN_SERVICE_DT_TO, SRC.START_DATE, SRC.Z_LEAD_ORG, SRC.Z_OUTAGE, SRC.Z_OUTAGE_INCREASE, SRC.Z_OUTAGE_DAYS, SRC.Z_APPY_PROB_CALC, SRC.Z_DESIGN_LIFE, SRC.OPRID_ENTERED_BY, SRC.OPRID_OWNER, SRC.YEAROFDATE, SRC.APPROVAL_DATE, SRC.APPROVAL_DT, SRC.DESCR254_MIXED, SRC.DESCR50_MIXED, SRC.PRIORITY, SRC.LAST_UPDT_TS, SRC.EMPLID2, SRC.Z_CI_MNDTRY_RSN, SRC.CSTDN_MGR_EMPLID, SRC.Z_PHASE_IR_AMT, SRC.PL_COL_NB
FROM (
    SELECT
        SQ.Z_CPP_ID AS Z_CPP_ID,
        SQ.REVISION_NUMBER AS REVISION_NUMBER,
        SQ.BUSINESS_UNIT AS BUSINESS_UNIT,
        SQ.PROJECT_ID AS PROJECT_ID,
        SQ.Z_CI_REVISION AS Z_CI_REVISION,
        SQ.BUSINESS_UNIT_GL AS BUSINESS_UNIT_GL,
        SQ.DESCR AS DESCR,
        SQ.Z_CPP_TYPE AS Z_CPP_TYPE,
        SQ.DESCR254 AS DESCR254,
        SQ.Z_CPP_STATUS AS Z_CPP_STATUS,
        SQ.Z_APPROVER AS Z_APPROVER,
        SQ.Z_APPROVAL_DT AS Z_APPROVAL_DT,
        SQ.IN_SERVICE_DT AS IN_SERVICE_DT,
        SQ.Z_CREATED_BY AS Z_CREATED_BY,
        SQ.Z_CREATED_BY_DTTM AS Z_CREATED_BY_DTTM,
        SQ.Z_APPROVED_BY AS Z_APPROVED_BY,
        SQ.Z_APPROVED_BY_DTTM AS Z_APPROVED_BY_DTTM,
        SQ.Z_REJECTED_BY AS Z_REJECTED_BY,
        SQ.Z_REJECTED_BY_DTTM AS Z_REJECTED_BY_DTTM,
        SQ.HDR_LAST_MAINT_OPRID AS HDR_LAST_MAINT_OPRID,
        SQ.HDR_LAST_MAINT_DTTM AS HDR_LAST_MAINT_DTTM,
        SQ.REV_LAST_MAINT_OPRID AS REV_LAST_MAINT_OPRID,
        SQ.REV_LAST_MAINT_DTTM AS REV_LAST_MAINT_DTTM,
        SQ.CLOSE_STATUS AS CLOSE_STATUS,
        SQ.Z_COMP_INTENT_TYPE AS Z_COMP_INTENT_TYPE,
        SQ.Z_LOB AS Z_LOB,
        SQ.COMPLETION_DATE AS COMPLETION_DATE,
        SQ.IN_SERVICE_DT_TO AS IN_SERVICE_DT_TO,
        SQ.START_DATE AS START_DATE,
        SQ.Z_LEAD_ORG AS Z_LEAD_ORG,
        SQ.Z_OUTAGE AS Z_OUTAGE,
        SQ.Z_OUTAGE_INCREASE AS Z_OUTAGE_INCREASE,
        SQ.Z_OUTAGE_DAYS AS Z_OUTAGE_DAYS,
        SQ.Z_APPY_PROB_CALC AS Z_APPY_PROB_CALC,
        SQ.Z_DESIGN_LIFE AS Z_DESIGN_LIFE,
        SQ.OPRID_ENTERED_BY AS OPRID_ENTERED_BY,
        SQ.OPRID_OWNER AS OPRID_OWNER,
        SQ.YEAROFDATE AS YEAROFDATE,
        SQ.APPROVAL_DATE AS APPROVAL_DATE,
        SQ.APPROVAL_DT AS APPROVAL_DT,
        SQ.DESCR254_MIXED AS DESCR254_MIXED,
        SQ.DESCR50_MIXED AS DESCR50_MIXED,
        SQ.PRIORITY AS PRIORITY,
        SQ.LAST_UPDT_TS AS LAST_UPDT_TS,
        SQ.EMPLID2 AS EMPLID2,
        SQ.Z_CI_MNDTRY_RSN AS Z_CI_MNDTRY_RSN,
        SQ.CSTDN_MGR_EMPLID AS CSTDN_MGR_EMPLID,
        SQ.Z_PHASE_IR_AMT AS Z_PHASE_IR_AMT,
        SQ.PL_COL_NB AS PL_COL_NB
    FROM (
        SELECT * FROM {{ source('CI_PSFT_SOURCE','PS_Z_CPP_DTL_VW') }}
    ) SQ
) SRC
