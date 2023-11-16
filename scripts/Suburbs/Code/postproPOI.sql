alter table :ptable add column itype integer;
ALTER TABLE :ptable ADD COLUMN nztm geometry(geometry,2193);
update :ptable set itype = ('x'||lpad(substring(type,3),4,'0'))::bit(16)::integer;
update :ptable set nztm = st_transform(the_geom,2193);

