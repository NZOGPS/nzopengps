-- 2:48 pm Friday, 8 November 2024 - created

\echo different label between map point and city in :ctable
select st_x(the_geom),st_y(the_geom), cc.label, cc.city, cp.label,cp.cityidx
	from :ptable cp join :ctable cc
	on cityidx = cityid
	where cp.label <> cc.label and cp.label <> concat_ws(', ',cc.label,cc.city);

copy( select  st_x(the_geom),st_y(the_geom), concat('Outside: ',cp.label),cp.cityidx, nzslid
	from :ctable cc
	join :ptable cp 
		on cityidx = cityid
	join nz_suburbs_and_localities nzsl
		on nzslid = nzsl.id
	where not st_contains(wkb_geometry,the_geom)
	UNION ALL
	select  st_x(the_geom),st_y(the_geom), concat('NotCity: ',cp.label),cp.cityidx, 0
	from :ctable cc
	join :ptable cp 
		on cityidx = cityid
	where not iscity='Y'
	UNION ALL
	select  st_x(the_geom),st_y(the_geom), concat('Lvl0: ',cp.label),cp.cityidx, 0
	from :ctable cc
	join :ptable cp 
		on cityidx = cityid
	where endlevel='0'

) to :outfile with CSV;
