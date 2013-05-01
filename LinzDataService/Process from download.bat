@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
call ..\setlocals.bat
@echo on
start tortoiseproc /command:update /path:".." /closeonend:1
@if not exist %nzogps_download%"lds-new-zealand-2layers-SHP.zip" echo new shapefile download not found. & goto :eof
move %nzogps_download%"lds-new-zealand-2layers-SHP.zip" .
%nzogps_unzip_cmd% lds-new-zealand-2layers-SHP -o lds-nz-street-address-electoral-SHP	*\nz-street-address-elector.*
%nzogps_unzip_cmd% lds-new-zealand-2layers-SHP -o lds-nz-road-centre-line-electoral-SHP	*\nz-road-centre-line-elect.*
%nzogps_perl_cmd% renzip.pl
:xx
cd ..\scripts\postgres
call update.bat
cd ..
start GenerateNumbers.bat
cd ..\linzdataservice
ruby shape-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
call numberlinz.bat
