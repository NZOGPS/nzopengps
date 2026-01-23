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
NUMBERS = $(BASE)\numbers
OUTPUTS = $(BASE)\scripts\outputs
PAPERRDS = $(LINZ)\PaperRoads
PSQL = $(nzogps_psql_bin)
ZIPIT = $(nzogps_zip_cmd)
UNZIP = $(nzogps_unzip_cmd)
RUBY = $(nzogps_ruby_cmd)
PERL = $(nzogps_perl_cmd)
TOUCH = $(nzogps_touch_cmd)

tilenum = $(subst Northland,1,$(subst Auckland,2,$(subst Waikato,3,$(subst Central,4,$(subst Wellington,5,$(subst Tasman,6,$(subst Canterbury,7,$(subst Southland,8,$(1)))))))))
 
all : $(addsuffix .zip,$(TILES))
.PHONY: all

install-csv : $(addsuffix -numbers-linzid.csv,$(addprefix $(NUMBERS)\,$(TILES)))
.PHONY: install

install-gdb : $(addsuffix -numbers.gdb,$(addprefix $(NUMBERS)\,$(TILES)))
.PHONY: install

install :  install-csv install-gdb
.PHONY: install


%.zip : $(LINZO)\%-LINZ-V5.mp $(LINZO)\%-LINZ-V4.mp $(OUTPUTS)\%-report-2.txt $(OUTPUTS)\%-report-6.txt $(OUTPUTS)\%-numbers-linzid.csv $(OUTPUTS)\%-numbers.gdb 
	$(ZIPIT) $@ $?

%-LINZ-V3.mp : %-LINZ.mp $(OUTPUTS)\%-report-2.txt
	$(PERL) colourisenodise.pl $(notdir $*)

%-LINZ-V4.mp : $(LINZO)\%-LINZ-V3.mp database.date
	$(RUBY) parseLinzMP.rb $(call tilenum, $(notdir $*)) 3

%-LINZ-V5.mp : %-LINZ-V4.mp
	$(PERL) -ne "print unless /;linz_/" $? >$@

%-LINZ.mp : $(LINZ)\lds-nz-road-centre-line-electoral-SHP\nz-road-centre-line-electoral.shp
	cd $(LINZ) && $(RUBY) shape-parser.rb

postgres\nz-street-address.sql : $(LINZ)\lds-nz-street-address-electoral-SHP\nz-street-address-electoral.shp
	time /t
	$(PSQL)shp2pgsql -d -D -s4167 $<  nz-street-address-elector > postgres\nz-street-address.sql
	time /t

database.date : postgres\nz-street-address.sql
	time /t
	$(PSQL)psql -U postgres -d nzopengps < postgres\nz-street-address.sql
	time /t
	$(PSQL)psql -U postgres -d nzopengps < postgres\postproc.sql
	TOUCH database.date
	time /t

$(LINZ)\lds-nz-road-centre-line-electoral-SHP\nz-road-centre-line-electoral.shp : $(DLOAD)\lds-nz-road-centre-line-electoral-SHP.zip 
	$(UNZIP) -o $< $(dir $@)
	move $(DLOAD)\lds-nz-road-centre-line-electoral-SHP.zip $(LINZ)
	$(PERL) $(LINZ)\renzip.pl $(LINZ)\lds-nz-road-centre-line-electoral-SHP

$(LINZ)\lds-nz-street-address-electoral-SHP\nz-street-address-electoral.shp : $(DLOAD)\lds-nz-street-address-electoral-SHP.zip
	$(UNZIP) -o $< $(dir $@)
	move $(DLOAD)\lds-nz-street-address-electoral-SHP.zip $(LINZ)
	$(PERL) $(LINZ)\renzip.pl $(LINZ)\lds-nz-street-address-electoral-SHP

$(OUTPUTS)\\%-report-2.txt : ..\%.mp $(PAPERRDS)\%.txt
	$(RUBY) parseMP.rb $(call tilenum, $(notdir $*)) 2
	
$(OUTPUTS)\\%-report-6.txt : ..\%.mp $(LINZO)\%-LINZ.mp
	$(RUBY) parseMP.rb $(call tilenum, $(notdir $*)) 6

$(NUMBERS)\\%-numbers.gdb : $(OUTPUTS)\%-numbers.gdb
	if exist $(subst /,\,$@) move /Y $(subst /,\,$@) $(addsuffix .old,$(subst /,\,$@))
	copy  $(subst /,\,$<)  $(subst /,\,$@)

$(NUMBERS)\\%-numbers.gdb : %.zip
	$(UNZIP) -o$(NUMBERS) $< $(notdir $@)

$(NUMBERS)\\%-numbers-linzid.csv : $(OUTPUTS)\%-numbers-linzid.csv
	if exist $(subst /,\,$@)  move /Y $(subst /,\,$@) $(addsuffix .old,$(subst /,\,$@))
	copy  $(subst /,\,$<)  $(subst /,\,$@)
	
$(NUMBERS)\\%-numbers-linzid.csv : %.zip
	$(UNZIP) -o$(NUMBERS) $< $(notdir $@)
	
$(OUTPUTS)\\%-numbers.gdb : database.date
	$(RUBY) parseMP.rb $(call tilenum, $(notdir $*)) 5

$(OUTPUTS)\\%-numbers-linzid.csv :database.date
	$(RUBY) parseMP.rb $(call tilenum, $(notdir $*)) 4
