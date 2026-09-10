-- ==========================================================================
-- Model      : FEL_ACCTG_INVTRY_LOC_DIM
-- Mapping    : m_FEL_ACCTG_INVTRY_LOC_DIM_ins
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_ACCTG_INVTRY_LOC_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM
-- Load type  : table + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT only. FILTRANS keeps the rows whose dimension lookup missed and
-- UPD_INSERT flags them DD_INSERT. There is no update path, so an existing
-- accounting inventory location is left untouched.
--
-- Insert only. The model holds the transformed source row set and the
-- post-hook inserts the rows the anti-join keeps.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_ACCTG_INVTRY_LOC_DIM_SRC',
    meta={"mapping_name": "m_FEL_ACCTG_INVTRY_LOC_DIM_ins", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_ACCTG_INVTRY_LOC_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_ACCTG_INVTRY_LOC_DIM', target_object='GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM')
    ],
    post_hook=[
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_ACCTG_INVTRY_LOC_DIM') }} (
         ACCTG_INVTRY_LOC_KEY,
         ACCTG_INVTRY_LOC_NM,
         INVTRY_CMDTY_TYPE_NM,
         INVTRY_CMDTY_NM,
         LAST_UPTD_TS
     )
     SELECT
         SRC.O_MAX_KEY,
         SRC.O_ACCTG_INV_LOC_NM_CAT,
         LEFT(SRC.CMDTY_TYPE, 30),
         SRC.CMDTY_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_ACCTG_INVTRY_LOC_DIM') }} ANV
         WHERE UPPER(TRIM(ANV.ACCTG_INVTRY_LOC_NM))  = SRC.O_ACCTG_INV_LOC_NM
           AND UPPER(TRIM(ANV.INVTRY_CMDTY_TYPE_NM)) = SRC.O_CMDTY_TYPE
           AND UPPER(TRIM(ANV.INVTRY_CMDTY_NM))      = SRC.O_CMDTY_NM
     )",
        log_model_end(this, 'TBD_FEL_ACCTG_INVTRY_LOC_DIM', target_object='GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM')
    ]
) }}

SELECT
    SQ.CMDTY_NM,
    SQ.CMDTY_TYPE,
    NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')'  AS O_ACCTG_INV_LOC_NM_CAT,
    UPPER(NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')') AS O_ACCTG_INV_LOC_NM,
    UPPER(LTRIM(RTRIM(SQ.CMDTY_NM)))                                                                 AS O_CMDTY_NM,
    UPPER(LTRIM(RTRIM(SQ.CMDTY_TYPE)))                                                               AS O_CMDTY_TYPE,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                                       AS LAST_UPDT_TS,
    NVL((SELECT MAX(ACCTG_INVTRY_LOC_KEY) FROM {{ source('GENDB01_FELADM','FEL_ACCTG_INVTRY_LOC_DIM') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCTG_INV_LOC_NM, SQ.CMDTY_NM, SQ.CMDTY_TYPE) AS O_MAX_KEY
FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_ACCT_INV_LOC_VW_TEST') }} SQ  --USED FOR TESTING
