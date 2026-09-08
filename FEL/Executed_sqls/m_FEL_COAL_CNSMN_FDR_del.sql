/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_CNSMN_FDR_del
 MAPPING   : m_FEL_COAL_CNSMN_FDR_del
 OPERATION : DELETE only. UPD_DELETE issues DD_DELETE for every row the source
             qualifier returns. Writer flags Delete YES, no update path.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_CNSMN_FDR   (the target read back through itself)
             GENDB01.FELADM.FEL_COAL_CNSMN_FDR  (Used for testing)
 LOOKUP    : none
 TARGET    : feladm.FEL_COAL_CNSMN_FDR
             GENDB01.FELADM.FEL_COAL_CNSMN_FDR  (Used for testing)
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS are declared on the mapping
             but NOT REFERENCED. The source filter uses a hardcoded 'INACTIVE'.
 SQ OVERRIDE : none. Mapping source filter UPPER(TRIM(STATUS_TX)) = 'INACTIVE',
               confirmed resolved in the session log RR_4010.
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no

 [FEL.WF:wkf_FEL_COAL_DIM_FACT_DEL]
 $DBConnection_Target=fel_GENDB001
 $DBConnection_Source=fel_COMTRAC
--------------------------------------------------------------------------------

================================================================================
*/

DELETE FROM GENDB01.FELADM.FEL_COAL_CNSMN_FDR TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT RECLAIM_ID
        FROM GENDB01.FELADM.FEL_COAL_CNSMN_FDR
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECLAIM_ID = TGT.RECLAIM_ID
);
