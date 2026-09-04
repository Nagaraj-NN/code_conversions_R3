/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_ACCT_TYP_DIM_ins_upd
 MAPPING   : m_FEL_ACCT_TYP_DIM_ins
 OPERATION : INSERT only. RTR_INS_UPT has a NEW group on the dimension lookup and
             an unconnected DEFAULT1 group; only UPD_INSERT is wired, so despite
             the session name no update is ever issued.
--------------------------------------------------------------------------------
 SOURCE    : FEL_FV_TRANS_FDR, distinct account type names
 LOOKUPS   : feladm.FEL_ACCT_TYP_DIM twice, both with a SQL override and both Use
             Any Value. Connected, for existence on the upper trimmed name.
             Unconnected, SELECT max(ACCT_TYP_KEY) as the surrogate key seed, its
             condition MAX_ACCT_TYP_KEY != IN_FAKE_KEY with the fake key -999.
 TARGET    : feladm.FEL_ACCT_TYP_DIM
--------------------------------------------------------------------------------
 PARAMETERS: none declared on the mapping
             SESSSTARTTIME -> LAST_UPDT_TS
             EXP_DEFAULT_VALUES locals: v_fake_key -999, v_next_key a row counter,
             v_lkp_max_key the max key lookup, and the unused v_def_string
 SQ OVERRIDE : PRESENT on SQ_FEL_FV_TRANS_FDR:
                 SELECT DISTINCT FEL_FV_TRANS_FDR.ACCT_TYP_NM FROM FEL_FV_TRANS_FDR
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The surrogate key is the max key plus a counter that increments once
             per row read. That counter sits UPSTREAM of the router, so it advances
             for existing rows too and the inserted keys are not contiguous. The row
             number below is taken over the whole source set before the filter, so
             the gaps are reproduced; a deterministic ordering is used.
             ACCT_TYP_NM is written in its ORIGINAL case, while the lookup matches
             on its upper cased and trimmed form.
             The captured run read 12 rows and wrote none.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

INSERT INTO feladm.FEL_ACCT_TYP_DIM (
    ACCT_TYP_KEY,
    ACCT_TYP_NM,
    LAST_UPDT_TS
)
SELECT
    SRC.O_ACCT_TYPE_KEY,
    SRC.ACCTG_TYP_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.ACCT_TYP_NM                                                            AS ACCTG_TYP_NM,
        UPPER(LTRIM(RTRIM(SQ.ACCT_TYP_NM)))                                       AS O_TRIM_ACCT_TYPE_NM,
        $V_SESSSTARTTIME                                                          AS LAST_UPDT_TS,
        NVL((SELECT MAX(ACCT_TYP_KEY) FROM FELADM.FEL_ACCT_TYP_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCT_TYP_NM)                         AS O_ACCT_TYPE_KEY
    FROM (
        SELECT DISTINCT FEL_FV_TRANS_FDR.ACCT_TYP_NM
        FROM FEL_FV_TRANS_FDR
    ) SQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_ACCT_TYP_DIM DIM
    WHERE UPPER(TRIM(DIM.ACCT_TYP_NM)) = SRC.O_TRIM_ACCT_TYPE_NM
);
