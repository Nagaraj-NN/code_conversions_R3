-- ==========================================================================
-- Model      : PS_Z_CI_EST_F00_ATOMIC_AUDIT
-- Mapping    : m_ps_z_ci_est_f00_atomic_audit
-- Workflow   : wkf_LOAD_CI_ATOMIC_AUDIT
-- Source SQL : wkf_LOAD_CI_ATOMIC_AUDIT.sql, lines 63-103 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_EPM_AUDIT
-- Load type  : table + MERGE post-hook
-- --------------------------------------------------------------------------
-- Completes the latest CI_EST_ATOMIC audit row with the destination row
-- count and amount from PS_Z_CI_EST_F00. It finds that row by MAX(RUN_DT),
-- so it must run after PS_Z_CI_REV_DTLVW_AUDIT has inserted it.
--
-- The model is the validated MERGE's USING subquery and the post-hook is the
-- MERGE itself, reading the model. Two authored edge cases are kept:
--   - PS_Z_CI_EST_F00 empty: the GROUP BY returns no row, nothing is merged,
--     and the destination figures stay at the 0 the first MERGE wrote.
--   - no CI_EST_ATOMIC row at all: RUN_DT is NULL, the ON clause cannot
--     match, and a row with a NULL RUN_DT and no source figures is inserted.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_CI_EST_F00_ATOMIC_AUDIT_SRC',
    meta={"mapping_name": "m_ps_z_ci_est_f00_atomic_audit", "workflow_name": "wkf_LOAD_CI_ATOMIC_AUDIT"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CI_EST_F00_ATOMIC_AUDIT', target_object=target.database ~ '.EPMADM.PS_Z_EPM_AUDIT')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_EPM_AUDIT') }} AS T
     USING {{ this }} AS S
     ON T.TABLE_NAME = S.TABLE_NAME
     AND T.LEDGER = S.LEDGER
     AND T.RUN_DT = S.RUN_DT
     WHEN MATCHED THEN UPDATE SET
         T.Z_DEST_AMOUNT = S.Z_DEST_AMOUNT,
         T.Z_DEST_QUANTITY = S.Z_DEST_QUANTITY
     WHEN NOT MATCHED THEN INSERT
     (TABLE_NAME, LEDGER, RUN_DT, Z_DEST_AMOUNT, Z_DEST_QUANTITY)
     VALUES
     (S.TABLE_NAME, S.LEDGER, S.RUN_DT, S.Z_DEST_AMOUNT, S.Z_DEST_QUANTITY)",
        log_model_end(this, 'TBD_PS_Z_CI_EST_F00_ATOMIC_AUDIT', target_object=target.database ~ '.EPMADM.PS_Z_EPM_AUDIT')
    ]
) }}

SELECT
    'CI_EST_ATOMIC' AS TABLE_NAME,
    ' ' AS LEDGER,
    R.RUN_DT,
    SUM(F.AMOUNT) AS Z_DEST_AMOUNT,
    COUNT(*) AS Z_DEST_QUANTITY
FROM {{ source('CRPDB01_EPMADM','PS_Z_CI_EST_F00') }} AS F
CROSS JOIN
(
    SELECT
        MAX(A.RUN_DT) AS RUN_DT
    FROM {{ source('CRPDB01_EPMADM','PS_Z_EPM_AUDIT') }} AS A
    WHERE A.TABLE_NAME = 'CI_EST_ATOMIC'
) AS R
GROUP BY R.RUN_DT
