/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_GNRTN_UNIT_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : GENDB01_DEV_SANDBOX.COMMON.AEP_DW_GENUNIT_VW
             GENDB01_DEV_SANDBOX.COMMON.AEP_DW_GENUNIT_VW_TEST (Used for testing)
 LOOKUP    : GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR
 TARGET    : GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no

 [FEL.WF:wkf_FEL_CMTRT_FDR_LOAD]
 $$START_TIME=09/05/2026 22:30:12
 $$END_TIME=09/06/2026 22:30:12
 $$RUN_STATUS=C
 $DBConnection_Target=fel_GENDB001
 $DBConnection_Source=fel_COMTRAC

================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR TGT
SET
    UNIT_NM      = SRC.UNIT_NM,
    UNIT_STAT_TX = SRC.UNIT_STAT_TX,
    LAST_UPDT_TS = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(CAST(DQ.UNIT_ID AS NUMBER(10,0)) AS VARCHAR)                              AS UNIT_ID,
        LEFT(IFF(DQ.UNIT_NAME IS NULL, 'UNSPECIFIED', DQ.UNIT_NAME), 40)               AS UNIT_NM,
        LEFT(IFF(DQ.UNIT_STATUS IS NULL, 'UNKNOWN', DQ.UNIT_STATUS), 18)               AS UNIT_STAT_TX,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS,
        LKP.UNIT_ID                                                                    AS LKP_UNIT_ID
    FROM (
        SELECT
            SQ.UNIT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_NAME)))   = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_NAME)   END AS UNIT_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_STATUS))) = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_STATUS) END AS UNIT_STATUS
        FROM GENDB01_DEV_SANDBOX.COMMON.AEP_DW_GENUNIT_VW_TEST SQ
        WHERE SQ.MOD_DT >  $V_START_TIME
          AND SQ.MOD_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT UPPER(TRIM(U.UNIT_ID)) AS UNIT_ID
        FROM GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR U
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(U.UNIT_ID)) ORDER BY UPPER(TRIM(U.UNIT_ID))) = 1
    ) LKP
      ON LKP.UNIT_ID = CAST(CAST(DQ.UNIT_ID AS NUMBER(10,0)) AS VARCHAR)
) SRC
WHERE TGT.UNIT_ID = SRC.LKP_UNIT_ID;

INSERT INTO GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR (
    UNIT_ID,
    UNIT_NM,
    UNIT_STAT_TX,
    LAST_UPDT_TS
)
SELECT
    SRC.UNIT_ID,
    SRC.UNIT_NM,
    SRC.UNIT_STAT_TX,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(CAST(DQ.UNIT_ID AS NUMBER(10,0)) AS VARCHAR)                              AS UNIT_ID,
        LEFT(IFF(DQ.UNIT_NAME IS NULL, 'UNSPECIFIED', DQ.UNIT_NAME), 40)               AS UNIT_NM,
        LEFT(IFF(DQ.UNIT_STATUS IS NULL, 'UNKNOWN', DQ.UNIT_STATUS), 18)               AS UNIT_STAT_TX,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.UNIT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_NAME)))   = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_NAME)   END AS UNIT_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_STATUS))) = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_STATUS) END AS UNIT_STATUS
        FROM GENDB01_DEV_SANDBOX.COMMON.AEP_DW_GENUNIT_VW_TEST SQ
        WHERE SQ.MOD_DT >  $V_START_TIME
          AND SQ.MOD_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_COMTRAC_GNRTN_UNIT_FDR U
    WHERE UPPER(TRIM(U.UNIT_ID)) = SRC.UNIT_ID
);
