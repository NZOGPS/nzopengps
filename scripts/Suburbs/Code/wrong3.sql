-- 21:44 08/08/23 change name to name_ascii as macrons(?) caused issues
-- 23:37 09/08/23 group by gid and array_agg the names to remove multiple points
\timing
copy( select st_x(st_lineinterpolatepoint(the_geom,0.01)),st_y(st_lineinterpolatepoint(the_geom,0.01)), cn.label,'Shouldbe: '|| array_to_string(array_agg(sb.name_ascii order by sb.name_ascii), ', '), max(st_distance(st_transform(the_geom,2193),nztm_geometry))::integer as distance
	from :ntable cn 
	join :ctable cc on cityidx = cityid 
	join nz_suburbs_and_localities on nzslid = id
	join ( select
		gid,sl.name_ascii from :ntable cn
		join nz_suburbs_and_localities sl 
		on st_intersects(st_transform(the_geom,2193),nztm_geometry)
		where watery is not true) sb on sb.gid = cn.gid
	where nzslid is not null 
	and not st_intersects(st_transform(the_geom,2193),nztm_geometry)  group by cn.gid 
	having max(st_distance(st_transform(the_geom,2193),nztm_geometry)) > :mdist
	order by max(st_distance(st_transform(the_geom,2193),nztm_geometry))
) to :outfile with CSV;
