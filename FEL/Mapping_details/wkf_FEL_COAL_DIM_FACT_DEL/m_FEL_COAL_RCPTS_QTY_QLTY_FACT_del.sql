/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
 MAPPING   : m_FEL_COAL_RCPTS_QTY_QLTY_FACT_del
 OPERATION : DELETE only. The fact key is resolved to a natural key through the
             receipt dimension, then checked against the feeder. FIL_INACTIVE keeps
             the rows whose lookup missed and UPD_DELETE issues DD_DELETE.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FACT   full read, no filter
 LOOKUPS   : feladm.FEL_RECEIPT_DIM               RECEIPT_KEY -> RECEIPT_ID, no override
             FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR   RECEIPT_ID + STATUS_TX = 'ACTIVE'
             lookup SQL override PRESENT on the feeder:
               SELECT F.RECEIPT_ID as RECEIPT_ID,
                      UPPER(TRIM(F.STATUS_TX)) as STATUS_TX
               FROM FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
 TARGET    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FACT
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECEIPT_KEY. A fact row whose RECEIPT_KEY is absent
             from the receipt dimension fails the first lookup, so the second
             lookup misses too and the row is deleted. That chain is preserved by
             requiring both joins to succeed.
             The captured run read 286655 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_RECEIPT_DIM D,
         FELADM.FEL_COAL_RCPTS_QTY_QLTY_FDR F
    WHERE D.RECEIPT_KEY            = TGT.RECEIPT_KEY
      AND F.RECEIPT_ID             = D.RECEIPT_ID
      AND UPPER(TRIM(F.STATUS_TX)) = 'ACTIVE'
);
