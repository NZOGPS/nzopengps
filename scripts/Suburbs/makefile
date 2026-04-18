ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
# BASE = $(subst \,/,$(nzogps_base))
DLOAD = $(subst ",,$(nzogps_download))
LINZ = $(BASE)\LinzDataService
LINZO = $(LINZ)\outputslinz
NZSL = nz-suburbs-and-localities
NUMBERS = $(BASE)\numbers
OUTPUTS = Outputs
SENTINELD = ..\DB_sentinels
PSQLC = $(nzogps_psql_bin)\psql -U postgres -d nzopengps
ZIPIT = $(nzogps_zip_cmd)
UNZIP = $(nzogps_unzip_cmd)
RUBY = $(nzogps_ruby_cmd)
PERL = $(nzogps_perl_cmd)
GREP = $(nzogps_grep_cmd)
OGR2OGR = $(nzogps_ogr2ogr)

ifdef nzogps_gdaldata
export GDAL_DATA = $(nzogps_gdaldata)
endif

ifdef nzogps_projdata
export PROJ_DATA = $(nzogps_projdata)
endif

tilenum = $(subst Northland,1,$(subst Auckland,2,$(subst Waikato,3,$(subst Central,4,$(subst Wellington,5,$(subst Tasman,6,$(subst Canterbury,7,$(subst Southland,8,$(1)))))))))

all : $(addprefix $(OUTPUTS)\, $(addsuffix -WrongCities2.csv, $(TILES)))
.PHONY: all

$(OUTPUTS)\\%-WrongCities2.csv : $(SENTINELD)/%-numberlines.sentinel $(SENTINELD)/sizecodes.sentinel $(LINZ)/$(NZSL).sentinel $(LINZ)/CityXlate/%_cidxlt.csv $(LINZ)/CityXlate/%_dont_cityindex.csv
	process_tile.bat numDBdone $*

$(SENTINELD)/sizecodes.sentinel : Code/CitySize.csv
	$(OGR2OGR) -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo AUTODETECT_TYPE=YES -lco OVERWRITE=yes $<
	echo sizecodes database updated %date% %time% sentinel > $@

Code/CitySize.csv : Code/CitySize.xlsx
	$(error CitySize.xlsx is newer than CitySize.csv - you need to manually update/export the csv )

$(SENTINELD)/%-numberlines.sentinel : $(BASE)/%.mp
	cd SQLData && $(PERL) ..\..\mp_2_n_sql2.pl -ci $(BASE)/$*.mp
	$(PSQLC) -f SQLData\$*_numberlines.sql
# for other checks
	$(PSQLC) -f SQLData\$*_cities.sql
	$(PSQLC) -f SQLData\$*_pois.sql
	echo %date% %time% > ..\DB_sentinels\$*-numberlines.sentinel

$(LINZ)\lds-$(NZSL)-CSV\$(NZSL).csv : $(DLOAD)\lds-$(NZSL)-CSV.zip
	if exist $(LINZ)\lds-$(NZSL)-CSV\* del /Q $(LINZ)\lds-$(NZSL)-CSV\*
	$(nzogps_unzip_cmd) $< -o$(LINZ)\lds-$(NZSL)-CSV
	GREP -q  "EPSG:4167" $(LINZ)\lds-$(NZSL)-CSV\$(NZSL).vrt
	cmd /C move $< $(LINZ)
	cd $(LINZ) &	$(PERL) renzip.pl $(notdir $<)

$(LINZ)\$(NZSL).sentinel : $(LINZ)\lds-$(NZSL)-CSV\$(NZSL).csv
	$(OGR2OGR) --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT $<
	$(PSQLC) -f Code\postproc.sql
	echo $(NZSL) database updated %date% %time% sentinel > $@

