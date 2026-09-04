/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COAL_RCPTS_QTY_QLTY_FDR_Cmtrt_ins_upd
 MAPPING   : m_FEL_COAL_RCPTS_QTY_QLTY_FDR_Cmtrt_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_RECEIPT_VW
 LOOKUP    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR
             existence, RECEIPT_ID = RCPT_ID, no lookup SQL override
 TARGET    : feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : SO2_LBS_PER_MBTU_MSR uses TRUNC to 3 decimals here, unlike
             m_FEL_COAL_CNSMN_FDR_ins_upd which rounds. Carried over as written.
             CNTRCT_DTL_ID is not a contract detail lookup, it is the source
             column COMMODITY_ID with 0 for null.
             Null defaults: 0 for ids and measures, ' ' for text, 12/31/2099 for
             the shipped, unloaded and priced dates.
             UNSMPLD_RSN_TX is cut to 50 by the source qualifier port.
             ASH, SULFUR and MOISTURE percentages are written to decimal(5,3);
             values above 99.999 overflow.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR TGT
SET
    CMDTY_SRC_ID          = SRC.CMDTY_SRC_ID,
    SHIPPED_TS            = SRC.SHIPPED_TS,
    UNLOADD_TS            = SRC.UNLOADD_TS,
    PRICED_DT             = SRC.PRICED_DT,
    INVTRY_LOC_ID         = SRC.INVTRY_LOC_ID,
    SHP_MTHD_TX           = SRC.SHP_MTHD_TX,
    STATUS_TX             = SRC.STATUS_TX,
    BARGE_ID              = SRC.BARGE_ID,
    TRAIN_ID              = SRC.TRAIN_ID,
    PRCD_TONS_QY          = SRC.PRCD_TONS_QY,
    SHP_TONS_QY           = SRC.SHP_TONS_QY,
    UNLOADD_TONS_QY       = SRC.UNLOADD_TONS_QY,
    FRZ_TRTMT_TONS_QY     = SRC.FRZ_TRTMT_TONS_QY,
    DUST_TRTMT_TONS_QY    = SRC.DUST_TRTMT_TONS_QY,
    UNLOADD_SMPLD_TONS_QY = SRC.UNLOADD_SMPLD_TONS_QY,
    ASH_QLTY_PCT          = SRC.ASH_QLTY_PCT,
    SULFUR_QLTY_PCT       = SRC.SULFUR_QLTY_PCT,
    MOISTURE_QLTY_PCT     = SRC.MOISTURE_QLTY_PCT,
    BTU_PER_LB_MSR        = SRC.BTU_PER_LB_MSR,
    SO2_LBS_PER_MBTU_MSR  = SRC.SO2_LBS_PER_MBTU_MSR,
    ANLYS_CTRL_NB         = SRC.ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB        = SRC.ANLYS_TRCKG_NB,
    TOW_ID                = SRC.TOW_ID,
    LAST_UPDT_TS          = SRC.LAST_UPDT_TS,
    CONTRACT_ID           = SRC.CONTRACT_ID,
    CNTRCT_DTL_ID         = SRC.CNTRCT_DTL_ID,
    UNSMPLD_RSN_TX        = SRC.UNSMPLD_RSN_TX
