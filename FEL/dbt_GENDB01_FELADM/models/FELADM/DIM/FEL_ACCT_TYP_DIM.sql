-- ==========================================================================
-- Model      : FEL_ACCT_TYP_DIM
-- Mapping    : m_FEL_ACCT_TYP_DIM_ins
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_ACCT_TYP_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_ACCT_TYP_DIM
-- Load type  : table + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT only. RTR_INS_UPT has a NEW group on the dimension lookup and an
-- unconnected DEFAULT1 group; only UPD_INSERT is wired, so despite the
-- session name no update is ever issued.
--
-- Insert only. The model holds the transformed source row set and the
-- post-hook inserts the rows the anti-join keeps.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_ACCT_TYP_DIM_SRC',
    meta={"mapping_name": "m_FEL_ACCT_TYP_DIM_ins", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_ACCT_TYP_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_ACCT_TYP_DIM', target_object='GENDB01.FELADM.FEL_ACCT_TYP_DIM')
    ],
    post_hook=[
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_ACCT_TYP_DIM') }} (
         ACCT_TYP_KEY,
         ACCT_TYP_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.O_ACCT_TYPE_KEY,
         SRC.ACCTG_TYP_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_ACCT_TYP_DIM') }} DIM
         WHERE UPPER(TRIM(DIM.ACCT_TYP_NM)) = SRC.O_TRIM_ACCT_TYPE_NM
     )",
        log_model_end(this, 'TBD_FEL_ACCT_TYP_DIM', target_object='GENDB01.FELADM.FEL_ACCT_TYP_DIM')
    ]
) }}

SELECT
    SQ.ACCT_TYP_NM                              AS ACCTG_TYP_NM,
    UPPER(LTRIM(RTRIM(SQ.ACCT_TYP_NM)))         AS O_TRIM_ACCT_TYPE_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)  AS LAST_UPDT_TS,
    NVL((SELECT MAX(ACCT_TYP_KEY) FROM {{ source('GENDB01_FELADM','FEL_ACCT_TYP_DIM') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCT_TYP_NM) AS O_ACCT_TYPE_KEY
FROM (
        SELECT DISTINCT FEL_FV_TRANS_FDR.ACCT_TYP_NM
        FROM {{ source('GENDB01_FELADM','FEL_FV_TRANS_FDR') }}
    ) SQ
