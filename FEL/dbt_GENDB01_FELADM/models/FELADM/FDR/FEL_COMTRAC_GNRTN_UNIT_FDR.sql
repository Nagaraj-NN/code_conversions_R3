-- ==========================================================================
-- Model      : FEL_COMTRAC_GNRTN_UNIT_FDR
-- Mapping    : m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR
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
-- Carried for the UPDATE branch only: LKP_UNIT_ID
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_GNRTN_UNIT_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_GNRTN_UNIT_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_GNRTN_UNIT_FDR') }} TGT
     SET
         UNIT_NM      = SRC.UNIT_NM,
         UNIT_STAT_TX = SRC.UNIT_STAT_TX,
         LAST_UPDT_TS = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.UNIT_ID = SRC.LKP_UNIT_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_GNRTN_UNIT_FDR') }} (
         UNIT_ID,
         UNIT_NM,
         UNIT_STAT_TX,
         LAST_UPDT_TS
     )
     SELECT
         SRC.UNIT_ID,
         SRC.UNIT_NM,
         SRC.UNIT_STAT_TX,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_GNRTN_UNIT_FDR') }} U
         WHERE UPPER(TRIM(U.UNIT_ID)) = SRC.UNIT_ID
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_GNRTN_UNIT_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR')
    ]
) }}

SELECT
    CAST(CAST(DQ.UNIT_ID AS NUMBER(10,0)) AS VARCHAR)                 AS UNIT_ID,
    LEFT(IFF(DQ.UNIT_NAME IS NULL, 'UNSPECIFIED', DQ.UNIT_NAME), 40)  AS UNIT_NM,
    LEFT(IFF(DQ.UNIT_STATUS IS NULL, 'UNKNOWN', DQ.UNIT_STATUS), 18)  AS UNIT_STAT_TX,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                        AS LAST_UPDT_TS,
    LKP.UNIT_ID                                                       AS LKP_UNIT_ID
FROM (
        SELECT
            SQ.UNIT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_NAME)))   = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_NAME)   END AS UNIT_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_STATUS))) = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_STATUS) END AS UNIT_STATUS
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_GENUNIT_VW_TEST') }} SQ
        WHERE SQ.MOD_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT UPPER(TRIM(U.UNIT_ID)) AS UNIT_ID
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_GNRTN_UNIT_FDR') }} U
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(U.UNIT_ID)) ORDER BY UPPER(TRIM(U.UNIT_ID))) = 1
    ) LKP
      ON LKP.UNIT_ID = CAST(CAST(DQ.UNIT_ID AS NUMBER(10,0)) AS VARCHAR)
