
/*
[ref].[apcd_zip] - Unique by zip_code - Set primary key to zip_code which clusters by zip_code

Add index by state-county_name for searching
select [zip_code]
from [PHClaims].[ref].[apcd_zip]
where [state] = 'WA' and [county_name] = 'King';
*/

alter table [ref].[apcd_zip] alter column [zip_code] varchar(5) not null;
go
alter table [ref].[apcd_zip] add constraint [PK_ref_apcd_zip] primary key([zip_code]);
go
create nonclustered index [idx_nc_apcd_zip_state_county_code]
on [ref].[apcd_zip]([state], [county_code]);
go

/*
[ref].[kc_claim_type_crosswalk]
*/

create unique clustered index [idx_cl_kc_claim_type_crosswalk_source_desc_source_clm_type_id]
on [ref].[kc_claim_type_crosswalk]([source_desc], [source_clm_type_id]);
