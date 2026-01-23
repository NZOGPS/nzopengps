
-- below is psql command to emit only tuples on selects for timing
\t 
SELECT 'ALTER TABLES',NOW();

ALTER TABLE nz_addresses_pilot ADD COLUMN is_odd boolean;
ALTER TABLE nz_addresses_pilot ADD COLUMN linz_numb_id integer;
ALTER TABLE nz_addresses_pilot ADD COLUMN full_road_name_ascii character varying;
ALTER TABLE nz_addresses_pilot ADD COLUMN suburb_locality_ascii character varying;

ALTER TABLE nz_addresses_roads_pilot ADD COLUMN full_road_name_ascii character varying;
ALTER TABLE nz_addresses_roads_pilot ADD COLUMN suburb_locality_ascii character varying;
ALTER TABLE nz_addresses_roads_pilot ADD COLUMN territorial_authority_ascii character varying;

SELECT 'IS ODD',NOW();
UPDATE nz_addresses_pilot SET is_odd = MOD(address_number,2) = 1;

SELECT 'ASCIIFY',NOW();
-- if unaccent fails, need to CREATE EXTENSION unaccent in nzopengps;
UPDATE nz_addresses_pilot SET full_road_name_ascii = unaccent(full_road_name);
UPDATE nz_addresses_pilot SET suburb_locality_ascii = unaccent(suburb_locality);

UPDATE nz_addresses_roads_pilot SET full_road_name_ascii = unaccent(full_road_name);

--now add indexes for speed
CREATE INDEX idx_rna_nza_id_p ON nz_addresses_pilot USING btree (road_id);
CREATE INDEX idx_rna_nza_id_is_odd_p ON nz_addresses_pilot USING btree (road_id,is_odd);

CREATE INDEX idx_road_id_p ON nz_addresses_roads_pilot USING btree (road_id);
