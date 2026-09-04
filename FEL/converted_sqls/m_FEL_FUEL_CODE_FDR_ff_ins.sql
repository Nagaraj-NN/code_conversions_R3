/*
================================================================================
 WORKFLOW  : wkf_FEL_STATIC_DIM_LOAD
 SESSION   : s_m_FEL_FUEL_CODE_FDR_ins
 MAPPING   : m_FEL_FUEL_CODE_FDR_ff_ins
 OPERATION : TRUNCATE + INSERT, full reload. Treat source rows as Insert, no
             router and no update strategy.
--------------------------------------------------------------------------------
 SOURCE    : FLAT FILE FuelCodes.csv, comma delimited, double quoted, no header
             row, null character '*', code page MS1252, trailing blanks kept.
             Directory comes from the session parameter $InputFile_SrcPath; the
             captured run read /edwpb1/edwp/atomic/fel/datafiles/inbound.
             Two columns in order: FUEL_CODE(2), FUEL_NAME(100).
 LOOKUPS   : none
 TARGET    : feladm.FEL_FUEL_CODE_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME is declared on the mapping but NOT REFERENCED
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : not applicable, the reader is a flat file
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
--------------------------------------------------------------------------------
 NOTES     : SNOWFLAKE HAS NO FLAT FILE READER. The SELECT below reads the same
             file from a stage; @FEL_INBOUND_STAGE is a PLACEHOLDER to point at
             wherever the file lands. The inline FILE_FORMAT reproduces the
             Informatica flat file properties exactly.
             The data quality pass turns an empty or all-space field into a single
             space, so it is never null by the time the filter runs. FILTRANS drops
             rows whose FUEL_CODE is null, which after that pass can only happen
             on a null character '*' in the file.
             FUEL_CD_DESCN_TX becomes 'UNKNOWN' when the name is null.
             The captured run read and loaded 20 rows.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE feladm.FEL_FUEL_CODE_FDR;

INSERT INTO feladm.FEL_FUEL_CODE_FDR (
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
            FROM @FEL_INBOUND_STAGE/FuelCodes.csv
                 (FILE_FORMAT => (TYPE = CSV
                                  FIELD_DELIMITER = ','
                                  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
                                  SKIP_HEADER = 0
                                  NULL_IF = ('*')
                                  TRIM_SPACE = FALSE
                                  ENCODING = 'WINDOWS1252'))
        ) SQ
    ) DQ
) SRC
WHERE SRC.FUEL_CODE IS NOT NULL;
