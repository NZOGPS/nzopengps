
-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW();
\set ROAD_TBL_S :ROAD_TBL'_s'

ALTER TABLE :ADD_TBL ADD COLUMN is_odd boolean;
ALTER TABLE :ADD_TBL ADD COLUMN linz_numb_id integer;
ALTER TABLE :ADD_TBL ADD COLUMN full_road_name_ascii character varying;
ALTER TABLE :ADD_TBL ADD COLUMN suburb_locality_ascii character varying;

drop table if exists :ROAD_TBL_S
CREATE TABLE :ROAD_TBL_S -- nz_addresses_roads_pilot_s
(
  ogc_fid serial PRIMARY KEY,
  road_id integer,
  full_road_name character varying,
  is_land character varying(2),
  wkb_geometry geometry(LineString,4167),
  full_road_name_ascii character varying,
  suburb_locality_ascii character varying,
  territorial_authority_ascii character varying,
);

ALTER TABLE :ROAD_TBL ADD COLUMN full_road_name_ascii character varying;

SELECT 'IS ODD',NOW();
UPDATE :ADD_TBL SET is_odd = MOD(address_number,2) = 1;

SELECT 'ASCIIFY',NOW();
-- if unaccent fails, need to CREATE EXTENSION unaccent in nzopengps;
UPDATE :ADD_TBL SET full_road_name_ascii = unaccent(full_road_name);
UPDATE :ADD_TBL SET suburb_locality_ascii = unaccent(suburb_locality);

UPDATE :ROAD_TBL SET full_road_name_ascii = unaccent(full_road_name);

SELECT 'SPLIT MULTIS',NOW();

INSERT INTO  nz_addresses_roads_pilot_s (road_id,full_road_name,wkb_geometry,full_road_name_ascii,is_land)
select 
	nzp.road_id, nzp.full_road_name, (st_dump(wkb_geometry)).geom, nzp.full_road_name_ascii,
	nzp.is_land
	from nz_addresses_roads_pilot nzp
	
SELECT 'ADD BURB and TA',NOW();
-- JUST DOES FULLY WITHIN?
update nz_addresses_roads_pilot_s rd
set suburb_locality_ascii = sal.name_ascii,
territorial_authority_ascii = sal.territorial_authority_ascii
from nz_suburbs_and_localities sal where st_within(rd.wkb_geometry,sal.wkb_geometry)
-- BEST MATCH?

--now add indexes for speed
SELECT 'ADD INDEXES',NOW();

CREATE INDEX idx_rna_nza_id_p ON :ADD_TBL USING btree (road_id);
CREATE INDEX idx_rna_nza_id_is_odd_p ON :ADD_TBL USING btree (road_id,is_odd);

CREATE INDEX idx_road_id_p ON :ROAD_TBL USING btree (road_id);
