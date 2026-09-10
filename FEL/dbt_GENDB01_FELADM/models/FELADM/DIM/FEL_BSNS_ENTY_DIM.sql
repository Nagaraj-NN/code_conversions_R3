-- ==========================================================================
-- Model      : FEL_BSNS_ENTY_DIM
-- Mapping    : m_FEL_COMTRAC_BSNS_ENTY_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_COMTRAC_BSNS_ENTY_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_BSNS_ENTY_DIM
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
    alias='FEL_BSNS_ENTY_DIM_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_BSNS_ENTY_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_COMTRAC_BSNS_ENTY_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_BSNS_ENTY_DIM', target_object='GENDB01.FELADM.FEL_BSNS_ENTY_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }} TGT
     SET
         BSNS_ENTY_ID       = SRC.BSNS_ENTY_ID,
         STATUS_TX          = SRC.STATUS_TX,
         BSNS_ENTY_TYPE_NM  = SRC.BSNS_ENTY_TYPE_NM,
         BSNS_ENTY_NM       = SRC.BSNS_ENTY_NM,
         BSNS_ENTY_SHORT_NM = SRC.BSNS_ENTY_SHORT_NM,
         COMPANY_NM         = SRC.COMPANY_NM,
         AP_VNDR_ID         = SRC.AP_VNDR_ID,
         BSNS_ENTY_OLD_NM   = SRC.BSNS_ENTY_OLD_NM,
         LDC_CD             = SRC.LDC_CD,
         SYSTEM_ID          = SRC.SYSTEM_ID,
         SYSTEM_NM          = SRC.SYSTEM_NM,
         CONSOLIDATION_ID   = SRC.CONSOLIDATION_ID,
         CONSOLIDATION_NM   = SRC.CONSOLIDATION_NM,
         CNSLDTN_SYS_NM     = SRC.CNSLDTN_SYS_NM,
         LAST_UPDT_TS       = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.BSNS_ENTY_ID = SRC.BSNS_ENTY_ID
       AND TGT.SYSTEM_ID    = SRC.SYSTEM_ID
       AND (   SRC.STATUS_TX          <> TGT.STATUS_TX
            OR SRC.BSNS_ENTY_TYPE_NM  <> TGT.BSNS_ENTY_TYPE_NM
            OR SRC.BSNS_ENTY_NM       <> TGT.BSNS_ENTY_NM
            OR SRC.BSNS_ENTY_SHORT_NM <> TGT.BSNS_ENTY_SHORT_NM
            OR SRC.COMPANY_NM         <> TGT.COMPANY_NM
            OR SRC.CONSOLIDATION_ID   <> TGT.CONSOLIDATION_ID
            OR SRC.CONSOLIDATION_NM   <> TGT.CONSOLIDATION_NM
            OR SRC.CNSLDTN_SYS_NM     <> TGT.CNSLDTN_SYS_NM)",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }} (
         BSNS_ENTY_KEY,
         BSNS_ENTY_ID,
         STATUS_TX,
         BSNS_ENTY_TYPE_NM,
         BSNS_ENTY_NM,
         BSNS_ENTY_SHORT_NM,
         COMPANY_NM,
         AP_VNDR_ID,
         BSNS_ENTY_OLD_NM,
         LDC_CD,
         SYSTEM_ID,
         SYSTEM_NM,
         CONSOLIDATION_ID,
         CONSOLIDATION_NM,
         CNSLDTN_SYS_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.BSNS_ENTY_KEY,
         SRC.BSNS_ENTY_ID,
         SRC.STATUS_TX,
         SRC.BSNS_ENTY_TYPE_NM,
         SRC.BSNS_ENTY_NM,
         SRC.BSNS_ENTY_SHORT_NM,
         SRC.COMPANY_NM,
         SRC.AP_VNDR_ID,
         SRC.BSNS_ENTY_OLD_NM,
         SRC.LDC_CD,
         SRC.SYSTEM_ID,
         SRC.SYSTEM_NM,
         SRC.CONSOLIDATION_ID,
         SRC.CONSOLIDATION_NM,
         SRC.CNSLDTN_SYS_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }} L
         WHERE L.BSNS_ENTY_ID = SRC.BSNS_ENTY_ID
           AND L.SYSTEM_ID    = SRC.SYSTEM_ID
     )",
        log_model_end(this, 'TBD_FEL_BSNS_ENTY_DIM', target_object='GENDB01.FELADM.FEL_BSNS_ENTY_DIM')
    ]
) }}

