-- ==========================================================================
-- Model      : PS_Z_CPP_GEN_STAT_INS
-- Mapping    : m_ps_z_cpp_gen_stat_ins
-- Workflow   : wkf_LOAD_CI_ATOMIC
-- Session    : s_m_ps_z_cpp_gen_stat_ins
-- Source SQL : ci/s_m_ps_z_cpp_gen_stat_ins.sql, lines 18-238 (MERGE)
-- Target     : CRPDB01.EPMADM.PS_Z_CPP_GEN_STAT
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
-- Three LKP_USERID_NAME lookups on PS_PERSONAL_D00 turn the assigned-by,
-- last-update and approved-by operator ids into names, keeping the id when
-- no name is found. PS_PERSONAL_D00 is read from EPMADM: the script ran
-- without error, so it exists there.
--
-- Source: the script reads PS_Z_CPP_GEN_STAT twice - as the mapping's source and as the
-- router's lookup on the target - and names EPMADM both times. The lookup
-- is the EPMADM target; the source is the PeopleSoft PS_Z_CPP_GEN_STAT, read through
-- CI_PSFT_SOURCE. As written the MERGE would read its own target and bring in
-- nothing new, so assert_psft_source stops compilation until CI_PSFT_SOURCE
-- points somewhere else.
-- ==========================================================================

{{ assert_psft_source(source('CI_PSFT_SOURCE', 'PS_Z_CPP_GEN_STAT'), source('CRPDB01_EPMADM', 'PS_Z_CPP_GEN_STAT')) }}

