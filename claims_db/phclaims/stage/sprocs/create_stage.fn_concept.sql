
USE [PHClaims];
GO

IF OBJECT_ID('[stage].[fn_concept]', 'IF') IS NOT NULL
DROP FUNCTION [stage].[fn_concept];
GO
CREATE FUNCTION [stage].[fn_concept](@measurement_start_date DATE, @measurement_end_date DATE)
RETURNS TABLE 
AS
RETURN

SELECT
 REPLACE(b.[measure_name], 'Penetration', 'Need') AS [concept_name]
,@measurement_start_date AS [start_date]
,@measurement_end_date AS [end_date]
,[id_mcaid]
,1 AS [flag]
FROM [stage].[perf_staging] AS a

INNER JOIN [ref].[perf_measure] AS b
ON a.[measure_id] = b.[measure_id]

INNER JOIN 
(
SELECT DISTINCT 
 [year_month]
,[first_day_month]
,[last_day_month]
FROM [ref].[date]
) AS day_month
ON a.[year_month] = day_month.[year_month]

WHERE 1 = 1
AND [num_denom] = 'D'
AND [measure_value] = 1
AND [measure_name] IN
('Mental Health Treatment Penetration'
,'SUD Treatment Penetration (Opioid)'
,'SUD Treatment Penetration')
AND day_month.[first_day_month] BETWEEN  @measurement_start_date AND @measurement_end_date

UNION

SELECT
 CASE 
 WHEN a.[sub_group] = 'ADHD' THEN 'ADHD'
 WHEN a.[sub_group] = 'ADHD Rx' THEN 'ADHD'
 WHEN a.[sub_group] = 'Adjustment' THEN 'Adjustment'
 WHEN a.[sub_group] = 'Anxiety' THEN 'Anxiety'
 WHEN a.[sub_group] = 'Antianxiety Rx' THEN 'Anxiety'
 WHEN a.[sub_group] = 'Depression' THEN 'Depression'
 WHEN a.[sub_group] = 'Antidepressants Rx' THEN 'Depression'
 WHEN a.[sub_group] = 'Disrup/Impulse/Conduct' THEN 'Disruptive/Impulsive/Conduct'
 WHEN a.[sub_group] = 'Mania/Bipolar' THEN 'Mania/Bipolar'
 WHEN a.[sub_group] = 'Antimania Rx' THEN 'Mania/Bipolar'
 WHEN a.[sub_group] = 'Psychotic' THEN 'Psychotic'
 WHEN a.[sub_group] = 'Antipsychotic Rx' THEN 'Psychotic'
 END AS [concept_name]
,@measurement_start_date AS [start_date]
,@measurement_end_date AS [end_date]
,[id_mcaid]
,1 AS [flag]
FROM [stage].[mcaid_claim_value_set] AS a

WHERE 1 = 1
AND (([value_set_name] = 'MH-Dx-value-set' AND [data_source_type] = 'Diagnosis') OR
    ([value_set_name] = 'MH-Rx-value-set' AND [data_source_type] = 'Pharmacy'))
AND a.[service_date] BETWEEN  @measurement_start_date AND @measurement_end_date;

GO

/*
SELECT TOP(100) *
FROM [stage].[fn_concept]('2016-01-01', '2017-12-31');
*/