@echo on
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof

set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
..\wrongside\mp_2_n_sql.pl -c %nzogps_base%\%1.mp
%nzogps_psqlc% -f %1_numberlines.sql
%nzogps_psqlc% -f %1_cities.sql
%nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -f postprocities.sql

set nzogps_CXLT=..\..\LinzDataService\CityXlate\%1_cidxlt.csv
if exist %nzogps_CXLT% %nzogps_ogr2ogr% -overwrite --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo autodetect_type=yes %nzogps_CXLT%
if exist %nzogps_CXLT% %nzogps_psqlc% -v ctable=%1_cities -v xtable=%1_cidxlt -f procxlt.sql

%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\%1-UnmatchedCities.csv' -f unmatched.sql
%nzogps_psqlc% -v ctable=%1_cities -v outfile='%nzogps_base%\scripts\suburbs\%1-UnusedCities.csv' -f unused.sql
rem %nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -v outfile='%nzogps_base%\scripts\suburbs\%1-WrongCities.csv' -f wrong.sql
%nzogps_psqlc% -v ctable=%1_cities -v ntable=%1_numberlines -v outfile='%nzogps_base%\scripts\suburbs\%1-WrongCities2.csv' -f wrong2.sql