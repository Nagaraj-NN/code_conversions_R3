-- ==========================================================================
-- Model      : FEL_COMTRAC_BSNS_ENTY_FDR
-- Mapping    : m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_BSNS_ENTY_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. The router splits on the feeder lookup with
-- no change test; DEFAULT1 is discarded.
--
-- The Informatica router branches are preserved as validated: the model holds
-- the transformed source row set once, and the two post-hooks apply the
-- UPDATE branch and the INSERT branch to the real target.
--
-- The feeder lookup LKP_FDR that the UPDATE branch joined with an INNER JOIN
-- is a LEFT JOIN here so the INSERT branch keeps its rows. It is reduced to
-- one row per BSNS_ENTY_ID by its QUALIFY, and the UPDATE post-hook still
-- filters on LKP_BSNS_ENTY_ID, so a row that finds no match cannot be
-- updated. Row counts and results are unchanged. The INSERT branch expressed
-- the same test as a NOT EXISTS and that is kept verbatim below.
--
-- BSNS_ENTY_NM is authored asymmetrically in the validated script: the UPDATE
-- branch truncates to 80 characters and the INSERT branch to 75. Both are
-- carried, as INS_BSNS_ENTY_NM for the insert, so neither branch changes.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_BSNS_ENTY_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_BSNS_ENTY_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_BSNS_ENTY_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_BSNS_ENTY_FDR') }} TGT
     SET
         STATUS_TX          = SRC.STATUS_TX,
         BSNS_ENTY_TYPE_NM  = SRC.BSNS_ENTY_TYPE_NM,
         BSNS_ENTY_NM       = SRC.BSNS_ENTY_NM,
         BSNS_ENTY_SHORT_NM = SRC.BSNS_ENTY_SHORT_NM,
         COMPANY_NM         = SRC.COMPANY_NAME,
         LAST_UPDT_TS       = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.BSNS_ENTY_ID = SRC.LKP_BSNS_ENTY_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_BSNS_ENTY_FDR') }} (
         BSNS_ENTY_ID,
         STATUS_TX,
         BSNS_ENTY_TYPE_NM,
         BSNS_ENTY_NM,
         BSNS_ENTY_SHORT_NM,
         COMPANY_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.BSNS_ENTY_ID,
         SRC.STATUS_TX,
         SRC.BSNS_ENTY_TYPE_NM,
         SRC.INS_BSNS_ENTY_NM,
         SRC.BSNS_ENTY_SHORT_NM,
         SRC.COMPANY_NAME,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_BSNS_ENTY_FDR') }} LKP_FDR
         WHERE LKP_FDR.BSNS_ENTY_ID = SRC.BSNS_ENTY_ID
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_BSNS_ENTY_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_BSNS_ENTY_FDR')
    ]
) }}

SELECT
    CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))                                                  AS BSNS_ENTY_ID,
    LEFT(IFF(SQ.STAT_NM IS NULL, ' ', SQ.STAT_NM), 12)                                     AS STATUS_TX,
    LEFT(IFF(SQ.BSNS_ENTY_TYPE IS NULL, ' ', SQ.BSNS_ENTY_TYPE), 15)                       AS BSNS_ENTY_TYPE_NM,
    LEFT(IFF(SQ.BSNS_ENTY_NM IS NULL, ' ', SQ.BSNS_ENTY_NM), 80)                           AS BSNS_ENTY_NM,
    LEFT(IFF(SQ.BSNS_ENTY_NM IS NULL, ' ', SQ.BSNS_ENTY_NM), 75)                           AS INS_BSNS_ENTY_NM,
    LEFT(IFF(SQ.BSNS_ENTY_SHRT_NM IS NULL, ' ', SQ.BSNS_ENTY_SHRT_NM), 30)                 AS BSNS_ENTY_SHORT_NM,
    LEFT(IFF(LKP.BSNS_ENTY_SHRT_NM IS NULL, 'UNKNOWN', UPPER(LKP.BSNS_ENTY_SHRT_NM)), 30)  AS COMPANY_NAME,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                             AS LAST_UPDT_TS,
    CAST(LKP_FDR.BSNS_ENTY_ID AS NUMBER(10,0))                                             AS LKP_BSNS_ENTY_ID
FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_BUSINESSENTITY_VW_TEST') }} SQ  --USED FOR TESTING
LEFT JOIN (
    SELECT
        BSNS_ENTY_SHRT_NM,
        BSNS_ENTY_ID
    FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_BUSINESSENTITY_VW_TEST') }}  --USED FOR TESTING
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID ORDER BY BSNS_ENTY_ID) = 1
) LKP
  ON LKP.BSNS_ENTY_ID = SQ.FK_HLDNG_CO_ID
LEFT JOIN (
    SELECT
        BSNS_ENTY_ID
    FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_BSNS_ENTY_FDR') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID ORDER BY BSNS_ENTY_ID) = 1
) LKP_FDR
  ON LKP_FDR.BSNS_ENTY_ID = CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))
WHERE SQ.MOD_BY_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
  AND SQ.MOD_BY_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
  AND 'C' = 'C'
