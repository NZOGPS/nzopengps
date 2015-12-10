if (%nzogps_unzip_cmd%)==() ..\setlocals.bat
forfiles /M *.zip /D 0 /c "cmd /c Unzip1Update.bat @file"