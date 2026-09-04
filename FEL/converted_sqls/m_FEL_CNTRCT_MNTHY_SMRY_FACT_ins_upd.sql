/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_FACT_LOAD
 SESSION   : s_m_FEL_CNTRCT_MNTHY_SMRY_FACT_ins_upd
 MAPPING   : m_FEL_CNTRCT_MNTHY_SMRY_FACT_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTRTRANS splits on the target fact
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR   full read, no filter
 LOOKUPS   : seven, all Use Any Value on multiple match. The system, contract
             product, facility, operating month, contract and date lookups are
             unconnected; the target fact is connected, for existence and change
             detection on the three keys. Facility and contract overrides trim.
 TARGET    : feladm.FEL_CNTRCT_MNTHY_SMRY_FACT   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS, $$REC_STATUS and $$COMTRAC are
             declared but NONE reach the generated SQL, see NOTES
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : EXIST_RECORD is (matched AND changed) OR (matched AND
             FDR_LAST_UPDT_TS >= $$START_TIME), but EXPTRANS.FDR_LAST_UPDT_TS has
             no incoming connector, so it is always null and the second branch can
             never fire. Only change detection is reproduced, which is also why no
             parameter appears in the SQL.
             flag_ChangedRecord uses plain <>, so a null on either side leaves the
             row unchanged rather than flagging it. Kept.
             The three key outputs carry no default, so a missed product, facility
             or operating month sends NULL into a NOT NULL key and is rejected.
             The captured run read 5666 rows and wrote none.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_CNTRCT_MNTHY_SMRY_FACT TGT
SET
    CONTRACT_KEY     = SRC.CONTRACT_KEY,
    CAL_DAY_ID       = SRC.CAL_DAY_ID,
    CNTRCTD_OBLGN_QY = SRC.CNTRCTD_OBLGN_QY,
    DELETE_FL        = SRC.DELETE_FL,
    LAST_UPDT_TS     = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(LKP_CP.CNTRCT_PROD_KEY AS NUMBER(10,0))                                  AS CNTRCT_PROD_KEY,
        CAST(LKP_FD.FACILITY_KEY AS NUMBER(10,0))                                     AS GEOG_FCLTY_KEY,
        CAST(LKP_OM.OPTD_MO_DAY_ID AS NUMBER(18,0))                                   AS OPRTG_MO_DAY_ID,
        CAST(IFF(LKP_CN.CONTRACT_KEY IS NOT NULL, LKP_CN.CONTRACT_KEY, -2) AS NUMBER(10,0)) AS CONTRACT_KEY,
        CAST(IFF(LKP_DT.DATE_ID IS NOT NULL, LKP_DT.DATE_ID, -2) AS NUMBER(5,0))      AS CAL_DAY_ID,
        CAST(DQ.CNTRCTD_OBLGN_QY AS NUMBER(14,5))                                     AS CNTRCTD_OBLGN_QY,
        'N'                                                                           AS DELETE_FL,
        $V_SESSSTARTTIME                                                              AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CNTRCT_DTL_ID,
            SQ.CNTRCT_DTL_OPRTG_DT,
            SQ.CNTRCTD_OBLGN_QY,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.FACILITY_ID) END AS FACILITY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID) END AS CONTRACT_ID
        FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR SQ
    ) DQ
    LEFT JOIN (
        SELECT CNTRCT_PROD_KEY, CNTRCT_DTL_ID
        FROM feladm.FEL_CNTRCT_PROD_CD_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY CNTRCT_DTL_ID ORDER BY CNTRCT_PROD_KEY) = 1
    ) LKP_CP
      ON LKP_CP.CNTRCT_DTL_ID = DQ.CNTRCT_DTL_ID
    LEFT JOIN (
        SELECT DIM.FACILITY_KEY, TRIM(UPPER(DIM.FACILITY_ID)) AS FACILITY_ID, DIM.SYSTEM_ID
        FROM feladm.FEL_FACILITY_DIM DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID ORDER BY DIM.FACILITY_KEY) = 1
    ) LKP_FD
      ON LKP_FD.FACILITY_ID = UPPER(DQ.FACILITY_ID)
     AND LKP_FD.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
    LEFT JOIN (
        SELECT OPTD_MO_DAY_ID, MONTH_NB, OPERATING_YEAR
        FROM FELADM.FEL_OPTG_MONTH_VW
        QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, OPERATING_YEAR ORDER BY MONTH_NB, OPERATING_YEAR) = 1
    ) LKP_OM
      ON LKP_OM.MONTH_NB       = CAST(DATE_PART(MONTH, DQ.CNTRCT_DTL_OPRTG_DT) AS NUMBER(10,0))
     AND LKP_OM.OPERATING_YEAR = CAST(DATE_PART(YEAR,  DQ.CNTRCT_DTL_OPRTG_DT) AS NUMBER(10,0))
    LEFT JOIN (
        SELECT cnt.CONTRACT_KEY, UPPER(TRIM(cnt.CONTRACT_ID)) AS CONTRACT_ID, cnt.SYSTEM_ID
        FROM feladm.FEL_CONTRACT_DIM cnt
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(cnt.CONTRACT_ID)), cnt.SYSTEM_ID ORDER BY cnt.CONTRACT_KEY) = 1
    ) LKP_CN
      ON LKP_CN.CONTRACT_ID = UPPER(DQ.CONTRACT_ID)
     AND LKP_CN.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
    LEFT JOIN (
        SELECT DATE_ID, FULL_DATE_DT
        FROM FELADM.AEP_DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
    ) LKP_DT
      ON LKP_DT.FULL_DATE_DT = DQ.CNTRCT_DTL_OPRTG_DT
) SRC
WHERE TGT.CNTRCT_PROD_KEY = SRC.CNTRCT_PROD_KEY
  AND TGT.GEOG_FCLTY_KEY  = SRC.GEOG_FCLTY_KEY
  AND TGT.OPRTG_MO_DAY_ID = SRC.OPRTG_MO_DAY_ID
  AND (   SRC.CONTRACT_KEY     <> TGT.CONTRACT_KEY
       OR SRC.CAL_DAY_ID       <> TGT.CAL_DAY_ID
       OR SRC.CNTRCTD_OBLGN_QY <> TGT.CNTRCTD_OBLGN_QY);

