@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
rem start tortoiseproc /command:update /path:".." /closeonend:1
%nzogps_git% pull -v
@if not exist %nzogps_download%"lds-new-zealand-2layers-SHP.zip" echo new shapefile download not found. & goto :eof
move %nzogps_download%"lds-new-zealand-2layers-SHP.zip" .
del lds-nz-street-address-electoral-SHP\nz*.*
%nzogps_unzip_cmd% lds-new-zealand-2layers-SHP.zip -olds-nz-street-address-electoral-SHP *\nz-street-address-electoral*.*
if %ERRORLEVEL% GTR 0 echo Street address files not found in zip file & goto :eof
del lds-nz-road-centre-line-electoral-SHP\nz*.*
%nzogps_unzip_cmd% lds-new-zealand-2layers-SHP.zip -olds-nz-road-centre-line-electoral-SHP *\nz-road-centre-line-electoral.*
if %ERRORLEVEL% GTR 0 echo Road centre line  files not found in zip file & goto :eof
%nzogps_perl_cmd% renzip.pl
:xx
cd ..\scripts\postgres
call update.bat
cd ..
start %nzogps_donumbers%
cd ..\linzdataservice
ruby shape-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
call numberlinz.bat
