DROP TABLE IF EXISTS :wrongstable;

CREATE TABLE :wrongstable (
	gid integer PRIMARY KEY,
	linzid integer,
	least_nums smallint,
	nztm_line geometry(LineString,2193),
	leftpoly  geometry(multipolygon,2193),
	rightpoly geometry(multipolygon,2193)
);

INSERT INTO :wrongstable (gid, linzid, nztm_line) select gid, linzid, st_transform(the_geom,2193) from :linestable;
\echo Create offset side polygons
select current_time;
update :wrongstable set rightpoly = ST_Multi(st_makepolygon(st_addpoint(st_makeline(nztm_line,(st_offsetcurve(nztm_line,-:distance))),st_startpoint(nztm_line)))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-:distance))=1;
-- needed reverse at work? - but still not right...
update :wrongstable set  leftpoly = ST_Multi(st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,:distance))),st_startpoint(nztm_line)))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,:distance))=1;

--using st_buffer
--update :wrongstable set rightpoly = ST_Multi(st_buffer(nztm_line,:distance,'side=right')) where linzid > 0;
--update :wrongstable set  leftpoly = ST_Multi(st_buffer(nztm_line,:distance,'side=left' )) where linzid > 0