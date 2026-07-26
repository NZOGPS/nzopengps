if not defined nzogps_git call ..\setlocals.bat
%nzogps_git% pull
rem %nzogps_curl% -u %nzogps_zenbu_user% -o zenbuNZ.csv.bz2 https://www.zenbu.co.nz/export/all
%nzogps_curl% -b %nzogps_zenbu_sessid% -o zenbuNZ.csv.bz2 https://www.zenbu.co.nz/export/all
if %nzogps_bunzip% --force zenbuNZ.csv.bz2
pause
