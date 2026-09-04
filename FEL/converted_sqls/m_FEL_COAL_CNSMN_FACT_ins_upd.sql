/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_FACT_LOAD
 SESSION   : s_m_FEL_COAL_CNSMN_FACT_ins_upd
 MAPPING   : m_FEL_COAL_CNSMN_FACT_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTRTRANS splits on the target fact
             lookup; the unconnected DEFAULT1 group is discarded.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COAL_CNSMN_FDR   source filter on status
 LOOKUPS   : eight, all Use Any Value on multiple match. System, date and sampled
             reason are unconnected, the last called three times; facility,
             generating unit, inventory location and the target fact twice, for
             existence on RECLAIM_ID and for all measures by RECLAIM_KEY, are
             connected. The location lookup has no system id in this mapping.
 TARGET    : feladm.FEL_COAL_CNSMN_FACT   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$RUN_STATUS, $$REC_STATUS (SQ filter), $$START_TIME (router),
             $$COMTRAC (system lookup). $$END_TIME is declared but unused.
             SESSSTARTTIME -> LAST_UPDT_TS
             :UDF.DQ_FOR_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, source filter UPPER(TRIM(STATUS_TX)) = '$$REC_STATUS' only
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : A row is updated when it exists AND either its measures differ or its
             feeder LAST_UPDT_TS is at or after $$START_TIME. flag_ChangedRecord is
             inverted here against the rest of the workflow: 1 means all MATCHES.
             SAMPLED_KEY takes the unsampled reason, else 'Sampled' when any of ash,
             sulfur, moisture or btu is non zero, else 'Unknown'. Keys fall back to
             -2, never -1; STATUS_TX is cut to 6 by the expression ports.
             RECLAIM_KEY comes from a PERSISTENT sequence at 2110328, not reset per
             run; here it continues from the fact's own maximum instead.
             The captured run read 221813 rows, updated 54995 and inserted 23.
================================================================================
*/

