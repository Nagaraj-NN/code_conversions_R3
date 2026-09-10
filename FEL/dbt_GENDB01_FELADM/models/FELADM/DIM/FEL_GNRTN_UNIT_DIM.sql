-- ==========================================================================
-- Model      : FEL_GNRTN_UNIT_DIM
-- Mapping    : m_FEL_COMTRAC_GNRTN_UNIT_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_COMTRAC_GNRTN_UNIT_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_GNRTN_UNIT_DIM
-- Load type  : table + UPDATE post-hook + INSERT post-hook
-- --------------------------------------------------------------------------
-- INSERT + UPDATE, data driven, with asymmetric writers: the insert instance
-- writes all 35 dimension columns and the update instance touches only 11.
--
-- The Informatica router branches are preserved as validated: the model holds
-- the transformed source row set once, and the two post-hooks apply the
-- UPDATE branch and the INSERT branch to the real target.
--
-- Both branches read exactly the same FROM in the validated script, so the
-- model carries it once. The 24 columns the insert instance fills with
-- placeholders ('NA', -2, 1900-01-01) are constants and stay in the INSERT
-- post-hook rather than becoming constant columns of this table. UNIT_KEY and
-- V_SYS_ID are the only source-derived values the insert branch needs beyond
-- the update branch's projection, so those two are added here.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_GNRTN_UNIT_DIM_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_GNRTN_UNIT_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_COMTRAC_GNRTN_UNIT_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_GNRTN_UNIT_DIM', target_object='GENDB01.FELADM.FEL_GNRTN_UNIT_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_GNRTN_UNIT_DIM') }} TGT
     SET
         UNIT_ID          = SRC.UNIT_ID,
         UNIT_NM          = SRC.UNIT_NM,
         UNIT_STAT_TX     = SRC.UNIT_STAT_TX,
         BSNS_ENTY_KEY    = SRC.BSNS_ENTY_KEY,
         BSNS_ENTY_NM     = SRC.BSNS_ENTY_NM,
         SYSTEM_ID        = SRC.SYSTEM_ID,
         SYSTEM_NM        = SRC.SYSTEM_NM,
         CONSOLIDATION_ID = SRC.CONSOLIDATION_ID,
         CONSOLIDATION_NM = SRC.CONSOLIDATION_NM,
         CNSLDTN_SYS_NM   = SRC.CNSLDTN_SYS_NM,
         LAST_UPDT_TS     = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TRIM(TGT.UNIT_ID) = SRC.UNIT_ID
       AND TGT.SYSTEM_ID     = SRC.SYSTEM_ID
       AND (   SRC.UNIT_NM          <> TGT.UNIT_NM
            OR SRC.UNIT_STAT_TX     <> TGT.UNIT_STAT_TX
            OR SRC.BSNS_ENTY_KEY    <> TGT.BSNS_ENTY_KEY
            OR SRC.BSNS_ENTY_NM     <> TGT.BSNS_ENTY_NM
            OR SRC.CONSOLIDATION_ID <> TGT.CONSOLIDATION_ID
            OR SRC.CONSOLIDATION_NM <> TGT.CONSOLIDATION_NM
            OR SRC.CNSLDTN_SYS_NM   <> TGT.CNSLDTN_SYS_NM)",
        "INSERT INTO {{ source('GENDB01_FELADM','FEL_GNRTN_UNIT_DIM') }} (
         UNIT_KEY,
         UNIT_ID,
         UNIT_NM,
         UNIT_TYP_CD,
         UNIT_TYP_NM,
         UNIT_TYP_TX,
         UNIT_STAT_TX,
         BSNS_ENTY_KEY,
         BSNS_ENTY_NM,
         BLK_START_TX,
         CMRCL_YR_NB,
         CMRCL_YR_MO_NB,
         COMMERCIAL_DT,
         ISO_CD,
         LOAD_TYP_TX,
         FUEL_PRMY_TYP_CD,
         FUEL_PRMY_LABEL_TYP_NM,
         FUEL_PRMY_DESCN_TYP_NM,
         FUEL_SCNDRY_TYP_CD,
         FUEL_SCNDRY_LABEL_TYP_NM,
         FUEL_SCNDRY_DESCN_TYP_NM,
         FUEL_TERTY_TYP_CD,
         FUEL_TERTY_LABEL_TYP_NM,
         FUEL_TERTY_DESCN_TYP_NM,
         FUEL_QTRNRY_TYP_CD,
         FUEL_QTRNRY_LABEL_TYP_NM,
         FUEL_QTRNRY_DESCN_TYP_NM,
         NM_PLATE_CAP_QY,
         PI_TAG_CD,
         SYSTEM_ID,
         SYSTEM_NM,
         CONSOLIDATION_ID,
         CONSOLIDATION_NM,
         CNSLDTN_SYS_NM,
         LAST_UPDT_TS
     )
     SELECT
         SRC.UNIT_KEY,
         SRC.UNIT_ID,
         SRC.UNIT_NM,
         LEFT('NA', 2),
         'NA',
         'NA',
         SRC.UNIT_STAT_TX,
         SRC.BSNS_ENTY_KEY,
         SRC.BSNS_ENTY_NM,
         LEFT('NA', 7),
         CAST(-2 AS NUMBER(5,0)),
         'NA',
         TO_DATE('1900-01-01', 'YYYY-MM-DD'),
         LEFT('NA', 10),
         'NA',
         LEFT('NA', 7),
         'NA',
         'NA',
         LEFT('NA', 7),
         'NA',
         'NA',
         LEFT('NA', 7),
         'NA',
         'NA',
         LEFT('NA', 7),
         'NA',
         'NA',
         'NA',
         LEFT('NA', 20),
         SRC.SYSTEM_ID,
         SRC.SYSTEM_NM,
         SRC.CONSOLIDATION_ID,
         SRC.CONSOLIDATION_NM,
         SRC.CNSLDTN_SYS_NM,
         SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE NOT EXISTS (
         SELECT 1
         FROM {{ source('GENDB01_FELADM','FEL_GNRTN_UNIT_DIM') }} L
         WHERE TRIM(L.UNIT_ID) = SRC.UNIT_ID
           AND L.SYSTEM_ID     = SRC.V_SYS_ID
     )",
        log_model_end(this, 'TBD_FEL_GNRTN_UNIT_DIM', target_object='GENDB01.FELADM.FEL_GNRTN_UNIT_DIM')
    ]
) }}

