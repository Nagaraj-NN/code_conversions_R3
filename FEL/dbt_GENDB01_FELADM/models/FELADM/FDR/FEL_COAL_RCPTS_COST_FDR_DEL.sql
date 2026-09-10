-- ==========================================================================
-- Model      : FEL_COAL_RCPTS_COST_FDR_DEL
-- Mapping    : m_FEL_COAL_RCPTS_COST_FDR_del
-- Workflow   : wkf_FEL_COAL_DIM_FACT_DEL
-- Session    : s_m_FEL_COAL_RCPTS_COST_FDR_del
-- Target     : GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- DELETE only. UPD_DELETE issues DD_DELETE for every row the source
-- qualifier returns. Writer flags Delete YES, no insert or update path.
--
-- The model holds the key of every target row the mapping deletes, one
-- row per target row, and the post-hook removes exactly those rows. The
-- original predicate reads the target only through RECEIPT_ID, CST_CMPNT_CD,
-- so selecting those keys and deleting on them is the same set as the
-- correlated DELETE. EQUAL_NULL keeps a NULL key matching, as before.
--
-- Materialised as a table, not a view, so the key set is snapshotted
-- before the DELETE runs and RECORDS_PROCESSED can count it afterwards.
-- Duplicate keys are kept rather than DISTINCT-ed so the count is the
-- exact number of rows removed; DELETE ... USING removes a target row
-- once however many times it matches.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COAL_RCPTS_COST_FDR_DEL_SRC',
    meta={"mapping_name": "m_FEL_COAL_RCPTS_COST_FDR_del", "workflow_name": "wkf_FEL_COAL_DIM_FACT_DEL", "session_name": "s_m_FEL_COAL_RCPTS_COST_FDR_del"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COAL_RCPTS_COST_FDR_DEL', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR')
    ],
    post_hook=[
        "DELETE FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} TGT
     USING {{ this }} D
     WHERE EQUAL_NULL(TGT.RECEIPT_ID, D.RECEIPT_ID)
       AND EQUAL_NULL(TGT.CST_CMPNT_CD, D.CST_CMPNT_CD)",
        log_model_end(this, 'TBD_FEL_COAL_RCPTS_COST_FDR_DEL', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR')
    ]
) }}

SELECT
    TGT.RECEIPT_ID,
    TGT.CST_CMPNT_CD
FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT
            RECEIPT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(CST_CMPNT_CD))) = 0 THEN ' ' ELSE RTRIM(CST_CMPNT_CD) END AS CST_CMPNT_CD
        FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }}
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECEIPT_ID   = TGT.RECEIPT_ID
      AND SRC.CST_CMPNT_CD = TGT.CST_CMPNT_CD
)
