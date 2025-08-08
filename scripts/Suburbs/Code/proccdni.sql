update :ctable set dontindex=0;

update :ctable set dontindex=1
	from :ditable ditbl
	where label = nzogps_name
		and cityid = nzogps_cityidx
		and rgnidx = nzogps_region;