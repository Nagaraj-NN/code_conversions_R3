-- ==========================================================================
-- Model      : FEL_FV_BEGBAL_FDR
-- Mapping    : m_FEL_FV_BEGBAL_FDR_Cmtrt_ins
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_FV_BEGBAL_FDR
-- Target     : GENDB01.FELADM.FEL_FV_BEGBAL_FDR
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- TRUNCATE + INSERT, full reload. No router, no update strategy. Session
-- log: TRUNCATE TABLE FEL_FV_BEGBAL_FDR, then insert. The captured run
-- loaded 16652 rows.
--
-- Full reload. The Informatica writer carried Truncate target table
-- option = YES, run by the PRE-SESS thread ahead of the load, so the
-- truncate is a pre-hook here and the model itself is the target.
-- ==========================================================================

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_FEL_FV_BEGBAL_FDR_Cmtrt_ins", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_FV_BEGBAL_FDR"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_FV_BEGBAL_FDR', target_object='GENDB01.FELADM.FEL_FV_BEGBAL_FDR'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_FV_BEGBAL_FDR', target_object='GENDB01.FELADM.FEL_FV_BEGBAL_FDR')
    ]
) }}

SELECT
    CAST(IFF(LKP.DATE_ID IS NOT NULL, LKP.DATE_ID,
             IFF(SQ.PERENDDATE IS NULL, -2, -1)) AS NUMBER(5,0)) AS ACCTG_MO_DAY_ID,
    CAST(SQ.INV_LOC_ID AS NUMBER(10,0))         AS INVTRY_LOC_ID,
    SQ.ACCT_INV_LOC_NM                          AS ACCTG_INVTRY_LOC_NM,
    CAST(SQ.JO_BUSENT_ID AS NUMBER(10,0))       AS JNT_OWNR_BSNS_ENTY_ID,
    CAST(SQ.QUANTITY AS NUMBER(18,9))           AS INVENTORY_QY,
    CAST(SQ.AMOUNT AS NUMBER(18,9))             AS INVENTORY_AT,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)  AS LAST_UPDT_TS
FROM (
    SELECT
        VW.PERENDDATE,
        VW.INV_LOC_ID,
        VW.ACCT_INV_LOC_NM,
        VW.JO_BUSENT_ID,
        VW.QUANTITY,
        VW.AMOUNT
    FROM
        {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_FV_BEGBAL_VW_TEST') }} VW  --USED FOR TESTING
) SQ
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM {{ source('GENDB01_FELADM','AEP_DATE') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP
  ON LKP.FULL_DATE_DT = TRUNC(SQ.PERENDDATE, 'DD')
