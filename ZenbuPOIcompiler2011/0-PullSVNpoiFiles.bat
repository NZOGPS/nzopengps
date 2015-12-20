if not defined nzogps_git call ..\setlocals.bat
%nzogps_git% pull
%nzogps_curl% -u %nzogps_zenbu_user% -o zenbuNZ.csv.bz2 http://www.zenbu.co.nz/export/all
%nzogps_bunzip% --force zenbuNZ.csv.bz2
pause
