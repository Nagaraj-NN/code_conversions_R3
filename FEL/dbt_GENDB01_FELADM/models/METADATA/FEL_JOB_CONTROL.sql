-- ==========================================================================
-- Model      : FEL_JOB_CONTROL
-- Target     : GENDB01.METADATA.FEL_JOB_CONTROL
-- Load type  : incremental / merge on JOB_NAME
-- --------------------------------------------------------------------------
-- Merges seeds/FEL_JOB_CONTROL_SEEDS.csv into the run-window control table.
-- No FELADM model reads this table yet: every model reproduces the frozen
-- literals of its validated script. parameters.text lists the 22 models whose
-- windows are meant to come from here and the exact steps to switch them over.
-- ==========================================================================

{{ config(
    materialized='incremental',
    schema='METADATA',
    alias='FEL_JOB_CONTROL',
    unique_key='JOB_NAME',
    incremental_strategy='merge',
    full_refresh=false,
    pre_hook=[
        log_model_start(this, 'TBD_FEL_JOB_CONTROL', target_object='GENDB01.METADATA.FEL_JOB_CONTROL')
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_JOB_CONTROL', target_object='GENDB01.METADATA.FEL_JOB_CONTROL')
    ]
) }}

-- On the very first run the control table has no rows yet (a fresh CI schema,
-- or a brand-new dev deploy). is_incremental() is false in that case and this
-- CTE stands in as an empty target, which makes every seed row fall through
-- the LEFT JOIN unchanged.
WITH TGT_EXISTING AS (

    {% if is_incremental() %}

        SELECT
            JOB_ID,
            JOB_NAME,
            AUTOSYS_JOB_NAME,
            START_DATE,
            END_DATE,
            PREV_START_DATE,
            PREV_END_DATE
        FROM {{ source('GENDB01_METADATA', 'FEL_JOB_CONTROL') }}

    {% else %}

        -- Shaped from the seed so the COALESCE pairs below compare identical
        -- types, and zero rows so every seed row survives the LEFT JOIN.
        -- JOB_ID is cast because the seed types it varchar(50) while the table
        -- types it NUMBER(30,0).
        SELECT
            JOB_ID::NUMBER(30, 0) AS JOB_ID,
            JOB_NAME,
            AUTOSYS_JOB_NAME,
            NULL::TIMESTAMP_NTZ(9) AS START_DATE,
            NULL::TIMESTAMP_NTZ(9) AS END_DATE,
            NULL::TIMESTAMP_NTZ(9) AS PREV_START_DATE,
            NULL::TIMESTAMP_NTZ(9) AS PREV_END_DATE
        FROM {{ ref('FEL_JOB_CONTROL_SEEDS') }}
        WHERE 1 = 0

    {% endif %}
)

SELECT
    COALESCE(TGT.JOB_ID, SRC.JOB_ID::NUMBER(30, 0))   AS JOB_ID,
    COALESCE(SRC.JOB_NAME, TGT.JOB_NAME)              AS JOB_NAME,
    COALESCE(SRC.AUTOSYS_JOB_NAME, TGT.AUTOSYS_JOB_NAME) AS AUTOSYS_JOB_NAME,

    -- A brand-new job starts at the full-history anchor so its first run
    -- backfills instead of picking up only the last day. A job already in the
    -- table keeps the watermark it has: this SELECT also fires when a seed
    -- row's AUTOSYS_JOB_NAME is corrected, and that must not rewind or skip
    -- the job's window.
    COALESCE(TGT.START_DATE, '2008-01-01 00:00:00.000'::TIMESTAMP_NTZ(9)) AS START_DATE,
    COALESCE(TGT.END_DATE, CURRENT_TIMESTAMP())       AS END_DATE,

    TGT.PREV_START_DATE                               AS PREV_START_DATE,
    TGT.PREV_END_DATE                                 AS PREV_END_DATE,
    1                                                 AS RUN_WINDOW,
    CURRENT_TIMESTAMP()                               AS ROW_CREATE_TIMESTAMP,
    CURRENT_TIMESTAMP()                               AS ROW_UPDATE_TIMESTAMP

FROM {{ ref('FEL_JOB_CONTROL_SEEDS') }} AS SRC

LEFT JOIN TGT_EXISTING AS TGT
    ON UPPER(SRC.JOB_NAME) = UPPER(TGT.JOB_NAME)

WHERE DECODE(TGT.AUTOSYS_JOB_NAME, SRC.AUTOSYS_JOB_NAME, 1, 0) = 0
