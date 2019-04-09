
USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_ed_visit_num]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_ed_visit_num];
GO
CREATE VIEW [stage].[v_perf_ed_visit_num] 
AS
/*
DSRIP Guidance
All emergency department visits contribute to the metric 
(e.g. an individual may have multiple emergency department 
visits on the same day and each is counted as an event, as 
long as they are on separate claims).

Each ED visit appears to have a distinct tcn

-- Both 1,178,287
SELECT COUNT(DISTINCT tcn) FROM [stage].[v_perf_ed_visit_num];
SELECT COUNT(tcn) FROM [stage].[v_perf_ed_visit_num];
*/

SELECT 
 ym.[year_month]
,hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [ed_visit_num]
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
WHERE hd.[clm_type_code] IN ('3', '26', '34')
  AND hd.[pos_code] IN ('23')
  
UNION

SELECT 
 ym.[year_month]
,hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [ed_visit_num]
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
WHERE hd.[clm_type_code] IN ('3', '26', '34')
  AND ln.[rcode] IN ('0450', '0451', '0452', '0456', '0459')
  
UNION

SELECT 
 ym.[year_month]
,hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]
,1 AS [ed_visit_num]
FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
WHERE hd.[clm_type_code] IN ('3', '26', '34')
  AND pr.[pcode] IN ('99281', '99282', '99283', '99284', '99285', '99288');
GO

/*
SELECT COUNT(*) FROM [stage].[v_perf_ed_visit_num];
*/