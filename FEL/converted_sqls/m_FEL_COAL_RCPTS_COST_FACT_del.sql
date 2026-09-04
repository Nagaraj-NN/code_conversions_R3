/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_COST_FACT_del
 MAPPING   : m_FEL_COAL_RCPTS_COST_FACT_del
 OPERATION : DELETE only. Both fact keys are resolved to natural keys through their
             dimensions, then checked against the feeder. FIL_INACTIVE keeps the
             rows whose lookup missed and UPD_DELETE issues DD_DELETE.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_RCPTS_COST_FACT   full read, no filter
 LOOKUPS   : feladm.FEL_RECEIPT_DIM       RECEIPT_KEY   -> RECEIPT_ID,   no override
             feladm.FEL_COST_CMPNT_DIM    CST_CMPNT_KEY -> CST_CMPNT_CD, no override
             feladm.FEL_COAL_RCPTS_COST_FDR
             keys RECEIPT_ID + CST_CMPNT_CD + STATUS_TX = 'ACTIVE'
             lookup SQL override PRESENT on the feeder:
               SELECT F.RECEIPT_ID as RECEIPT_ID,
                      UPPER(TRIM(F.CST_CMPNT_CD)) as CST_CMPNT_CD,
                      UPPER(TRIM(F.STATUS_TX)) as STATUS_TX
               FROM feladm.FEL_COAL_RCPTS_COST_FDR F
 TARGET    : feladm.FEL_COAL_RCPTS_COST_FACT
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECEIPT_KEY and CST_CMPNT_KEY.
             The two sides of the cost component comparison are not symmetric.
             EXPTRANS.trim_CST_CMPNT_CD applies UPPER only, despite its name, while
             the feeder override applies UPPER(TRIM(...)). Reproduced as written,
             so a dimension code with trailing spaces will not match.
             The captured run read 787520 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_RCPTS_COST_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_RECEIPT_DIM RD,
         feladm.FEL_COST_CMPNT_DIM CD,
         feladm.FEL_COAL_RCPTS_COST_FDR F
    WHERE RD.RECEIPT_KEY                = TGT.RECEIPT_KEY
      AND CD.CST_CMPNT_KEY              = TGT.CST_CMPNT_KEY
      AND F.RECEIPT_ID                  = RD.RECEIPT_ID
      AND UPPER(TRIM(F.CST_CMPNT_CD))   = UPPER(CD.CST_CMPNT_CD)
      AND UPPER(TRIM(F.STATUS_TX))      = 'ACTIVE'
);
