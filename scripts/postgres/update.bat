setlocal
set psql=C:\Program Files\PostgreSQL\9.1\bin\
net start "postgresql-9.1 - PostgreSQL Server 9.1"
time /t
"%psql%shp2pgsql" -d -D -s4167 "..\..\LinzDataService\lds-nz-street-address-electoral-SHP\nz-street-address-elector.shp"  nz-street-address-elector > nz-street-address.sql
time /t
"%psql%psql" -U postgres -d nzopengps < nz-street-address.sql
time /t
"%psql%psql" -U postgres -d nzopengps < postproc.sql
time /t
touch ..\database.date
