
USE [PHClaims];
GO

IF OBJECT_ID('[stage].[sp_perf_elig_member_month]','P') IS NOT NULL
DROP PROCEDURE [stage].[sp_perf_elig_member_month];
GO
CREATE PROCEDURE [stage].[sp_perf_elig_member_month]
AS
SET NOCOUNT ON;

BEGIN

-- Create slim table for temporary work
IF OBJECT_ID('tempdb..#temp') IS NOT NULL
DROP TABLE #temp;
SELECT
 [CLNDR_YEAR_MNTH]
,[MEDICAID_RECIPIENT_ID]
,[RPRTBL_RAC_CODE]
,[FROM_DATE]
,[TO_DATE]
,[COVERAGE_TYPE_IND]
,[MC_PRVDR_NAME]
,[DUAL_ELIG]
,[TPL_FULL_FLAG]
INTO #temp
FROM [stage].[mcaid_elig];

CREATE NONCLUSTERED INDEX [idx_nc_#temp] 
ON #temp([MEDICAID_RECIPIENT_ID], [CLNDR_YEAR_MNTH]);

/*
-- ZERO ROWS
-- THERE ARE NO MEMBER MONTHS WITH CONFLICTING DUAL_ELIG, TPL_FULL_FLAG, OR full_benefit_flag
-- SO THE MEMBER-MONTH TABLE ABOVE (#temp) CAN BE COLLAPSED ARBITRARILY
SELECT *
FROM
(
SELECT
 [CLNDR_YEAR_MNTH]
,[MEDICAID_RECIPIENT_ID]
,MIN([DUAL_ELIG]) AS [MIN_DUAL_ELIG]
,MAX([DUAL_ELIG]) AS [MAX_DUAL_ELIG]
,MIN([TPL_FULL_FLAG]) AS [MIN_TPL_FULL_FLAG]
,MAX([TPL_FULL_FLAG]) AS [MAX_TPL_FULL_FLAG]
,MIN(CASE WHEN b.[rda_full_benefit_flag] IS NULL THEN 'N' ELSE b.[rda_full_benefit_flag] END) AS [MIN_rda_full_benefit_flag]
,MAX(CASE WHEN b.[rda_full_benefit_flag] IS NULL THEN 'N' ELSE b.[rda_full_benefit_flag] END) AS [MAX_rda_full_benefit_flag]
FROM #temp AS a
LEFT JOIN [ref].[mcaid_rac_code] AS b
ON a.[RPRTBL_RAC_CODE] = b.[rac_code]
GROUP BY [CLNDR_YEAR_MNTH], [MEDICAID_RECIPIENT_ID]
) AS a
WHERE 
[MIN_DUAL_ELIG] <> [MAX_DUAL_ELIG] OR
[MIN_TPL_FULL_FLAG] <> [MAX_TPL_FULL_FLAG] OR
[MIN_rda_full_benefit_flag] <> [MAX_rda_full_benefit_flag];
*/

IF OBJECT_ID('[stage].[perf_elig_member_month]', 'U') IS NOT NULL
DROP TABLE [stage].[perf_elig_member_month];

WITH CTE AS
(
SELECT
 [CLNDR_YEAR_MNTH]
,[MEDICAID_RECIPIENT_ID]
,[RPRTBL_RAC_CODE]
,[FROM_DATE]
,[TO_DATE]
,[COVERAGE_TYPE_IND]
,[MC_PRVDR_NAME]
,[DUAL_ELIG]
,[TPL_FULL_FLAG]
,ROW_NUMBER() OVER(PARTITION BY [MEDICAID_RECIPIENT_ID], [CLNDR_YEAR_MNTH] 
                   ORDER BY DATEDIFF(DAY, [FROM_DATE], [TO_DATE]) DESC) AS [row_num]
FROM #temp
)

SELECT
 [CLNDR_YEAR_MNTH]
,[MEDICAID_RECIPIENT_ID]
,[RPRTBL_RAC_CODE]
,[FROM_DATE]
,[TO_DATE]
,[COVERAGE_TYPE_IND]
,[MC_PRVDR_NAME]
,[DUAL_ELIG]
,[TPL_FULL_FLAG]

INTO [stage].[perf_elig_member_month]
FROM CTE
WHERE 1 = 1
AND [row_num] = 1;

ALTER TABLE [stage].[perf_elig_member_month] ALTER COLUMN [CLNDR_YEAR_MNTH] INT NOT NULL;
ALTER TABLE [stage].[perf_elig_member_month] ALTER COLUMN [MEDICAID_RECIPIENT_ID] VARCHAR(200) NOT NULL;
ALTER TABLE [stage].[perf_elig_member_month] ADD CONSTRAINT PK_stage_perf_elig_member_month PRIMARY KEY ([MEDICAID_RECIPIENT_ID], [CLNDR_YEAR_MNTH]);

END
GO

--EXEC [stage].[sp_perf_elig_member_month];

/*
SELECT NumRows
	  ,COUNT(*)
FROM
(
SELECT [MEDICAID_RECIPIENT_ID]
	  ,[CLNDR_YEAR_MNTH]
	  ,COUNT(*) AS NumRows
FROM [stage].[perf_elig_member_month]
GROUP BY [MEDICAID_RECIPIENT_ID], [CLNDR_YEAR_MNTH]
) AS SubQuery
GROUP BY NumRows
ORDER BY NumRows;
*/