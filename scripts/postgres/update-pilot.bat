@echo on
setlocal

rem change from nz-addresses to nz-addresses-pilot

set nzogps_nzad=..\..\LinzDataService\nz-addresses-pilot\nz-addresses-pilot.csv
set nzogps_nzrd=..\..\LinzDataService\nz-addresses-roads-pilot\nz-addresses-roads-pilot.csv

%nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_nzad"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %0"' > ..\linz_updates\LINZ_last_pilot.date

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file
if not defined nzogps_ogr2ogr call ..\..\setlocals.bat

%nzogps_psql_bin%pg_ctl status -D %nzogps_psql_data%
if errorlevel 3 %nzogps_psql_bin%pg_ctl start -D %nzogps_psql_data%

@%nzogps_psql_bin%psql -U postgres -d nzopengps -c "SELECT ST_ASTEXT(ST_POINT(45,45))" | grep -q "POINT(45 45)"
if errorlevel 1 echo Error - No PostGIS installed?  & pause & exit 1

for %%f in ("%nzogps_nzad%" "%nzogps_nzrd%") do (
%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
if errorlevel 1 echo Wrong projection  & pause & exit 1
)

time /t
rem addresses
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT "%nzogps_nzad%"

time /t
rem roads
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT -nlt MULTILINESTRING "%nzogps_nzrd%"

time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc-pilot.sql
time /t
rem need to decide whether to split out multilines into lines before suburb processing...
%nzogps_psql_bin%psql -U postgres -d nzopengps < add_burbs-pilot.sql
time /t

%nzogps_touch_cmd% ../database-pilot.date
