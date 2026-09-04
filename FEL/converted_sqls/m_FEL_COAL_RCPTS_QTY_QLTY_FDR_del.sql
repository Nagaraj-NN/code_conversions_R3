/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_QTY_QLTY_FDR_del
 MAPPING   : m_FEL_COAL_RCPTS_QTY_QLTY_FDR_del
 OPERATION : DELETE only. UPD_DELETE issues DD_DELETE for every row the source
             qualifier returns. Writer flags Delete YES, no insert or update path.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR   (the target read back through itself)
 LOOKUP    : none
 TARGET    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS are declared on the mapping
             but NOT REFERENCED. The source filter uses a hardcoded 'INACTIVE'.
 SQ OVERRIDE : none. Mapping source filter UPPER(TRIM(STATUS_TX)) = 'INACTIVE',
               confirmed resolved in the session log RR_4010.
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECEIPT_ID. The captured run read 23 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT RECEIPT_ID
        FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECEIPT_ID = TGT.RECEIPT_ID
);
