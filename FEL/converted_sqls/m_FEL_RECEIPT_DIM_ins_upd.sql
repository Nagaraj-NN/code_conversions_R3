/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_RECEIPT_DIM_ins_upd
 MAPPING   : m_FEL_RECEIPT_DIM_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the dimension
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR   filtered on time and status
 LOOKUP    : feladm.FEL_RECEIPT_DIM   existence on RECEIPT_ID, no SQL override,
             Use Any Value on multiple match
 TARGET    : feladm.FEL_RECEIPT_DIM   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$RUN_STATUS, $$REC_STATUS  (SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only:
                 LAST_UPDT_TS >= '$$START_TIME' AND '$$RUN_STATUS' = 'C'
                 AND UPPER(TRIM(STATUS_TX)) = '$$REC_STATUS'
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The lookup is fed trim_RCPT_ID = upper(RECEIPT_ID), a numeric column
             pushed through UPPER into a 200 character port and then compared with
             the integer RECEIPT_ID of the dimension. Informatica converts it back,
             so the match is numeric and it is written that way below.
             The update keys on RECEIPT_KEY from the lookup; the insert takes its
             key from SEQ_RECEIPTS_DIM, a PERSISTENT sequence at 1518424 that is not
             reset. Here it continues from the dimension's own maximum instead.
             The shipping method, barge, train, tow, both analysis numbers and the
             status are data quality cleaned; the rest pass through untouched.
             The captured run read 1848 rows, updated 1828 and inserted 20.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS');
SET V_REC_STATUS    = 'ACTIVE';
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_RECEIPT_DIM TGT
SET
    RECEIPT_ID     = SRC.RECEIPT_ID,
    BARGE_ID       = SRC.BARGE_ID,
    TRAIN_ID       = SRC.TRAIN_ID,
    TOW_ID         = SRC.TOW_ID,
    UNLOADD_TS     = SRC.UNLOADD_TS,
    SHIPPED_TS     = SRC.SHIPPED_TS,
    ANLYS_CTRL_NB  = SRC.ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB = SRC.ANLYS_TRCKG_NB,
    SHP_MTHD_TX    = SRC.SHP_MTHD_TX,
    STATUS_TX      = SRC.STATUS_TX,
    LAST_UPDT_TS   = SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.RECEIPT_ID,
        SQ.UNLOADD_TS,
        SQ.SHIPPED_TS,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BARGE_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.BARGE_ID)       END AS BARGE_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TRAIN_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.TRAIN_ID)       END AS TRAIN_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TOW_ID)))         = 0 THEN ' ' ELSE RTRIM(SQ.TOW_ID)         END AS TOW_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_CTRL_NB)))  = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_CTRL_NB)  END AS ANLYS_CTRL_NB,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_TRCKG_NB))) = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_TRCKG_NB) END AS ANLYS_TRCKG_NB,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))    = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)    END AS SHP_MTHD_TX,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))      = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)      END AS STATUS_TX,
        $V_SESSSTARTTIME                                                                                AS LAST_UPDT_TS
    FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR SQ
    WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
      AND $V_RUN_STATUS = 'C'
      AND UPPER(TRIM(SQ.STATUS_TX)) = $V_REC_STATUS
) SRC
WHERE TGT.RECEIPT_ID = SRC.RECEIPT_ID;

INSERT INTO feladm.FEL_RECEIPT_DIM (
    RECEIPT_KEY,
    RECEIPT_ID,
    BARGE_ID,
    TRAIN_ID,
    TOW_ID,
    UNLOADD_TS,
    SHIPPED_TS,
    ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB,
    SHP_MTHD_TX,
    STATUS_TX,
    LAST_UPDT_TS
)
SELECT
    NVL((SELECT MAX(RECEIPT_KEY) FROM feladm.FEL_RECEIPT_DIM), 0)
        + ROW_NUMBER() OVER (ORDER BY SRC.RECEIPT_ID)   AS RECEIPT_KEY,
    SRC.RECEIPT_ID,
    SRC.BARGE_ID,
    SRC.TRAIN_ID,
    SRC.TOW_ID,
    SRC.UNLOADD_TS,
    SRC.SHIPPED_TS,
    SRC.ANLYS_CTRL_NB,
    SRC.ANLYS_TRCKG_NB,
    SRC.SHP_MTHD_TX,
    SRC.STATUS_TX,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.RECEIPT_ID,
        SQ.UNLOADD_TS,
        SQ.SHIPPED_TS,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BARGE_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.BARGE_ID)       END AS BARGE_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TRAIN_ID)))       = 0 THEN ' ' ELSE RTRIM(SQ.TRAIN_ID)       END AS TRAIN_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TOW_ID)))         = 0 THEN ' ' ELSE RTRIM(SQ.TOW_ID)         END AS TOW_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_CTRL_NB)))  = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_CTRL_NB)  END AS ANLYS_CTRL_NB,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_TRCKG_NB))) = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_TRCKG_NB) END AS ANLYS_TRCKG_NB,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))    = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)    END AS SHP_MTHD_TX,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))      = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)      END AS STATUS_TX,
        $V_SESSSTARTTIME                                                                                AS LAST_UPDT_TS
    FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR SQ
    WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
      AND $V_RUN_STATUS = 'C'
      AND UPPER(TRIM(SQ.STATUS_TX)) = $V_REC_STATUS
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_RECEIPT_DIM L
    WHERE L.RECEIPT_ID = SRC.RECEIPT_ID
);
