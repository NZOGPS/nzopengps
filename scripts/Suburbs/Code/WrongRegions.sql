copy( select st_x(st_centroid(stbound)), st_y(st_centroid(stbound)),label,regc_00, sc.rgnidx,cityid,city,nzslid from  :ctable sc
	join regional_council rc 
		on rgnidx = nzo_rgnid
	where not (st_contains(wkb_geometry,stbound) or st_overlaps(wkb_geometry,stbound))
) to :outfile with CSV;