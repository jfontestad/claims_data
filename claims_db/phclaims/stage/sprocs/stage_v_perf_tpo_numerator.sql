/*
This view gets claims that meet the requirements for the DSHS RDA Substance Use
Disorder Treatment Penetration (Opioid) rate numerator.

Author: Philip Sylling
Created: 2019-05-22
Last Modified: 2019-05-22

Returns:
 [id]
,[tcn]
,[from_date], [FROM_SRVC_DATE]
,[flag], 1 for claim meeting numerator criteria
*/

USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_tpo_numerator]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_tpo_numerator];
GO
CREATE VIEW [stage].[v_perf_tpo_numerator]
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
Data elements required for numerator:
All eligible individuals receiving at least one qualifying medication in the 
measurement year, based on the NDC codes in OUD-Tx-Pen-Value-Set-2 or an 
outpatient encounter with procedure code H0020
(receipt of methadone opiate substitution treatment).
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
-- 2,084,557
SELECT COUNT(*) FROM [stage].[v_perf_tpo_numerator];
*/


/*
This view gets BHO services that meet the requirements for the DSHS RDA Substance Use
Disorder Treatment Penetration (Opioid) rate numerator.

Author: Philip Sylling
Created: 2019-05-28
Last Modified: 2019-05-28

Returns:
 [kcid]
,[ea_cpt_service_id]
,[tcn]
,[event_date]
,[flag], 1 for service meeting numerator criteria
*/

USE [DCHS_Analytics];
GO

IF OBJECT_ID('[stage].[v_perf_bho_tpo_numerator]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_bho_tpo_numerator];
GO
CREATE VIEW [stage].[v_perf_bho_tpo_numerator]
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
Data elements required for numerator:
All eligible individuals receiving at least one qualifying medication in the 
measurement year, based on the NDC codes in OUD-Tx-Pen-Value-Set-2 or an 
outpatient encounter with procedure code H0020
(receipt of methadone opiate substitution treatment).
*/

/*
There are no NDC Codes in the BHO database
*/

SELECT
--TOP(100)
 svc.[kcid]
,svc.[ea_cpt_service_id]
,svc.[tcn]
,svc.[event_date]
,1 AS [flag]

--SELECT COUNT(*)
FROM [php96].[service_procedure] AS svc
INNER JOIN [ref].[rda_value_set] AS rda
ON rda.[value_set_group] = 'OUD'
AND rda.[value_set_name] = 'OUD-Tx-Pen-Receipt-of-MAT'
AND rda.[data_source_type] = 'Procedure'
AND rda.[code_set] IN ('HCPCS')
AND svc.[pcode] = rda.[code];
GO

/*
-- 3,560,468
SELECT COUNT(*) FROM [stage].[v_perf_bho_tpo_numerator];
*/