-- ==========================================================================
-- Model      : FEL_COAL_CNSMN_FDR
-- Mapping    : m_FEL_COAL_CNSMN_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COAL_CNSMN_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COAL_CNSMN_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the target lookup;
-- the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COAL_CNSMN_FDR_SRC',
    meta={"mapping_name": "m_FEL_COAL_CNSMN_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COAL_CNSMN_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COAL_CNSMN_FDR', target_object='GENDB01.FELADM.FEL_COAL_CNSMN_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }} TGT
     SET
         UNIT_ID              = SRC.UNIT_ID,
         INVTRY_LOC_ID        = SRC.INVTRY_LOC_ID,
         CNSMN_DATE           = SRC.CNSMN_DATE,
         OWNING_FACILITY_ID   = SRC.OWNING_FACILITY_ID,
         STATUS_TX            = SRC.STATUS_TX,
         UNSMPLD_RSN_TX       = SRC.UNSMPLD_RSN_TX,
         ANLYS_CTRL_NB        = SRC.ANLYS_CTRL_NB,
         ANLYS_TRCKG_NB       = SRC.ANLYS_TRCKG_NB,
         ASH_QLTY_PCT         = SRC.ASH_QLTY_PCT,
         SULFUR_QLTY_PCT      = SRC.SULFUR_QLTY_PCT,
         MOISTURE_QLTY_PCT    = SRC.MOISTURE_QLTY_PCT,
         BTU_PER_LB_MSR       = SRC.BTU_PER_LB_MSR,
         SO2_LBS_PER_MBTU_MSR = SRC.SO2_LBS_PER_MBTU_MSR,
         BURND_TONS_QY        = SRC.BURND_TONS_QY,
         SMPLD_TONS_QY        = SRC.SMPLD_TONS_QY,
         CNSMN_CST_AT         = SRC.CNSMN_CST_AT,
         LAST_UPDT_TS         = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.RECLAIM_ID = SRC.RECLAIM_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }} (
         RECLAIM_ID,
         UNIT_ID,
         INVTRY_LOC_ID,
         CNSMN_DATE,
         OWNING_FACILITY_ID,
         STATUS_TX,
         UNSMPLD_RSN_TX,
         ANLYS_CTRL_NB,
         ANLYS_TRCKG_NB,
         ASH_QLTY_PCT,
         SULFUR_QLTY_PCT,
         MOISTURE_QLTY_PCT,
         BTU_PER_LB_MSR,
         SO2_LBS_PER_MBTU_MSR,
         BURND_TONS_QY,
         SMPLD_TONS_QY,
         CNSMN_CST_AT,
         LAST_UPDT_TS
     )
     SELECT
         SRC.RECLAIM_ID,
         SRC.UNIT_ID,
         SRC.INVTRY_LOC_ID,
         SRC.CNSMN_DATE,
         SRC.OWNING_FACILITY_ID,
         SRC.STATUS_TX,
         SRC.UNSMPLD_RSN_TX,
         SRC.ANLYS_CTRL_NB,
         SRC.ANLYS_TRCKG_NB,
         SRC.ASH_QLTY_PCT,
         SRC.SULFUR_QLTY_PCT,
         SRC.MOISTURE_QLTY_PCT,
         SRC.BTU_PER_LB_MSR,
         SRC.SO2_LBS_PER_MBTU_MSR,
         SRC.BURND_TONS_QY,
         SRC.SMPLD_TONS_QY,
         SRC.CNSMN_CST_AT,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }} LKP
         WHERE LKP.RECLAIM_ID = SRC.RECLAIM_ID
     )",
        log_model_end(this, 'TBD_FEL_COAL_CNSMN_FDR', target_object='GENDB01.FELADM.FEL_COAL_CNSMN_FDR')
    ]
) }}

