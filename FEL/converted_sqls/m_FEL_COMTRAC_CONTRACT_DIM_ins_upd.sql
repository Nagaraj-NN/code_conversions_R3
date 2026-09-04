/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
 MAPPING   : m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
 OPERATION : INSERT + UPDATE from the feeder, then a SECOND UPDATE pass over the
             dimension itself. Three target instances, load order 1 for the feeder
             insert and update and 2 for the second pass.
--------------------------------------------------------------------------------
 SOURCES   : feladm.FEL_COMTRAC_CONTRACT_FDR, filtered on time, drives insert and
             update; feladm.FEL_CONTRACT_DIM, SYSTEM_NM = 'COMTRAC', the second pass
 LOOKUPS   : six, all Use Any Value. FEL_SYSTEM_DIM 'COMTRAC' and
             MAX(CONTRACT_KEY) are unconnected; FEL_CONTRACT_DIM on the upper
             trimmed CONTRACT_ID + SYSTEM_ID, FEL_BSNS_ENTY_DIM for the vendor and
             buyer names, and FEL_CONTRACT_DIM again for the latest expiring
             contract in each parent, are connected. FEL_DATATYPE_DIM is unread.
 TARGET    : FELADM.FEL_CONTRACT_DIM   three instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$RUN_STATUS  (SQ source filter)
             $$REC_STATUS is declared but not referenced
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none on either source qualifier, source filters only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The router splits on the contract lookup alone, with no change test,
             so every matched feeder row is updated.
             The payment term, format, obligation and commodity columns are the
             constant 'N/A', as are the vendor and opco names on a lookup miss.
             The second pass rewrites the vendor and opco names of every COMTRAC
             contract from the row with the highest CNTRCT_EXPR_DT in its parent,
             so it must run after the first two statements.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE FELADM.FEL_CONTRACT_DIM TGT
SET
    CONTRACT_ID         = SRC.CONTRACT_ID,
    CNTRCT_EFCTV_DT     = SRC.CNTRCT_EFCTV_DT,
    CNTRCT_EXPR_DT      = SRC.CNTRCT_EXPR_DT,
    PARNT_CNTRCT_NM     = SRC.PARNT_CNTRCT_NM,
    CONTRACT_NM         = SRC.CONTRACT_NM,
    CNTRCT_TYPE_NM      = SRC.CNTRCT_TYPE_NM,
    CURR_CNTRCT_VNDR_NM = SRC.CURR_CNTRCT_VNDR_NM,
    CURR_OPCO_NM        = SRC.CURR_OPCO_NM,
    STATUS_TX           = SRC.STATUS_TX,
    CNTRCT_PYMT_TRM_NM  = SRC.CNTRCT_PYMT_TRM_NM,
    CNTRCT_FRMT_TX      = SRC.CNTRCT_FRMT_TX,
    CNTRCT_OBLGN_TX     = SRC.CNTRCT_OBLGN_TX,
    CNTRCT_CMDTY_NM     = SRC.CNTRCT_CMDTY_NM,
    SYSTEM_ID           = SRC.SYSTEM_ID,
    SYSTEM_NM           = SRC.SYSTEM_NM,
    LAST_UPDT_TS        = SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CONTRACT_ID,
        DQ.CNTRCT_EFCTV_DT,
        DQ.CNTRCT_EXPR_DT,
        DQ.PARNT_CNTRCT_NM,
        DQ.CONTRACT_NM,
        DQ.CNTRCT_TYPE_NM,
        LEFT(IFF(LKP_VND.BSNS_ENTY_NM IS NULL, 'N/A', LKP_VND.BSNS_ENTY_NM), 75)  AS CURR_CNTRCT_VNDR_NM,
        LEFT(IFF(LKP_BYR.BSNS_ENTY_NM IS NULL, 'N/A', LKP_BYR.BSNS_ENTY_NM), 75)  AS CURR_OPCO_NM,
        DQ.STATUS_TX,
        'N/A'                                                                     AS CNTRCT_PYMT_TRM_NM,
        'N/A'                                                                     AS CNTRCT_FRMT_TX,
        'N/A'                                                                     AS CNTRCT_OBLGN_TX,
        'N/A'                                                                     AS CNTRCT_CMDTY_NM,
        CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                          AS SYSTEM_ID,
        'COMTRAC'                                                                 AS SYSTEM_NM,
        DQ.V_TRIM_CONTRACT_ID,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CNTRCT_EFCTV_DT,
            SQ.CNTRCT_EXPR_DT,
            SQ.CURR_CNTRCT_VNDR_ID,
            SQ.CURR_BYR_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID)     END AS CONTRACT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PARNT_CNTRCT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.PARNT_CNTRCT_NM) END AS PARNT_CNTRCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_NM)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_NM)     END AS CONTRACT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYPE_NM)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYPE_NM)  END AS CNTRCT_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))       = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)       END AS STATUS_TX,
            UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID) END)  AS V_TRIM_CONTRACT_ID,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')                           AS V_SYS_ID,
            NVL((SELECT MAX(CONTRACT_KEY) FROM FELADM.FEL_CONTRACT_DIM), 0)
                + ROW_NUMBER() OVER (ORDER BY SQ.CONTRACT_ID)                                                  AS O_CONTRACT_KEY
        FROM feladm.FEL_COMTRAC_CONTRACT_FDR SQ
        WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM feladm.FEL_BSNS_ENTY_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_VND
      ON LKP_VND.BSNS_ENTY_ID = DQ.CURR_CNTRCT_VNDR_ID
     AND LKP_VND.SYSTEM_ID    = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM feladm.FEL_BSNS_ENTY_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_BYR
      ON LKP_BYR.BSNS_ENTY_ID = DQ.CURR_BYR_ID
     AND LKP_BYR.SYSTEM_ID    = DQ.V_SYS_ID
) SRC
WHERE UPPER(TRIM(TGT.CONTRACT_ID)) = SRC.V_TRIM_CONTRACT_ID
  AND TGT.SYSTEM_ID                = SRC.SYSTEM_ID;

