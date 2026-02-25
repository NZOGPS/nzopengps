SHELL = C:\WINDOWS\system32\cmd.exe
ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

BASE = $(subst ",,$(nzogps_base))
LINZ = $(BASE)\LinzDataService
PAPERRDS = $(LINZ)\PaperRoads

.SUFFIXES:
.SECONDARY:
TILES = Northland Southland Tasman Waikato Central Wellington Canterbury Auckland
 
all : $(addsuffix _num_err.txt,$(TILES))
.PHONY: all

pilot : $(addsuffix _num_err_p.txt,$(TILES))
.PHONY: pilot

%_num_err.txt : ..\%.mp ..\numbers\%-numbers-linzid.csv $(PAPERRDS)\%.txt
	$(nzogps_perl_cmd) ../scripts/check_mp.pl "$<" > $@

%_num_err_p.txt : ..\%.mp $(LINZ)\outputs\%-numbers-linzid.csv $(PAPERRDS)\%.txt
	$(nzogps_perl_cmd) ../scripts/check_mp.pl -P "$<" > $@
