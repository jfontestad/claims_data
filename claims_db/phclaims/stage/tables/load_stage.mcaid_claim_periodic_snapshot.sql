
USE [PHClaims];
GO

/*
IF OBJECT_ID('[stage].[sp_load_mcaid_claim_periodic_snapshot]','P') IS NOT NULL
DROP PROCEDURE [stage].[sp_load_mcaid_claim_periodic_snapshot];
GO
CREATE PROCEDURE [stage].[sp_load_mcaid_claim_periodic_snapshot]
AS
SET NOCOUNT ON;

BEGIN
*/

DECLARE 
 @start_year_quarter INT = 201201
,@end_year_quarter INT = 201902;

IF OBJECT_ID('tempdb..#year_quarter') IS NOT NULL
DROP TABLE #year_quarter;
SELECT DISTINCT
 [quarter]
,[quarter_name]
,[year_quarter]
,[first_day_quarter]
,[last_day_quarter]
INTO #year_quarter
FROM [ref].[date]
WHERE [year_quarter] BETWEEN @start_year_quarter AND @end_year_quarter;
CREATE CLUSTERED INDEX idx_cl_#year_quarter
ON #year_quarter([first_day_quarter], [last_day_quarter]);

IF OBJECT_ID('tempdb..#year_month') IS NOT NULL
DROP TABLE #year_month;
CREATE TABLE #year_month
([measure_period_id] INT IDENTITY(1,1)
,[year_month] INT
,[year_quarter] INT);
INSERT INTO #year_month([year_month], [year_quarter])
SELECT DISTINCT
 [year_month]
,[year_quarter]
FROM [ref].[date]
WHERE [month] IN (3, 6, 9, 12)
AND [year_quarter] BETWEEN @start_year_quarter AND @end_year_quarter
ORDER BY [year_month];
CREATE CLUSTERED INDEX idx_cl_#year_month
ON #year_month([year_quarter]);

/*
SELECT * FROM #year_quarter ORDER BY [first_day_quarter], [last_day_quarter];
SELECT * FROM #year_month ORDER BY [year_quarter];
*/

/*
Step 1:
Aggregate [ed_pophealth] to member-quarter level.
*/
IF OBJECT_ID('tempdb..#ed_pophealth') IS NOT NULL
DROP TABLE #ed_pophealth;
SELECT
--TOP(1000)
 [year_quarter]
,[id_mcaid]
,SUM([ed_pophealth]) AS [ed_pophealth]
INTO #ed_pophealth

FROM (
SELECT 
 [id_mcaid]
,[episode_first_service_date]
,COUNT(DISTINCT [ed_pophealth_id]) AS [ed_pophealth]
FROM [tmp].[mcaid_ed_yale_final_philip]
GROUP BY
 [id_mcaid]
,[episode_first_service_date]
) AS a

INNER JOIN #year_quarter AS c
ON a.[episode_first_service_date] BETWEEN c.[first_day_quarter] AND c.[last_day_quarter]

GROUP BY
 [year_quarter]
,[id_mcaid];
CREATE CLUSTERED INDEX idx_cl_#ed_pophealth
ON #ed_pophealth([id_mcaid], [year_quarter]);

/*
Step 2:
In order to sum total utilization within rolling 4-quarter windows,
it is necessary to create empty/placeholder [year_quarter] rows
for [id_mcaid] values.

This enables use of the window function below:
,SUM(a.[ed_pophealth]) OVER(PARTITION BY a.[id_mcaid] ORDER BY a.[year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [ed_pophealth]

The empty/placeholder [year_quarter] rows are necessary for 
ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
to work properly.

The empty/placeholder [year_quarter] rows are created by
(SELECT DISTINCT [id_mcaid] FROM #ed_pophealth) AS a CROSS JOIN #year_quarter AS b LEFT JOIN #ed_pophealth AS c
*/
IF OBJECT_ID('tempdb..#ed_pophealth_by_year_quarter') IS NOT NULL
DROP TABLE #ed_pophealth_by_year_quarter;
SELECT
 b.[year_quarter]
