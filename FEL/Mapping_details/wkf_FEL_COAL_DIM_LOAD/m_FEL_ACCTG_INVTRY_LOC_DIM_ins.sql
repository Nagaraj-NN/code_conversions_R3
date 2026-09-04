/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_LOAD
 SESSION   : s_m_FEL_ACCTG_INVTRY_LOC_DIM_ins_upd
 MAPPING   : m_FEL_ACCTG_INVTRY_LOC_DIM_ins
 OPERATION : INSERT only. FILTRANS keeps the rows whose dimension lookup missed and
             UPD_INSERT flags them DD_INSERT. There is no update path, so an
             existing accounting inventory location is left untouched.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_ACCT_INV_LOC_VW   full read, no filter
 LOOKUPS   : feladm.FEL_ACCTG_INVTRY_LOC_DIM twice, both with a SQL override and
             both Use Any Value on multiple match. Connected, for existence on the
             upper cased and trimmed name, commodity type and commodity name.
             Unconnected, returning MAX(ACCTG_INVTRY_LOC_KEY) as the key seed.
 TARGET    : feladm.FEL_ACCTG_INVTRY_LOC_DIM
--------------------------------------------------------------------------------
 PARAMETERS: none declared on the mapping
             SESSSTARTTIME -> LAST_UPTD_TS
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole view
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : The surrogate key is the max key plus a row counter that increments
             once per row read. That counter sits UPSTREAM of the filter, so it
             advances for existing rows too and the inserted keys are not
             contiguous. The row number below is taken over the whole source set
             before the filter, which reproduces the gaps. Informatica assigns it
             in source read order, which no ORDER BY pins down; a deterministic
             ordering on the natural key is used instead.
             ACCTG_INVTRY_LOC_NM is "name (commodity)" written in its original
             case, while the lookup matches its upper cased form.
             INVTRY_CMDTY_TYPE_NM is cut to 30 by the UPD_INSERT port.
             The captured run read 82 rows.
================================================================================
*/

SET V_SESSSTARTTIME = CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ);

INSERT INTO feladm.FEL_ACCTG_INVTRY_LOC_DIM (
    ACCTG_INVTRY_LOC_KEY,
    ACCTG_INVTRY_LOC_NM,
    INVTRY_CMDTY_TYPE_NM,
    INVTRY_CMDTY_NM,
    LAST_UPTD_TS
)
SELECT
    SRC.O_MAX_KEY,
    SRC.O_ACCTG_INV_LOC_NM_CAT,
    LEFT(SRC.CMDTY_TYPE, 30),
    SRC.CMDTY_NM,
    SRC.LAST_UPDT_TS
FROM (
    SELECT
        SQ.CMDTY_NM,
        SQ.CMDTY_TYPE,
        NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')'          AS O_ACCTG_INV_LOC_NM_CAT,
        UPPER(NVL(LTRIM(RTRIM(SQ.ACCTG_INV_LOC_NM)), '') || ' (' || NVL(LTRIM(RTRIM(SQ.CMDTY_NM)), '') || ')')   AS O_ACCTG_INV_LOC_NM,
        UPPER(LTRIM(RTRIM(SQ.CMDTY_NM)))                                                                         AS O_CMDTY_NM,
        UPPER(LTRIM(RTRIM(SQ.CMDTY_TYPE)))                                                                       AS O_CMDTY_TYPE,
        $V_SESSSTARTTIME                                                                                         AS LAST_UPDT_TS,
        NVL((SELECT MAX(ACCTG_INVTRY_LOC_KEY) FROM FELADM.FEL_ACCTG_INVTRY_LOC_DIM), 0)
            + ROW_NUMBER() OVER (ORDER BY SQ.ACCTG_INV_LOC_NM, SQ.CMDTY_NM, SQ.CMDTY_TYPE)                       AS O_MAX_KEY
    FROM AEP_DW_ACCT_INV_LOC_VW SQ
) SRC
WHERE NOT EXISTS (
    SELECT 1
    FROM feladm.FEL_ACCTG_INVTRY_LOC_DIM ANV
    WHERE UPPER(TRIM(ANV.ACCTG_INVTRY_LOC_NM))  = SRC.O_ACCTG_INV_LOC_NM
      AND UPPER(TRIM(ANV.INVTRY_CMDTY_TYPE_NM)) = SRC.O_CMDTY_TYPE
      AND UPPER(TRIM(ANV.INVTRY_CMDTY_NM))      = SRC.O_CMDTY_NM
);
