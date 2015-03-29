Alter Table :linestable Add Column least_nums smallint;
Update :linestable set least_nums = -1 where ltype = 'N';
Update :linestable set least_nums = abs(lend-lstart)+1 where ltype <> 'N';
Update :linestable set least_nums = abs(rend-rstart)+1 where rtype <> 'N' and abs(rend-rstart)+1 < least_nums;
-- select st_length(nztm_line)/least_nums from :linestable where st_length(nztm_line)/least_nums > :distance order by 1 desc;
copy(select st_x(st_startpoint(the_geom)),st_y(st_startpoint(the_geom)),label,st_length(nztm_line)/least_nums from :linestable where st_length(nztm_line)/least_nums > :distance order by 4) to :outfile with CSV;