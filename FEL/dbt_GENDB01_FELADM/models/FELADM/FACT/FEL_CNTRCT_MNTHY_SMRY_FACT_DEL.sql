-- ==========================================================================
-- Model      : FEL_CNTRCT_MNTHY_SMRY_FACT_DEL
-- Mapping    : m_FEL_CNTRCT_MNTHY_SMRY_FACT_del
-- Workflow   : wkf_FEL_COAL_DIM_FACT_DEL
-- Session    : s_m_FEL_CNTRCT_MNTHY_SMRY_FACT_del
-- Target     : feladm.FEL_CNTRCT_MNTHY_SMRY_FACT
-- Load type  : table + DELETE post-hook
-- --------------------------------------------------------------------------
-- DELETE only, and the one mapping in this workflow that joins rather than
-- looks up. The obligation feeder is turned into the fact's three part key
-- through four unconnected lookups, JNRTRANS full outer joins that key set
-- against the fact, FIL_INACTIVE keeps the fact rows with no matching
-- feeder key, and UPD_DELETE issues DD_DELETE.
--
-- The model holds the key of every target row the mapping deletes, one
-- row per target row, and the post-hook removes exactly those rows. The
-- original predicate reads the target only through CNTRCT_PROD_KEY, GEOG_FCLTY_KEY, OPRTG_MO_DAY_ID,
-- so selecting those keys and deleting on them is the same set as the
-- correlated DELETE. EQUAL_NULL keeps a NULL key matching, as before.
--
-- Materialised as a table, not a view, so the key set is snapshotted
-- before the DELETE runs and RECORDS_PROCESSED can count it afterwards.
-- Duplicate keys are kept rather than DISTINCT-ed so the count is the
-- exact number of rows removed; DELETE ... USING removes a target row
-- once however many times it matches.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='FEL_CNTRCT_MNTHY_SMRY_FACT_DEL_SRC',
    meta={"mapping_name": "m_FEL_CNTRCT_MNTHY_SMRY_FACT_del", "workflow_name": "wkf_FEL_COAL_DIM_FACT_DEL", "session_name": "s_m_FEL_CNTRCT_MNTHY_SMRY_FACT_del"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_CNTRCT_MNTHY_SMRY_FACT_DEL', target_object='GENDB01.FELADM.FEL_CNTRCT_MNTHY_SMRY_FACT')
    ],
    post_hook=[
        "DELETE FROM {{ source('GENDB01_FELADM','FEL_CNTRCT_MNTHY_SMRY_FACT') }} TGT
     USING {{ this }} D
     WHERE EQUAL_NULL(TGT.CNTRCT_PROD_KEY, D.CNTRCT_PROD_KEY)
       AND EQUAL_NULL(TGT.GEOG_FCLTY_KEY, D.GEOG_FCLTY_KEY)
       AND EQUAL_NULL(TGT.OPRTG_MO_DAY_ID, D.OPRTG_MO_DAY_ID)",
        log_model_end(this, 'TBD_FEL_CNTRCT_MNTHY_SMRY_FACT_DEL', target_object='GENDB01.FELADM.FEL_CNTRCT_MNTHY_SMRY_FACT')
    ]
) }}

SELECT
    TGT.CNTRCT_PROD_KEY,
    TGT.GEOG_FCLTY_KEY,
    TGT.OPRTG_MO_DAY_ID
FROM {{ source('GENDB01_FELADM','FEL_CNTRCT_MNTHY_SMRY_FACT') }} TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            PD.CNTRCT_PROD_KEY   AS CNTRCT_PROD_KEY,
            FD.FACILITY_KEY      AS GEOG_FCLTY_KEY,
            OM.OPTD_MO_DAY_ID    AS OPTG_MO_DAY_ID
        FROM {{ source('GENDB01_FELADM','FEL_COMTRAC_CNTRCT_OBLGN_FDR') }} SQ
        LEFT JOIN (
            SELECT CNTRCT_DTL_ID, CNTRCT_PROD_KEY
            FROM {{ source('GENDB01_FELADM','FEL_CNTRCT_PROD_CD_DIM') }}
            QUALIFY ROW_NUMBER() OVER (PARTITION BY CNTRCT_DTL_ID ORDER BY CNTRCT_DTL_ID) = 1
        ) PD
          ON PD.CNTRCT_DTL_ID = SQ.CNTRCT_DTL_ID
        LEFT JOIN (
            SELECT
                DIM.FACILITY_KEY                  AS FACILITY_KEY,
                TRIM(UPPER(DIM.FACILITY_ID))      AS FACILITY_ID,
                DIM.SYSTEM_ID                     AS SYSTEM_ID
            FROM {{ source('GENDB01_FELADM','FEL_FACILITY_DIM') }} DIM
            QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID
                                       ORDER BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID, DIM.FACILITY_KEY) = 1
        ) FD
          ON FD.FACILITY_ID = UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.FACILITY_ID) END)
         AND FD.SYSTEM_ID   = (
                SELECT SYS_ID
                FROM {{ source('GENDB01_FELADM','FEL_SYSTEM_DIM') }}
                WHERE SYS_NM = 'COMTRAC'
                QUALIFY ROW_NUMBER() OVER (ORDER BY SYS_NM) = 1
             )
        LEFT JOIN (
            SELECT OPTD_MO_DAY_ID, MONTH_NB, OPERATING_YEAR
            FROM {{ source('GENDB01_FELADM','FEL_OPTG_MONTH_VW') }}
            QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, OPERATING_YEAR
                                       ORDER BY MONTH_NB, OPERATING_YEAR) = 1
        ) OM
          ON OM.MONTH_NB       = MONTH(SQ.CNTRCT_DTL_OPRTG_DT)
         AND OM.OPERATING_YEAR = YEAR(SQ.CNTRCT_DTL_OPRTG_DT)
    ) FDR
    WHERE FDR.CNTRCT_PROD_KEY = TGT.CNTRCT_PROD_KEY
      AND FDR.GEOG_FCLTY_KEY  = TGT.GEOG_FCLTY_KEY
      AND FDR.OPTG_MO_DAY_ID  = TGT.OPRTG_MO_DAY_ID
)
