/*
This function gets inpatient stays as denominator events for the FUH (Follow-up After Hospitalization for Mental Illness)

LOGIC: Acute Inpatient Stays with a Mental Illness Principal Diagnosis
Principal diagnosis in Mental Illness Value Set
INTERSECT
(
Inpatient Stay Value Set
EXCEPT
Nonacute Inpatient Stay
)

Author: Philip Sylling
Last Modified: 2019-04-25

Returns:
 [id]
,[age]
,[tcn]
,[from_date]
,[to_date]
,[flag], = 1
*/

USE PHClaims;
GO

IF OBJECT_ID('[stage].[fn_perf_fuh_inpatient_index_stay]', 'IF') IS NOT NULL
DROP FUNCTION [stage].[fn_perf_fuh_inpatient_index_stay];
GO
CREATE FUNCTION [stage].[fn_perf_fuh_inpatient_index_stay]
(@measurement_start_date DATE
,@measurement_end_date DATE
,@age INT
,@dx_value_set_name VARCHAR(100))
RETURNS TABLE 
AS
RETURN
/*
SELECT [value_set_name]
      ,[code_system]
      ,COUNT([code])
FROM [ref].[hedis_code_system]
WHERE [value_set_name] IN
('Mental Illness'
,'Inpatient Stay'
,'Nonacute Inpatient Stay')
GROUP BY [value_set_name], [code_system]
ORDER BY [value_set_name], [code_system];
*/

WITH [get_claims] AS
(
/*
Mental Illness Value Set does not include ICD9CM diagnosis codes
*/
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
-- Principal Diagnosis
AND dx.[dx_number] = 1
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] = @dx_value_set_name
--ON [value_set_name] IN ('Mental Illness')
AND hed.[code_system] = 'ICD10CM'
AND dx.[dx_ver] = 10 
AND dx.[dx_norm] = hed.[code]
WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[to_date] BETWEEN @measurement_start_date AND DATEADD(DAY, -30, @measurement_end_date)
--WHERE hd.[to_date] BETWEEN '2017-01-01' AND '2017-12-01'

INTERSECT

(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Inpatient Stay')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]
WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[to_date] BETWEEN @measurement_start_date AND DATEADD(DAY, -30, @measurement_end_date)
--WHERE hd.[to_date] BETWEEN '2017-01-01' AND '2017-12-01'

EXCEPT

(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Nonacute Inpatient Stay')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]
WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[to_date] BETWEEN @measurement_start_date AND DATEADD(DAY, -30, @measurement_end_date)
--WHERE hd.[to_date] BETWEEN '2017-01-01' AND '2017-12-01'

UNION

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Nonacute Inpatient Stay')
AND hed.[code_system] = 'UBTOB' 
AND hd.[bill_type_code] = hed.[code]
WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[to_date] BETWEEN @measurement_start_date AND DATEADD(DAY, -30, @measurement_end_date)
--WHERE hd.[to_date] BETWEEN '2017-01-01' AND '2017-12-01'
))),

[age_x_year_old] AS
(
SELECT 
 cl.[id]
,DATEDIFF(YEAR, elig.[dobnew], cl.[from_date]) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, elig.[dobnew], cl.[from_date]), elig.[dobnew]) > cl.[from_date] THEN 1 ELSE 0 END AS [age]
,[tcn]
,[from_date]
,[to_date]
,[flag]
FROM [get_claims] AS cl
INNER JOIN [dbo].[mcaid_elig_demoever] AS elig
ON cl.[id] = elig.[id]
WHERE DATEDIFF(YEAR, elig.[dobnew], cl.[from_date]) - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, elig.[dobnew], cl.[from_date]), elig.[dobnew]) > cl.[from_date] THEN 1 ELSE 0 END >= @age
)

SELECT *
FROM [age_x_year_old];
GO

/*
IF OBJECT_ID('tempdb..#temp', 'U') IS NOT NULL
DROP TABLE #temp;
SELECT * INTO #temp FROM [stage].[fn_perf_fuh_inpatient_index_stay]('2017-01-01', '2017-12-31', 6, 'Mental Illness');
*/