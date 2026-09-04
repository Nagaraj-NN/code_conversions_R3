/*
================================================================================
 WORKFLOW  : wkf_FEL_CMTRT_FDR_LOAD
 SESSION   : s_m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd
 MAPPING   : m_FEL_COMTRAC_BSNS_ENTY_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_BUSINESSENTITY_VW
 LOOKUPS   : AEP_DW_BUSINESSENTITY_VW          parent short name, key FK_HLDNG_CO_ID
             feladm.FEL_COMTRAC_BSNS_ENTY_FDR  existence, key BSNS_ENTY_ID
             no lookup SQL overrides
 TARGET    : feladm.FEL_COMTRAC_BSNS_ENTY_FDR  insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$END_TIME, $$RUN_STATUS  (fel_parm.txt, SQ source filter)
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : none, source filter only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : BSNS_ENTY_NM is cut to 75 on insert and 80 on update, from the
             differing UPD_INSERT and UPD_UPDATE port widths.
             COMPANY_NM defaults to 'UNKNOWN' when the parent lookup misses.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_END_TIME      = TO_TIMESTAMP_NTZ('09/03/2026 22:30:12', 'MM/DD/YYYY HH24:MI:SS');
SET V_RUN_STATUS    = 'C';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COMTRAC_BSNS_ENTY_FDR TGT
SET
    STATUS_TX          = SRC.STATUS_TX,
    BSNS_ENTY_TYPE_NM  = SRC.BSNS_ENTY_TYPE_NM,
    BSNS_ENTY_NM       = SRC.BSNS_ENTY_NM,
    BSNS_ENTY_SHORT_NM = SRC.BSNS_ENTY_SHORT_NM,
    COMPANY_NM         = SRC.COMPANY_NAME,
    LAST_UPDT_TS       = SRC.LAST_UPDT_TS
FROM (
    SELECT
        LEFT(IFF(SQ.STAT_NM IS NULL, ' ', SQ.STAT_NM), 12)                                        AS STATUS_TX,
        LEFT(IFF(SQ.BSNS_ENTY_TYPE IS NULL, ' ', SQ.BSNS_ENTY_TYPE), 15)                          AS BSNS_ENTY_TYPE_NM,
        LEFT(IFF(SQ.BSNS_ENTY_NM IS NULL, ' ', SQ.BSNS_ENTY_NM), 80)                              AS BSNS_ENTY_NM,
        LEFT(IFF(SQ.BSNS_ENTY_SHRT_NM IS NULL, ' ', SQ.BSNS_ENTY_SHRT_NM), 30)                    AS BSNS_ENTY_SHORT_NM,
        LEFT(IFF(LKP.BSNS_ENTY_SHRT_NM IS NULL, 'UNKNOWN', UPPER(LKP.BSNS_ENTY_SHRT_NM)), 30)     AS COMPANY_NAME,
        $V_SESSSTARTTIME                                                                          AS LAST_UPDT_TS,
        CAST(LKP_FDR.BSNS_ENTY_ID AS NUMBER(10,0))                                                AS LKP_BSNS_ENTY_ID
    FROM AEP_DW_BUSINESSENTITY_VW SQ
    LEFT JOIN (
        SELECT
            BSNS_ENTY_SHRT_NM,
            BSNS_ENTY_ID
        FROM AEP_DW_BUSINESSENTITY_VW
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID ORDER BY BSNS_ENTY_ID) = 1
    ) LKP
      ON LKP.BSNS_ENTY_ID = SQ.FK_HLDNG_CO_ID
    JOIN (
        SELECT
            BSNS_ENTY_ID
        FROM feladm.FEL_COMTRAC_BSNS_ENTY_FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID ORDER BY BSNS_ENTY_ID) = 1
    ) LKP_FDR
      ON LKP_FDR.BSNS_ENTY_ID = CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))
    WHERE SQ.MOD_BY_DT >  $V_START_TIME
      AND SQ.MOD_BY_DT <= $V_END_TIME
      AND $V_RUN_STATUS = 'C'
) SRC
WHERE TGT.BSNS_ENTY_ID = SRC.LKP_BSNS_ENTY_ID;

INSERT INTO feladm.FEL_COMTRAC_BSNS_ENTY_FDR (
    BSNS_ENTY_ID,
    STATUS_TX,
    BSNS_ENTY_TYPE_NM,
    BSNS_ENTY_NM,
    BSNS_ENTY_SHORT_NM,
    COMPANY_NM,
    LAST_UPDT_TS
)
SELECT
    CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))                                                     AS BSNS_ENTY_ID,
    LEFT(IFF(SQ.STAT_NM IS NULL, ' ', SQ.STAT_NM), 12)                                        AS STATUS_TX,
    LEFT(IFF(SQ.BSNS_ENTY_TYPE IS NULL, ' ', SQ.BSNS_ENTY_TYPE), 15)                          AS BSNS_ENTY_TYPE_NM,
    LEFT(IFF(SQ.BSNS_ENTY_NM IS NULL, ' ', SQ.BSNS_ENTY_NM), 75)                              AS BSNS_ENTY_NM,
    LEFT(IFF(SQ.BSNS_ENTY_SHRT_NM IS NULL, ' ', SQ.BSNS_ENTY_SHRT_NM), 30)                    AS BSNS_ENTY_SHORT_NM,
    LEFT(IFF(LKP.BSNS_ENTY_SHRT_NM IS NULL, 'UNKNOWN', UPPER(LKP.BSNS_ENTY_SHRT_NM)), 30)     AS COMPANY_NM,
    $V_SESSSTARTTIME                                                                          AS LAST_UPDT_TS
FROM AEP_DW_BUSINESSENTITY_VW SQ
LEFT JOIN (
    SELECT
        BSNS_ENTY_SHRT_NM,
        BSNS_ENTY_ID
    FROM AEP_DW_BUSINESSENTITY_VW
    QUALIFY ROW_NUMBER() OVER (PARTITION BY BSNS_ENTY_ID ORDER BY BSNS_ENTY_ID) = 1
) LKP
  ON LKP.BSNS_ENTY_ID = SQ.FK_HLDNG_CO_ID
WHERE SQ.MOD_BY_DT >  $V_START_TIME
  AND SQ.MOD_BY_DT <= $V_END_TIME
  AND $V_RUN_STATUS = 'C'
  AND NOT EXISTS (
        SELECT 1
        FROM feladm.FEL_COMTRAC_BSNS_ENTY_FDR LKP_FDR
        WHERE LKP_FDR.BSNS_ENTY_ID = CAST(SQ.BSNS_ENTY_ID AS NUMBER(10,0))
      );
