-- ==========================================================================
-- Where the PeopleSoft objects this project reads actually are.
-- Run it in Snowflake as the role dbt runs with; it only reads metadata.
--
-- Results of queries 1-4, 2026-09-12 (the full output is in git history,
-- commit 18470f1):
--   1. 7 of the 14 exist, all BASE TABLE, stored in lower case in schema
--      "bronze_peoplesoft": ps_z_ci_gen_stat, ps_z_cpp_gen_stat,
--      ps_z_ir_detail_tbl, ps_z_job_control, ps_z_jtp_relate_ci,
--      ps_z_pmrg_anls_tbl, ps_z_pmrg_cpp_tbl. None of the 7 views exists:
--      PS_Z_CI_CHG_LOG_VW, PS_Z_CPP_CH_LOG_VW, PS_Z_CI_REV_DTLVW,
--      PS_Z_CI_DTL_VW, PS_Z_CPP_DTL_VW, PS_Z_PDS_CI_VW, PS_Z_PDS_CPP_VW.
--   2. every column of those 7 tables is lower case (ci_gen_stat 47,
--      cpp_gen_stat 46, ir_detail_tbl 78, job_control 13, jtp_relate_ci 19,
--      pmrg_anls_tbl 20, pmrg_cpp_tbl 19). Snowflake resolves unquoted names
--      to them, so the models need no quoting.
--   3. all 210 bronze objects are unmanaged Iceberg tables (catalog
--      GLUE_REST_BRONZE); no views.
--   4. PS_Z_JOB_CONTROL_CI not found. The ci/f.txt run that followed created
--      it (its on-run-start INSERT into the table succeeded), so run 4 again.
--
-- Queries 5 and 6 are new: whether the 7 views exist anywhere this role can
-- see, and whether PeopleSoft's own view definitions were replicated.
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

-- 3. which are Iceberg tables
SHOW ICEBERG TABLES IN SCHEMA BRONZE_CORP_CONF.BRONZE_PEOPLESOFT;

-- 4. the job-control copy on-run-start creates
SHOW TABLES LIKE 'PS_Z_JOB_CONTROL_CI' IN SCHEMA CRPDB01_DEV_SANDBOX.EPMADM;
SELECT COUNT(*) AS job_control_rows FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_JOB_CONTROL_CI;

-- 5. the 7 views, anywhere in the account this role can see. Matches
--    PS_Z_*VW, so PS_Z_CI_REV_DTLVW is included.
SHOW OBJECTS LIKE 'PS_Z_%VW' IN ACCOUNT;

-- 6. PeopleSoft keeps each view's SQL in PeopleTools table PSSQLTEXTDEFN
--    (SQLTYPE '2', SQLID = record name without PS_, e.g. Z_CI_DTL_VW). If it
--    was replicated anywhere, the view definitions can be read from it.
--    Bronze has PeopleTools tables PSTREE* and PSXLAT*, but not this one.
SHOW OBJECTS LIKE 'PSSQLTEXTDEFN' IN ACCOUNT;
