/*
================================================================================
 WORKFLOW  : wkf_FEL_STATIC_DIM_LOAD
 SESSION   : s_m_FEL_PWRMGR_LOAD_TYPE_FDR_ins
 MAPPING   : m_FEL_PWRMGR_LOAD_TYPE_FDR_ins
 OPERATION : UPDATE ELSE INSERT on LOAD_TYPE_ID. Treat source rows as Update with
             the writer set to Update else Insert, so a row is updated when the id
             exists and inserted when it does not.
--------------------------------------------------------------------------------
 SOURCE    : pmgr.ENUMTABLE, the single ENUM row for ENUMID = 82. That one string
             holds up to ten "id - name" pairs separated by commas.
 LOOKUPS   : none
 TARGET    : feladm.FEL_PWRMGR_LOAD_TYPE_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME is declared on the mapping but NOT REFERENCED
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only:  ENUMID = 82
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : EXPTRANS_SUBSTR cuts the ENUM string into ten id and name pairs using
             comma and dash positions, NRMTRANS pivots those ten occurrences into
             ten rows, and FILTRANS drops the ones whose id is null. The occurrence
             list below reproduces that pivot; each branch keeps its own authored
             expression rather than a common formula.
             Kept as authored: the fourth name falls back to the SEVENTH dash, not
             the fourth, when its comma is missing; and the guards on the eighth
             and ninth ids test "position < 0", which INSTR never returns since it
             reports 0 for not found, so those branches never fire.
             An id that is empty becomes null and is filtered out, which is why one
             source row produced 7 target rows in the captured run.
             EXPTRANS1 builds the literal '1 - test' but nothing reads it.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_PWRMGR_LOAD_TYPE_FDR TGT
SET
    LOAD_TYPE_NM = SRC.LOAD_TYPE_NAME,
    LAST_UPDT_TS = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(IFF(N.LOAD_TYPE_ID = '', NULL, TO_NUMBER(TRIM(N.LOAD_TYPE_ID))) AS NUMBER(5,0)) AS LOAD_TYPE_ID,
        LEFT(N.LOAD_TYPE_NAME, 50)                                                           AS LOAD_TYPE_NAME,
        $V_SESSSTARTTIME                                                                     AS LAST_UPDT_TS
    FROM (
        SELECT
            LEFT(CASE OCC.N
                 WHEN  1 THEN SUBSTR(P.ENUM, 1,       GREATEST(P.D1 - 1, 0))
                 WHEN  2 THEN SUBSTR(P.ENUM, P.C1 + 1, GREATEST(P.D2 - 1 - P.C1, 0))
                 WHEN  3 THEN SUBSTR(P.ENUM, P.C2 + 1, GREATEST(P.D3 - 1 - P.C2, 0))
                 WHEN  4 THEN SUBSTR(P.ENUM, P.C3 + 1, GREATEST(P.D4 - 1 - P.C3, 0))
                 WHEN  5 THEN SUBSTR(P.ENUM, P.C4 + 1, GREATEST(P.D5 - 1 - P.C4, 0))
                 WHEN  6 THEN SUBSTR(P.ENUM, P.C5 + 1, GREATEST(P.D6 - 1 - P.C5, 0))
                 WHEN  7 THEN SUBSTR(P.ENUM, P.C6 + 1, GREATEST(P.D7 - 1 - P.C6, 0))
                 WHEN  8 THEN IFF(P.C7 < 0, NULL, SUBSTR(P.ENUM, P.C7 + 1, GREATEST(P.D8 - 1 - P.C7, 0)))
                 WHEN  9 THEN IFF(P.C8 < 0, NULL, SUBSTR(P.ENUM, P.C8 + 1, GREATEST(P.D9 - 1 - P.C8, 0)))
                 WHEN 10 THEN SUBSTR(P.ENUM, P.C9 + 1, GREATEST(P.D10 - 1 - P.C9, 0))
                 END, 5)                                                                     AS LOAD_TYPE_ID,
            LEFT(CASE OCC.N
                 WHEN  1 THEN IFF(P.C1 > 0, SUBSTR(P.ENUM, P.D1 + 1, GREATEST(P.C1 - 1 - P.D1, 0)), SUBSTR(P.ENUM, P.D1 + 1))
                 WHEN  2 THEN IFF(P.C2 > 0, SUBSTR(P.ENUM, P.D2 + 1, GREATEST(P.C2 - 1 - P.D2, 0)), SUBSTR(P.ENUM, P.D2 + 1))
                 WHEN  3 THEN IFF(P.C3 > 0, SUBSTR(P.ENUM, P.D3 + 1, GREATEST(P.C3 - 1 - P.D3, 0)), SUBSTR(P.ENUM, P.D3 + 1))
                 WHEN  4 THEN IFF(P.C4 > 0, SUBSTR(P.ENUM, P.D4 + 1, GREATEST(P.C4 - 1 - P.D4, 0)), SUBSTR(P.ENUM, P.D7 + 1))
                 WHEN  5 THEN IFF(P.C5 > 0, SUBSTR(P.ENUM, P.D5 + 1, GREATEST(P.C5 - 1 - P.D5, 0)), SUBSTR(P.ENUM, P.D5 + 1))
                 WHEN  6 THEN IFF(P.C6 > 0, SUBSTR(P.ENUM, P.D6 + 1, GREATEST(P.C6 - 1 - P.D6, 0)), SUBSTR(P.ENUM, P.D6 + 1))
                 WHEN  7 THEN IFF(P.C7 > 0, SUBSTR(P.ENUM, P.D7 + 1, GREATEST(P.C7 - 1 - P.D7, 0)), SUBSTR(P.ENUM, P.D7 + 1))
                 WHEN  8 THEN IFF(P.C8 > 0, SUBSTR(P.ENUM, P.D8 + 1, GREATEST(P.C8 - 1 - P.D8, 0)), SUBSTR(P.ENUM, P.D8 + 1))
                 WHEN  9 THEN IFF(P.C9 > 0, SUBSTR(P.ENUM, P.D9 + 1, GREATEST(P.C9 - 1 - P.D9, 0)), SUBSTR(P.ENUM, P.D9 + 1))
                 WHEN 10 THEN IFF(P.D10 = 0, NULL, SUBSTR(P.ENUM, P.D10 + 1))
                 END, 50)                                                                    AS LOAD_TYPE_NAME
        FROM (
            SELECT
                DQ.ENUM,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 1) AS C1, REGEXP_INSTR(DQ.ENUM, '-', 1,  1) AS D1,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 2) AS C2, REGEXP_INSTR(DQ.ENUM, '-', 1,  2) AS D2,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 3) AS C3, REGEXP_INSTR(DQ.ENUM, '-', 1,  3) AS D3,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 4) AS C4, REGEXP_INSTR(DQ.ENUM, '-', 1,  4) AS D4,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 5) AS C5, REGEXP_INSTR(DQ.ENUM, '-', 1,  5) AS D5,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 6) AS C6, REGEXP_INSTR(DQ.ENUM, '-', 1,  6) AS D6,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 7) AS C7, REGEXP_INSTR(DQ.ENUM, '-', 1,  7) AS D7,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 8) AS C8, REGEXP_INSTR(DQ.ENUM, '-', 1,  8) AS D8,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 9) AS C9, REGEXP_INSTR(DQ.ENUM, '-', 1,  9) AS D9,
                                                        REGEXP_INSTR(DQ.ENUM, '-', 1, 10) AS D10
            FROM (
                SELECT
                    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ENUM))) = 0 THEN ' ' ELSE RTRIM(SQ.ENUM) END AS ENUM
                FROM pmgr.ENUMTABLE SQ
                WHERE SQ.ENUMID = 82
            ) DQ
        ) P
        CROSS JOIN (
            SELECT 1 AS N UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        ) OCC
    ) N
    WHERE IFF(N.LOAD_TYPE_ID = '', NULL, TO_NUMBER(TRIM(N.LOAD_TYPE_ID))) IS NOT NULL
) SRC
WHERE TGT.LOAD_TYPE_ID = SRC.LOAD_TYPE_ID;

INSERT INTO feladm.FEL_PWRMGR_LOAD_TYPE_FDR (
    LOAD_TYPE_ID,
    LOAD_TYPE_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.LOAD_TYPE_ID,
    SRC.LOAD_TYPE_NAME,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(IFF(N.LOAD_TYPE_ID = '', NULL, TO_NUMBER(TRIM(N.LOAD_TYPE_ID))) AS NUMBER(5,0)) AS LOAD_TYPE_ID,
        LEFT(N.LOAD_TYPE_NAME, 50)                                                           AS LOAD_TYPE_NAME,
        $V_SESSSTARTTIME                                                                     AS LAST_UPDT_TS
    FROM (
        SELECT
            LEFT(CASE OCC.N
                 WHEN  1 THEN SUBSTR(P.ENUM, 1,       GREATEST(P.D1 - 1, 0))
                 WHEN  2 THEN SUBSTR(P.ENUM, P.C1 + 1, GREATEST(P.D2 - 1 - P.C1, 0))
                 WHEN  3 THEN SUBSTR(P.ENUM, P.C2 + 1, GREATEST(P.D3 - 1 - P.C2, 0))
                 WHEN  4 THEN SUBSTR(P.ENUM, P.C3 + 1, GREATEST(P.D4 - 1 - P.C3, 0))
                 WHEN  5 THEN SUBSTR(P.ENUM, P.C4 + 1, GREATEST(P.D5 - 1 - P.C4, 0))
                 WHEN  6 THEN SUBSTR(P.ENUM, P.C5 + 1, GREATEST(P.D6 - 1 - P.C5, 0))
                 WHEN  7 THEN SUBSTR(P.ENUM, P.C6 + 1, GREATEST(P.D7 - 1 - P.C6, 0))
                 WHEN  8 THEN IFF(P.C7 < 0, NULL, SUBSTR(P.ENUM, P.C7 + 1, GREATEST(P.D8 - 1 - P.C7, 0)))
                 WHEN  9 THEN IFF(P.C8 < 0, NULL, SUBSTR(P.ENUM, P.C8 + 1, GREATEST(P.D9 - 1 - P.C8, 0)))
                 WHEN 10 THEN SUBSTR(P.ENUM, P.C9 + 1, GREATEST(P.D10 - 1 - P.C9, 0))
                 END, 5)                                                                     AS LOAD_TYPE_ID,
            LEFT(CASE OCC.N
                 WHEN  1 THEN IFF(P.C1 > 0, SUBSTR(P.ENUM, P.D1 + 1, GREATEST(P.C1 - 1 - P.D1, 0)), SUBSTR(P.ENUM, P.D1 + 1))
                 WHEN  2 THEN IFF(P.C2 > 0, SUBSTR(P.ENUM, P.D2 + 1, GREATEST(P.C2 - 1 - P.D2, 0)), SUBSTR(P.ENUM, P.D2 + 1))
                 WHEN  3 THEN IFF(P.C3 > 0, SUBSTR(P.ENUM, P.D3 + 1, GREATEST(P.C3 - 1 - P.D3, 0)), SUBSTR(P.ENUM, P.D3 + 1))
                 WHEN  4 THEN IFF(P.C4 > 0, SUBSTR(P.ENUM, P.D4 + 1, GREATEST(P.C4 - 1 - P.D4, 0)), SUBSTR(P.ENUM, P.D7 + 1))
                 WHEN  5 THEN IFF(P.C5 > 0, SUBSTR(P.ENUM, P.D5 + 1, GREATEST(P.C5 - 1 - P.D5, 0)), SUBSTR(P.ENUM, P.D5 + 1))
                 WHEN  6 THEN IFF(P.C6 > 0, SUBSTR(P.ENUM, P.D6 + 1, GREATEST(P.C6 - 1 - P.D6, 0)), SUBSTR(P.ENUM, P.D6 + 1))
                 WHEN  7 THEN IFF(P.C7 > 0, SUBSTR(P.ENUM, P.D7 + 1, GREATEST(P.C7 - 1 - P.D7, 0)), SUBSTR(P.ENUM, P.D7 + 1))
                 WHEN  8 THEN IFF(P.C8 > 0, SUBSTR(P.ENUM, P.D8 + 1, GREATEST(P.C8 - 1 - P.D8, 0)), SUBSTR(P.ENUM, P.D8 + 1))
                 WHEN  9 THEN IFF(P.C9 > 0, SUBSTR(P.ENUM, P.D9 + 1, GREATEST(P.C9 - 1 - P.D9, 0)), SUBSTR(P.ENUM, P.D9 + 1))
                 WHEN 10 THEN IFF(P.D10 = 0, NULL, SUBSTR(P.ENUM, P.D10 + 1))
                 END, 50)                                                                    AS LOAD_TYPE_NAME
        FROM (
            SELECT
                DQ.ENUM,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 1) AS C1, REGEXP_INSTR(DQ.ENUM, '-', 1,  1) AS D1,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 2) AS C2, REGEXP_INSTR(DQ.ENUM, '-', 1,  2) AS D2,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 3) AS C3, REGEXP_INSTR(DQ.ENUM, '-', 1,  3) AS D3,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 4) AS C4, REGEXP_INSTR(DQ.ENUM, '-', 1,  4) AS D4,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 5) AS C5, REGEXP_INSTR(DQ.ENUM, '-', 1,  5) AS D5,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 6) AS C6, REGEXP_INSTR(DQ.ENUM, '-', 1,  6) AS D6,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 7) AS C7, REGEXP_INSTR(DQ.ENUM, '-', 1,  7) AS D7,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 8) AS C8, REGEXP_INSTR(DQ.ENUM, '-', 1,  8) AS D8,
                REGEXP_INSTR(DQ.ENUM, ',', 1, 9) AS C9, REGEXP_INSTR(DQ.ENUM, '-', 1,  9) AS D9,
                                                        REGEXP_INSTR(DQ.ENUM, '-', 1, 10) AS D10
            FROM (
                SELECT
                    CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ENUM))) = 0 THEN ' ' ELSE RTRIM(SQ.ENUM) END AS ENUM
                FROM pmgr.ENUMTABLE SQ
                WHERE SQ.ENUMID = 82
            ) DQ
        ) P
        CROSS JOIN (
            SELECT 1 AS N UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        ) OCC
    ) N
    WHERE IFF(N.LOAD_TYPE_ID = '', NULL, TO_NUMBER(TRIM(N.LOAD_TYPE_ID))) IS NOT NULL
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_PWRMGR_LOAD_TYPE_FDR L
    WHERE L.LOAD_TYPE_ID = SRC.LOAD_TYPE_ID
);
