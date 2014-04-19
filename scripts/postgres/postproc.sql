ALTER TABLE "nz-street-address-electoral" ADD COLUMN range_low integer;
ALTER TABLE "nz-street-address-electoral" ADD COLUMN is_odd boolean;
--house_numb: 8
UPDATE "nz-street-address-electoral" SET range_low = cast(house_numb AS INTEGER) WHERE house_numb ~* E'^\\d+$';
--house_numb: 8A
UPDATE "nz-street-address-electoral" SET range_low = cast(substring(house_numb FROM E'^(\\d+)\\w$') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\\w$';
--house_numb: 8-10
UPDATE "nz-street-address-electoral" SET range_low = cast(substring(house_numb FROM E'^(\\d+)[A-Z]?\-\\d+[A-Z]?$') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^(\\d+)[A-Z]?\-\\d+[A-Z]?$';
--house_numb: 1A/10
UPDATE "nz-street-address-electoral" SET range_low = cast(substring(house_numb FROM E'^\\d+\/(\\d+)\-?') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\/(\\d+)\-?';
--house_numb: 1/10 and 1/10-5/10
UPDATE "nz-street-address-electoral" SET range_low = cast(substring(house_numb FROM E'^\\d+\/(\\d+)\-?') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\/(\\d+)\-?';
--set is_odd
UPDATE "nz-street-address-electoral" SET is_odd = MOD(range_low,2) = 1;

--now add indexes for speed
CREATE INDEX idx_rna_id ON "nz-street-address-electoral" USING btree (rna_id);
CREATE INDEX idx_rna_id_is_odd ON "nz-street-address-electoral" USING btree (rna_id,is_odd);
