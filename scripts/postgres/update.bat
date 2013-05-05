setlocal
net start %nzogps_psql_svc%
time /t
%nzogps_psql_bin%shp2pgsql -d -g the_geom -D -s4167 "..\..\LinzDataService\lds-nz-street-address-electoral-SHP\nz-street-address-elector.shp"  nz-street-address-elector > nz-street-address.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < nz-street-address.sql
time /t
%nzogps_psql_bin%psql -U postgres -d nzopengps < postproc.sql
time /t
touch ..\database.date
