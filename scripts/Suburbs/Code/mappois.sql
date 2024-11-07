-- 21:44 08/08/23 change name to name_ascii as macrons(?) caused issues
-- 23:37 09/08/23 group by gid and array_agg the names to remove multiple points

-- 7:26 pm 6/11/2024 huh? just read above comment. Was it copied? 
--		current issue in this file is that cities can match multiple POI. Less so if you include iscity=0
\timing
copy( select st_x(the_geom),st_y(the_geom), cp.label,city,cityid
	from :ptable cp 
	join :ctable cc on cc.label = cp.label
	where itype <= 4352 
		and cityidx = 0
		and iscity = 'Y'
		and st_contains(stbound,the_geom)
) to :outfile with CSV;
