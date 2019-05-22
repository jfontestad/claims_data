/*
This view gets claims that meet the requirements for the DSHS RDA Substance Use
Disorder Treatment Penetration (Opioid) rate denominator.

Author: Philip Sylling
Created: 2019-05-22
Last Modified: 2019-05-22

Returns:
 [id]
,[tcn]
,[from_date], [FROM_SRVC_DATE]
,[flag], 1 for claim meeting denominator criteria
*/

USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_tpo_denominator]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_tpo_denominator];
GO
CREATE VIEW [stage].[v_perf_tpo_denominator]
AS

/*
SELECT [value_set_group]
      ,[value_set_name]
      ,[data_source_type]
      ,[code_set]
	  ,[active]
      ,COUNT([code])
FROM [ref].[rda_value_set]
WHERE [value_set_group] = 'OUD'
GROUP BY [value_set_group], [value_set_name], [data_source_type], [code_set], [active]
ORDER BY [value_set_group], [value_set_name], [data_source_type], [code_set], [active];

SELECT [value_set_group]
      ,[value_set_name]
      ,[data_source_type]
      ,[code_set]
	  ,[active]
      ,[code]
FROM [ref].[rda_value_set]
WHERE [value_set_group] = 'OUD'
ORDER BY 
 [value_set_group]
,[value_set_name]
,[data_source_type]
,[code_set]
,[active]
,[code];
*/

/*
1. Diagnosis of OUD in any health service event (OUD-Tx-Pen-Value-Set-1)
SELECT * 
FROM [ref].[rda_value_set] AS rda
WHERE rda.[value_set_name] = 'OUD-Tx-Pen-Value-Set-1';
*/

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
--,ym.[year_month]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
-- Any diagnosis (not restricted to primary)
INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
INNER JOIN [ref].[rda_value_set] AS rda
ON rda.[value_set_name] = 'OUD-Tx-Pen-Value-Set-1'
AND rda.[code_set] = 'ICD10CM'
AND dx.[dx_ver] = 10 
AND dx.[dx_norm] = rda.[code]
--INNER JOIN [ref].[perf_year_month] AS ym
--ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
WHERE hd.[from_date] >= '2015-10-01'
--WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[from_date] BETWEEN CAST(DATEADD(YEAR, -1, @measurement_start_date) AS DATE) AND @measurement_end_date

UNION

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
--,ym.[year_month]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
-- Any diagnosis (not restricted to primary)
INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
INNER JOIN [ref].[rda_value_set] AS rda
ON rda.[value_set_name] = 'OUD-Tx-Pen-Value-Set-1'
AND rda.[code_set] = 'ICD9CM'
AND dx.[dx_ver] = 9 
AND dx.[dx_norm] = rda.[code]
--INNER JOIN [ref].[perf_year_month] AS ym
--ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
WHERE hd.[from_date] < '2015-10-01'
--WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[from_date] BETWEEN CAST(DATEADD(YEAR, -1, @measurement_start_date) AS DATE) AND @measurement_end_date

UNION

/*
2. Receipt of a medication meeting numerator criteria: NDC codes indicating 
receipt of other forms of medication assisted treatment for 
OUD: OUD-Tx-Pen-Value-Set-2
SELECT * 
FROM [ref].[rda_value_set] AS rda
WHERE rda.[value_set_name] = 'OUD-Tx-Pen-Value-Set-2';
*/

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
--,ym.[year_month]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_pharm] AS ph
ON hd.[tcn] = ph.[tcn]
INNER JOIN [ref].[rda_value_set] AS rda
ON rda.[value_set_name] = 'OUD-Tx-Pen-Value-Set-2'
AND rda.[code_set] = 'NDC'
AND rda.[active] = 'Y'
AND ph.[ndc_code] = rda.[code]
--INNER JOIN [ref].[perf_year_month] AS ym
--ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
--WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[from_date] BETWEEN CAST(DATEADD(YEAR, -1, @measurement_start_date) AS DATE) AND @measurement_end_date

UNION

/*
3. Receipt of methadone opiate substitution treatment indicated by an 
outpatient encounter with procedure code H0020
SELECT * 
FROM [ref].[rda_value_set] AS rda
WHERE rda.[value_set_name] = 'OUD-Tx-Pen-Receipt-of-MAT';
*/

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
--,ym.[year_month]
,1 AS [flag]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]
INNER JOIN [ref].[rda_value_set] AS rda
ON rda.[value_set_name] = 'OUD-Tx-Pen-Receipt-of-MAT'
AND rda.[code_set] IN ('HCPCS')
AND pr.[pcode] = rda.[code]
--INNER JOIN [ref].[perf_year_month] AS ym
--ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
--WHERE hd.[from_date] BETWEEN @measurement_start_date AND @measurement_end_date
--WHERE hd.[from_date] BETWEEN CAST(DATEADD(YEAR, -1, @measurement_start_date) AS DATE) AND @measurement_end_date
GO

/*
-- 2,654,113
SELECT COUNT(*) FROM [stage].[v_perf_tpo_denominator];
*/