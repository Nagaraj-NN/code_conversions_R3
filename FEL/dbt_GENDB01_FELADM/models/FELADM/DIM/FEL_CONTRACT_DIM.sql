-- ==========================================================================
-- Model      : FEL_CONTRACT_DIM
-- Mapping    : m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_CONTRACT_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE from the feeder, then a SECOND UPDATE pass over the
-- dimension itself. Three target instances, load order 1 for the feeder
-- insert and update and 2 for the second pass.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
--
-- Target load order 1 of 2. The second pass over the dimension is the
-- separate model FEL_CONTRACT_DIM_PARENT_ROLLUP, which depends on this one.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_CONTRACT_DIM_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CONTRACT_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_COMTRAC_CONTRACT_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_CONTRACT_DIM', target_object='GENDB01.FELADM.FEL_CONTRACT_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} TGT
     SET
         CONTRACT_ID         = SRC.CONTRACT_ID,
         CNTRCT_EFCTV_DT     = SRC.CNTRCT_EFCTV_DT,
         CNTRCT_EXPR_DT      = SRC.CNTRCT_EXPR_DT,
         PARNT_CNTRCT_NM     = SRC.PARNT_CNTRCT_NM,
         CONTRACT_NM         = SRC.CONTRACT_NM,
         CNTRCT_TYPE_NM      = SRC.CNTRCT_TYPE_NM,
         CURR_CNTRCT_VNDR_NM = SRC.CURR_CNTRCT_VNDR_NM,
         CURR_OPCO_NM        = SRC.CURR_OPCO_NM,
         STATUS_TX           = SRC.STATUS_TX,
         CNTRCT_PYMT_TRM_NM  = SRC.CNTRCT_PYMT_TRM_NM,
         CNTRCT_FRMT_TX      = SRC.CNTRCT_FRMT_TX,
         CNTRCT_OBLGN_TX     = SRC.CNTRCT_OBLGN_TX,
         CNTRCT_CMDTY_NM     = SRC.CNTRCT_CMDTY_NM,
         SYSTEM_ID           = SRC.SYSTEM_ID,
         SYSTEM_NM           = SRC.SYSTEM_NM,
         LAST_UPDT_TS        = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE UPPER(TRIM(TGT.CONTRACT_ID)) = SRC.V_TRIM_CONTRACT_ID
       AND TGT.SYSTEM_ID                = SRC.SYSTEM_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} (
         CONTRACT_KEY,
         CONTRACT_ID,
         CNTRCT_EFCTV_DT,
         CNTRCT_EXPR_DT,
         PARNT_CNTRCT_NM,
         CONTRACT_NM,
         CNTRCT_TYPE_NM,
         CURR_CNTRCT_VNDR_NM,
         CURR_OPCO_NM,
         STATUS_TX,
         CNTRCT_PYMT_TRM_NM,
         CNTRCT_FRMT_TX,
         CNTRCT_OBLGN_TX,
         CNTRCT_CMDTY_NM,
         SYSTEM_ID,
         SYSTEM_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CONTRACT_KEY,
         SRC.CONTRACT_ID,
         SRC.CNTRCT_EFCTV_DT,
         SRC.CNTRCT_EXPR_DT,
         SRC.PARNT_CNTRCT_NM,
         SRC.CONTRACT_NM,
         SRC.CNTRCT_TYPE_NM,
         SRC.CURR_CNTRCT_VNDR_NM,
         SRC.CURR_OPCO_NM,
         SRC.STATUS_TX,
         SRC.CNTRCT_PYMT_TRM_NM,
         SRC.CNTRCT_FRMT_TX,
         SRC.CNTRCT_OBLGN_TX,
         SRC.CNTRCT_CMDTY_NM,
         SRC.SYSTEM_ID,
         SRC.SYSTEM_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} L
         WHERE UPPER(TRIM(L.CONTRACT_ID)) = SRC.V_TRIM_CONTRACT_ID
           AND L.SYSTEM_ID                = SRC.SYSTEM_ID
     )",
        log_model_end(this, 'TBD_FEL_CONTRACT_DIM', target_object='GENDB01.FELADM.FEL_CONTRACT_DIM')
    ]
) }}

SELECT
    CAST(DQ.O_CONTRACT_KEY AS NUMBER(10,0))                                   AS CONTRACT_KEY,
    DQ.CONTRACT_ID,
    DQ.CNTRCT_EFCTV_DT,
    DQ.CNTRCT_EXPR_DT,
    DQ.PARNT_CNTRCT_NM,
    DQ.CONTRACT_NM,
    DQ.CNTRCT_TYPE_NM,
    LEFT(IFF(LKP_VND.BSNS_ENTY_NM IS NULL, 'N/A', LKP_VND.BSNS_ENTY_NM), 75)  AS CURR_CNTRCT_VNDR_NM,
    LEFT(IFF(LKP_BYR.BSNS_ENTY_NM IS NULL, 'N/A', LKP_BYR.BSNS_ENTY_NM), 75)  AS CURR_OPCO_NM,
    DQ.STATUS_TX,
    'N/A'                                                                     AS CNTRCT_PYMT_TRM_NM,
    'N/A'                                                                     AS CNTRCT_FRMT_TX,
    'N/A'                                                                     AS CNTRCT_OBLGN_TX,
    'N/A'                                                                     AS CNTRCT_CMDTY_NM,
    CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                          AS SYSTEM_ID,
    'COMTRAC'                                                                 AS SYSTEM_NM,
    DQ.V_TRIM_CONTRACT_ID,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                AS LAST_UPDT_TS
FROM (
        SELECT
            SQ.CNTRCT_EFCTV_DT,
            SQ.CNTRCT_EXPR_DT,
            SQ.CURR_CNTRCT_VNDR_ID,
            SQ.CURR_BYR_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID)     END AS CONTRACT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PARNT_CNTRCT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.PARNT_CNTRCT_NM) END AS PARNT_CNTRCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_NM)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_NM)     END AS CONTRACT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYPE_NM)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYPE_NM)  END AS CNTRCT_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))       = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)       END AS STATUS_TX,
            UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID) END)  AS V_TRIM_CONTRACT_ID,
            (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')                           AS V_SYS_ID,
            NVL((SELECT MAX(CONTRACT_KEY) FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }}), 0)
                + ROW_NUMBER() OVER (ORDER BY SQ.CONTRACT_ID)                                                  AS O_CONTRACT_KEY
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CONTRACT_FDR') }} SQ
        WHERE SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }}
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_VND
      ON LKP_VND.BSNS_ENTY_ID = DQ.CURR_CNTRCT_VNDR_ID
     AND LKP_VND.SYSTEM_ID    = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }}
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_BYR
      ON LKP_BYR.BSNS_ENTY_ID = DQ.CURR_BYR_ID
     AND LKP_BYR.SYSTEM_ID    = DQ.V_SYS_ID
