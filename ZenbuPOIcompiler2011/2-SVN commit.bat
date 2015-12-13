if (%nzogps_base%)==() call setlocals.bat
%nzogps_git% commit -m "POI Update" -uno ..\NZPOIs*.mp
pause
%nzogps_git% push
pause