CREATE INDEX idx_road_id_p ON nz_addresses_road_sections_pilot USING btree (road_id);

-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW();
ALTER TABLE nz_addresses_pilot ADD COLUMN is_odd boolean;
ALTER TABLE nz_addresses_pilot ADD COLUMN road_section_id integer;
ALTER TABLE nz_addresses_pilot ADD COLUMN rna_id integer;
ALTER TABLE nz_addresses_pilot ADD COLUMN linz_numb_id integer;

SELECT 'IS ODD',NOW(); -- 4 min on 20230304
UPDATE nz_addresses_pilot    SET is_odd = MOD(address_number,2) = 1;

--Not  working? No address reference?

-- also need to ascify?

-- SELECT 'ROAD SECTION ID',NOW(); -- 47 min on 20230304
-- UPDATE nz_addresses_pilot sa 
	-- SET road_section_id = aar.address_reference_object_value::INTEGER 
	-- from aims_address_reference aar
	-- where aar.address_id = sa.address_id and aar.address_reference_object_type='RoadCentreline';
	
-- SELECT 'RNA ID,LNID',NOW(); -- 1:32  on 20230304
-- UPDATE nz_addresses_pilot sa 
	-- SET  rna_id = rsa.road_id,
		-- linz_numb_id = rsa.address_range_road_id
	-- from nz_roads_subsections_addressing rsa 
	-- where sa.road_section_id is not null and rsa.road_section_id = sa.road_section_id;
-- SELECT 'RNA ID,LNID DONE',NOW();

--now add indexes for speed
CREATE INDEX idx_rna_nza_id_p ON nz_addresses_pilot USING btree (rna_id);
CREATE INDEX idx_rna_nza_id_is_odd_p ON nz_addresses_pilot USING btree (rna_id,is_odd);