FROM (
    SELECT
        CAST(DQ.RCPT_ID AS NUMBER(10,0))                                                            AS RECEIPT_ID,
        CAST(IFF(DQ.COMMSRC_ID IS NOT NULL, DQ.COMMSRC_ID, 0) AS NUMBER(10,0))                      AS CMDTY_SRC_ID,
        CAST(IFF(DQ.SHIPPED_DT IS NULL, DATE '2099-12-31', DQ.SHIPPED_DT) AS TIMESTAMP_NTZ)         AS SHIPPED_TS,
        CAST(IFF(DQ.UNLOAD_END_DT IS NULL, DATE '2099-12-31', DQ.UNLOAD_END_DT) AS TIMESTAMP_NTZ)   AS UNLOADD_TS,
        CAST(IFF(DQ.PRICED_DT IS NULL, DATE '2099-12-31', DQ.PRICED_DT) AS DATE)                    AS PRICED_DT,
        CAST(IFF(DQ.INVLOC_ID IS NOT NULL, DQ.INVLOC_ID, 0) AS NUMBER(10,0))                        AS INVTRY_LOC_ID,
        IFF(DQ.SHIP_MTHD IS NOT NULL, DQ.SHIP_MTHD, ' ')                                            AS SHP_MTHD_TX,
        DQ.STATUS                                                                                   AS STATUS_TX,
        IFF(DQ.BARGE_ID IS NOT NULL, DQ.BARGE_ID, ' ')                                              AS BARGE_ID,
        IFF(DQ.TRAIN_ID IS NOT NULL, DQ.TRAIN_ID, ' ')                                              AS TRAIN_ID,
        CAST(IFF(DQ.PRICED_TNS IS NOT NULL, DQ.PRICED_TNS, 0) AS NUMBER(12,3))                      AS PRCD_TONS_QY,
        CAST(IFF(DQ.LOADED_TONS IS NOT NULL, DQ.LOADED_TONS, 0) AS NUMBER(12,3))                    AS SHP_TONS_QY,
        CAST(IFF(DQ.UNLOADED_TONS IS NOT NULL, DQ.UNLOADED_TONS, 0) AS NUMBER(12,3))                AS UNLOADD_TONS_QY,
        CAST(IFF(DQ.FREEZE_TNS IS NOT NULL, DQ.FREEZE_TNS, 0) AS NUMBER(12,3))                      AS FRZ_TRTMT_TONS_QY,
        CAST(IFF(DQ.DUST_TNS IS NOT NULL, DQ.DUST_TNS, 0) AS NUMBER(12,3))                          AS DUST_TRTMT_TONS_QY,
        CAST(IFF(DQ.WTD_UNLOAD_TNS IS NOT NULL, DQ.WTD_UNLOAD_TNS, 0) AS NUMBER(12,3))              AS UNLOADD_SMPLD_TONS_QY,
        CAST(IFF(DQ.ASH_QLTY IS NOT NULL, DQ.ASH_QLTY, 0) AS NUMBER(5,3))                           AS ASH_QLTY_PCT,
        CAST(IFF(DQ.SULFUR_QLTY IS NOT NULL, DQ.SULFUR_QLTY, 0) AS NUMBER(5,3))                     AS SULFUR_QLTY_PCT,
        CAST(IFF(DQ.MOIST_QLTY IS NOT NULL, DQ.MOIST_QLTY, 0) AS NUMBER(5,3))                       AS MOISTURE_QLTY_PCT,
        CAST(IFF(DQ.BTU_QLTY IS NOT NULL, DQ.BTU_QLTY, 0) AS NUMBER(12,3))                          AS BTU_PER_LB_MSR,
        CAST(TRUNC(IFF(DQ.BTU_QLTY IS NULL OR DQ.BTU_QLTY = 0, 0,
                       (20000 * DQ.SULFUR_QLTY) / DQ.BTU_QLTY), 3) AS NUMBER(12,3))                 AS SO2_LBS_PER_MBTU_MSR,
        IFF(DQ.ACN IS NULL, ' ', DQ.ACN)                                                            AS ANLYS_CTRL_NB,
        IFF(DQ.ATN IS NULL, ' ', DQ.ATN)                                                            AS ANLYS_TRCKG_NB,
        IFF(DQ.TOW_ID IS NULL, ' ', DQ.TOW_ID)                                                      AS TOW_ID,
        $V_SESSSTARTTIME                                                                            AS LAST_UPDT_TS,
        IFF(DQ.CONTRACT_ID IS NOT NULL, DQ.CONTRACT_ID, ' ')                                        AS CONTRACT_ID,
        CAST(IFF(DQ.COMMODITY_ID IS NOT NULL, DQ.COMMODITY_ID, 0) AS NUMBER(10,0))                  AS CNTRCT_DTL_ID,
        IFF(DQ.UNSMPLE_RSN_CDE IS NOT NULL, DQ.UNSMPLE_RSN_CDE, ' ')                                AS UNSMPLD_RSN_TX
    FROM (
        SELECT
            SQ.RCPT_ID,
            SQ.INVLOC_ID,
            SQ.COMMSRC_ID,
            SQ.SHIPPED_DT,
            SQ.UNLOAD_END_DT,
            SQ.LOADED_TONS,
            SQ.UNLOADED_TONS,
            SQ.FREEZE_TNS,
            SQ.DUST_TNS,
            SQ.PRICED_DT,
            SQ.PRICED_TNS,
            SQ.COMMODITY_ID,
            SQ.BTU_QLTY,
            SQ.ASH_QLTY,
            SQ.MOIST_QLTY,
            SQ.SULFUR_QLTY,
            SQ.WTD_UNLOAD_TNS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID)))          = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID)          END AS CONTRACT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHIP_MTHD)))            = 0 THEN ' ' ELSE RTRIM(SQ.SHIP_MTHD)            END AS SHIP_MTHD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TRAIN_ID)))             = 0 THEN ' ' ELSE RTRIM(SQ.TRAIN_ID)             END AS TRAIN_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BARGE_ID)))             = 0 THEN ' ' ELSE RTRIM(SQ.BARGE_ID)             END AS BARGE_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ACN)))                  = 0 THEN ' ' ELSE RTRIM(SQ.ACN)                  END AS ACN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ATN)))                  = 0 THEN ' ' ELSE RTRIM(SQ.ATN)                  END AS ATN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TOW_ID)))               = 0 THEN ' ' ELSE RTRIM(SQ.TOW_ID)               END AS TOW_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(LEFT(SQ.UNSMPLE_RSN_CDE, 50)))) = 0 THEN ' ' ELSE RTRIM(LEFT(SQ.UNSMPLE_RSN_CDE, 50)) END AS UNSMPLE_RSN_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))               = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)               END AS STATUS
        FROM AEP_DW_RECEIPT_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE TGT.RECEIPT_ID = SRC.RECEIPT_ID;

