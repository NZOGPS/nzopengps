@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
call ..\setlocals.bat
@echo on
start tortoiseproc /command:update /path:".." /closeonend:1
@if not exist %nzogps_download%"lds-new-zealand-2layers-SHP.zip" echo new shapefile download not found. & goto :eof
move %nzogps_download%"lds-new-zealand-2layers-SHP.zip" .
%nzogps_unzip_cmd% lds-new-zealand-2layers-SHP.zip -olds-nz-street-address-electoral-SHP *\nz-street-address-electoral-?.*
if %ERRORLEVEL% GTR 0 echo Street address files not found in zip file & goto :eof
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
