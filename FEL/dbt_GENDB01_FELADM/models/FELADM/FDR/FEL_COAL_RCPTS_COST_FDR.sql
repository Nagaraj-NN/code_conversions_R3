-- ==========================================================================
-- Model      : FEL_COAL_RCPTS_COST_FDR
-- Mapping    : m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd
-- Target     : feladm.FEL_COAL_RCPTS_COST_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
-- lookup; the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
--
-- The lookup the UPDATE branch joined with an INNER JOIN is a LEFT
-- JOIN here so the INSERT branch keeps its rows. That lookup is cut
-- to one row per key by its QUALIFY, and the UPDATE post-hook still
-- filters on the lookup column, so a row that finds no match cannot
-- be updated. Row counts and results are unchanged.
--
-- Carried for the UPDATE branch only: LKP_RECEIPT_ID
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COAL_RCPTS_COST_FDR_SRC',
    meta={"mapping_name": "m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COAL_RCPTS_COST_FDR', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} TGT
     SET
         STATUS_TX    = SRC.STATUS_TX,
         RCPT_CST_AT  = SRC.RCPT_CST_AT,
         LAST_UPDT_TS = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.RECEIPT_ID   = SRC.LKP_RECEIPT_ID
       AND TGT.CST_CMPNT_CD = SRC.CST_CMPNT_CD",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} (
         RECEIPT_ID,
         CST_CMPNT_CD,
         STATUS_TX,
         RCPT_CST_AT,
         LAST_UPDT_TS
     )
     SELECT
         SRC.RECEIPT_ID,
         SRC.CST_CMPNT_CD,
         SRC.STATUS_TX,
         SRC.RCPT_CST_AT,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} F
         WHERE F.RECEIPT_ID                = SRC.RECEIPT_ID
           AND UPPER(TRIM(F.CST_CMPNT_CD)) = SRC.TRIM_COST_COMPONENT_CD
     )",
        log_model_end(this, 'TBD_FEL_COAL_RCPTS_COST_FDR', target_object='GENDB01.FELADM.FEL_COAL_RCPTS_COST_FDR')
    ]
) }}

SELECT
    CAST(DQ.RCPT_ID AS NUMBER(10,0))                                  AS RECEIPT_ID,
    DQ.RCPT_CST_TYPE                                                  AS CST_CMPNT_CD,
    UPPER(DQ.RCPT_CST_TYPE)                                           AS TRIM_COST_COMPONENT_CD,
    DQ.STATUS                                                         AS STATUS_TX,
    CAST(IFF(DQ.CST_AMT IS NOT NULL, DQ.CST_AMT, 0) AS NUMBER(12,3))  AS RCPT_CST_AT,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                        AS LAST_UPDT_TS,
    LKP.RECEIPT_ID                                                    AS LKP_RECEIPT_ID
FROM (
        SELECT
            SQ.RCPT_ID,
            SQ.CST_AMT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_TYPE))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_TYPE) END AS RCPT_CST_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))        = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)        END AS STATUS
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_RECEIPT_COSTDTL_VW_TEST') }} SQ  --USED FOR TESTING
        WHERE SQ.MODDATETIME >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MODDATETIME <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
    LEFT JOIN (
        SELECT
            F.RECEIPT_ID                    AS RECEIPT_ID,
            UPPER(TRIM(F.CST_CMPNT_CD))     AS CST_CMPNT_CD
        FROM {{ source('GENDB01_FELADM','FEL_COAL_RCPTS_COST_FDR') }} F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY F.RECEIPT_ID, UPPER(TRIM(F.CST_CMPNT_CD))
                                   ORDER BY F.RECEIPT_ID, UPPER(TRIM(F.CST_CMPNT_CD))) = 1
    ) LKP
      ON LKP.RECEIPT_ID   = CAST(DQ.RCPT_ID AS NUMBER(10,0))
     AND LKP.CST_CMPNT_CD = UPPER(DQ.RCPT_CST_TYPE)
