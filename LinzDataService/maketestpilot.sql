DROP TABLE IF EXISTS nz_addresses_pilot_test;

--copy Reefton-ish area from read data as a bit of non-original test

CREATE TABLE nz_addresses_pilot_test AS
SELECT * FROM nz_addresses_pilot
where wkb_geometry && ST_MakeEnvelope ( 171.7, -42.2, 171.9, -42.1, 4167); 

DROP TABLE IF EXISTS nz_addresses_roads_pilot_test_s;

CREATE TABLE nz_addresses_roads_pilot_test_s AS
SELECT * FROM nz_addresses_roads_pilot_s
where wkb_geometry && ST_MakeEnvelope ( 171.7, -42.2, 171.9, -42.1, 4167);

--then copy in data to be deleted or modified

INSERT INTO nz_addresses_pilot_test (
	wkt, address_id, road_id, full_address_number, full_road_name, full_address,
	territorial_authority, unit, address_number,address_number_suffix, address_number_high, 
	road_name, road_name_type, road_name_suffix,
	suburb_locality, town_city, address_lifecycle, 
	shape_x, shape_y, is_odd, linz_numb_id,
	full_road_name_ascii, full_address_ascii, territorial_authority_ascii,
	road_name_ascii, suburb_locality_ascii, town_city_ascii,
	is_land, wkb_geometry
) SELECT 
	nap.wkt, nap.address_id, nap.road_id, nap.full_address_number, nap.full_road_name, nap.full_address,
	nap.territorial_authority, nap.unit, nap.address_number, nap.address_number_suffix, nap.address_number_high,
	nap.road_name, nap.road_name_type, nap.road_name_suffix, 
	nap.suburb_locality, nap.town_city, nap.address_lifecycle, 
	nap.shape_x, nap.shape_y, nap.is_odd, nap.linz_numb_id,
	nap.full_road_name_ascii, nap.full_address_ascii, nap.territorial_authority_ascii,
	nap.road_name_ascii, nap.suburb_locality_ascii, nap.town_city_ascii,
	nap.is_land, nap.wkb_geometry
FROM nz_addresses_pilot nap
join layer_123113_cs cs
	on cs.address_id = nap.address_id
where __change__ = 'DELETE' or __change__ = 'UPDATE';

INSERT INTO nz_addresses_roads_pilot_test_s(
	    road_id,     full_road_name,     is_land,     wkb_geometry,     full_road_name_ascii,     road_name_label_ascii,     suburb_locality_ascii,     territorial_authority_ascii
) SELECT 
	arp.road_id, arp.full_road_name, arp.is_land, arp.wkb_geometry, arp.full_road_name_ascii, arp.road_name_label_ascii, arp.suburb_locality_ascii, arp.territorial_authority_ascii
FROM nz_addresses_roads_pilot_s arp
join layer_123110_cs cs
	on cs.road_id = arp.road_id
where __change__ = 'DELETE' or __change__ = 'UPDATE';