INSERT INTO FELADM.FEL_CONTRACT_DIM (
    CONTRACT_KEY,
    CONTRACT_ID,
    CNTRCT_EFCTV_DT,
    CNTRCT_EXPR_DT,
    PARNT_CNTRCT_NM,
    CONTRACT_NM,
    CNTRCT_TYPE_NM,
    CURR_CNTRCT_VNDR_NM,
    CURR_OPCO_NM,
    STATUS_TX,
    CNTRCT_PYMT_TRM_NM,
    CNTRCT_FRMT_TX,
    CNTRCT_OBLGN_TX,
    CNTRCT_CMDTY_NM,
    SYSTEM_ID,
    SYSTEM_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.CONTRACT_KEY,
    SRC.CONTRACT_ID,
    SRC.CNTRCT_EFCTV_DT,
    SRC.CNTRCT_EXPR_DT,
    SRC.PARNT_CNTRCT_NM,
    SRC.CONTRACT_NM,
    SRC.CNTRCT_TYPE_NM,
    SRC.CURR_CNTRCT_VNDR_NM,
    SRC.CURR_OPCO_NM,
    SRC.STATUS_TX,
    SRC.CNTRCT_PYMT_TRM_NM,
    SRC.CNTRCT_FRMT_TX,
    SRC.CNTRCT_OBLGN_TX,
    SRC.CNTRCT_CMDTY_NM,
    SRC.SYSTEM_ID,
    SRC.SYSTEM_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.O_CONTRACT_KEY AS NUMBER(10,0))                                   AS CONTRACT_KEY,
        DQ.CONTRACT_ID,
        DQ.CNTRCT_EFCTV_DT,
        DQ.CNTRCT_EXPR_DT,
        DQ.PARNT_CNTRCT_NM,
        DQ.CONTRACT_NM,
        DQ.CNTRCT_TYPE_NM,
        LEFT(IFF(LKP_VND.BSNS_ENTY_NM IS NULL, 'N/A', LKP_VND.BSNS_ENTY_NM), 75)  AS CURR_CNTRCT_VNDR_NM,
        LEFT(IFF(LKP_BYR.BSNS_ENTY_NM IS NULL, 'N/A', LKP_BYR.BSNS_ENTY_NM), 75)  AS CURR_OPCO_NM,
        DQ.STATUS_TX,
        'N/A'                                                                     AS CNTRCT_PYMT_TRM_NM,
        'N/A'                                                                     AS CNTRCT_FRMT_TX,
        'N/A'                                                                     AS CNTRCT_OBLGN_TX,
        'N/A'                                                                     AS CNTRCT_CMDTY_NM,
        CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                          AS SYSTEM_ID,
        'COMTRAC'                                                                 AS SYSTEM_NM,
        DQ.V_TRIM_CONTRACT_ID,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CNTRCT_EFCTV_DT,
            SQ.CNTRCT_EXPR_DT,
            SQ.CURR_CNTRCT_VNDR_ID,
            SQ.CURR_BYR_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID)     END AS CONTRACT_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PARNT_CNTRCT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.PARNT_CNTRCT_NM) END AS PARNT_CNTRCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_NM)))     = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_NM)     END AS CONTRACT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_TYPE_NM)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_TYPE_NM)  END AS CNTRCT_TYPE_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS_TX)))       = 0 THEN ' ' ELSE RTRIM(SQ.STATUS_TX)       END AS STATUS_TX,
            UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_ID) END)  AS V_TRIM_CONTRACT_ID,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')                           AS V_SYS_ID,
            NVL((SELECT MAX(CONTRACT_KEY) FROM FELADM.FEL_CONTRACT_DIM), 0)
                + ROW_NUMBER() OVER (ORDER BY SQ.CONTRACT_ID)                                                  AS O_CONTRACT_KEY
        FROM feladm.FEL_COMTRAC_CONTRACT_FDR SQ
        WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM feladm.FEL_BSNS_ENTY_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_VND
      ON LKP_VND.BSNS_ENTY_ID = DQ.CURR_CNTRCT_VNDR_ID
     AND LKP_VND.SYSTEM_ID    = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT BSNS_ENTY_NM, BSNS_ENTY_ID, SYSTEM_ID
        FROM feladm.FEL_BSNS_ENTY_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_NM) = 1
    ) LKP_BYR
      ON LKP_BYR.BSNS_ENTY_ID = DQ.CURR_BYR_ID
     AND LKP_BYR.SYSTEM_ID    = DQ.V_SYS_ID
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_CONTRACT_DIM L
    WHERE UPPER(TRIM(L.CONTRACT_ID)) = SRC.V_TRIM_CONTRACT_ID
      AND L.SYSTEM_ID                = SRC.SYSTEM_ID
);

