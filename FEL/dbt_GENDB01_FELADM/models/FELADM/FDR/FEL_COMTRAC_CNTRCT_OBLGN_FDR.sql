-- ==========================================================================
-- Model      : FEL_COMTRAC_CNTRCT_OBLGN_FDR
-- Mapping    : m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + CONDITIONAL UPDATE, data driven. RTR_NEW_EXIST updates only
-- when the key exists AND the obligation quantity actually changed. An
-- existing key with an unchanged quantity is written nowhere.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
--
-- The lookup the UPDATE branch joined with an INNER JOIN is a LEFT
-- JOIN here so the INSERT branch keeps its rows. That lookup is cut
-- to one row per key by its QUALIFY, and the UPDATE post-hook still
-- filters on the lookup column, so a row that finds no match cannot
-- be updated. Row counts and results are unchanged.
--
-- Carried for the UPDATE branch only: LKP_CNTRCTD_OBLGN_QY
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_CNTRCT_OBLGN_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_CNTRCT_OBLGN_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} TGT
     SET
         CONTRACT_ID      = SRC.CONTRACT_ID,
         CNTRCTD_OBLGN_QY = SRC.CNTRCTD_OBLGN_QY,
         LAST_UPDT_TS     = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE SRC.LKP_CNTRCTD_OBLGN_QY <> SRC.CNTRCTD_OBLGN_QY
       AND TGT.CNTRCT_DTL_ID       = SRC.CNTRCT_DTL_ID
       AND TGT.FACILITY_ID         = SRC.FACILITY_ID
       AND TGT.CNTRCT_DTL_OPRTG_DT = SRC.CNTRCT_DTL_OPRTG_DT",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} (
         CNTRCT_DTL_ID,
         FACILITY_ID,
         CNTRCT_DTL_OPRTG_DT,
         CONTRACT_ID,
         CNTRCTD_OBLGN_QY,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CNTRCT_DTL_ID,
         SRC.FACILITY_ID,
         CAST(SRC.CNTRCT_DTL_OPRTG_DT AS DATE),
         SRC.CONTRACT_ID,
         SRC.CNTRCTD_OBLGN_QY,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} FDR
         WHERE FDR.CNTRCT_DTL_ID       = SRC.CNTRCT_DTL_ID
           AND TRIM(FDR.FACILITY_ID)   = SRC.FACILITY_ID
           AND FDR.CNTRCT_DTL_OPRTG_DT = SRC.CNTRCT_DTL_OPRTG_DT
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_CNTRCT_OBLGN_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR')
    ]
) }}

SELECT
    CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                        AS CNTRCT_DTL_ID,
    LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(10,0)) AS VARCHAR), 3)  AS FACILITY_ID,
    LEFT(DQ.CNTRCT_ID, 25)                                       AS CONTRACT_ID,
    DQ.CONTRCTDTL_OB_DT                                          AS CNTRCT_DTL_OPRTG_DT,
    CAST(DQ.CONTRCTDTL_OB_TONS AS NUMBER(14,5))                  AS CNTRCTD_OBLGN_QY,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                   AS LAST_UPDT_TS,
    LKP.CNTRCTD_OBLGN_QY                                         AS LKP_CNTRCTD_OBLGN_QY
FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID) END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            SQ.FCLTY_ID,
            SQ.CONTRCTDTL_OB_DT,
            SQ.CONTRCTDTL_OB_TONS
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_CONTRACT_OBLIGATIONS_VW_TEST') }} SQ  --USED FOR TESTING
        WHERE SQ.MODDATETIME >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MODDATETIME <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT
            FDR.CNTRCTD_OBLGN_QY    AS CNTRCTD_OBLGN_QY,
            FDR.CNTRCT_DTL_ID       AS CNTRCT_DTL_ID,
            TRIM(FDR.FACILITY_ID)   AS FACILITY_ID,
            FDR.CNTRCT_DTL_OPRTG_DT AS CNTRCT_DTL_OPRTG_DT
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FDR.CNTRCT_DTL_ID, TRIM(FDR.FACILITY_ID), FDR.CNTRCT_DTL_OPRTG_DT
                                   ORDER BY FDR.CNTRCT_DTL_ID, TRIM(FDR.FACILITY_ID), FDR.CNTRCT_DTL_OPRTG_DT, FDR.CNTRCTD_OBLGN_QY) = 1
    ) LKP
      ON LKP.CNTRCT_DTL_ID       = CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))
     AND LKP.FACILITY_ID         = LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(10,0)) AS VARCHAR), 3)
     AND LKP.CNTRCT_DTL_OPRTG_DT = DQ.CONTRCTDTL_OB_DT
