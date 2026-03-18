ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
OUTPUTD = Outputs
REPORTD = $(OUTPUTD)/Reports/
NUM_SENTINELD = ../DB_sentinels

all : $(addprefix $(REPORTD), $(addsuffix -Wrongside-report.txt, $(TILES)))
.PHONY: all

$(NUM_SENTINELD)/%-nums.sentinel : ../linz_updates/LINZ_last.date
	Update_nums.bat $*
	echo %date% %time% > $@
	
$(NUM_SENTINELD)/%-numberlines.sentinel : $(BASE)/%.mp
	cd TempData && $(PERL) ..\..\mp_2_n_sql2.pl -ci $(BASE)/$*.mp
	$(PSQLC) -f TempData\$*_numberlines.sql
	# for other checks
	$(PSQLC) -f TempData\$*_cities.sql
	$(PSQLC) -f TempData\$*_pois.sql
	echo %date% %time% > ..\DB_sentinels\$*-numberlines.sentinel

$(REPORTD)%-Wrongside-report.txt : ../DB_sentinels/%-numberlines.sentinel $(NUM_SENTINELD)/%-nums.sentinel
	Redo_tile.bat numDBdone $*

