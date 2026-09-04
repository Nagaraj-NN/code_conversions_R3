/*
================================================================================
 WORKFLOW  : wkf_FEL_STATIC_DIM_LOAD
 SESSION   : s_m_FEL_SAMPLED_DIM_stat
 MAPPING   : m_FEL_SAMPLED_DIM_stat
 OPERATION : INSERT + UPDATE, data driven. RTRTRANS splits on the dimension
             lookup, with no change test; DEFAULT1 is discarded.
--------------------------------------------------------------------------------
 SOURCE    : COMTRACAPP.PERMVALUE, the missed sample reasons for the sampleproblem
             table, unioned with the literal 'Sampled'
 LOOKUP    : feladm.FEL_SAMPLED_DIM   existence on the upper trimmed reason,
             SQL override PRESENT, Use Any Value on multiple match
 TARGET    : feladm.FEL_SAMPLED_DIM   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME is declared on the mapping but NOT REFERENCED
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : PRESENT on SQ_PERMVALUE, reproduced verbatim below:
                 Select t.COLVALUETEXT from COMTRACAPP.PERMVALUE t
                 WHERE t.tablename = 'sampleproblem'
                   AND t.colname = 'missedsamplereason'
                 union
                 select 'Sampled' from dual
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : SAMPLED_TX is 'Sampled' when the reason is exactly 'Sampled', else
             'Unsampled'. DECODE compares case sensitively, so a differently cased
             value falls through to 'Unsampled'.
             SMPLD_RSN_TX keeps its ORIGINAL case; the lookup matches upper trimmed.
             SAMPLED_KEY comes from SEQ_FEL_SAMPLED_DIM, a PERSISTENT sequence at
             202, not reset per run; here it continues from the table maximum.
             The captured run read 8 rows and updated all 8.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_SAMPLED_DIM TGT
SET
    SMPLD_RSN_TX = SRC.SMPLD_RSN_TX,
    SAMPLED_TX   = SRC.SAMPLED_TX,
    LAST_UPDT_TS = SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.UNSMPLE_RSN_CDE                                                        AS SMPLD_RSN_TX,
        IFF(DQ.UNSMPLE_RSN_CDE = 'Sampled', 'Sampled', 'Unsampled')               AS SAMPLED_TX,
        UPPER(DQ.UNSMPLE_RSN_CDE)                                                 AS TRIM_SMPLD_RSN_TX,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COLVALUETEXT))) = 0 THEN ' ' ELSE RTRIM(SQ.COLVALUETEXT) END AS UNSMPLE_RSN_CDE
        FROM (
            SELECT t.COLVALUETEXT
            FROM COMTRACAPP.PERMVALUE t
            WHERE t.tablename = 'sampleproblem'
              AND t.colname   = 'missedsamplereason'
            UNION
            SELECT 'Sampled'
        ) SQ
    ) DQ
) SRC
WHERE UPPER(TRIM(TGT.SMPLD_RSN_TX)) = SRC.TRIM_SMPLD_RSN_TX;

INSERT INTO feladm.FEL_SAMPLED_DIM (
    SAMPLED_KEY,
    SMPLD_RSN_TX,
    SAMPLED_TX,
    LAST_UPDT_TS
)
SELECT
    NVL((SELECT MAX(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM), 0)
        + ROW_NUMBER() OVER (ORDER BY SRC.SMPLD_RSN_TX)                           AS SAMPLED_KEY,
    SRC.SMPLD_RSN_TX,
    SRC.SAMPLED_TX,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        DQ.UNSMPLE_RSN_CDE                                                        AS SMPLD_RSN_TX,
        IFF(DQ.UNSMPLE_RSN_CDE = 'Sampled', 'Sampled', 'Unsampled')               AS SAMPLED_TX,
        UPPER(DQ.UNSMPLE_RSN_CDE)                                                 AS TRIM_SMPLD_RSN_TX,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS
    FROM (
        SELECT
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.COLVALUETEXT))) = 0 THEN ' ' ELSE RTRIM(SQ.COLVALUETEXT) END AS UNSMPLE_RSN_CDE
        FROM (
            SELECT t.COLVALUETEXT
            FROM COMTRACAPP.PERMVALUE t
            WHERE t.tablename = 'sampleproblem'
              AND t.colname   = 'missedsamplereason'
            UNION
            SELECT 'Sampled'
        ) SQ
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_SAMPLED_DIM S
    WHERE UPPER(TRIM(S.SMPLD_RSN_TX)) = SRC.TRIM_SMPLD_RSN_TX
);
