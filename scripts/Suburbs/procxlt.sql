select nzogps_name,nzogps_cityidx,cityid
		from :ctable ct
		join :xtable xt
		on nzogps_name = label
			and nzogps_region = rgnidx
			and nzogps_city = city
			and cityid != nzogps_cityidx;

update :ctable set nzslid=id
	from nz_suburbs_and_localities
	join (
		select nzsl_nameascii, count(*) as count
		from :xtable 
		join nz_suburbs_and_localities nzsl 
		on nzsl_nameascii = name_ascii and nzsl_majornameascii = major_name_ascii
		where watery is not true
		group by nzsl_nameascii
		having count(*) = 1
	) uniq
		on uniq.nzsl_nameascii = name_ascii
	join :xtable
		on :xtable.nzsl_nameascii = name_ascii
		and nzsl_majornameascii = major_name_ascii
		and watery is not true
	where label = :xtable.nzogps_name
		and city = :xtable.nzogps_city
		and rgnidx = :xtable.nzogps_region;

select nzogps_name,nzsl_id,id
		from :ctable ct
		join :xtable xt
		on nzogps_name = label
			and nzogps_region = rgnidx
			and nzogps_city = city
		join nz_suburbs_and_localities nzsl
		on nzsl_nameascii = name_ascii
			and nzsl_majornameascii = major_name_ascii
		where nzsl_id != id

/* select name_ascii,id
	from nz_suburbs_and_localities
	join (
		select nzsl_nameascii, count(*) as count
		from :xtable 
		join nz_suburbs_and_localities nzsl 
		on nzsl_nameascii = name_ascii and nzsl_majornameascii = major_name_ascii
		where watery is not true
		group by nzsl_nameascii
		having count(*) = 1
	) uniq
		on uniq.nzsl_nameascii = name_ascii
	join :xtable
		on :xtable.nzsl_nameascii = name_ascii
		and nzsl_majornameascii = major_name_ascii
		and watery is not true;
 */
