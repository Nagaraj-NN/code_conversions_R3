-- ==========================================================================
-- Model      : FEL_COAL_CNSMN_FDR_DEL
-- Mapping    : m_FEL_COAL_CNSMN_FDR_del
-- Workflow   : wkf_FEL_COAL_DIM_FACT_DEL
-- Session    : s_m_FEL_COAL_CNSMN_FDR_del
-- Target     : GENDB01.FELADM.FEL_COAL_CNSMN_FDR
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- DELETE only. UPD_DELETE issues DD_DELETE for every row the source
-- qualifier returns. Writer flags Delete YES, no update path.
--
-- The model holds the key of every target row the mapping deletes, one
-- row per target row, and the post-hook removes exactly those rows. The
-- original predicate reads the target only through RECLAIM_ID,
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
    alias='FEL_COAL_CNSMN_FDR_DEL_SRC',
    meta={"mapping_name": "m_FEL_COAL_CNSMN_FDR_del", "workflow_name": "wkf_FEL_COAL_DIM_FACT_DEL", "session_name": "s_m_FEL_COAL_CNSMN_FDR_del"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COAL_CNSMN_FDR_DEL', target_object='GENDB01.FELADM.FEL_COAL_CNSMN_FDR')
    ],
    post_hook=[
        "DELETE FROM {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }} TGT
     USING {{ this }} D
     WHERE EQUAL_NULL(TGT.RECLAIM_ID, D.RECLAIM_ID)",
        log_model_end(this, 'TBD_FEL_COAL_CNSMN_FDR_DEL', target_object='GENDB01.FELADM.FEL_COAL_CNSMN_FDR')
    ]
) }}

SELECT
    TGT.RECLAIM_ID
FROM {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }} TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT RECLAIM_ID
        FROM {{ source('GENDB01_FELADM','FEL_COAL_CNSMN_FDR') }}
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECLAIM_ID = TGT.RECLAIM_ID
)
