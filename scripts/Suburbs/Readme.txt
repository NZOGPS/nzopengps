LINZ has taken over the FENZ suburbs database:
https://data.linz.govt.nz/layer/113764-nz-suburbs-and-localities/
To use to to compare to our maps:
	Download from above. Export to csv, EPSG 4167, no crop
	import to postgres table with ogr2ogr

Convert maps to sql with mp_2_n_sql -c
Import city sql
	%nzogps_psql_bin%psql -U postgres -d nzopengps -f southland_cities.sql
Import numberline sql
	%nzogps_psql_bin%psql -U postgres -d nzopengps -f Southland_numberlines.sql
Read nzsl ID into cities
	Use match on just names where only one match
	Use match on names and city name (")
	Use table for odd ones?
Generate convex hull of roads with given city in cities (interest only?)
Canterbury - started with 6581 incorrect.
20230806 2512
20230807 1593 BUT - only goes up to L? Encoding?

Sort-of working. 
Wasn't intending to do down to road segments but it's working out that way.
TO DO:
Add code/table to do Different spelling (e.g. English/Maori) and duplicates.
Encoding error?