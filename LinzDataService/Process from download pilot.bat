@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v

set nzogps_dl_fn=lds-new-zealand-2layers-CSV.zip
@if not exist %nzogps_download%\%nzogps_dl_fn% echo new CSV download %nzogps_dl_fn% not found. & goto :eof
move %nzogps_download%\%nzogps_dl_fn% .

set nzogps_ex_pt=nz-addresses-roads-pilot
if exist %nzogps_ex_pt%\%nzogps_ex_pt%.*  del %nzogps_ex_pt%\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -o%nzogps_ex_pt% %nzogps_ex_pt%\%nzogps_ex_pt%.*
if not exist %nzogps_ex_pt%\%nzogps_ex_pt%.csv echo Road centre line  files not found in zip file %nzogps_dl_fn% & goto :eof

set nzogps_ex_pt=nz-addresses-pilot
if exist %nzogps_ex_pt%\%nzogps_ex_pt%.*  del %nzogps_ex_pt%\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -o%nzogps_ex_pt% %nzogps_ex_pt%\%nzogps_ex_pt%.*
if not exist %nzogps_ex_pt%\%nzogps_ex_pt%.csv echo Address files not found in zip file %nzogps_dl_fn% & goto :eof

%nzogps_perl_cmd% renzip.pl

:xx
cd ..\scripts\postgres
call update-pilot.bat
if errorlevel 1 goto :eof
cd ..
start %nzogps_donumbers%-pilot
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser-pilot.rb
cd ..\scripts
call dochecks-pilot.bat
call colouriseall-pilot.bat
if errorlevel 1 goto :eof
call %nzogps_linznumb%-pilot
