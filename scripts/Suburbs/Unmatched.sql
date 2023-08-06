copy (select st_x(st_centroid(stbound)),st_y(st_centroid(stbound)),'Unmatched: '||label
		from :ctable
			where nzslid is null
			and stbound is not null )
 to :outfile with CSV;