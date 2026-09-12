/***************************/
--Errors
--		SQL compilation error: Object 'CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_PDS_CI_VW' does not exist or not authorized.
-- =============================================================================
-- Workflow Name: wkf_LOAD_CI_ATOMIC
-- Mappings Name: m_ps_z_pds_ci_dtl_ins
-- List of Other tasks: None
-- =============================================================================
-- DEVELOPER : Neelakanta
-- LAST UPDATED : 
-- LOGIC: Source Qualifier, Expression, lookup transformations, Router, Update Strategy, and all target branches preserved in mapping order
-- SOURCE Tables: PS_Z_PDS_CI_VW
-- TARGET TABLE: PS_Z_PDS_CI_DTL
-- PRE SQL: None
-- POST SQL: None
-- Parameters used: $Source, $Target, $PMCacheDir

MERGE INTO CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_PDS_CI_DTL t
USING (
        SELECT
            exp.*,
            lkp.BUSINESS_UNIT AS LKP_BUSINESS_UNIT,
            IFF(lkp.BUSINESS_UNIT IS NULL, 'INSERT', 'UPDATE') AS ROUTER_ACTION
        FROM (
        SELECT
            RTRIM(src.BUSINESS_UNIT) AS BUSINESS_UNIT,
            RTRIM(src.PROJECT_ID) AS PROJECT_ID,
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
        FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_PDS_CI_VW src
        ) exp
        LEFT JOIN (
            SELECT
                BUSINESS_UNIT,
                PROJECT_ID,
                REVISION_NUMBER,
                FISCAL_YEAR,
                Z_CI_COST_CATG
            FROM CRPDB01_DEV_SANDBOX.EPMADM.PS_Z_PDS_CI_DTL
            GROUP BY
                BUSINESS_UNIT,
                PROJECT_ID,
                REVISION_NUMBER,
                FISCAL_YEAR,
                Z_CI_COST_CATG
        ) lkp
            ON lkp.BUSINESS_UNIT = exp.BUSINESS_UNIT AND
               lkp.PROJECT_ID = exp.PROJECT_ID AND
               lkp.REVISION_NUMBER = exp.REVISION_NUMBER AND
               lkp.FISCAL_YEAR = exp.FISCAL_YEAR AND
               lkp.Z_CI_COST_CATG = exp.Z_CI_COST_CATG
) s
ON t.BUSINESS_UNIT = s.BUSINESS_UNIT AND
    t.PROJECT_ID = s.PROJECT_ID AND
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
WHEN NOT MATCHED AND s.ROUTER_ACTION = 'INSERT' THEN INSERT (BUSINESS_UNIT, PROJECT_ID, REVISION_NUMBER, FISCAL_YEAR, Z_CI_COST_CATG, Z_FODA, Z_LABOR, Z_MATERIAL, Z_OTHER, Z_FRINGES, Z_OTH_SER, Z_CONTING, Z_FLEET, Z_REMOVAL, Z_LEASE, Z_DIR_RML, Z_DIRECT, Z_OVHD, Z_EXP, Z_APPR_PROJ, Z_AFUDC, Z_AFUDC_DEBT, Z_AFUDC_EQUITY, Z_AFUDC_BASIS, Z_CIAC, EDW_LAST_UPDT_TS)
VALUES (s.BUSINESS_UNIT, s.PROJECT_ID, s.REVISION_NUMBER, s.FISCAL_YEAR, s.Z_CI_COST_CATG, s.Z_FODA, s.Z_LABOR, s.Z_MATERIAL, s.Z_OTHER, s.Z_FRINGES, s.Z_OTH_SER, s.Z_CONTING, s.Z_FLEET, s.Z_REMOVAL, s.Z_LEASE, s.Z_DIR_RML, s.Z_DIRECT, s.Z_OVHD, s.Z_EXP, s.Z_APPR_PROJ, s.Z_AFUDC, s.Z_AFUDC_DEBT, s.Z_AFUDC_EQUITY, s.Z_AFUDC_BASIS, s.Z_CIAC, s.EDW_LAST_UPDT_TS);
