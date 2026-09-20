@echo off
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps

REM if /i %1 equ Northland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y > -36.39;"
REM if /i %1 equ Auckland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-36.39 and shape_y >-37.105228;"
REM if /i %1 equ Waikato	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-37.105228 and shape_y >-38.638100;"
REM if /i %1 equ Central	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-38.638100 and shape_y >-40.170971;"
REM if /i %1 equ Wellington	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-40.170971 and shape_y >-41.703838 and shape_x >174.561661;"
REM if /i %1 equ Tasman		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-40.407970 and shape_y >-41.703838 and shape_x <174.561661;"
REM if /i %1 equ Canterbury	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-42.731949 and shape_y >-44.55553 and shape_x > 0;"
REM if /i %1 equ Southland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-44.55553;"

%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from nz_addresses join _boundb on st_contains(poly,wkb_geometry) and name='%1'

%nzogps_psqlc% -v numstable=%1_nums  -f Code\postpro-nums.sql