SELECT
    DQ.UNIT_ID,
    DQ.UNIT_NM,
    DQ.UNIT_STAT_TX,
    CAST(IFF(LKP_FD.BSNS_ENTY_KEY IS NULL, -2, LKP_FD.BSNS_ENTY_KEY) AS NUMBER(10,0))  AS BSNS_ENTY_KEY,
    LEFT(IFF(LKP_FD.BSNS_ENTY_NM IS NULL, 'NOT FOUND', LKP_FD.BSNS_ENTY_NM), 75)       AS BSNS_ENTY_NM,
    CAST(DQ.V_SYS_ID AS NUMBER(5,0))                                                   AS SYSTEM_ID,
    LEFT('COMTRAC', 25)                                                                AS SYSTEM_NM,
    CAST(DQ.O_CONSOLIDATION_ID AS NUMBER(10,0))                                        AS CONSOLIDATION_ID,
    LEFT(IFF(MSTR.CONSOLIDATION_ID IS NULL, DQ.UNIT_NM, MSTR.BUSINESS_NM), 255)        AS CONSOLIDATION_NM,
    LEFT(IFF(MSTR.CONSOLIDATION_ID IS NULL, 'COMTRAC', MSTR.SYSTEM_NM), 25)            AS CNSLDTN_SYS_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)                                         AS LAST_UPDT_TS,
    CAST(DQ.O_GEN_UNIT_KEY AS NUMBER(10,0))                                            AS UNIT_KEY,
    DQ.V_SYS_ID                                                                        AS V_SYS_ID
