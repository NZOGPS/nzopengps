-- 21:44 08/08/23 change name to name_ascii as macrons(?) caused issues
-- 23:37 09/08/23 group by gid and array_agg the names to remove multiple points
\timing
copy( select st_x(the_geom),st_y(the_geom), cp.label,city,cityid
	from :ptable cp 
	join :ctable cc on cc.label = cp.label
	where type = '0xb00' and cityidx=0
	and st_contains(stbound,the_geom)
	and city = '' ) 
to :outfile with CSV;