SET V_START_TIME    = TO_TIMESTAMP_NTZ('09/02/2026 22:30:11', 'MM/DD/YYYY HH24:MI:SS');
SET V_REC_STATUS    = 'ACTIVE';
SET V_RUN_STATUS    = 'C';
SET V_COMTRAC       = 'COMTRAC';
SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_COAL_CNSMN_FACT TGT
SET
    RECLAIM_ID              = SRC.RECLAIM_ID,
    UNIT_KEY                = SRC.UNIT_KEY,
    INVTRY_LOC_KEY          = SRC.INVTRY_LOC_KEY,
    SAMPLED_KEY             = SRC.SAMPLED_KEY,
    CNSMN_DT_ID             = SRC.CNSMN_DT_ID,
    OWNING_FCLTY_KEY        = SRC.OWNING_FCLTY_KEY,
    STATUS_TX               = SRC.STATUS_TX,
    ANLYS_CTRL_NB           = SRC.ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB          = SRC.ANLYS_TRCKG_NB,
    ASH_QLTY_PCT            = SRC.ASH_QLTY_PCT,
    SULFUR_QLTY_PCT         = SRC.SULFUR_QLTY_PCT,
    MOISTURE_QLTY_PCT       = SRC.MOISTURE_QLTY_PCT,
    BTU_PER_LB_MSR          = SRC.BTU_PER_LB_MSR,
    SO2_LBS_PER_MBTU_MSR    = SRC.SO2_LBS_PER_MBTU_MSR,
    BURND_TONS_QY           = SRC.BURND_TONS_QY,
    SMPLD_TONS_QY           = SRC.SMPLD_TONS_QY,
    CNSMN_CST_AT            = SRC.CNSMN_CST_AT,
    CNSMN_SMPLD_ASH_QY      = SRC.CNSMN_SMPLD_ASH_QY,
    CNSMN_SMPLD_BTU_LB_QY   = SRC.CNSMN_SMPLD_BTU_LB_QY,
    CNSMN_SMPLD_MOISTURE_QY = SRC.CNSMN_SMPLD_MOISTURE_QY,
    CNSMN_SMPLD_SULFUR_QY   = SRC.CNSMN_SMPLD_SULFUR_QY,
    LAST_UPDT_TS            = SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.RECLAIM_ID AS NUMBER(10,0))                                              AS RECLAIM_ID,
        CAST(IFF(LKP_GU.UNIT_KEY IS NULL, -2, LKP_GU.UNIT_KEY) AS NUMBER(10,0))          AS UNIT_KEY,
        CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NULL, -2, LKP_IL.INVTRY_LOC_KEY) AS NUMBER(10,0)) AS INVTRY_LOC_KEY,
        CAST(IFF(DQ.DERIVED_SAMPLED_RCPT_KEY IS NULL, -2, DQ.DERIVED_SAMPLED_RCPT_KEY) AS NUMBER(10,0)) AS SAMPLED_KEY,
        CAST(IFF(LKP_DT.DATE_ID IS NULL, -2, LKP_DT.DATE_ID) AS NUMBER(5,0))             AS CNSMN_DT_ID,
        CAST(IFF(LKP_FD.FACILITY_KEY IS NULL, -2, LKP_FD.FACILITY_KEY) AS NUMBER(10,0))  AS OWNING_FCLTY_KEY,
        DQ.STATUS_TX,
        DQ.ANLYS_CTRL_NB,
        DQ.ANLYS_TRCKG_NB,
        CAST(DQ.ASH_QLTY_PCT AS NUMBER(12,3))                                            AS ASH_QLTY_PCT,
        CAST(DQ.SULFUR_QLTY_PCT AS NUMBER(12,3))                                         AS SULFUR_QLTY_PCT,
        CAST(DQ.MOISTURE_QLTY_PCT AS NUMBER(12,3))                                       AS MOISTURE_QLTY_PCT,
        CAST(DQ.BTU_PER_LB_MSR AS NUMBER(12,3))                                          AS BTU_PER_LB_MSR,
        CAST(DQ.SO2_LBS_PER_MBTU_MSR AS NUMBER(12,3))                                    AS SO2_LBS_PER_MBTU_MSR,
        CAST(DQ.BURND_TONS_QY AS NUMBER(12,3))                                           AS BURND_TONS_QY,
        CAST(DQ.SMPLD_TONS_QY AS NUMBER(12,3))                                           AS SMPLD_TONS_QY,
        CAST(DQ.CNSMN_CST_AT AS NUMBER(12,3))                                            AS CNSMN_CST_AT,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.ASH_QLTY_PCT, 5)      AS NUMBER(12,5))          AS CNSMN_SMPLD_ASH_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.BTU_PER_LB_MSR, 5)    AS NUMBER(12,3))          AS CNSMN_SMPLD_BTU_LB_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.MOISTURE_QLTY_PCT, 5) AS NUMBER(12,5))          AS CNSMN_SMPLD_MOISTURE_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.SULFUR_QLTY_PCT, 5)   AS NUMBER(12,5))          AS CNSMN_SMPLD_SULFUR_QY,
        DQ.FDR_LAST_UPDT_TS,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.RECLAIM_ID,
            SQ.UNIT_ID,
            SQ.INVTRY_LOC_ID,
            SQ.CNSMN_DATE,
            SQ.OWNING_FACILITY_ID,
            SQ.ASH_QLTY_PCT,
            SQ.SULFUR_QLTY_PCT,
            SQ.MOISTURE_QLTY_PCT,
            SQ.BTU_PER_LB_MSR,
            SQ.SO2_LBS_PER_MBTU_MSR,
            SQ.BURND_TONS_QY,
            SQ.SMPLD_TONS_QY,
            SQ.CNSMN_CST_AT,
            SQ.LAST_UPDT_TS                                                              AS FDR_LAST_UPDT_TS,
            CASE WHEN LENGTH(LTRIM(RTRIM(LEFT(SQ.STATUS_TX, 6)))) = 0 THEN ' ' ELSE RTRIM(LEFT(SQ.STATUS_TX, 6)) END AS STATUS_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLD_RSN_TX)))     = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLD_RSN_TX)     END AS UNSMPLD_RSN_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_CTRL_NB)))      = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_CTRL_NB)      END AS ANLYS_CTRL_NB,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_TRCKG_NB)))     = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_TRCKG_NB)     END AS ANLYS_TRCKG_NB,
            IFF((SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM
                  WHERE SMPLD_RSN_TX = CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLD_RSN_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLD_RSN_TX) END) IS NULL,
                IFF(SQ.ASH_QLTY_PCT <> 0 OR SQ.SULFUR_QLTY_PCT <> 0
                 OR SQ.MOISTURE_QLTY_PCT <> 0 OR SQ.BTU_PER_LB_MSR <> 0,
                    (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM WHERE SMPLD_RSN_TX = 'Sampled'),
                    (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM WHERE SMPLD_RSN_TX = 'Unknown')),
                (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM
                  WHERE SMPLD_RSN_TX = CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLD_RSN_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLD_RSN_TX) END)) AS DERIVED_SAMPLED_RCPT_KEY,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)    AS V_SYS_ID
        FROM feladm.FEL_COAL_CNSMN_FDR SQ
        WHERE UPPER(TRIM(SQ.STATUS_TX)) = $V_REC_STATUS
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT F.UNIT_KEY, UPPER(TRIM(F.UNIT_ID)) AS UNIT_ID, F.SYSTEM_ID
        FROM feladm.FEL_GNRTN_UNIT_DIM F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.UNIT_ID)), F.SYSTEM_ID ORDER BY F.UNIT_KEY) = 1
    ) LKP_GU
      ON LKP_GU.UNIT_ID   = LEFT(UPPER(TO_VARCHAR(DQ.UNIT_ID)), 20)
     AND LKP_GU.SYSTEM_ID = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT INVTRY_LOC_KEY, INVTRY_LOC_ID
        FROM feladm.FEL_INVTRY_LOC_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY INVTRY_LOC_ID ORDER BY INVTRY_LOC_KEY) = 1
    ) LKP_IL
      ON LKP_IL.INVTRY_LOC_ID = DQ.INVTRY_LOC_ID
    LEFT JOIN (
        SELECT DIM.FACILITY_KEY, TRIM(DIM.FACILITY_ID) AS FACILITY_ID, DIM.SYSTEM_ID
        FROM feladm.FEL_FACILITY_DIM DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(DIM.FACILITY_ID), DIM.SYSTEM_ID ORDER BY DIM.FACILITY_KEY) = 1
    ) LKP_FD
      ON LKP_FD.FACILITY_ID = LEFT(TO_VARCHAR(DQ.OWNING_FACILITY_ID), 3)
     AND LKP_FD.SYSTEM_ID   = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT DATE_ID, FULL_DATE_DT
        FROM FELADM.AEP_DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
    ) LKP_DT
      ON LKP_DT.FULL_DATE_DT = TRUNC(DQ.CNSMN_DATE, 'DD')
) SRC
WHERE TGT.RECLAIM_ID = SRC.RECLAIM_ID
  AND (   SRC.FDR_LAST_UPDT_TS >= $V_START_TIME
       OR NOT (    TGT.UNIT_KEY                = SRC.UNIT_KEY
               AND TGT.INVTRY_LOC_KEY          = SRC.INVTRY_LOC_KEY
               AND TGT.SAMPLED_KEY             = SRC.SAMPLED_KEY
               AND TGT.CNSMN_DT_ID             = SRC.CNSMN_DT_ID
               AND TGT.OWNING_FCLTY_KEY        = SRC.OWNING_FCLTY_KEY
               AND TGT.ANLYS_CTRL_NB           = SRC.ANLYS_CTRL_NB
               AND TGT.ANLYS_TRCKG_NB          = SRC.ANLYS_TRCKG_NB
               AND TGT.ASH_QLTY_PCT            = SRC.ASH_QLTY_PCT
               AND TGT.SULFUR_QLTY_PCT         = SRC.SULFUR_QLTY_PCT
               AND TGT.MOISTURE_QLTY_PCT       = SRC.MOISTURE_QLTY_PCT
               AND TGT.BTU_PER_LB_MSR          = SRC.BTU_PER_LB_MSR
               AND TGT.SO2_LBS_PER_MBTU_MSR    = SRC.SO2_LBS_PER_MBTU_MSR
               AND TGT.BURND_TONS_QY           = SRC.BURND_TONS_QY
               AND TGT.SMPLD_TONS_QY           = SRC.SMPLD_TONS_QY
               AND TGT.CNSMN_CST_AT            = SRC.CNSMN_CST_AT
               AND TGT.CNSMN_SMPLD_ASH_QY      = SRC.CNSMN_SMPLD_ASH_QY
               AND TGT.CNSMN_SMPLD_BTU_LB_QY   = SRC.CNSMN_SMPLD_BTU_LB_QY
               AND TGT.CNSMN_SMPLD_MOISTURE_QY = SRC.CNSMN_SMPLD_MOISTURE_QY
               AND TGT.CNSMN_SMPLD_SULFUR_QY   = SRC.CNSMN_SMPLD_SULFUR_QY));

