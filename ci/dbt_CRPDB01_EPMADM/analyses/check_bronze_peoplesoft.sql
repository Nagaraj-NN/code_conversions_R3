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
TABLE_SCHEMA	TABLE_NAME	TABLE_TYPE
bronze_peoplesoft	ps_z_ci_gen_stat	BASE TABLE
bronze_peoplesoft	ps_z_cpp_gen_stat	BASE TABLE
bronze_peoplesoft	ps_z_ir_detail_tbl	BASE TABLE
bronze_peoplesoft	ps_z_job_control	BASE TABLE
bronze_peoplesoft	ps_z_jtp_relate_ci	BASE TABLE
bronze_peoplesoft	ps_z_pmrg_anls_tbl	BASE TABLE
bronze_peoplesoft	ps_z_pmrg_cpp_tbl	BASE TABLE
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

TABLE_NAME	COLUMNS	COLUMNS_NOT_UPPER_CASE
ps_z_ci_gen_stat	47	47
ps_z_cpp_gen_stat	46	46
ps_z_ir_detail_tbl	78	78
ps_z_job_control	13	13
ps_z_jtp_relate_ci	19	19
ps_z_pmrg_anls_tbl	20	20
ps_z_pmrg_cpp_tbl	19	19

-- 3. which bronze tables are Iceberg
SHOW ICEBERG TABLES IN SCHEMA BRONZE_CORP_CONF.BRONZE_PEOPLESOFT;
created_on	name	database_name	schema_name	owner	external_volume_name	catalog_name	iceberg_table_type	catalog_table_name	catalog_namespace	base_location	can_write_metadata	comment	owner_role_type	name_mapping	catalog_sync_name	auto_refresh_status	partition_specs	current_partition_spec_id	iceberg_table_format_version
2026-09-10 03:00:27.349 -0700	ogg_test_table	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ogg_test_table	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.376 -0700	ps_alloc_amt_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_amt_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.374 -0700	ps_alloc_basf_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_basf_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.391 -0700	ps_alloc_basv_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_basv_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.356 -0700	ps_alloc_group_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_group_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.342 -0700	ps_alloc_grstp_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_grstp_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.352 -0700	ps_alloc_offv_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_offv_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.436 -0700	ps_alloc_poolf_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_poolf_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.379 -0700	ps_alloc_poolv_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_poolv_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.380 -0700	ps_alloc_step_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_step_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.346 -0700	ps_alloc_targv_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_alloc_targv_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.391 -0700	ps_bank_acct_defn	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bank_acct_defn	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.417 -0700	ps_bank_cd_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bank_cd_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.374 -0700	ps_bi_acct_entry	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_acct_entry	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.418 -0700	ps_bi_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.426 -0700	ps_bi_hdr_ar	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_hdr_ar	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.380 -0700	ps_bi_hdr_note	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_hdr_note	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.376 -0700	ps_bi_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.407 -0700	ps_bi_line_dst	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_line_dst	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.404 -0700	ps_bi_line_note	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_line_note	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.370 -0700	ps_bi_line_tax	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bi_line_tax	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.404 -0700	ps_bus_unit_tbl_ap	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bus_unit_tbl_ap	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.380 -0700	ps_bus_unit_tbl_bi	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bus_unit_tbl_bi	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.065 -0700	ps_bus_unit_tbl_fs	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bus_unit_tbl_fs	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.380 -0700	ps_bus_unit_tbl_gl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bus_unit_tbl_gl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.382 -0700	ps_bus_unit_tbl_pc	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_bus_unit_tbl_pc	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.412 -0700	ps_cash_flow_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_cash_flow_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.406 -0700	ps_customer	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_customer	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.409 -0700	ps_dept_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_dept_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.041 -0700	ps_distrib_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_distrib_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.225 -0700	ps_ex_exp_mthd_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_exp_mthd_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.192 -0700	ps_ex_purpose_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_purpose_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.992 -0700	ps_ex_sheet_dist	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_sheet_dist	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.475 -0700	ps_ex_sheet_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_sheet_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.195 -0700	ps_ex_sheet_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_sheet_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.672 -0700	ps_ex_trans	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_trans	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.865 -0700	ps_ex_types_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ex_types_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.147 -0700	ps_fclty_dfn	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_fclty_dfn	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.027 -0700	ps_fclty_memo	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_fclty_memo	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.239 -0700	ps_gl_account_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_gl_account_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.478 -0700	ps_hr_acctg_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_hr_acctg_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.034 -0700	ps_installation_ap	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_installation_ap	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.076 -0700	ps_instr_header_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_instr_header_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.052 -0700	ps_item	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_item	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.054 -0700	ps_item_activity	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_item_activity	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.109 -0700	ps_item_dst	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_item_dst	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.867 -0700	ps_jrnl_header	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_jrnl_header	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.076 -0700	ps_jrnl_ln	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_jrnl_ln	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.175 -0700	ps_lc_amend	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_lc_amend	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.091 -0700	ps_lc_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_lc_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.985 -0700	ps_lc_status	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_lc_status	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.072 -0700	ps_ledger	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ledger	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.048 -0700	ps_ledger_budg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ledger_budg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.389 -0700	ps_ledger_proj	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ledger_proj	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.682 -0700	ps_oper_unit_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_oper_unit_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.512 -0700	ps_payment	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_payment	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.680 -0700	ps_payment_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_payment_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.862 -0700	ps_pc_jobcode_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_pc_jobcode_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:32.878 -0700	ps_personal_data	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_personal_data	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.071 -0700	ps_po_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_po_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.658 -0700	ps_po_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_po_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.890 -0700	ps_po_line_distrib	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_po_line_distrib	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.431 -0700	ps_po_line_ship	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_po_line_ship	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.425 -0700	ps_primary_jobs	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_primary_jobs	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.894 -0700	ps_product_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_product_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:54.054 -0700	ps_proj_act_descr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_act_descr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.910 -0700	ps_proj_act_loc	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_act_loc	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.407 -0700	ps_proj_act_status	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_act_status	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.536 -0700	ps_proj_act_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_act_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:47.767 -0700	ps_proj_activity	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_activity	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.979 -0700	ps_proj_an_grp_map	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_an_grp_map	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.562 -0700	ps_proj_an_grp_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_an_grp_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.895 -0700	ps_proj_antype_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_antype_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.042 -0700	ps_proj_catg_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_catg_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.930 -0700	ps_proj_location	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_location	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.989 -0700	ps_proj_res_type	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_res_type	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.980 -0700	ps_proj_resource	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_resource	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.893 -0700	ps_proj_status_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_status_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.409 -0700	ps_proj_subcat_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_subcat_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.899 -0700	ps_proj_type_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_proj_type_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.989 -0700	ps_project	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_project	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:49.640 -0700	ps_project_mgr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_project_mgr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.890 -0700	ps_project_status	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_project_status	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.967 -0700	ps_pymnt_vchr_xref	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_pymnt_vchr_xref	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:53.056 -0700	ps_pymt_trms_dscnt	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_pymt_trms_dscnt	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.972 -0700	ps_pymt_trms_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_pymt_trms_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.610 -0700	ps_pymt_trms_net	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_pymt_trms_net	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.980 -0700	ps_rt_rate_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_rt_rate_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:46.462 -0700	ps_source_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_source_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.407 -0700	ps_stat_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_stat_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:48.182 -0700	ps_tree_node_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_tree_node_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.515 -0700	ps_trx_detail_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_trx_detail_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.980 -0700	ps_trx_header_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_trx_header_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:27.987 -0700	ps_trx_interest_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_trx_interest_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:53.572 -0700	ps_trx_portflio_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_trx_portflio_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:52.600 -0700	ps_trx_position_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_trx_position_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:56.074 -0700	ps_tse_misc_fld	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_tse_misc_fld	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.467 -0700	ps_tse_pymnt_fld	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_tse_pymnt_fld	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.423 -0700	ps_tse_vchr_fld	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_tse_vchr_fld	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.419 -0700	ps_tse_vchrln_fld	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_tse_vchrln_fld	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.450 -0700	ps_vchr_acctg_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_vchr_acctg_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:44.272 -0700	ps_vendor	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_vendor	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:48.654 -0700	ps_vendor_addr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_vendor_addr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.893 -0700	ps_vendor_cntct	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_vendor_cntct	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.447 -0700	ps_vndr_addr_scrol	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_vndr_addr_scrol	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:57.051 -0700	ps_voucher	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_voucher	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.394 -0700	ps_voucher_line	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_voucher_line	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:48.647 -0700	ps_z_analysis_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_analysis_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.895 -0700	ps_z_ap_fldgls_stg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ap_fldgls_stg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:52.546 -0700	ps_z_ap_inv_hist	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ap_inv_hist	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.926 -0700	ps_z_ap_uvl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ap_uvl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.491 -0700	ps_z_ariba_inv_upd	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ariba_inv_upd	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:54.059 -0700	ps_z_bd_prj_catg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bd_prj_catg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.481 -0700	ps_z_bd_prj_class	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bd_prj_class	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.459 -0700	ps_z_bd_prj_tree	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bd_prj_tree	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.406 -0700	ps_z_bd_treeexp_ld	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bd_treeexp_ld	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:46.500 -0700	ps_z_ben_bu_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ben_bu_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.436 -0700	ps_z_benefit_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_benefit_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:46.519 -0700	ps_z_bill_target	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bill_target	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.908 -0700	ps_z_bldtel_basis	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_bldtel_basis	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:49.604 -0700	ps_z_cash_flow_trg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cash_flow_trg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.894 -0700	ps_z_ci_chng_log	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_chng_log	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.454 -0700	ps_z_ci_fndtyp_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_fndtyp_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.889 -0700	ps_z_ci_gen_stat	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_gen_stat	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.884 -0700	ps_z_ci_juris_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_juris_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.898 -0700	ps_z_ci_juris_sub	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_juris_sub	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:52.548 -0700	ps_z_ci_maj_loc	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_maj_loc	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.893 -0700	ps_z_ci_rev_dtl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_rev_dtl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.899 -0700	ps_z_ci_revision	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ci_revision	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.918 -0700	ps_z_cili_ikw_asst	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cili_ikw_asst	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.038 -0700	ps_z_cpp_chng_log	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_chng_log	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.887 -0700	ps_z_cpp_gen_stat	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_gen_stat	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.895 -0700	ps_z_cpp_header	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_header	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.930 -0700	ps_z_cpp_ir_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_ir_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:40.899 -0700	ps_z_cpp_rev_dtl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_rev_dtl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.391 -0700	ps_z_cpp_revision	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_cpp_revision	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.629 -0700	ps_z_dept_dim	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_dept_dim	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.439 -0700	ps_z_dscnt_pro	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_dscnt_pro	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:47.739 -0700	ps_z_employee	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_employee	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.903 -0700	ps_z_ex_mc_tbl5010	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ex_mc_tbl5010	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.903 -0700	ps_z_fltact_report	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_fltact_report	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:44.273 -0700	ps_z_fltclr_nonlbr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_fltclr_nonlbr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.424 -0700	ps_z_genbu_clrper	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_genbu_clrper	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.438 -0700	ps_z_gl_acct_dim	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_gl_acct_dim	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.907 -0700	ps_z_gl_all_lkup	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_gl_all_lkup	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.474 -0700	ps_z_glact_report	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_glact_report	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:49.600 -0700	ps_z_grand_parent	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_grand_parent	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.464 -0700	ps_z_guarantee_dtl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_guarantee_dtl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.587 -0700	ps_z_guarantee_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_guarantee_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.475 -0700	ps_z_hr_ln_2002	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_hr_ln_2002	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.931 -0700	ps_z_hr_ln_2003	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_hr_ln_2003	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:53.644 -0700	ps_z_hr_ln_2004	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_hr_ln_2004	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.526 -0700	ps_z_hr_ln_2005	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_hr_ln_2005	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.100 -0700	ps_z_icboh_rates	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_icboh_rates	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.960 -0700	ps_z_imx_distrib	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_imx_distrib	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:38.891 -0700	ps_z_ir_detail_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ir_detail_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.404 -0700	ps_z_job_control	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_job_control	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.040 -0700	ps_z_jrnl_hd_trg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_jrnl_hd_trg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:46.477 -0700	ps_z_jrnl_ln_trg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_jrnl_ln_trg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.105 -0700	ps_z_jtp_relate_ci	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_jtp_relate_ci	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:33.401 -0700	ps_z_ld_ur_basis	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_ld_ur_basis	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.783 -0700	ps_z_metering	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_metering	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.081 -0700	ps_z_mtch_exc_hist	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_mtch_exc_hist	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.288 -0700	ps_z_numberlist	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_numberlist	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.772 -0700	ps_z_oec_prj	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_oec_prj	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.799 -0700	ps_z_pmrg_anls_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_pmrg_anls_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.901 -0700	ps_z_pmrg_cpp_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_pmrg_cpp_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.274 -0700	ps_z_pr_pb_log	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_pr_pb_log	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.275 -0700	ps_z_prj_driver	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_prj_driver	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:50.306 -0700	ps_z_prj_offsetgrp	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_prj_offsetgrp	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.186 -0700	ps_z_prjact_report	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_prjact_report	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:52.274 -0700	ps_z_proj_act_addl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_proj_act_addl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.785 -0700	ps_z_proj_deletes	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_proj_deletes	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.779 -0700	ps_z_project	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_project	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.804 -0700	ps_z_psexp_load	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_psexp_load	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.801 -0700	ps_z_pymt_xref_trg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_pymt_xref_trg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.800 -0700	ps_z_rfp_rqst_att	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_rfp_rqst_att	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:40.824 -0700	ps_z_rfp_rqst_dst	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_rfp_rqst_dst	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.868 -0700	ps_z_rfp_rqst_hdr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_rfp_rqst_hdr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.191 -0700	ps_z_risk_matrix	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_risk_matrix	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.796 -0700	ps_z_scb_dept_grp	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_scb_dept_grp	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.273 -0700	ps_z_scbact_report	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_scbact_report	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.810 -0700	ps_z_scp_ocp_map	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_scp_ocp_map	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.777 -0700	ps_z_sec_dept	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sec_dept	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:40.805 -0700	ps_z_sec_glbu	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sec_glbu	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.909 -0700	ps_z_sec_object	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sec_object	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.280 -0700	ps_z_sec_summary	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sec_summary	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.077 -0700	ps_z_seg_cons_dim	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_seg_cons_dim	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.799 -0700	ps_z_sss_basis	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sss_basis	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.799 -0700	ps_z_sum_dtl_prj	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_sum_dtl_prj	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.780 -0700	ps_z_td_detail	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_td_detail	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:46.778 -0700	ps_z_telecom	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_telecom	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.793 -0700	ps_z_tr_biltrl_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_tr_biltrl_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.082 -0700	ps_z_tr_bu_setup	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_tr_bu_setup	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.887 -0700	ps_z_tr_std_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_tr_std_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.273 -0700	ps_z_trans_add_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_trans_add_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.284 -0700	ps_z_trx_detail_tr	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_trx_detail_tr	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:55.202 -0700	ps_z_trx_intrst_tg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_trx_intrst_tg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.906 -0700	ps_z_val_audit	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_val_audit	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:43.780 -0700	ps_z_vchr_acct_trg	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_vchr_acct_trg	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.888 -0700	ps_z_vchr_apr_hist	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_vchr_apr_hist	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:40.809 -0700	ps_z_vchr_doc	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_vchr_doc	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.287 -0700	ps_z_vealloc_tbl	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_z_vealloc_tbl	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:40.820 -0700	ps_ztr_bnk_bal_all	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	ps_ztr_bnk_bal_all	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.797 -0700	pstreedefn	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	pstreedefn	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:42.790 -0700	pstreeleaf	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	pstreeleaf	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:41.787 -0700	pstreenode	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	pstreenode	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.889 -0700	psxlatdefn	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	psxlatdefn	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 03:00:39.900 -0700	psxlatitem	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	psxlatitem	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2
2026-09-10 15:01:59.281 -0700	tst_ps_z_ariba_inv_upd	BRONZE_CORP_CONF	bronze_peoplesoft	DP_DW_IT_TRANSFORMER	BRONZE_EXTERNAL_VOLUME_CONFIDENTIAL_CORP	GLUE_REST_BRONZE	UNMANAGED	tst_ps_z_ariba_inv_upd	bronze_peoplesoft		Y		ROLE				[ {
  "spec-id" : 0,
  "fields" : [ ]
} ]	0	2

-- 4. did on-run-start create the job-control copy?
SHOW TABLES LIKE 'PS_Z_JOB_CONTROL_CI' IN SCHEMA CRPDB01_DEV_SANDBOX.EPMADM;
Query produced no results
