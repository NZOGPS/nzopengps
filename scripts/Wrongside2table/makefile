ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

PSQLC=$(nzogps_psql_bin)psql -U postgres -d nzopengps
PERL=$(nzogps_perl_cmd)
BASE = $(subst ",,$(nzogps_base))
OUTPUTD = Outputs/
REPORTD = $(OUTPUTD)Reports/
NUM_SENTINELD = ../DB_sentinels
PAPERDIR = $(BASE)/LinzDataService/PaperRoads/
POSTPROLINES = $(nzogps_wsppl)

all : $(addprefix $(REPORTD), $(addsuffix -Wrongside-report.txt, $(TILES))) $(addprefix $(OUTPUTD), $(addsuffix -Sparsest.csv, $(TILES)))
.PHONY: all

$(NUM_SENTINELD)/%-nums.sentinel : ../linz_updates/LINZ_last.date
$(PSQLC) -c "drop table if exists $*_nums; Create table $*_Nums as select * from nz_addresses join _boundb on st_contains(poly,wkb_geometry) and name='$*'

#	Update_nums.bat $*
	echo %date% %time% > $@

$(NUM_SENTINELD)/%-numberlines.sentinel : $(BASE)/%.mp
	cd TempData && $(PERL) ..\..\mp_2_n_sql2.pl -ci $(BASE)/$*.mp
	$(PSQLC) -f TempData\$*_numberlines.sql
	$(PSQLC) -f TempData\$*_cities.sql
	$(PSQLC) -f TempData\$*_pois.sql
	echo %date% %time% > ..\DB_sentinels\$*-numberlines.sentinel
	%$(PSQLC) -t -v linestable=$*_numberlines -v wrongstable=$*_wrongside -v distance=100 -f Code\$(POSTPROLINES)

$(OUTPUTD)/%-Wrongside.csv : ../DB_sentinels/%-numberlines.sentinel $(NUM_SENTINELD)/%-nums.sentinel
	$(PSQLC) -t -v linestable=$*_numberlines -v wrongstable=$*_wrongside -v numstable=$*_nums -v outfile='$(CURDIR)\Outputs\$*-WrongSide.csv' -f Code\intersect.sql

$(OUTPUTD)/%-Sparsest.csv : ../DB_sentinels/%-numberlines.sentinel $(NUM_SENTINELD)/%-nums.sentinel
	$(PSQLC) -v linestable=$*_numberlines -v wrongstable=$*_wrongside  \-v distance=350 -v outfile='$(CURDIR)\Outputs\$*-Sparsest.csv' -f Code\Sparsest.sql

$(REPORTD)%-Wrongside-report.txt : $(OUTPUTD)/%-Wrongside.csv
	cd $(OUTPUTD) && $(PERL) ..\Code\wrongsidereport.pl $* > Reports\$*-Wrongside-report.txt


