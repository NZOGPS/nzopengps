\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION pg_temp.gcterr(msg varchar) RETURNS boolean
  AS $$ BEGIN RAISE '%',msg; END; $$ LANGUAGE plpgsql;

select * from nzogps_regions nzo join regional_council src on src.regc_00 = nzo.regc_00 where src.regc_name_ascii <> nzo.regc_name_ascii;

SELECT CASE WHEN (
 select count(*) from nzogps_regions nzo join regional_council src on src.regc_00 = nzo.regc_00 where src.regc_name_ascii <> nzo.regc_name_ascii
) > 0 THEN pg_temp.gcterr('Discrepancies in Regional Council Database') END;

ALTER TABLE regional_council ADD COLUMN if not exists nzo_rgnid integer;

UPDATE regional_council rc SET nzo_rgnid = RgnIDX
from nzogps_regions nzor
WHERE rc.REGC_00 = nzor.REGC_00;

