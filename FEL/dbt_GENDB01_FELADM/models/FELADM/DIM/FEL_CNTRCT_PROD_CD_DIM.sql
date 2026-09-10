-- ==========================================================================
-- Model      : FEL_CNTRCT_PROD_CD_DIM
-- Mapping    : m_FEL_CNTRCT_PROD_CD_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_CNTRCT_PROD_CD_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_CNTRCT_PROD_CD_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_INS_UPD splits on the dimension lookup
-- alone; the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_CNTRCT_PROD_CD_DIM_SRC',
    meta={"mapping_name": "m_FEL_CNTRCT_PROD_CD_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_CNTRCT_PROD_CD_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_CNTRCT_PROD_CD_DIM', target_object='GENDB01.FELADM.FEL_CNTRCT_PROD_CD_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_CNTRCT_PROD_CD_DIM') }} TGT
     SET
         CNTRCT_DTL_ID   = SRC.CNTRCT_DTL_ID,
         CONTRACT_KEY    = SRC.CONTRACT_KEY,
         PRODUCT_CD      = SRC.PRODUCT_CD,
         PRODUCT_NM      = SRC.PRODUCT_NM,
         PARNT_CNTRCT_NM = SRC.PARNT_CNTRCT_NM,
         CONTRACT_NM     = SRC.CONTRACT_NM,
         FOB_POINT_TX    = SRC.FOB_POINT_TX,
         SHP_MTHD_TX     = SRC.SHP_MTHD_TX,
         EFFECTIVE_DT    = SRC.EFFECTIVE_DT,
         EXPIRATION_DT   = SRC.EXPIRATION_DT,
         MODIFIED_DT     = SRC.MODIFIED_DT,
         LAST_UPDT_TS    = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.CNTRCT_DTL_ID = SRC.CNTRCT_DTL_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_CNTRCT_PROD_CD_DIM') }} (
         CNTRCT_PROD_KEY,
         CNTRCT_DTL_ID,
         CONTRACT_KEY,
         PRODUCT_CD,
         PRODUCT_NM,
         PARNT_CNTRCT_NM,
         CONTRACT_NM,
         FOB_POINT_TX,
         SHP_MTHD_TX,
         EFFECTIVE_DT,
         EXPIRATION_DT,
         MODIFIED_DT,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CNTRCT_PROD_KEY,
         SRC.CNTRCT_DTL_ID,
         SRC.CONTRACT_KEY,
         SRC.PRODUCT_CD,
         SRC.PRODUCT_NM,
         SRC.PARNT_CNTRCT_NM,
         SRC.CONTRACT_NM,
         SRC.FOB_POINT_TX,
         SRC.SHP_MTHD_TX,
         SRC.EFFECTIVE_DT,
         SRC.EXPIRATION_DT,
         SRC.MODIFIED_DT,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_CNTRCT_PROD_CD_DIM') }} L
         WHERE L.CNTRCT_DTL_ID = SRC.CNTRCT_DTL_ID
     )",
        log_model_end(this, 'TBD_FEL_CNTRCT_PROD_CD_DIM', target_object='GENDB01.FELADM.FEL_CNTRCT_PROD_CD_DIM')
    ]
) }}

SELECT
    DQ.CNTRCT_DTL_ID,
    CAST(IFF(LKP_CD.CONTRACT_KEY IS NULL, -2, LKP_CD.CONTRACT_KEY) AS NUMBER(10,0))   AS CONTRACT_KEY,
    DQ.PRODUCT_CD,
    DQ.PRODUCT_NM,
    LEFT(IFF(LKP_CD.PARNT_CNTRCT_NM IS NULL, 'UNKNOWN', LKP_CD.PARNT_CNTRCT_NM), 40)  AS PARNT_CNTRCT_NM,
    LEFT(IFF(LKP_CD.CONTRACT_NM IS NULL, 'UNKNOWN', LKP_CD.CONTRACT_NM), 40)          AS CONTRACT_NM,
    DQ.FOB_POINT_TX,
    DQ.SHP_MTHD_TX,
    DQ.EFFECTIVE_DT,
    DQ.EXPIRATION_DT,
    DQ.MODIFIED_DT,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                        AS LAST_UPDT_TS,
    NVL((SELECT MAX(CNTRCT_PROD_KEY) FROM {{ source('GENDB01_FELADM','FEL_CNTRCT_PROD_CD_DIM') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY DQ.CNTRCT_DTL_ID) AS CNTRCT_PROD_KEY
FROM (
        SELECT
            SQ.CNTRCT_DTL_ID,
            SQ.EFFECTIVE_DT,
            SQ.EXPIRATION_DT,
            SQ.MODIFIED_DT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_CD)))  = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_CD)  END AS CONTRACT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_CD)   END AS PRODUCT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_NM)   END AS PRODUCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_POINT_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.FOB_POINT_TX) END AS FOB_POINT_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)  END AS SHP_MTHD_TX
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_PROD_CD_FDR') }} SQ
        WHERE SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT dim.CONTRACT_KEY, dim.PARNT_CNTRCT_NM, dim.CONTRACT_NM,
               TRIM(dim.CONTRACT_ID) AS CONTRACT_ID, dim.SYSTEM_ID
        FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} dim
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(dim.CONTRACT_ID), dim.SYSTEM_ID ORDER BY dim.CONTRACT_KEY) = 1
    ) LKP_CD
      ON LKP_CD.CONTRACT_ID = DQ.CONTRACT_CD
     AND LKP_CD.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
