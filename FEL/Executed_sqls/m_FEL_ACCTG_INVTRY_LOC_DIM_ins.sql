/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_ACCTG_INVTRY_LOC_DIM_ins_upd
 MAPPING   : m_FEL_ACCTG_INVTRY_LOC_DIM_ins
 OPERATION : INSERT only. FILTRANS keeps the rows whose dimension lookup missed and
             UPD_INSERT flags them DD_INSERT. There is no update path, so an
             existing accounting inventory location is left untouched.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_ACCT_INV_LOC_VW
             GENDB01_DEV_SANDBOX.COMMON.AEP_DW_ACCT_INV_LOC_VW_TEST  --USED FOR TESTING
 LOOKUPS   : GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM
 TARGET    : GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM
--------------------------------------------------------------------------------
 PARAMETERS: none declared on the mapping
             SESSSTARTTIME -> LAST_UPTD_TS
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole view
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
    $$START_TIME=2026-09-05 22:30:12
    $$REC_STATUS=ACTIVE
    $$RUN_STATUS=C
    $$COMTRAC=COMTRAC
    $$BUSINESSENTITY=BUSINESS ENTITY
    $$FACILITY=FACILITY
    $$INVTRYLOC=INVENTORY LOCATION
    $$GEN_UNIT=GENERATING UNIT
    $DBConnection_Target=fel_GENDB001
    $DBConnection_Source=fel_GENDB001

================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

INSERT INTO GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM (
    ACCTG_INVTRY_LOC_KEY,
    ACCTG_INVTRY_LOC_NM,
    INVTRY_CMDTY_TYPE_NM,
    INVTRY_CMDTY_NM,
    LAST_UPTD_TS
)
SELECT
    SRC.O_MAX_KEY,
    SRC.O_ACCTG_INV_LOC_NM_CAT,
    LEFT(SRC.CMDTY_TYPE, 30),
    SRC.CMDTY_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.CMDTY_NM,
        SQ.CMDTY_TYPE,
        NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')'          AS O_ACCTG_INV_LOC_NM_CAT,
        UPPER(NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')')   AS O_ACCTG_INV_LOC_NM,
        UPPER(LTRIM(RTRIM(SQ.CMDTY_NM)))                                                                         AS O_CMDTY_NM,
        UPPER(LTRIM(RTRIM(SQ.CMDTY_TYPE)))                                                                       AS O_CMDTY_TYPE,
        $V_SESSSTARTTIME                                                                                         AS LAST_UPDT_TS,
        NVL((SELECT MAX(ACCTG_INVTRY_LOC_KEY) FROM GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCTG_INV_LOC_NM, SQ.CMDTY_NM, SQ.CMDTY_TYPE)                       AS O_MAX_KEY
    FROM GENDB01_DEV_SANDBOX.COMMON.AEP_DW_ACCT_INV_LOC_VW_TEST SQ  --USED FOR TESTING
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_ACCTG_INVTRY_LOC_DIM ANV
    WHERE UPPER(TRIM(ANV.ACCTG_INVTRY_LOC_NM))  = SRC.O_ACCTG_INV_LOC_NM
      AND UPPER(TRIM(ANV.INVTRY_CMDTY_TYPE_NM)) = SRC.O_CMDTY_TYPE
      AND UPPER(TRIM(ANV.INVTRY_CMDTY_NM))      = SRC.O_CMDTY_NM
);
