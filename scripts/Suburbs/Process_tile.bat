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

set nzogps_CXLT=..\..\LinzDataService\CityXlate\%1_cidxlt.csv
if exist %nzogps_CXLT% %nzogps_ogr2ogr% -overwrite --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo autodetect_type=yes %nzogps_CXLT%
if exist %nzogps_CXLT% %nzogps_psqlc% -v ctable=%1_cities -v xtable=%1_cidxlt -v of1='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongXLTCityID.csv' -v of2='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongXLTSLID.csv' -f Code\procxlt.sql

set nzogps_CDNE=..\..\LinzDataService\CityXlate\%1_dont_cityindex.csv
if exist %nzogps_CDNE% %nzogps_ogr2ogr% -overwrite --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo autodetect_type=yes %nzogps_CDNE%
if exist %nzogps_CDNE% %nzogps_psqlc% -v ctable=%1_cities -v ditable=%1_dont_cityindex -f Code\proccdni.sql

%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-UnmatchedCities.csv' -f Code\unmatched.sql
%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-UnusedCities.csv' -f Code\unused.sql

%nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongCities2.csv' -f Code\wrong2.sql

rem %nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -v mdist=5000 -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongCities5k.csv' -f Code\wrong3.sql

%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-nearpois.csv' -f Code\nearpois.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-unindexed.csv' -f Code\unindexed.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-sizecodes.csv' -f Code\sizecodes.sql

%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-dupliPOIs.csv' -f Code\dupliPOIs.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-checkPOIs.csv' -f Code\checkPOIs.sql
%nzogps_psqlc% -v ctable=%1_cities -v ptable=%1_pois -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-mappois.csv' -f Code\mappois.sql

%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\Outputs\%1-WrongRegions.csv' -f Code\WrongRegions.sql

%nzogps_perl_cmd% code\changemp2.pl %1 > Outputs\mapped\%1.mp
