@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v

@if not exist %nzogps_download%\"lds-new-zealand-2layers-CSV.zip" echo new CSV download not found. & goto :eof
move %nzogps_download%\"lds-new-zealand-2layers-CSV.zip" .

del lds-nz-roads-subsections-addressing-CSV\nz-roads*.*
%nzogps_unzip_cmd% lds-new-zealand-2layers-CSV.zip -olds-nz-roads-subsections-addressing-CSV *\nz-roads-subsections-addressing*.*
if %ERRORLEVEL% GTR 0 echo Road centre line  files not found in zip file & goto :eof

rem change from nz-street-address to nz-addresses
rem del lds-nz-street-address-CSV\nz-roads-addressing*.*
rem %nzogps_unzip_cmd% lds-new-zealand-2layers-CSV.zip -olds-nz-street-address-CSV nz-street-address\nz-street-address.*
rem if %ERRORLEVEL% GTR 0 echo Street address files not found in zip file & goto :eof

%nzogps_unzip_cmd% lds-new-zealand-2layers-CSV.zip -olds-nz-addresses-CSV nz-addresses\nz-addresses.*
if %ERRORLEVEL% GTR 0 echo Street address files not found in zip file & goto :eof

rem only partly done??? Also need AIMS:Address Reference...

%nzogps_perl_cmd% renzip.pl
:xx
cd ..\scripts\postgres
call update.bat
cd ..
start Generatenumbers
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
if errorlevel 1 goto :eof
call numberlinz.bat
