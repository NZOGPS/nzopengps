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
Alter Table "Southland-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Southland-Nums" Add Column isect_side smallint;
Alter Table "Southland-Nums" Add Column isect_roadid numeric(10);
Alter Table "Southland-Nums" Add Column isect_segment smallint;
Alter Table "Southland-Nums" Add Column isect_distance double precision;
Alter Table "Southland-Nums" Add Column asnum_dist_err double precision;


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


CREATE OR REPLACE FUNCTION gt_within(number integer, start integer, last integer, type character varying)
  RETURNS boolean AS
$BODY$
DECLARE 
	ret boolean;
	n1 integer;
	n2 integer;
	
BEGIN
	if last >= start then
		n1 = start;
		n2 = last;
	else
		n2 = start;
		n1 = last;	
	end if;
	if type = 'N' then
		return FALSE;
	end if;
	if type = 'E' then
		if mod(number,2)=1 then
			return FALSE;
		end if;
		if number/2 between n1/2 and n2/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'O' then
		if mod(number,2)=0 then
			return FALSE;
		end if;
		if (number-1)/2 between (n1-1)/2 and (n2-1)/2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
	if type = 'B' then
		if number between n1 and n2 then
			return TRUE;
		else
			return FALSE;
		end if;
	end if;
END;
$BODY$
  LANGUAGE plpgsql
  
create or replace function gt_splitline2(roadid integer, linzid integer, line geometry, nodes character varying[]) returns set of record as $$
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

create type numberedline as
(
  line geometry(LineString,2193),
  nodes character varying[7]
);

Alter Table "Southland-numberlines" Add Column nztm_line geometry(LineString,2193);
Update "Southland-numberlines" set nztm_line = st_transform(the_geom,2193);
Alter Table "Southland-numberlines" Add Column leftpoly geometry(polygon,2193);
Alter Table "Southland-numberlines" Add Column rightpoly geometry(polygon,2193);
update "Southland-numberlines" set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Southland-numberlines" set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;

update "Southland-Nums" set asnum_roadid = -1 from "SouthlandPaperNumbers" where  "Southland-Nums".rna_id = "SouthlandPaperNumbers".linzid and gt_within(range_low,start,"end",type) 
select address,rna_id from "Southland-Nums", "Southland-numberlines" where  "Southland-Nums".rna_id = "Southland-numberlines".linzid and gt_within(range_low,lstart,"lend",ltype) and "Southland-Nums".asnum_roadid=-1
update "Southland-Nums" set asnum_roadid="Southland-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Southland-numberlines" where  "Southland-Nums".rna_id = "Southland-numberlines".linzid and gt_within(range_low,lstart,"lend",ltype) ;
update "Southland-Nums" set asnum_roadid="Southland-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Southland-numberlines" where  "Southland-Nums".rna_id = "Southland-numberlines".linzid and gt_within(range_low,rstart,"rend",rtype) ;

create or replace function gt_distance(number integer, side integer, n1 integer, n2 integer) returns double precision as $$	
BEGIN
	if n1 = n2 then
		return 0.5;
	end if;
	return (number - n1)::double precision/(n2-n1)::double precision;
END;
$$ language plpgsql;

update "Southland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Southland-numberlines" where "Southland-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Southland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Southland-numberlines" where "Southland-numberlines".gid=asnum_roadid and asnum_side=1;
update "Southland-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Southland-numberlines" where "Southland-numberlines".gid=asnum_roadid;
update "Southland-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Southland-Nums" set isect_side=1, isect_roadid="Southland-numberlines".gid from "Southland-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Southland-Nums" set isect_side=-1, isect_roadid="Southland-numberlines".gid from "Southland-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);
select address,st_y(the_geom),st_x(the_geom) from "Southland-Nums" where asnum_roadid = isect_roadid and asnum_side*isect_side=-1
 copy(select st_x(the_geom),st_y(the_geom),address,'Wrong Side' from "Southland-Nums" where asnum_roadid = isect_roadid and asnum_side*isect_side=-1) to 'C:\Gary\NZOGPS\nzopengps\scripts\Southland-Wrongside.csv' with CSV;


