Alter Table :linestable Add Column nztm_line geometry(LineString,2193);
Update :linestable set nztm_line = st_transform(the_geom,2193);
Alter Table :linestable Add Column leftpoly geometry(polygon,2193);
Alter Table :linestable Add Column rightpoly geometry(polygon,2193);
update :linestable set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-:distance)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-:distance))=1;
update :linestable set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,:distance))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,:distance))=1;
