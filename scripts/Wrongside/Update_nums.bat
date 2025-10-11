@echo off
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps

if /i %1 equ Northland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord > -36.39;"
if /i %1 equ Auckland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-36.39 and gd2000_ycoord >-37.105228;"
if /i %1 equ Waikato	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-37.105228 and gd2000_ycoord >-38.638100;"
if /i %1 equ Central	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-38.638100 and gd2000_ycoord >-40.170971;"
if /i %1 equ Wellington	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-40.170971 and gd2000_ycoord >-41.703838 and gd2000_xcoord >174.561661;"
if /i %1 equ Tasman		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-40.407970 and gd2000_ycoord >-41.703838 and gd2000_xcoord <174.561661;"
if /i %1 equ Canterbury	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-42.731949 and gd2000_ycoord >-44.55553 and gd2000_xcoord > 0;"
if /i %1 equ Southland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where gd2000_ycoord <-44.55553;"

%nzogps_psqlc% -v numstable=%1_nums  -f Code\postpro-nums.sql
