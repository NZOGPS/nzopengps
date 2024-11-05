@echo on
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof

set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
cd SQLData
..\..\wrongside\mp_2_n_sql2.pl -ci %nzogps_base%\%1.mp
cd ..
%nzogps_psqlc% -f SQLData\%1_numberlines.sql
%nzogps_psqlc% -f SQLData\%1_cities.sql
%nzogps_psqlc% -f SQLData\%1_pois.sql

%nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -f Code\postprocities.sql
%nzogps_psqlc% -v ptable=%1_pois -f Code\postproPOI.sql

set nzogps_CXLT=..\..\LinzDataService\CityXlate\%1_cidxlt.csv
if exist %nzogps_CXLT% %nzogps_ogr2ogr% -overwrite --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo autodetect_type=yes %nzogps_CXLT%
if exist %nzogps_CXLT% %nzogps_psqlc% -v ctable=%1_cities -v xtable=%1_cidxlt -f Code\procxlt.sql

%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-nearpois.csv' -f Code\nearpois.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-unindexed.csv' -f Code\unindexed.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-sizecodes.csv' -f Code\sizecodes.sql

%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-mappois.csv' -f Code\mappois.sql
%nzogps_perl_cmd% code\changemp.pl %1 > Outputs\%1-mapped.mp