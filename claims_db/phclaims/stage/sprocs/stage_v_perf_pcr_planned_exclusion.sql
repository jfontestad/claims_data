/*
This view gets claims that meet the requirements for Planned Hospital Stays.
These stays should not be counted as Hospital Readmissions.

Author: Philip Sylling
Created: 2019-04-30
Last Modified: 2019-04-30

Logic:
SELECT

((('Inpatient Stay')
FOR
('Bone Marrow Transplant'
,'Chemotherapy'
,'Kidney Transplant'
,'Organ Transplant Other Than Kidney'
,'Rehabilitation'))

UNION

(('Inpatient Stay')
FOR
('Potentially Planned Procedures'))
EXCEPT
(('Inpatient Stay')
FOR
('Acute Condition')))

EXCEPT

('Nonacute Inpatient Stay')

Returns:
 [id]
,[tcn]
,[from_date], [FROM_SRVC_DATE]
,[to_date], [TO_SRVC_DATE]
,[flag], 1 for claim meeting planned hospital stay criteria
*/

USE PHClaims;
GO

IF OBJECT_ID('[stage].[v_perf_pcr_planned_exclusion]', 'V') IS NOT NULL
DROP VIEW [stage].[v_perf_pcr_planned_exclusion];
GO
CREATE VIEW [stage].[v_perf_pcr_planned_exclusion]
AS
/*
SELECT 
 [value_set_name]
,[code_system]
,COUNT([code])
FROM [ref].[hedis_code_system]
WHERE [value_set_name] IN
('Chemotherapy'
,'Rehabilitation'
,'Kidney Transplant'
,'Bone Marrow Transplant'
,'Organ Transplant Other Than Kidney'
,'Potentially Planned Procedures'
,'Acute Condition')
GROUP BY [value_set_name], [code_system]
ORDER BY [code_system], [value_set_name];
*/

/*
Exclude any hospital stay as an Index Hospital Stay if the admission date of 
the first stay within 30 days meets any of the following criteria:
A principal diagnosis of maintenance chemotherapy (Chemotherapy Value Set).
A principal diagnosis of rehabilitation (Rehabilitation Value Set).
An organ transplant (Kidney Transplant Value Set, Bone Marrow Transplant Value 
Set, Organ Transplant Other Than Kidney Value Set).
A potentially planned procedure (Potentially Planned Procedures Value Set) 
without a principal acute diagnosis (Acute Condition Value Set).
*/

/*
Diagnosis Codes for
A principal diagnosis of maintenance chemotherapy (Chemotherapy Value Set).
A principal diagnosis of rehabilitation (Rehabilitation Value Set).
An organ transplant (Kidney Transplant Value Set).
*/

WITH [get_claims] AS
((
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
AND dx.[dx_number] = 1
AND dx.[dx_ver] = 10

INNER JOIN [ref].[hedis_code_system] AS hed_rev
ON hed_rev.[value_set_name] IN 
('Inpatient Stay')
AND hed_rev.[code_system] = 'UBREV'
AND ln.[rcode] = hed_rev.[code]

INNER JOIN [ref].[hedis_code_system] AS hed_dx
ON hed_dx.[value_set_name] IN 
('Chemotherapy'
,'Kidney Transplant'
,'Rehabilitation')
AND hed_dx.[code_system] = 'ICD10CM' 
AND dx.[dx_norm] = hed_dx.[code]

UNION

/*
Procedure Codes for
An organ transplant (Kidney Transplant Value Set, Bone Marrow Transplant Value 
Set, Organ Transplant Other Than Kidney Value Set).
*/
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]

INNER JOIN [ref].[hedis_code_system] AS hed_rev
ON hed_rev.[value_set_name] IN 
('Inpatient Stay')
AND hed_rev.[code_system] = 'UBREV'
AND ln.[rcode] = hed_rev.[code]

INNER JOIN [ref].[hedis_code_system] AS hed_pr
ON hed_pr.[value_set_name] IN 
('Bone Marrow Transplant'
,'Kidney Transplant'
,'Organ Transplant Other Than Kidney')
AND hed_pr.[code_system] IN ('CPT', 'HCPCS', 'ICD10PCS')
AND pr.[pcode] = hed_pr.[code]

UNION

/*
Revenue Codes for
An organ transplant (Kidney Transplant Value Set, Organ Transplant Other Than 
Kidney Value Set).
*/
(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [ref].[hedis_code_system] AS hed
ON hed.[value_set_name] IN 
('Inpatient Stay')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]

INTERSECT

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [ref].[hedis_code_system] AS hed
ON hed.[value_set_name] IN 
('Kidney Transplant'
,'Organ Transplant Other Than Kidney')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]
)

UNION

/*
A potentially planned procedure (Potentially Planned Procedures Value Set) 
without a principal acute diagnosis (Acute Condition Value Set).
*/
(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [dbo].[mcaid_claim_proc] AS pr
ON hd.[tcn] = pr.[tcn]

INNER JOIN [ref].[hedis_code_system] AS hed_rev
ON hed_rev.[value_set_name] IN 
('Inpatient Stay')
AND hed_rev.[code_system] = 'UBREV'
AND ln.[rcode] = hed_rev.[code]

INNER JOIN [ref].[hedis_code_system] AS hed_pr
ON hed_pr.[value_set_name] IN 
('Potentially Planned Procedures')
AND hed_pr.[code_system] IN ('ICD10PCS')
AND pr.[pcode] = hed_pr.[code]

EXCEPT

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [dbo].[mcaid_claim_dx] AS dx
ON hd.[tcn] = dx.[tcn]
AND dx.[dx_number] = 1
AND dx.[dx_ver] = 10

INNER JOIN [ref].[hedis_code_system] AS hed_rev
ON hed_rev.[value_set_name] IN 
('Inpatient Stay')
AND hed_rev.[code_system] = 'UBREV'
AND ln.[rcode] = hed_rev.[code]

INNER JOIN [ref].[hedis_code_system] AS hed_dx
ON hed_dx.[value_set_name] IN 
('Acute Condition')
AND hed_dx.[code_system] = 'ICD10CM' 
AND dx.[dx_norm] = hed_dx.[code]
))

/*
Only 0.3% of the above planned stays are non-acute.
The EXCEPT below removes these non-acute stays.
To include non-acute stays, the below EXCEPT should be commented out.
*/

EXCEPT

(
SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [dbo].[mcaid_claim_line] AS ln
ON hd.[tcn] = ln.[tcn]

INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Nonacute Inpatient Stay')
AND hed.[code_system] = 'UBREV'
AND ln.[rcode] = hed.[code]

UNION

SELECT 
 hd.[id]
,hd.[tcn]
,hd.[from_date]
,hd.[to_date]

FROM [dbo].[mcaid_claim_header] AS hd

INNER JOIN [ref].[hedis_code_system] AS hed
ON [value_set_name] IN 
('Nonacute Inpatient Stay')
AND hed.[code_system] = 'UBTOB' 
AND hd.[bill_type_code] = hed.[code]
))

SELECT
 [id]
,[tcn]
,[from_date]
,[to_date]
,1 AS [flag]
FROM [get_claims];
GO

/*
SELECT * FROM [stage].[v_perf_pcr_planned_exclusion];
*/