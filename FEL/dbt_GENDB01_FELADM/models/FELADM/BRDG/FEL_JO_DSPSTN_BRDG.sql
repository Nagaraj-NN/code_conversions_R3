-- ==========================================================================
-- Model      : FEL_JO_DSPSTN_BRDG
-- Mapping    : m_FEL_JO_DSPSTN_BRDG_ins
-- Workflow   : wkf_FEL_COAL_FACT_LOAD
-- Session    : s_m_FEL_JO_DSPSTN_BRDG_ins
-- Target     : GENDB01.FELADM.FEL_JO_DSPSTN_BRDG
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- TRUNCATE + INSERT, full reload. No router, no update strategy.
--
-- Full reload. The Informatica writer carried Truncate target table
-- option = YES, run by the PRE-SESS thread ahead of the load, so the
-- truncate is a pre-hook here and the model itself is the target.
-- ==========================================================================

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_FEL_JO_DSPSTN_BRDG_ins", "workflow_name": "wkf_FEL_COAL_FACT_LOAD", "session_name": "s_m_FEL_JO_DSPSTN_BRDG_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_JO_DSPSTN_BRDG', target_object='GENDB01.FELADM.FEL_JO_DSPSTN_BRDG'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_JO_DSPSTN_BRDG', target_object='GENDB01.FELADM.FEL_JO_DSPSTN_BRDG')
    ]
) }}

SELECT
    CAST(IFF(LKP_MO.ACCTG_MO_DAY_ID IS NOT NULL, LKP_MO.ACCTG_MO_DAY_ID, -2) AS NUMBER(5,0))  AS ACCTG_MO_DAY_ID,
    IFF(SQ.TRAN_CLASS_LVL3 IS NOT NULL, LEFT(SQ.TRAN_CLASS_LVL3, 17), 'NA')                   AS TRAN_CLS_LVL_3_NM,
    CAST(SQ.PERCENT_QTY_NBR AS NUMBER(10,9))                                                  AS PERCENT_QY,
    CAST(SQ.PERCENT_AMT_NBR AS NUMBER(10,9))                                                  AS PERCENT_AT,
    CAST(IFF(LKP_BE.BSNS_ENTY_KEY IS NOT NULL, LKP_BE.BSNS_ENTY_KEY, -2) AS NUMBER(10,0))     AS BSNS_ENTY_KEY,
    CAST(IFF(LKP_GU.UNIT_KEY IS NOT NULL, LKP_GU.UNIT_KEY, -2) AS NUMBER(10,0))               AS UNIT_KEY,
    CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NOT NULL, LKP_IL.INVTRY_LOC_KEY, -2) AS NUMBER(10,0))   AS INVTRY_LOC_KEY,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                                AS LAST_UPDT_TS
FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_FV_JO_DISPOSED_VW_TEST') }} SQ
LEFT JOIN (
    SELECT ACCTG_MO_DAY_ID, MONTH_NB, CALENDAR_YEAR
    FROM {{ source('GENDB01_FELADM','FEL_ACCTG_MONTH_VW') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, CALENDAR_YEAR ORDER BY MONTH_NB, CALENDAR_YEAR) = 1
) LKP_MO
  ON LKP_MO.MONTH_NB      = CAST(DATE_PART(MONTH, SQ.ACCTG_MONTH) AS NUMBER(10,0))
 AND LKP_MO.CALENDAR_YEAR = CAST(DATE_PART(YEAR,  SQ.ACCTG_MONTH) AS NUMBER(10,0))
LEFT JOIN (
    SELECT BSNS_ENTY_KEY, BSNS_ENTY_ID, SYSTEM_ID
    FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_ID, SYSTEM_ID) = 1
) LKP_BE
  ON LKP_BE.BSNS_ENTY_ID = CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))
 AND LKP_BE.SYSTEM_ID    = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
LEFT JOIN (
    SELECT F.UNIT_KEY, TRIM(F.UNIT_ID) AS UNIT_ID, F.SYSTEM_ID
    FROM {{ source('GENDB01_FELADM','FEL_GNRTN_UNIT_DIM') }} F
    QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(F.UNIT_ID), F.SYSTEM_ID ORDER BY TRIM(F.UNIT_ID), F.SYSTEM_ID) = 1
) LKP_GU
  ON LKP_GU.UNIT_ID   = LEFT(TO_VARCHAR(CAST(SQ.UNIT_ID AS NUMBER(8,0))), 20)
 AND LKP_GU.SYSTEM_ID = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
LEFT JOIN (
    SELECT iloc.INVTRY_LOC_KEY, iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID
    FROM {{ source('GENDB01_FELADM','FEL_INVTRY_LOC_DIM') }} iloc
    QUALIFY ROW_NUMBER() OVER (PARTITION BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID ORDER BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID) = 1
) LKP_IL
  ON LKP_IL.INVTRY_LOC_ID = CAST(SQ.INV_LOC_ID AS NUMBER(10,0))
 AND LKP_IL.SYSTEM_ID     = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
