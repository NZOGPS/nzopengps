SHELL = cmd.exe
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
OUTPUTS = outputs
PSQL = $(nzogps_psql_bin)
ZIPIT = $(nzogps_zip_cmd)
UNZIP = $(nzogps_unzip_cmd)
RUBY = $(nzogps_ruby_cmd)
PERL = $(nzogps_perl_cmd)

tilenum = $(subst Northland,1,$(subst Auckland,2,$(subst Waikato,3,$(subst Central,4,$(subst Wellington,5,$(subst Tasman,6,$(subst Canterbury,7,$(subst Southland,8,$(1)))))))))

all : $(addprefix $(OUTPUTS)/, $(addsuffix -WrongCities2.csv, $(TILES)))
.PHONY: all

$(OUTPUTS)/%-WrongCities2.csv : $(BASE)\%.mp $(LINZ)\lds-$(NZSL)-CSV\$(NZSL).csv
	process_tile.bat $*


