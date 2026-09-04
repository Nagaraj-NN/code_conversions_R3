/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_CNSMN_FDR_del
 MAPPING   : m_FEL_COAL_CNSMN_FDR_del
 OPERATION : DELETE only. UPD_DELETE issues DD_DELETE for every row the source
             qualifier returns. Writer flags Delete YES, no update path.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_CNSMN_FDR   (the target read back through itself)
 LOOKUP    : none
 TARGET    : feladm.FEL_COAL_CNSMN_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS are declared on the mapping
             but NOT REFERENCED. The source filter uses a hardcoded 'INACTIVE'.
 SQ OVERRIDE : none. Mapping source filter UPPER(TRIM(STATUS_TX)) = 'INACTIVE',
               confirmed resolved in the session log RR_4010.
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The reader selects the key set first and the writer then deletes by
             RECLAIM_ID, so the driving set is expressed as its own subquery
             rather than as a direct predicate on the delete.
             The captured run read 0 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_CNSMN_FDR TGT
WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT RECLAIM_ID
        FROM feladm.FEL_COAL_CNSMN_FDR
        WHERE UPPER(TRIM(STATUS_TX)) = 'INACTIVE'
    ) SRC
    WHERE SRC.RECLAIM_ID = TGT.RECLAIM_ID
);
