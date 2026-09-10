-- ==========================================================================
-- Model      : FEL_FV_BEGBAL_FACT
-- Mapping    : m_FEL_FV_BEGBAL_FACT_ins
-- Workflow   : wkf_FEL_COAL_FACT_LOAD
-- Session    : s_m_FEL_FV_BEGBAL_FACT_ins
-- Target     : GENDB01.FELADM.FEL_FV_BEGBAL_FACT
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
    meta={"mapping_name": "m_FEL_FV_BEGBAL_FACT_ins", "workflow_name": "wkf_FEL_COAL_FACT_LOAD", "session_name": "s_m_FEL_FV_BEGBAL_FACT_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_FV_BEGBAL_FACT', target_object='GENDB01.FELADM.FEL_FV_BEGBAL_FACT'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_FEL_FV_BEGBAL_FACT', target_object='GENDB01.FELADM.FEL_FV_BEGBAL_FACT')
    ]
) }}

SELECT
    CAST(SRC.ACCTG_MO_DAY_ID AS NUMBER(5,0))                                            AS ACCTG_MO_DAY_ID,
    CAST(IFF(LKP_BE.BSNS_ENTY_KEY IS NOT NULL, LKP_BE.BSNS_ENTY_KEY,
             IFF(SRC.JNT_OWNR_BSNS_ENTY_ID IS NULL, -2, -1)) AS NUMBER(10,0)) AS JNT_OWNR_BSNS_ENTY_KEY,
    CAST(IFF(LKP_AL.ACCTG_INVTRY_LOC_KEY IS NOT NULL, LKP_AL.ACCTG_INVTRY_LOC_KEY,
             IFF(SRC.ACCTG_INVTRY_LOC_NM IS NULL, -2, -1)) AS NUMBER(10,0)) AS ACCTG_INVTRY_LOC_KEY,
    CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NOT NULL, LKP_IL.INVTRY_LOC_KEY,
             IFF(SRC.ACCTG_INVTRY_LOC_NM IS NULL, -2, -1)) AS NUMBER(10,0)) AS INVTRY_LOC_KEY,
    CAST(SRC.V_SYSTEM_ID AS NUMBER(5,0))                                                AS SYSTEM_ID,
    CAST(IFF(SRC.LKP_TRAN_CLS_KEY IS NULL, -2, SRC.LKP_TRAN_CLS_KEY) AS NUMBER(10,0))   AS TRAN_CLS_KEY,
    CAST(IFF(LKP_IL.INVTRY_PRMRY_FCLTY_KEY IS NOT NULL, LKP_IL.INVTRY_PRMRY_FCLTY_KEY,
             IFF(SRC.ACCTG_INVTRY_LOC_NM IS NULL, -2, -1)) AS NUMBER(10,0)) AS GEOG_FCLTY_KEY,
    CAST(IFF(LKP_IL.INVTRY_SCNDRY_FCLTY_KEY IS NOT NULL, LKP_IL.INVTRY_SCNDRY_FCLTY_KEY,
             IFF(SRC.ACCTG_INVTRY_LOC_NM IS NULL, -2, -1)) AS NUMBER(10,0)) AS OWNING_FCLTY_KEY,
    CAST(IFF(LKP_AT.ACCT_TYP_KEY IS NOT NULL, LKP_AT.ACCT_TYP_KEY, 2) AS NUMBER(10,0))  AS ACCT_TYP_KEY,
    CAST(SRC.O_PERCENT_QTY_NB AS NUMBER(10,9))                                          AS PERCENT_QY,
    CAST(SRC.O_PERCENT_AMT_NB AS NUMBER(10,9))                                          AS PERCENT_AT,
    CAST(SRC.INVENTORY_QY AS NUMBER(18,9))                                              AS INVENTORY_QY,
    CAST(SRC.INVENTORY_AT AS NUMBER(18,9))                                              AS INVENTORY_AT,
    'N'                                                                                 AS DELETE_FL,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                          AS LAST_UPDT_TS
