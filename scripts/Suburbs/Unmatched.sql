copy (select st_x(st_centroid(stbound)),st_y(st_centroid(stbound)),'Unmatched: '||label, city, rgnidx, cityid
		from :ctable
			where nzslid is null
			and stbound is not null
			order by label)
 to :outfile with CSV;