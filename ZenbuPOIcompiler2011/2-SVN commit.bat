cd ..
rem svn st
if (%nzogps_base%)==() call setlocals.bat
%nzogps_git% commit -m "POI Update" -uno NZPOIs*.mp
pause
rem svn commit -m "POI Update"
%nzogps_git% push
pause