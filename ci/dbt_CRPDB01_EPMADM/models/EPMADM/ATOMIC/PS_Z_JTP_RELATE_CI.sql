-- ==========================================================================
-- Model      : PS_Z_JTP_RELATE_CI
-- Mapping    : m_ps_z_jtp_relate_ci_ins
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Source SQL : wkf_LOAD_CI_ATOMIC.sql, lines 39-55 (TRUNCATE + INSERT)
-- Target     : CRPDB01.EPMADM.PS_Z_JTP_RELATE_CI
-- Load type  : incremental / append (truncate + reload), the model IS the target
-- --------------------------------------------------------------------------
-- Full refresh of the JTP relationship table. The workflow header lists the
-- truncate as session PRE SQL, so it is a pre-hook here and the model itself
-- is the target, as for FEL's truncate-and-reload models.
--
-- DO NOT RUN AS VALIDATED. The validated script truncates
-- EPMADM.PS_Z_JTP_RELATE_CI and then inserts SELECT ... FROM
-- EPMADM.PS_Z_JTP_RELATE_CI - the table it has just emptied. As written it
-- loads zero rows and leaves the table empty on every run. In Informatica the
-- source qualifier read PS_Z_JTP_RELATE_CI through the PeopleSoft source
-- connection and the writer wrote it through the warehouse connection; the
-- conversion resolved both to the same name.
--
-- The source is declared in its own group, CI_PSFT_SOURCE, and
-- assert_psft_source below stops compilation - before the TRUNCATE can run -
-- while that source is this model's own table, or does not exist. Repoint
-- CI_PSFT_SOURCE in models/epmadm_schema.yml and this model builds unchanged.
-- ==========================================================================

{{ assert_psft_source(source('CI_PSFT_SOURCE', 'PS_Z_JTP_RELATE_CI'), this, must_exist=true) }}

{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    meta={"mapping_name": "m_ps_z_jtp_relate_ci_ins", "workflow_name": "wkf_LOAD_CI_ATOMIC"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_JTP_RELATE_CI', target_object=target.database ~ '.EPMADM.PS_Z_JTP_RELATE_CI'),
        "TRUNCATE TABLE IF EXISTS {{ this }}"
    ],
    post_hook=[
        log_model_end(this, 'TBD_PS_Z_JTP_RELATE_CI', target_object=target.database ~ '.EPMADM.PS_Z_JTP_RELATE_CI')
    ]
) }}

SELECT
    Z_PLANT_ID,
    Z_LEAD_PROJECT,
    Z_LEAD_BUGL,
    Z_RELATED_BUGL,
    EFFDT,
    EFFSEQ,
    Z_RELATED_PROJECT,
    Z_LEAD_BU_PC,
    Z_RELATED_BU_PC,
    OPRID,
    DTTM_STAMP
FROM {{ source('CI_PSFT_SOURCE','PS_Z_JTP_RELATE_CI') }}
