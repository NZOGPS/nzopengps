CREATE INDEX idx_road_id ON nz_roads_subsections_addressing USING btree (road_id);

-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'CREATE TABLES',NOW();
ALTER TABLE nz_addresses ADD COLUMN is_odd boolean;
ALTER TABLE nz_addresses ADD COLUMN road_section_id integer;
ALTER TABLE nz_addresses ADD COLUMN rna_id integer;
ALTER TABLE nz_addresses ADD COLUMN linz_numb_id integer;

SELECT 'IS ODD',NOW(); -- 4 min on 20230304
UPDATE nz_addresses    SET is_odd = MOD(address_number,2) = 1;

SELECT 'ROAD SECTION ID',NOW(); -- 47 min on 20230304
UPDATE nz_addresses sa 
	SET road_section_id = aar.address_reference_object_value::INTEGER 
	from aims_address_reference aar
	where aar.address_id = sa.address_id and aar.address_reference_object_type='RoadCentreline';
	
SELECT 'RNA ID,LNID',NOW(); -- 1:32  on 20230304
UPDATE nz_addresses sa 
	SET  rna_id = rsa.road_id,
		linz_numb_id = rsa.address_range_road_id
	from nz_roads_subsections_addressing rsa 
	where sa.road_section_id is not null and rsa.road_section_id = sa.road_section_id;
SELECT 'RNA ID,LNID DONE',NOW();

--now add indexes for speed
CREATE INDEX idx_rna_nza_id ON nz_addresses USING btree (rna_id);
CREATE INDEX idx_rna_nza_id_is_odd ON nz_addresses USING btree (rna_id,is_odd);

--old
-- SELECT 'CREATE TABLES',NOW();
-- ALTER TABLE nz_street_address ADD COLUMN is_odd boolean;
-- ALTER TABLE nz_street_address ADD COLUMN rna_id integer;
-- ALTER TABLE nz_street_address ADD COLUMN linz_numb_id integer;

-- SELECT 'IS ODD',NOW();
-- UPDATE nz_street_address SET is_odd = MOD(address_number,2) = 1; -- 26 min on 20230304
-- SELECT 'RNA ID,LNID',NOW();
-- UPDATE nz_street_address sa
	-- SET rna_id = rsa.road_id
	-- from nz_roads_subsections_addressing rsa 
	-- where rsa.road_section_id = sa.road_section_id;
-- UPDATE nz_street_address sa 
	-- SET linz_numb_id = rsa.address_range_road_id 
	-- from nz_roads_subsections_addressing rsa 
	-- where rsa.road_section_id = sa.road_section_id;
-- SELECT 'RNA ID,LNID DONE',NOW();		-- combination of both 48 min on 20230304

--now add indexes for speed
-- CREATE INDEX idx_rna_sae_id ON nz_street_address USING btree (rna_id);
-- CREATE INDEX idx_rna_sae_id_is_odd ON nz_street_address USING btree (rna_id,is_odd);
