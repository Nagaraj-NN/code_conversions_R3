-- ==========================================================================
-- Model      : FEL_COAL_RCPTS_QTY_QLTY_FACT_DEL
-- Mapping    : m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
-- Workflow   : wkf_FEL_COAL_DIM_FACT_DEL
-- Session    : s_m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
-- Target     : GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FACT
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- DELETE only. The fact key is resolved to a natural key through the
-- receipt dimension, then checked against the feeder. FIL_INACTIVE keeps
-- the rows whose lookup missed and UPD_DELETE issues DD_DELETE.
--
-- The model holds the key of every target row the mapping deletes, one
-- row per target row, and the post-hook removes exactly those rows. The
-- original predicate reads the target only through RECEIPT_KEY,
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
    alias='FEL_COAL_RCPTS_QTY_QLTY_FACT_DEL_SRC',
    meta={"mapping_name": "m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del", "workflow_name": "wkf_FEL_COAL_DIM_FACT_DEL", "session_name": "s_m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COAL_RCPTS_QTY_QLTY_FACT_DEL', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FACT')
    ],
    post_hook=[
        "DELETE FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_QTY_QLTY_FACT') }} TGT
     USING {{ this }} D
     WHERE EQUAL_NULL(TGT.RECEIPT_KEY, D.RECEIPT_KEY)",
        log_model_end(this, 'TBD_FEL_COAL_RCPTS_QTY_QLTY_FACT_DEL', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FACT')
    ]
) }}

SELECT
    TGT.RECEIPT_KEY
FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_QTY_QLTY_FACT') }} TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('GENDB01_FELADM','FEL_RECEIPT_DIM') }} D,
         {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_QTY_QLTY_FDR') }} F
    WHERE D.RECEIPT_KEY            = TGT.RECEIPT_KEY
      AND F.RECEIPT_ID             = D.RECEIPT_ID
      AND UPPER(TRIM(F.STATUS_TX)) = 'ACTIVE'
)
