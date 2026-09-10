-- ==========================================================================
-- Model      : FEL_FV_TRANS_FDR
-- Mapping    : m_FEL_FV_TRANS_FDR_Cmtrt_ins
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_FV_TRANS_FDR_Cmtrt_ins
-- Target     : GENDB01.FELADM.FEL_FV_TRANS_FDR
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- TRUNCATE + INSERT, full reload. No router, no update strategy. Session
-- log: TRUNCATE TABLE feladm.FEL_FV_TRANS_FDR, then insert. The captured
-- run loaded 2138256 rows.
--
-- Full reload. The Informatica writer carried Truncate target table
-- option = YES, run by the PRE-SESS thread ahead of the load, so the
-- truncate is a pre-hook here and the model itself is the target.
-- ==========================================================================

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_FEL_FV_TRANS_FDR_Cmtrt_ins", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_FV_TRANS_FDR_Cmtrt_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_FV_TRANS_FDR', target_object='GENDB01.FELADM.FEL_FV_TRANS_FDR'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_FV_TRANS_FDR', target_object='GENDB01.FELADM.FEL_FV_TRANS_FDR')
    ]
) }}

SELECT
    CAST(IFF(LKP_ACCT.DATE_ID IS NOT NULL, LKP_ACCT.DATE_ID,
             IFF(SQ.ACCT_YEAR_MONTH_DAY IS NULL, -2, -1)) AS NUMBER(5,0)) AS ACCTG_MO_DAY_ID,
    CAST(IFF(LKP_TRAN.DATE_ID IS NOT NULL, LKP_TRAN.DATE_ID,
             IFF(SQ.TRANSACTION_DATE IS NULL, -2, -1)) AS NUMBER(5,0)) AS CAL_DAY_ID,
    SQ.TRAN_CLS_LVL1_NM                         AS TRAN_CLS_LVL_1_NM,
    SQ.TRAN_CLASS_LVL2_NM                       AS TRAN_CLS_LVL_2_NM,
    SQ.TRAN_CLASS_LVL3_NM                       AS TRAN_CLS_LVL_3_NM,
    SQ.TRAN_CLASS_LVL4_NM                       AS TRAN_CLS_LVL_4_NM,
    SQ.TRAN_CLASS_LVL5_NM                       AS TRAN_CLS_LVL_5_NM,
    SQ.FAENTRY_TYPE                             AS ENTRY_TYP_NM,
    CAST(SQ.FAENTRY_ID AS NUMBER(10,0))         AS ENTRY_ID,
    SQ.FATRAN_TYPE                              AS TRAN_TYP_NM,
    CAST(SQ.FATRAN_ID AS NUMBER(10,0))          AS TRANSACTION_ID,
    SQ.FATRAN_DESC                              AS TRAN_DESCN_TX,
    SQ.ACCT_INV_LOC_NM                          AS ACCTG_INVTRY_LOC_NM,
    CAST(SQ.INV_LOC_ID AS NUMBER(10,0))         AS INVTRY_LOC_ID,
    IFF(SQ.GEN_UNIT_ID IS NULL, '0',
        CAST(CAST(SQ.GEN_UNIT_ID AS NUMBER(8,0)) AS VARCHAR)) AS UNIT_ID,
    SQ.CNTRCT_ID                                AS CONTRACT_ID,
    CAST(SQ.CNTRCTDTL_ID AS NUMBER(10,0))       AS CNTRCT_DTL_ID,
    SQ.CNTRC_PROD_CD                            AS CNTRCT_PROD_CD,
    SQ.ACCTTYPECLASSNAME                        AS ACCT_TYP_NM,
    SQ.SOURCETYPE                               AS SRC_TYP_NM,
    SQ.CF_GL_ACCT                               AS ACCOUNT_CD,
    CAST(SQ.CF_DEPT AS NUMBER(10,0))            AS EPM_DEPT_ID,
    SQ.CF_WORK_ORDER                            AS WO_ID,
    CAST(SQ.CF_COST_COMP AS NUMBER(10,0))       AS EPM_RSRC_TYP_ID,
    LEFT(SQ.CF_PROJ_COST_BU, 10)                AS PROJ_CST_BSNS_UNT_ID,
    SQ.CF_RESOURCE_CAT                          AS RSRC_SBCTGY_CD,
    CAST(SQ.CF_ABM_ACTIVITY AS NUMBER(10,0))    AS EPM_ABM_ACTV_ID,
    CAST(SQ.CF_PROJECT AS NUMBER(10,0))         AS EPM_PROJ_ID,
    CAST(SQ.CF_GL_BUS_UNIT AS NUMBER(10,0))     AS EPM_BSNS_UNT_GL_ID,
    CAST(SQ.QTY AS NUMBER(18,9))                AS TRANSACTION_QY,
    CAST(SQ.AMT AS NUMBER(18,9))                AS TRANSACTION_AT,
    CAST(SQ.RECLAIM_ID AS NUMBER(10,0))         AS RECLAIM_ID,
    CAST(SQ.RECEIPT_ID AS NUMBER(10,0))         AS RECEIPT_ID,
    CAST(SQ.JO_BSNS_ENTY_ID AS NUMBER(10,0))    AS JO_BSNS_ENTY_ID,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)  AS LAST_UPDT_TS
FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_FV_TRANS_VW_TEST') }} SQ  --USED FOR TESTING
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM {{ source('GENDB01_FELADM','AEP_DATE') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP_ACCT
  ON LKP_ACCT.FULL_DATE_DT = TRUNC(SQ.ACCT_YEAR_MONTH_DAY, 'DD')
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM {{ source('GENDB01_FELADM','AEP_DATE') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP_TRAN
  ON LKP_TRAN.FULL_DATE_DT = TRUNC(SQ.TRANSACTION_DATE, 'DD')
