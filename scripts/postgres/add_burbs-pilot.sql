-- SELECT COUNT(*) FROM :NZSL_TBL;
UPDATE nz_addresses_roads_pilot rd
	SET suburb_locality_ascii = :NZSL.name_ascii 
	from :NZSL nzsl
	WHERE st_within(:NZSL.wkb_geometry,rd.wkb_geometry);