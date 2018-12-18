@echo off
for /f "delims=_ tokens=1" %%d in ( 'dir /b /od *.exe') do set nzogps_latest_compile=%%d
7z a %nzogps_latest_compile%_Free_Uppercase_Mac_Open_GPS_NZ_Autorouting.gmapi.zip "d:\garmin\Free Open GPS NZ Autorouting.gmapi"