,a.[id_mcaid]
,c.[ed_pophealth]
INTO #ed_pophealth_by_year_quarter
FROM (SELECT DISTINCT [id_mcaid] FROM #ed_pophealth) AS a
CROSS JOIN #year_quarter AS b
LEFT JOIN #ed_pophealth AS c
ON a.[id_mcaid] = c.[id_mcaid]
AND b.[year_quarter] = c.[year_quarter];
CREATE CLUSTERED INDEX idx_cl_#ed_pophealth_by_year_quarter
ON #ed_pophealth_by_year_quarter([id_mcaid], [year_quarter]);

/*
Step 3:
SUM(a.[ed_pophealth]) within a 4-quarter window.
*/
IF OBJECT_ID('tempdb..#ed_pophealth_t_12_m') IS NOT NULL
DROP TABLE #ed_pophealth_t_12_m;
WITH CTE AS
(
SELECT
 c.[beg_measure_year_month] AS [beg_year_month]
,b.[year_month] AS [end_year_month]
,a.[id_mcaid]
,SUM(a.[ed_pophealth]) OVER(PARTITION BY a.[id_mcaid] ORDER BY a.[year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [ed_pophealth_t_12_m]

FROM #ed_pophealth_by_year_quarter AS a
INNER JOIN #year_month AS b
ON a.[year_quarter] = b.[year_quarter]
INNER JOIN [ref].[perf_year_month] AS c
ON b.[year_month] = c.[year_month]
)
SELECT 
 [beg_year_month]
,[end_year_month]
,[id_mcaid]
,[ed_pophealth_t_12_m]
INTO #ed_pophealth_t_12_m
FROM CTE
WHERE [ed_pophealth_t_12_m] IS NOT NULL;
CREATE CLUSTERED INDEX idx_cl_#ed_pophealth_t_12_m
ON #ed_pophealth_t_12_m([id_mcaid], [end_year_month]);

/*
Step 4:
JOIN [final].[mcaid_claim_icdcm_header] to [ref].[comorb_value_set] to #year_quarter
and GROUP BY [year_quarter], [id_mcaid], [cond_id].
This table will have an Indicator/Weight for Person by Quarter by Condition.
*/
IF OBJECT_ID('tempdb..#comorb_value_set') IS NOT NULL
DROP TABLE #comorb_value_set;
SELECT
--TOP(1000)
 [year_quarter]
,[id_mcaid]
,[cond_id]
,[elixhauser_wgt]
,[charlson_wgt]
,[gagne_wgt]
,SUM([flag]) AS [flag]
INTO #comorb_value_set
FROM [final].[mcaid_claim_icdcm_header] AS a
INNER JOIN [ref].[comorb_value_set] AS b
ON a.[icdcm_version] = b.[dx_ver]
AND a.[icdcm_norm] = b.[dx]
INNER JOIN #year_quarter AS c
ON a.[first_service_date] BETWEEN c.[first_day_quarter] AND c.[last_day_quarter]
GROUP BY
 [year_quarter]
,[id_mcaid]
,[cond_id]
,[elixhauser_wgt]
,[charlson_wgt]
,[gagne_wgt];
CREATE CLUSTERED INDEX idx_cl_#comorb_value_set 
ON #comorb_value_set([id_mcaid], [cond_id], [year_quarter]);

/*
Step 5:
In order to calculate scores within rolling 4-quarter windows,
it is necessary to create empty/placeholder [year_quarter] rows
for [id_mcaid] by [cond_id] combinations.

This enables use of the window function below:
MAX([elixhauser_wgt]) OVER(PARTITION BY [id_mcaid], [cond_id] ORDER BY [year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [elixhauser_t_12_m]

The empty/placeholder [year_quarter] rows are necessary for 
ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
to work properly.

The empty/placeholder [year_quarter] rows are created by
(SELECT DISTINCT [id_mcaid], [cond_id] FROM #comorb_value_set) AS a CROSS JOIN #year_quarter AS b LEFT JOIN #comorb_value_set AS c
*/

IF OBJECT_ID('tempdb..#comorb_value_set_by_year_quarter') IS NOT NULL
DROP TABLE #comorb_value_set_by_year_quarter;
SELECT
 b.[year_quarter]
,a.[id_mcaid]
,a.[cond_id]
,c.[elixhauser_wgt]
,c.[charlson_wgt]
,c.[gagne_wgt]
INTO #comorb_value_set_by_year_quarter
FROM (SELECT DISTINCT [id_mcaid], [cond_id] FROM #comorb_value_set) AS a
CROSS JOIN #year_quarter AS b
LEFT JOIN #comorb_value_set AS c
ON a.[id_mcaid] = c.[id_mcaid]
AND a.[cond_id] = c.[cond_id]
AND b.[year_quarter] = c.[year_quarter];
CREATE CLUSTERED INDEX idx_cl_#comorb_value_set_by_year_quarter
ON #comorb_value_set_by_year_quarter([id_mcaid], [cond_id], [year_quarter]);

/*
Step 6:

First, determine if each cond_id is present a 4-quarter window.
This is done by MAX([elixhauser_wgt]) within each 4-quarter window.

Second, SUM([elixhauser_wgt]) GROUP BY [year_month], [id_mcaid]
to get each weighted score within a 4-quarter window.
*/
IF OBJECT_ID('tempdb..#comorb_t_12_m') IS NOT NULL
DROP TABLE #comorb_t_12_m;
WITH [max_over_window] AS
(
SELECT
 [year_quarter]
,[id_mcaid]
,[cond_id]
--,[elixhauser_wgt]
--,[charlson_wgt]
--,[gagne_wgt]
,MAX([elixhauser_wgt]) OVER(PARTITION BY [id_mcaid], [cond_id] ORDER BY [year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [elixhauser_t_12_m]
,MAX([charlson_wgt]) OVER(PARTITION BY [id_mcaid], [cond_id] ORDER BY [year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [charlson_t_12_m]
,MAX([gagne_wgt]) OVER(PARTITION BY [id_mcaid], [cond_id] ORDER BY [year_quarter] ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS [gagne_t_12_m]
FROM #comorb_value_set_by_year_quarter
),

[sum_over_cond_id] AS
(
SELECT 
 b.[year_month]
,a.[id_mcaid]
,SUM([elixhauser_t_12_m]) AS [elixhauser_t_12_m] 
,SUM([charlson_t_12_m]) AS [charlson_t_12_m] 
,SUM([gagne_t_12_m]) AS [gagne_t_12_m]
FROM [max_over_window] AS a
INNER JOIN #year_month AS b
ON a.[year_quarter] = b.[year_quarter]
GROUP BY
 b.[year_month]
,a.[id_mcaid]
)

SELECT 
 b.[beg_measure_year_month] AS [beg_year_month]
,a.[year_month] AS [end_year_month]
,a.[id_mcaid]
,[elixhauser_t_12_m] 
,[charlson_t_12_m] 
,[gagne_t_12_m]
INTO #comorb_t_12_m
FROM [sum_over_cond_id] AS a
INNER JOIN [ref].[perf_year_month] AS b
ON a.[year_month] = b.[year_month]
WHERE COALESCE([elixhauser_t_12_m], [charlson_t_12_m], [gagne_t_12_m]) IS NOT NULL;
CREATE CLUSTERED INDEX idx_cl_#comorb_t_12_m
ON #comorb_t_12_m([id_mcaid], [end_year_month]);

TRUNCATE TABLE [stage].[mcaid_claim_periodic_snapshot]

INSERT INTO [stage].[mcaid_claim_periodic_snapshot]

SELECT 
--TOP(100)
 b.[measure_period_id]
,a.[beg_year_month]
,a.[end_year_month]
,a.[id_mcaid]
,ISNULL(c.[ed_pophealth_t_12_m], 0) AS [ed_pophealth_t_12_m]
,ISNULL(d.[elixhauser_t_12_m], 0) AS [elixhauser_t_12_m]
,ISNULL(d.[charlson_t_12_m], 0) AS [charlson_t_12_m]
,ISNULL(d.[gagne_t_12_m], 0) AS [gagne_t_12_m]

FROM (SELECT [id_mcaid], [beg_year_month], [end_year_month] FROM #ed_pophealth_t_12_m UNION SELECT [id_mcaid], [beg_year_month], [end_year_month] FROM #comorb_t_12_m) AS a
INNER JOIN #year_month AS b
ON a.[end_year_month] = b.[year_month]
LEFT JOIN #ed_pophealth_t_12_m AS c
ON a.[id_mcaid] = c.[id_mcaid]
AND a.[end_year_month] = c.[end_year_month]
LEFT JOIN #comorb_t_12_m AS d
ON a.[id_mcaid] = d.[id_mcaid]
AND a.[end_year_month] = d.[end_year_month]

ORDER BY a.[id_mcaid], a.[end_year_month];

/*
SELECT COUNT(*) FROM [stage].[mcaid_claim_periodic_snapshot];
*/