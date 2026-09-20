Update :wrongstable set least_nums = -1 from :linestable where :wrongstable.gid = :linestable.gid and ltype = 'N';
Update :wrongstable set least_nums = abs(lend-lstart)+1 from :linestable where :wrongstable.gid = :linestable.gid and ltype <> 'N';
Update :wrongstable set least_nums = abs(rend-rstart)+1 from :linestable where :wrongstable.gid = :linestable.gid and rtype <> 'N' and ( abs(rend-rstart)+1 < :wrongstable.least_nums  or :wrongstable.least_nums = -1) ;
-- explicitly put :wrongstable.least_nums and :wrongstable.linzid in case they are present in numberlines from old versions

copy(select st_x(st_startpoint(the_geom)), st_y(st_startpoint(the_geom)), label, 'Sparse: ' || to_char(st_length(nztm_line)/least_nums,'FM99999"m, nums:"') || round(st_length(nztm_line)/10) 
	from :wrongstable wt join :linestable lt on wt.gid=lt.gid 
	where st_length(nztm_line)/least_nums > :distance
	and sparse_ok is null
	order by st_length(nztm_line)/least_nums desc)
	to :outfile with CSV;       