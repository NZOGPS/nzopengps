
-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW(); -- ~1 sec 2026/1/24
\set ROAD_TBL_S :ROAD_TBL'_s'

SELECT current_timestamp AS nowtxt \gset
\set tblcommentbase ' data. Code modified in January 2026. This table processed: ' :nowtxt
\set tblcomment 'New (2026) address' :tblcommentbase
COMMENT ON TABLE :ADD_TBL IS :'tblcomment';
\set tblcomment 'New (2026) addressing roads' :tblcommentbase
COMMENT ON TABLE :ROAD_TBL IS :'tblcomment';

ALTER TABLE :ADD_TBL ADD COLUMN is_odd boolean;
ALTER TABLE :ADD_TBL ADD COLUMN linz_numb_id integer;
ALTER TABLE :ADD_TBL ADD COLUMN updated character varying;

drop table if exists :ROAD_TBL_S;
CREATE TABLE :ROAD_TBL_S -- nz_addresses_roads_s
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

\set tblcomment 'New (2026) addressing roads split into LineString ' :tblcommentbase
COMMENT ON TABLE :ROAD_TBL_S IS :'tblcomment';

SELECT 'IS ODD',NOW(); -- Following: ~1 min 2026/1/24 2 min 2026/02/23 13 min on on elecst11 on 26/03/18
UPDATE :ADD_TBL SET is_odd = MOD(address_number,2) = 1;
UPDATE :ADD_TBL SET updated = :'nowtxt';

select 'binarise is_land',NOW(); -- ~ 1 min 30 2026/02/23 15 min on on elecst11 on 26/03/18
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
	from nz_addresses_roads nzp;

UPDATE :ROAD_TBL_S SET updated = :'nowtxt';
-- remaining tasks in slow_sql and/or postproc2.sql