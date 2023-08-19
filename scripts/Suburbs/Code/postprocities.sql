alter table :ctable add column nzslid integer;

update :ctable set nzslid=id  -- find cities in linz whose names are unique match to ours
	from nz_suburbs_and_localities 
	join (
		select label, count(*) as count 
		from :ctable 
		join nz_suburbs_and_localities nzsl 
		on label = name_ascii 
		where nzslid is null and watery is not true
		group by label 
		having count(*)=1 
	) uni 
	on uni.label = name_ascii 
	where :ctable.label=name_ascii 
		and nzslid is null 
		and watery is not true;

update :ctable set nzslid=id  -- find cities in linz that match on name and city
	from nz_suburbs_and_localities 
	where label = name_ascii 
	and city = major_name_ascii
	and city != ''
	and nzslid is null;

update :ctable cc set stbound = st_polygonfromtext(sq.ch,4167) -- ugly hack as ??? see misc_code?
from (
	select cityidx as ci, st_astext(st_convexhull(st_collect(the_geom))) as ch from :ntable group by cityidx
) as sq 
where cc.cityid = sq.ci;
