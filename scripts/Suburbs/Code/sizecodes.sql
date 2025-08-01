\timing
-- 01:07 29/07/25 put codehex (desired) before type so it appears in the POI
copy( select st_x(the_geom),st_y(the_geom), cp.label, codehex, cp.type, population_estimate
	FROM :ptable cp
	JOIN :ctable cc
		on cityidx = cityid
	JOIN nz_suburbs_and_localities
		on nzslid = id
	JOIN citysize
		on population_estimate >= pmin 
			and population_estimate < pmax
	where cp.type <> codehex
	order by population_estimate DESC
) to :outfile with CSV;