{{ config(
    materialized='table',
    alias='PS_Z_CPP_GEN_STAT_INS_SRC',
    meta={"mapping_name": "m_ps_z_cpp_gen_stat_ins", "workflow_name": "wkf_LOAD_CI_ATOMIC", "session_name": "s_m_ps_z_cpp_gen_stat_ins"},
    pre_hook=[
        log_model_start(this, 'TBD_PS_Z_CPP_GEN_STAT_INS', target_object='CRPDB01.EPMADM.PS_Z_CPP_GEN_STAT')
    ],
    post_hook=[
        "MERGE INTO {{ source('CRPDB01_EPMADM','PS_Z_CPP_GEN_STAT') }} t
     USING {{ this }} s
     ON t.Z_CPP_ID = s.Z_CPP_ID
     AND s.ROUTER_ACTION = 'UPDATE'
     WHEN MATCHED THEN UPDATE SET
             Z_ECON_COMPLETE = s.Z_ECON_COMPLETE,
             Z_EC_COMPLETE = s.Z_EC_COMPLETE,
             Z_PDS_COMPLETE = s.Z_PDS_COMPLETE,
             Z_RBTO_COMPLETE = s.Z_RBTO_COMPLETE,
             Z_SPDM_COMPLETE = s.Z_SPDM_COMPLETE,
             Z_CI_GEN_STATUS = s.Z_CI_GEN_STATUS,
             FROM_DATE = s.FROM_DATE,
             TO_DATE = s.TO_DATE,
             Z_EMERGENT = s.Z_EMERGENT,
             Z_WO_ECON = s.Z_WO_ECON,
             Z_PDS_SENT = s.Z_PDS_SENT,
             DATE1 = s.DATE1,
             Z_SCPP_APPROVED = s.Z_SCPP_APPROVED,
             Z_PMA_ACCEPT = s.Z_PMA_ACCEPT,
             DATE2 = s.DATE2,
             Z_PMA_REVIEW = s.Z_PMA_REVIEW,
             DATE3 = s.DATE3,
             Z_ECON_DATE = s.Z_ECON_DATE,
             Z_EC_DATE = s.Z_EC_DATE,
             Z_RBTO_DATE = s.Z_RBTO_DATE,
             Z_SPDM_DATE = s.Z_SPDM_DATE,
             Z_PDS_DATE = s.Z_PDS_DATE,
             Z_PRJ_DEL_MDL = s.Z_PRJ_DEL_MDL,
             Z_SCR_PRJ_DEL_MDL = s.Z_SCR_PRJ_DEL_MDL,
             Z_COST_EST_QUALITY = s.Z_COST_EST_QUALITY,
             Z_ESTIMATE_BASIS = s.Z_ESTIMATE_BASIS,
             CONFIRMED = s.CONFIRMED,
             ASSIGNED_BY_OPRID = s.ASSIGNED_BY_OPRID,
             EDW_LAST_UPDT_TS = s.EDW_LAST_UPDT_TS,
             LASTUPDOPRID = s.LASTUPDOPRID,
             PRIORITY = s.PRIORITY,
             APPROVED = s.APPROVED,
             FLEX_PREF_REQ = s.FLEX_PREF_REQ,
             APPROVAL_DT = s.APPROVAL_DT,
             OPRID_APPROVED_BY = s.OPRID_APPROVED_BY
     WHEN NOT MATCHED AND s.ROUTER_ACTION = 'INSERT' THEN INSERT
     (
             Z_CPP_ID,
             Z_ECON_COMPLETE,
             Z_EC_COMPLETE,
             Z_PDS_COMPLETE,
             Z_RBTO_COMPLETE,
             Z_SPDM_COMPLETE,
             Z_CI_GEN_STATUS,
             FROM_DATE,
             TO_DATE,
             Z_EMERGENT,
             Z_WO_ECON,
             Z_PDS_SENT,
             DATE1,
             Z_SCPP_APPROVED,
             Z_PMA_ACCEPT,
             DATE2,
             Z_PMA_REVIEW,
             DATE3,
             Z_ECON_DATE,
             Z_EC_DATE,
             Z_RBTO_DATE,
             Z_SPDM_DATE,
             Z_PDS_DATE,
             Z_PRJ_DEL_MDL,
             Z_SCR_PRJ_DEL_MDL,
             Z_COST_EST_QUALITY,
             Z_ESTIMATE_BASIS,
             CONFIRMED,
             ASSIGNED_BY_OPRID,
             EDW_LAST_UPDT_TS,
             LASTUPDOPRID,
             PRIORITY,
             APPROVED,
             FLEX_PREF_REQ,
             APPROVAL_DT,
             OPRID_APPROVED_BY
     )
     VALUES
     (
             s.Z_CPP_ID,
             s.Z_ECON_COMPLETE,
             s.Z_EC_COMPLETE,
             s.Z_PDS_COMPLETE,
             s.Z_RBTO_COMPLETE,
             s.Z_SPDM_COMPLETE,
             s.Z_CI_GEN_STATUS,
             s.FROM_DATE,
             s.TO_DATE,
             s.Z_EMERGENT,
             s.Z_WO_ECON,
             s.Z_PDS_SENT,
             s.DATE1,
             s.Z_SCPP_APPROVED,
             s.Z_PMA_ACCEPT,
             s.DATE2,
             s.Z_PMA_REVIEW,
             s.DATE3,
             s.Z_ECON_DATE,
             s.Z_EC_DATE,
             s.Z_RBTO_DATE,
             s.Z_SPDM_DATE,
             s.Z_PDS_DATE,
             s.Z_PRJ_DEL_MDL,
             s.Z_SCR_PRJ_DEL_MDL,
             s.Z_COST_EST_QUALITY,
             s.Z_ESTIMATE_BASIS,
             s.CONFIRMED,
             s.ASSIGNED_BY_OPRID,
             s.EDW_LAST_UPDT_TS,
             s.LASTUPDOPRID,
             s.PRIORITY,
             s.APPROVED,
             s.FLEX_PREF_REQ,
             s.APPROVAL_DT,
             s.OPRID_APPROVED_BY
     )",
        log_model_end(this, 'TBD_PS_Z_CPP_GEN_STAT_INS', target_object='CRPDB01.EPMADM.PS_Z_CPP_GEN_STAT')
    ]
) }}

SELECT
    exp.*,
    lkp_target.Z_CPP_ID AS LKP_Z_CPP_ID,
    IFF(lkp_target.Z_CPP_ID IS NULL, 'INSERT', 'UPDATE') AS ROUTER_ACTION
