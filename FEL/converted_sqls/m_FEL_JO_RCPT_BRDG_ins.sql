/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_FACT_LOAD
 SESSION   : s_m_FEL_JO_RCPT_BRDG_ins
 MAPPING   : m_FEL_JO_RCPT_BRDG_ins
 OPERATION : TRUNCATE + INSERT, full reload. Treat source rows as Insert, no
             router and no update strategy.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_FV_JO_RECEIPT_VW   full read, no filter
 LOOKUPS   : feladm.FEL_SYSTEM_DIM              UNCONNECTED, SYS_NM = 'COMTRAC'
             feladm.FEL_ACCTG_MONTH_VW          UNCONNECTED, MONTH_NB + CALENDAR_YEAR
             FELADM.FEL_BSNS_ENTY_DIM           UNCONNECTED, BSNS_ENTY_ID + SYSTEM_ID
             feladm.FEL_INVTRY_LOC_DIM          UNCONNECTED, INVTRY_LOC_ID + SYSTEM_ID
             lookup SQL override PRESENT on FEL_INVTRY_LOC_DIM, column list only:
               SELECT iloc.INVTRY_LOC_KEY, iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID
               FROM feladm.FEL_INVTRY_LOC_DIM iloc
             All four are Lookup policy on multiple match = Use Any Value.
 TARGET    : feladm.FEL_JO_RCPT_BRDG
--------------------------------------------------------------------------------
 PARAMETERS: none declared on the mapping
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole view
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
--------------------------------------------------------------------------------
 NOTES     : Every key defaults to -2 when its lookup misses, never -1.
             TRAN_CLASS_LVL2 is cut to 17 by the EXPTRANS1 input port, well
             inside the 25 character target column.
             The captured run loaded 4424 rows.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE feladm.FEL_JO_RCPT_BRDG;

INSERT INTO feladm.FEL_JO_RCPT_BRDG (
    ACCTG_MO_DAY_ID,
    TRAN_CLS_LVL_2_NM,
    PERCENT_QY,
    PERCENT_AT,
    BSNS_ENTY_KEY,
    INVTRY_LOC_KEY,
    LAST_UPDT_TS
)
SELECT
    CAST(IFF(LKP_MO.ACCTG_MO_DAY_ID IS NOT NULL, LKP_MO.ACCTG_MO_DAY_ID, -2) AS NUMBER(5,0))   AS ACCTG_MO_DAY_ID,
    IFF(SQ.TRAN_CLASS_LVL2 IS NOT NULL, LEFT(SQ.TRAN_CLASS_LVL2, 17), 'NA')                    AS TRAN_CLS_LVL_2_NM,
    CAST(SQ.PERCENT_QTY_NBR AS NUMBER(10,9))                                                   AS PERCENT_QY,
    CAST(SQ.PERCENT_AMT_NBR AS NUMBER(10,9))                                                   AS PERCENT_AT,
    CAST(IFF(LKP_BE.BSNS_ENTY_KEY IS NOT NULL, LKP_BE.BSNS_ENTY_KEY, -2) AS NUMBER(10,0))      AS BSNS_ENTY_KEY,
    CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NOT NULL, LKP_IL.INVTRY_LOC_KEY, -2) AS NUMBER(10,0))    AS INVTRY_LOC_KEY,
    $V_SESSSTARTTIME                                                                           AS LAST_UPDT_TS
FROM AEP_DW_FV_JO_RECEIPT_VW SQ
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
  ON LKP_BE.BSNS_ENTY_ID = CAST(SQ.FK_BUSENTIDNBR AS NUMBER(10,0))
 AND LKP_BE.SYSTEM_ID    = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC')
LEFT JOIN (
    SELECT iloc.INVTRY_LOC_KEY, iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID
    FROM feladm.FEL_INVTRY_LOC_DIM iloc
    QUALIFY ROW_NUMBER() OVER (PARTITION BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID ORDER BY iloc.INVTRY_LOC_ID, iloc.SYSTEM_ID) = 1
) LKP_IL
  ON LKP_IL.INVTRY_LOC_ID = CAST(SQ.INV_LOC_ID AS NUMBER(10,0))
 AND LKP_IL.SYSTEM_ID     = (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = 'COMTRAC');
