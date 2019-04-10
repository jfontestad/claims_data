
USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_cap_ambulatory_visit]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_cap_ambulatory_visit];
GO
CREATE VIEW [stage].[v_perf_cap_ambulatory_visit]
AS
/*
SELECT [value_set_name]
      ,[code_system]
	  ,COUNT([code])
FROM [PHClaims].[ref].[hedis_code_system]
WHERE [value_set_name] IN ('Ambulatory Visits')
GROUP BY [value_set_name], [code_system];
*/

WITH [get_claims] AS
(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

--SELECT COUNT(*)
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Ambulatory Visits')
AND hed.[code_system] IN ('CPT', 'HCPCS')
AND pr.[pcode] = hed.[code]

UNION

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

--SELECT COUNT(*)
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Ambulatory Visits')
AND hed.[code_system] = 'ICD10CM'
AND dx.[dx_ver] = 10 
AND dx.[dx_norm] = hed.[code]

UNION

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

--SELECT COUNT(*)
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Ambulatory Visits')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]
)

SELECT 
 ym.[year_month]
,a.[id]
,a.[tcn]
,a.[from_date]
,a.[to_date]
,a.[flag]
FROM [get_claims] AS a
INNER JOIN [ref].[perf_year_month] AS ym
ON a.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
GO

/*
-- 10,271,484 rows
IF OBJECT_ID('tempdb..#temp') IS NOT NULL
DROP TABLE #temp;
SELECT * 
INTO #temp
FROM [stage].[v_perf_cap_ambulatory_visit];

SELECT TOP(100) * 
FROM #temp;

SELECT NumRows
      ,COUNT(*)
FROM
(
SELECT [id]
      ,[tcn]
      ,COUNT(*) AS NumRows
FROM #temp
GROUP BY [id], [tcn]
) AS SubQuery
GROUP BY NumRows
ORDER BY NumRows;
*/

