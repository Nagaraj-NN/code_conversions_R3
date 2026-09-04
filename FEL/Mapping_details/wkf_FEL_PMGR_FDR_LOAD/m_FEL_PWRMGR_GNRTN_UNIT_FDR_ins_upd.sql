/*
================================================================================
 WORKFLOW  : wkf_FEL_PMGR_FDR_LOAD
 SESSION   : s_m_FEL_PWRMGR_GNRTN_UNIT_FDR_ins_upd
 MAPPING   : m_FEL_PWRMGR_GNRTN_UNIT_FDR_ins_upd
 OPERATION : INSERT + UPDATE, data driven. RTR_NEW_OR_EXIST splits on the target
             lookup alone, with no change test; DEFAULT1 is discarded.
--------------------------------------------------------------------------------
 SOURCE    : PMGR.UNIT, latest EFFECTIVEDATE per UNITID, joined to Unit_Type and
             utility_operator
 LOOKUPS   : five, all Use Any Value. PMGR.CAP_UNIT_CAPABILITY for the nameplate
             capacity, filtered to CAPABILITYID = 'NAMEPLATE'; the load type feeder
             for the load type name; PMGR.FUEL_CODE and FEL_FUEL_CODE_FDR, each
             called four times; and FEL_PWRMGR_GNRTN_UNIT_FDR for existence.
 TARGET    : feladm.FEL_PWRMGR_GNRTN_UNIT_FDR   insert and update instances
--------------------------------------------------------------------------------
 PARAMETERS: $$RUN_STATUS, $$START_TIME and $$END_TIME are declared but NONE are
             referenced; the SQ override carries no filter
             SESSSTARTTIME -> LAST_UPDT_TS
 SQ OVERRIDE : PRESENT on SQ_UNIT, reproduced verbatim below. Its 14 columns bind
               positionally to the 14 connected ports.
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : Each fuel label takes the PowerManager description first, then the
             FEL feeder description, then 'UNKNOWN'; each fuel text prefixes the
             code and a dash to whichever label won.
             The insert writes the RAW UNITID while the update keys on the TRIMMED
             value returned by the lookup. Kept as authored.
             BSNS_ENTY_NM is computed from utilityname but reaches no target column.
             NM_PLATE_CAP_QY has no default, so a unit with no NAMEPLATE row sends
             NULL into a NOT NULL column and is rejected.
             The captured run read 408 rows and updated all 408.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

UPDATE feladm.FEL_PWRMGR_GNRTN_UNIT_FDR TGT
SET
    UNIT_NM           = SRC.UNIT_NM,
    UNIT_TYPE_CD      = SRC.UNIT_TYPE_CD,
    UNIT_TYPE_NM      = SRC.UNIT_TYPE_NM,
    UNIT_TYPE_TX      = SRC.UNIT_TYPE_TX,
    BLACK_START_TX    = SRC.BLACK_START_TX,
    CMRCL_YR_NB       = SRC.CMRCL_YR_NB,
    CMRCL_YR_MO_NB    = SRC.CMRCL_YR_MO_NB,
    CMRCL_DT          = SRC.CMRCL_DT,
    ISO_CD            = SRC.ISO_CD,
    LOAD_TYPE_TX      = SRC.LOAD_TYPE_TX,
    FUEL_CD_PRMRY     = SRC.FUEL_CD_PRMRY,
    FUEL_LABEL_PRMRY  = SRC.FUEL_LABEL_PRMRY,
    FUEL_DESCN_PRMRY  = SRC.FUEL_DESCN_PRMRY,
    FUEL_CD_SCNDRY    = SRC.FUEL_CD_SCNDRY,
    FUEL_LABEL_SCNDRY = SRC.FUEL_LABEL_SCNDRY,
    FUEL_DESC_SCNDRY  = SRC.FUEL_DESC_SCNDRY,
    FUEL_CD_TERTY     = SRC.FUEL_CD_TERTY,
    FUEL_LABEL_TERTY  = SRC.FUEL_LABEL_TERTY,
    FUEL_DESC_TERTY   = SRC.FUEL_DESC_TERTY,
    FUEL_CD_QTRNRY    = SRC.FUEL_CD_QTRNRY,
    FUEL_LABEL_QTRNRY = SRC.FUEL_LABEL_QTRNRY,
    FUEL_DESC_QTRNRY  = SRC.FUEL_DESC_QTRNRY,
    NM_PLATE_CAP_QY   = SRC.NM_PLATE_CAP_QY,
    PI_TAG_CD         = SRC.PI_TAG_CD,
    LAST_UPDT_TS      = SRC.LAST_UPDT_TS
FROM (
    SELECT
        LTRIM(RTRIM(SQ.UNITID))                                                        AS TRIM_UNIT_ID,
        LEFT(SQ.UNITNAME, 40)                                                          AS UNIT_NM,
        LEFT(SQ.UNITTYPECODE, 2)                                                       AS UNIT_TYPE_CD,
        LEFT(SQ.unittype, 100)                                                         AS UNIT_TYPE_NM,
        LEFT(NVL(SQ.UNITTYPECODE, '') || '-' || NVL(SQ.unittype, ''), 100)             AS UNIT_TYPE_TX,
        LEFT(IFF(SQ.BLACK_START IS NOT NULL, SQ.BLACK_START, 'UNKNOWN'), 7)            AS BLACK_START_TX,
        CAST(IFF(SQ.COMMERCIALDATE IS NOT NULL, YEAR(SQ.COMMERCIALDATE), -1) AS NUMBER(5,0)) AS CMRCL_YR_NB,
        LEFT(IFF(SQ.COMMERCIALDATE IS NOT NULL,
                 TO_VARCHAR(YEAR(SQ.COMMERCIALDATE)) || ' (' ||
                 LPAD(TO_VARCHAR(MONTH(SQ.COMMERCIALDATE)), 2, '0') || ') ' ||
                 TO_CHAR(SQ.COMMERCIALDATE, 'MMMM'), 'UNKNOWN'), 22)                   AS CMRCL_YR_MO_NB,
        IFF(SQ.COMMERCIALDATE IS NOT NULL, SQ.COMMERCIALDATE,
            TO_DATE('01/01/1900', 'MM/DD/YYYY'))                                       AS CMRCL_DT,
        LEFT(IFF(SQ.ISO IS NOT NULL, SQ.ISO, 'UNKNOWN'), 10)                           AS ISO_CD,
        LEFT(IFF(SQ.LOADING_CHAR IS NOT NULL,
                 NVL(SQ.LOADING_CHAR, '') || ' - ' || NVL(LKP_LT.LOAD_TYPE_NM, ''),
                 'UNKNOWN'), 100)                                                      AS LOAD_TYPE_TX,
        LEFT(IFF(SQ.PRIMARY_FUEL_CODE     IS NOT NULL, SQ.PRIMARY_FUEL_CODE,     'UNKNOWN'), 7) AS FUEL_CD_PRMRY,
        LEFT(IFF(SQ.SECONDARY_FUEL_CODE   IS NOT NULL, SQ.SECONDARY_FUEL_CODE,   'UNKNOWN'), 7) AS FUEL_CD_SCNDRY,
        LEFT(IFF(SQ.TERTIARY_FUEL_CODE    IS NOT NULL, SQ.TERTIARY_FUEL_CODE,    'UNKNOWN'), 7) AS FUEL_CD_TERTY,
        LEFT(IFF(SQ.QUARTERNARY_FUEL_CODE IS NOT NULL, SQ.QUARTERNARY_FUEL_CODE, 'UNKNOWN'), 7) AS FUEL_CD_QTRNRY,
        LEFT(CASE WHEN PF1.DESCRIPTION IS NOT NULL THEN PF1.DESCRIPTION
                  WHEN FF1.FUEL_CD_DESCN_TX IS NOT NULL THEN FF1.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_PRMRY,
        LEFT(CASE WHEN PF2.DESCRIPTION IS NOT NULL THEN PF2.DESCRIPTION
                  WHEN FF2.FUEL_CD_DESCN_TX IS NOT NULL THEN FF2.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_SCNDRY,
        LEFT(CASE WHEN PF3.DESCRIPTION IS NOT NULL THEN PF3.DESCRIPTION
                  WHEN FF3.FUEL_CD_DESCN_TX IS NOT NULL THEN FF3.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_TERTY,
        LEFT(CASE WHEN PF4.DESCRIPTION IS NOT NULL THEN PF4.DESCRIPTION
                  WHEN FF4.FUEL_CD_DESCN_TX IS NOT NULL THEN FF4.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_QTRNRY,
        LEFT(CASE WHEN PF1.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.PRIMARY_FUEL_CODE, '') || ' - ' || PF1.DESCRIPTION
                  WHEN FF1.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.PRIMARY_FUEL_CODE, '') || ' - ' || FF1.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESCN_PRMRY,
        LEFT(CASE WHEN PF2.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.SECONDARY_FUEL_CODE, '') || ' - ' || PF2.DESCRIPTION
                  WHEN FF2.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.SECONDARY_FUEL_CODE, '') || ' - ' || FF2.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_SCNDRY,
        LEFT(CASE WHEN PF3.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.TERTIARY_FUEL_CODE, '') || ' - ' || PF3.DESCRIPTION
                  WHEN FF3.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.TERTIARY_FUEL_CODE, '') || ' - ' || FF3.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_TERTY,
        LEFT(CASE WHEN PF4.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.QUARTERNARY_FUEL_CODE, '') || ' - ' || PF4.DESCRIPTION
                  WHEN FF4.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.QUARTERNARY_FUEL_CODE, '') || ' - ' || FF4.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_QTRNRY,
        LEFT(IFF(LKP_CAP.CAP1 IS NOT NULL, TO_VARCHAR(LKP_CAP.CAP1), NULL), 25)        AS NM_PLATE_CAP_QY,
        LEFT(IFF(SQ.PITAG IS NOT NULL, SQ.PITAG, 'UNKNOWN'), 20)                       AS PI_TAG_CD,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS
    FROM (
        SELECT
            u.UNITNAME,
            u.UNITID,
            u.UNITTYPECODE,
            u.ISO,
            u.BLACK_START,
            u.LOADING_CHAR,
            u.PRIMARY_FUEL_CODE,
            u.SECONDARY_FUEL_CODE,
            u.TERTIARY_FUEL_CODE,
            u.QUARTERNARY_FUEL_CODE,
            u.PITAG,
            u.COMMERCIALDATE,
            ut.unittype        AS unittype,
            uo.utilityname     AS businessname
        FROM PMGR.UNIT U
        INNER JOIN (
            SELECT UNITID, MAX(EFFECTIVEDATE) AS m_EFFECTIVEDATE
            FROM PMGR.UNIT
            GROUP BY UNITID
        ) m
          ON u.unitid = m.unitid
         AND u.EFFECTIVEDATE = m.m_EFFECTIVEDATE
        LEFT OUTER JOIN PMGR.Unit_Type ut
          ON u.UNITTYPECODE = ut.unittypecode
        LEFT OUTER JOIN PMGR.utility_operator uo
          ON u.UTILITY = uo.utility
    ) SQ
    LEFT JOIN (
        SELECT CAP1, UNITID
        FROM PMGR.CAP_UNIT_CAPABILITY
        WHERE CAPABILITYID = 'NAMEPLATE'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UNITID ORDER BY UNITID, CAP1) = 1
    ) LKP_CAP
      ON LKP_CAP.UNITID = SQ.UNITID
    LEFT JOIN (
        SELECT LOAD_TYPE_NM, LOAD_TYPE_ID
        FROM feladm.FEL_PWRMGR_LOAD_TYPE_FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY LOAD_TYPE_ID ORDER BY LOAD_TYPE_ID) = 1
    ) LKP_LT
      ON LKP_LT.LOAD_TYPE_ID = TRY_TO_NUMBER(SQ.LOADING_CHAR)
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF1
      ON PF1.CODE = LTRIM(RTRIM(SQ.PRIMARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF2
      ON PF2.CODE = LTRIM(RTRIM(SQ.SECONDARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF3
      ON PF3.CODE = LTRIM(RTRIM(SQ.TERTIARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF4
      ON PF4.CODE = LTRIM(RTRIM(SQ.QUARTERNARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF1
      ON FF1.FUEL_CD = LTRIM(RTRIM(SQ.PRIMARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF2
      ON FF2.FUEL_CD = LTRIM(RTRIM(SQ.SECONDARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF3
      ON FF3.FUEL_CD = LTRIM(RTRIM(SQ.TERTIARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF4
      ON FF4.FUEL_CD = LTRIM(RTRIM(SQ.QUARTERNARY_FUEL_CODE))
) SRC
WHERE TRIM(TGT.UNIT_ID) = SRC.TRIM_UNIT_ID;

INSERT INTO feladm.FEL_PWRMGR_GNRTN_UNIT_FDR (
    UNIT_ID,
    UNIT_NM,
    UNIT_TYPE_CD,
    UNIT_TYPE_NM,
    UNIT_TYPE_TX,
    BLACK_START_TX,
    CMRCL_YR_NB,
    CMRCL_YR_MO_NB,
    CMRCL_DT,
    ISO_CD,
    LOAD_TYPE_TX,
    FUEL_CD_PRMRY,
    FUEL_LABEL_PRMRY,
    FUEL_DESCN_PRMRY,
    FUEL_CD_SCNDRY,
    FUEL_LABEL_SCNDRY,
    FUEL_DESC_SCNDRY,
    FUEL_CD_TERTY,
    FUEL_LABEL_TERTY,
    FUEL_DESC_TERTY,
    FUEL_CD_QTRNRY,
    FUEL_LABEL_QTRNRY,
    FUEL_DESC_QTRNRY,
    NM_PLATE_CAP_QY,
    PI_TAG_CD,
    LAST_UPDT_TS
)
SELECT
    SRC.UNIT_ID,
    SRC.UNIT_NM,
    SRC.UNIT_TYPE_CD,
    SRC.UNIT_TYPE_NM,
    SRC.UNIT_TYPE_TX,
    SRC.BLACK_START_TX,
    SRC.CMRCL_YR_NB,
    SRC.CMRCL_YR_MO_NB,
    SRC.CMRCL_DT,
    SRC.ISO_CD,
    SRC.LOAD_TYPE_TX,
    SRC.FUEL_CD_PRMRY,
    SRC.FUEL_LABEL_PRMRY,
    SRC.FUEL_DESCN_PRMRY,
    SRC.FUEL_CD_SCNDRY,
    SRC.FUEL_LABEL_SCNDRY,
    SRC.FUEL_DESC_SCNDRY,
    SRC.FUEL_CD_TERTY,
    SRC.FUEL_LABEL_TERTY,
    SRC.FUEL_DESC_TERTY,
    SRC.FUEL_CD_QTRNRY,
    SRC.FUEL_LABEL_QTRNRY,
    SRC.FUEL_DESC_QTRNRY,
    SRC.NM_PLATE_CAP_QY,
    SRC.PI_TAG_CD,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        LEFT(SQ.UNITID, 20)                                                            AS UNIT_ID,
        LTRIM(RTRIM(SQ.UNITID))                                                        AS TRIM_UNIT_ID,
        LEFT(SQ.UNITNAME, 40)                                                          AS UNIT_NM,
        LEFT(SQ.UNITTYPECODE, 2)                                                       AS UNIT_TYPE_CD,
        LEFT(SQ.unittype, 100)                                                         AS UNIT_TYPE_NM,
        LEFT(NVL(SQ.UNITTYPECODE, '') || '-' || NVL(SQ.unittype, ''), 100)             AS UNIT_TYPE_TX,
        LEFT(IFF(SQ.BLACK_START IS NOT NULL, SQ.BLACK_START, 'UNKNOWN'), 7)            AS BLACK_START_TX,
        CAST(IFF(SQ.COMMERCIALDATE IS NOT NULL, YEAR(SQ.COMMERCIALDATE), -1) AS NUMBER(5,0)) AS CMRCL_YR_NB,
        LEFT(IFF(SQ.COMMERCIALDATE IS NOT NULL,
                 TO_VARCHAR(YEAR(SQ.COMMERCIALDATE)) || ' (' ||
                 LPAD(TO_VARCHAR(MONTH(SQ.COMMERCIALDATE)), 2, '0') || ') ' ||
                 TO_CHAR(SQ.COMMERCIALDATE, 'MMMM'), 'UNKNOWN'), 22)                   AS CMRCL_YR_MO_NB,
        IFF(SQ.COMMERCIALDATE IS NOT NULL, SQ.COMMERCIALDATE,
            TO_DATE('01/01/1900', 'MM/DD/YYYY'))                                       AS CMRCL_DT,
        LEFT(IFF(SQ.ISO IS NOT NULL, SQ.ISO, 'UNKNOWN'), 10)                           AS ISO_CD,
        LEFT(IFF(SQ.LOADING_CHAR IS NOT NULL,
                 NVL(SQ.LOADING_CHAR, '') || ' - ' || NVL(LKP_LT.LOAD_TYPE_NM, ''),
                 'UNKNOWN'), 100)                                                      AS LOAD_TYPE_TX,
        LEFT(IFF(SQ.PRIMARY_FUEL_CODE     IS NOT NULL, SQ.PRIMARY_FUEL_CODE,     'UNKNOWN'), 7) AS FUEL_CD_PRMRY,
        LEFT(IFF(SQ.SECONDARY_FUEL_CODE   IS NOT NULL, SQ.SECONDARY_FUEL_CODE,   'UNKNOWN'), 7) AS FUEL_CD_SCNDRY,
        LEFT(IFF(SQ.TERTIARY_FUEL_CODE    IS NOT NULL, SQ.TERTIARY_FUEL_CODE,    'UNKNOWN'), 7) AS FUEL_CD_TERTY,
        LEFT(IFF(SQ.QUARTERNARY_FUEL_CODE IS NOT NULL, SQ.QUARTERNARY_FUEL_CODE, 'UNKNOWN'), 7) AS FUEL_CD_QTRNRY,
        LEFT(CASE WHEN PF1.DESCRIPTION IS NOT NULL THEN PF1.DESCRIPTION
                  WHEN FF1.FUEL_CD_DESCN_TX IS NOT NULL THEN FF1.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_PRMRY,
        LEFT(CASE WHEN PF2.DESCRIPTION IS NOT NULL THEN PF2.DESCRIPTION
                  WHEN FF2.FUEL_CD_DESCN_TX IS NOT NULL THEN FF2.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_SCNDRY,
        LEFT(CASE WHEN PF3.DESCRIPTION IS NOT NULL THEN PF3.DESCRIPTION
                  WHEN FF3.FUEL_CD_DESCN_TX IS NOT NULL THEN FF3.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_TERTY,
        LEFT(CASE WHEN PF4.DESCRIPTION IS NOT NULL THEN PF4.DESCRIPTION
                  WHEN FF4.FUEL_CD_DESCN_TX IS NOT NULL THEN FF4.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_LABEL_QTRNRY,
        LEFT(CASE WHEN PF1.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.PRIMARY_FUEL_CODE, '') || ' - ' || PF1.DESCRIPTION
                  WHEN FF1.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.PRIMARY_FUEL_CODE, '') || ' - ' || FF1.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESCN_PRMRY,
        LEFT(CASE WHEN PF2.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.SECONDARY_FUEL_CODE, '') || ' - ' || PF2.DESCRIPTION
                  WHEN FF2.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.SECONDARY_FUEL_CODE, '') || ' - ' || FF2.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_SCNDRY,
        LEFT(CASE WHEN PF3.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.TERTIARY_FUEL_CODE, '') || ' - ' || PF3.DESCRIPTION
                  WHEN FF3.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.TERTIARY_FUEL_CODE, '') || ' - ' || FF3.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_TERTY,
        LEFT(CASE WHEN PF4.DESCRIPTION IS NOT NULL
                       THEN NVL(SQ.QUARTERNARY_FUEL_CODE, '') || ' - ' || PF4.DESCRIPTION
                  WHEN FF4.FUEL_CD_DESCN_TX IS NOT NULL
                       THEN NVL(SQ.QUARTERNARY_FUEL_CODE, '') || ' - ' || FF4.FUEL_CD_DESCN_TX
                  ELSE 'UNKNOWN' END, 100)                                             AS FUEL_DESC_QTRNRY,
        LEFT(IFF(LKP_CAP.CAP1 IS NOT NULL, TO_VARCHAR(LKP_CAP.CAP1), NULL), 25)        AS NM_PLATE_CAP_QY,
        LEFT(IFF(SQ.PITAG IS NOT NULL, SQ.PITAG, 'UNKNOWN'), 20)                       AS PI_TAG_CD,
        $V_SESSSTARTTIME                                                               AS LAST_UPDT_TS
    FROM (
        SELECT
            u.UNITNAME,
            u.UNITID,
            u.UNITTYPECODE,
            u.ISO,
            u.BLACK_START,
            u.LOADING_CHAR,
            u.PRIMARY_FUEL_CODE,
            u.SECONDARY_FUEL_CODE,
            u.TERTIARY_FUEL_CODE,
            u.QUARTERNARY_FUEL_CODE,
            u.PITAG,
            u.COMMERCIALDATE,
            ut.unittype        AS unittype,
            uo.utilityname     AS businessname
        FROM PMGR.UNIT U
        INNER JOIN (
            SELECT UNITID, MAX(EFFECTIVEDATE) AS m_EFFECTIVEDATE
            FROM PMGR.UNIT
            GROUP BY UNITID
        ) m
          ON u.unitid = m.unitid
         AND u.EFFECTIVEDATE = m.m_EFFECTIVEDATE
        LEFT OUTER JOIN PMGR.Unit_Type ut
          ON u.UNITTYPECODE = ut.unittypecode
        LEFT OUTER JOIN PMGR.utility_operator uo
          ON u.UTILITY = uo.utility
    ) SQ
    LEFT JOIN (
        SELECT CAP1, UNITID
        FROM PMGR.CAP_UNIT_CAPABILITY
        WHERE CAPABILITYID = 'NAMEPLATE'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UNITID ORDER BY UNITID, CAP1) = 1
    ) LKP_CAP
      ON LKP_CAP.UNITID = SQ.UNITID
    LEFT JOIN (
        SELECT LOAD_TYPE_NM, LOAD_TYPE_ID
        FROM feladm.FEL_PWRMGR_LOAD_TYPE_FDR
        QUALIFY ROW_NUMBER() OVER (PARTITION BY LOAD_TYPE_ID ORDER BY LOAD_TYPE_ID) = 1
    ) LKP_LT
      ON LKP_LT.LOAD_TYPE_ID = TRY_TO_NUMBER(SQ.LOADING_CHAR)
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF1
      ON PF1.CODE = LTRIM(RTRIM(SQ.PRIMARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF2
      ON PF2.CODE = LTRIM(RTRIM(SQ.SECONDARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF3
      ON PF3.CODE = LTRIM(RTRIM(SQ.TERTIARY_FUEL_CODE))
    LEFT JOIN (SELECT FC.DESCRIPTION, TRIM(FC.CODE) AS CODE FROM PMGR.FUEL_CODE FC
               QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(FC.CODE) ORDER BY FC.DESCRIPTION) = 1) PF4
      ON PF4.CODE = LTRIM(RTRIM(SQ.QUARTERNARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF1
      ON FF1.FUEL_CD = LTRIM(RTRIM(SQ.PRIMARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF2
      ON FF2.FUEL_CD = LTRIM(RTRIM(SQ.SECONDARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF3
      ON FF3.FUEL_CD = LTRIM(RTRIM(SQ.TERTIARY_FUEL_CODE))
    LEFT JOIN (SELECT F.FUEL_CD_DESCN_TX, UPPER(TRIM(F.FUEL_CD)) AS FUEL_CD FROM FELADM.FEL_FUEL_CODE_FDR F
               QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(F.FUEL_CD)) ORDER BY F.FUEL_CD_DESCN_TX) = 1) FF4
      ON FF4.FUEL_CD = LTRIM(RTRIM(SQ.QUARTERNARY_FUEL_CODE))
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM FELADM.FEL_PWRMGR_GNRTN_UNIT_FDR U
    WHERE TRIM(U.UNIT_ID) = SRC.TRIM_UNIT_ID
);
