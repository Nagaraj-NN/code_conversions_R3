/*
================================================================================
 WORKFLOW  : wkf_FEL_STATIC_DIM_LOAD
 SESSION   : s_m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd
 MAPPING   : m_FEL_COMTRAC_COST_CMPNT_DIM_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_EXIST splits on the dimension
             lookup, with no change test; DEFAULT1 is discarded.
--------------------------------------------------------------------------------
 SOURCE    : FLAT FILE Cost_Type_Dim_Data.csv, comma delimited, double quoted, ONE
             HEADER ROW SKIPPED, null character '*', code page MS1252. Directory
             comes from $InputFile_SrcPath; the run read the fel inbound folder.
             Six columns: ID(8,0), NM(100), CAT(100), CD(50), KEY(8,0), DESC(255).
 LOOKUPS   : three, all Use Any Value. FEL_SYSTEM_DIM $$COMTRAC and
             MAX(CST_CMPNT_KEY) unconnected; FEL_COST_CMPNT_DIM connected.
 TARGET    : feladm.FEL_COST_CMPNT_DIM   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$COMTRAC  (system dimension lookup and SYSTEM_NM)
             $$START_TIME is declared on the mapping but NOT REFERENCED
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : not applicable, the reader is a flat file
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : SNOWFLAKE HAS NO FLAT FILE READER. The SELECT below reads the same
             file from a stage; @FEL_INBOUND_STAGE is a PLACEHOLDER to point at
             wherever the file lands. The inline FILE_FORMAT reproduces the
             Informatica flat file properties exactly, header row included.
             All four text columns default to a single space when null.
             RCPT_CST_COMP_KEY is read and cleaned but reaches no target column;
             the key is the max key plus a counter incremented once per row read,
             UPSTREAM of the router.
             The captured run read 15 rows and updated all 15.
================================================================================
*/

