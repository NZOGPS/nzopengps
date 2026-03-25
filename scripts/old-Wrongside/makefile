ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
OUTPUTD = Outputs
REPORTD = $(OUTPUTD)/Reports/
TMPDIR = TempData

all : $(addprefix $(REPORTD), $(addsuffix -Wrongside-report.txt, $(TILES)))
.PHONY: all

$(TMPDIR)/%-nums.sentinel : ../linz_updates/LINZ_last.date
	Update_nums.bat $*
	echo %date% %time% > $@

$(REPORTD)%-Wrongside-report.txt : $(BASE)/%.mp $(TMPDIR)/%-nums.sentinel
	Redo_tile.bat $*

