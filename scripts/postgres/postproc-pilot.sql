
-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW(); -- ~1 sec 2026/1/24
\set ROAD_TBL_S :ROAD_TBL'_s'

SELECT current_timestamp AS nowtxt \gset
\set tblcommentbase ' data. Code modified in January 2026. This table processed: ' :nowtxt
\set tblcomment 'Pilot address' :tblcommentbase
COMMENT ON TABLE :ADD_TBL IS :'tblcomment';
\set tblcomment 'Pilot addressing roads' :tblcommentbase
COMMENT ON TABLE :ROAD_TBL IS :'tblcomment';

ALTER TABLE :ADD_TBL ADD COLUMN is_odd boolean;
ALTER TABLE :ADD_TBL ADD COLUMN linz_numb_id integer;
ALTER TABLE :ADD_TBL ADD COLUMN updated character varying;

drop table if exists :ROAD_TBL_S;
CREATE TABLE :ROAD_TBL_S -- nz_addresses_roads_pilot_s
(
  ogc_fid serial PRIMARY KEY,
  road_id integer,
  full_road_name character varying,
  road_name_label character varying,
  is_land boolean,
  full_road_name_ascii character varying,
  road_name_label_ascii character varying,
  suburb_locality_ascii character varying,
  territorial_authority_ascii character varying,
  updated character varying,
  wkb_geometry geometry(LineString,4167)
);

\set tblcomment 'Pilot addressing roads split into LineString ' :tblcommentbase
COMMENT ON TABLE :ROAD_TBL_S IS :'tblcomment';

SELECT 'IS ODD',NOW(); -- ~1 min 2026/1/24 2 min 2026/02/23
UPDATE :ADD_TBL SET is_odd = MOD(address_number,2) = 1;
UPDATE :ADD_TBL SET updated = :'nowtxt';

select 'binarise is_land',NOW(); -- ~ 1 min 30 2026/02/23
ALTER TABLE :ADD_TBL RENAME COLUMN is_land TO is_land_txt;
ALTER TABLE :ADD_TBL ADD COLUMN is_land boolean;
UPDATE :ADD_TBL SET is_land = is_land_txt::BOOLEAN;
ALTER TABLE :ADD_TBL DROP COLUMN is_land_txt;

ALTER TABLE :ROAD_TBL RENAME COLUMN is_land TO is_land_txt;
ALTER TABLE :ROAD_TBL ADD COLUMN is_land boolean;
UPDATE :ROAD_TBL SET is_land = is_land_txt::BOOLEAN;
ALTER TABLE :ROAD_TBL DROP COLUMN is_land_txt;

SELECT 'SPLIT MULTIS',NOW();  -- ~4 sec 2026/1/24

INSERT INTO  :ROAD_TBL_S (road_id, full_road_name, road_name_label, is_land, full_road_name_ascii, road_name_label_ascii, wkb_geometry)
select 
	nzp.road_id, nzp.full_road_name, nzp.road_name_label, nzp.is_land, nzp.full_road_name_ascii, nzp.road_name_label_ascii,
	(st_dump(wkb_geometry)).geom
	from nz_addresses_roads_pilot nzp;

UPDATE :ROAD_TBL_S SET updated = :'nowtxt';

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

VACUUM ANALYSE :ROAD_TBL;
VACUUM ANALYSE :ADD_TBL;
