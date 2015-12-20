if not defined nzogps_git call ..\setlocals.bat
%nzogps_git% commit -m "POI Update" -uno ..\NZPOIs*.mp
pause
%nzogps_git% push
pause