FROM
(
    SELECT
            sq.Z_CPP_ID AS Z_CPP_ID,
            RTRIM(sq.Z_ECON_COMPLETE) AS Z_ECON_COMPLETE,
            RTRIM(sq.Z_EC_COMPLETE) AS Z_EC_COMPLETE,
            RTRIM(sq.Z_PDS_COMPLETE) AS Z_PDS_COMPLETE,
            RTRIM(sq.Z_RBTO_COMPLETE) AS Z_RBTO_COMPLETE,
            RTRIM(sq.Z_SPDM_COMPLETE) AS Z_SPDM_COMPLETE,
            RTRIM(sq.Z_CI_GEN_STATUS) AS Z_CI_GEN_STATUS,
            sq.FROM_DATE AS FROM_DATE,
            sq.TO_DATE AS TO_DATE,
            RTRIM(sq.Z_EMERGENT) AS Z_EMERGENT,
            RTRIM(sq.Z_WO_ECON) AS Z_WO_ECON,
            RTRIM(sq.Z_PDS_SENT) AS Z_PDS_SENT,
            sq.DATE1 AS DATE1,
            RTRIM(sq.Z_SCPP_APPROVED) AS Z_SCPP_APPROVED,
            RTRIM(sq.Z_PMA_ACCEPT) AS Z_PMA_ACCEPT,
            sq.DATE2 AS DATE2,
            RTRIM(sq.Z_PMA_REVIEW) AS Z_PMA_REVIEW,
            sq.DATE3 AS DATE3,
            sq.Z_ECON_DATE AS Z_ECON_DATE,
            sq.Z_EC_DATE AS Z_EC_DATE,
            sq.Z_RBTO_DATE AS Z_RBTO_DATE,
            sq.Z_SPDM_DATE AS Z_SPDM_DATE,
            sq.Z_PDS_DATE AS Z_PDS_DATE,
            RTRIM(sq.Z_PRJ_DEL_MDL) AS Z_PRJ_DEL_MDL,
            RTRIM(sq.Z_SCR_PRJ_DEL_MDL) AS Z_SCR_PRJ_DEL_MDL,
            RTRIM(sq.Z_COST_EST_QUALITY) AS Z_COST_EST_QUALITY,
            RTRIM(sq.Z_ESTIMATE_BASIS) AS Z_ESTIMATE_BASIS,
            RTRIM(sq.CONFIRMED) AS CONFIRMED,
            COALESCE(p_assigned.PERS_NAME, sq.ASSIGNED_BY_OPRID) AS ASSIGNED_BY_OPRID,
            CURRENT_TIMESTAMP() AS EDW_LAST_UPDT_TS,
            COALESCE(p_lastupd.PERS_NAME, sq.LASTUPDOPRID) AS LASTUPDOPRID,
            sq.PRIORITY AS PRIORITY,
            RTRIM(sq.APPROVED) AS APPROVED,
            RTRIM(sq.FLEX_PREF_REQ) AS FLEX_PREF_REQ,
            sq.APPROVAL_DT AS APPROVAL_DT,
            COALESCE(p_approved.PERS_NAME, sq.OPRID_APPROVED_BY) AS OPRID_APPROVED_BY
    FROM
    (
        SELECT
            *
        FROM {{ source('CI_PSFT_SOURCE','PS_Z_CPP_GEN_STAT') }}
    ) sq
    LEFT JOIN (
            SELECT
                SETID,
                EMPLID,
                ALTER_EMPLID,
                PERS_NAME
            FROM {{ source('CRPDB01_EPMADM','PS_PERSONAL_D00') }}
            WHERE EFFDT <= CURRENT_DATE()
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY SETID, EMPLID
                ORDER BY EFFDT DESC
            ) = 1
        ) p_assigned
        ON p_assigned.ALTER_EMPLID = RTRIM(sq.ASSIGNED_BY_OPRID)
    LEFT JOIN (
            SELECT
                SETID,
                EMPLID,
                ALTER_EMPLID,
                PERS_NAME
            FROM {{ source('CRPDB01_EPMADM','PS_PERSONAL_D00') }}
            WHERE EFFDT <= CURRENT_DATE()
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY SETID, EMPLID
                ORDER BY EFFDT DESC
            ) = 1
        ) p_lastupd
        ON p_lastupd.ALTER_EMPLID = RTRIM(sq.LASTUPDOPRID)
    LEFT JOIN (
            SELECT
                SETID,
                EMPLID,
                ALTER_EMPLID,
                PERS_NAME
            FROM {{ source('CRPDB01_EPMADM','PS_PERSONAL_D00') }}
            WHERE EFFDT <= CURRENT_DATE()
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY SETID, EMPLID
                ORDER BY EFFDT DESC
            ) = 1
        ) p_approved
        ON p_approved.ALTER_EMPLID = RTRIM(sq.OPRID_APPROVED_BY)
) exp
LEFT JOIN
(
    SELECT
        Z_CPP_ID
    FROM {{ source('CRPDB01_EPMADM','PS_Z_CPP_GEN_STAT') }}
    GROUP BY
        Z_CPP_ID
) lkp_target
    ON lkp_target.Z_CPP_ID = exp.Z_CPP_ID
