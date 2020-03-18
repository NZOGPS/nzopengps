ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland
 
all : $(addsuffix _num_err.txt,$(TILES))
.PHONY: all

%_num_err.txt : ..\%.mp
	$(nzogps_perl_cmd) ../scripts/check_mp.pl "$<" > $@

