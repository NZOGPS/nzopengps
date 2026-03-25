Alter Table :linestable Add Column least_nums smallint;
Update :linestable set least_nums = -1 where ltype = 'N';
Update :linestable set least_nums = abs(lend-lstart)+1 where ltype <> 'N';
Update :linestable set least_nums = abs(rend-rstart)+1 where rtype <> 'N' and ( abs(rend-rstart)+1 < least_nums  or least_nums = -1) ;
-- select st_length(nztm_line)/least_nums from :linestable where st_length(nztm_line)/least_nums > :distance order by 1 desc;
copy(select st_x(st_startpoint(the_geom)),st_y(st_startpoint(the_geom)),label,'Sparse: '||to_char(st_length(nztm_line)/least_nums,'FM99999"m, nums:"')||round(st_length(nztm_line)/10) from :linestable where st_length(nztm_line)/least_nums > :distance order by st_length(nztm_line)/least_nums desc) to :outfile with CSV;