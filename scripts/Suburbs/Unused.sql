copy (select cityid,label
		from :ctable
			where stbound is null
			order by cityid )
 to :outfile with CSV;