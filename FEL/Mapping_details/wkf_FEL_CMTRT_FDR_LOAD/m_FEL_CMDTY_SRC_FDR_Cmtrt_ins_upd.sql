/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_CMDTY_SRC_FDR_Cmtrt_ins_upd
 MAPPING   : m_FEL_CMDTY_SRC_FDR_Cmtrt_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW splits on the target lookup;
             the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_COMMODITYSOURCE_VW
 LOOKUP    : feladm.FEL_CMDTY_SRC_FDR   existence, keys ALLOCATED_ID + CMDTY_SRC_ID
             no lookup SQL override
 TARGET    : feladm.FEL_CMDTY_SRC_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : CMDTY_SRC_TYPE_NM is the constant 'Mine'. Dates default to 12/31/2099,
             text to ' '. ALCTD_CMDTY_SRC_NM is built as name(srcid,allocid).
             DISTRICT_NB uses TO_INTEGER, which yields 0 for non numeric text.
             ALLOCATED_PCT is written to decimal(5,3); values above 99.999 overflow.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_CMDTY_SRC_FDR TGT
SET
    CMDTY_SRC_EFCTV_DT    = SRC.CMDTY_SRC_EFCTV_DT,
    CMDTY_SRC_EXPR_DT     = SRC.CMDTY_SRC_EXPR_DT,
    CMDTY_SRC_NM          = SRC.CMDTY_SRC_NM,
    CMDTY_SRC_TYPE_NM     = SRC.CMDTY_SRC_TYPE_NM,
    CMDTY_SRC_SUB_TYPE_NM = SRC.CMDTY_SRC_SUB_TYPE_NM,
    CMDTY_SRC_STAT_TX     = SRC.CMDTY_SRC_STAT_TX,
    ALCTD_CMDTY_SRC_NM    = SRC.ALCTD_CMDTY_SRC_NM,
    ALLOCATED_PCT         = SRC.ALLOCATED_PCT,
    GEOG_BASIN_NM         = SRC.GEOG_BASIN_NM,
    LABOR_TYPE_NM         = SRC.LABOR_TYPE_NM,
    FUEL_TYPE_NM          = SRC.FUEL_TYPE_NM,
    MSHA_NB               = SRC.MSHA_NB,
    DISTRICT_NB           = SRC.DISTRICT_NB,
    STATE_NM              = SRC.STATE_NM,
    COUNTY_NM             = SRC.COUNTY_NM,
    LAST_UPDT_TS          = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.ALLC_ID AS NUMBER(10,0))                                                        AS ALLOCATED_ID,
        CAST(DQ.COMMSRC_ID AS NUMBER(10,0))                                                     AS CMDTY_SRC_ID,
        CAST(IFF(DQ.ALLOC_EFF_DT IS NOT NULL, DQ.ALLOC_EFF_DT, DATE '2099-12-31') AS DATE)      AS CMDTY_SRC_EFCTV_DT,
        CAST(IFF(DQ.ALLOC_EXP_DT IS NOT NULL, DQ.ALLOC_EXP_DT, DATE '2099-12-31') AS DATE)      AS CMDTY_SRC_EXPR_DT,
        IFF(DQ.COMMSRC_NME IS NOT NULL, DQ.COMMSRC_NME, ' ')                                    AS CMDTY_SRC_NM,
        'Mine'                                                                                  AS CMDTY_SRC_TYPE_NM,
        IFF(DQ.COMMSRC_SUB_TPE IS NOT NULL, DQ.COMMSRC_SUB_TPE, ' ')                            AS CMDTY_SRC_SUB_TYPE_NM,
        IFF(DQ.STATUS IS NOT NULL, DQ.STATUS, ' ')                                              AS CMDTY_SRC_STAT_TX,
        NVL(DQ.COMMSRC_NME, '') || '(' || NVL(CAST(CAST(DQ.COMMSRC_ID AS NUMBER(8,0)) AS VARCHAR), '')
            || ',' || NVL(CAST(CAST(DQ.ALLC_ID AS NUMBER(15,0)) AS VARCHAR), '') || ')'         AS ALCTD_CMDTY_SRC_NM,
        CAST(DQ.ALLOC_PCT AS NUMBER(5,3))                                                       AS ALLOCATED_PCT,
        IFF(DQ.GEO_BASN IS NOT NULL, DQ.GEO_BASN, ' ')                                          AS GEOG_BASIN_NM,
        IFF(DQ.LBR_TPE IS NOT NULL, DQ.LBR_TPE, ' ')                                            AS LABOR_TYPE_NM,
        IFF(DQ.FUEL_TPE IS NOT NULL, DQ.FUEL_TPE, ' ')                                          AS FUEL_TYPE_NM,
        IFF(DQ.MSHA_NBR IS NOT NULL, DQ.MSHA_NBR, ' ')                                          AS MSHA_NB,
        IFF(DQ.DSTRCT IS NULL, NULL, COALESCE(TRY_TO_NUMBER(DQ.DSTRCT), 0))                     AS DISTRICT_NB,
        IFF(DQ.ST_NME IS NOT NULL, DQ.ST_NME, ' ')                                              AS STATE_NM,
        IFF(DQ.CNTY_NME IS NOT NULL, DQ.CNTY_NME, ' ')                                          AS COUNTY_NM,
        $V_SESSSTARTTIME                                                                        AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.ALLC_ID,
            SQ.COMMSRC_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COMMSRC_NME)))      = 0 THEN ' ' ELSE RTRIM(SQ.COMMSRC_NME)      END AS COMMSRC_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.DSTRCT)))           = 0 THEN ' ' ELSE RTRIM(SQ.DSTRCT)           END AS DSTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.GEO_BASN)))         = 0 THEN ' ' ELSE RTRIM(SQ.GEO_BASN)         END AS GEO_BASN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ST_NME)))           = 0 THEN ' ' ELSE RTRIM(SQ.ST_NME)           END AS ST_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTY_NME)))         = 0 THEN ' ' ELSE RTRIM(SQ.CNTY_NME)         END AS CNTY_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COMMSRC_SUB_TPE)))  = 0 THEN ' ' ELSE RTRIM(SQ.COMMSRC_SUB_TPE)  END AS COMMSRC_SUB_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_TPE)))         = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_TPE)         END AS FUEL_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.LBR_TPE)))          = 0 THEN ' ' ELSE RTRIM(SQ.LBR_TPE)          END AS LBR_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))           = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)           END AS STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.MSHA_NBR)))         = 0 THEN ' ' ELSE RTRIM(SQ.MSHA_NBR)         END AS MSHA_NBR,
            SQ.ALLOC_PCT,
            SQ.ALLOC_EFF_DT,
            SQ.ALLOC_EXP_DT
        FROM AEP_DW_COMMODITYSOURCE_VW SQ
        WHERE SQ.MOD_DT >= $V_START_TIME
          AND SQ.MOD_DT <  $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE TGT.ALLOCATED_ID = SRC.ALLOCATED_ID
  AND TGT.CMDTY_SRC_ID = SRC.CMDTY_SRC_ID;

