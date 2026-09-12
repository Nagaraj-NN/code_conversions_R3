-- ==========================================================================
-- Model      : PS_Z_PDS_CPP_DTL_INS
-- Mapping    : m_ps_z_pds_cpp_dtl_ins
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Session    : s_m_ps_z_pds_cpp_dtl_ins
-- Source SQL : ci/s_m_ps_z_pds_cpp_dtl_ins.sql, lines 18-99 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_PDS_CPP_DTL
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
-- This upload inserts new keys as well; the first version of this session
-- only updated. PS_Z_PDS_CPP_VW is read through CI_PSFT_SOURCE; the
-- execution log reports it missing in EPMADM.
-- ==========================================================================

{{ config(
    materialized='table',
    alias='PS_Z_PDS_CPP_DTL_INS_SRC',
    meta={"mapping_name": "m_ps_z_pds_cpp_dtl_ins", "workflow_name": "wkf_LOAD_CI_ATOMIC", "session_name": "s_m_ps_z_pds_cpp_dtl_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_PDS_CPP_DTL_INS', target_object='CRPDB01.EPMADM.PS_Z_PDS_CPP_DTL')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_PDS_CPP_DTL') }} t
     USING {{ this }} s
     ON t.Z_CPP_ID = s.Z_CPP_ID AND
         t.REVISION_NUMBER = s.REVISION_NUMBER AND
         t.FISCAL_YEAR = s.FISCAL_YEAR AND
         t.Z_CI_COST_CATG = s.Z_CI_COST_CATG
     AND s.ROUTER_ACTION = 'UPDATE'
     WHEN MATCHED THEN UPDATE SET
         Z_FODA = s.Z_FODA,
         Z_LABOR = s.Z_LABOR,
         Z_MATERIAL = s.Z_MATERIAL,
         Z_OTHER = s.Z_OTHER,
         Z_FRINGES = s.Z_FRINGES,
         Z_OTH_SER = s.Z_OTH_SER,
         Z_CONTING = s.Z_CONTING,
         Z_FLEET = s.Z_FLEET,
         Z_REMOVAL = s.Z_REMOVAL,
         Z_LEASE = s.Z_LEASE,
         Z_DIR_RML = s.Z_DIR_RML,
         Z_DIRECT = s.Z_DIRECT,
         Z_OVHD = s.Z_OVHD,
         Z_EXP = s.Z_EXP,
         Z_APPR_PROJ = s.Z_APPR_PROJ,
         Z_AFUDC = s.Z_AFUDC,
         Z_AFUDC_DEBT = s.Z_AFUDC_DEBT,
         Z_AFUDC_EQUITY = s.Z_AFUDC_EQUITY,
         Z_AFUDC_BASIS = s.Z_AFUDC_BASIS,
         Z_CIAC = s.Z_CIAC,
         EDW_LAST_UPDT_TS = s.EDW_LAST_UPDT_TS
     WHEN NOT MATCHED AND s.ROUTER_ACTION = 'INSERT' THEN INSERT (Z_CPP_ID, REVISION_NUMBER, FISCAL_YEAR, Z_CI_COST_CATG, Z_FODA, Z_LABOR, Z_MATERIAL, Z_OTHER, Z_FRINGES, Z_OTH_SER, Z_CONTING, Z_FLEET, Z_REMOVAL, Z_LEASE, Z_DIR_RML, Z_DIRECT, Z_OVHD, Z_EXP, Z_APPR_PROJ, Z_AFUDC, Z_AFUDC_DEBT, Z_AFUDC_EQUITY, Z_AFUDC_BASIS, Z_CIAC, EDW_LAST_UPDT_TS)
     VALUES (s.Z_CPP_ID, s.REVISION_NUMBER, s.FISCAL_YEAR, s.Z_CI_COST_CATG, s.Z_FODA, s.Z_LABOR, s.Z_MATERIAL, s.Z_OTHER, s.Z_FRINGES, s.Z_OTH_SER, s.Z_CONTING, s.Z_FLEET, s.Z_REMOVAL, s.Z_LEASE, s.Z_DIR_RML, s.Z_DIRECT, s.Z_OVHD, s.Z_EXP, s.Z_APPR_PROJ, s.Z_AFUDC, s.Z_AFUDC_DEBT, s.Z_AFUDC_EQUITY, s.Z_AFUDC_BASIS, s.Z_CIAC, s.EDW_LAST_UPDT_TS)",
        log_model_end(this, 'TBD_PS_Z_PDS_CPP_DTL_INS', target_object='CRPDB01.EPMADM.PS_Z_PDS_CPP_DTL')
    ]
) }}

SELECT
    exp.*,
    lkp.Z_CPP_ID AS LKP_Z_CPP_ID,
    IFF(lkp.Z_CPP_ID IS NULL, 'INSERT', 'UPDATE') AS ROUTER_ACTION
FROM (
SELECT
    RTRIM(src.Z_CPP_ID) AS Z_CPP_ID,
    src.REVISION_NUMBER AS REVISION_NUMBER,
    src.FISCAL_YEAR AS FISCAL_YEAR,
    RTRIM(src.Z_CI_COST_CATG) AS Z_CI_COST_CATG,
    src.Z_FODA AS Z_FODA,
    src.Z_LABOR AS Z_LABOR,
    src.Z_MATERIAL AS Z_MATERIAL,
    src.Z_OTHER AS Z_OTHER,
    src.Z_FRINGES AS Z_FRINGES,
    src.Z_OTH_SER AS Z_OTH_SER,
    src.Z_CONTING AS Z_CONTING,
    src.Z_FLEET AS Z_FLEET,
    src.Z_REMOVAL AS Z_REMOVAL,
    src.Z_LEASE AS Z_LEASE,
    src.Z_DIR_RML AS Z_DIR_RML,
    src.Z_DIRECT AS Z_DIRECT,
    src.Z_OVHD AS Z_OVHD,
    src.Z_EXP AS Z_EXP,
    src.Z_APPR_PROJ AS Z_APPR_PROJ,
    src.Z_AFUDC AS Z_AFUDC,
    src.Z_AFUDC_DEBT AS Z_AFUDC_DEBT,
    src.Z_AFUDC_EQUITY AS Z_AFUDC_EQUITY,
    src.Z_AFUDC_BASIS AS Z_AFUDC_BASIS,
    src.Z_CIAC AS Z_CIAC,
    CURRENT_TIMESTAMP() AS EDW_LAST_UPDT_TS
FROM {{ source('CI_PSFT_SOURCE','PS_Z_PDS_CPP_VW') }} src
) exp
LEFT JOIN (
    SELECT
        Z_CPP_ID,
        REVISION_NUMBER,
        FISCAL_YEAR,
        Z_CI_COST_CATG
    FROM {{ source('CRPDB01_EPMADM','PS_Z_PDS_CPP_DTL') }}
    GROUP BY
        Z_CPP_ID,
        REVISION_NUMBER,
        FISCAL_YEAR,
        Z_CI_COST_CATG
) lkp
    ON lkp.Z_CPP_ID = exp.Z_CPP_ID AND
       lkp.REVISION_NUMBER = exp.REVISION_NUMBER AND
       lkp.FISCAL_YEAR = exp.FISCAL_YEAR AND
       lkp.Z_CI_COST_CATG = exp.Z_CI_COST_CATG
