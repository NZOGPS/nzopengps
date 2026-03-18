-- postproc2 - stuff to do after initial queries and slow queries
-- SELECT 'ADD FULLY OVERLAPPED BURB and TA',NOW(); -- 4212223 ms ~ 70 min ~ 1 hr 10 - 249586 rows of 266002 26/1/24
-- 20260224 added watery is not true. Then 18 min  for 249531
-- JUST DOES FULLY WITHIN

/* update :ROAD_TBL_S rd
	set suburb_locality_ascii = sal.name_ascii,
		territorial_authority_ascii = sal.territorial_authority_ascii
	from nz_suburbs_and_localities sal where st_within(rd.wkb_geometry,sal.wkb_geometry) and watery is not true;
 */
-- future? use slow_query_progress to monitor progress of this slow query?
-- ruby slow_query_progress.rb -i ogc_fid -t nz_addresses_roads_s -q " set suburb_locality_ascii = sal.name_ascii,territorial_authority_ascii = sal.territorial_authority_ascii from nz_suburbs_and_localities sal" -w "st_within(sqptbl.wkb_geometry,sal.wkb_geometry) and watery is not true "

-- SELECT 'ADD MOST OVERLAPPED BURB and TA',NOW(); -- ~ 4 min 26/1/25
-- BEST MATCH? 16416 to do on 26/1/25
-- 20260224 post not watery: 16316 3 min

/* update :ROAD_TBL_S rd
	set suburb_locality_ascii = name_ascii,
	    territorial_authority_ascii = isect.territorial_authority_ascii
	from (
		SELECT distinct on (rd.ogc_fid) 
			st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
			FROM :ROAD_TBL_S rd
			join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
			WHERE suburb_locality_ascii is null and watery is not true
			order by rd.ogc_fid, overlap desc
	) as isect
where rd.ogc_fid = isect.ogc_fid;
 */
-- as above. Below untested
-- ruby slow_query_progress.rb -i ogc_fid -t nz_addresses_roads_s -q "set suburb_locality_ascii = name_ascii,territorial_authority_ascii = isect.territorial_authority_ascii \
-- from ( SELECT distinct on (rd.ogc_fid) st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii \
-- FROM sqptbl rd join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry) where suburb_locality_ascii is null and watery is not true \
-- order by rd.ogc_fid, overlap desc) as isect" -w  "rd.ogc_fid = isect.ogc_fid;"

--now add indexes for speed
SELECT 'ADD INDEXES',NOW();

CREATE INDEX idx_rna_nza_id_p ON :ADD_TBL USING btree (road_id);
CREATE INDEX idx_rna_nza_id_is_odd_p ON :ADD_TBL USING btree (road_id,is_odd);

CREATE INDEX idx_road_id_p_s ON :ROAD_TBL_S USING btree (road_id);

VACUUM ANALYSE :ROAD_TBL;
VACUUM ANALYSE :ADD_TBL;