SET V_COMTRAC       = 'COMTRAC';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COST_CMPNT_DIM TGT
SET
    CST_CMPNT_ID       = SRC.CST_CMPNT_ID,
    CST_CMPNT_NM       = SRC.CST_CMPNT_NM,
    CST_CMPNT_CTGY_NM  = SRC.CST_CMPNT_CTGY_NM,
    CST_CMPNT_CD       = SRC.CST_CMPNT_CD,
    CST_CMPNT_DESCN_TX = SRC.CST_CMPNT_DESCN_TX,
    SYSTEM_ID          = SRC.SYSTEM_ID,
    SYSTEM_NM          = SRC.SYSTEM_NM,
    LAST_UPDT_TS       = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.RCPT_CST_COMP_ID AS NUMBER(5,0))                                         AS CST_CMPNT_ID,
        LEFT(IFF(DQ.RCPT_CST_COMP_NM   IS NULL, ' ', DQ.RCPT_CST_COMP_NM), 40)           AS CST_CMPNT_NM,
        LEFT(IFF(DQ.RCPT_CST_COMP_CAT  IS NULL, ' ', DQ.RCPT_CST_COMP_CAT), 40)          AS CST_CMPNT_CTGY_NM,
        LEFT(IFF(DQ.RCPT_CST_COMP_CD   IS NULL, ' ', DQ.RCPT_CST_COMP_CD), 25)           AS CST_CMPNT_CD,
        LEFT(IFF(DQ.RCPT_CST_COMP_DESC IS NULL, ' ', DQ.RCPT_CST_COMP_DESC), 250)        AS CST_CMPNT_DESCN_TX,
        CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                                 AS SYSTEM_ID,
        LEFT($V_COMTRAC, 25)                                                             AS SYSTEM_NM,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.RCPT_CST_COMP_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_NM)   END AS RCPT_CST_COMP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CAT)))  = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CAT)  END AS RCPT_CST_COMP_CAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CD)   END AS RCPT_CST_COMP_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_DESC))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_DESC) END AS RCPT_CST_COMP_DESC,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)    AS V_SYS_ID
        FROM (
            SELECT
                CAST($1 AS NUMBER(8,0)) AS RCPT_CST_COMP_ID,
                LEFT($2, 100)           AS RCPT_CST_COMP_NM,
                LEFT($3, 100)           AS RCPT_CST_COMP_CAT,
                LEFT($4, 50)            AS RCPT_CST_COMP_CD,
                CAST($5 AS NUMBER(8,0)) AS RCPT_CST_COMP_KEY,
                LEFT($6, 255)           AS RCPT_CST_COMP_DESC
            FROM @FEL_INBOUND_STAGE/Cost_Type_Dim_Data.csv
                 (FILE_FORMAT => (TYPE = CSV
                                  FIELD_DELIMITER = ','
                                  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                                  SKIP_HEADER = 1
                                  NULL_IF = ('*')
                                  TRIM_SPACE = FALSE
                                  ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
) SRC
WHERE TGT.CST_CMPNT_ID = SRC.CST_CMPNT_ID
  AND TGT.SYSTEM_ID    = SRC.SYSTEM_ID;

INSERT INTO feladm.FEL_COST_CMPNT_DIM (
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
FROM (
    SELECT
        CAST(DQ.RCPT_CST_COMP_ID AS NUMBER(5,0))                                         AS CST_CMPNT_ID,
        LEFT(IFF(DQ.RCPT_CST_COMP_NM   IS NULL, ' ', DQ.RCPT_CST_COMP_NM), 40)           AS CST_CMPNT_NM,
        LEFT(IFF(DQ.RCPT_CST_COMP_CAT  IS NULL, ' ', DQ.RCPT_CST_COMP_CAT), 40)          AS CST_CMPNT_CTGY_NM,
        LEFT(IFF(DQ.RCPT_CST_COMP_CD   IS NULL, ' ', DQ.RCPT_CST_COMP_CD), 25)           AS CST_CMPNT_CD,
        LEFT(IFF(DQ.RCPT_CST_COMP_DESC IS NULL, ' ', DQ.RCPT_CST_COMP_DESC), 250)        AS CST_CMPNT_DESCN_TX,
        CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                                 AS SYSTEM_ID,
        LEFT($V_COMTRAC, 25)                                                             AS SYSTEM_NM,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS,
        NVL((SELECT MAX(CST_CMPNT_KEY) FROM FELADM.FEL_COST_CMPNT_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY DQ.RCPT_CST_COMP_ID)                           AS CST_CMPNT_KEY
    FROM (
        SELECT
            SQ.RCPT_CST_COMP_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_NM)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_NM)   END AS RCPT_CST_COMP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CAT)))  = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CAT)  END AS RCPT_CST_COMP_CAT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_CD)))   = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_CD)   END AS RCPT_CST_COMP_CD,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_COMP_DESC))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_COMP_DESC) END AS RCPT_CST_COMP_DESC,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)    AS V_SYS_ID
        FROM (
            SELECT
                CAST($1 AS NUMBER(8,0)) AS RCPT_CST_COMP_ID,
                LEFT($2, 100)           AS RCPT_CST_COMP_NM,
                LEFT($3, 100)           AS RCPT_CST_COMP_CAT,
                LEFT($4, 50)            AS RCPT_CST_COMP_CD,
                CAST($5 AS NUMBER(8,0)) AS RCPT_CST_COMP_KEY,
                LEFT($6, 255)           AS RCPT_CST_COMP_DESC
            FROM @FEL_INBOUND_STAGE/Cost_Type_Dim_Data.csv
                 (FILE_FORMAT => (TYPE = CSV
                                  FIELD_DELIMITER = ','
                                  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                                  SKIP_HEADER = 1
                                  NULL_IF = ('*')
                                  TRIM_SPACE = FALSE
                                  ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COST_CMPNT_DIM L
    WHERE L.CST_CMPNT_ID = SRC.CST_CMPNT_ID
      AND L.SYSTEM_ID    = SRC.SYSTEM_ID
);