INSERT INTO feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR (
    RECEIPT_ID,
    CMDTY_SRC_ID,
    SHIPPED_TS,
    UNLOADD_TS,
    PRICED_DT,
    INVTRY_LOC_ID,
    SHP_MTHD_TX,
    STATUS_TX,
    BARGE_ID,
    TRAIN_ID,
    PRCD_TONS_QY,
    SHP_TONS_QY,
    UNLOADD_TONS_QY,
    FRZ_TRTMT_TONS_QY,
    DUST_TRTMT_TONS_QY,
    UNLOADD_SMPLD_TONS_QY,
    ASH_QLTY_PCT,
    SULFUR_QLTY_PCT,
    MOISTURE_QLTY_PCT,
    BTU_PER_LB_MSR,
    SO2_LBS_PER_MBTU_MSR,
    ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB,
    TOW_ID,
    LAST_UPDT_TS,
    CONTRACT_ID,
    CNTRCT_DTL_ID,
    UNSMPLD_RSN_TX
)
SELECT
    SRC.RECEIPT_ID,
    SRC.CMDTY_SRC_ID,
    SRC.SHIPPED_TS,
    SRC.UNLOADD_TS,
    SRC.PRICED_DT,
    SRC.INVTRY_LOC_ID,
    SRC.SHP_MTHD_TX,
    SRC.STATUS_TX,
    SRC.BARGE_ID,
    SRC.TRAIN_ID,
    SRC.PRCD_TONS_QY,
    SRC.SHP_TONS_QY,
    SRC.UNLOADD_TONS_QY,
    SRC.FRZ_TRTMT_TONS_QY,
    SRC.DUST_TRTMT_TONS_QY,
    SRC.UNLOADD_SMPLD_TONS_QY,
    SRC.ASH_QLTY_PCT,
    SRC.SULFUR_QLTY_PCT,
    SRC.MOISTURE_QLTY_PCT,
    SRC.BTU_PER_LB_MSR,
    SRC.SO2_LBS_PER_MBTU_MSR,
    SRC.ANLYS_CTRL_NB,
    SRC.ANLYS_TRCKG_NB,
    SRC.TOW_ID,
    SRC.LAST_UPDT_TS,
    SRC.CONTRACT_ID,
    SRC.CNTRCT_DTL_ID,
    SRC.UNSMPLD_RSN_TX
