--15/08/2023 8:42 pm add group by major in uniq select
--15:58 02/08/25 add output to file (avoid having to troll output)
\echo incorrect cityid in :xtable

select nzogps_name,nzogps_cityidx,cityid
	from :ctable ct
	join :xtable xt
	on nzogps_name = label
		and nzogps_region = rgnidx
		and nzogps_city = city
		and cityid != nzogps_cityidx;

copy( select nzogps_name,nzogps_cityidx,cityid
	from :ctable ct
	join :xtable xt
	on nzogps_name = label
		and nzogps_region = rgnidx
		and nzogps_city = city
		and cityid != nzogps_cityidx
) to :of1 with CSV;

update :ctable set nzslid=id
	from nz_suburbs_and_localities
	join (
		select nzsl_nameascii, nzsl_majornameascii, count(*) as count
		from :xtable 
		join nz_suburbs_and_localities nzsl 
		on nzsl_nameascii = name_ascii and nzsl_majornameascii = major_name_ascii
		where watery is not true
		group by nzsl_nameascii, nzsl_majornameascii
		having count(*) = 1
	) uniq
		on uniq.nzsl_nameascii = name_ascii 
		and uniq.nzsl_majornameascii = major_name_ascii
	join :xtable xtbl
		on xtbl.nzsl_nameascii = name_ascii
		and xtbl.nzsl_majornameascii = major_name_ascii
		and watery is not true
	where label = xtbl.nzogps_name
		and city = xtbl.nzogps_city
		and rgnidx = xtbl.nzogps_region
		and nzslid is null;

update :ctable set nzslid=nzsl_id
	from :xtable xtbl
	join nz_suburbs_and_localities nzsl
		on nzsl_id = id
		where force = 1 and cityid = nzogps_cityidx and nzsl_nameascii = name_ascii and nzsl_majornameascii = major_name_ascii;

update :ctable set secondary=0;
update :ctable set secondary=xtbl.secondary
	from :xtable xtbl
	where label = xtbl.nzogps_name
		and city = xtbl.nzogps_city
		and rgnidx = xtbl.nzogps_region
		and xtbl.secondary = 1;

\echo incorrect nzsl_id in :xtable
select nzogps_name,nzsl_id,id
	from :ctable ct
	join :xtable xt
	on nzogps_name = label
		and nzogps_region = rgnidx
		and nzogps_city = city
	join nz_suburbs_and_localities nzsl
	on nzsl_nameascii = name_ascii
		and nzsl_majornameascii = major_name_ascii
	where nzslid != id and force != 1;

copy( select nzogps_name,nzsl_id,id
	from :ctable ct
	join :xtable xt
	on nzogps_name = label
		and nzogps_region = rgnidx
		and nzogps_city = city
	join nz_suburbs_and_localities nzsl
	on nzsl_nameascii = name_ascii
		and nzsl_majornameascii = major_name_ascii
	where nzslid != id and force != 1
) to :of2 with CSV;