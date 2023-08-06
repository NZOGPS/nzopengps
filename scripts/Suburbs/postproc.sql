CREATE INDEX nzsl_idx ON nz_suburbs_and_localities USING btree(id);

-- below is psql command to emit only tuples on selects for timing

ALTER TABLE nz_suburbs_and_localities ADD COLUMN watery boolean;
UPDATE nz_suburbs_and_localities SET watery = true where type = 'Coastal Bay' or type = 'Lake' or type = 'Inland Bay'