SELECT
    CAST(DQ.O_BSNS_ENTY_KEY AS NUMBER(10,0))                                          AS BSNS_ENTY_KEY,
    DQ.BSNS_ENTY_ID,
    DQ.STATUS_TX,
    DQ.BSNS_ENTY_TYPE_NM,
    DQ.BSNS_ENTY_NM,
    DQ.BSNS_ENTY_SHORT_NM,
    DQ.COMPANY_NM,
    'N/A'                                                                             AS AP_VNDR_ID,
    'N/A'                                                                             AS BSNS_ENTY_OLD_NM,
    'N/A'                                                                             AS LDC_CD,
    CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                                  AS SYSTEM_ID,
    LEFT('COMTRAC', 25)                                                               AS SYSTEM_NM,
    CAST(DQ.O_CONSOLIDATION_ID AS NUMBER(10,0))                                       AS CONSOLIDATION_ID,
    LEFT(IFF(MSTR.CONSOLIDATION_ID IS NULL, DQ.BSNS_ENTY_NM, MSTR.BUSINESS_NM), 255)  AS CONSOLIDATION_NM,
    LEFT(IFF(MSTR.CONSOLIDATION_ID IS NULL, 'COMTRAC', MSTR.SYSTEM_NM), 25)           AS CNSLDTN_SYS_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                        AS LAST_UPDT_TS
FROM (
        SELECT
            SQ.BSNS_ENTY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))          = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)          END AS STATUS_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BSNS_ENTY_TYPE_NM)))  = 0 THEN ' ' ELSE RTRIM(SQ.BSNS_ENTY_TYPE_NM)  END AS BSNS_ENTY_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BSNS_ENTY_NM)))       = 0 THEN ' ' ELSE RTRIM(SQ.BSNS_ENTY_NM)       END AS BSNS_ENTY_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BSNS_ENTY_SHORT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.BSNS_ENTY_SHORT_NM) END AS BSNS_ENTY_SHORT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COMPANY_NM)))         = 0 THEN ' ' ELSE RTRIM(SQ.COMPANY_NM)         END AS COMPANY_NM,
            (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')          AS V_SYS_ID,
            IFF(XRF.CONSOLIDATION_ID IS NOT NULL, XRF.CONSOLIDATION_ID,
                NVL((SELECT MAX(CONSOLIDATION_ID) FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }}), 0)
                + ROW_NUMBER() OVER (ORDER BY SQ.BSNS_ENTY_ID))                                AS O_CONSOLIDATION_ID,
            NVL((SELECT MAX(BSNS_ENTY_KEY) FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }}), 0)
                + ROW_NUMBER() OVER (ORDER BY SQ.BSNS_ENTY_ID)                                 AS O_BSNS_ENTY_KEY
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_BSNS_ENTY_FDR') }} SQ
        LEFT JOIN (
            SELECT xrf.CONSOLIDATION_ID, XRF.DATA_TYP_ID, XRF.SYSTEM_ID,
                   UPPER(TRIM(XRF.BUSINESS_ID)) AS BUSINESS_ID
            FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }} xrf
            QUALIFY ROW_NUMBER() OVER (PARTITION BY XRF.DATA_TYP_ID, XRF.SYSTEM_ID, UPPER(TRIM(XRF.BUSINESS_ID))
                                       ORDER BY xrf.CONSOLIDATION_ID) = 1
        ) XRF
          ON XRF.DATA_TYP_ID = (SELECT MIN(DATA_TYPE_ID) FROM {{ source('GENDB01_FELADM','FEL_DATATYPE_DIM') }} WHERE DATA_TYPE_NM = 'BUSINESSENTITY')
         AND XRF.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
         AND XRF.BUSINESS_ID = LEFT(UPPER(TO_VARCHAR(SQ.BSNS_ENTY_ID)), 20)
        WHERE SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT XRF.BUSINESS_NM, SYS.SYS_NM AS SYSTEM_NM, XRF.CONSOLIDATION_ID,
               UPPER(XRF.MASTER_FL) AS MASTER_FL
        FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }} XRF
        INNER JOIN {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} SYS
          ON SYS.SYS_ID = XRF.SYSTEM_ID
        QUALIFY ROW_NUMBER() OVER (PARTITION BY XRF.CONSOLIDATION_ID, UPPER(XRF.MASTER_FL)
                                   ORDER BY XRF.BUSINESS_NM, SYS.SYS_NM) = 1
    ) MSTR
      ON MSTR.CONSOLIDATION_ID = DQ.O_CONSOLIDATION_ID
     AND MSTR.MASTER_FL        = 'Y'
