ifndef nzogps_base
$(error nzogps_base environment variable not set - run setlocals first)
endif

CGPS = $(nzogps_cgps)
CPV = $(nzogps_cprv)
ISCC = $(nzogps_iscc)
MPPATH = $(subst $\",,$(nzogps_base))

# $(info mppath is $(MPPATH))
.SUFFIXES:

MPIMGS = 64000013.img 64000014.img 64000015.img 64000016.img 64000017.img 64000018.img 64000019.img 64000020.img
POIIMGS = 64000012.img 64000021.img

SETUP = $(wildcard *FREE_Uppercase_OpenGPS_NZ*)

$(SETUP) : Free\ Open\ GPS\ NZ\ Autorouting.img
	$(ISCC) /dSdir=. /dBdir=$(nzogps_base) /dWImg=..\$(nzogps_inst_image) "NZ OpenGPS Setup.iss"

Free\ Open\ GPS\ NZ\ Autorouting.img : Free\ Open\ GPS\ NZ\ Autorouting.mp
	%nzogps_perl_cmd% ../RemoveCodepage.pl "Free Open GPS NZ Autorouting.mp"
	$(CGPS) "$<"

Free\ Open\ GPS\ NZ\ Autorouting.mp : $(MPIMGS) $(POIIMGS) NZO5_pv_template.txt
	cscript /nologo ..\DateScript.vbs /u > NZO5_pv.txt
	$(CPV) NZO5_pv.txt

define compile
$(CGPS) ac -l $(notdir $<) > $(notdir $(basename $<))compileLog.txt
endef

64000013.img : $(MPPATH)\Northland.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 1 8
	$(compile)

64000014.img : $(MPPATH)\Auckland.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 2 8
	$(compile)

64000015.img : $(MPPATH)\Wellington.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 5 8
	$(compile)

64000016.img : $(MPPATH)\Tasman.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 6 8
	$(compile)

64000017.img : $(MPPATH)\Canterbury.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 7 8
	$(compile)

64000018.img : $(MPPATH)\Southland.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 8 8
	$(compile)

64000019.img : $(MPPATH)\Central.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 4 8
	$(compile)

64000020.img : $(MPPATH)\Waikato.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 3 8
	$(compile)

64000012.img : $(MPPATH)\NZPOIs3A.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 12 8
	$(compile)

64000021.img : $(MPPATH)\NZPOIs3B.mp
	cd ..\..\scripts & $(nzogps_ruby_cmd) parseMP.rb 21 8
	$(compile)
