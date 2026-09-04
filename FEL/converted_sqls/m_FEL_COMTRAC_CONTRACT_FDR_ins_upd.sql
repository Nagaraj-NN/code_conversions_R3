/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_CONTRACT_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_CONTRACT_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_CONTRACT_VW
 LOOKUP    : FELADM.FEL_COMTRAC_CONTRACT_FDR   existence, key CONTRACT_ID
             lookup SQL override PRESENT:
               SELECT UPPER(TRIM(F.CONTRACT_ID)) as CONTRACT_ID
               FROM FELADM.FEL_COMTRAC_CONTRACT_FDR F
 TARGET    : feladm.FEL_COMTRAC_CONTRACT_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Insert writes CNTRCT_ID in its original case; update keys on the
             lookup's UPPER(TRIM(CONTRACT_ID)). A stored id that is not already
             upper case and trimmed will not match. Reproduced, not corrected.
             Null defaults: 'UNKNOWN' for names and status, -2 for ids,
             12/30/2099 for the dates.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COMTRAC_CONTRACT_FDR TGT
SET
    CNTRCT_EFCTV_DT     = SRC.CNTRCT_EFCTV_DT,
    CNTRCT_EXPR_DT      = SRC.CNTRCT_EXPR_DT,
    PARNT_CNTRCT_NM     = SRC.PARNT_CNTRCT_NM,
    CONTRACT_NM         = SRC.CONTRACT_NM,
    CNTRCT_TYPE_NM      = SRC.CNTRCT_TYPE_NM,
    CURR_CNTRCT_VNDR_ID = SRC.CURR_CNTRCT_VNDR_ID,
    CURR_BYR_ID         = SRC.CURR_BYR_ID,
    STATUS_TX           = SRC.STATUS_TX,
    LAST_UPDT_TS        = SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CNTRCT_ID                                                                               AS CONTRACT_ID,
        UPPER(DQ.CNTRCT_ID)                                                                        AS IN_CONTRACT_ID,
        CAST(IFF(DQ.EFF_DT IS NOT NULL, DQ.EFF_DT, DATE '2099-12-30') AS DATE)                     AS CNTRCT_EFCTV_DT,
        CAST(IFF(DQ.EXP_DT IS NOT NULL, DQ.EXP_DT, DATE '2099-12-30') AS DATE)                     AS CNTRCT_EXPR_DT,
        IFF(DQ.P_CNTRCT IS NOT NULL, DQ.P_CNTRCT, 'UNKNOWN')                                       AS PARNT_CNTRCT_NM,
        IFF(DQ.CNTRCT IS NOT NULL, DQ.CNTRCT, 'UNKNOWN')                                           AS CONTRACT_NM,
        IFF(DQ.CNTRCT_TYP IS NOT NULL, DQ.CNTRCT_TYP, 'UNKNOWN')                                   AS CNTRCT_TYPE_NM,
        CAST(IFF(DQ.VNDR_ID IS NOT NULL, DQ.VNDR_ID, -2) AS NUMBER(10,0))                          AS CURR_CNTRCT_VNDR_ID,
        CAST(IFF(DQ.BYR_ID IS NOT NULL, DQ.BYR_ID, -2) AS NUMBER(10,0))                            AS CURR_BYR_ID,
        IFF(DQ.CNTRCT_STAT IS NULL, 'UNKNOWN', DQ.CNTRCT_STAT)                                     AS STATUS_TX,
        $V_SESSSTARTTIME                                                                           AS LAST_UPDT_TS,
        LKP.CONTRACT_ID                                                                            AS LKP_CONTRACT_ID
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))   = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)   END AS CNTRCT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_STAT))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_STAT) END AS CNTRCT_STAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.P_CNTRCT)))    = 0 THEN ' ' ELSE RTRIM(SQ.P_CNTRCT)    END AS P_CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT)))      = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT)      END AS CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYP)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYP)  END AS CNTRCT_TYP,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.VNDR_ID,
            SQ.BYR_ID
        FROM AEP_DW_CONTRACT_VW SQ
        WHERE SQ.MOD_DT >  $V_START_TIME
          AND SQ.MOD_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT UPPER(TRIM(F.CONTRACT_ID)) AS CONTRACT_ID
        FROM FELADM.FEL_COMTRAC_CONTRACT_FDR F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.CONTRACT_ID)) ORDER BY UPPER(TRIM(F.CONTRACT_ID))) = 1
    ) LKP
      ON LKP.CONTRACT_ID = UPPER(DQ.CNTRCT_ID)
) SRC
WHERE TGT.CONTRACT_ID = SRC.LKP_CONTRACT_ID;

