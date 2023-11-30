LINZ has taken over the FENZ suburbs database:
https://data.linz.govt.nz/layer/113764-nz-suburbs-and-localities/

To use to to compare to our maps:
	Download from above. Export to csv, EPSG 4167, no crop

process from download.bat
	unzips zip file. Stored in linzdataservice
	checks for correct datum
	imports to postgres table with ogr2ogr
	adds 'watery' to table - lakes/bays, so not to index

Per-tile processing:
	process_tile.bat tilename
		Converts map to sql with mp_2_n_sql -c
		Import city sql
			%nzogps_psql_bin%psql -U postgres -d nzopengps -f tilename_cities.sql
		Import numberline sql
			%nzogps_psql_bin%psql -U postgres -d nzopengps -f tilename_numberlines.sql
		Read nzsl ID into cities
			Use match on just names where only one match
			Use match on names and city name (")
			Use table for odd ones
		Generate convex hull of roads with given city in cities (interest only?)
		Generate reports of:
			unmatched cities
			unused cities
				CARE: not all lines are actually imported, so may not be reported
			roads that are not within the area of the matching LINZ city / suburb

Manual work:
	Check unmatched cities file:
		Helpful to add csv file to map to see where they are;
		Unlink/move roads from improper suburbs
			Looks like original assignment accidentally often linked to 'watery' ones that should just be the physical area beside it.
		Correct spelling mistakes / name changes.
		Add entries as needed to exception table ..\..\]linzdataservice\CityXlate\tilename_cidxlt.csv
			To distinguish same name in two different areas.
			create an exception for ones we want to add, e.g. Wigram Skies in Canterbury
	Care with deleting unneeded suburbs from mp file as that will renumber everything and screw up the xlate file (not that bad?).
	Check tilename_-WrongCities100k.csv. A likely scenario for entries in this file is an incorrect automatic name assignment.
	
Canterbury - started with 6581 incorrect.
20230806 2512
20230807 1593 BUT - only goes up to L? Encoding? YES Desc goes down to T
21:45 08/08/23 Fixed. Changed name to name_ascii. Was failing on macrons. Now 4790

Notes:
	Sort-of working. 
	Wasn't intending to do down to road segments but it's working out that way.
	interesting to see there's a bit of variation. Roads appear as needing correction after 2-3 checks. Maybe that was related to macrons failing?
TO DO:
	Add code/table to do Different spelling (e.g. English/Maori) and duplicates. Done.
	Encoding error? - done.
	Add buffer to intersects? Done.
	Move code / sql data / outputs to subdirectories Done.
	Add order in suggested cities Done. Wrong2.
	wrong3 by distance - index? SLOW!!!
		Without index: 540s With 25s
	or pre-transform roads to nztm?
	Pre-index roads in new linz imports. Done.
