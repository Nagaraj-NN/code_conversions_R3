/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_CNTRCT_PROD_CD_DIM_ins_upd
 MAPPING   : m_FEL_CNTRCT_PROD_CD_DIM_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_INS_UPD splits on the dimension
             lookup alone; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR   filtered on time
 LOOKUPS   : four, all Use Any Value. FEL_SYSTEM_DIM $$COMTRAC and
             MAX(CNTRCT_PROD_KEY) are unconnected; FEL_CNTRCT_PROD_CD_DIM on
             CNTRCT_DTL_ID and FEL_CONTRACT_DIM on CONTRACT_ID + SYSTEM_ID are
             connected. The last three carry SQL overrides that trim.
 TARGET    : feladm.FEL_CNTRCT_PROD_CD_DIM   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$RUN_STATUS (SQ filter), $$COMTRAC (system lookup)
             $$REC_STATUS is declared but not referenced
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only:
                 LAST_UPDT_TS >= '$$START_TIME' AND '$$RUN_STATUS' = 'C'
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : EXPTRANS1 computes changed_flg over eleven columns, but the router
             UPDATE group is only NOT ISNULL(lkp_CNTRCT_PROD_KEY), so the flag is
             never read and every matched row is updated. Reproduced as authored,
             which is why there is no change test in the UPDATE below.
             CONTRACT_KEY falls back to -2 and both contract names to 'UNKNOWN'
             when the contract dimension lookup misses.
             The surrogate key is the max key plus a counter incremented once per
             row read, UPSTREAM of the router, so keys are not contiguous.
             The captured run read 4 rows and updated all 4.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_COMTRAC       = 'COMTRAC';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_CNTRCT_PROD_CD_DIM TGT
SET
    CNTRCT_DTL_ID   = SRC.CNTRCT_DTL_ID,
    CONTRACT_KEY    = SRC.CONTRACT_KEY,
    PRODUCT_CD      = SRC.PRODUCT_CD,
    PRODUCT_NM      = SRC.PRODUCT_NM,
    PARNT_CNTRCT_NM = SRC.PARNT_CNTRCT_NM,
    CONTRACT_NM     = SRC.CONTRACT_NM,
    FOB_POINT_TX    = SRC.FOB_POINT_TX,
    SHP_MTHD_TX     = SRC.SHP_MTHD_TX,
    EFFECTIVE_DT    = SRC.EFFECTIVE_DT,
    EXPIRATION_DT   = SRC.EXPIRATION_DT,
    MODIFIED_DT     = SRC.MODIFIED_DT,
    LAST_UPDT_TS    = SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CNTRCT_DTL_ID,
        CAST(IFF(LKP_CD.CONTRACT_KEY IS NULL, -2, LKP_CD.CONTRACT_KEY) AS NUMBER(10,0))    AS CONTRACT_KEY,
        DQ.PRODUCT_CD,
        DQ.PRODUCT_NM,
        LEFT(IFF(LKP_CD.PARNT_CNTRCT_NM IS NULL, 'UNKNOWN', LKP_CD.PARNT_CNTRCT_NM), 40)   AS PARNT_CNTRCT_NM,
        LEFT(IFF(LKP_CD.CONTRACT_NM IS NULL, 'UNKNOWN', LKP_CD.CONTRACT_NM), 40)           AS CONTRACT_NM,
        DQ.FOB_POINT_TX,
        DQ.SHP_MTHD_TX,
        DQ.EFFECTIVE_DT,
        DQ.EXPIRATION_DT,
        DQ.MODIFIED_DT,
        $V_SESSSTARTTIME                                                                   AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.CNTRCT_DTL_ID,
            SQ.EFFECTIVE_DT,
            SQ.EXPIRATION_DT,
            SQ.MODIFIED_DT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_CD)))  = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_CD)  END AS CONTRACT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_CD)   END AS PRODUCT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_NM)   END AS PRODUCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_POINT_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.FOB_POINT_TX) END AS FOB_POINT_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)  END AS SHP_MTHD_TX
        FROM feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR SQ
        WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT dim.CONTRACT_KEY, dim.PARNT_CNTRCT_NM, dim.CONTRACT_NM,
               TRIM(dim.CONTRACT_ID) AS CONTRACT_ID, dim.SYSTEM_ID
        FROM feladm.FEL_CONTRACT_DIM dim
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(dim.CONTRACT_ID), dim.SYSTEM_ID ORDER BY dim.CONTRACT_KEY) = 1
    ) LKP_CD
      ON LKP_CD.CONTRACT_ID = DQ.CONTRACT_CD
     AND LKP_CD.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)
) SRC
WHERE TGT.CNTRCT_DTL_ID = SRC.CNTRCT_DTL_ID;

