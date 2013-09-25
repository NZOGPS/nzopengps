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

Alter Table "Southland" Add Column nnums smallint;
update "Southland" set nnums = array_length(numbers,1);
Alter Table "Southland" Add Column nztm_line geometry(LineString,2193);
Update "Southland" set nztm_line = st_transform(the_geom,2193);
Alter Table "Southland" Add Column numberlines geometry(linestring,2193)[];
Alter Table "Southland" Add Column numberleft geometry(polygon,2193)[];
Alter Table "Southland" Add Column numberight geometry(polygon,2193)[];

Create table "Northland-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)>-35.572380

Create table "Auckland-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-35.572380 and st_y(the_geom)>-37.105228;
Alter table "Auckland-Nums" add primary key (gid);
CREATE INDEX idx_ak_rna_id ON "Auckland-Nums" USING btree (rna_id);
ALTER TABLE "Auckland-Nums" ADD COLUMN nztm geometry(Point,2193);
update "Auckland-Nums" set nztm = st_transform(the_geom,2193);

Create table "Southland-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-45.055931 and st_y(the_geom)>-47.450901;

Alter table "Southland-Nums" add primary key (gid);
Create Index idx_sth_rna_id ON "Southland-Nums" USING btree (rna_id);

Alter Table "Southland-Nums" Add Column  nztm geometry(Point,2193);
update "Southland-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Southland-Nums" Add Column asnum_side smallint;
Alter Table "Southland-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Southland-Nums" Add Column asnum_segment smallint;
Alter Table "Southland-Nums" Add Column asnum_distance double precision;

Alter Table "Southland-Nums" Add Column isect_side smallint;
Alter Table "Southland-Nums" Add Column isect_roadid numeric(10);
Alter Table "Southland-Nums" Add Column isect_segment smallint;
Alter Table "Southland-Nums" Add Column isect_distance double precision;


create or replace function gt_splitline(line geometry, nodes character varying[]) returns geometry(LineString,2193)[] as $$
DECLARE 
	j smallint;
	nlines geometry(LineString,2193)[];
	
BEGIN
	for i in 1.. array_length(nodes,1) loop
		j = nodes[i][1]::integer;
		nlines[i] = ST_MakeLine(ST_PointN(line,j+1),ST_PointN(line,j+2));
		j=j+1;
		while j < ST_NPoints(line) and j < nodes[i+1][1]::integer loop
			j = j + 1;
			nlines[i] = ST_AddPoint(nlines[i],ST_PointN(line,j),-1);
		end loop;
	end loop;
	return nlines;
END;
$$ language plpgsql;

select st_astext(the_geom) from "Southland" where roadid=43
"LINESTRING(167.61198 -45.56451,167.61102 -45.56498,167.61006 -45.56565,167.60928 -45.56599,167.60902 -45.56614,167.60881 -45.56644,167.60844 -45.5674,167.60833 -45.56758,167.6078 -45.5682,167.60783 -45.56837,167.60867 -45.56882,167.60916 -45.56903,167.60948 -45.56908,167.61064 -45.56908,167.61128 -45.56906)"

select gt_splitline(nztm_line,numbers[1:nnums][1:1]) from "Southland" where roadid=43
update "Southland" set numberlines = gt_splitline(nztm_line,numbers[1:nnums][1:1]) where roadid=43

select range_low,start,"end",type,address from "Southland-Nums" join "SouthlandPaperNumbers" on "Southland-Nums".rna_id = "SouthlandPaperNumbers".linzid
select range_low,start,"end",type,address from "Southland-Nums" join "SouthlandPaperNumbers" on "Southland-Nums".rna_id = "SouthlandPaperNumbers".linzid where gt_within(range_low,start,"end",type)

update "Southland-Nums" set asnum_side = 2 from "SouthlandPaperNumbers" where  "Southland-Nums".rna_id = "SouthlandPaperNumbers".linzid and gt_within(range_low,start,"end",type) 

CREATE OR REPLACE FUNCTION gt_within(number integer, start integer, last integer, type character varying)
  RETURNS boolean AS
$BODY$
DECLARE 
	ret boolean;
	
BEGIN
	if type = 'E' then
		if mod(number,2)=1 then
			return FALSE;
		end if;
		if number/2 between start/2 and last/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'O' then
		if mod(number,2)=0 then
			return FALSE;
		end if;
		if (number-1)/2 between (start-1)/2 and (last-1)/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'B' then
		if number between start and last then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;

END;
$BODY$
  LANGUAGE plpgsql