Alter Table "Canterbury-numberlines" Add Column nztm_line geometry(LineString,2193);
Update "Canterbury-numberlines" set nztm_line = st_transform(the_geom,2193);
Alter Table "Canterbury-numberlines" Add Column leftpoly geometry(polygon,2193);
Alter Table "Canterbury-numberlines" Add Column rightpoly geometry(polygon,2193);
update "Canterbury-numberlines" set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Canterbury-numberlines" set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;


Create table "Canterbury-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-42.731949 and st_y(the_geom)>-45.055931 and st_x(the_geom) > 0;

Alter table "Canterbury-Nums" add primary key (gid);
Create Index idx_can_rna_id ON "Canterbury-Nums" USING btree (rna_id);

Alter Table "Canterbury-Nums" Add Column  nztm geometry(Point,2193);
update "Canterbury-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Canterbury-Nums" Add Column asnum_side smallint;
Alter Table "Canterbury-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Canterbury-Nums" Add Column asnum_segment smallint;
Alter Table "Canterbury-Nums" Add Column asnum_distance double precision;
Alter Table "Canterbury-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Canterbury-Nums" Add Column isect_side smallint;
Alter Table "Canterbury-Nums" Add Column isect_roadid numeric(10);
Alter Table "Canterbury-Nums" Add Column isect_segment smallint;
Alter Table "Canterbury-Nums" Add Column isect_distance double precision;
Alter Table "Canterbury-Nums" Add Column asnum_dist_err double precision;

update "Canterbury-Nums" set asnum_roadid="Canterbury-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Canterbury-numberlines" where  "Canterbury-Nums".rna_id = "Canterbury-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Canterbury-Nums" set asnum_roadid="Canterbury-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Canterbury-numberlines" where  "Canterbury-Nums".rna_id = "Canterbury-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Canterbury-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Canterbury-numberlines" where "Canterbury-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Canterbury-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Canterbury-numberlines" where "Canterbury-numberlines".gid=asnum_roadid and asnum_side=1;
update "Canterbury-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Canterbury-numberlines" where "Canterbury-numberlines".gid=asnum_roadid;
update "Canterbury-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Canterbury-Nums" set isect_side=1, isect_roadid="Canterbury-numberlines".gid from "Canterbury-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Canterbury-Nums" set isect_side=-1, isect_roadid="Canterbury-numberlines".gid from "Canterbury-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);


Alter Table "Tasman-numberlines" Add Column nztm_line geometry(LineString,2193);
Update "Tasman-numberlines" set nztm_line = st_transform(the_geom,2193);
Alter Table "Tasman-numberlines" Add Column leftpoly geometry(polygon,2193);
Alter Table "Tasman-numberlines" Add Column rightpoly geometry(polygon,2193);
update "Tasman-numberlines" set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Tasman-numberlines" set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;


Create table "Tasman-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-40.407970 and st_y(the_geom)>-41.703838 and st_x(the_geom) <174.561661;

Alter table "Tasman-Nums" add primary key (gid);
Create Index idx_tas_rna_id ON "Tasman-Nums" USING btree (rna_id);

Alter Table "Tasman-Nums" Add Column  nztm geometry(Point,2193);
update "Tasman-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Tasman-Nums" Add Column asnum_side smallint;
Alter Table "Tasman-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Tasman-Nums" Add Column asnum_segment smallint;
Alter Table "Tasman-Nums" Add Column asnum_distance double precision;
Alter Table "Tasman-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Tasman-Nums" Add Column isect_side smallint;
Alter Table "Tasman-Nums" Add Column isect_roadid numeric(10);
Alter Table "Tasman-Nums" Add Column isect_segment smallint;
Alter Table "Tasman-Nums" Add Column isect_distance double precision;
Alter Table "Tasman-Nums" Add Column asnum_dist_err double precision;

update "Tasman-Nums" set asnum_roadid="Tasman-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Tasman-numberlines" where  "Tasman-Nums".rna_id = "Tasman-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Tasman-Nums" set asnum_roadid="Tasman-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Tasman-numberlines" where  "Tasman-Nums".rna_id = "Tasman-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Tasman-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Tasman-numberlines" where "Tasman-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Tasman-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Tasman-numberlines" where "Tasman-numberlines".gid=asnum_roadid and asnum_side=1;
update "Tasman-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Tasman-numberlines" where "Tasman-numberlines".gid=asnum_roadid;
update "Tasman-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Tasman-Nums" set isect_side=1, isect_roadid="Tasman-numberlines".gid from "Tasman-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Tasman-Nums" set isect_side=-1, isect_roadid="Tasman-numberlines".gid from "Tasman-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);

