-- ==========================================================================
-- Model      : PS_Z_PMRG_CPP_TBL_INS
-- Mapping    : m_ps_z_pmrg_cpp_tbl_ins
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Session    : s_m_ps_z_pmrg_cpp_tbl_ins
-- Source SQL : ci/s_m_ps_z_pmrg_cpp_tbl_ins.sql, lines 18-150 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_PMRG_CPP_TBL
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
-- Source: the script reads PS_Z_PMRG_CPP_TBL twice - as the mapping's source and as the
-- router's lookup on the target - and names EPMADM both times. The lookup
-- is the EPMADM target; the source is the PeopleSoft PS_Z_PMRG_CPP_TBL, read through
-- CI_PSFT_SOURCE. As written the MERGE would read its own target and bring in
-- nothing new, so assert_psft_source stops compilation until CI_PSFT_SOURCE
-- points somewhere else.
-- ==========================================================================

{{ assert_psft_source(source('CI_PSFT_SOURCE', 'PS_Z_PMRG_CPP_TBL'), source('CRPDB01_EPMADM', 'PS_Z_PMRG_CPP_TBL')) }}

{{ config(
    materialized='table',
    alias='PS_Z_PMRG_CPP_TBL_INS_SRC',
    meta={"mapping_name": "m_ps_z_pmrg_cpp_tbl_ins", "workflow_name": "wkf_LOAD_CI_ATOMIC", "session_name": "s_m_ps_z_pmrg_cpp_tbl_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_PMRG_CPP_TBL_INS', target_object=target.database ~ '.EPMADM.PS_Z_PMRG_CPP_TBL')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_PMRG_CPP_TBL') }} t
     USING {{ this }} s
     ON t.Z_CPP_ID = s.Z_CPP_ID
     AND t.REVISION_NUMBER = s.REVISION_NUMBER
     AND t.Z_LOB = s.Z_LOB
     AND s.ROUTER_ACTION = 'UPDATE'
     WHEN MATCHED THEN
         UPDATE SET
             Z_CI_IRR_SCORE = s.Z_CI_IRR_SCORE,
             Z_CI_NPV = s.Z_CI_NPV,
             Z_CI_PAYBACK_SCORE = s.Z_CI_PAYBACK_SCORE,
             DISCOUNT = s.DISCOUNT,
             ADDTL_ADJUST_PCT = s.ADDTL_ADJUST_PCT,
             ADDTL_WTHD_PCT = s.ADDTL_WTHD_PCT,
             ADJUSTMENT_PCT = s.ADJUSTMENT_PCT,
             Z_COST_RED = s.Z_COST_RED,
             EDW_LAST_UPDT_TS = s.EDW_LAST_UPDT_TS
     WHEN NOT MATCHED AND s.ROUTER_ACTION = 'INSERT' THEN
         INSERT
         (
             Z_CPP_ID,
             REVISION_NUMBER,
             Z_LOB,
             Z_CI_IRR_SCORE,
             Z_CI_NPV,
             Z_CI_PAYBACK_SCORE,
             DISCOUNT,
             ADDTL_ADJUST_PCT,
             ADDTL_WTHD_PCT,
             ADJUSTMENT_PCT,
             Z_COST_RED,
             EDW_LAST_UPDT_TS
         )
         VALUES
         (
             s.Z_CPP_ID,
             s.REVISION_NUMBER,
             s.Z_LOB,
             s.Z_CI_IRR_SCORE,
             s.Z_CI_NPV,
             s.Z_CI_PAYBACK_SCORE,
             s.DISCOUNT,
             s.ADDTL_ADJUST_PCT,
             s.ADDTL_WTHD_PCT,
             s.ADJUSTMENT_PCT,
             s.Z_COST_RED,
             s.EDW_LAST_UPDT_TS
         )",
        log_model_end(this, 'TBD_PS_Z_PMRG_CPP_TBL_INS', target_object=target.database ~ '.EPMADM.PS_Z_PMRG_CPP_TBL')
    ]
) }}

SELECT
    lkp_router.Z_CPP_ID,
    lkp_router.REVISION_NUMBER,
    lkp_router.Z_LOB,
    lkp_router.Z_CI_IRR_SCORE,
    lkp_router.Z_CI_NPV,
    lkp_router.Z_CI_PAYBACK_SCORE,
    lkp_router.DISCOUNT,
    lkp_router.ADDTL_ADJUST_PCT,
    lkp_router.ADDTL_WTHD_PCT,
    lkp_router.ADJUSTMENT_PCT,
    lkp_router.Z_COST_RED,
    lkp_router.EDW_LAST_UPDT_TS,
    lkp_router.LKP_Z_CPP_ID,
    IFF(
        lkp_router.LKP_Z_CPP_ID IS NULL,
        'INSERT',
        'UPDATE'
    ) AS ROUTER_ACTION
FROM
(
    SELECT
        exp.Z_CPP_ID,
        exp.REVISION_NUMBER,
        exp.Z_LOB,
        exp.Z_CI_IRR_SCORE,
        exp.Z_CI_NPV,
        exp.Z_CI_PAYBACK_SCORE,
        exp.DISCOUNT,
        exp.ADDTL_ADJUST_PCT,
        exp.ADDTL_WTHD_PCT,
        exp.ADJUSTMENT_PCT,
        exp.Z_COST_RED,
        exp.EDW_LAST_UPDT_TS,
        lkp.Z_CPP_ID AS LKP_Z_CPP_ID
    FROM
    (
        SELECT
            RTRIM(sq.Z_CPP_ID) AS Z_CPP_ID,
            sq.REVISION_NUMBER AS REVISION_NUMBER,
            RTRIM(sq.Z_LOB) AS Z_LOB,
            sq.Z_CI_IRR_SCORE AS Z_CI_IRR_SCORE,
            sq.Z_CI_NPV AS Z_CI_NPV,
            sq.Z_CI_PAYBACK_SCORE AS Z_CI_PAYBACK_SCORE,
            sq.DISCOUNT AS DISCOUNT,
            sq.ADDTL_ADJUST_PCT AS ADDTL_ADJUST_PCT,
            sq.ADDTL_WTHD_PCT AS ADDTL_WTHD_PCT,
            sq.ADJUSTMENT_PCT AS ADJUSTMENT_PCT,
            sq.Z_COST_RED AS Z_COST_RED,
            CURRENT_TIMESTAMP() AS EDW_LAST_UPDT_TS
        FROM
        (
            SELECT
                Z_CPP_ID,
                REVISION_NUMBER,
                Z_LOB,
                Z_CI_IRR_SCORE,
                Z_CI_NPV,
                Z_CI_PAYBACK_SCORE,
                DISCOUNT,
                ADDTL_ADJUST_PCT,
                ADDTL_WTHD_PCT,
                ADJUSTMENT_PCT,
                Z_COST_RED
            FROM {{ source('CI_PSFT_SOURCE','PS_Z_PMRG_CPP_TBL') }}
        ) sq
    ) exp
    LEFT JOIN
    (
        SELECT
            Z_CPP_ID,
            REVISION_NUMBER,
            Z_LOB
        FROM {{ source('CRPDB01_EPMADM','PS_Z_PMRG_CPP_TBL') }}
        GROUP BY
            Z_CPP_ID,
            REVISION_NUMBER,
            Z_LOB
    ) lkp
        ON lkp.Z_CPP_ID = exp.Z_CPP_ID
       AND lkp.REVISION_NUMBER = exp.REVISION_NUMBER
       AND lkp.Z_LOB = exp.Z_LOB
) lkp_router
