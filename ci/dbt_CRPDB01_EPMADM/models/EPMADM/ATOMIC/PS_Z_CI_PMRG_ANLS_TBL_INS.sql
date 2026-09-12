-- ==========================================================================
-- Model      : PS_Z_CI_PMRG_ANLS_TBL_INS
-- Mapping    : m_ps_z_ci_pmrg_anls_tbl_ins
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Session    : s_m_ps_z_ci_pmrg_anls_tbl_ins
-- Source SQL : ci/s_m_ps_z_pmrg_anls_tbl_ins.sql, lines 16-73 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_PMRG_ANLS_TBL
-- Load type  : table + MERGE post-hook
-- --------------------------------------------------------------------------
-- Update-else-insert through the mapping's router: the source rows are
-- left-joined to a lookup on the target's key, ROUTER_ACTION is UPDATE when
-- the key exists and INSERT when it does not, and the MERGE acts on it. The
-- lookup is the target itself on the MERGE's own keys, so this matches on
-- exactly those keys.
--
-- The model is the MERGE's USING subquery - lookup included, so its snapshot
-- of the target is taken as the model materialises, immediately before the
-- MERGE - and the post-hook is the MERGE itself, reading the model.
--
-- Source: the script reads PS_Z_PMRG_ANLS_TBL twice - as the mapping's source and as the
-- router's lookup on the target - and names EPMADM both times. The lookup
-- is the EPMADM target; the source is the PeopleSoft PS_Z_PMRG_ANLS_TBL, read through
-- CI_PSFT_SOURCE. As written the MERGE would read its own target and bring in
-- nothing new, so assert_psft_source stops compilation until CI_PSFT_SOURCE
-- points somewhere else.
-- ==========================================================================

{{ assert_psft_source(source('CI_PSFT_SOURCE', 'PS_Z_PMRG_ANLS_TBL'), source('CRPDB01_EPMADM', 'PS_Z_PMRG_ANLS_TBL')) }}

{{ config(
    materialized='table',
    alias='PS_Z_CI_PMRG_ANLS_TBL_INS_SRC',
    meta={"mapping_name": "m_ps_z_ci_pmrg_anls_tbl_ins", "workflow_name": "wkf_LOAD_CI_ATOMIC", "session_name": "s_m_ps_z_ci_pmrg_anls_tbl_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CI_PMRG_ANLS_TBL_INS', target_object='CRPDB01.EPMADM.PS_Z_PMRG_ANLS_TBL')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_PMRG_ANLS_TBL') }} t
     USING {{ this }} s
     ON t.BUSINESS_UNIT = s.BUSINESS_UNIT AND
         t.PROJECT_ID = s.PROJECT_ID AND
         t.REVISION_NUMBER = s.REVISION_NUMBER AND
         t.Z_LOB = s.Z_LOB
     AND s.ROUTER_ACTION = 'UPDATE'
     WHEN MATCHED THEN UPDATE SET
         Z_CI_IRR_SCORE = s.Z_CI_IRR_SCORE,
         Z_CI_NPV = s.Z_CI_NPV,
         Z_CI_PAYBACK_SCORE = s.Z_CI_PAYBACK_SCORE,
         DISCOUNT = s.DISCOUNT,
         ADDTL_ADJUST_PCT = s.ADDTL_ADJUST_PCT,
         ADDTL_WTHD_PCT = s.ADDTL_WTHD_PCT,
         ADJUSTMENT_PCT = s.ADJUSTMENT_PCT,
         Z_COST_RED = s.Z_COST_RED,
         EDW_LAST_UPDT_TS = s.EDW_LAST_UPDT_TS
     WHEN NOT MATCHED AND s.ROUTER_ACTION = 'INSERT' THEN INSERT (BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER, Z_LOB, Z_CI_IRR_SCORE, Z_CI_NPV, Z_CI_PAYBACK_SCORE, DISCOUNT, ADDTL_ADJUST_PCT, ADDTL_WTHD_PCT, ADJUSTMENT_PCT, Z_COST_RED, EDW_LAST_UPDT_TS)
     VALUES (s.BUSINESS_UNIT, s.PROJECT_ID, s.REVISION_NUMBER, s.Z_LOB, s.Z_CI_IRR_SCORE, s.Z_CI_NPV, s.Z_CI_PAYBACK_SCORE, s.DISCOUNT, s.ADDTL_ADJUST_PCT, s.ADDTL_WTHD_PCT, s.ADJUSTMENT_PCT, s.Z_COST_RED, s.EDW_LAST_UPDT_TS)",
        log_model_end(this, 'TBD_PS_Z_CI_PMRG_ANLS_TBL_INS', target_object='CRPDB01.EPMADM.PS_Z_PMRG_ANLS_TBL')
    ]
) }}

SELECT
    exp.*,
    lkp.BUSINESS_UNIT AS LKP_BUSINESS_UNIT,
    IFF(lkp.BUSINESS_UNIT IS NULL, 'INSERT', 'UPDATE') AS ROUTER_ACTION
FROM (
SELECT
    RTRIM(src.BUSINESS_UNIT) AS BUSINESS_UNIT,
    RTRIM(src.PROJECT_ID) AS PROJECT_ID,
    src.REVISION_NUMBER AS REVISION_NUMBER,
    RTRIM(src.Z_LOB) AS Z_LOB,
    src.Z_CI_IRR_SCORE AS Z_CI_IRR_SCORE,
    src.Z_CI_NPV AS Z_CI_NPV,
    src.Z_CI_PAYBACK_SCORE AS Z_CI_PAYBACK_SCORE,
    src.DISCOUNT AS DISCOUNT,
    src.ADDTL_ADJUST_PCT AS ADDTL_ADJUST_PCT,
    src.ADDTL_WTHD_PCT AS ADDTL_WTHD_PCT,
    src.ADJUSTMENT_PCT AS ADJUSTMENT_PCT,
    src.Z_COST_RED AS Z_COST_RED,
    CURRENT_TIMESTAMP() AS EDW_LAST_UPDT_TS
FROM {{ source('CI_PSFT_SOURCE','PS_Z_PMRG_ANLS_TBL') }} src
) exp
LEFT JOIN (
    SELECT
        BUSINESS_UNIT,
        PROJECT_ID,
        REVISION_NUMBER,
        Z_LOB
    FROM {{ source('CRPDB01_EPMADM','PS_Z_PMRG_ANLS_TBL') }}
    GROUP BY
        BUSINESS_UNIT,
        PROJECT_ID,
        REVISION_NUMBER,
        Z_LOB
) lkp
    ON lkp.BUSINESS_UNIT = exp.BUSINESS_UNIT AND
       lkp.PROJECT_ID = exp.PROJECT_ID AND
       lkp.REVISION_NUMBER = exp.REVISION_NUMBER AND
       lkp.Z_LOB = exp.Z_LOB
