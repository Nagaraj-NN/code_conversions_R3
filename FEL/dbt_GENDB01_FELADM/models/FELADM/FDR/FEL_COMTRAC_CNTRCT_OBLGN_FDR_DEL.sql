-- ==========================================================================
-- Model      : FEL_COMTRAC_CNTRCT_OBLGN_FDR_DEL
-- Mapping    : m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
-- Workflow   : wkf_FEL_COAL_DIM_FACT_DEL
-- Session    : s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
-- Target     : GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- DELETE only. FILTRANS keeps the rows whose lookup missed, that is the
-- FDR rows that no longer exist in the Comtrac source view, and UPD_DELETE
-- issues DD_DELETE for them.
--
-- The model holds the key of every target row the mapping deletes, one
-- row per target row, and the post-hook removes exactly those rows. The
-- original predicate reads the target only through CNTRCT_DTL_ID, FACILITY_ID, CNTRCT_DTL_OPRTG_DT,
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
    alias='FEL_COMTRAC_CNTRCT_OBLGN_FDR_DEL_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del", "workflow_name": "wkf_FEL_COAL_DIM_FACT_DEL", "session_name": "s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COMTRAC_CNTRCT_OBLGN_FDR_DEL', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR')
    ],
    post_hook=[
        "DELETE FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} TGT
     USING {{ this }} D
     WHERE EQUAL_NULL(TGT.CNTRCT_DTL_ID, D.CNTRCT_DTL_ID)
       AND EQUAL_NULL(TGT.FACILITY_ID, D.FACILITY_ID)
       AND EQUAL_NULL(TGT.CNTRCT_DTL_OPRTG_DT, D.CNTRCT_DTL_OPRTG_DT)",
        log_model_end(this, 'TBD_FEL_COMTRAC_CNTRCT_OBLGN_FDR_DEL', target_object='GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR')
    ]
) }}

SELECT
    TGT.CNTRCT_DTL_ID,
    TGT.FACILITY_ID,
    TGT.CNTRCT_DTL_OPRTG_DT
FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_CONTRACT_OBLIGATIONS_VW_TEST') }} VW  --USED FOR TESTING
    WHERE VW.CNTRCTDTL_ID     = TGT.CNTRCT_DTL_ID 
      AND VW.FCLTY_ID         = IFF(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END IS NULL, NULL,
                                    COALESCE(TRY_TO_NUMBER(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END), 0))
      AND VW.CONTRCTDTL_OB_DT = TGT.CNTRCT_DTL_OPRTG_DT
)
