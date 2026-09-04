/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_RECEIPT_DIM_del
 MAPPING   : m_FEL_RECEIPT_DIM_del
 OPERATION : DELETE only. FIL_INACTIVE keeps the dimension rows whose lookup
             missed, that is the rows with no ACTIVE feeder record, and UPD_DELETE
             issues DD_DELETE for them.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_RECEIPT_DIM   full read, no filter
 LOOKUP    : FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR
             keys RECEIPT_ID + STATUS_TX, matched against the constant 'ACTIVE'
             lookup SQL override PRESENT:
               SELECT F.RECEIPT_ID as RECEIPT_ID,
                      UPPER(TRIM(F.STATUS_TX)) as STATUS_TX
               FROM FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
 TARGET    : feladm.FEL_RECEIPT_DIM
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECEIPT_KEY. The captured run read 286655 rows.
             This session runs first in the workflow, so the fact deletes that
             follow resolve their keys against the already pruned dimension.
================================================================================
*/

DELETE FROM feladm.FEL_RECEIPT_DIM TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
    WHERE F.RECEIPT_ID             = TGT.RECEIPT_ID
      AND UPPER(TRIM(F.STATUS_TX)) = 'ACTIVE'
);