copy(select st_x(the_geom),st_y(the_geom),address,'Wrong Side' from "Tasman-Nums" where asnum_roadid = isect_roadid and asnum_side*isect_side=-1) to 'C:\Gary\NZOGPS\nzopengps\scripts\Tasman-Wrongside.csv' with CSV;

Alter Table "Wellington-numberlines" Add Column nztm_line geometry(LineString,2193);
Update "Wellington-numberlines" set nztm_line = st_transform(the_geom,2193);
Alter Table "Wellington-numberlines" Add Column leftpoly geometry(polygon,2193);
Alter Table "Wellington-numberlines" Add Column rightpoly geometry(polygon,2193);
update "Wellington-numberlines" set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Wellington-numberlines" set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;

Create table "Wellington-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-40.170971 and st_y(the_geom)>-41.703838 and st_x(the_geom) >174.561661;

Alter table "Wellington-Nums" add primary key (gid);
Create Index idx_wlg_rna_id ON "Wellington-Nums" USING btree (rna_id);

Alter Table "Wellington-Nums" Add Column  nztm geometry(Point,2193);
update "Wellington-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Wellington-Nums" Add Column asnum_side smallint;
Alter Table "Wellington-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Wellington-Nums" Add Column asnum_segment smallint;
Alter Table "Wellington-Nums" Add Column asnum_distance double precision;
Alter Table "Wellington-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Wellington-Nums" Add Column isect_side smallint;
Alter Table "Wellington-Nums" Add Column isect_roadid numeric(10);
Alter Table "Wellington-Nums" Add Column isect_segment smallint;
Alter Table "Wellington-Nums" Add Column isect_distance double precision;
Alter Table "Wellington-Nums" Add Column asnum_dist_err double precision;

update "Wellington-Nums" set asnum_roadid="Wellington-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Wellington-numberlines" where  "Wellington-Nums".rna_id = "Wellington-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Wellington-Nums" set asnum_roadid="Wellington-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Wellington-numberlines" where  "Wellington-Nums".rna_id = "Wellington-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Wellington-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Wellington-numberlines" where "Wellington-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Wellington-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Wellington-numberlines" where "Wellington-numberlines".gid=asnum_roadid and asnum_side=1;
update "Wellington-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Wellington-numberlines" where "Wellington-numberlines".gid=asnum_roadid;
update "Wellington-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Wellington-Nums" set isect_side=1, isect_roadid="Wellington-numberlines".gid from "Wellington-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Wellington-Nums" set isect_side=-1, isect_roadid="Wellington-numberlines".gid from "Wellington-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);


Create table "Central-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-38.638100 and st_y(the_geom)>-40.170971;

Alter table "Central-Nums" add primary key (gid);
Create Index idx_ctl_rna_id ON "Central-Nums" USING btree (rna_id);

Alter Table "Central-Nums" Add Column  nztm geometry(Point,2193);
update "Central-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Central-Nums" Add Column asnum_side smallint;
Alter Table "Central-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Central-Nums" Add Column asnum_segment smallint;
Alter Table "Central-Nums" Add Column asnum_distance double precision;
Alter Table "Central-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Central-Nums" Add Column isect_side smallint;
Alter Table "Central-Nums" Add Column isect_roadid numeric(10);
Alter Table "Central-Nums" Add Column isect_segment smallint;
Alter Table "Central-Nums" Add Column isect_distance double precision;
Alter Table "Central-Nums" Add Column asnum_dist_err double precision;

update "Central-Nums" set asnum_roadid="Central-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Central-numberlines" where  "Central-Nums".rna_id = "Central-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Central-Nums" set asnum_roadid="Central-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Central-numberlines" where  "Central-Nums".rna_id = "Central-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Central-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Central-numberlines" where "Central-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Central-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Central-numberlines" where "Central-numberlines".gid=asnum_roadid and asnum_side=1;
update "Central-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Central-numberlines" where "Central-numberlines".gid=asnum_roadid;
update "Central-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Central-Nums" set isect_side=1, isect_roadid="Central-numberlines".gid from "Central-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Central-Nums" set isect_side=-1, isect_roadid="Central-numberlines".gid from "Central-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);



