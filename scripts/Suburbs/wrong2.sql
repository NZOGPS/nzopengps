copy( select st_x(st_startpoint(the_geom)),st_y(st_startpoint(the_geom)), 'Shouldbe: '||sb.name,cn.label
	from :ntable cn 
	join :ctable cc on cityidx = cityid 
	join nz_suburbs_and_localities on nzslid = id
	join ( select
		gid,sl.name from :ntable cn
		join nz_suburbs_and_localities sl 
		on st_intersects(the_geom,wkb_geometry)) sb on sb.gid = cn.gid
	where nzslid is not null 
	and not st_intersects(the_geom,wkb_geometry) order by sb.name 
) to :outfile with CSV;
-- copy(select st_x(st_startpoint(the_geom)),st_y(st_startpoint(the_geom)),label,'Sparse: '||to_char(st_length(nztm_line)/least_nums,'FM99999"m, nums:"')||round(st_length(nztm_line)/10) from :linestable where st_length(nztm_line)/least_nums > :distance order by st_length(nztm_line)/least_nums desc) to :outfile with CSV;