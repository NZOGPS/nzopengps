ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland

BASE = $(subst ",,$(nzogps_base))
OUTPUTS = Outputs

all : $(addprefix $(OUTPUTS)/, $(addsuffix -Wrongside-report.txt, $(TILES)))
.PHONY: all

$(OUTPUTS)/%-Wrongside-report.txt : $(BASE)/%.mp
	process_tile.bat $*