Create table "Waikato-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-37.105228 and st_y(the_geom)>-38.638100;

Alter table "Waikato-Nums" add primary key (gid);
Create Index idx_wkt_rna_id ON "Waikato-Nums" USING btree (rna_id);

Alter Table "Waikato-Nums" Add Column  nztm geometry(Point,2193);
update "Waikato-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Waikato-Nums" Add Column asnum_side smallint;
Alter Table "Waikato-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Waikato-Nums" Add Column asnum_segment smallint;
Alter Table "Waikato-Nums" Add Column asnum_distance double precision;
Alter Table "Waikato-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Waikato-Nums" Add Column isect_side smallint;
Alter Table "Waikato-Nums" Add Column isect_roadid numeric(10);
Alter Table "Waikato-Nums" Add Column isect_segment smallint;
Alter Table "Waikato-Nums" Add Column isect_distance double precision;
Alter Table "Waikato-Nums" Add Column asnum_dist_err double precision;

update "Waikato-Nums" set asnum_roadid="Waikato-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Waikato-numberlines" where  "Waikato-Nums".rna_id = "Waikato-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Waikato-Nums" set asnum_roadid="Waikato-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Waikato-numberlines" where  "Waikato-Nums".rna_id = "Waikato-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Waikato-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Waikato-numberlines" where "Waikato-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Waikato-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Waikato-numberlines" where "Waikato-numberlines".gid=asnum_roadid and asnum_side=1;
update "Waikato-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Waikato-numberlines" where "Waikato-numberlines".gid=asnum_roadid;
update "Waikato-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Waikato-Nums" set isect_side=1, isect_roadid="Waikato-numberlines".gid from "Waikato-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Waikato-Nums" set isect_side=-1, isect_roadid="Waikato-numberlines".gid from "Waikato-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);



Create table "Auckland-Nums" as select * from "nz-street-address-elector" where st_y(the_geom)<-35.572380 and st_y(the_geom)>-37.105228;

Alter table "Auckland-Nums" add primary key (gid);
Create Index idx_akl_rna_id ON "Auckland-Nums" USING btree (rna_id);

Alter Table "Auckland-Nums" Add Column  nztm geometry(Point,2193);
update "Auckland-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Auckland-Nums" Add Column asnum_side smallint;
Alter Table "Auckland-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Auckland-Nums" Add Column asnum_segment smallint;
Alter Table "Auckland-Nums" Add Column asnum_distance double precision;
Alter Table "Auckland-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Auckland-Nums" Add Column isect_side smallint;
Alter Table "Auckland-Nums" Add Column isect_roadid numeric(10);
Alter Table "Auckland-Nums" Add Column isect_segment smallint;
Alter Table "Auckland-Nums" Add Column isect_distance double precision;
Alter Table "Auckland-Nums" Add Column asnum_dist_err double precision;

update "Auckland-Nums" set asnum_roadid="Auckland-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Auckland-numberlines" where  "Auckland-Nums".rna_id = "Auckland-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Auckland-Nums" set asnum_roadid="Auckland-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Auckland-numberlines" where  "Auckland-Nums".rna_id = "Auckland-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Auckland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Auckland-numberlines" where "Auckland-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Auckland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Auckland-numberlines" where "Auckland-numberlines".gid=asnum_roadid and asnum_side=1;
update "Auckland-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Auckland-numberlines" where "Auckland-numberlines".gid=asnum_roadid;
update "Auckland-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Auckland-Nums" set isect_side=1, isect_roadid="Auckland-numberlines".gid from "Auckland-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Auckland-Nums" set isect_side=-1, isect_roadid="Auckland-numberlines".gid from "Auckland-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);