FROM (
    SELECT
        SQ.ACCTG_MO_DAY_ID,
        SQ.INVTRY_LOC_ID,
        SQ.ACCTG_INVTRY_LOC_NM,
        SQ.JNT_OWNR_BSNS_ENTY_ID,
        SQ.INVENTORY_QY,
        SQ.INVENTORY_AT,
        LEFT(LTRIM(RTRIM(UPPER(SQ.ACCTG_INVTRY_LOC_NM))), 30)                           AS O_ACCT_INV_LOC_NM,
        (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')        AS V_SYSTEM_ID,
        (SELECT MIN(DIM.TRAN_CLS_KEY)
           FROM {{ source('GENDB01_FELADM','FEL_TRAN_CLASS_DIM') }} DIM
          WHERE TRIM(UPPER(DIM.TRAN_CLS_LVL_5_NM)) = 'BEGINNING BALANCE')               AS LKP_TRAN_CLS_KEY,
        IFF(ROUND(IFF(SQ.SUM_QTY <> 0, SQ.INVENTORY_QY / NULLIF(SQ.SUM_QTY, 0), 0), 2) > 1
         OR ROUND(IFF(SQ.SUM_QTY <> 0, SQ.INVENTORY_QY / NULLIF(SQ.SUM_QTY, 0), 0), 2) < 0,
            0,
            ROUND(IFF(SQ.SUM_QTY <> 0, SQ.INVENTORY_QY / NULLIF(SQ.SUM_QTY, 0), 0), 2)) AS O_PERCENT_QTY_NB,
        IFF(ROUND(IFF(SQ.SUM_AMT <> 0, SQ.INVENTORY_AT / NULLIF(SQ.SUM_AMT, 0), 0), 2) > 1
         OR ROUND(IFF(SQ.SUM_AMT <> 0, SQ.INVENTORY_AT / NULLIF(SQ.SUM_AMT, 0), 0), 2) < 0,
            0,
            ROUND(IFF(SQ.SUM_AMT <> 0, SQ.INVENTORY_AT / NULLIF(SQ.SUM_AMT, 0), 0), 2)) AS O_PERCENT_AMT_NB
    FROM (
        SELECT
            f.ACCTG_MO_DAY_ID,
            f.INVTRY_LOC_ID,
            f.ACCTG_INVTRY_LOC_NM,
            f.JNT_OWNR_BSNS_ENTY_ID,
            f.INVENTORY_QY,
            f.INVENTORY_AT,
            ttl.sum_qty AS SUM_QTY,
            ttl.sum_amt AS SUM_AMT
        FROM {{ source('GENDB01_FELADM','FEL_FV_BEGBAL_FDR') }} f
        INNER JOIN (
            SELECT
                ACCTG_MO_DAY_ID,
                INVTRY_LOC_ID,
                SUM(INVENTORY_QY) AS sum_qty,
                SUM(INVENTORY_AT) AS sum_amt
            FROM {{ source('GENDB01_FELADM','FEL_FV_BEGBAL_FDR') }}
            GROUP BY ACCTG_MO_DAY_ID, INVTRY_LOC_ID
        ) ttl
          ON ttl.ACCTG_MO_DAY_ID = f.ACCTG_MO_DAY_ID
         AND ttl.INVTRY_LOC_ID   = f.INVTRY_LOC_ID
    ) SQ
) SRC
LEFT JOIN (
    SELECT BSNS_ENTY_KEY, BSNS_ENTY_ID, SYSTEM_ID
    FROM {{ source('GENDB01_FELADM','FEL_BSNS_ENTY_DIM') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_ID, SYSTEM_ID) = 1
) LKP_BE
  ON LKP_BE.BSNS_ENTY_ID = CAST(SRC.JNT_OWNR_BSNS_ENTY_ID AS NUMBER(10,0))
 AND LKP_BE.SYSTEM_ID    = SRC.V_SYSTEM_ID
LEFT JOIN (
    SELECT
        iloc.INVTRY_LOC_KEY,
        TRIM(UPPER(iloc.INVTRY_CMDTY_NM))      AS INVTRY_CMDTY_NM,
        TRIM(UPPER(iloc.INVTRY_CMDTY_TYPE_NM)) AS INVTRY_CMDTY_TYPE_NM,
        iloc.INVTRY_PRMRY_FCLTY_KEY,
        iloc.INVTRY_SCNDRY_FCLTY_KEY,
        iloc.INVTRY_LOC_ID,
        iloc.SYSTEM_ID
    FROM {{ source('GENDB01_FELADM','FEL_INVTRY_LOC_DIM') }} iloc
    QUALIFY ROW_NUMBER() OVER (PARTITION BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID ORDER BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID) = 1
) LKP_IL
  ON LKP_IL.INVTRY_LOC_ID = CAST(SRC.INVTRY_LOC_ID AS NUMBER(10,0))
 AND LKP_IL.SYSTEM_ID     = SRC.V_SYSTEM_ID
LEFT JOIN (
    SELECT
        aloc.ACCTG_INVTRY_LOC_KEY,
        TRIM(UPPER(aloc.ACCTG_INVTRY_LOC_NM))  AS ACCTG_INVTRY_LOC_NM,
        TRIM(UPPER(aloc.INVTRY_CMDTY_TYPE_NM)) AS INVTRY_CMDTY_TYPE_NM,
        TRIM(UPPER(aloc.INVTRY_CMDTY_NM))      AS INVTRY_CMDTY_NM
    FROM {{ source('GENDB01_FELADM','FEL_ACCTG_INVTRY_LOC_DIM') }} aloc
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(UPPER(aloc.ACCTG_INVTRY_LOC_NM)),
                     TRIM(UPPER(aloc.INVTRY_CMDTY_TYPE_NM)),
                     TRIM(UPPER(aloc.INVTRY_CMDTY_NM))
        ORDER BY     TRIM(UPPER(aloc.ACCTG_INVTRY_LOC_NM)),
                     TRIM(UPPER(aloc.INVTRY_CMDTY_TYPE_NM)),
                     TRIM(UPPER(aloc.INVTRY_CMDTY_NM))) = 1
) LKP_AL
  ON LKP_AL.ACCTG_INVTRY_LOC_NM  = NVL(LTRIM(RTRIM(SRC.O_ACCT_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(LKP_IL.INVTRY_CMDTY_NM)), '') || ')'
 AND LKP_AL.INVTRY_CMDTY_TYPE_NM = LKP_IL.INVTRY_CMDTY_TYPE_NM
 AND LKP_AL.INVTRY_CMDTY_NM      = LKP_IL.INVTRY_CMDTY_NM
LEFT JOIN (
    SELECT dim.ACCT_TYP_KEY, UPPER(TRIM(dim.ACCT_TYP_NM)) AS ACCT_TYP_NM
    FROM {{ source('GENDB01_FELADM','FEL_ACCT_TYP_DIM') }} dim
    QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(dim.ACCT_TYP_NM)) ORDER BY UPPER(TRIM(dim.ACCT_TYP_NM))) = 1
) LKP_AT
  ON LKP_AT.ACCT_TYP_NM = 'INVENTORY'
