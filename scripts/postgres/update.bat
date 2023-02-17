@echo on
setlocal

rem change from nz-street-address to nz-addresses
rem set nzogps_sae=..\..\LinzDataService\lds-nz-street-address-CSV\nz-street-address.vrt
set nzogps_sae=..\..\LinzDataService\lds-nz-addresses-CSV\nz-addresses.vrt
set nzogps_rcl=..\..\LinzDataService\lds-nz-roads-subsections-addressing-CSV\nz-roads-subsections-addressing.vrt

%nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_sae"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %0"' > ..\linz_updates\LINZ_last.date

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file
if not defined nzogps_ogr2ogr call ..\..\setlocals.bat

net start %nzogps_psql_svc%
rem if you get error 5 on win8 doing net start - look here: https://thommck.wordpress.com/2011/12/02/how-to-allow-non-admins-to-start-and-stop-system-services/
grep -q  "EPSG:4167" "%nzogps_sae%" 
if errorlevel 1 echo Wrong projection  & pause & exit 1

time /t
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes "%nzogps_sae%" 
rem roads
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -nlt MULTILINESTRING "%nzogps_rcl%"
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc.sql
time /t
touch ../database.date