INSERT INTO feladm.FEL_COMTRAC_CONTRACT_FDR (
    CONTRACT_ID,
    CNTRCT_EFCTV_DT,
    CNTRCT_EXPR_DT,
    PARNT_CNTRCT_NM,
    CONTRACT_NM,
    CNTRCT_TYPE_NM,
    CURR_CNTRCT_VNDR_ID,
    CURR_BYR_ID,
    STATUS_TX,
    LAST_UPDT_TS
)
SELECT
    SRC.CONTRACT_ID,
    SRC.CNTRCT_EFCTV_DT,
    SRC.CNTRCT_EXPR_DT,
    SRC.PARNT_CNTRCT_NM,
    SRC.CONTRACT_NM,
    SRC.CNTRCT_TYPE_NM,
    SRC.CURR_CNTRCT_VNDR_ID,
    SRC.CURR_BYR_ID,
    SRC.STATUS_TX,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CNTRCT_ID                                                                               AS CONTRACT_ID,
        UPPER(DQ.CNTRCT_ID)                                                                        AS IN_CONTRACT_ID,
        CAST(IFF(DQ.EFF_DT IS NOT NULL, DQ.EFF_DT, DATE '2099-12-30') AS DATE)                     AS CNTRCT_EFCTV_DT,
        CAST(IFF(DQ.EXP_DT IS NOT NULL, DQ.EXP_DT, DATE '2099-12-30') AS DATE)                     AS CNTRCT_EXPR_DT,
        IFF(DQ.P_CNTRCT IS NOT NULL, DQ.P_CNTRCT, 'UNKNOWN')                                       AS PARNT_CNTRCT_NM,
        IFF(DQ.CNTRCT IS NOT NULL, DQ.CNTRCT, 'UNKNOWN')                                           AS CONTRACT_NM,
        IFF(DQ.CNTRCT_TYP IS NOT NULL, DQ.CNTRCT_TYP, 'UNKNOWN')                                   AS CNTRCT_TYPE_NM,
        CAST(IFF(DQ.VNDR_ID IS NOT NULL, DQ.VNDR_ID, -2) AS NUMBER(10,0))                          AS CURR_CNTRCT_VNDR_ID,
        CAST(IFF(DQ.BYR_ID IS NOT NULL, DQ.BYR_ID, -2) AS NUMBER(10,0))                            AS CURR_BYR_ID,
        IFF(DQ.CNTRCT_STAT IS NULL, 'UNKNOWN', DQ.CNTRCT_STAT)                                     AS STATUS_TX,
        $V_SESSSTARTTIME                                                                           AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))   = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)   END AS CNTRCT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_STAT))) = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_STAT) END AS CNTRCT_STAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.P_CNTRCT)))    = 0 THEN ' ' ELSE RTRIM(SQ.P_CNTRCT)    END AS P_CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT)))      = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT)      END AS CNTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYP)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYP)  END AS CNTRCT_TYP,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.VNDR_ID,
            SQ.BYR_ID
        FROM AEP_DW_CONTRACT_VW SQ
        WHERE SQ.MOD_DT >  $V_START_TIME
          AND SQ.MOD_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM FELADM.FEL_COMTRAC_CONTRACT_FDR F
    WHERE UPPER(TRIM(F.CONTRACT_ID)) = SRC.IN_CONTRACT_ID
);
