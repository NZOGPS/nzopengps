@echo off
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps

if /i %1 equ Northland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)> -35.572380;"
if /i %1 equ Auckland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-35.572380 and st_y(the_geom)>-37.105228;"
if /i %1 equ Waikato		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-37.105228 and st_y(the_geom)>-38.638100;"
if /i %1 equ Central		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-38.638100 and st_y(the_geom)>-40.170971;"
if /i %1 equ Wellington	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-40.170971 and st_y(the_geom)>-41.703838 and st_x(the_geom) >174.561661;"
if /i %1 equ Tasman		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-40.407970 and st_y(the_geom)>-41.703838 and st_x(the_geom) <174.561661;"
if /i %1 equ Canterbury	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-42.731949 and st_y(the_geom)>-44.55553 and st_x(the_geom) > 0;"
if /i %1 equ Southland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz-street-address-elector\" where st_y(the_geom)<-44.55553;"

%nzogps_psqlc% -v numstable=%1_nums  -f postpro-nums.sql

mp_2_n_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc%   -f %1_numberlines.sql
%nzogps_psqlc% -v linestable=%1_numberlines -v distance=100 -f postpro-lines.sql
%nzogps_psqlc% -v linestable=%1_numberlines  -v numstable=%1_nums -v outfile='%nzogps_base%\scripts\wrongside\%1-WrongSide.csv' -f intersect.sql
perl wrongsidereport.pl %1 > %1-Wrongside-report.txt