-- ==========================================================================
-- Model      : PS_Z_CI_REV_DTLVW_AUDIT
-- Mapping    : m_ps_z_ci_rev_dtlvw_audit
-- Workflow   : wkf_LOAD_CI_ATOMIC_AUDIT
-- Source SQL : wkf_LOAD_CI_ATOMIC_AUDIT.sql, lines 21-61 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_EPM_AUDIT
-- Load type  : table + MERGE post-hook
-- --------------------------------------------------------------------------
-- Opens today's CI_EST_ATOMIC audit row: source row count and amount from
-- PS_Z_CI_REV_DTLVW, destination count and amount zeroed until
-- PS_Z_CI_EST_F00_ATOMIC_AUDIT fills them in.
--
-- The model is the validated MERGE's USING subquery and the post-hook is the
-- MERGE itself, reading the model. RUN_DT is the current timestamp, so WHEN
-- MATCHED fires only if a row with that exact timestamp already exists - in
-- practice this always inserts. Kept as authored.
--
-- PS_Z_EPM_AUDIT is written by both audit models and, by its name, shared
-- with other EPM loads, which is why dbt does not own it as an incremental.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_CI_REV_DTLVW_AUDIT_SRC',
    meta={"mapping_name": "m_ps_z_ci_rev_dtlvw_audit", "workflow_name": "wkf_LOAD_CI_ATOMIC_AUDIT"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CI_REV_DTLVW_AUDIT', target_object=target.database ~ '.EPMADM.PS_Z_EPM_AUDIT')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_EPM_AUDIT') }} AS T
     USING {{ this }} AS S
     ON T.TABLE_NAME = S.TABLE_NAME
     AND T.LEDGER = S.LEDGER
     AND T.RUN_DT = S.RUN_DT
     WHEN MATCHED THEN UPDATE SET
         T.Z_SRC_AMOUNT = S.Z_SRC_AMOUNT,
         T.Z_DEST_AMOUNT = S.Z_DEST_AMOUNT,
         T.Z_SRC_QUANTITY = S.Z_SRC_QUANTITY,
         T.Z_DEST_QUANTITY = S.Z_DEST_QUANTITY
     WHEN NOT MATCHED THEN INSERT
     (TABLE_NAME, LEDGER, RUN_DT, Z_SRC_AMOUNT, Z_DEST_AMOUNT, Z_SRC_QUANTITY, Z_DEST_QUANTITY)
     VALUES
     (S.TABLE_NAME, S.LEDGER, S.RUN_DT, S.Z_SRC_AMOUNT, S.Z_DEST_AMOUNT, S.Z_SRC_QUANTITY, S.Z_DEST_QUANTITY)",
        log_model_end(this, 'TBD_PS_Z_CI_REV_DTLVW_AUDIT', target_object=target.database ~ '.EPMADM.PS_Z_EPM_AUDIT')
    ]
) }}

SELECT
    'CI_EST_ATOMIC' AS TABLE_NAME,
    ' ' AS LEDGER,
    CURRENT_TIMESTAMP() AS RUN_DT,
    SUM(S.AMOUNT) AS Z_SRC_AMOUNT,
    0 AS Z_DEST_AMOUNT,
    COUNT(*) AS Z_SRC_QUANTITY,
    0 AS Z_DEST_QUANTITY
FROM {{ source('CI_PSFT_SOURCE','PS_Z_CI_REV_DTLVW') }} AS S
