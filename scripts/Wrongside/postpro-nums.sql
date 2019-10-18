Alter table :numstable add primary key (address_id);
Create Index idx_:numstable ON :numstable USING btree (rna_id);

Alter Table :numstable Add Column  nztm geometry(Point,2193);
update :numstable set nztm = st_transform(wkb_geometry,2193);

Alter Table :numstable Add Column asnum_side smallint;
Alter Table :numstable Add Column asnum_roadid numeric(10);
Alter Table :numstable Add Column asnum_segment smallint;
Alter Table :numstable Add Column asnum_distance double precision;
Alter Table :numstable Add Column asnum_position geometry(Point,2193);

Alter Table :numstable Add Column isect_side smallint;
Alter Table :numstable Add Column isect_roadid numeric(10);
Alter Table :numstable Add Column isect_segment smallint;
Alter Table :numstable Add Column isect_distance double precision;
Alter Table :numstable Add Column asnum_dist_err double precision;
