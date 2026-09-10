-- ==========================================================================
-- Model      : FEL_COMTRAC_FACILITY_FDR
-- Mapping    : m_FEL_COMTRAC_FACILITY_FDR_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COMTRAC_FACILITY_FDR_ins_upd
-- Target     : GENDB01.FELADM.FEL_COMTRAC_FACILITY_FDR
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
-- Carried for the UPDATE branch only: LKP_FACILITY_ID
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COMTRAC_FACILITY_FDR_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_FACILITY_FDR_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COMTRAC_FACILITY_FDR_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_FACILITY_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_FACILITY_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COMTRAC_FACILITY_FDR') }} TGT
     SET
         FACILITY_NM   = SRC.FACILITY_NM,
         FCLTY_TYPE_NM = SRC.FCLTY_TYPE_NM,
         FCLTY_STAT_TX = SRC.FCLTY_STAT_TX,
         BSNS_ENTY_ID  = SRC.BSNS_ENTY_ID,
         WV_PLANT_CD   = SRC.WV_PLANT_CD,
         GEOG_STATE_NM = SRC.GEOG_STATE_NM,
         REGION_NM     = SRC.REGION_NM,
         LAST_UPDT_TS  = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.FACILITY_ID = SRC.LKP_FACILITY_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COMTRAC_FACILITY_FDR') }} (
         FACILITY_ID,
         FACILITY_NM,
         FCLTY_TYPE_NM,
         FCLTY_STAT_TX,
         BSNS_ENTY_ID,
         WV_PLANT_CD,
         GEOG_STATE_NM,
         REGION_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.FACILITY_ID,
         SRC.FACILITY_NM,
         SRC.FCLTY_TYPE_NM,
         SRC.FCLTY_STAT_TX,
         SRC.BSNS_ENTY_ID,
         SRC.WV_PLANT_CD,
         SRC.GEOG_STATE_NM,
         SRC.REGION_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_FACILITY_FDR') }} FDR
         WHERE TRIM(FDR.FACILITY_ID) = SRC.FACILITY_ID
     )",
        log_model_end(this, 'TBD_FEL_COMTRAC_FACILITY_FDR', target_object='GENDB01.FELADM.FEL_COMTRAC_FACILITY_FDR')
    ]
) }}

SELECT
    LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(15,0)) AS VARCHAR), 3)            AS FACILITY_ID,
    IFF(DQ.FCLTY_NAME IS NULL, ' ', DQ.FCLTY_NAME)                         AS FACILITY_NM,
    IFF(DQ.FCLTY_TPE IS NULL, ' ', DQ.FCLTY_TPE)                           AS FCLTY_TYPE_NM,
    IFF(DQ.FCLTY_STAT_NM IS NULL, ' ', DQ.FCLTY_STAT_NM)                   AS FCLTY_STAT_TX,
    CAST(IFF(DQ.FK_OPCO_ID IS NULL, -999, DQ.FK_OPCO_ID) AS NUMBER(10,0))  AS BSNS_ENTY_ID,
    IFF(DQ.WV_CDE IS NULL, 'N/A', DQ.WV_CDE)                               AS WV_PLANT_CD,
    IFF(DQ.STATE IS NULL, 'UNKNOWN', DQ.STATE)                             AS GEOG_STATE_NM,
    LEFT(IFF(DQ.REGION IS NULL, 'UNKNOWN', DQ.REGION), 10)                 AS REGION_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                             AS LAST_UPDT_TS,
    LKP.FACILITY_ID                                                        AS LKP_FACILITY_ID
FROM (
        SELECT
            SQ.FCLTY_ID,
            SQ.FK_OPCO_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_NAME)))    = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_NAME)    END AS FCLTY_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_STAT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_STAT_NM) END AS FCLTY_STAT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_TPE)))     = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_TPE)     END AS FCLTY_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.WV_CDE)))        = 0 THEN ' ' ELSE RTRIM(SQ.WV_CDE)        END AS WV_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATE)))         = 0 THEN ' ' ELSE RTRIM(SQ.STATE)         END AS STATE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.REGION)))        = 0 THEN ' ' ELSE RTRIM(SQ.REGION)        END AS REGION
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_FACILITY_VW_TEST') }} SQ
        WHERE SQ.MOD_BY_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_BY_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT TRIM(FDR.FACILITY_ID) AS FACILITY_ID
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_FACILITY_FDR') }} FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FDR.FACILITY_ID) ORDER BY TRIM(FDR.FACILITY_ID)) = 1
    ) LKP
      ON LKP.FACILITY_ID = LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(15,0)) AS VARCHAR), 3)
