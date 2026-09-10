-- ==========================================================================
-- Model      : FEL_RECEIPT_DIM
-- Mapping    : m_FEL_RECEIPT_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_RECEIPT_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_RECEIPT_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the dimension
-- lookup; the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_RECEIPT_DIM_SRC',
    meta={"mapping_name": "m_FEL_RECEIPT_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_RECEIPT_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_RECEIPT_DIM', target_object='GENDB01.FELADM.FEL_RECEIPT_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_RECEIPT_DIM') }} TGT
     SET
         RECEIPT_ID     = SRC.RECEIPT_ID,
         BARGE_ID       = SRC.BARGE_ID,
         TRAIN_ID       = SRC.TRAIN_ID,
         TOW_ID         = SRC.TOW_ID,
         UNLOADD_TS     = SRC.UNLOADD_TS,
         SHIPPED_TS     = SRC.SHIPPED_TS,
         ANLYS_CTRL_NB  = SRC.ANLYS_CTRL_NB,
         ANLYS_TRCKG_NB = SRC.ANLYS_TRCKG_NB,
         SHP_MTHD_TX    = SRC.SHP_MTHD_TX,
         STATUS_TX      = SRC.STATUS_TX,
         LAST_UPDT_TS   = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.RECEIPT_ID = SRC.RECEIPT_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_RECEIPT_DIM') }} (
         RECEIPT_KEY,
         RECEIPT_ID,
         BARGE_ID,
         TRAIN_ID,
         TOW_ID,
         UNLOADD_TS,
         SHIPPED_TS,
         ANLYS_CTRL_NB,
         ANLYS_TRCKG_NB,
         SHP_MTHD_TX,
         STATUS_TX,
         LAST_UPDT_TS
     )
     SELECT
         NVL((SELECT MAX(RECEIPT_KEY) FROM {{ source('GENDB01_FELADM','FEL_RECEIPT_DIM') }}), 0)
             + ROW_NUMBER() OVER (ORDER BY SRC.RECEIPT_ID)   AS RECEIPT_KEY,
         SRC.RECEIPT_ID,
         SRC.BARGE_ID,
         SRC.TRAIN_ID,
         SRC.TOW_ID,
         SRC.UNLOADD_TS,
         SRC.SHIPPED_TS,
         SRC.ANLYS_CTRL_NB,
         SRC.ANLYS_TRCKG_NB,
         SRC.SHP_MTHD_TX,
         SRC.STATUS_TX,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_RECEIPT_DIM') }} L
         WHERE L.RECEIPT_ID = SRC.RECEIPT_ID
     )",
        log_model_end(this, 'TBD_FEL_RECEIPT_DIM', target_object='GENDB01.FELADM.FEL_RECEIPT_DIM')
    ]
) }}

SELECT
    SQ.RECEIPT_ID,
    SQ.UNLOADD_TS,
    SQ.SHIPPED_TS,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BARGE_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.BARGE_ID)       END  AS BARGE_ID,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TRAIN_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.TRAIN_ID)       END  AS TRAIN_ID,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TOW_ID)))         = 0 THEN ' ' ELSE RTRIM(SQ.TOW_ID)         END  AS TOW_ID,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_CTRL_NB)))  = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_CTRL_NB)  END  AS ANLYS_CTRL_NB,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_TRCKG_NB))) = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_TRCKG_NB) END  AS ANLYS_TRCKG_NB,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))    = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)    END  AS SHP_MTHD_TX,
    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))      = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)      END  AS STATUS_TX,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                                        AS LAST_UPDT_TS
FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_QTY_QLTY_FDR') }} SQ
    WHERE SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
      AND 'C' = 'C'
      AND UPPER(TRIM(SQ.STATUS_TX)) = 'ACTIVE'
