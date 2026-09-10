/***************************/
--Errors
--				SQL compilation error: Object 'CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_CI_REV_DTLVW' does not exist or not authorized.

-- =============================================================================
-- Workflow Name: wkf_LOAD_CI_ATOMIC_AUDIT
-- Mappings Name: m_ps_z_ci_rev_dtlvw_audit, m_ps_z_ci_est_f00_atomic_audit
-- List of Other tasks: 
-- =============================================================================
 
-- DEVELOPER : Neelakanta
-- LAST UPDATED : 24/08/2026
 
--LOGIC: Capture source count and amount from PS_Z_CI_REV_DTLVW, insert or update the CI_EST_ATOMIC audit row, then capture destination count and amount from PS_Z_CI_EST_F00 and update the same audit row using the maximum audit run date
--SOURCE Tables: PS_Z_CI_REV_DTLVW, PS_Z_CI_EST_F00, PS_Z_EPM_AUDIT
--TARGET TABLE: PS_Z_EPM_AUDIT
--PRE SQL :
--POST SQL :
--Parameters used : 

MERGE INTO CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_EPM_AUDIT AS T
USING
(
    SELECT
        'CI_EST_ATOMIC' AS TABLE_NAME,
        ' ' AS LEDGER,
        CURRENT_TIMESTAMP() AS RUN_DT,
        SUM(S.AMOUNT) AS Z_SRC_AMOUNT,
        0 AS Z_DEST_AMOUNT,
        COUNT(*) AS Z_SRC_QUANTITY,
        0 AS Z_DEST_QUANTITY
    FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_CI_REV_DTLVW AS S
) AS S
ON T.TABLE_NAME = S.TABLE_NAME
AND T.LEDGER = S.LEDGER
AND T.RUN_DT = S.RUN_DT
WHEN MATCHED THEN UPDATE SET
    T.Z_SRC_AMOUNT = S.Z_SRC_AMOUNT,
    T.Z_DEST_AMOUNT = S.Z_DEST_AMOUNT,
    T.Z_SRC_QUANTITY = S.Z_SRC_QUANTITY,
    T.Z_DEST_QUANTITY = S.Z_DEST_QUANTITY
WHEN NOT MATCHED THEN INSERT
(
    TABLE_NAME,
    LEDGER,
    RUN_DT,
    Z_SRC_AMOUNT,
    Z_DEST_AMOUNT,
    Z_SRC_QUANTITY,
    Z_DEST_QUANTITY
)
VALUES
(
    S.TABLE_NAME,
    S.LEDGER,
    S.RUN_DT,
    S.Z_SRC_AMOUNT,
    S.Z_DEST_AMOUNT,
    S.Z_SRC_QUANTITY,
    S.Z_DEST_QUANTITY
);

MERGE INTO CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_EPM_AUDIT AS T
USING
(
    SELECT
        'CI_EST_ATOMIC' AS TABLE_NAME,
        ' ' AS LEDGER,
        R.RUN_DT,
        SUM(F.AMOUNT) AS Z_DEST_AMOUNT,
        COUNT(*) AS Z_DEST_QUANTITY
    FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_CI_EST_F00 AS F
    CROSS JOIN
    (
        SELECT
            MAX(A.RUN_DT) AS RUN_DT
        FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_EPM_AUDIT AS A
        WHERE A.TABLE_NAME = 'CI_EST_ATOMIC'
    ) AS R
    GROUP BY R.RUN_DT
) AS S
ON T.TABLE_NAME = S.TABLE_NAME
AND T.LEDGER = S.LEDGER
AND T.RUN_DT = S.RUN_DT
WHEN MATCHED THEN UPDATE SET
    T.Z_DEST_AMOUNT = S.Z_DEST_AMOUNT,
    T.Z_DEST_QUANTITY = S.Z_DEST_QUANTITY
WHEN NOT MATCHED THEN INSERT
(
    TABLE_NAME,
    LEDGER,
    RUN_DT,
    Z_DEST_AMOUNT,
    Z_DEST_QUANTITY
)
VALUES
(
    S.TABLE_NAME,
    S.LEDGER,
    S.RUN_DT,
    S.Z_DEST_AMOUNT,
    S.Z_DEST_QUANTITY
);