INSERT INTO feladm.FEL_COAL_CNSMN_FACT (
    RECLAIM_KEY,
    RECLAIM_ID,
    UNIT_KEY,
    INVTRY_LOC_KEY,
    SAMPLED_KEY,
    CNSMN_DT_ID,
    OWNING_FCLTY_KEY,
    STATUS_TX,
    ANLYS_CTRL_NB,
    ANLYS_TRCKG_NB,
    ASH_QLTY_PCT,
    SULFUR_QLTY_PCT,
    MOISTURE_QLTY_PCT,
    BTU_PER_LB_MSR,
    SO2_LBS_PER_MBTU_MSR,
    BURND_TONS_QY,
    SMPLD_TONS_QY,
    CNSMN_CST_AT,
    CNSMN_SMPLD_ASH_QY,
    CNSMN_SMPLD_BTU_LB_QY,
    CNSMN_SMPLD_MOISTURE_QY,
    CNSMN_SMPLD_SULFUR_QY,
    LAST_UPDT_TS
)
SELECT
    NVL((SELECT MAX(RECLAIM_KEY) FROM feladm.FEL_COAL_CNSMN_FACT), 0)
        + ROW_NUMBER() OVER (ORDER BY SRC.RECLAIM_ID)                                    AS RECLAIM_KEY,
    SRC.RECLAIM_ID,
    SRC.UNIT_KEY,
    SRC.INVTRY_LOC_KEY,
    SRC.SAMPLED_KEY,
    SRC.CNSMN_DT_ID,
    SRC.OWNING_FCLTY_KEY,
    SRC.STATUS_TX,
    SRC.ANLYS_CTRL_NB,
    SRC.ANLYS_TRCKG_NB,
    SRC.ASH_QLTY_PCT,
    SRC.SULFUR_QLTY_PCT,
    SRC.MOISTURE_QLTY_PCT,
    SRC.BTU_PER_LB_MSR,
    SRC.SO2_LBS_PER_MBTU_MSR,
    SRC.BURND_TONS_QY,
    SRC.SMPLD_TONS_QY,
    SRC.CNSMN_CST_AT,
    SRC.CNSMN_SMPLD_ASH_QY,
    SRC.CNSMN_SMPLD_BTU_LB_QY,
    SRC.CNSMN_SMPLD_MOISTURE_QY,
    SRC.CNSMN_SMPLD_SULFUR_QY,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        CAST(DQ.RECLAIM_ID AS NUMBER(10,0))                                              AS RECLAIM_ID,
        CAST(IFF(LKP_GU.UNIT_KEY IS NULL, -2, LKP_GU.UNIT_KEY) AS NUMBER(10,0))          AS UNIT_KEY,
        CAST(IFF(LKP_IL.INVTRY_LOC_KEY IS NULL, -2, LKP_IL.INVTRY_LOC_KEY) AS NUMBER(10,0)) AS INVTRY_LOC_KEY,
        CAST(IFF(DQ.DERIVED_SAMPLED_RCPT_KEY IS NULL, -2, DQ.DERIVED_SAMPLED_RCPT_KEY) AS NUMBER(10,0)) AS SAMPLED_KEY,
        CAST(IFF(LKP_DT.DATE_ID IS NULL, -2, LKP_DT.DATE_ID) AS NUMBER(5,0))             AS CNSMN_DT_ID,
        CAST(IFF(LKP_FD.FACILITY_KEY IS NULL, -2, LKP_FD.FACILITY_KEY) AS NUMBER(10,0))  AS OWNING_FCLTY_KEY,
        DQ.STATUS_TX,
        DQ.ANLYS_CTRL_NB,
        DQ.ANLYS_TRCKG_NB,
        CAST(DQ.ASH_QLTY_PCT AS NUMBER(12,3))                                            AS ASH_QLTY_PCT,
        CAST(DQ.SULFUR_QLTY_PCT AS NUMBER(12,3))                                         AS SULFUR_QLTY_PCT,
        CAST(DQ.MOISTURE_QLTY_PCT AS NUMBER(12,3))                                       AS MOISTURE_QLTY_PCT,
        CAST(DQ.BTU_PER_LB_MSR AS NUMBER(12,3))                                          AS BTU_PER_LB_MSR,
        CAST(DQ.SO2_LBS_PER_MBTU_MSR AS NUMBER(12,3))                                    AS SO2_LBS_PER_MBTU_MSR,
        CAST(DQ.BURND_TONS_QY AS NUMBER(12,3))                                           AS BURND_TONS_QY,
        CAST(DQ.SMPLD_TONS_QY AS NUMBER(12,3))                                           AS SMPLD_TONS_QY,
        CAST(DQ.CNSMN_CST_AT AS NUMBER(12,3))                                            AS CNSMN_CST_AT,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.ASH_QLTY_PCT, 5)      AS NUMBER(12,5))          AS CNSMN_SMPLD_ASH_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.BTU_PER_LB_MSR, 5)    AS NUMBER(12,3))          AS CNSMN_SMPLD_BTU_LB_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.MOISTURE_QLTY_PCT, 5) AS NUMBER(12,5))          AS CNSMN_SMPLD_MOISTURE_QY,
        CAST(ROUND(DQ.SMPLD_TONS_QY * DQ.SULFUR_QLTY_PCT, 5)   AS NUMBER(12,5))          AS CNSMN_SMPLD_SULFUR_QY,
        $V_SESSSTARTTIME                                                                 AS LAST_UPDT_TS
    FROM (
        SELECT
            SQ.RECLAIM_ID,
            SQ.UNIT_ID,
            SQ.INVTRY_LOC_ID,
            SQ.CNSMN_DATE,
            SQ.OWNING_FACILITY_ID,
            SQ.ASH_QLTY_PCT,
            SQ.SULFUR_QLTY_PCT,
            SQ.MOISTURE_QLTY_PCT,
            SQ.BTU_PER_LB_MSR,
            SQ.SO2_LBS_PER_MBTU_MSR,
            SQ.BURND_TONS_QY,
            SQ.SMPLD_TONS_QY,
            SQ.CNSMN_CST_AT,
            CASE WHEN LENGTH(LTRIM(RTRIM(LEFT(SQ.STATUS_TX, 6)))) = 0 THEN ' ' ELSE RTRIM(LEFT(SQ.STATUS_TX, 6)) END AS STATUS_TX,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_CTRL_NB)))      = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_CTRL_NB)      END AS ANLYS_CTRL_NB,
            CASE WHEN LENGTH(LTRIM(RTRIM(SQ.ANLYS_TRCKG_NB)))     = 0 THEN ' ' ELSE RTRIM(SQ.ANLYS_TRCKG_NB)     END AS ANLYS_TRCKG_NB,
            IFF((SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM
                  WHERE SMPLD_RSN_TX = CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLD_RSN_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLD_RSN_TX) END) IS NULL,
                IFF(SQ.ASH_QLTY_PCT <> 0 OR SQ.SULFUR_QLTY_PCT <> 0
                 OR SQ.MOISTURE_QLTY_PCT <> 0 OR SQ.BTU_PER_LB_MSR <> 0,
                    (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM WHERE SMPLD_RSN_TX = 'Sampled'),
                    (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM WHERE SMPLD_RSN_TX = 'Unknown')),
                (SELECT MIN(SAMPLED_KEY) FROM feladm.FEL_SAMPLED_DIM
                  WHERE SMPLD_RSN_TX = CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNSMPLD_RSN_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.UNSMPLD_RSN_TX) END)) AS DERIVED_SAMPLED_RCPT_KEY,
            (SELECT MIN(SYS_ID) FROM feladm.FEL_SYSTEM_DIM WHERE SYS_NM = $V_COMTRAC)    AS V_SYS_ID
        FROM feladm.FEL_COAL_CNSMN_FDR SQ
        WHERE UPPER(TRIM(SQ.STATUS_TX)) = $V_REC_STATUS
          AND $V_RUN_STATUS = 'C'
    ) DQ
    LEFT JOIN (
        SELECT F.UNIT_KEY, UPPER(TRIM(F.UNIT_ID)) AS UNIT_ID, F.SYSTEM_ID
        FROM feladm.FEL_GNRTN_UNIT_DIM F
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.UNIT_ID)), F.SYSTEM_ID ORDER BY F.UNIT_KEY) = 1
    ) LKP_GU
      ON LKP_GU.UNIT_ID   = LEFT(UPPER(TO_VARCHAR(DQ.UNIT_ID)), 20)
     AND LKP_GU.SYSTEM_ID = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT INVTRY_LOC_KEY, INVTRY_LOC_ID
        FROM feladm.FEL_INVTRY_LOC_DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY INVTRY_LOC_ID ORDER BY INVTRY_LOC_KEY) = 1
    ) LKP_IL
      ON LKP_IL.INVTRY_LOC_ID = DQ.INVTRY_LOC_ID
    LEFT JOIN (
        SELECT DIM.FACILITY_KEY, TRIM(DIM.FACILITY_ID) AS FACILITY_ID, DIM.SYSTEM_ID
        FROM feladm.FEL_FACILITY_DIM DIM
        QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(DIM.FACILITY_ID), DIM.SYSTEM_ID ORDER BY DIM.FACILITY_KEY) = 1
    ) LKP_FD
      ON LKP_FD.FACILITY_ID = LEFT(TO_VARCHAR(DQ.OWNING_FACILITY_ID), 3)
     AND LKP_FD.SYSTEM_ID   = DQ.V_SYS_ID
    LEFT JOIN (
        SELECT DATE_ID, FULL_DATE_DT
        FROM FELADM.AEP_DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY FULL_DATE_DT ORDER BY FULL_DATE_DT) = 1
    ) LKP_DT
      ON LKP_DT.FULL_DATE_DT = TRUNC(DQ.CNSMN_DATE, 'DD')
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_COAL_CNSMN_FACT L
    WHERE L.RECLAIM_ID = SRC.RECLAIM_ID
);
