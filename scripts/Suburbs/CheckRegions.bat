@echo on
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof

set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
cd SQLData
%nzogps_perl_cmd% ..\..\mp_2_n_sql2.pl -ci %nzogps_base%\%1.mp
cd ..
%nzogps_psqlc% -f SQLData\%1_numberlines.sql
%nzogps_psqlc% -f SQLData\%1_cities.sql
%nzogps_psqlc% -f SQLData\%1_pois.sql

%nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -f Code\postprocities.sql
%nzogps_psqlc% -v ptable=%1_pois -f Code\postproPOI.sql

%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongRegions.csv' -f Code\WrongRegions.sql
