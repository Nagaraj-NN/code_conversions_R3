/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd
 MAPPING   : m_FEL_COAL_RCPTS_COST_FDR_Cmtrt_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_RECEIPT_COSTDTL_VW
 LOOKUP    : FELADM.FEL_COAL_RCPTS_COST_FDR
             existence, keys RECEIPT_ID + CST_CMPNT_CD
             lookup SQL override PRESENT:
               SELECT F.RECEIPT_ID, UPPER(TRIM(F.CST_CMPNT_CD)) as CST_CMPNT_CD
               FROM FELADM.FEL_COAL_RCPTS_COST_FDR F
 TARGET    : feladm.FEL_COAL_RCPTS_COST_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The cost component code is uppercased for the lookup only. The value
             written, and the value used in the update predicate, keeps its
             original case. Both are reproduced rather than harmonised.
             A null cost amount defaults to 0 and is written to decimal(12,3),
             so the amount is rounded to three decimals.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COAL_RCPTS_COST_FDR TGT
SET
    STATUS_TX    = SRC.STATUS_TX,
    RCPT_CST_AT  = SRC.RCPT_CST_AT,
    LAST_UPDT_TS = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.RCPT_ID AS NUMBER(10,0))                                             AS RECEIPT_ID,
        DQ.RCPT_CST_TYPE                                                             AS CST_CMPNT_CD,
        UPPER(DQ.RCPT_CST_TYPE)                                                      AS TRIM_COST_COMPONENT_CD,
        DQ.STATUS                                                                    AS STATUS_TX,
        CAST(IFF(DQ.CST_AMT IS NOT NULL, DQ.CST_AMT, 0) AS NUMBER(12,3))             AS RCPT_CST_AT,
        $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS,
        LKP.RECEIPT_ID                                                               AS LKP_RECEIPT_ID
    FROM (
        SELECT
            SQ.RCPT_ID,
            SQ.CST_AMT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_TYPE))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_TYPE) END AS RCPT_CST_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))        = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)        END AS STATUS
        FROM AEP_DW_RECEIPT_COSTDTL_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
    JOIN (
        SELECT
            F.RECEIPT_ID                    AS RECEIPT_ID,
            UPPER(TRIM(F.CST_CMPNT_CD))     AS CST_CMPNT_CD
        FROM FELADM.FEL_COAL_RCPTS_COST_FDR F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY F.RECEIPT_ID, UPPER(TRIM(F.CST_CMPNT_CD))
                                   ORDER BY F.RECEIPT_ID, UPPER(TRIM(F.CST_CMPNT_CD))) = 1
    ) LKP
      ON LKP.RECEIPT_ID   = CAST(DQ.RCPT_ID AS NUMBER(10,0))
     AND LKP.CST_CMPNT_CD = UPPER(DQ.RCPT_CST_TYPE)
) SRC
WHERE TGT.RECEIPT_ID   = SRC.LKP_RECEIPT_ID
  AND TGT.CST_CMPNT_CD = SRC.CST_CMPNT_CD;

INSERT INTO feladm.FEL_COAL_RCPTS_COST_FDR (
    RECEIPT_ID,
    CST_CMPNT_CD,
    STATUS_TX,
    RCPT_CST_AT,
    LAST_UPDT_TS
)
SELECT
    SRC.RECEIPT_ID,
    SRC.CST_CMPNT_CD,
    SRC.STATUS_TX,
    SRC.RCPT_CST_AT,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.RCPT_ID AS NUMBER(10,0))                                             AS RECEIPT_ID,
        DQ.RCPT_CST_TYPE                                                             AS CST_CMPNT_CD,
        UPPER(DQ.RCPT_CST_TYPE)                                                      AS TRIM_COST_COMPONENT_CD,
        DQ.STATUS                                                                    AS STATUS_TX,
        CAST(IFF(DQ.CST_AMT IS NOT NULL, DQ.CST_AMT, 0) AS NUMBER(12,3))             AS RCPT_CST_AT,
        $V_SESSSTARTTIME                                                             AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.RCPT_ID,
            SQ.CST_AMT,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.RCPT_CST_TYPE))) = 0 THEN ' ' ELSE RTRIM(SQ.RCPT_CST_TYPE) END AS RCPT_CST_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.STATUS)))        = 0 THEN ' ' ELSE RTRIM(SQ.STATUS)        END AS STATUS
        FROM AEP_DW_RECEIPT_COSTDTL_VW SQ
        WHERE SQ.MODDATETIME >  $V_START_TIME
          AND SQ.MODDATETIME <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM FELADM.FEL_COAL_RCPTS_COST_FDR F
    WHERE F.RECEIPT_ID                = SRC.RECEIPT_ID
      AND UPPER(TRIM(F.CST_CMPNT_CD)) = SRC.TRIM_COST_COMPONENT_CD
);
