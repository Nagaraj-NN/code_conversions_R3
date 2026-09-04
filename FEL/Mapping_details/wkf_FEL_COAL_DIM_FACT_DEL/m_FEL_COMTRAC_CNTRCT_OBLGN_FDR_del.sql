/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
 MAPPING   : m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
 OPERATION : DELETE only. FILTRANS keeps the rows whose lookup missed, that is the
             FDR rows that no longer exist in the Comtrac source view, and
             UPD_DELETE issues DD_DELETE for them.
--------------------------------------------------------------------------------
 SOURCE    : feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR   full read, no filter
 LOOKUP    : AEP_DW_CONTRACT_OBLIGATIONS_VW
             keys CNTRCTDTL_ID + FCLTY_ID + CONTRCTDTL_OB_DT, no SQL override
 TARGET    : feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS declared, NOT REFERENCED
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
--------------------------------------------------------------------------------
 NOTES     : FACILITY_ID is stored as char(3) but the lookup key is numeric, so
             EXPTRANS applies TO_INTEGER to the data quality output. TO_INTEGER
             yields 0 for non numeric text and null for null, reproduced below.
             The delete itself keys on the untouched char FACILITY_ID.
             The captured run read 5666 rows.
================================================================================
*/

DELETE FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM AEP_DW_CONTRACT_OBLIGATIONS_VW VW
    WHERE VW.CNTRCTDTL_ID     = TGT.CNTRCT_DTL_ID
      AND VW.FCLTY_ID         = IFF(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END IS NULL, NULL,
                                    COALESCE(TRY_TO_NUMBER(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END), 0))
      AND VW.CONTRCTDTL_OB_DT = TGT.CNTRCT_DTL_OPRTG_DT
);
