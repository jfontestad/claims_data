
USE PHClaims;
GO

IF OBJECT_ID('[stage].[mcaid_claim_value_set]') IS NOT NULL
DROP TABLE [stage].[mcaid_claim_value_set];
CREATE TABLE [stage].[mcaid_claim_value_set]
([value_set_group] VARCHAR(20) NULL
,[value_set_name] VARCHAR(100) NOT NULL
,[data_source_type] VARCHAR(50) NULL
,[sub_group] VARCHAR(50) NULL
,[code_set] VARCHAR(50) NOT NULL
,[primary_dx_only] CHAR(1) NULL
,[id_mcaid] VARCHAR(255) NOT NULL
,[claim_header_id] BIGINT NULL
,[service_date] DATE NULL)
ON [PRIMARY];
GO