INSERT INTO feladm.FEL_CMDTY_SRC_FDR (
    ALLOCATED_ID,
    CMDTY_SRC_ID,
    CMDTY_SRC_EFCTV_DT,
    CMDTY_SRC_EXPR_DT,
    CMDTY_SRC_NM,
    CMDTY_SRC_TYPE_NM,
    CMDTY_SRC_SUB_TYPE_NM,
    CMDTY_SRC_STAT_TX,
    ALCTD_CMDTY_SRC_NM,
    ALLOCATED_PCT,
    GEOG_BASIN_NM,
    LABOR_TYPE_NM,
    FUEL_TYPE_NM,
    MSHA_NB,
    DISTRICT_NB,
    STATE_NM,
    COUNTY_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.ALLOCATED_ID,
    SRC.CMDTY_SRC_ID,
    SRC.CMDTY_SRC_EFCTV_DT,
    SRC.CMDTY_SRC_EXPR_DT,
    SRC.CMDTY_SRC_NM,
    SRC.CMDTY_SRC_TYPE_NM,
    SRC.CMDTY_SRC_SUB_TYPE_NM,
    SRC.CMDTY_SRC_STAT_TX,
    SRC.ALCTD_CMDTY_SRC_NM,
    SRC.ALLOCATED_PCT,
    SRC.GEOG_BASIN_NM,
    SRC.LABOR_TYPE_NM,
    SRC.FUEL_TYPE_NM,
    SRC.MSHA_NB,
    SRC.DISTRICT_NB,
    SRC.STATE_NM,
    SRC.COUNTY_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.ALLC_ID AS NUMBER(10,0))                                                        AS ALLOCATED_ID,
        CAST(DQ.COMMSRC_ID AS NUMBER(10,0))                                                     AS CMDTY_SRC_ID,
        CAST(IFF(DQ.ALLOC_EFF_DT IS NOT NULL, DQ.ALLOC_EFF_DT, DATE '2099-12-31') AS DATE)      AS CMDTY_SRC_EFCTV_DT,
        CAST(IFF(DQ.ALLOC_EXP_DT IS NOT NULL, DQ.ALLOC_EXP_DT, DATE '2099-12-31') AS DATE)      AS CMDTY_SRC_EXPR_DT,
        IFF(DQ.COMMSRC_NME IS NOT NULL, DQ.COMMSRC_NME, ' ')                                    AS CMDTY_SRC_NM,
        'Mine'                                                                                  AS CMDTY_SRC_TYPE_NM,
        IFF(DQ.COMMSRC_SUB_TPE IS NOT NULL, DQ.COMMSRC_SUB_TPE, ' ')                            AS CMDTY_SRC_SUB_TYPE_NM,
        IFF(DQ.STATUS IS NOT NULL, DQ.STATUS, ' ')                                              AS CMDTY_SRC_STAT_TX,
        NVL(DQ.COMMSRC_NME, '') || '(' || NVL(CAST(CAST(DQ.COMMSRC_ID AS NUMBER(8,0)) AS VARCHAR), '')
            || ',' || NVL(CAST(CAST(DQ.ALLC_ID AS NUMBER(15,0)) AS VARCHAR), '') || ')'         AS ALCTD_CMDTY_SRC_NM,
        CAST(DQ.ALLOC_PCT AS NUMBER(5,3))                                                       AS ALLOCATED_PCT,
        IFF(DQ.GEO_BASN IS NOT NULL, DQ.GEO_BASN, ' ')                                          AS GEOG_BASIN_NM,
        IFF(DQ.LBR_TPE IS NOT NULL, DQ.LBR_TPE, ' ')                                            AS LABOR_TYPE_NM,
        IFF(DQ.FUEL_TPE IS NOT NULL, DQ.FUEL_TPE, ' ')                                          AS FUEL_TYPE_NM,
        IFF(DQ.MSHA_NBR IS NOT NULL, DQ.MSHA_NBR, ' ')                                          AS MSHA_NB,
        IFF(DQ.DSTRCT IS NULL, NULL, COALESCE(TRY_TO_NUMBER(DQ.DSTRCT), 0))                     AS DISTRICT_NB,
        IFF(DQ.ST_NME IS NOT NULL, DQ.ST_NME, ' ')                                              AS STATE_NM,
        IFF(DQ.CNTY_NME IS NOT NULL, DQ.CNTY_NME, ' ')                                          AS COUNTY_NM,
        $V_SESSSTARTTIME                                                                        AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.ALLC_ID,
            SQ.COMMSRC_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COMMSRC_NME)))      = 0 THEN ' ' ELSE RTRIM(SQ.COMMSRC_NME)      END AS COMMSRC_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.DSTRCT)))           = 0 THEN ' ' ELSE RTRIM(SQ.DSTRCT)           END AS DSTRCT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.GEO_BASN)))         = 0 THEN ' ' ELSE RTRIM(SQ.GEO_BASN)         END AS GEO_BASN,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ST_NME)))           = 0 THEN ' ' ELSE RTRIM(SQ.ST_NME)           END AS ST_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CNTY_NME)))         = 0 THEN ' ' ELSE RTRIM(SQ.CNTY_NME)         END AS CNTY_NME,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COMMSRC_SUB_TPE)))  = 0 THEN ' ' ELSE RTRIM(SQ.COMMSRC_SUB_TPE)  END AS COMMSRC_SUB_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_TPE)))         = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_TPE)         END AS FUEL_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.LBR_TPE)))          = 0 THEN ' ' ELSE RTRIM(SQ.LBR_TPE)          END AS LBR_TPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))           = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)           END AS STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.MSHA_NBR)))         = 0 THEN ' ' ELSE RTRIM(SQ.MSHA_NBR)         END AS MSHA_NBR,
            SQ.ALLOC_PCT,
            SQ.ALLOC_EFF_DT,
            SQ.ALLOC_EXP_DT
        FROM AEP_DW_COMMODITYSOURCE_VW SQ
        WHERE SQ.MOD_DT >= $V_START_TIME
          AND SQ.MOD_DT <  $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_CMDTY_SRC_FDR LKP
    WHERE LKP.ALLOCATED_ID = SRC.ALLOCATED_ID
      AND LKP.CMDTY_SRC_ID = SRC.CMDTY_SRC_ID
);
