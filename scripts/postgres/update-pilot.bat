@echo on
setlocal

rem change from nz-addresses to nz-addresses-pilot

set nzogps_sae=..\..\LinzDataService\nz-addresses-pilot\nz-addresses-pilot.csv
set nzogps_rcl=..\..\LinzDataService\nz-addresses-road-sections-pilot\nz-addresses-road-sections-pilot.csv

%nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_sae"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %0"' > ..\linz_updates\LINZ_last_pilot.date

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file
if not defined nzogps_ogr2ogr call ..\..\setlocals.bat

net start %nzogps_psql_svc%
rem if you get error 5 on win8 doing net start - look here: https://thommck.wordpress.com/2011/12/02/how-to-allow-non-admins-to-start-and-stop-system-services/

@%nzogps_psql_bin%psql -U postgres -d nzopengps -c "SELECT ST_ASTEXT(ST_POINT(45,45))" | grep -q "POINT(45 45)"
if errorlevel 1 echo Error - No PostGIS installed?  & pause & exit 1

for %%f in ("%nzogps_sae%" "%nzogps_rcl%") do (
 grep -q  "EPSG:4167" %%~dpnf.vrt
if errorlevel 1 echo Wrong projection  & pause & exit 1
)

time /t

rem new addresses
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT "%nzogps_sae%"
rem roads
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT -nlt LINESTRING "%nzogps_rcl%"
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc-pilot.sql
time /t
touch ../database-pilot.date
