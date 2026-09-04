/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_ins_upd
 OPERATION : INSERT + CONDITIONAL UPDATE, data driven. RTR_NEW_EXIST updates only
             when the key exists AND the obligation quantity actually changed.
             An existing key with an unchanged quantity is written nowhere.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_CONTRACT_OBLIGATIONS_VW
 LOOKUP    : feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR
             keys CNTRCT_DTL_ID + FACILITY_ID + CNTRCT_DTL_OPRTG_DT,
             also returns CNTRCTD_OBLGN_QY for the change test
             lookup SQL override PRESENT:
               SELECT fdr.CNTRCTD_OBLGN_QY, fdr.CNTRCT_DTL_ID,
                      trim(fdr.FACILITY_ID) as FACILITY_ID, fdr.CNTRCT_DTL_OPRTG_DT
               FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR fdr
 TARGET    : feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : FACILITY_ID is TO_CHAR of the numeric id cut to 3 characters.
             CONTRACT_ID is cut to 25 by the router port even though the target
             column is varchar(81). A null on either side of the quantity test
             makes it unknown, so the row is discarded, as in Informatica.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR TGT
SET
    CONTRACT_ID      = SRC.CONTRACT_ID,
    CNTRCTD_OBLGN_QY = SRC.CNTRCTD_OBLGN_QY,
    LAST_UPDT_TS     = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                                        AS CNTRCT_DTL_ID,
        LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(10,0)) AS VARCHAR), 3)                  AS FACILITY_ID,
        LEFT(DQ.CNTRCT_ID, 25)                                                       AS CONTRACT_ID,
        DQ.CONTRCTDTL_OB_DT                                                          AS CNTRCT_DTL_OPRTG_DT,
        CAST(DQ.CONTRCTDTL_OB_TONS AS NUMBER(14,5))                                  AS CNTRCTD_OBLGN_QY,
        $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS,
        LKP.CNTRCTD_OBLGN_QY                                                         AS LKP_CNTRCTD_OBLGN_QY
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID) END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            SQ.FCLTY_ID,
            SQ.CONTRCTDTL_OB_DT,
            SQ.CONTRCTDTL_OB_TONS
        FROM AEP_DW_CONTRACT_OBLIGATIONS_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT
            FDR.CNTRCTD_OBLGN_QY    AS CNTRCTD_OBLGN_QY,
            FDR.CNTRCT_DTL_ID       AS CNTRCT_DTL_ID,
            TRIM(FDR.FACILITY_ID)   AS FACILITY_ID,
            FDR.CNTRCT_DTL_OPRTG_DT AS CNTRCT_DTL_OPRTG_DT
        FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FDR.CNTRCT_DTL_ID, TRIM(FDR.FACILITY_ID), FDR.CNTRCT_DTL_OPRTG_DT
                                   ORDER BY FDR.CNTRCT_DTL_ID, TRIM(FDR.FACILITY_ID), FDR.CNTRCT_DTL_OPRTG_DT, FDR.CNTRCTD_OBLGN_QY) = 1
    ) LKP
      ON LKP.CNTRCT_DTL_ID       = CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))
     AND LKP.FACILITY_ID         = LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(10,0)) AS VARCHAR), 3)
     AND LKP.CNTRCT_DTL_OPRTG_DT = DQ.CONTRCTDTL_OB_DT
) SRC
WHERE SRC.LKP_CNTRCTD_OBLGN_QY <> SRC.CNTRCTD_OBLGN_QY
  AND TGT.CNTRCT_DTL_ID       = SRC.CNTRCT_DTL_ID
  AND TGT.FACILITY_ID         = SRC.FACILITY_ID
  AND TGT.CNTRCT_DTL_OPRTG_DT = SRC.CNTRCT_DTL_OPRTG_DT;

INSERT INTO feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR (
    CNTRCT_DTL_ID,
    FACILITY_ID,
    CNTRCT_DTL_OPRTG_DT,
    CONTRACT_ID,
    CNTRCTD_OBLGN_QY,
    LAST_UPDT_TS
)
SELECT
    SRC.CNTRCT_DTL_ID,
    SRC.FACILITY_ID,
    CAST(SRC.CNTRCT_DTL_OPRTG_DT AS DATE),
    SRC.CONTRACT_ID,
    SRC.CNTRCTD_OBLGN_QY,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                                        AS CNTRCT_DTL_ID,
        LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(10,0)) AS VARCHAR), 3)                  AS FACILITY_ID,
        LEFT(DQ.CNTRCT_ID, 25)                                                       AS CONTRACT_ID,
        DQ.CONTRCTDTL_OB_DT                                                          AS CNTRCT_DTL_OPRTG_DT,
        CAST(DQ.CONTRCTDTL_OB_TONS AS NUMBER(14,5))                                  AS CNTRCTD_OBLGN_QY,
        $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID) END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            SQ.FCLTY_ID,
            SQ.CONTRCTDTL_OB_DT,
            SQ.CONTRCTDTL_OB_TONS
        FROM AEP_DW_CONTRACT_OBLIGATIONS_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR FDR
    WHERE FDR.CNTRCT_DTL_ID       = SRC.CNTRCT_DTL_ID
      AND TRIM(FDR.FACILITY_ID)   = SRC.FACILITY_ID
      AND FDR.CNTRCT_DTL_OPRTG_DT = SRC.CNTRCT_DTL_OPRTG_DT
);
