-- ==========================================================================
-- Model      : FEL_SAMPLED_DIM
-- Mapping    : m_FEL_SAMPLED_DIM_stat
-- Workflow   : wkf_FEL_STATIC_DIM_LOAD
-- Session    : s_m_FEL_SAMPLED_DIM_stat
-- Target     : GENDB01.FELADM.FEL_SAMPLED_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTRTRANS splits on the dimension lookup,
-- with no change test; DEFAULT1 is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_SAMPLED_DIM_SRC',
    meta={"mapping_name": "m_FEL_SAMPLED_DIM_stat", "workflow_name": "wkf_FEL_STATIC_DIM_LOAD", "session_name": "s_m_FEL_SAMPLED_DIM_stat"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_SAMPLED_DIM', target_object='GENDB01.FELADM.FEL_SAMPLED_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_SAMPLED_DIM') }} TGT
     SET
         SMPLD_RSN_TX = SRC.SMPLD_RSN_TX,
         SAMPLED_TX   = SRC.SAMPLED_TX,
         LAST_UPDT_TS = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE UPPER(TRIM(TGT.SMPLD_RSN_TX)) = SRC.TRIM_SMPLD_RSN_TX",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_SAMPLED_DIM') }} (
         SAMPLED_KEY,
         SMPLD_RSN_TX,
         SAMPLED_TX,
         LAST_UPDT_TS
     )
     SELECT
         NVL((SELECT MAX(SAMPLED_KEY) FROM {{ source('GENDB01_FELADM','FEL_SAMPLED_DIM') }}), 0)
             + ROW_NUMBER() OVER (ORDER BY SRC.SMPLD_RSN_TX)                           AS SAMPLED_KEY,
         SRC.SMPLD_RSN_TX,
         SRC.SAMPLED_TX,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_SAMPLED_DIM') }} S
         WHERE UPPER(TRIM(S.SMPLD_RSN_TX)) = SRC.TRIM_SMPLD_RSN_TX
     )",
        log_model_end(this, 'TBD_FEL_SAMPLED_DIM', target_object='GENDB01.FELADM.FEL_SAMPLED_DIM')
    ]
) }}

SELECT
    DQ.UNSMPLE_RSN_CDE                                           AS SMPLD_RSN_TX,
    IFF(DQ.UNSMPLE_RSN_CDE = 'Sampled', 'Sampled', 'Unsampled')  AS SAMPLED_TX,
    UPPER(DQ.UNSMPLE_RSN_CDE)                                    AS TRIM_SMPLD_RSN_TX,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                   AS LAST_UPDT_TS
FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COLVALUETEXT))) = 0 THEN ' ' ELSE RTRIM(SQ.COLVALUETEXT) END AS UNSMPLE_RSN_CDE
        FROM (
            SELECT t.COLVALUETEXT
            FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','PERMVALUE_TEST') }} t  --USED FOR TESTING
            WHERE t.tablename = 'sampleproblem'
              AND t.colname   = 'missedsamplereason'
            UNION
            SELECT 'Sampled'
        ) SQ
    ) DQ
