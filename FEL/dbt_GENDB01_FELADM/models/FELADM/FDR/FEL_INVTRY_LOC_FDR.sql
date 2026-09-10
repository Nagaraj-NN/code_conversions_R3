-- ==========================================================================
-- Model      : FEL_INVTRY_LOC_FDR
-- Mapping    : m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd
-- Workflow   : wkf_FEL_CMTRT_FDR_LOAD
-- Session    : s_m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd
-- Target     : GENDB01.FELADM.FEL_INVTRY_LOC_FDR
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
-- lookup; the unconnected DEFAULT1 group is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_INVTRY_LOC_FDR_SRC',
    meta={"mapping_name": "m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd", "workflow_name": "wkf_FEL_CMTRT_FDR_LOAD", "session_name": "s_m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_INVTRY_LOC_FDR', target_object='GENDB01.FELADM.FEL_INVTRY_LOC_FDR')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_INVTRY_LOC_FDR') }} TGT
     SET
         INVTRY_LOC_NM          = SRC.INVTRY_LOC_NM,
         INVTRY_CMDTY_TYPE_NM   = SRC.INVTRY_CMDTY_TYPE_NM,
         INVTRY_CMDTY_NM        = SRC.INVTRY_CMDTY_NM,
         INVTRY_LOC_TYPE_NM     = SRC.INVTRY_LOC_TYPE_NM,
         INVTRY_LOC_STAT_TX     = SRC.INVTRY_LOC_STAT_TX,
         INVTRY_LOC_DSPLY_NM    = SRC.INVTRY_LOC_DSPLY_NM,
         INVTRY_PRMRY_FCLTY_ID  = SRC.INVTRY_PRMRY_FCLTY_ID,
         INVTRY_SCNDRY_FCLTY_ID = SRC.INVTRY_SCNDRY_FCLTY_ID,
         LAST_UPDT_TS           = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.INVTRY_LOC_ID = SRC.INVTRY_LOC_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_INVTRY_LOC_FDR') }} (
         INVTRY_LOC_ID,
         INVTRY_LOC_NM,
         INVTRY_CMDTY_TYPE_NM,
         INVTRY_CMDTY_NM,
         INVTRY_LOC_TYPE_NM,
         INVTRY_LOC_STAT_TX,
         INVTRY_LOC_DSPLY_NM,
         INVTRY_PRMRY_FCLTY_ID,
         INVTRY_SCNDRY_FCLTY_ID,
         LAST_UPDT_TS
     )
     SELECT
         SRC.INVTRY_LOC_ID,
         SRC.INVTRY_LOC_NM,
         SRC.INVTRY_CMDTY_TYPE_NM,
         SRC.INVTRY_CMDTY_NM,
         SRC.INVTRY_LOC_TYPE_NM,
         SRC.INVTRY_LOC_STAT_TX,
         SRC.INVTRY_LOC_DSPLY_NM,
         SRC.INVTRY_PRMRY_FCLTY_ID,
         SRC.INVTRY_SCNDRY_FCLTY_ID,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_INVTRY_LOC_FDR') }} LKP
         WHERE LKP.INVTRY_LOC_ID = SRC.INVTRY_LOC_ID
     )",
        log_model_end(this, 'TBD_FEL_INVTRY_LOC_FDR', target_object='GENDB01.FELADM.FEL_INVTRY_LOC_FDR')
    ]
) }}

SELECT
    CAST(DQ.INV_LOC_ID AS NUMBER(10,0))                           AS INVTRY_LOC_ID,
    IFF(DQ.INV_LOC_NM IS NOT NULL, DQ.INV_LOC_NM, ' ')            AS INVTRY_LOC_NM,
    LEFT(IFF(DQ.CMDTY_TYPE IS NOT NULL, DQ.CMDTY_TYPE, ' '), 30)  AS INVTRY_CMDTY_TYPE_NM,
    IFF(DQ.CMDTY_NM IS NOT NULL, DQ.CMDTY_NM, ' ')                AS INVTRY_CMDTY_NM,
    IFF(DQ.INV_LOC_TYPE IS NOT NULL, DQ.INV_LOC_TYPE, ' ')        AS INVTRY_LOC_TYPE_NM,
    IFF(DQ.INV_STATUS IS NOT NULL, DQ.INV_STATUS, ' ')            AS INVTRY_LOC_STAT_TX,
    IFF(DQ.INV_LOC_DISP_NM IS NOT NULL, DQ.INV_LOC_DISP_NM, ' ')  AS INVTRY_LOC_DSPLY_NM,
    CAST(DQ.FK_PRIM_FCLTY_ID AS NUMBER(10,0))                     AS INVTRY_PRMRY_FCLTY_ID,
    CAST(DQ.FK_SEC_FCLTY_ID AS NUMBER(10,0))                      AS INVTRY_SCNDRY_FCLTY_ID,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                    AS LAST_UPDT_TS
FROM (
        SELECT
            SQ.INV_LOC_ID,
            SQ.FK_PRIM_FCLTY_ID,
            SQ.FK_SEC_FCLTY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_STATUS)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_STATUS)      END AS INV_STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_NM)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_NM)      END AS INV_LOC_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_DISP_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_DISP_NM) END AS INV_LOC_DISP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_TYPE)))      = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_TYPE)      END AS CMDTY_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_NM)))        = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_NM)        END AS CMDTY_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_TYPE)))    = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_TYPE)    END AS INV_LOC_TYPE
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_INVENTORYLOC_VW_TEST') }} SQ
        WHERE SQ.MOD_BY_DT >  TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS')
          AND SQ.MOD_BY_DT <= TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS')
          AND 'C' = 'C'
    ) DQ
