-- ==========================================================================
-- Model      : FEL_COMTRAC_CONTRACT_FDR
-- Mapping    : m_FEL_COMTRAC_CONTRACT_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_CONTRACT_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_CONTRACT_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
-- lookup; the unconnected DEFAULT1 group is discarded.
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
-- Carried for the UPDATE branch only: LKP_CONTRACT_ID
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_CONTRACT_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CONTRACT_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_CONTRACT_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_CONTRACT_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CONTRACT_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_CONTRACT_FDR') }} TGT
     SET
         CNTRCT_EFCTV_DT     = SRC.CNTRCT_EFCTV_DT,
         CNTRCT_EXPR_DT      = SRC.CNTRCT_EXPR_DT,
         PARNT_CNTRCT_NM     = SRC.PARNT_CNTRCT_NM,
         CONTRACT_NM         = SRC.CONTRACT_NM,
         CNTRCT_TYPE_NM      = SRC.CNTRCT_TYPE_NM,
         CURR_CNTRCT_VNDR_ID = SRC.CURR_CNTRCT_VNDR_ID,
         CURR_BYR_ID         = SRC.CURR_BYR_ID,
         STATUS_TX           = SRC.STATUS_TX,
         LAST_UPDT_TS        = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.CONTRACT_ID = SRC.LKP_CONTRACT_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_CONTRACT_FDR') }} (
         CONTRACT_ID,
         CNTRCT_EFCTV_DT,
         CNTRCT_EXPR_DT,
         PARNT_CNTRCT_NM,
         CONTRACT_NM,
         CNTRCT_TYPE_NM,
         CURR_CNTRCT_VNDR_ID,
         CURR_BYR_ID,
         STATUS_TX,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CONTRACT_ID,
         SRC.CNTRCT_EFCTV_DT,
         SRC.CNTRCT_EXPR_DT,
         SRC.PARNT_CNTRCT_NM,
         SRC.CONTRACT_NM,
         SRC.CNTRCT_TYPE_NM,
         SRC.CURR_CNTRCT_VNDR_ID,
         SRC.CURR_BYR_ID,
         SRC.STATUS_TX,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CONTRACT_FDR') }} F
         WHERE UPPER(TRIM(F.CONTRACT_ID)) = SRC.IN_CONTRACT_ID
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_CONTRACT_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CONTRACT_FDR')
    ]
) }}

SELECT
    DQ.CNTRCT_ID                                                            AS CONTRACT_ID,
    UPPER(DQ.CNTRCT_ID)                                                     AS IN_CONTRACT_ID,
    CAST(IFF(DQ.EFF_DT IS NOT NULL, DQ.EFF_DT, DATE '2099-12-30') AS DATE)  AS CNTRCT_EFCTV_DT,
    CAST(IFF(DQ.EXP_DT IS NOT NULL, DQ.EXP_DT, DATE '2099-12-30') AS DATE)  AS CNTRCT_EXPR_DT,
    IFF(DQ.P_CNTRCT IS NOT NULL, DQ.P_CNTRCT, 'UNKNOWN')                    AS PARNT_CNTRCT_NM,
    IFF(DQ.CNTRCT IS NOT NULL, DQ.CNTRCT, 'UNKNOWN')                        AS CONTRACT_NM,
    IFF(DQ.CNTRCT_TYP IS NOT NULL, DQ.CNTRCT_TYP, 'UNKNOWN')                AS CNTRCT_TYPE_NM,
    CAST(IFF(DQ.VNDR_ID IS NOT NULL, DQ.VNDR_ID, -2) AS NUMBER(10,0))       AS CURR_CNTRCT_VNDR_ID,
    CAST(IFF(DQ.BYR_ID IS NOT NULL, DQ.BYR_ID, -2) AS NUMBER(10,0))         AS CURR_BYR_ID,
    IFF(DQ.CNTRCT_STAT IS NULL, 'UNKNOWN', DQ.CNTRCT_STAT)                  AS STATUS_TX,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                              AS LAST_UPDT_TS,
    LKP.CONTRACT_ID                                                         AS LKP_CONTRACT_ID
FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))   = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)   END AS CNTRCT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_STAT))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_STAT) END AS CNTRCT_STAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.P_CNTRCT)))    = 0 THEN ' ' ELSE RTRIM(SQ.P_CNTRCT)    END AS P_CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT)))      = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT)      END AS CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYP)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYP)  END AS CNTRCT_TYP,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.VNDR_ID,
            SQ.BYR_ID
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_CONTRACT_VW_TEST') }} SQ  --USED FOR TESTING
        WHERE SQ.MOD_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT UPPER(TRIM(F.CONTRACT_ID)) AS CONTRACT_ID
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CONTRACT_FDR') }} F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.CONTRACT_ID)) ORDER BY UPPER(TRIM(F.CONTRACT_ID))) = 1
    ) LKP
      ON LKP.CONTRACT_ID = UPPER(DQ.CNTRCT_ID)
