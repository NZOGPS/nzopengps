ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
DLOAD = $(subst ",,$(nzogps_download))
LINZ = $(BASE)\LinzDataService
LINZO = $(LINZ)\outputslinz
NZSL = nz-suburbs-and-localities
NUMBERS = $(BASE)\numbers
OUTPUTS = Outputs
PSQL = $(nzogps_psql_bin)\psql
ZIPIT = $(nzogps_zip_cmd)
UNZIP = $(nzogps_unzip_cmd)
RUBY = $(nzogps_ruby_cmd)
PERL = $(nzogps_perl_cmd)
OGR2OGR = $(nzogps_ogr2ogr)

tilenum = $(subst Northland,1,$(subst Auckland,2,$(subst Waikato,3,$(subst Central,4,$(subst Wellington,5,$(subst Tasman,6,$(subst Canterbury,7,$(subst Southland,8,$(1)))))))))

all : $(addprefix $(OUTPUTS)/, $(addsuffix -WrongCities2.csv, $(TILES)))
.PHONY: all

$(OUTPUTS)/%-WrongCities2.csv : $(BASE)/%.mp $(LINZ)/$(NZSL).sentinel $(LINZ)\CityXlate\%_cidxlt.csv $(LINZ)\CityXlate\%_dont_cityindex.csv
	process_tile.bat $*

$(LINZ)\lds-$(NZSL)-CSV\$(NZSL).csv : $(DLOAD)\lds-$(NZSL)-CSV.zip
	if exist $(LINZ)\lds-$(NZSL)-CSV\* del /Q $(LINZ)\lds-$(NZSL)-CSV\*
	$(nzogps_unzip_cmd) $< -o$(LINZ)\lds-$(NZSL)-CSV
	grep -q  "EPSG:4167" $(LINZ)\lds-$(NZSL)-CSV\$(NZSL).vrt
	mv $< $(LINZ)\*

$(LINZ)\$(NZSL).sentinel : $(LINZ)\lds-$(NZSL)-CSV\$(NZSL).csv
	$(OGR2OGR) --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT $<
	$(PSQL) -U postgres -d nzopengps < Code\postproc.sql
	echo database updated %date% sentinel > $@

