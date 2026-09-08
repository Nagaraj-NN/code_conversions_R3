/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_RECEIPT_DIM_del
 MAPPING   : m_FEL_RECEIPT_DIM_del
 OPERATION : DELETE only. FIL_INACTIVE keeps the dimension rows whose lookup
             missed, that is the rows with no ACTIVE feeder record, and UPD_DELETE
             issues DD_DELETE for them.
--------------------------------------------------------------------------------
 SOURCE    : GENDB01.FELADM.FEL_RECEIPT_DIM
 LOOKUP    : GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR
 TARGET    : GENDB01.FELADM.FEL_RECEIPT_DIM
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no

[FEL.WF:wkf_FEL_COAL_DIM_FACT_DEL]
$DBConnection_Target=fel_GENDB001
$DBConnection_Source=fel_COMTRAC
================================================================================
*/

DELETE FROM GENDB01.FELADM.FEL_RECEIPT_DIM TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
    WHERE F.RECEIPT_ID             = TGT.RECEIPT_ID
      AND UPPER(TRIM(F.STATUS_TX)) = 'ACTIVE'
);
