copy (select to_char(st_x(st_centroid(stbound)),'999D99999'),to_char(st_y(st_centroid(stbound)),'99D99999'),'Unmatched: '||label, city, rgnidx, cityid
		from :ctable
			where nzslid is null
			and stbound is not null
			order by label)
 to :outfile with CSV;