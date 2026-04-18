@echo off
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
if [%1]==[] echo tile not specified. Usage process tile tilename & goto :eof
if [%nzogps_psql_bin%]==[] echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
echo Wrongside processing %1 started %time%

if /i %1 equ Northland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y > -36.39;"
if /i %1 equ Auckland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-36.39 and shape_y >-37.105228;"
if /i %1 equ Waikato	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-37.105228 and shape_y >-38.638100;"
if /i %1 equ Central	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-38.638100 and shape_y >-40.170971;"
if /i %1 equ Wellington	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-40.170971 and shape_y >-41.703838 and shape_x >174.561661;"
if /i %1 equ Tasman		%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-40.407970 and shape_y >-41.703838 and shape_x <174.561661;"
if /i %1 equ Canterbury	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-42.731949 and shape_y >-44.55553 and shape_x > 0;"
if /i %1 equ Southland	%nzogps_psqlc% -c "drop table if exists %1_nums; Create table %1_Nums as select * from \"nz_addresses\" where shape_y <-44.55553;"

if errorlevel 1 echo tile address failed & goto :EOF

%nzogps_psqlc% -v numstable=%1_nums  -f Code\postpro-nums.sql

pushd TempData
%nzogps_perl_cmd% ..\Code\mp_2_n_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc% -f %1_numberlines.sql
popd
%nzogps_psqlc% -t -v linestable=%1_numberlines -v wrongstable=%1_wrongside -v distance=250 -f Code\%nzogps_wsppl%
if errorlevel 1 echo postpro lines failed & goto :EOF
%nzogps_psqlc% -t -v linestable=%1_numberlines -v wrongstable=%1_wrongside -v numstable=%1_nums -v outfile='%cd%\Outputs\%1-WrongSide.csv' -f Code\intersect.sql
%nzogps_psqlc% -v linestable=%1_numberlines -v wrongstable=%1_wrongside -v distance=400 -v outfile='%CD%\Outputs\%1-Sparsest.csv' -f Code\Sparsest.sql
rem if you get a write failure for CSV files you may need to grant write access for the user for the pg server process e.g. NETWORK SERVICE ? Use task manager/details
pushd Outputs
%nzogps_perl_cmd% ..\Code\wrongsidereport.pl %1 > Reports\%1-Wrongside-report.txt
popd
echo Wrongside processing %1 finished %time%
