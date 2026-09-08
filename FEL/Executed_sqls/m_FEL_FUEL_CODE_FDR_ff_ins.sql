/*
================================================================================
 WORKFLOW  : wkf_FEL_STATIC_DIM_LOAD
 SESSION   : s_m_FEL_FUEL_CODE_FDR_ins
 MAPPING   : m_FEL_FUEL_CODE_FDR_ff_ins
 OPERATION : TRUNCATE + INSERT, full reload. Treat source rows as Insert, no
             router and no update strategy.
--------------------------------------------------------------------------------
 SOURCE    : FLAT FILE
             @FEL_INBOUND_STAGE/FuelCodes.csv
             GENDB01_DEV_SANDBOX.COMMON.FUELCODES_TEST  (USED FOR TESTING)
 LOOKUPS   : none
 TARGET    : GENDB01.FELADM.FEL_FUEL_CODE_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME is declared on the mapping but NOT REFERENCED
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : not applicable, the reader is a flat file
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE GENDB01.FELADM.FEL_FUEL_CODE_FDR;

INSERT INTO GENDB01.FELADM.FEL_FUEL_CODE_FDR (
    FUEL_CD,
    FUEL_CD_DESCN_TX,
    LAST_UPDT_TS
)
SELECT
    SRC.FUEL_CODE,
    SRC.O_FUEL_CODE_DESC,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.FUEL_CODE,
        LEFT(IFF(DQ.FUEL_NAME IS NULL, 'UNKNOWN', DQ.FUEL_NAME), 100)                AS O_FUEL_CODE_DESC,
        $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_CODE))) = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_CODE) END AS FUEL_CODE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FUEL_NAME))) = 0 THEN ' ' ELSE RTRIM(SQ.FUEL_NAME) END AS FUEL_NAME
        FROM (
            SELECT
                LEFT($1, 2)   AS FUEL_CODE,
                LEFT($2, 100) AS FUEL_NAME
            -- FROM @FEL_INBOUND_STAGE/FuelCodes.csv
            FROM GENDB01_DEV_SANDBOX.COMMON.FUELCODES_TEST  --USED FOR TESTING
                -- COMMENTED OUT AS SRC IS CREATED AS A TABLE
                --  (FILE_FORMAT => (TYPE = CSV
                --                   FIELD_DELIMITER = ','
                --                   FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                --                   SKIP_HEADER = 0
                --                   NULL_IF = ('*')
                --                   TRIM_SPACE = FALSE
                --                   ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
) SRC
WHERE SRC.FUEL_CODE IS NOT NULL;
