if  defined %nzogps_unzip_cmd% goto itsset
call ..\setlocals.bat
:itsset
forfiles /M *.zip /D 0 /c "cmd /c Unzip1Update.bat @file"