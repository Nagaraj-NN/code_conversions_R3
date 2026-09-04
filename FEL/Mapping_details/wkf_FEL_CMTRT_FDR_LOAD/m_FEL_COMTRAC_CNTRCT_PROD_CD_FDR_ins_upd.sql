/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_CNTRCT_PROD_CD_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW splits on the target lookup;
             the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_CONTRACTDTL_VW
 LOOKUP    : feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR
             existence, keys CNTRCT_DTL_ID + CONTRACT_CD
             lookup SQL override PRESENT:
               SELECT FDR.CNTRCT_DTL_ID as CNTRCT_DTL_ID,
                      trim(FDR.CONTRACT_CD) as CONTRACT_CD
               FROM feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR FDR
 TARGET    : feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The two column lookup decides insert against update, but the writer
             keys the update on CNTRCT_DTL_ID alone. Both are reproduced.
             Null defaults: ' ' for the text columns, 01-01-1900 for the effective
             date, 01-01-2055 for the expiry date. No value is truncated.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR TGT
SET
    CONTRACT_CD   = SRC.CONTRACT_CD,
    PRODUCT_CD    = SRC.PRODUCT_CD,
    PRODUCT_NM    = SRC.PRODUCT_NM,
    FOB_POINT_TX  = SRC.FOB_POINT_TX,
    SHP_MTHD_TX   = SRC.SHP_MTHD_TX,
    EFFECTIVE_DT  = SRC.EFFECTIVE_DT,
    EXPIRATION_DT = SRC.EXPIRATION_DT,
    MODIFIED_DT   = SRC.MODIFIED_DT,
    LAST_UPDT_TS  = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                                                 AS CNTRCT_DTL_ID,
        DQ.CNTRCT_ID                                                                          AS CONTRACT_CD,
        IFF(DQ.PDCT_CDE IS NULL, ' ', DQ.PDCT_CDE)                                            AS PRODUCT_CD,
        IFF(DQ.NME IS NULL, ' ', DQ.NME)                                                      AS PRODUCT_NM,
        IFF(DQ.FOB_PT IS NULL, ' ', DQ.FOB_PT)                                                AS FOB_POINT_TX,
        IFF(DQ.SHIP_MTHD IS NULL, ' ', DQ.SHIP_MTHD)                                          AS SHP_MTHD_TX,
        CAST(IFF(DQ.EFF_DT IS NULL, DATE '1900-01-01', DQ.EFF_DT) AS DATE)                    AS EFFECTIVE_DT,
        CAST(IFF(DQ.EXP_DT IS NULL, DATE '2055-01-01', DQ.EXP_DT) AS DATE)                    AS EXPIRATION_DT,
        CAST(DQ.MOD_DT AS DATE)                                                               AS MODIFIED_DT,
        $V_SESSSTARTTIME                                                                      AS LAST_UPDT_TS,
        LKP.CNTRCT_DTL_ID                                                                     AS LKP_CNTRCT_DTL_ID
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)  END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PDCT_CDE)))   = 0 THEN ' ' ELSE RTRIM(SQ.PDCT_CDE)   END AS PDCT_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.NME)))        = 0 THEN ' ' ELSE RTRIM(SQ.NME)        END AS NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_PT)))     = 0 THEN ' ' ELSE RTRIM(SQ.FOB_PT)     END AS FOB_PT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHIP_MTHD)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHIP_MTHD)  END AS SHIP_MTHD,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.MOD_DT
        FROM AEP_DW_CONTRACTDTL_VW SQ
        WHERE SQ.MOD_DT >= $V_START_TIME
          AND SQ.MOD_DT <  $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT
            FDR.CNTRCT_DTL_ID          AS CNTRCT_DTL_ID,
            TRIM(FDR.CONTRACT_CD)      AS CONTRACT_CD
        FROM feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FDR.CNTRCT_DTL_ID, TRIM(FDR.CONTRACT_CD)
                                   ORDER BY FDR.CNTRCT_DTL_ID, TRIM(FDR.CONTRACT_CD)) = 1
    ) LKP
      ON LKP.CNTRCT_DTL_ID = CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))
     AND LKP.CONTRACT_CD   = DQ.CNTRCT_ID
) SRC
WHERE TGT.CNTRCT_DTL_ID = SRC.LKP_CNTRCT_DTL_ID;

INSERT INTO feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR (
    CNTRCT_DTL_ID,
    CONTRACT_CD,
    PRODUCT_CD,
    PRODUCT_NM,
    FOB_POINT_TX,
    SHP_MTHD_TX,
    EFFECTIVE_DT,
    EXPIRATION_DT,
    MODIFIED_DT,
    LAST_UPDT_TS
)
SELECT
    SRC.CNTRCT_DTL_ID,
    SRC.CONTRACT_CD,
    SRC.PRODUCT_CD,
    SRC.PRODUCT_NM,
    SRC.FOB_POINT_TX,
    SRC.SHP_MTHD_TX,
    SRC.EFFECTIVE_DT,
    SRC.EXPIRATION_DT,
    SRC.MODIFIED_DT,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.CNTRCTDTL_ID AS NUMBER(10,0))                                                 AS CNTRCT_DTL_ID,
        DQ.CNTRCT_ID                                                                          AS CONTRACT_CD,
        IFF(DQ.PDCT_CDE IS NULL, ' ', DQ.PDCT_CDE)                                            AS PRODUCT_CD,
        IFF(DQ.NME IS NULL, ' ', DQ.NME)                                                      AS PRODUCT_NM,
        IFF(DQ.FOB_PT IS NULL, ' ', DQ.FOB_PT)                                                AS FOB_POINT_TX,
        IFF(DQ.SHIP_MTHD IS NULL, ' ', DQ.SHIP_MTHD)                                          AS SHP_MTHD_TX,
        CAST(IFF(DQ.EFF_DT IS NULL, DATE '1900-01-01', DQ.EFF_DT) AS DATE)                    AS EFFECTIVE_DT,
        CAST(IFF(DQ.EXP_DT IS NULL, DATE '2055-01-01', DQ.EXP_DT) AS DATE)                    AS EXPIRATION_DT,
        CAST(DQ.MOD_DT AS DATE)                                                               AS MODIFIED_DT,
        $V_SESSSTARTTIME                                                                      AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTRCT_ID)))  = 0 THEN ' ' ELSE RTRIM(SQ.CNTRCT_ID)  END AS CNTRCT_ID,
            SQ.CNTRCTDTL_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PDCT_CDE)))   = 0 THEN ' ' ELSE RTRIM(SQ.PDCT_CDE)   END AS PDCT_CDE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.NME)))        = 0 THEN ' ' ELSE RTRIM(SQ.NME)        END AS NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FOB_PT)))     = 0 THEN ' ' ELSE RTRIM(SQ.FOB_PT)     END AS FOB_PT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.SHIP_MTHD)))  = 0 THEN ' ' ELSE RTRIM(SQ.SHIP_MTHD)  END AS SHIP_MTHD,
            SQ.EFF_DT,
            SQ.EXP_DT,
            SQ.MOD_DT
        FROM AEP_DW_CONTRACTDTL_VW SQ
        WHERE SQ.MOD_DT >= $V_START_TIME
          AND SQ.MOD_DT <  $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COMTRAC_CNTRCT_PROD_CD_FDR FDR
    WHERE FDR.CNTRCT_DTL_ID     = SRC.CNTRCT_DTL_ID
      AND TRIM(FDR.CONTRACT_CD) = SRC.CONTRACT_CD
);
