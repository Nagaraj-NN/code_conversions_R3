-- ==========================================================================
-- Model      : FEL_CMDTY_SRC_DIM
-- Mapping    : m_FEL_CMDTY_SRC_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_CMDTY_SRC_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_CMDTY_SRC_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the existence
-- lookup; the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_CMDTY_SRC_DIM_SRC',
    meta={"mapping_name": "m_FEL_CMDTY_SRC_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_CMDTY_SRC_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_CMDTY_SRC_DIM', target_object='GENDB01.FELADM.FEL_CMDTY_SRC_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_DIM') }} TGT
     SET
         CMDTY_SRC_EFCTV_DT    = SRC.CMDTY_SRC_EFCTV_DT,
         CMDTY_SRC_EXPR_DT     = SRC.CMDTY_SRC_EXPR_DT,
         CMDTY_SRC_KEY         = SRC.CMDTY_SRC_KEY,
         CMDTY_SRC_NM          = SRC.CMDTY_SRC_NM,
         CMDTY_SRC_TYPE_NM     = SRC.CMDTY_SRC_TYPE_NM,
         CMDTY_SRC_SUB_TYPE_NM = SRC.CMDTY_SRC_SUB_TYPE_NM,
         CMDTY_SRC_STAT_TX     = SRC.CMDTY_SRC_STAT_TX,
         ALCTD_CMDTY_SRC_NM    = SRC.ALCTD_CMDTY_SRC_NM,
         ALLOCATED_PCT         = SRC.ALLOCATED_PCT,
         GEOG_BASIN_NM         = SRC.GEOG_BASIN_NM,
         LABOR_TYPE_NM         = SRC.LABOR_TYPE_NM,
         FUEL_TYPE_NM          = SRC.FUEL_TYPE_NM,
         MSHA_NB               = SRC.MSHA_NB,
         DISTRICT_NB           = SRC.DISTRICT_NB,
         STATE_NM              = SRC.STATE_NM,
         COUNTY_NM             = SRC.COUNTY_NM,
         LAST_UPDT_TS          = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.ALLOCATED_ID = SRC.ALLOCATED_ID
       AND TGT.CMDTY_SRC_ID = SRC.CMDTY_SRC_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_DIM') }} (
         ALLOCATED_ID,
         CMDTY_SRC_ID,
         CMDTY_SRC_EFCTV_DT,
         CMDTY_SRC_EXPR_DT,
         CMDTY_SRC_KEY,
         CMDTY_SRC_NM,
         CMDTY_SRC_TYPE_NM,
         CMDTY_SRC_SUB_TYPE_NM,
         CMDTY_SRC_STAT_TX,
         ALCTD_CMDTY_SRC_NM,
         ALLOCATED_PCT,
         GEOG_BASIN_NM,
         LABOR_TYPE_NM,
         FUEL_TYPE_NM,
         MSHA_NB,
         DISTRICT_NB,
         STATE_NM,
         COUNTY_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.ALLOCATED_ID,
         SRC.CMDTY_SRC_ID,
         SRC.CMDTY_SRC_EFCTV_DT,
         SRC.CMDTY_SRC_EXPR_DT,
         SRC.CMDTY_SRC_KEY,
         SRC.CMDTY_SRC_NM,
         SRC.CMDTY_SRC_TYPE_NM,
         SRC.CMDTY_SRC_SUB_TYPE_NM,
         SRC.CMDTY_SRC_STAT_TX,
         SRC.ALCTD_CMDTY_SRC_NM,
         SRC.ALLOCATED_PCT,
         SRC.GEOG_BASIN_NM,
         SRC.LABOR_TYPE_NM,
         SRC.FUEL_TYPE_NM,
         SRC.MSHA_NB,
         SRC.DISTRICT_NB,
         SRC.STATE_NM,
         SRC.COUNTY_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_DIM') }} L
         WHERE L.CMDTY_SRC_ID = SRC.CMDTY_SRC_ID
           AND L.ALLOCATED_ID = SRC.ALLOCATED_ID
     )",
        log_model_end(this, 'TBD_FEL_CMDTY_SRC_DIM', target_object='GENDB01.FELADM.FEL_CMDTY_SRC_DIM')
    ]
) }}

