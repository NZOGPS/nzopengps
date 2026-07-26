@echo off
if not defined nzogps_git call ..\setlocals.bat
%nzogps_git% pull
rem %nzogps_curl% -L -u %nzogps_zenbu_user% -o zenbuNZ.csv.bz2 https://www.zenbu.co.nz/export/all
%nzogps_curl% -b %nzogps_zenbu_sessid% -o zenbuNZ.csv.bz2 https://www.zenbu.co.nz/export/all
echo %errorlevel%
if errorlevel 1 exit /b
%nzogps_bunzip% --force zenbuNZ.csv.bz2
if errorlevel 1 exit /b
if not defined nzogps_ruby_cmd call ..\setlocals.bat
%nzogps_ruby_cmd% process.rb
%nzogps_git% commit -m "POI Update" -uno ..\NZPOIs*.mp
%nzogps_git% push
%nzogps_ruby_cmd% rebuild_category_files.rb
%nzogps_git% commit -m "Zenbu Category Update" -uno ..\ZenbuPOIcategories2011\*.txt
%nzogps_git% push
