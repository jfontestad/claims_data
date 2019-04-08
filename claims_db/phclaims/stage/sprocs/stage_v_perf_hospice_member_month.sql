
USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_hospice_member_month]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_hospice_member_month];
GO
CREATE VIEW [stage].[v_perf_hospice_member_month]
AS
/*
SELECT [value_set_name]
      ,[code_system]
      ,COUNT([code])
FROM [ref].[hedis_code_system]
WHERE [value_set_name] = 'Hospice'
GROUP BY [value_set_name], [code_system];
*/
WITH CTE AS
(
SELECT 
 ym.[year_month]
,hd.[id]
--,hd.[tcn]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Hospice')
AND hed.[code_system] = 'UBTOB' 
AND hd.[bill_type_code] = hed.[code]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]

UNION

SELECT 
 ym.[year_month]
,hd.[id]
--,hd.[tcn]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Hospice')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]

UNION 

SELECT
 ym.[year_month]
,hd.[id]
--,hd.[tcn]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed 
 ON [value_set_name] IN
('Hospice')
AND hed.[code_system] = 'CPT'
AND pr.[pcode] = hed.[code]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]

UNION

SELECT
 ym.[year_month]
,hd.[id]
--,hd.[tcn]

FROM [dbo].[mcaid_claim_header] AS hd
INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]
INNER JOIN [ref].[hedis_code_system] AS hed 
 ON [value_set_name] IN
('Hospice')
AND hed.[code_system] = 'HCPCS'
AND pr.[pcode] = hed.[code]
INNER JOIN [ref].[perf_year_month] AS ym
ON hd.[from_date] BETWEEN ym.[beg_month] AND ym.[end_month]
)

SELECT
 [year_month]
,[id]
,1 AS [hospice_flag]
FROM CTE;
GO

/*
SELECT 
 [year_month]
,COUNT(*)
FROM [stage].[v_perf_hospice_member_month]
GROUP BY [year_month];
*/