/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_FV_TRANS_FDR_Cmtrt_ins
 MAPPING   : m_FEL_FV_TRANS_FDR_Cmtrt_ins
 OPERATION : TRUNCATE + INSERT, full reload. No router, no update strategy.
             Session log: TRUNCATE TABLE feladm.FEL_FV_TRANS_FDR, then insert.
             The captured run loaded 2138256 rows.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_FV_TRANS_VW   full read, no filter
 LOOKUP    : FELADM.AEP_DATE   UNCONNECTED, called twice as
             :LKP.LKP_AEP_DATE(trunc(<date>,'DD')) returning DATE_ID.
             Mapping connection is DMDB01X, the session overrides it to $Target.
             No lookup SQL override.
 TARGET    : feladm.FEL_FV_TRANS_FDR   single instance
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS are declared on the mapping but
             NOT REFERENCED, there is no source filter and no SQ query override.
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole view
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
--------------------------------------------------------------------------------
 NOTES     : The two date keys resolve through AEP_DATE, with -1 when the date is
             present but not found and -2 when the date is null.
             UNIT_ID is the numeric generating unit id as text, '0' when null.
             CF_PROJ_COST_BU is cut to 10 by the source qualifier port and
             FAENTRY_ID is narrowed from 38 to 8 digits by its port.
             Five PeopleSoft chartfield strings are written into numeric columns.
             Informatica rejects the single bad row; these casts fail the
             statement instead, which surfaces the same data rather than hiding it.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE feladm.FEL_FV_TRANS_FDR;

INSERT INTO feladm.FEL_FV_TRANS_FDR (
    ACCTG_MO_DAY_ID,
    CAL_DAY_ID,
    TRAN_CLS_LVL_1_NM,
    TRAN_CLS_LVL_2_NM,
    TRAN_CLS_LVL_3_NM,
    TRAN_CLS_LVL_4_NM,
    TRAN_CLS_LVL_5_NM,
    ENTRY_TYP_NM,
    ENTRY_ID,
    TRAN_TYP_NM,
    TRANSACTION_ID,
    TRAN_DESCN_TX,
    ACCTG_INVTRY_LOC_NM,
    INVTRY_LOC_ID,
    UNIT_ID,
    CONTRACT_ID,
    CNTRCT_DTL_ID,
    CNTRCT_PROD_CD,
    ACCT_TYP_NM,
    SRC_TYP_NM,
    ACCOUNT_CD,
    EPM_DEPT_ID,
    WO_ID,
    EPM_RSRC_TYP_ID,
    PROJ_CST_BSNS_UNT_ID,
    RSRC_SBCTGY_CD,
    EPM_ABM_ACTV_ID,
    EPM_PROJ_ID,
    EPM_BSNS_UNT_GL_ID,
    TRANSACTION_QY,
    TRANSACTION_AT,
    RECLAIM_ID,
    RECEIPT_ID,
    JO_BSNS_ENTY_ID,
    LAST_UPDT_TS
)
SELECT
    CAST(IFF(LKP_ACCT.DATE_ID IS NOT NULL, LKP_ACCT.DATE_ID,
             IFF(SQ.ACCT_YEAR_MONTH_DAY IS NULL, -2, -1)) AS NUMBER(5,0))       AS ACCTG_MO_DAY_ID,
    CAST(IFF(LKP_TRAN.DATE_ID IS NOT NULL, LKP_TRAN.DATE_ID,
             IFF(SQ.TRANSACTION_DATE IS NULL, -2, -1)) AS NUMBER(5,0))          AS CAL_DAY_ID,
    SQ.TRAN_CLS_LVL1_NM                                                          AS TRAN_CLS_LVL_1_NM,
    SQ.TRAN_CLASS_LVL2_NM                                                        AS TRAN_CLS_LVL_2_NM,
    SQ.TRAN_CLASS_LVL3_NM                                                        AS TRAN_CLS_LVL_3_NM,
    SQ.TRAN_CLASS_LVL4_NM                                                        AS TRAN_CLS_LVL_4_NM,
    SQ.TRAN_CLASS_LVL5_NM                                                        AS TRAN_CLS_LVL_5_NM,
    SQ.FAENTRY_TYPE                                                              AS ENTRY_TYP_NM,
    CAST(SQ.FAENTRY_ID AS NUMBER(10,0))                                          AS ENTRY_ID,
    SQ.FATRAN_TYPE                                                               AS TRAN_TYP_NM,
    CAST(SQ.FATRAN_ID AS NUMBER(10,0))                                           AS TRANSACTION_ID,
    SQ.FATRAN_DESC                                                               AS TRAN_DESCN_TX,
    SQ.ACCT_INV_LOC_NM                                                           AS ACCTG_INVTRY_LOC_NM,
    CAST(SQ.INV_LOC_ID AS NUMBER(10,0))                                          AS INVTRY_LOC_ID,
    IFF(SQ.GEN_UNIT_ID IS NULL, '0',
        CAST(CAST(SQ.GEN_UNIT_ID AS NUMBER(8,0)) AS VARCHAR))                    AS UNIT_ID,
    SQ.CNTRCT_ID                                                                 AS CONTRACT_ID,
    CAST(SQ.CNTRCTDTL_ID AS NUMBER(10,0))                                        AS CNTRCT_DTL_ID,
    SQ.CNTRC_PROD_CD                                                             AS CNTRCT_PROD_CD,
    SQ.ACCTTYPECLASSNAME                                                         AS ACCT_TYP_NM,
    SQ.SOURCETYPE                                                                AS SRC_TYP_NM,
    SQ.CF_GL_ACCT                                                                AS ACCOUNT_CD,
    CAST(SQ.CF_DEPT AS NUMBER(10,0))                                             AS EPM_DEPT_ID,
    SQ.CF_WORK_ORDER                                                             AS WO_ID,
    CAST(SQ.CF_COST_COMP AS NUMBER(10,0))                                        AS EPM_RSRC_TYP_ID,
    LEFT(SQ.CF_PROJ_COST_BU, 10)                                                 AS PROJ_CST_BSNS_UNT_ID,
    SQ.CF_RESOURCE_CAT                                                           AS RSRC_SBCTGY_CD,
    CAST(SQ.CF_ABM_ACTIVITY AS NUMBER(10,0))                                     AS EPM_ABM_ACTV_ID,
    CAST(SQ.CF_PROJECT AS NUMBER(10,0))                                          AS EPM_PROJ_ID,
    CAST(SQ.CF_GL_BUS_UNIT AS NUMBER(10,0))                                      AS EPM_BSNS_UNT_GL_ID,
    CAST(SQ.QTY AS NUMBER(18,9))                                                 AS TRANSACTION_QY,
    CAST(SQ.AMT AS NUMBER(18,9))                                                 AS TRANSACTION_AT,
    CAST(SQ.RECLAIM_ID AS NUMBER(10,0))                                          AS RECLAIM_ID,
    CAST(SQ.RECEIPT_ID AS NUMBER(10,0))                                          AS RECEIPT_ID,
    CAST(SQ.JO_BSNS_ENTY_ID AS NUMBER(10,0))                                     AS JO_BSNS_ENTY_ID,
    $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS
FROM AEP_DW_FV_TRANS_VW SQ
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM FELADM.AEP_DATE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP_ACCT
  ON LKP_ACCT.FULL_DATE_DT = TRUNC(SQ.ACCT_YEAR_MONTH_DAY, 'DD')
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM FELADM.AEP_DATE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP_TRAN
  ON LKP_TRAN.FULL_DATE_DT = TRUNC(SQ.TRANSACTION_DATE, 'DD');
