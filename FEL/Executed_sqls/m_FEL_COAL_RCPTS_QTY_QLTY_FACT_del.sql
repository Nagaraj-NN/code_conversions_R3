/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
 MAPPING   : m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
 OPERATION : DELETE only. The fact key is resolved to a natural key through the
             receipt dimension, then checked against the feeder. FIL_INACTIVE keeps
             the rows whose lookup missed and UPD_DELETE issues DD_DELETE.
--------------------------------------------------------------------------------
 SOURCE    : GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR   full read, no filter
 LOOKUPS   : GENDB01.FELADM.FEL_RECEIPT_DIM
 TARGET    : GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FACT
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
================================================================================
*/

DELETE FROM GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_RECEIPT_DIM D,
         GENDB01.FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
    WHERE D.RECEIPT_KEY            = TGT.RECEIPT_KEY
      AND F.RECEIPT_ID             = D.RECEIPT_ID
      AND UPPER(TRIM(F.STATUS_TX)) = 'ACTIVE'
);