FROM (
    SELECT
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_ID)))      = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_ID)      END AS UNIT_ID,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_NM)))      = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_NM)      END AS UNIT_NM,
        CASE WHEN LENGTH(LTRIM(RTRIM(SQ.UNIT_STAT_TX))) = 0 THEN ' ' ELSE RTRIM(SQ.UNIT_STAT_TX) END AS UNIT_STAT_TX,
        (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')  AS V_SYS_ID,
        GNU.FCLTY_ID,
        IFF(XRF.CONSOLIDATION_ID IS NOT NULL, XRF.CONSOLIDATION_ID,
            NVL((SELECT MAX(CONSOLIDATION_ID) FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.UNIT_ID))                                 AS O_CONSOLIDATION_ID,
        NVL((SELECT MAX(UNIT_KEY) FROM {{ source('GENDB01_FELADM','FEL_GNRTN_UNIT_DIM') }}), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.UNIT_ID)                                  AS O_GEN_UNIT_KEY
    FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_GNRTN_UNIT_FDR') }} SQ
    LEFT JOIN (
        SELECT FCLTY_ID, UNIT_ID
        FROM {{ source('GENDB01_DEV_SANDBOX_COMMON','AEP_DW_GENUNIT_VW_TEST') }}
        QUALIFY ROW_NUMBER() OVER (PARTITION BY UNIT_ID ORDER BY FCLTY_ID) = 1
    ) GNU
      ON GNU.UNIT_ID = CAST(SQ.UNIT_ID AS NUMBER(8,0))
    LEFT JOIN (
        SELECT xrf.CONSOLIDATION_ID, XRF.DATA_TYP_ID, XRF.SYSTEM_ID,
               UPPER(TRIM(XRF.BUSINESS_ID)) AS BUSINESS_ID
        FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }} xrf
        QUALIFY ROW_NUMBER() OVER (PARTITION BY XRF.DATA_TYP_ID, XRF.SYSTEM_ID, UPPER(TRIM(XRF.BUSINESS_ID))
                                   ORDER BY xrf.CONSOLIDATION_ID) = 1
    ) XRF
      ON XRF.DATA_TYP_ID = (SELECT MIN(DATA_TYPE_ID) FROM {{ source('GENDB01_FELADM','FEL_DATATYPE_DIM') }} WHERE DATA_TYPE_NM = 'GEN_UNIT')
     AND XRF.SYSTEM_ID   = (SELECT MIN(SYS_ID) FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} WHERE SYS_NM = 'COMTRAC')
     AND XRF.BUSINESS_ID = LEFT(UPPER(SQ.UNIT_ID), 20)
    WHERE SQ.LAST_UPDT_TS >= TO_TIMESTAMP_NTZ('2026-09-02 22:30:11', 'YYYY-MM-DD HH24:MI:SS')
      AND 'C' = 'C'
) DQ
LEFT JOIN (
    SELECT BSNS_ENTY_KEY, BSNS_ENTY_NM, FACILITY_ID
    FROM {{ source('GENDB01_FELADM','FEL_FACILITY_DIM') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY FACILITY_ID ORDER BY BSNS_ENTY_KEY) = 1
) LKP_FD
  ON LKP_FD.FACILITY_ID = DQ.FCLTY_ID
LEFT JOIN (
    SELECT XRF.BUSINESS_NM, SYS.SYS_NM AS SYSTEM_NM, XRF.CONSOLIDATION_ID,
           UPPER(XRF.MASTER_FL) AS MASTER_FL
    FROM {{ source('GENDB01_FELADM','FEL_MASTER_DIM_XRF') }} XRF
    INNER JOIN {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }} SYS
      ON SYS.SYS_ID = XRF.SYSTEM_ID
    QUALIFY ROW_NUMBER() OVER (PARTITION BY XRF.CONSOLIDATION_ID, UPPER(XRF.MASTER_FL)
                               ORDER BY XRF.BUSINESS_NM, SYS.SYS_NM) = 1
) MSTR
  ON MSTR.CONSOLIDATION_ID = DQ.O_CONSOLIDATION_ID
 AND MSTR.MASTER_FL        = 'Y'
