drop table if exists _boundb;
create table _boundb(
	id serial PRIMARY KEY,
	name character varying,
	box box2d,
	poly geometry(Polygon,4167)
);
INSERT INTO _boundb (id,name,box) VALUES 
 (1,'Northland' ,'BOX(171.9     -36.390,   175.8     -34.03   )')
,(2,'Auckland'  ,'BOX(173.26    -37.10523, 176.1043  -36.390  )')
,(3,'Waikato'   ,'BOX(173       -38.63810, 179.0     -37.10523)')
,(4,'Central'   ,'BOX(173.0     -40.17097, 178.323   -38.63810)')
,(5,'Wellington','BOX(174.56166 -41.70384, 176.97476 -40.17097)')
,(6,'Tasman'    ,'BOX(170.840   -42.73194, 174.56166 -40.40797)')
,(7,'Canterbury','BOX(167.0     -44.55553, 173.60    -42.73194)')
,(8,'Southland' ,'BOX(166       -47.45090, 171.6     -44.55553)');

UPDATE _boundb set poly=st_setsrid(box,4167);