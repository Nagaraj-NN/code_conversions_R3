/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
 MAPPING   : m_FEL_COMTRAC_CNTRCT_OBLGN_FDR_del
 OPERATION : DELETE only. FILTRANS keeps the rows whose lookup missed, that is the
             FDR rows that no longer exist in the Comtrac source view, and
             UPD_DELETE issues DD_DELETE for them.
--------------------------------------------------------------------------------
 SOURCE    : AEP_DW_CONTRACT_OBLIGATIONS_VW
             GENDB01_DEV_SANDBOX.COMMON.AEP_DW_CONTRACT_OBLIGATIONS_VW_TEST   --USED FOR TESTING
 TARGET    : GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR
--------------------------------------------------------------------------------
 PARAMETERS: $$START_TIME, $$REC_STATUS, $$RUN_STATUS declared, NOT REFERENCED
             :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
 SQ OVERRIDE : none, and no source filter, so the reader takes the whole table
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no

================================================================================
*/

DELETE FROM GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM GENDB01_DEV_SANDBOX.COMMON.AEP_DW_CONTRACT_OBLIGATIONS_VW_TEST VW  --USED FOR TESTING
    WHERE VW.CNTRCTDTL_ID     = TGT.CNTRCT_DTL_ID 
      AND VW.FCLTY_ID         = IFF(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END IS NULL, NULL,
                                    COALESCE(TRY_TO_NUMBER(CASE WHEN LENGTH(LTRIM(RTRIM(TGT.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(TGT.FACILITY_ID) END), 0))
      AND VW.CONTRCTDTL_OB_DT = TGT.CNTRCT_DTL_OPRTG_DT
);