Alter Table "Northland-numberlines" Add Column nztm_line geometry(LineString,2193);
Update "Northland-numberlines" set nztm_line = st_transform(the_geom,2193);
Alter Table "Northland-numberlines" Add Column leftpoly geometry(polygon,2193);
Alter Table "Northland-numberlines" Add Column rightpoly geometry(polygon,2193);
update "Northland-numberlines" set rightpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_offsetcurve(nztm_line,-100)),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,-100))=1;
update "Northland-numberlines" set leftpoly = st_makepolygon(st_addpoint(st_makeline(nztm_line,st_reverse(st_offsetcurve(nztm_line,100))),st_startpoint(nztm_line))) where linzid>0 and ST_NumGeometries(st_offsetcurve(nztm_line,100))=1;

Create table "Northland-Nums" as select * from "nz-street-address-elector" where  st_y(the_geom)> -35.572380;

Alter table "Northland-Nums" add primary key (gid);
Create Index idx_nth_rna_id ON "Northland-Nums" USING btree (rna_id);

Alter Table "Northland-Nums" Add Column  nztm geometry(Point,2193);
update "Northland-Nums" set nztm = st_transform(the_geom,2193);

Alter Table "Northland-Nums" Add Column asnum_side smallint;
Alter Table "Northland-Nums" Add Column asnum_roadid numeric(10);
Alter Table "Northland-Nums" Add Column asnum_segment smallint;
Alter Table "Northland-Nums" Add Column asnum_distance double precision;
Alter Table "Northland-Nums" Add Column asnum_position geometry(Point,2193);

Alter Table "Northland-Nums" Add Column isect_side smallint;
Alter Table "Northland-Nums" Add Column isect_roadid numeric(10);
Alter Table "Northland-Nums" Add Column isect_segment smallint;
Alter Table "Northland-Nums" Add Column isect_distance double precision;
Alter Table "Northland-Nums" Add Column asnum_dist_err double precision;

update "Northland-Nums" set asnum_roadid="Northland-numberlines".gid,asnum_side=-1,asnum_segment=nnum  from "Northland-numberlines" where  "Northland-Nums".rna_id = "Northland-numberlines".linzid and gt_within(range_low,lstart,lend,ltype) ;
update "Northland-Nums" set asnum_roadid="Northland-numberlines".gid,asnum_side=1,asnum_segment=nnum  from "Northland-numberlines" where  "Northland-Nums".rna_id = "Northland-numberlines".linzid and gt_within(range_low,rstart,rend,rtype) ;
update "Northland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,lstart,lend) from "Northland-numberlines" where "Northland-numberlines".gid=asnum_roadid and asnum_side=-1;
update "Northland-Nums" set asnum_distance=gt_distance(range_low,asnum_side,rstart,rend) from "Northland-numberlines" where "Northland-numberlines".gid=asnum_roadid and asnum_side=1;
update "Northland-Nums" set asnum_position=ST_Line_Interpolate_Point(nztm_line,asnum_distance) from "Northland-numberlines" where "Northland-numberlines".gid=asnum_roadid;
update "Northland-Nums" set asnum_dist_err=ST_Distance(nztm,asnum_position) ;
update "Northland-Nums" set isect_side=1, isect_roadid="Northland-numberlines".gid from "Northland-numberlines" where rna_id=linzid and ST_Intersects(nztm,rightpoly);
update "Northland-Nums" set isect_side=-1, isect_roadid="Northland-numberlines".gid from "Northland-numberlines" where rna_id=linzid and ST_Intersects(nztm,leftpoly);

copy(select st_x(the_geom),st_y(the_geom),address,'Wrong Side' from "Northland-Nums" where asnum_roadid = isect_roadid and asnum_side*isect_side=-1) to 'C:\Gary\NZOGPS\nzopengps\scripts\Northland-Wrongside.csv' with CSV;

select st_length (nztm_line) as len,label,st_y(st_startpoint(the_geom)),st_x(st_startpoint(the_geom)),lstart from canterbury_numberlines where lstart=lend and lstart > 0 order by len desc;
select st_length (nztm_line) as len,label,st_y(st_startpoint(the_geom)),st_x(st_startpoint(the_geom)),rstart from canterbury_numberlines where rstart=rend and rstart > 0 order by len desc;
select st_length (nztm_line)/(abs(lstart-lend)) as len,label,st_y(st_startpoint(the_geom)),st_x(st_startpoint(the_geom)),lstart,lend from canterbury_numberlines where lstart<>lend and lstart > 0 order by len desc;
select st_length (nztm_line)/(abs(rstart-rend)) as len,label,st_y(st_startpoint(the_geom)),st_x(st_startpoint(the_geom)),rstart,rend from canterbury_numberlines where rstart<>rend and rstart > 0 order by len desc;

