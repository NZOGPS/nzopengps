@echo on
setlocal
set nzogps_sae=..\..\LinzDataService\lds-nz-street-address-electoral-SHP
set nzogps_2xsae=

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file & goto :eof
call ..\..\setlocals.bat
net start %nzogps_psql_svc%
rem if you get error 5 on win8 doing net start - look here: https://thommck.wordpress.com/2011/12/02/how-to-allow-non-admins-to-start-and-stop-system-services/
if exist "%nzogps_sae%\nz-street-address-electoral-2.prj" set nzogps_2xsae=-2
grep -q  "^GEOGCS\[\"GCS_NZGD_2000" "%nzogps_sae%\nz-street-address-electoral%nzogps_2xsae%.prj" 
if errorlevel 1 echo Wrong projection  & pause & exit 1
if exist "%nzogps_sae%\nz-street-address-electoral-4.shp" echo 4th shapefile found & pause & exit 1
del nz-street-address*.sql
time /t
%nzogps_psql_bin%shp2pgsql -d -g the_geom -D -s4167 "%nzogps_sae%\nz-street-address-electoral%nzogps_2xsae%.shp"  nz-street-address-electoral > nz-street-address-1.sql
if not "%nzogps_2xsae%"=="" %nzogps_psql_bin%shp2pgsql -a -g the_geom -D -s4167 "%nzogps_sae%\nz-street-address-electoral-3.shp"  nz-street-address-electoral > nz-street-address-2.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < nz-street-address-1.sql
if not "%nzogps_2xsae%"=="" %nzogps_psql_bin%psql -U postgres -d nzopengps < nz-street-address-2.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc.sql
time /t
touch ../database.date
