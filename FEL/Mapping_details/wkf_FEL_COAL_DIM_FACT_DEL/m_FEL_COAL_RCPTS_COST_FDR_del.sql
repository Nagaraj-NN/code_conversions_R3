/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_RCPTS_COST_FDR_del
 MAPPING   : m_FEL_COAL_RCPTS_COST_FDR_del
 OPERATION : DELETE only. UPD_DELETE issues DD_DELETE for every row the source
             qualifier returns. Writer flags Delete YES, no insert or update path.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_RCPTS_COST_FDR   (the target read back through itself)
 LOOKUP    : none
 TARGET    : feladm.FEL_COAL_RCPTS_COST_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS are declared on the mapping
             but NOT REFERENCED. The source filter uses a hardcoded 'INACTIVE'.
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none. Mapping source filter UPPER(TRIM(STATUS_TX)) = 'INACTIVE',
               confirmed resolved in the session log RR_4010.
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECEIPT_ID and CST_CMPNT_CD. The cost component code
             passes through the data quality function first, so the delete matches
             on the right trimmed value, not on the raw stored value.
             The captured run read 113 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_RCPTS_COST_FDR TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT
            RECEIPT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(CST_CMPNT_CD))) = 0 THEN ' ' ELSE RTRIM(CST_CMPNT_CD) END AS CST_CMPNT_CD
        FROM feladm.FEL_COAL_RCPTS_COST_FDR
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECEIPT_ID   = TGT.RECEIPT_ID
      AND SRC.CST_CMPNT_CD = TGT.CST_CMPNT_CD
);
