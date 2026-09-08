/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_ACCT_TYP_DIM_ins_upd
 MAPPING   : m_FEL_ACCT_TYP_DIM_ins
 OPERATION : INSERT only. RTR_INS_UPT has a NEW group on the dimension lookup and
             an unconnected DEFAULT1 group; only UPD_INSERT is wired, so despite
             the session name no update is ever issued.
--------------------------------------------------------------------------------
 SOURCE    : GENDB01.FELADM.FEL_FV_TRANS_FDR  (USED FOR TETSING)
 LOOKUPS   : GENDB01.FELADM.FEL_ACCT_TYP_DIM  (USED FOR TETSING)
 TARGET    : GENDB01.FELADM.FEL_ACCT_TYP_DIM  (USED FOR TETSING)
--------------------------------------------------------------------------------
 PARAMETERS: 
 [FEL.WF:wkf_FEL_COAL_DIM_LOAD]
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

INSERT INTO GENDB01.FELADM.FEL_ACCT_TYP_DIM (
    ACCT_TYP_KEY,
    ACCT_TYP_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.O_ACCT_TYPE_KEY,
    SRC.ACCTG_TYP_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.ACCT_TYP_NM                                                            AS ACCTG_TYP_NM,
        UPPER(LTRIM(RTRIM(SQ.ACCT_TYP_NM)))                                       AS O_TRIM_ACCT_TYPE_NM,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS,
        NVL((SELECT MAX(ACCT_TYP_KEY) FROM GENDB01.FELADM.FEL_ACCT_TYP_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCT_TYP_NM)                         AS O_ACCT_TYPE_KEY
    FROM (
        SELECT DISTINCT FEL_FV_TRANS_FDR.ACCT_TYP_NM
        FROM GENDB01.FELADM.FEL_FV_TRANS_FDR
    ) SQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01.FELADM.FEL_ACCT_TYP_DIM DIM
    WHERE UPPER(TRIM(DIM.ACCT_TYP_NM)) = SRC.O_TRIM_ACCT_TYPE_NM
);