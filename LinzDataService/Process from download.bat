@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v

set nzogps_dl_fn=lds-new-zealand-2layers-CSV.zip
@if not exist %nzogps_download%\%nzogps_dl_fn% echo new CSV download %nzogps_dl_fn% not found. & goto :eof
move %nzogps_download%\%nzogps_dl_fn% .

set nzogps_ex_pt=nz-roads-subsections-addressing
del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%\%nzogps_ex_pt%.*
if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo Road centre line  files not found in zip file %nzogps_dl_fn% & goto :eof

set nzogps_ex_pt=nz-addresses
del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%\%nzogps_ex_pt%.*
if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo Address files not found in zip file %nzogps_dl_fn% & goto :eof
%nzogps_perl_cmd% renzip.pl

set nzogps_dl_fn=lds-aims-address-reference-CSV.zip
@if not exist %nzogps_download%\%nzogps_dl_fn% echo new CSV download %nzogps_dl_fn% not found. & goto :eof
move %nzogps_download%\%nzogps_dl_fn% .
rem no nz in dir name
rem no subdir in single file output-old
set nzogps_ex_pt=AIMS-address-reference
del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%.*
if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo Address reference files not found in zip file %nzogps_dl_fn% & goto :eof
%nzogps_perl_cmd% renzip.pl

rem change from nz-street-address to nz-addresses - temp add 'deprecated' to fn
rem set nzogps_ex_pt=nz-street-address
rem del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
rem %nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%-deprecated\%nzogps_ex_pt%-deprecated.*
rem if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%-deprecated.csv echo old address files not found in zip file %nzogps_dl_fn% & goto :eof
rem fix filenames
rem ren lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%-deprecated.* %nzogps_ex_pt%.*
rem change reference to deprecated in vrt file - untested 
rem %nzogps_perl_cmd% -i.bak -pe "s/-deprecated//" lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.vrt

:xx
cd ..\scripts\postgres
call update.bat
cd ..
start %nzogps_donumbers%
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
if errorlevel 1 goto :eof
call numberlinz.bat
