/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_FACT_LOAD
 SESSION   : s_m_FEL_JO_DSPSTN_BRDG_ins
 MAPPING   : m_FEL_JO_DSPSTN_BRDG_ins
 OPERATION : TRUNCATE + INSERT, full reload. No router, no update strategy.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_FV_JO_DISPOSED_VW   full read, no filter
 LOOKUPS   : five, all UNCONNECTED and Use Any Value on multiple match
             FEL_SYSTEM_DIM 'COMTRAC', FEL_ACCTG_MONTH_VW month + year,
             FEL_BSNS_ENTY_DIM, FEL_GNRTN_UNIT_DIM and FEL_INVTRY_LOC_DIM, the
             last two by id + system id with SQL overrides that trim the id
 TARGET    : feladm.FEL_JO_DSPSTN_BRDG
--------------------------------------------------------------------------------
 PARAMETERS: none declared on the mapping
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole view
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
--------------------------------------------------------------------------------
 NOTES     : Every key defaults to -2 on a lookup miss, never -1.
             The unit lookup keys on TO_CHAR(UNIT_ID), matching a numeric source id
             against the trimmed text UNIT_ID of the dimension.
             TRAN_CLASS_LVL3 is cut to 17 by the EXPTRANS input port, inside the
             25 character target column.
             The writer also carries Update and Delete, but with no update strategy
             every row is flagged for insert, so neither is issued.
             The captured run loaded 21522 rows.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE feladm.FEL_JO_DSPSTN_BRDG;

INSERT INTO feladm.FEL_JO_DSPSTN_BRDG (
    ACCTG_MO_DAY_ID,
    TRAN_CLS_LVL_3_NM,
    PERCENT_QY,
    PERCENT_AT,
    BSNS_ENTY_KEY,
    UNIT_KEY,
    INVTRY_LOC_KEY,
    LAST_UPDT_TS
)
SELECT
    CAST(IFF(LKP_MO.ACCTG_MO_DAY_ID IS NOT NULL, LKP_MO.ACCTG_MO_DAY_ID, -2) AS NUMBER(5,0))   AS ACCTG_MO_DAY_ID,
    IFF(SQ.TRAN_CLASS_LVL3 IS NOT NULL, LEFT(SQ.TRAN_CLASS_LVL3, 17), 'NA')                    AS TRAN_CLS_LVL_3_NM,
    CAST(SQ.PERCENT_QTY_NBR AS NUMBER(10,9))                                                   AS PERCENT_QY,
    CAST(SQ.PERCENT_AMT_NBR AS NUMBER(10,9))                                                   AS PERCENT_AT,
    CAST(IFF(LKP_BE.BSNS_ENTY_KEY IS NOT NULL, LKP_BE.BSNS_ENTY_KEY, -2) AS NUMBER(10,0))      AS BSNS_ENTY_KEY,
    CAST(IFF(LKP_GU.UNIT_KEY IS NOT NULL, LKP_GU.UNIT_KEY, -2) AS NUMBER(10,0))                AS UNIT_KEY,
    CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NOT NULL, LKP_IL.INVTRY_LOC_KEY, -2) AS NUMBER(10,0))    AS INVTRY_LOC_KEY,
    $V_SESSSTARTTIME                                                                           AS LAST_UPDT_TS
FROM AEP_DW_FV_JO_DISPOSED_VW SQ
LEFT JOIN (
    SELECT ACCTG_MO_DAY_ID, MONTH_NB, CALENDAR_YEAR
    FROM feladm.FEL_ACCTG_MONTH_VW
    QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, CALENDAR_YEAR ORDER BY MONTH_NB, CALENDAR_YEAR) = 1
) LKP_MO
  ON LKP_MO.MONTH_NB      = CAST(DATE_PART(MONTH, SQ.ACCTG_MONTH) AS NUMBER(10,0))
 AND LKP_MO.CALENDAR_YEAR = CAST(DATE_PART(YEAR,  SQ.ACCTG_MONTH) AS NUMBER(10,0))
LEFT JOIN (
    SELECT BSNS_ENTY_KEY, BSNS_ENTY_ID, SYSTEM_ID
    FROM FELADM.FEL_BSNS_ENTY_DIM
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID, SYSTEM_ID ORDER BY BSNS_ENTY_ID, SYSTEM_ID) = 1
) LKP_BE
  ON LKP_BE.BSNS_ENTY_ID = CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))
 AND LKP_BE.SYSTEM_ID    = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
LEFT JOIN (
    SELECT F.UNIT_KEY, TRIM(F.UNIT_ID) AS UNIT_ID, F.SYSTEM_ID
    FROM feladm.FEL_GNRTN_UNIT_DIM F
    QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(F.UNIT_ID), F.SYSTEM_ID ORDER BY TRIM(F.UNIT_ID), F.SYSTEM_ID) = 1
) LKP_GU
  ON LKP_GU.UNIT_ID   = LEFT(TO_VARCHAR(CAST(SQ.UNIT_ID AS NUMBER(8,0))), 20)
 AND LKP_GU.SYSTEM_ID = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
LEFT JOIN (
    SELECT iloc.INVTRY_LOC_KEY, iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID
    FROM feladm.FEL_INVTRY_LOC_DIM iloc
    QUALIFY ROW_NUMBER() OVER (PARTITION BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID ORDER BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID) = 1
) LKP_IL
  ON LKP_IL.INVTRY_LOC_ID = CAST(SQ.INV_LOC_ID AS NUMBER(10,0))
 AND LKP_IL.SYSTEM_ID     = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC');
