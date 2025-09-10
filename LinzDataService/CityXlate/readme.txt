cidxlt means something like 'city id translate'
These files are used to translate between the nzogps city id, and the LINZ suburbs and localities (NZSL).
They are used by the code in scripts\suburbs. They are loaded from csv to a database by ogr2ogr.
The code primarily uses the name/name_ascii of the 'city' to match, then if there is no unique match, it tries finding a unique match matching both the name and the part of the name after the comma with the majorname in NZSL.
The code checks these files for inconsistencies, such as ids being incorrect/out of date.
We can use these files to assist that process of matching.
The column headings should mostly be self-evident.
'secondary' means that the entry is not an official NZSL name. It means we can create our own 'sub-suburbs'. I think these need to be fully enclosed by one official NZSL one.
'force' allows us to force an association, (i.e. the checkers will not complain about errors). USE SPARINGLY! I created this mainly to deal with the 'credits' pseudo-city, but it was also useful for Lion Rock in Piha, there are man Lion Rocks, and most have no majorname to disambiguate.

The _dont_cityindex files prevent warnings for not having a city city indexed (i.e having a city POI indexed to that city)
This is probably only useful at the tile borders, where a very small part of a city or locality is on one tile, and most of it is on another.
I'm guessing somewhat, but it would be confusing to users to choose a city and be navigated to an area on the outskirts that happens to be on another of our tiles.

The xlt_rsa_sal files are to help city indexing. Translate from nz_roads_subsections_addressing to nz_suburbs_and_localities
Gary got lazy and used the left_suburb_locality in nz_roads_subsections_addressing to do the addressing. 
Problem is - that isn't quite 1:1 with nz_suburbs_and_localities which our suburbs/cities are now tied to.
Mostly it's OK, but there are cases of different spellings and capitalisations that muck things up. Saint/St./St is common.
Adding translations in here improves the rate of getting addressed.
