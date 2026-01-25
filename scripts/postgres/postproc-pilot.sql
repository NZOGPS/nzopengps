
-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW(); -- ~1 sec 2026/1/24
\set ROAD_TBL_S :ROAD_TBL'_s'

ALTER TABLE :ADD_TBL ADD COLUMN is_odd boolean;
ALTER TABLE :ADD_TBL ADD COLUMN linz_numb_id integer;
ALTER TABLE :ADD_TBL ADD COLUMN full_road_name_ascii character varying;
ALTER TABLE :ADD_TBL ADD COLUMN suburb_locality_ascii character varying;

drop table if exists :ROAD_TBL_S;
CREATE TABLE :ROAD_TBL_S -- nz_addresses_roads_pilot_s
(
  ogc_fid serial PRIMARY KEY,
  road_id integer,
  full_road_name character varying,
  is_land character varying(2),
  wkb_geometry geometry(LineString,4167),
  full_road_name_ascii character varying,
  suburb_locality_ascii character varying,
  territorial_authority_ascii character varying
);

ALTER TABLE :ROAD_TBL ADD COLUMN full_road_name_ascii character varying;

SELECT 'IS ODD',NOW(); -- ~1 min 2026/1/24
UPDATE :ADD_TBL SET is_odd = MOD(address_number,2) = 1;

SELECT 'ASCIIFY',NOW();  -- ~3 min 2026/1/25
-- if unaccent fails, need to CREATE EXTENSION unaccent in nzopengps;
UPDATE :ADD_TBL SET full_road_name_ascii = unaccent(full_road_name);
UPDATE :ADD_TBL SET suburb_locality_ascii = unaccent(suburb_locality);

UPDATE :ROAD_TBL SET full_road_name_ascii = unaccent(full_road_name);

SELECT 'SPLIT MULTIS',NOW();  -- ~4 sec 2026/1/24

INSERT INTO  :ROAD_TBL_S (road_id,full_road_name,wkb_geometry,full_road_name_ascii,is_land)
select 
	nzp.road_id, nzp.full_road_name, (st_dump(wkb_geometry)).geom, nzp.full_road_name_ascii,
	nzp.is_land
	from nz_addresses_roads_pilot nzp;

SELECT 'ADD FULLY OVERLAPPED BURB and TA',NOW(); -- 4212223 ms ~ 70 min ~ 1 hr 10 - 249586 rows of 266002 26/1/24
-- JUST DOES FULLY WITHIN?
update :ROAD_TBL_S rd
	set suburb_locality_ascii = sal.name_ascii,
		territorial_authority_ascii = sal.territorial_authority_ascii
	from nz_suburbs_and_localities sal where st_within(rd.wkb_geometry,sal.wkb_geometry);

SELECT 'ADD MOST OVERLAPPED BURB and TA',NOW(); -- ~ 4 min 26/1/25
-- BEST MATCH? 16416 to do on 26/1/25
update :ROAD_TBL_S rd
	set suburb_locality_ascii = name_ascii,
	    territorial_authority_ascii = isect.territorial_authority_ascii
	from (
		SELECT distinct on (rd.ogc_fid) 
			st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
			FROM :ROAD_TBL_S rd
			join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
			WHERE suburb_locality_ascii is null
			order by rd.ogc_fid, overlap desc
	) as isect
where rd.ogc_fid = isect.ogc_fid;

--now add indexes for speed
SELECT 'ADD INDEXES',NOW();

CREATE INDEX idx_rna_nza_id_p ON :ADD_TBL USING btree (road_id);
CREATE INDEX idx_rna_nza_id_is_odd_p ON :ADD_TBL USING btree (road_id,is_odd);

CREATE INDEX idx_road_id_p_s ON :ROAD_TBL_S USING btree (road_id);