UPDATE FELADM.FEL_CONTRACT_DIM TGT
SET
    CURR_CNTRCT_VNDR_NM = SRC.CURR_CNTRCT_VNDR_NM,
    CURR_OPCO_NM        = SRC.CURR_OPCO_NM,
    LAST_UPDT_TS        = SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CONTRACT_KEY,
        LEFT(LKP_CN.CURR_CNTRCT_VNDR_NM, 50)   AS CURR_CNTRCT_VNDR_NM,
        LEFT(LKP_CN.CURR_OPCO_NM, 50)          AS CURR_OPCO_NM,
        $V_SESSSTARTTIME                       AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CONTRACT_KEY,
            UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PARNT_CNTRCT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.PARNT_CNTRCT_NM) END) AS O_PARENT_CONTRACT_NAME
        FROM feladm.FEL_CONTRACT_DIM SQ
        WHERE SQ.SYSTEM_NM = 'COMTRAC'
    ) DQ
    LEFT JOIN (
        SELECT c.curr_cntrct_vndr_nm, c.curr_opco_nm, UPPER(c.parnt_cntrct_nm) AS parnt_cntrct_nm
        FROM feladm.fel_contract_dim c
        INNER JOIN (
            SELECT d.parnt_cntrct_nm AS pname, MAX(d.cntrct_expr_dt) AS max_date
            FROM feladm.fel_contract_dim d
            WHERE UPPER(TRIM(d.system_nm)) = 'COMTRAC'
            GROUP BY d.parnt_cntrct_nm
        ) m
          ON c.parnt_cntrct_nm = m.pname
         AND c.cntrct_expr_dt  = m.max_date
        WHERE UPPER(TRIM(c.system_nm)) = 'COMTRAC'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(c.parnt_cntrct_nm)
                                   ORDER BY c.curr_cntrct_vndr_nm, c.curr_opco_nm) = 1
    ) LKP_CN
      ON LKP_CN.parnt_cntrct_nm = DQ.O_PARENT_CONTRACT_NAME
) SRC
WHERE TGT.CONTRACT_KEY = SRC.CONTRACT_KEY;
