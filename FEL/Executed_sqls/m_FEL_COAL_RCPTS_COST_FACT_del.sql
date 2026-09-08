/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_COST_FACT_del
 MAPPING   : m_FEL_COAL_RCPTS_COST_FACT_del
 OPERATION : DELETE only. Both fact keys are resolved to natural keys through their
             dimensions, then checked against the feeder. FIL_INACTIVE keeps the
             rows whose lookup missed and UPD_DELETE issues DD_DELETE.
--------------------------------------------------------------------------------
 SOURCE    : GENDB01.FELADM.FEL_COAL_RCPTS_COST_FACT   full read, no filter
 LOOKUPS   : GENDB01.FELADM.FEL_RECEIPT_DIM     
             GENDB01.FELADM.FEL_COST_CMPNT_DIM    
             GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR
             keys RECEIPT_ID + CST_CMPNT_CD + STATUS_TX = 'ACTIVE'
             lookup SQL override PRESENT on the feeder:
               SELECT F.RECEIPT_ID as RECEIPT_ID,
                      UPPER(TRIM(F.CST_CMPNT_CD)) as CST_CMPNT_CD,
                      UPPER(TRIM(F.STATUS_TX)) as STATUS_TX
               FROM GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR F
 TARGET    : GENDB01.FELADM.FEL_COAL_RCPTS_COST_FACT
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
================================================================================
*/

DELETE FROM GENDB01.FELADM.FEL_COAL_RCPTS_COST_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_RECEIPT_DIM RD,
         GENDB01.FELADM.FEL_COST_CMPNT_DIM CD,
         GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR F
    WHERE RD.RECEIPT_KEY                = TGT.RECEIPT_KEY
      AND CD.CST_CMPNT_KEY              = TGT.CST_CMPNT_KEY
      AND F.RECEIPT_ID                  = RD.RECEIPT_ID
      AND UPPER(TRIM(F.CST_CMPNT_CD))   = UPPER(CD.CST_CMPNT_CD)
      AND UPPER(TRIM(F.STATUS_TX))      = 'ACTIVE'
);
