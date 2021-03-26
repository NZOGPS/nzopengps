drop table if exists :nodedtable;
CREATE TABLE :nodedtable
(
  idx serial PRIMARY KEY,
  roadid integer,
  label character varying(100),
  type character varying(10),
  path integer,
  geom geometry,
  startpt geometry(Point),
  endpt geometry(Point),
  loop character varying(40)
);
insert into :nodedtable(geom,path,roadid,label,type) select (ST_dump(ST_node(the_geom))).geom, (ST_dump(ST_node(the_geom))).path[1],roadid,label,type from :linestable where not ST_IsSimple(the_geom);
update :nodedtable set startpt = st_pointn(geom,1), endpt = st_pointn(geom,st_npoints(geom));
update :nodedtable set loop = st_y(startpt) || ' ' || st_x(startpt) where startpt = endpt;

-- select count(endp),roadid,st_y(endp) || ' ' || st_x(endp) from ( select roadid, startpt as endp from wellington_noded_loops union all select roadid, endpt as endp from wellington_noded_loops ) as ends group by endp,roadid having count(endp)>2


copy(
	select st_x(endp),st_y(endp),label,'Loopy: ' 
	from ( select roadid, label, startpt as endp from :nodedtable union all select roadid, label, endpt as endp from :nodedtable ) 
	as ends group by endp,label, roadid having count(endp)>2 )
	to :outfile with CSV;