create or replace function border() returns table(x real, sum bigint) as $$
declare x real;
begin   
    x := -45.05594;
    while x < -44.2 loop
        return query select x,sum(st_npoints(st_intersection(the_geom,st_setsrid(st_makeline(st_point(167.7,x),st_point(171.5,x)),4167)))) from canterbury_numberlines;
        x := x + 0.0004;
    end loop;
end
$$ language plpgsql;

create or replace function border() returns table(x real, sum bigint) as $$
declare x real;
begin 	
	x := -35.5724;
	while x > -36.4 loop
		return query select x,sum(st_npoints(st_intersection(the_geom,st_setsrid(st_makeline(st_point(173.3,x),st_point(175,x)),4167)))) from auckland_numberlines;
		x := x - 0.0004;
	end loop;
end
$$ language plpgsql;

create or replace function NewRoadBookmarks() returns void as
$nrbm$
DECLARE
   _name text;
   _date text;
BEGIN
   SELECT CURRENT_DATE into _date;
   FOR _name IN
      SELECT name FROM _bounds
   LOOP
   EXECUTE format('COPY (select st_y(ST_LineInterpolatePoint(ST_LineMerge(wkb_geometry),0.5)),st_x(ST_LineInterpolatePoint(ST_LineMerge(wkb_geometry),0.5)),full_road_name,road_id
                                 FROM   _bounds b
                            JOIN   layer_3383_cs p ON ST_INTERSECTS(st_flipcoordinates(geom), wkb_geometry)
                            WHERE  b.name = %L and __change__ = ''INSERT'' and geometry_class = ''Addressing Road'' and road_section_id not in (select road_section_id  from layer_3383_cs where __change__ = ''DELETE'') and road_id > 3000000
                            ) TO %L (FORMAT csv)'
                   , _name
                   , 'd:\nzopengps\linzdataservice\outputslinz\' || _name || '_' || _date || '.csv');'
   END LOOP;
END
$nrbm$ language plpgsql;

copy ( select * from ( select name, old.id, new.road_id, st_hausdorffdistance(new.the_geom,old.the_geom) d from nz_road_centre_line old  join nz_roads_addressing new on new.full_road_ = old.name and id<>road_id ) as t where d < 0.01 order by d ) to 'd:\nzopengps\scripts\outputs\same_name_id_trans.txt' 

copy ( select * from ( select name, old.id, new.road_id, st_hausdorffdistance(new.the_geom,old.the_geom) d from nz_road_centre_line old  join nz_roads_addressing new on new.road_type = old.name and id<>road_id ) as t where d < 0.01 order by d ) to 'd:\nzopengps\scripts\outputs\access-service_id_trans.txt'

