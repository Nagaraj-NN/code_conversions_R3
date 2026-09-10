-- ==========================================================================
-- Model      : FEL_COMTRAC_CNTRCT_PROD_CD_FDR
-- Mapping    : m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_CNTRCT_PROD_CD_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW splits on the target lookup; the
-- unconnected DEFAULT1 group is discarded.
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
-- Carried for the UPDATE branch only: LKP_CNTRCT_DTL_ID
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_CNTRCT_PROD_CD_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_CNTRCT_PROD_CD_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_PROD_CD_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_PROD_CD_FDR') }} TGT
     SET
         CONTRACT_CD   = SRC.CONTRACT_CD,
         PRODUCT_CD    = SRC.PRODUCT_CD,
         PRODUCT_NM    = SRC.PRODUCT_NM,
         FOB_POINT_TX  = SRC.FOB_POINT_TX,
         SHP_MTHD_TX   = SRC.SHP_MTHD_TX,
         EFFECTIVE_DT  = SRC.EFFECTIVE_DT,
         EXPIRATION_DT = SRC.EXPIRATION_DT,
         MODIFIED_DT   = SRC.MODIFIED_DT,
         LAST_UPDT_TS  = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.CNTRCT_DTL_ID = SRC.LKP_CNTRCT_DTL_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_PROD_CD_FDR') }} (
         CNTRCT_DTL_ID,
         CONTRACT_CD,
         PRODUCT_CD,
         PRODUCT_NM,
         FOB_POINT_TX,
         SHP_MTHD_TX,
         EFFECTIVE_DT,
         EXPIRATION_DT,
         MODIFIED_DT,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CNTRCT_DTL_ID,
         SRC.CONTRACT_CD,
         SRC.PRODUCT_CD,
         SRC.PRODUCT_NM,
         SRC.FOB_POINT_TX,
         SRC.SHP_MTHD_TX,
         SRC.EFFECTIVE_DT,
         SRC.EXPIRATION_DT,
         SRC.MODIFIED_DT,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_PROD_CD_FDR') }} FDR
         WHERE FDR.CNTRCT_DTL_ID     = SRC.CNTRCT_DTL_ID
           AND TRIM(FDR.CONTRACT_CD) = SRC.CONTRACT_CD
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_CNTRCT_PROD_CD_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_PROD_CD_FDR')
    ]
) }}

SELECT
    CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                               AS CNTRCT_DTL_ID,
    DQ.CNTRCT_ID                                                        AS CONTRACT_CD,
    IFF(DQ.PDCT_CDE IS NULL, ' ', DQ.PDCT_CDE)                          AS PRODUCT_CD,
    IFF(DQ.NME IS NULL, ' ', DQ.NME)                                    AS PRODUCT_NM,
    IFF(DQ.FOB_PT IS NULL, ' ', DQ.FOB_PT)                              AS FOB_POINT_TX,
    IFF(DQ.SHIP_MTHD IS NULL, ' ', DQ.SHIP_MTHD)                        AS SHP_MTHD_TX,
    CAST(IFF(DQ.EFF_DT IS NULL, DATE '1900-01-01', DQ.EFF_DT) AS DATE)  AS EFFECTIVE_DT,
    CAST(IFF(DQ.EXP_DT IS NULL, DATE '2055-01-01', DQ.EXP_DT) AS DATE)  AS EXPIRATION_DT,
    CAST(DQ.MOD_DT AS DATE)                                             AS MODIFIED_DT,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                          AS LAST_UPDT_TS,
    LKP.CNTRCT_DTL_ID                                                   AS LKP_CNTRCT_DTL_ID
FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)  END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PDCT_CDE)))   = 0 THEN ' ' ELSE RTRIM(SQ.PDCT_CDE)   END AS PDCT_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.NME)))        = 0 THEN ' ' ELSE RTRIM(SQ.NME)        END AS NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_PT)))     = 0 THEN ' ' ELSE RTRIM(SQ.FOB_PT)     END AS FOB_PT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHIP_MTHD)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHIP_MTHD)  END AS SHIP_MTHD,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.MOD_DT
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_CONTRACTDTL_VW_TEST') }} SQ  --USED FOR TESTING
        WHERE SQ.MOD_DT >= TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_DT <  TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT
            FDR.CNTRCT_DTL_ID          AS CNTRCT_DTL_ID,
            TRIM(FDR.CONTRACT_CD)      AS CONTRACT_CD
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_PROD_CD_FDR') }} FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FDR.CNTRCT_DTL_ID, TRIM(FDR.CONTRACT_CD)
                                   ORDER BY FDR.CNTRCT_DTL_ID, TRIM(FDR.CONTRACT_CD)) = 1
    ) LKP
      ON LKP.CNTRCT_DTL_ID = CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))
     AND LKP.CONTRACT_CD   = DQ.CNTRCT_ID
