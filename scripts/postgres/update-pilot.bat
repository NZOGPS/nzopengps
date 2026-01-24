@echo on
setlocal
set nzogps_nzad=nz_addresses_pilot
set nzogps_nzrd=nz_addresses_roads_pilot
rem change from nz-addresses to nz-addresses-pilot
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
set nzogps_nzadf=..\..\LinzDataService\%nzogps_nzad:_=-%\%nzogps_nzad:_=-%.csv
set nzogps_nzrdf=..\..\LinzDataService\%nzogps_nzrd:_=-%\%nzogps_nzrd:_=-%.csv

%nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_nzadf"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %0"' > ..\linz_updates\LINZ_last_pilot.date

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file
if not defined nzogps_ogr2ogr call ..\..\setlocals.bat

%nzogps_psql_bin%pg_ctl status -D %nzogps_psql_data%
setif errorlevel 3 %nzogps_psql_bin%pg_ctl start -D %nzogps_psql_data%

%nzogps_psqlc% -c "SELECT ST_ASTEXT(ST_POINT(45,45))" | grep -q "POINT(45 45)"
if errorlevel 1 echo Error - No PostGIS installed?  & pause & exit /b 1

for %%f in ("%nzogps_nzadf%" "%nzogps_nzrdf%") do (
%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
if errorlevel 1 echo Wrong projection  & pause & exit /b 1
)

time /t
rem addresses
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT "%nzogps_nzadf%"

time /t
rem roads
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT -nlt MULTILINESTRING "%nzogps_nzrdf%"

time /t
%nzogps_psqlc% -v ADD_TBL=%nzogps_nzad% -v ROAD_TBL=%nzogps_nzrd% -f postproc-pilot.sql
time /t
call add_burbs-pilot.bat 
%nzogps_touch_cmd% ../database-pilot.date
