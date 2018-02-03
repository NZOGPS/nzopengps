CREATE INDEX idx_road_id ON nz_roads_subsections_addressing USING btree (road_id);
ALTER TABLE nz_street_address ADD COLUMN is_odd boolean;
ALTER TABLE nz_street_address ADD COLUMN rna_id integer;
ALTER TABLE nz_street_address ADD COLUMN linz_numb_id integer;

UPDATE nz_street_address SET is_odd = MOD(address_number,2) = 1;
UPDATE nz_street_address sa SET       rna_id = rsa.road_id              from nz_roads_subsections_addressing rsa where rsa.road_section_id = sa.road_section_id;
UPDATE nz_street_address sa SET linz_numb_id = rsa.address_range_road_id from nz_roads_subsections_addressing rsa where rsa.road_section_id = sa.road_section_id;

--now add indexes for speed
CREATE INDEX idx_rna_sae_id ON nz_street_address USING btree (rna_id);
CREATE INDEX idx_rna_sae_id_is_odd ON nz_street_address USING btree (rna_id,is_odd);
