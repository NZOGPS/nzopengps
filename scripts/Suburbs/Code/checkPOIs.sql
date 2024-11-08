-- 2:48 pm Friday, 8 November 2024 - created

\echo different label between map point and city in :ctable
select st_x(the_geom),st_y(the_geom), cc.label, cc.city, cp.label,cp.cityidx
	from :ptable cp join :ctable cc
	on cityidx = cityid
	where cp.label <> cc.label and cp.label <> concat_ws(', ',cc.label,cc.city);

copy( select  st_x(the_geom),st_y(the_geom), cp.label,cp.cityidx, nzslid
	from :ctable cc
	join :ptable cp 
		on cityidx = cityid
	join nz_suburbs_and_localities nzsl
		on nzslid = nzsl.id
	where not st_contains(wkb_geometry,the_geom)
) to :outfile with CSV;
