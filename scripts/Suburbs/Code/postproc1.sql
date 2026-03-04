
-- below is psql command to emit only tuples on selects for timing
SELECT current_timestamp AS nowtxt \gset
\set tblcommentbase ' data. Code modified in March 2026. This table processed: ' :nowtxt
\set tblcomment 'nz_suburbs_and_localities' :tblcommentbase
COMMENT ON TABLE nz_suburbs_and_localities IS :'tblcomment';

ALTER TABLE nz_suburbs_and_localities ADD COLUMN watery boolean;
ALTER TABLE nz_suburbs_and_localities ADD COLUMN nztm_geometry geometry(geometry,2193);
ALTER TABLE nz_suburbs_and_localities ADD COLUMN updated character varying;

UPDATE nz_suburbs_and_localities SET updated = :'nowtxt';
UPDATE nz_suburbs_and_localities SET watery = false;
UPDATE nz_suburbs_and_localities SET watery = true where type = 'Coastal Bay' or type = 'Lake' or type = 'Inland Bay';

