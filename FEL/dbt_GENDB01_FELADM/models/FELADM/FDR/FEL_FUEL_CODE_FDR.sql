-- ==========================================================================
-- Model      : FEL_FUEL_CODE_FDR
-- Mapping    : m_FEL_FUEL_CODE_FDR_ff_ins
-- Workflow   : wkf_FEL_STATIC_DIM_LOAD
-- Session    : s_m_FEL_FUEL_CODE_FDR_ins
-- Target     : GENDB01.FELADM.FEL_FUEL_CODE_FDR
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- TRUNCATE + INSERT, full reload. Treat source rows as Insert, no router
-- and no update strategy.
--
-- Full reload. The Informatica writer carried Truncate target table
-- option = YES, run by the PRE-SESS thread ahead of the load, so the
-- truncate is a pre-hook here and the model itself is the target.
-- ==========================================================================

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_FEL_FUEL_CODE_FDR_ff_ins", "workflow_name": "wkf_FEL_STATIC_DIM_LOAD", "session_name": "s_m_FEL_FUEL_CODE_FDR_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_FUEL_CODE_FDR', target_object='GENDB01.FELADM.FEL_FUEL_CODE_FDR'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_FUEL_CODE_FDR', target_object='GENDB01.FELADM.FEL_FUEL_CODE_FDR')
    ]
) }}

SELECT
    SRC.FUEL_CODE         AS FUEL_CD,
    SRC.O_FUEL_CODE_DESC  AS FUEL_CD_DESCN_TX,
    SRC.LAST_UPDT_TS      AS LAST_UPDT_TS
FROM (
    SELECT
        DQ.FUEL_CODE,
        LEFT(IFF(DQ.FUEL_NAME IS NULL, 'UNKNOWN', DQ.FUEL_NAME), 100)                AS O_FUEL_CODE_DESC,
        CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                                             AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_CODE))) = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_CODE) END AS FUEL_CODE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_NAME))) = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_NAME) END AS FUEL_NAME
        FROM (
            SELECT
                LEFT($1, 2)   AS FUEL_CODE,
                LEFT($2, 100) AS FUEL_NAME
            -- FROM @FEL_INBOUND_STAGE/FuelCodes.csv
            FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','FUELCODES_TEST') }}  --USED FOR TESTING
                -- COMMENTED OUT AS SRC IS CREATED AS A TABLE
                --  (FILE_FORMAT => (TYPE = CSV
                --                   FIELD_DELIMITER = ','
                --                   FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                --                   SKIP_HEADER = 0
                --                   NULL_IF = ('*')
                --                   TRIM_SPACE = FALSE
                --                   ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
) SRC
WHERE SRC.FUEL_CODE IS NOT NULL
