-- ==========================================================================
-- Model      : FEL_COST_CMPNT_DIM
-- Mapping    : m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd
-- Workflow   : wkf_FEL_STATIC_DIM_LOAD
-- Session    : s_m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_COST_CMPNT_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the dimension
-- lookup, with no change test; DEFAULT1 is discarded.
--
-- The Informatica router branches are preserved as validated: the model
-- holds the transformed source row set once, and the two post-hooks
-- apply the UPDATE branch and the INSERT branch to the real target.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_COST_CMPNT_DIM_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd", "workflow_name": "wkf_FEL_STATIC_DIM_LOAD", "session_name": "s_m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_COST_CMPNT_DIM', target_object='GENDB01.FELADM.FEL_COST_CMPNT_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_COST_CMPNT_DIM') }} TGT
     SET
         CST_CMPNT_ID       = SRC.CST_CMPNT_ID,
         CST_CMPNT_NM       = SRC.CST_CMPNT_NM,
         CST_CMPNT_CTGY_NM  = SRC.CST_CMPNT_CTGY_NM,
         CST_CMPNT_CD       = SRC.CST_CMPNT_CD,
         CST_CMPNT_DESCN_TX = SRC.CST_CMPNT_DESCN_TX,
         SYSTEM_ID          = SRC.SYSTEM_ID,
         SYSTEM_NM          = SRC.SYSTEM_NM,
         LAST_UPDT_TS       = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.CST_CMPNT_ID = SRC.CST_CMPNT_ID
       AND TGT.SYSTEM_ID    = SRC.SYSTEM_ID",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_COST_CMPNT_DIM') }} (
         CST_CMPNT_KEY,
         CST_CMPNT_ID,
         CST_CMPNT_NM,
         CST_CMPNT_CTGY_NM,
         CST_CMPNT_CD,
         CST_CMPNT_DESCN_TX,
         SYSTEM_ID,
         SYSTEM_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.CST_CMPNT_KEY,
         SRC.CST_CMPNT_ID,
         SRC.CST_CMPNT_NM,
         SRC.CST_CMPNT_CTGY_NM,
         SRC.CST_CMPNT_CD,
         SRC.CST_CMPNT_DESCN_TX,
         SRC.SYSTEM_ID,
         SRC.SYSTEM_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_COST_CMPNT_DIM') }} L
         WHERE L.CST_CMPNT_ID = SRC.CST_CMPNT_ID
           AND L.SYSTEM_ID    = SRC.SYSTEM_ID
     )",
        log_model_end(this, 'TBD_FEL_COST_CMPNT_DIM', target_object='GENDB01.FELADM.FEL_COST_CMPNT_DIM')
    ]
) }}

SELECT
    CAST(DQ.RCPT_CST_COMP_ID AS NUMBER(5,0))                                   AS CST_CMPNT_ID,
    LEFT(IFF(DQ.RCPT_CST_COMP_NM   IS NULL, ' ', DQ.RCPT_CST_COMP_NM), 40)     AS CST_CMPNT_NM,
    LEFT(IFF(DQ.RCPT_CST_COMP_CAT  IS NULL, ' ', DQ.RCPT_CST_COMP_CAT), 40)    AS CST_CMPNT_CTGY_NM,
    LEFT(IFF(DQ.RCPT_CST_COMP_CD   IS NULL, ' ', DQ.RCPT_CST_COMP_CD), 25)     AS CST_CMPNT_CD,
    LEFT(IFF(DQ.RCPT_CST_COMP_DESC IS NULL, ' ', DQ.RCPT_CST_COMP_DESC), 250)  AS CST_CMPNT_DESCN_TX,
    CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                           AS SYSTEM_ID,
    LEFT('COMTRAC', 25)                                                        AS SYSTEM_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                 AS LAST_UPDT_TS,
    NVL((SELECT MAX(CST_CMPNT_KEY) FROM {{ source('GENDB01_FELADM','FEL_COST_CMPNT_DIM') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY DQ.RCPT_CST_COMP_ID) AS CST_CMPNT_KEY
FROM (
        SELECT
            SQ.RCPT_CST_COMP_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_NM)   END AS RCPT_CST_COMP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CAT)))  = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CAT)  END AS RCPT_CST_COMP_CAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CD)   END AS RCPT_CST_COMP_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_DESC))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_DESC) END AS RCPT_CST_COMP_DESC,
            (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')    AS V_SYS_ID
        FROM (
            SELECT
                CAST($1 AS NUMBER(8,0)) AS RCPT_CST_COMP_ID,
                LEFT($2, 100)           AS RCPT_CST_COMP_NM,
                LEFT($3, 100)           AS RCPT_CST_COMP_CAT,
                LEFT($4, 50)            AS RCPT_CST_COMP_CD,
                CAST($5 AS NUMBER(8,0)) AS RCPT_CST_COMP_KEY,
                LEFT($6, 255)           AS RCPT_CST_COMP_DESC
            FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','COST_TYPE_DIM_DATA_TEST') }}  --USED FOR TESTING
                -- COMMENTED OUT BCOZ THE SRC IS CREATED AS A TABLE
                --  (FILE_FORMAT => (TYPE = CSV
                --                   FIELD_DELIMITER = ','
                --                   FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                --                   SKIP_HEADER = 1
                --                   NULL_IF = ('*')
                --                   TRIM_SPACE = FALSE
                --                   ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