INSERT INTO feladm.FEL_CNTRCT_MNTHY_SMRY_FACT (
    CNTRCT_PROD_KEY,
    GEOG_FCLTY_KEY,
    OPRTG_MO_DAY_ID,
    CONTRACT_KEY,
    CAL_DAY_ID,
    CNTRCTD_OBLGN_QY,
    DELETE_FL,
    LAST_UPDT_TS
)
SELECT
    SRC.CNTRCT_PROD_KEY,
    SRC.GEOG_FCLTY_KEY,
    SRC.OPRTG_MO_DAY_ID,
    SRC.CONTRACT_KEY,
    SRC.CAL_DAY_ID,
    SRC.CNTRCTD_OBLGN_QY,
    SRC.DELETE_FL,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(LKP_CP.CNTRCT_PROD_KEY AS NUMBER(10,0))                                  AS CNTRCT_PROD_KEY,
        CAST(LKP_FD.FACILITY_KEY AS NUMBER(10,0))                                     AS GEOG_FCLTY_KEY,
        CAST(LKP_OM.OPTD_MO_DAY_ID AS NUMBER(18,0))                                   AS OPRTG_MO_DAY_ID,
        CAST(IFF(LKP_CN.CONTRACT_KEY IS NOT NULL, LKP_CN.CONTRACT_KEY, -2) AS NUMBER(10,0)) AS CONTRACT_KEY,
        CAST(IFF(LKP_DT.DATE_ID IS NOT NULL, LKP_DT.DATE_ID, -2) AS NUMBER(5,0))      AS CAL_DAY_ID,
        CAST(DQ.CNTRCTD_OBLGN_QY AS NUMBER(14,5))                                     AS CNTRCTD_OBLGN_QY,
        'N'                                                                           AS DELETE_FL,
        $V_SESSSTARTTIME                                                              AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CNTRCT_DTL_ID,
            SQ.CNTRCT_DTL_OPRTG_DT,
            SQ.CNTRCTD_OBLGN_QY,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.FACILITY_ID) END AS FACILITY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID) END AS CONTRACT_ID
        FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR SQ
    ) DQ
    LEFT JOIN (
        SELECT CNTRCT_PROD_KEY, CNTRCT_DTL_ID
        FROM feladm.FEL_CNTRCT_PROD_CD_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY CNTRCT_DTL_ID ORDER BY CNTRCT_PROD_KEY) = 1
    ) LKP_CP
      ON LKP_CP.CNTRCT_DTL_ID = DQ.CNTRCT_DTL_ID
    LEFT JOIN (
        SELECT DIM.FACILITY_KEY, TRIM(UPPER(DIM.FACILITY_ID)) AS FACILITY_ID, DIM.SYSTEM_ID
        FROM feladm.FEL_FACILITY_DIM DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID ORDER BY DIM.FACILITY_KEY) = 1
    ) LKP_FD
      ON LKP_FD.FACILITY_ID = UPPER(DQ.FACILITY_ID)
     AND LKP_FD.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
    LEFT JOIN (
        SELECT OPTD_MO_DAY_ID, MONTH_NB, OPERATING_YEAR
        FROM FELADM.FEL_OPTG_MONTH_VW
        QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, OPERATING_YEAR ORDER BY MONTH_NB, OPERATING_YEAR) = 1
    ) LKP_OM
      ON LKP_OM.MONTH_NB       = CAST(DATE_PART(MONTH, DQ.CNTRCT_DTL_OPRTG_DT) AS NUMBER(10,0))
     AND LKP_OM.OPERATING_YEAR = CAST(DATE_PART(YEAR,  DQ.CNTRCT_DTL_OPRTG_DT) AS NUMBER(10,0))
    LEFT JOIN (
        SELECT cnt.CONTRACT_KEY, UPPER(TRIM(cnt.CONTRACT_ID)) AS CONTRACT_ID, cnt.SYSTEM_ID
        FROM feladm.FEL_CONTRACT_DIM cnt
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(cnt.CONTRACT_ID)), cnt.SYSTEM_ID ORDER BY cnt.CONTRACT_KEY) = 1
    ) LKP_CN
      ON LKP_CN.CONTRACT_ID = UPPER(DQ.CONTRACT_ID)
     AND LKP_CN.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
    LEFT JOIN (
        SELECT DATE_ID, FULL_DATE_DT
        FROM FELADM.AEP_DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
    ) LKP_DT
      ON LKP_DT.FULL_DATE_DT = DQ.CNTRCT_DTL_OPRTG_DT
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_CNTRCT_MNTHY_SMRY_FACT L
    WHERE L.CNTRCT_PROD_KEY = SRC.CNTRCT_PROD_KEY
      AND L.GEOG_FCLTY_KEY  = SRC.GEOG_FCLTY_KEY
      AND L.OPRTG_MO_DAY_ID = SRC.OPRTG_MO_DAY_ID
);
