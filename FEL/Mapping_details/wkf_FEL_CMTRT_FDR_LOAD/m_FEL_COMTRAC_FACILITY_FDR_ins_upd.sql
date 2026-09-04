/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_FACILITY_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_FACILITY_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_FACILITY_VW
 LOOKUP    : FELADM.FEL_COMTRAC_FACILITY_FDR   existence, key FACILITY_ID
             lookup SQL override PRESENT:
               SELECT trim(FDR.FACILITY_ID) as FACILITY_ID
               FROM FELADM.FEL_COMTRAC_FACILITY_FDR fdr
 TARGET    : FELADM.FEL_COMTRAC_FACILITY_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none at session level; mapping source filter applied below
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 OPEN ITEM : The mapping defines the MOD_BY_DT source filter used below, but the
             captured run issued NO WHERE clause and read the whole view, 81 rows,
             all to update. This script applies the mapping filter. To reproduce
             the captured run instead, delete the three WHERE conditions that
             reference V_START_TIME, V_END_TIME and V_RUN_STATUS.
 NOTES     : FACILITY_ID is TO_CHAR of the numeric id cut to 3 characters;
             REGION_NM is cut to 10. Null defaults: ' ' for name, status and type,
             'N/A' for the WV code, -999 for the operating company, 'UNKNOWN'
             for state and region.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE FELADM.FEL_COMTRAC_FACILITY_FDR TGT
SET
    FACILITY_NM   = SRC.FACILITY_NM,
    FCLTY_TYPE_NM = SRC.FCLTY_TYPE_NM,
    FCLTY_STAT_TX = SRC.FCLTY_STAT_TX,
    BSNS_ENTY_ID  = SRC.BSNS_ENTY_ID,
    WV_PLANT_CD   = SRC.WV_PLANT_CD,
    GEOG_STATE_NM = SRC.GEOG_STATE_NM,
    REGION_NM     = SRC.REGION_NM,
    LAST_UPDT_TS  = SRC.LAST_UPDT_TS
FROM (
    SELECT
        LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(15,0)) AS VARCHAR), 3)                    AS FACILITY_ID,
        IFF(DQ.FCLTY_NAME IS NULL, ' ', DQ.FCLTY_NAME)                                 AS FACILITY_NM,
        IFF(DQ.FCLTY_TPE IS NULL, ' ', DQ.FCLTY_TPE)                                   AS FCLTY_TYPE_NM,
        IFF(DQ.FCLTY_STAT_NM IS NULL, ' ', DQ.FCLTY_STAT_NM)                           AS FCLTY_STAT_TX,
        CAST(IFF(DQ.FK_OPCO_ID IS NULL, -999, DQ.FK_OPCO_ID) AS NUMBER(10,0))          AS BSNS_ENTY_ID,
        IFF(DQ.WV_CDE IS NULL, 'N/A', DQ.WV_CDE)                                       AS WV_PLANT_CD,
        IFF(DQ.STATE IS NULL, 'UNKNOWN', DQ.STATE)                                     AS GEOG_STATE_NM,
        LEFT(IFF(DQ.REGION IS NULL, 'UNKNOWN', DQ.REGION), 10)                         AS REGION_NM,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS,
        LKP.FACILITY_ID                                                                AS LKP_FACILITY_ID
    FROM (
        SELECT
            SQ.FCLTY_ID,
            SQ.FK_OPCO_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_NAME)))    = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_NAME)    END AS FCLTY_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_STAT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_STAT_NM) END AS FCLTY_STAT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_TPE)))     = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_TPE)     END AS FCLTY_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.WV_CDE)))        = 0 THEN ' ' ELSE RTRIM(SQ.WV_CDE)        END AS WV_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATE)))         = 0 THEN ' ' ELSE RTRIM(SQ.STATE)         END AS STATE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.REGION)))        = 0 THEN ' ' ELSE RTRIM(SQ.REGION)        END AS REGION
        FROM AEP_DW_FACILITY_VW SQ
        WHERE SQ.MOD_BY_DT >  $V_START_TIME
          AND SQ.MOD_BY_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT TRIM(FDR.FACILITY_ID) AS FACILITY_ID
        FROM FELADM.FEL_COMTRAC_FACILITY_FDR FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FDR.FACILITY_ID) ORDER BY TRIM(FDR.FACILITY_ID)) = 1
    ) LKP
      ON LKP.FACILITY_ID = LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(15,0)) AS VARCHAR), 3)
) SRC
WHERE TGT.FACILITY_ID = SRC.LKP_FACILITY_ID;

INSERT INTO FELADM.FEL_COMTRAC_FACILITY_FDR (
    FACILITY_ID,
    FACILITY_NM,
    FCLTY_TYPE_NM,
    FCLTY_STAT_TX,
    BSNS_ENTY_ID,
    WV_PLANT_CD,
    GEOG_STATE_NM,
    REGION_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.FACILITY_ID,
    SRC.FACILITY_NM,
    SRC.FCLTY_TYPE_NM,
    SRC.FCLTY_STAT_TX,
    SRC.BSNS_ENTY_ID,
    SRC.WV_PLANT_CD,
    SRC.GEOG_STATE_NM,
    SRC.REGION_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        LEFT(CAST(CAST(DQ.FCLTY_ID AS NUMBER(15,0)) AS VARCHAR), 3)                    AS FACILITY_ID,
        IFF(DQ.FCLTY_NAME IS NULL, ' ', DQ.FCLTY_NAME)                                 AS FACILITY_NM,
        IFF(DQ.FCLTY_TPE IS NULL, ' ', DQ.FCLTY_TPE)                                   AS FCLTY_TYPE_NM,
        IFF(DQ.FCLTY_STAT_NM IS NULL, ' ', DQ.FCLTY_STAT_NM)                           AS FCLTY_STAT_TX,
        CAST(IFF(DQ.FK_OPCO_ID IS NULL, -999, DQ.FK_OPCO_ID) AS NUMBER(10,0))          AS BSNS_ENTY_ID,
        IFF(DQ.WV_CDE IS NULL, 'N/A', DQ.WV_CDE)                                       AS WV_PLANT_CD,
        IFF(DQ.STATE IS NULL, 'UNKNOWN', DQ.STATE)                                     AS GEOG_STATE_NM,
        LEFT(IFF(DQ.REGION IS NULL, 'UNKNOWN', DQ.REGION), 10)                         AS REGION_NM,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.FCLTY_ID,
            SQ.FK_OPCO_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_NAME)))    = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_NAME)    END AS FCLTY_NAME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_STAT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_STAT_NM) END AS FCLTY_STAT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FCLTY_TPE)))     = 0 THEN ' ' ELSE RTRIM(SQ.FCLTY_TPE)     END AS FCLTY_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.WV_CDE)))        = 0 THEN ' ' ELSE RTRIM(SQ.WV_CDE)        END AS WV_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATE)))         = 0 THEN ' ' ELSE RTRIM(SQ.STATE)         END AS STATE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.REGION)))        = 0 THEN ' ' ELSE RTRIM(SQ.REGION)        END AS REGION
        FROM AEP_DW_FACILITY_VW SQ
        WHERE SQ.MOD_BY_DT >  $V_START_TIME
          AND SQ.MOD_BY_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM FELADM.FEL_COMTRAC_FACILITY_FDR FDR
    WHERE TRIM(FDR.FACILITY_ID) = SRC.FACILITY_ID
);
