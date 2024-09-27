Alter Table :linestable Add Column nztm_line geometry(LineString,2193);
Update :linestable set nztm_line = st_transform(the_geom,2193);
-- polygon -> multipolygon
Alter Table :linestable Add Column leftpoly geometry(multipolygon,2193);
Alter Table :linestable Add Column rightpoly geometry(multipolygon,2193);
\echo Create offset side polygons
--update :linestable set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,-:distance))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-:distance))=1;
-- needed reverse at work? - but still not right...
--update :linestable set  leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,:distance))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,:distance))=1;

update :linestable set rightpoly = ST_Multi(st_buffer(nztm_line,:distance,'side=right')) where linzid > 0;
update :linestable set  leftpoly = ST_Multi(st_buffer(nztm_line,:distance,'side=left' )) where linzid > 0;
