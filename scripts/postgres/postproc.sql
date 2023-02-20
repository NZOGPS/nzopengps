CREATE INDEX idx_road_id ON nz_roads_subsections_addressing USING btree (road_id);
ALTER TABLE nz_addresses ADD COLUMN is_odd boolean;
ALTER TABLE nz_addresses ADD COLUMN road_section_id integer;
ALTER TABLE nz_addresses ADD COLUMN rna_id integer;
ALTER TABLE nz_addresses ADD COLUMN linz_numb_id integer;

UPDATE nz_addresses    SET is_odd = MOD(address_number,2) = 1;
UPDATE nz_addresses sa SET road_section_id = aar.address_reference_object_value::INTEGER 
				from aims_address_reference aar where aar.address_id = sa.address_id and aar.address_reference_object_type='RoadCentreline';
UPDATE nz_addresses sa SET  rna_id       = rsa.road_id,
							linz_numb_id = rsa.address_range_road_id
						from nz_roads_subsections_addressing rsa 
						where sa.road_section_id is not null and rsa.road_section_id = sa.road_section_id;

--now add indexes for speed
CREATE INDEX idx_rna_nza_id ON nz_addresses USING btree (rna_id);
CREATE INDEX idx_rna_nza_id_is_odd ON nz_addresses USING btree (rna_id,is_odd);