SELECT
    CAST(DQ.CONSUMP_ID AS NUMBER(10,0))                                                   AS RECLAIM_ID,
    CAST(IFF(DQ.UNIT_ID IS NOT NULL, DQ.UNIT_ID, 0) AS NUMBER(10,0))                      AS UNIT_ID,
    CAST(IFF(DQ.INV_LOC_ID IS NOT NULL, DQ.INV_LOC_ID, 0) AS NUMBER(10,0))                AS INVTRY_LOC_ID,
    CAST(IFF(DQ.CALENDAR_DATE IS NOT NULL, DQ.CALENDAR_DATE, DATE '1900-01-01') AS DATE)  AS CNSMN_DATE,
    CAST(IFF(DQ.FCLTY_ID IS NOT NULL, DQ.FCLTY_ID, 0) AS NUMBER(10,0))                    AS OWNING_FACILITY_ID,
    LEFT(IFF(DQ.STATUS IS NOT NULL, DQ.STATUS, ' '), 6)                                   AS STATUS_TX,
    LEFT(IFF(DQ.UNSMPLE_RSN_CDE IS NOT NULL, DQ.UNSMPLE_RSN_CDE, ' '), 50)                AS UNSMPLD_RSN_TX,
    LEFT(IFF(DQ.ACN IS NOT NULL, DQ.ACN, ' '), 8)                                         AS ANLYS_CTRL_NB,
    LEFT(IFF(DQ.ATN IS NOT NULL, DQ.ATN, ' '), 15)                                        AS ANLYS_TRCKG_NB,
    CAST(IFF(DQ.ASH_QLTY IS NOT NULL, DQ.ASH_QLTY, 0) AS NUMBER(12,3))                    AS ASH_QLTY_PCT,
    CAST(IFF(DQ.SULFUR_QLTY IS NOT NULL, DQ.SULFUR_QLTY, 0) AS NUMBER(12,3))              AS SULFUR_QLTY_PCT,
    CAST(IFF(DQ.MOISTURE_QLTY IS NOT NULL, DQ.MOISTURE_QLTY, 0) AS NUMBER(12,3))          AS MOISTURE_QLTY_PCT,
    CAST(IFF(DQ.HEAT_QLTY IS NOT NULL, DQ.HEAT_QLTY, 0) AS NUMBER(12,3))                  AS BTU_PER_LB_MSR,
    CAST(ROUND(IFF(DQ.HEAT_QLTY IS NULL OR DQ.HEAT_QLTY = 0, 0,
                       (20000 * DQ.SULFUR_QLTY) / DQ.HEAT_QLTY), 3) AS NUMBER(12,3)) AS SO2_LBS_PER_MBTU_MSR,
    CAST(IFF(DQ.COSUMED_TONS IS NOT NULL, DQ.COSUMED_TONS, 0) AS NUMBER(12,3))            AS BURND_TONS_QY,
    CAST(IFF(DQ.SAMPLED_TONS IS NOT NULL, DQ.SAMPLED_TONS, 0) AS NUMBER(12,3))            AS SMPLD_TONS_QY,
    CAST(IFF(DQ.CONSUMED_AMT IS NOT NULL, DQ.CONSUMED_AMT, 0) AS NUMBER(12,3))            AS CNSMN_CST_AT,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                            AS LAST_UPDT_TS
FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))          = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)          END AS STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ACN)))             = 0 THEN ' ' ELSE RTRIM(SQ.ACN)             END AS ACN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ATN)))             = 0 THEN ' ' ELSE RTRIM(SQ.ATN)             END AS ATN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLE_RSN_CDE))) = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLE_RSN_CDE) END AS UNSMPLE_RSN_CDE,
            SQ.UNIT_ID,
            SQ.CONSUMP_ID,
            SQ.FCLTY_ID,
            SQ.INV_LOC_ID,
            SQ.CALENDAR_DATE,
            SQ.CONSUMED_TONS AS COSUMED_TONS,
            SQ.ASH_QLTY,
            SQ.HEAT_QLTY,
            SQ.MOISTURE_QLTY,
            SQ.SULFUR_QLTY,
            SQ.SAMPLED_TONS,
            SQ.CONSUMED_AMT
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_CONSUMPTION_VW_TEST') }} SQ  --USED FOR TESTING
        WHERE SQ.MOD_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