FROM (
    SELECT
        CAST(DQ.RCPT_ID AS NUMBER(10,0))                                                            AS RECEIPT_ID,
        CAST(IFF(DQ.COMMSRC_ID IS NOT NULL, DQ.COMMSRC_ID, 0) AS NUMBER(10,0))                      AS CMDTY_SRC_ID,
        CAST(IFF(DQ.SHIPPED_DT IS NULL, DATE '2099-12-31', DQ.SHIPPED_DT) AS TIMESTAMP_NTZ)         AS SHIPPED_TS,
        CAST(IFF(DQ.UNLOAD_END_DT IS NULL, DATE '2099-12-31', DQ.UNLOAD_END_DT) AS TIMESTAMP_NTZ)   AS UNLOADD_TS,
        CAST(IFF(DQ.PRICED_DT IS NULL, DATE '2099-12-31', DQ.PRICED_DT) AS DATE)                    AS PRICED_DT,
        CAST(IFF(DQ.INVLOC_ID IS NOT NULL, DQ.INVLOC_ID, 0) AS NUMBER(10,0))                        AS INVTRY_LOC_ID,
        IFF(DQ.SHIP_MTHD IS NOT NULL, DQ.SHIP_MTHD, ' ')                                            AS SHP_MTHD_TX,
        DQ.STATUS                                                                                   AS STATUS_TX,
        IFF(DQ.BARGE_ID IS NOT NULL, DQ.BARGE_ID, ' ')                                              AS BARGE_ID,
        IFF(DQ.TRAIN_ID IS NOT NULL, DQ.TRAIN_ID, ' ')                                              AS TRAIN_ID,
        CAST(IFF(DQ.PRICED_TNS IS NOT NULL, DQ.PRICED_TNS, 0) AS NUMBER(12,3))                      AS PRCD_TONS_QY,
        CAST(IFF(DQ.LOADED_TONS IS NOT NULL, DQ.LOADED_TONS, 0) AS NUMBER(12,3))                    AS SHP_TONS_QY,
        CAST(IFF(DQ.UNLOADED_TONS IS NOT NULL, DQ.UNLOADED_TONS, 0) AS NUMBER(12,3))                AS UNLOADD_TONS_QY,
        CAST(IFF(DQ.FREEZE_TNS IS NOT NULL, DQ.FREEZE_TNS, 0) AS NUMBER(12,3))                      AS FRZ_TRTMT_TONS_QY,
        CAST(IFF(DQ.DUST_TNS IS NOT NULL, DQ.DUST_TNS, 0) AS NUMBER(12,3))                          AS DUST_TRTMT_TONS_QY,
        CAST(IFF(DQ.WTD_UNLOAD_TNS IS NOT NULL, DQ.WTD_UNLOAD_TNS, 0) AS NUMBER(12,3))              AS UNLOADD_SMPLD_TONS_QY,
        CAST(IFF(DQ.ASH_QLTY IS NOT NULL, DQ.ASH_QLTY, 0) AS NUMBER(5,3))                           AS ASH_QLTY_PCT,
        CAST(IFF(DQ.SULFUR_QLTY IS NOT NULL, DQ.SULFUR_QLTY, 0) AS NUMBER(5,3))                     AS SULFUR_QLTY_PCT,
        CAST(IFF(DQ.MOIST_QLTY IS NOT NULL, DQ.MOIST_QLTY, 0) AS NUMBER(5,3))                       AS MOISTURE_QLTY_PCT,
        CAST(IFF(DQ.BTU_QLTY IS NOT NULL, DQ.BTU_QLTY, 0) AS NUMBER(12,3))                          AS BTU_PER_LB_MSR,
        CAST(TRUNC(IFF(DQ.BTU_QLTY IS NULL OR DQ.BTU_QLTY = 0, 0,
                       (20000 * DQ.SULFUR_QLTY) / DQ.BTU_QLTY), 3) AS NUMBER(12,3))                 AS SO2_LBS_PER_MBTU_MSR,
        IFF(DQ.ACN IS NULL, ' ', DQ.ACN)                                                            AS ANLYS_CTRL_NB,
        IFF(DQ.ATN IS NULL, ' ', DQ.ATN)                                                            AS ANLYS_TRCKG_NB,
        IFF(DQ.TOW_ID IS NULL, ' ', DQ.TOW_ID)                                                      AS TOW_ID,
        $V_SESSSTARTTIME                                                                            AS LAST_UPDT_TS,
        IFF(DQ.CONTRACT_ID IS NOT NULL, DQ.CONTRACT_ID, ' ')                                        AS CONTRACT_ID,
        CAST(IFF(DQ.COMMODITY_ID IS NOT NULL, DQ.COMMODITY_ID, 0) AS NUMBER(10,0))                  AS CNTRCT_DTL_ID,
        IFF(DQ.UNSMPLE_RSN_CDE IS NOT NULL, DQ.UNSMPLE_RSN_CDE, ' ')                                AS UNSMPLD_RSN_TX
    FROM (
        SELECT
            SQ.RCPT_ID,
            SQ.INVLOC_ID,
            SQ.COMMSRC_ID,
            SQ.SHIPPED_DT,
            SQ.UNLOAD_END_DT,
            SQ.LOADED_TONS,
            SQ.UNLOADED_TONS,
            SQ.FREEZE_TNS,
            SQ.DUST_TNS,
            SQ.PRICED_DT,
            SQ.PRICED_TNS,
            SQ.COMMODITY_ID,
            SQ.BTU_QLTY,
            SQ.ASH_QLTY,
            SQ.MOIST_QLTY,
            SQ.SULFUR_QLTY,
            SQ.WTD_UNLOAD_TNS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID)))          = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID)          END AS CONTRACT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHIP_MTHD)))            = 0 THEN ' ' ELSE RTRIM(SQ.SHIP_MTHD)            END AS SHIP_MTHD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TRAIN_ID)))             = 0 THEN ' ' ELSE RTRIM(SQ.TRAIN_ID)             END AS TRAIN_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.BARGE_ID)))             = 0 THEN ' ' ELSE RTRIM(SQ.BARGE_ID)             END AS BARGE_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ACN)))                  = 0 THEN ' ' ELSE RTRIM(SQ.ACN)                  END AS ACN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ATN)))                  = 0 THEN ' ' ELSE RTRIM(SQ.ATN)                  END AS ATN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.TOW_ID)))               = 0 THEN ' ' ELSE RTRIM(SQ.TOW_ID)               END AS TOW_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(LEFT(SQ.UNSMPLE_RSN_CDE, 50)))) = 0 THEN ' ' ELSE RTRIM(LEFT(SQ.UNSMPLE_RSN_CDE, 50)) END AS UNSMPLE_RSN_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))               = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)               END AS STATUS
        FROM AEP_DW_RECEIPT_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COAL_RCPTS_QTY_QLTY_FDR LKP
    WHERE LKP.RECEIPT_ID = SRC.RECEIPT_ID
);
