-- ==========================================================================
-- Model      : FEL_CONTRACT_DIM_PARENT_ROLLUP
-- Mapping    : m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
-- Workflow   : wkf_FEL_COAL_DIM_LOAD
-- Session    : s_m_FEL_COMTRAC_CONTRACT_DIM_ins_upd
-- Target     : GENDB01.FELADM.FEL_CONTRACT_DIM
-- Load type  : table + UPDATE post-hook
-- --------------------------------------------------------------------------
-- Target load order 2 of 2 for m_FEL_COMTRAC_CONTRACT_DIM_ins_upd. The third
-- statement of the validated script is a second pass over the dimension: for
-- every COMTRAC contract it rewrites CURR_CNTRCT_VNDR_NM and CURR_OPCO_NM
-- from the row with the greatest CNTRCT_EXPR_DT inside the same parent
-- contract. It reads the dimension after the feeder insert and update have
-- landed, which is why it is a model of its own rather than a third hook on
-- FEL_CONTRACT_DIM: the depends_on below makes dbt run it second.
-- ==========================================================================

-- depends_on: {{ ref('FEL_CONTRACT_DIM') }}

{{ config(
    materialized='table',
    alias='FEL_CONTRACT_DIM_PARENT_ROLLUP_SRC',
    meta={"mapping_name": "m_FEL_COMTRAC_CONTRACT_DIM_ins_upd", "workflow_name": "wkf_FEL_COAL_DIM_LOAD", "session_name": "s_m_FEL_COMTRAC_CONTRACT_DIM_ins_upd"},
    pre_hook=[
        log_model_start(this, 'TBD_FEL_CONTRACT_DIM_PARENT_ROLLUP', target_object='GENDB01.FELADM.FEL_CONTRACT_DIM')
    ],
    post_hook=[
        "UPDATE {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} TGT
     SET
         CURR_CNTRCT_VNDR_NM = SRC.CURR_CNTRCT_VNDR_NM,
         CURR_OPCO_NM        = SRC.CURR_OPCO_NM,
         LAST_UPDT_TS        = SRC.LAST_UPDT_TS
     FROM {{ this }} SRC
     WHERE TGT.CONTRACT_KEY = SRC.CONTRACT_KEY",
        log_model_end(this, 'TBD_FEL_CONTRACT_DIM_PARENT_ROLLUP', target_object='GENDB01.FELADM.FEL_CONTRACT_DIM')
    ]
) }}

SELECT
    DQ.CONTRACT_KEY,
    LEFT(LKP_CN.CURR_CNTRCT_VNDR_NM, 50)        AS CURR_CNTRCT_VNDR_NM,
    LEFT(LKP_CN.CURR_OPCO_NM, 50)               AS CURR_OPCO_NM,
    CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)  AS LAST_UPDT_TS
FROM (
    SELECT
        SQ.CONTRACT_KEY,
        UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.PARNT_CNTRCT_NM))) = 0 THEN ' ' ELSE RTRIM(SQ.PARNT_CNTRCT_NM) END) AS O_PARENT_CONTRACT_NAME
    FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} SQ
    WHERE SQ.SYSTEM_NM = 'COMTRAC'
) DQ
LEFT JOIN (
    SELECT c.curr_cntrct_vndr_nm, c.curr_opco_nm, UPPER(c.parnt_cntrct_nm) AS parnt_cntrct_nm
    FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} c
    INNER JOIN (
        SELECT d.parnt_cntrct_nm AS pname, MAX(d.cntrct_expr_dt) AS max_date
        FROM {{ source('GENDB01_FELADM','FEL_CONTRACT_DIM') }} d
        WHERE UPPER(TRIM(d.system_nm)) = 'COMTRAC'
        GROUP BY d.parnt_cntrct_nm
    ) m
      ON c.parnt_cntrct_nm = m.pname
     AND c.cntrct_expr_dt  = m.max_date
    WHERE UPPER(TRIM(c.system_nm)) = 'COMTRAC'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY UPPER(c.parnt_cntrct_nm)
                               ORDER BY c.curr_cntrct_vndr_nm, c.curr_opco_nm) = 1
) LKP_CN
  ON LKP_CN.parnt_cntrct_nm = DQ.O_PARENT_CONTRACT_NAME
