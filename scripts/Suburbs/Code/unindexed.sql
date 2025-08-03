\timing
copy( select st_x(st_centroid(stbound)), st_y(st_centroid(stbound)), cc.label, cityid
	from :ctable cc
	left join :ptable cp on cityid = cityidx
	where cp.label is null
	and stbound is not null
	and dontindex != 1
	order by cityid
) to :outfile with CSV;
