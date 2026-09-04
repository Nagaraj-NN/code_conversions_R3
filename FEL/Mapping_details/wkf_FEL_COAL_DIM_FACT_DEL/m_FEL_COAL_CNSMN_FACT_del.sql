/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COAL_CNSMN_FACT_del
 MAPPING   : m_FEL_COAL_CNSMN_FACT_del
 OPERATION : DELETE only. FIL_INACTIVE keeps the fact rows whose lookup missed,
             that is the rows with no ACTIVE feeder record, and UPD_DELETE issues
             DD_DELETE for them. The session also has Insert YES and Update as
             Update YES, but the mapping flags every row DD_DELETE, so the writer
             logs the insert and update statements and never uses them.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_CNSMN_FACT   full read, no filter
 LOOKUP    : feladm.FEL_COAL_CNSMN_FDR
             keys RECLAIM_ID + STATUS_TX, matched against the constant 'ACTIVE'
             lookup SQL override PRESENT:
               SELECT F.RECLAIM_ID as RECLAIM_ID,
                      upper(trim(F.STATUS_TX)) as STATUS_TX
               FROM feladm.FEL_COAL_CNSMN_FDR F
 TARGET    : feladm.FEL_COAL_CNSMN_FACT
--------------------------------------------------------------------------------
 PARAMETERS: EXPTRANS.active_STATUS_TX is the constant 'ACTIVE' feeding the lookup.
             No mapping parameters are referenced.
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Writer deletes by RECLAIM_KEY. A fact row whose RECLAIM_ID has no
             ACTIVE feeder row, including one with no feeder row at all, is deleted.
             The captured run read 221813 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COAL_CNSMN_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COAL_CNSMN_FDR F
    WHERE F.RECLAIM_ID                = TGT.RECLAIM_ID
      AND UPPER(TRIM(F.STATUS_TX))    = 'ACTIVE'
);
