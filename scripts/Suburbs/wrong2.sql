-- 21:44 08/08/23 change name to name_ascii as macrons(?) caused issues
-- 23:37 09/08/23 group by gid and array_agg the names to remove multiple points
copy( select st_x(st_startpoint(the_geom)),st_y(st_startpoint(the_geom)), cn.label,'Shouldbe: '||array_to_string(array_agg(sb.name_ascii),', ')
	from :ntable cn 
	join :ctable cc on cityidx = cityid 
	join nz_suburbs_and_localities on nzslid = id
	join ( select
		gid,sl.name_ascii from :ntable cn
		join nz_suburbs_and_localities sl 
		on st_intersects(the_geom,wkb_geometry)) sb on sb.gid = cn.gid
	where nzslid is not null 
	and not st_intersects(the_geom,wkb_geometry)  group by cn.gid order by array_to_string(array_agg(sb.name_ascii),', ')
) to :outfile with CSV;
