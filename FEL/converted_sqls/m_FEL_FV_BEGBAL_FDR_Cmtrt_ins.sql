/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_FV_BEGBAL_FDR
 MAPPING   : m_FEL_FV_BEGBAL_FDR_Cmtrt_ins
 OPERATION : TRUNCATE + INSERT, full reload. No router, no update strategy.
             Session log: TRUNCATE TABLE FEL_FV_BEGBAL_FDR, then insert.
             The captured run loaded 16652 rows.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_FV_BEGBAL_VW   full read, no filter
 LOOKUP    : FELADM.AEP_DATE   UNCONNECTED, called as
             :LKP.LKP_AEP_DATE(trunc(PERENDDATE,'DD')) returning DATE_ID.
             Mapping connection is DMDB01X, the session overrides it to $Target.
             No lookup SQL override.
 TARGET    : FEL_FV_BEGBAL_FDR   single instance, written unqualified because no
             Table Name Prefix is set on this session
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS are declared on the mapping but
             NOT REFERENCED, the SQ query override below carries no WHERE clause.
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : PRESENT on SQ_AEP_DW_FV_BEGBAL_VW, reproduced verbatim below:
                 SELECT VW.PERENDDATE, VW.INV_LOC_ID, VW.ACCT_INV_LOC_NM,
                        VW.JO_BUSENT_ID, VW.QUANTITY, VW.AMOUNT
                 FROM AEP_DW_FV_BEGBAL_VW VW
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : YES
--------------------------------------------------------------------------------
 NOTES     : ACCTG_MO_DAY_ID resolves through AEP_DATE, with -1 when the date is
             present but not found and -2 when the date is null.
             INV_LOC_ID and JO_BUSENT_ID are narrowed from 38 to 8 digits by their
             source qualifier ports.
             The writer also carries Delete = YES, but with no update strategy
             every row is flagged for insert, so no delete is ever issued.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

TRUNCATE TABLE FEL_FV_BEGBAL_FDR;

INSERT INTO FEL_FV_BEGBAL_FDR (
    ACCTG_MO_DAY_ID,
    INVTRY_LOC_ID,
    ACCTG_INVTRY_LOC_NM,
    JNT_OWNR_BSNS_ENTY_ID,
    INVENTORY_QY,
    INVENTORY_AT,
    LAST_UPDT_TS
)
SELECT
    CAST(IFF(LKP.DATE_ID IS NOT NULL, LKP.DATE_ID,
             IFF(SQ.PERENDDATE IS NULL, -2, -1)) AS NUMBER(5,0))     AS ACCTG_MO_DAY_ID,
    CAST(SQ.INV_LOC_ID AS NUMBER(10,0))                              AS INVTRY_LOC_ID,
    SQ.ACCT_INV_LOC_NM                                               AS ACCTG_INVTRY_LOC_NM,
    CAST(SQ.JO_BUSENT_ID AS NUMBER(10,0))                            AS JNT_OWNR_BSNS_ENTY_ID,
    CAST(SQ.QUANTITY AS NUMBER(18,9))                                AS INVENTORY_QY,
    CAST(SQ.AMOUNT AS NUMBER(18,9))                                  AS INVENTORY_AT,
    $V_SESSSTARTTIME                                                 AS LAST_UPDT_TS
FROM (
    SELECT
        VW.PERENDDATE,
        VW.INV_LOC_ID,
        VW.ACCT_INV_LOC_NM,
        VW.JO_BUSENT_ID,
        VW.QUANTITY,
        VW.AMOUNT
    FROM
        AEP_DW_FV_BEGBAL_VW VW
) SQ
LEFT JOIN (
    SELECT DATE_ID, FULL_DATE_DT
    FROM FELADM.AEP_DATE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
) LKP
  ON LKP.FULL_DATE_DT = TRUNC(SQ.PERENDDATE, 'DD');
