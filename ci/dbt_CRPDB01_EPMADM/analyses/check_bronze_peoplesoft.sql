-- ==========================================================================
-- Diagnostic for the 2026-09-12 run in CRPDB01_DEV_SANDBOX (ci/f.txt).
-- Run it in Snowflake as the dbt role; it only reads metadata.
--
-- It answers what the run could not:
--   1. which of the 14 PeopleSoft objects exist in bronze, and under what exact
--      (possibly lower-case) name - Snowflake reports a lower-case name and a
--      missing one with the same "does not exist" error;
--   2. which have column names that are not upper case and so need quoting;
--   3. which are Iceberg tables (the GEN_STAT loads failed on
--      "Equality deletes on Iceberg tables are not supported");
--   4. whether on-run-start created PS_Z_JOB_CONTROL_CI.
-- ==========================================================================

-- 1. existence and exact stored name
SELECT t.table_schema, t.table_name, t.table_type
FROM BRONZE_CORP_CONF.INFORMATION_SCHEMA.TABLES t
WHERE t.table_schema ILIKE 'BRONZE_PEOPLESOFT'
  AND t.table_name ILIKE ANY (
      'PS_Z_JOB_CONTROL', 'PS_Z_CI_CHG_LOG_VW', 'PS_Z_CPP_CH_LOG_VW', 'PS_Z_CI_REV_DTLVW',
      'PS_Z_JTP_RELATE_CI', 'PS_Z_CI_DTL_VW', 'PS_Z_CPP_DTL_VW', 'PS_Z_PDS_CI_VW',
      'PS_Z_PDS_CPP_VW', 'PS_Z_IR_DETAIL_TBL', 'PS_Z_PMRG_ANLS_TBL', 'PS_Z_PMRG_CPP_TBL',
      'PS_Z_CI_GEN_STAT', 'PS_Z_CPP_GEN_STAT')
ORDER BY t.table_name;

-- 2. column-name case per object
SELECT c.table_name,
       COUNT(*)                                          AS columns,
       COUNT_IF(c.column_name <> UPPER(c.column_name))   AS columns_not_upper_case
FROM BRONZE_CORP_CONF.INFORMATION_SCHEMA.COLUMNS c
WHERE c.table_schema ILIKE 'BRONZE_PEOPLESOFT'
  AND c.table_name ILIKE ANY (
      'PS_Z_JOB_CONTROL', 'PS_Z_CI_CHG_LOG_VW', 'PS_Z_CPP_CH_LOG_VW', 'PS_Z_CI_REV_DTLVW',
      'PS_Z_JTP_RELATE_CI', 'PS_Z_CI_DTL_VW', 'PS_Z_CPP_DTL_VW', 'PS_Z_PDS_CI_VW',
      'PS_Z_PDS_CPP_VW', 'PS_Z_IR_DETAIL_TBL', 'PS_Z_PMRG_ANLS_TBL', 'PS_Z_PMRG_CPP_TBL',
      'PS_Z_CI_GEN_STAT', 'PS_Z_CPP_GEN_STAT')
GROUP BY c.table_name
ORDER BY c.table_name;

-- 3. which bronze tables are Iceberg
SHOW ICEBERG TABLES IN SCHEMA BRONZE_CORP_CONF.BRONZE_PEOPLESOFT;

-- 4. did on-run-start create the job-control copy?
SHOW TABLES LIKE 'PS_Z_JOB_CONTROL_CI' IN SCHEMA CRPDB01_DEV_SANDBOX.EPMADM;
