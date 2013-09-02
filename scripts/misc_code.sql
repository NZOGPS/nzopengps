ALTER TABLE "nz-street-address-elector" ADD COLUMN nztm geometry(Point,2193);
update "nz-street-address-elector" set nztm = st_transform(the_geom,2193);
ALTER TABLE "small_test" ADD COLUMN nztm_line geometry(LineString,2193);
update "small_test" set nztm_line = st_transform(the_geom,2193);
ALTER TABLE "small_test" ADD COLUMN nztm_left_poly geometry(polygon,2193);
ALTER TABLE "small_test" ADD COLUMN nztm_right_poly geometry(polygon,2193);
update "small_test" set nztm_left_poly = st_makepolygon(st_addpoint(st_linemerge(st_union(nztm_line,st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line)));
update "small_test" set nztm_left_poly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,100)),st_startpoint(nztm_line))))
update "small_test" set nztm_left_poly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where roadid<>20672 and roadid<>22589 and roadid<>28032
select st_astext(st_startpoint(nztm_line)) from small_test where roadid=28345
update "small_test" set nztm_right_poly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1

ALTER TABLE "Canterbury" ADD COLUMN nztm_line geometry(LineString,2193);
ALTER TABLE "Canterbury" ADD COLUMN nztm_left_poly geometry(polygon,2193);
ALTER TABLE "Canterbury" ADD COLUMN nztm_right_poly geometry(polygon,2193);
update "Canterbury" set nztm_line = st_transform(the_geom,2193);
update "Canterbury" set nztm_right_poly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where to_number(linzid,'999999')>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Canterbury" set nztm_left_poly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where to_number(linzid,'999999')>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;

