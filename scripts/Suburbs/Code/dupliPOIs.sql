-- 4:27 pm Thursday, 7 November 2024 - created

\timing
copy(select st_x(the_geom),st_y(the_geom), cp.label
	from :ptable cp join (
		select cp.label, count(*)as cnt
		from :ptable cp 
		join :ctable cc on cc.label = cp.label
		where itype <= 4352 and cityidx=0
		and st_contains(stbound,the_geom)
		--	and iscity='Y'
		group by cp.label
		having count(*)>1
	) multi
	on multi.label = cp.label
	order by label
) to :outfile with CSV;