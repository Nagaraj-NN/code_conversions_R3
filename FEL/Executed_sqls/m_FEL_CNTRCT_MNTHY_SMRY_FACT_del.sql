/*
================================================================================
 WORKFLOW  : wkf_FEL_COAL_DIM_FACT_DEL
 SESSION   : s_m_FEL_CNTRCT_MNTHY_SMRY_FACT_del
 MAPPING   : m_FEL_CNTRCT_MNTHY_SMRY_FACT_del
 OPERATION : DELETE only, and the one mapping in this workflow that joins rather
             than looks up. The obligation feeder is turned into the fact's three
             part key through four unconnected lookups, JNRTRANS full outer joins
             that key set against the fact, FIL_INACTIVE keeps the fact rows with
             no matching feeder key, and UPD_DELETE issues DD_DELETE.
    $DBConnection_Target=fel_GENDB001
    $DBConnection_Source=fel_COMTRAC

--------------------------------------------------------------------------------
 SOURCES   : GENDB01.FELADM.FEL_COMTRAC_CNTRCT_OBLGN_FDR  (USED FOR TETSING)
 LOOKUPS   : GENDB01.FELADM.FEL_CNTRCT_PROD_CD_DIM (USED FOR TETSING)
             GENDB01.FELADM.FEL_FACILITY_DIM
             GENDB01.FELADM.FEL_SYSTEM_DIM
             GENDB01.FELADM.FEL_OPTG_MONTH_VW
 TARGET    : GENDB01.FELADM.FEL_CNTRCT_MNTHY_SMRY_FACT (USED FOR TETSING)
--------------------------------------------------------------------------------
 PARAMETERS: :UDF.DQ_for_CHAR_VARCHAR   empty or all-space to ' ', else right trim
             No mapping parameters are referenced.
 SQ OVERRIDE : none on either source qualifier, and no source filters
 PRE-SQL   : none     POST-SQL : none     TRUNCATE TARGET : no
================================================================================
*/

DELETE FROM feladm.FEL_CNTRCT_MNTHY_SMRY_FACT TGT
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT
            PD.CNTRCT_PROD_KEY   AS CNTRCT_PROD_KEY,
            FD.FACILITY_KEY      AS GEOG_FCLTY_KEY,
            OM.OPTD_MO_DAY_ID    AS OPTG_MO_DAY_ID
        FROM feladm.FEL_COMTRAC_CNTRCT_OBLGN_FDR SQ
        LEFT JOIN (
            SELECT CNTRCT_DTL_ID, CNTRCT_PROD_KEY
            FROM feladm.FEL_CNTRCT_PROD_CD_DIM
            QUALIFY ROW_NUMBER() OVER (PARTITION BY CNTRCT_DTL_ID ORDER BY CNTRCT_DTL_ID) = 1
        ) PD
          ON PD.CNTRCT_DTL_ID = SQ.CNTRCT_DTL_ID
        LEFT JOIN (
            SELECT
                DIM.FACILITY_KEY                  AS FACILITY_KEY,
                TRIM(UPPER(DIM.FACILITY_ID))      AS FACILITY_ID,
                DIM.SYSTEM_ID                     AS SYSTEM_ID
            FROM feladm.FEL_FACILITY_DIM DIM
            QUALIFY ROW_NUMBER() OVER (PARTITION BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID
                                       ORDER BY TRIM(UPPER(DIM.FACILITY_ID)), DIM.SYSTEM_ID, DIM.FACILITY_KEY) = 1
        ) FD
          ON FD.FACILITY_ID = UPPER(CASE WHEN LENGTH(LTRIM(RTRIM(SQ.FACILITY_ID))) = 0 THEN ' ' ELSE RTRIM(SQ.FACILITY_ID) END)
         AND FD.SYSTEM_ID   = (
                SELECT SYS_ID
                FROM feladm.FEL_SYSTEM_DIM
                WHERE SYS_NM = 'COMTRAC'
                QUALIFY ROW_NUMBER() OVER (ORDER BY SYS_NM) = 1
             )
        LEFT JOIN (
            SELECT OPTD_MO_DAY_ID, MONTH_NB, OPERATING_YEAR
            FROM FELADM.FEL_OPTG_MONTH_VW
            QUALIFY ROW_NUMBER() OVER (PARTITION BY MONTH_NB, OPERATING_YEAR
                                       ORDER BY MONTH_NB, OPERATING_YEAR) = 1
        ) OM
          ON OM.MONTH_NB       = MONTH(SQ.CNTRCT_DTL_OPRTG_DT)
         AND OM.OPERATING_YEAR = YEAR(SQ.CNTRCT_DTL_OPRTG_DT)
    ) FDR
    WHERE FDR.CNTRCT_PROD_KEY = TGT.CNTRCT_PROD_KEY
      AND FDR.GEOG_FCLTY_KEY  = TGT.GEOG_FCLTY_KEY
      AND FDR.OPTG_MO_DAY_ID  = TGT.OPRTG_MO_DAY_ID
);