with ng as ( select label,roadid,the_geom,st_dump(st_node(the_geom))as t from wellington_numberlines where not st_issimple(the_geom)) select distinct on (roadid) label, st_numpoints((t).geom), concat(st_y(st_pointn((t).geom,1)),',',st_x(st_pointn((t).geom,1))) from ng order by roadid, st_numpoints((t).geom

-- comparing parks in map to parks in database
-- import parks shapefile with ? 
-- perl mp_2_sql.pl -p ..\Canterbury.mp
-- %nzogps_psql_bin%\psql -U postgres -d nzopengps -f Canterbury-polys.sql

SELECT UpdateGeometrySRID('parks','geom',2193);
update parks set centroid_lat = st_y(st_centroid(st_transform(geom,4167))),centroid_lon = st_x(st_centroid(st_transform(geom,4167)))

SELECT p1.common_nam,p1.centroid_lat,p1.centroid_lon,p1.shape_area
FROM parks p1
LEFT JOIN "Canterbury-polys" p2 ON upper(p2.label) = upper(p1.common_nam)
WHERE p2.label IS NULL and p1.centroid_lat::double precision > -44.55553 and p1.shape_area::double precision > 500
order by p1.shape_area desc

SELECT p1.common_nam,p1.centroid_lat::double precision,p1.centroid_lon::double precision,p1.shape_area,st_distance(st_transform(st_setsrid(st_point(p1.centroid_lon::float,p1.centroid_lat::float),4326), 2193),st_transform('srid=4326;point(172.58919 -43.52497)'::geometry, 2193)) as d1
FROM parks p1
LEFT JOIN "Canterbury-polys" p2 ON upper(p2.label) = upper(p1.common_nam)
WHERE p2.label IS NULL and p1.centroid_lat::double precision > -44.55553 and p1.shape_area::double precision > 500
order by d1 asc

#Compare columns of two tables
select COALESCE(c1.column_name, c2.column_name) as table_column,
       c1.column_name as table1,
       c2.column_name as table2
from
    (select table_name,
            column_name
     from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = 'nz_street_address') c1
full join
         (select table_name,
                 column_name
          from information_schema.columns c
          where c.table_schema = 'public' and c.table_name = 'layer_3353_cs') c2
on  c1.column_name = c2.column_name
where c1.column_name is null
      or c2.column_name is null
order by c1.table_name,
         table_column;

-- canterbury cities - 402 total 43 are multis
select cityid, label,city,id,major_name,territorial_authority 
	from canterbury_cities
	join nz_suburbs_and_localities 
	on label = name_ascii 
	where nzslid is null 
	order by label;
	
-- ignore lakes and bays!
select cityid, label,city,id,major_name,territorial_authority,type 
	from canterbury_cities
	join nz_suburbs_and_localities 
	on label = name_ascii 
	where nzslid is null and type <> 'Coastal Bay' and type <> 'Lake' and type <> 'Inland Bay'
	order by label;canterbury_cities
	
--compare names in LINZ suburbs to ours #sets 341
update canterbury_cities set linzidx=id 
	from nz_suburbs_and_localities 
	join (
		select label, count(*) as count 
		from canterbury_cities 
		join nz_suburbs_and_localities nzsl 
		on label = name_ascii 
		where linzidx is null and type <> 'Coastal Bay' and type <> 'Lake' and type <> 'Inland Bay'
		group by label 
		having count(*)=1 
	) uni 
	on uni.label = name_ascii 
	where "Canterbury-cities".label=name_ascii 
		and linzidx is null 
		and type <> 'Coastal Bay' and type <> 'Lake' and type <> 'Inland Bay'

-- sets 17
update "Canterbury-cities" set linzidx=id 
	from nz_suburbs_and_localities 
	where label = name_ascii 
	and city = major_name 
	and linzidx is null

select st_collect(the_geom) from canterbury_numberlines where cityidx=277 --returns geometrycollection
select st_collect(tmp.the_geom) from (select the_geom from canterbury_numberlines where cityidx=277 )as tmp -- also works
update canterbury_cities set stbound = (select st_convexhull(st_collect(tmp.the_geom)) from (select the_geom from canterbury_numberlines where cityidx=cityidx )as tmp ) 

-- almost? fails as st_ch returns generic geometry
update canterbury_cities cc set stbound = sq.ch
from (
	select cityidx as ci, st_convexhull(st_collect(the_geom)) as ch from canterbury_numberlines group by cityidx
) as sq 
where cc.cityid = sq.ci
-- weird - need to cast via text
update canterbury_cities cc set stbound = st_polygonfromtext(sq.ch,4167)
from (
	select cityidx as ci, st_astext(st_convexhull(st_collect(the_geom))) as ch from canterbury_numberlines group by cityidx
) as sq 
where cc.cityid = sq.ci
-- roads out of area?
select roadid,cn.label,cc.label,linzid,st_astext(st_pointn(the_geom,0)) from canterbury_numberlines cn join canterbury_cities cc on cityidx = cityid join nz_suburbs_and_localities on linzidx = id where linzidx is not null and not st_intersects(the_geom,wkb_geometry)
select roadid,cn.label,cc.label,linzid,concat_ws(' ',st_y(st_pointn(the_geom,1)),st_x(st_pointn(the_geom,1)))as coords from canterbury_numberlines cn join canterbury_cities cc on cityidx = cityid join nz_suburbs_and_localities on linzidx = id where linzidx is not null and not st_intersects(the_geom,wkb_geometry)
-- what should it be?
select roadid,cn.label,sl.name from canterbury_numberlines cn join nz_suburbs_and_localities sl on st_intersects(the_geom,wkb_geometry) order by sl.name
-- put it together ~22s on Canterbury
select cn.roadid,cn.label,cc.label,sb.name,linzid,
	concat_ws(' ',st_y(st_pointn(the_geom,1)),st_x(st_pointn(the_geom,1)))as coords 
	from canterbury_numberlines cn 
	join canterbury_cities cc on cityidx = cityid 
	join nz_suburbs_and_localities on linzidx = id
	join ( select
		gid,sl.name from canterbury_numberlines cn
		join nz_suburbs_and_localities sl 
		on st_intersects(the_geom,wkb_geometry)) sb on sb.gid = cn.gid
	where linzidx is not null 
	and not st_intersects(the_geom,wkb_geometry) order by sb.name
-- What's not right? 
select cityid,label,city, st_y(st_centroid(stbound))||' '||st_x(st_centroid(stbound)) as coords from canterbury_cities where stbound is null or linzidx is null

SELECT * FROM public.central_pois join central_cities
	on central_pois.label = central_cities.label
	where type = '0xb00' and cityidx=0
	and st_contains(stbound,the_geom)

SELECT st_distance(st_transform(stbound,2193),st_transform(the_geom,2193)),*
	FROM public.central_pois join central_cities
		on central_pois.label = central_cities.label
		where type = '0xb00' and cityidx=0
		and not st_contains(stbound,the_geom)
		order by st_distance

SELECT st_x(the_geom),st_y(the_geom),central_pois.label,city FROM public.central_pois join central_cities
	on central_pois.label = central_cities.label
	where type = '0xb00' and cityidx=0
	and st_contains(stbound,the_geom)
	and city != ''
	order by city

select codehex from citysize where 4567 >= pmin and 4567 < pmax --ok

select name_ascii, major_name_ascii, codehex from citysize 
	join nz_suburbs_and_localities
	on population_estimate >= pmin e
		and population_estimate < pmax
	where name_ascii = 'Otara' --pop=24148 s.b.0x900

select label, type from canterbury_pois
	join canterbury_cities
		on cityidx = cityid

select cp.label, cp.type, codehex, population_estimate from canterbury_pois cp
	join canterbury_cities cc
		on cityidx = cityid
	join nz_suburbs_and_localities
		on nzslid = id
	join citysize
		on population_estimate >= pmin 
			and population_estimate < pmax
	where cp.type <> codehex
	order by type

select label,nzslid,rgnidx,tablename,territorial_authority from waikato_cities
	join regionlist on rgnidx=ogc_fid
	join nz_suburbs_and_localities on nzslid=id


create or replace function slidinregion(slid integer, region integer) returns character varying as $$
declare _districts character varying; --comma delimited
declare _dista character varying[];
declare _disti character varying;
declare _table character varying;
declare _query character varying;
declare _retid character varying;
BEGIN
	select territorial_authority_ascii from nz_suburbs_and_localities
		where id = slid
		into _districts;
--	if _districts is null then
--		raise warning 'ooops';
--		return -1;
--	end if;
	_dista = string_to_array(_districts,',');
	foreach _disti in array _dista
	loop
		_disti = trim(_disti); -- take off space after comma!
		select tablename from regionlist 
			where ogc_fid=region
			into _table;
		_query = 'select ogc_fid from '|| _table ||'_region where district='||quote_literal(_disti) ||' ;';
		execute _query into _retid;
		if _retid is not null 
			then return 0; 
		end if;
	end loop;
	return _table ||' - '|| _districts; 
END;
$$ language plpgsql;

select label,cityid,nzslid,rgnidx, slidinregion(nzslid,rgnidx) as slinr from canterbury_cities
where nzslid is not null
and slidinregion(nzslid,rgnidx)<> '0'

create table temp_southland_not_contains as select sc.rgnidx,src.regc_00,cityid,label,city,stbound,nzslid from nzogps_regions nzo 
	join regional_council src 
		on src.regc_00 = nzo.regc_00
	join southland_cities sc
		on sc.rgnidx = nzo.rgnidx::integer
	where not st_contains(wkb_geometry,stbound) or st_overlaps(wkb_geometry,stbound)
