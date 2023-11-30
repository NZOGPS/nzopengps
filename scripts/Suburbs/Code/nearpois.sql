\timing
copy( select st_x(the_geom),st_y(the_geom), cp.label,city,cityid,st_distance(st_transform(stbound,2193),st_transform(the_geom,2193)) as sd
	from :ptable cp 
	join :ctable cc on cc.label = cp.label
	where itype <= 4352 and cityidx=0
	and not st_contains(stbound,the_geom)
	and st_distance(st_transform(stbound,2193),st_transform(the_geom,2193)) <=1000
	order by sd
) to :outfile with CSV;