INSERT INTO feladm.FEL_CNTRCT_PROD_CD_DIM (
    CNTRCT_PROD_KEY,
    CNTRCT_DTL_ID,
    CONTRACT_KEY,
    PRODUCT_CD,
    PRODUCT_NM,
    PARNT_CNTRCT_NM,
    CONTRACT_NM,
    FOB_POINT_TX,
    SHP_MTHD_TX,
    EFFECTIVE_DT,
    EXPIRATION_DT,
    MODIFIED_DT,
    LAST_UPDT_TS
)
SELECT
    SRC.CNTRCT_PROD_KEY,
    SRC.CNTRCT_DTL_ID,
    SRC.CONTRACT_KEY,
    SRC.PRODUCT_CD,
    SRC.PRODUCT_NM,
    SRC.PARNT_CNTRCT_NM,
    SRC.CONTRACT_NM,
    SRC.FOB_POINT_TX,
    SRC.SHP_MTHD_TX,
    SRC.EFFECTIVE_DT,
    SRC.EXPIRATION_DT,
    SRC.MODIFIED_DT,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.CNTRCT_DTL_ID,
        CAST(IFF(LKP_CD.CONTRACT_KEY IS NULL, -2, LKP_CD.CONTRACT_KEY) AS NUMBER(10,0))    AS CONTRACT_KEY,
        DQ.PRODUCT_CD,
        DQ.PRODUCT_NM,
        LEFT(IFF(LKP_CD.PARNT_CNTRCT_NM IS NULL, 'UNKNOWN', LKP_CD.PARNT_CNTRCT_NM), 40)   AS PARNT_CNTRCT_NM,
        LEFT(IFF(LKP_CD.CONTRACT_NM IS NULL, 'UNKNOWN', LKP_CD.CONTRACT_NM), 40)           AS CONTRACT_NM,
        DQ.FOB_POINT_TX,
        DQ.SHP_MTHD_TX,
        DQ.EFFECTIVE_DT,
        DQ.EXPIRATION_DT,
        DQ.MODIFIED_DT,
        $V_SESSSTARTTIME                                                                   AS LAST_UPDT_TS,
        NVL((SELECT MAX(CNTRCT_PROD_KEY) FROM FELADM.FEL_CNTRCT_PROD_CD_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY DQ.CNTRCT_DTL_ID)                                AS CNTRCT_PROD_KEY
    FROM (
        SELECT
            SQ.CNTRCT_DTL_ID,
            SQ.EFFECTIVE_DT,
            SQ.EXPIRATION_DT,
            SQ.MODIFIED_DT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CONTRACT_CD)))  = 0 THEN ' ' ELSE RTRIM(SQ.CONTRACT_CD)  END AS CONTRACT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_CD)   END AS PRODUCT_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PRODUCT_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.PRODUCT_NM)   END AS PRODUCT_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_POINT_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.FOB_POINT_TX) END AS FOB_POINT_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHP_MTHD_TX)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHP_MTHD_TX)  END AS SHP_MTHD_TX
        FROM feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR SQ
        WHERE SQ.LAST_UPDT_TS >= $V_START_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT dim.CONTRACT_KEY, dim.PARNT_CNTRCT_NM, dim.CONTRACT_NM,
               TRIM(dim.CONTRACT_ID) AS CONTRACT_ID, dim.SYSTEM_ID
        FROM feladm.FEL_CONTRACT_DIM dim
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(dim.CONTRACT_ID), dim.SYSTEM_ID ORDER BY dim.CONTRACT_KEY) = 1
    ) LKP_CD
      ON LKP_CD.CONTRACT_ID = DQ.CONTRACT_CD
     AND LKP_CD.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_CNTRCT_PROD_CD_DIM L
    WHERE L.CNTRCT_DTL_ID = SRC.CNTRCT_DTL_ID
);
