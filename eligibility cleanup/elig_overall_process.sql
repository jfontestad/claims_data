-- Code to create an overall record of a person's Medicaid eligibility
-- Alastair Matheson (PHSKC-APDE)
-- 2017-05, updated 2018-02-12 to account for sub-month coverage

-- Code collapses data from 1+ rows per person per month to a single row of contiguous coverage per person
-- Takes ~3m40s to run

-- Remove existing table
IF OBJECT_ID('dbo.mcaid_elig_overall', 'U') IS NOT NULL 
  DROP TABLE dbo.mcaid_elig_overall;

-- Collapse to single row again
SELECT h.id,
	MIN(h.from_date) AS from_date,
	MAX(h.to_date) AS to_date,
	DATEDIFF(dd, MIN(h.from_date), MAX(h.to_date)) + 1 AS cov_time_day
INTO PHClaims.dbo.mcaid_elig_overall
FROM (
	-- Set up groups where there is contiguous coverage
	SELECT g.id,
		g.from_date,
		g.to_date,
		g.group_num,
		g.group_num2,
		SUM(CASE WHEN g.group_num2 IS NULL THEN 0 ELSE 1 END) OVER
			(ORDER BY g.temp_row ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS group_num3
	FROM (
		-- Set up flag for when there is a break in coverage
		SELECT f.id,
		f.group_num,
			CASE 
				WHEN f.from_date - lag(f.to_date) OVER (PARTITION BY f.id ORDER BY f.id, f.from_date) <= 1 THEN NULL
				ELSE ROW_NUMBER() OVER (PARTITION BY f.id ORDER BY f.from_date)
				END AS group_num2,
			ROW_NUMBER() OVER (ORDER BY f.id, f.from_date, f.to_date) AS temp_row,
			f.from_date,
			f.to_date			
		FROM (
			-- Use the from and to date info to find sub-month coverage
			SELECT e.id,
				e.group_num,
				CASE 
					WHEN e.startdate >= e.fromdate THEN e.startdate
					WHEN e.startdate < e.fromdate THEN e.fromdate
					ELSE NULL
					END AS from_date,
				CASE 
					WHEN e.enddate <= e.todate THEN e.enddate
					WHEN e.enddate > e.todate THEN e.todate
					ELSE NULL
					END AS to_date
			FROM (
				-- Now take the max and min of each ID/contiguous date combo to collapse to one row
				SELECT d.id,					
					MIN(calmonth) AS startdate,
					DATEADD(day, - 1, DATEADD(month, 1, MAX(calmonth))) AS enddate,
					d.group_num,
					d.fromdate,
					d.todate
				FROM (
					-- Keep just the variables formed in the select statement below
					SELECT DISTINCT c.id,
						c.calmonth,
						c.group_num,
						c.fromdate,
						c.todate
					FROM
						-- This sets assigns a contiguous set of months to the same group number per id
						(
						SELECT DISTINCT b.id,
							b.calmonth,
							DATEDIFF(MONTH, 0, calmonth) - 
								ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY calmonth) AS group_num,
							b.fromdate,
							b.todate
						FROM
							-- Start here by pulling out the row per month data and converting the row per month field into a date
							(
							SELECT DISTINCT a.MEDICAID_RECIPIENT_ID AS id,
								CONVERT(DATETIME, a.CLNDR_YEAR_MNTH + '01', 112) AS calmonth,
								a.FROM_DATE AS fromdate,
								a.TO_DATE AS todate
							FROM 
							(SELECT * FROM
							[PHClaims].[dbo].[NewEligibility]) a
							) b
						) c
					) d
				GROUP BY d.id, d.group_num, d.fromdate, d.todate
				) e
			) f
		) g
	) h
GROUP BY h.id, h.group_num3
ORDER BY h.id, from_date