/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd
 MAPPING   : m_FEL_INVTRY_LOC_FDR_Cmtrt_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_INVENTORYLOC_VW
 LOOKUP    : feladm.FEL_INVTRY_LOC_FDR   existence, key INVTRY_LOC_ID
             no lookup SQL override
 TARGET    : feladm.FEL_INVTRY_LOC_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : INVTRY_CMDTY_TYPE_NM is cut to 30 from a 100 character port.
             Text columns default to ' '. The two facility ids have no null
             default, so a null would be rejected by the not null target columns.
             MOD_BY_ID and MOD_BY_DT are read but reach no target column.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_INVTRY_LOC_FDR TGT
SET
    INVTRY_LOC_NM          = SRC.INVTRY_LOC_NM,
    INVTRY_CMDTY_TYPE_NM   = SRC.INVTRY_CMDTY_TYPE_NM,
    INVTRY_CMDTY_NM        = SRC.INVTRY_CMDTY_NM,
    INVTRY_LOC_TYPE_NM     = SRC.INVTRY_LOC_TYPE_NM,
    INVTRY_LOC_STAT_TX     = SRC.INVTRY_LOC_STAT_TX,
    INVTRY_LOC_DSPLY_NM    = SRC.INVTRY_LOC_DSPLY_NM,
    INVTRY_PRMRY_FCLTY_ID  = SRC.INVTRY_PRMRY_FCLTY_ID,
    INVTRY_SCNDRY_FCLTY_ID = SRC.INVTRY_SCNDRY_FCLTY_ID,
    LAST_UPDT_TS           = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.INV_LOC_ID AS NUMBER(10,0))                                              AS INVTRY_LOC_ID,
        IFF(DQ.INV_LOC_NM IS NOT NULL, DQ.INV_LOC_NM, ' ')                               AS INVTRY_LOC_NM,
        LEFT(IFF(DQ.CMDTY_TYPE IS NOT NULL, DQ.CMDTY_TYPE, ' '), 30)                     AS INVTRY_CMDTY_TYPE_NM,
        IFF(DQ.CMDTY_NM IS NOT NULL, DQ.CMDTY_NM, ' ')                                   AS INVTRY_CMDTY_NM,
        IFF(DQ.INV_LOC_TYPE IS NOT NULL, DQ.INV_LOC_TYPE, ' ')                           AS INVTRY_LOC_TYPE_NM,
        IFF(DQ.INV_STATUS IS NOT NULL, DQ.INV_STATUS, ' ')                               AS INVTRY_LOC_STAT_TX,
        IFF(DQ.INV_LOC_DISP_NM IS NOT NULL, DQ.INV_LOC_DISP_NM, ' ')                     AS INVTRY_LOC_DSPLY_NM,
        CAST(DQ.FK_PRIM_FCLTY_ID AS NUMBER(10,0))                                        AS INVTRY_PRMRY_FCLTY_ID,
        CAST(DQ.FK_SEC_FCLTY_ID AS NUMBER(10,0))                                         AS INVTRY_SCNDRY_FCLTY_ID,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.INV_LOC_ID,
            SQ.FK_PRIM_FCLTY_ID,
            SQ.FK_SEC_FCLTY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_STATUS)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_STATUS)      END AS INV_STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_NM)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_NM)      END AS INV_LOC_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_DISP_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_DISP_NM) END AS INV_LOC_DISP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_TYPE)))      = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_TYPE)      END AS CMDTY_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_NM)))        = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_NM)        END AS CMDTY_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_TYPE)))    = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_TYPE)    END AS INV_LOC_TYPE
        FROM AEP_DW_INVENTORYLOC_VW SQ
        WHERE SQ.MOD_BY_DT >  $V_START_TIME
          AND SQ.MOD_BY_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE TGT.INVTRY_LOC_ID = SRC.INVTRY_LOC_ID;

INSERT INTO feladm.FEL_INVTRY_LOC_FDR (
    INVTRY_LOC_ID,
    INVTRY_LOC_NM,
    INVTRY_CMDTY_TYPE_NM,
    INVTRY_CMDTY_NM,
    INVTRY_LOC_TYPE_NM,
    INVTRY_LOC_STAT_TX,
    INVTRY_LOC_DSPLY_NM,
    INVTRY_PRMRY_FCLTY_ID,
    INVTRY_SCNDRY_FCLTY_ID,
    LAST_UPDT_TS
)
SELECT
    SRC.INVTRY_LOC_ID,
    SRC.INVTRY_LOC_NM,
    SRC.INVTRY_CMDTY_TYPE_NM,
    SRC.INVTRY_CMDTY_NM,
    SRC.INVTRY_LOC_TYPE_NM,
    SRC.INVTRY_LOC_STAT_TX,
    SRC.INVTRY_LOC_DSPLY_NM,
    SRC.INVTRY_PRMRY_FCLTY_ID,
    SRC.INVTRY_SCNDRY_FCLTY_ID,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.INV_LOC_ID AS NUMBER(10,0))                                              AS INVTRY_LOC_ID,
        IFF(DQ.INV_LOC_NM IS NOT NULL, DQ.INV_LOC_NM, ' ')                               AS INVTRY_LOC_NM,
        LEFT(IFF(DQ.CMDTY_TYPE IS NOT NULL, DQ.CMDTY_TYPE, ' '), 30)                     AS INVTRY_CMDTY_TYPE_NM,
        IFF(DQ.CMDTY_NM IS NOT NULL, DQ.CMDTY_NM, ' ')                                   AS INVTRY_CMDTY_NM,
        IFF(DQ.INV_LOC_TYPE IS NOT NULL, DQ.INV_LOC_TYPE, ' ')                           AS INVTRY_LOC_TYPE_NM,
        IFF(DQ.INV_STATUS IS NOT NULL, DQ.INV_STATUS, ' ')                               AS INVTRY_LOC_STAT_TX,
        IFF(DQ.INV_LOC_DISP_NM IS NOT NULL, DQ.INV_LOC_DISP_NM, ' ')                     AS INVTRY_LOC_DSPLY_NM,
        CAST(DQ.FK_PRIM_FCLTY_ID AS NUMBER(10,0))                                        AS INVTRY_PRMRY_FCLTY_ID,
        CAST(DQ.FK_SEC_FCLTY_ID AS NUMBER(10,0))                                         AS INVTRY_SCNDRY_FCLTY_ID,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.INV_LOC_ID,
            SQ.FK_PRIM_FCLTY_ID,
            SQ.FK_SEC_FCLTY_ID,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_STATUS)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_STATUS)      END AS INV_STATUS,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_NM)))      = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_NM)      END AS INV_LOC_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_DISP_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_DISP_NM) END AS INV_LOC_DISP_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_TYPE)))      = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_TYPE)      END AS CMDTY_TYPE,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.CMDTY_NM)))        = 0 THEN ' ' ELSE RTRIM(SQ.CMDTY_NM)        END AS CMDTY_NM,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.INV_LOC_TYPE)))    = 0 THEN ' ' ELSE RTRIM(SQ.INV_LOC_TYPE)    END AS INV_LOC_TYPE
        FROM AEP_DW_INVENTORYLOC_VW SQ
        WHERE SQ.MOD_BY_DT >  $V_START_TIME
          AND SQ.MOD_BY_DT <= $V_END_TIME
          AND $V_RUN_STATUS = 'C'
    ) DQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_INVTRY_LOC_FDR LKP
    WHERE LKP.INVTRY_LOC_ID = SRC.INVTRY_LOC_ID
);
