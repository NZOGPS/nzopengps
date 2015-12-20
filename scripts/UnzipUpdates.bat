if not defined nzogps_unzip_cmd call ..\setlocals.bat

forfiles /M *.zip /D 0 /c "cmd /c Unzip1Update.bat @file"