SELECT
    DQ.ALLOCATED_ID,
    DQ.CMDTY_SRC_ID,
    DQ.CMDTY_SRC_EFCTV_DT,
    DQ.CMDTY_SRC_EXPR_DT,
    CAST(IFF(LKP_KEY.CMDTY_SRC_KEY IS NOT NULL, LKP_KEY.CMDTY_SRC_KEY,
                 NVL((SELECT MAX(CMDTY_SRC_KEY) FROM {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_DIM') }}), 0)
                 + DENSE_RANK() OVER (PARTITION BY IFF(LKP_KEY.CMDTY_SRC_KEY IS NULL, 1, 0)
                                      ORDER BY DQ.CMDTY_SRC_ID)) AS NUMBER(10,0)) AS CMDTY_SRC_KEY,
    DQ.CMDTY_SRC_NM,
    DQ.CMDTY_SRC_TYPE_NM,
    DQ.CMDTY_SRC_SUB_TYPE_NM,
    DQ.CMDTY_SRC_STAT_TX,
    DQ.ALCTD_CMDTY_SRC_NM,
    CAST(DQ.ALLOCATED_PCT AS NUMBER(5,3))       AS ALLOCATED_PCT,
    DQ.GEOG_BASIN_NM,
    DQ.LABOR_TYPE_NM,
    DQ.FUEL_TYPE_NM,
    DQ.MSHA_NB,
    CAST(DQ.DISTRICT_NB AS NUMBER(5,0))         AS DISTRICT_NB,
    DQ.STATE_NM,
    DQ.COUNTY_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)  AS LAST_UPDT_TS
FROM (
        SELECT
            SQ.ALLOCATED_ID,
            SQ.CMDTY_SRC_ID,
            SQ.CMDTY_SRC_EFCTV_DT,
            SQ.CMDTY_SRC_EXPR_DT,
            SQ.ALLOCATED_PCT,
            SQ.DISTRICT_NB,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ALCTD_CMDTY_SRC_NM)))    = 0 THEN ' ' ELSE RTRIM(SQ.ALCTD_CMDTY_SRC_NM)    END AS ALCTD_CMDTY_SRC_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_SRC_NM)))          = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_SRC_NM)          END AS CMDTY_SRC_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.GEOG_BASIN_NM)))         = 0 THEN ' ' ELSE RTRIM(SQ.GEOG_BASIN_NM)         END AS GEOG_BASIN_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_SRC_SUB_TYPE_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_SRC_SUB_TYPE_NM) END AS CMDTY_SRC_SUB_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.LABOR_TYPE_NM)))         = 0 THEN ' ' ELSE RTRIM(SQ.LABOR_TYPE_NM)         END AS LABOR_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATE_NM)))              = 0 THEN ' ' ELSE RTRIM(SQ.STATE_NM)              END AS STATE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COUNTY_NM)))             = 0 THEN ' ' ELSE RTRIM(SQ.COUNTY_NM)             END AS COUNTY_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_SRC_TYPE_NM)))     = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_SRC_TYPE_NM)     END AS CMDTY_SRC_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_TYPE_NM)))          = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_TYPE_NM)          END AS FUEL_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_SRC_STAT_TX)))     = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_SRC_STAT_TX)     END AS CMDTY_SRC_STAT_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.MSHA_NB)))               = 0 THEN ' ' ELSE RTRIM(SQ.MSHA_NB)               END AS MSHA_NB
        FROM {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_FDR') }} SQ  --USED FOR TESTING
        WHERE 'C' = 'C'
          AND SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
    ) DQ
    LEFT JOIN (
        SELECT MAX(d.CMDTY_SRC_KEY) AS CMDTY_SRC_KEY, d.CMDTY_SRC_ID
        FROM {{ source('GENDB01_FELADM','FEL_CMDTY_SRC_DIM') }} d
        GROUP BY d.CMDTY_SRC_ID
    ) LKP_KEY
      ON LKP_KEY.CMDTY_SRC_ID = DQ.CMDTY_SRC_ID
