@echo on
setlocal
if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file & goto :eof
call ..\..\setlocals.bat
net start %nzogps_psql_svc%
grep -q  "^GEOGCS\[\"GCS_NZGD_2000" "..\..\LinzDataService\lds-nz-street-address-electoral-SHP\nz-street-address-electoral.prj" 
if errorlevel 1 echo Wrong projection  & pause & exit 1
time /t
%nzogps_psql_bin%shp2pgsql -d -g the_geom -D -s4167 "..\..\LinzDataService\lds-nz-street-address-electoral-SHP\nz-street-address-electoral.shp"  nz-street-address-electoral > nz-street-address.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < nz-street-address.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc.sql
time /t
touch ../database.date
