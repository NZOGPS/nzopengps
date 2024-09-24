@echo off
if not exist %nzogps_gmapsupp_loc% echo %nzogps_gmapsupp_loc% does not exist &goto :eof
for /f "delims=_ tokens=1" %%d in ( 'dir /b /od *.exe') do set NZOGPS_LatestCompile=%%d
%nzogps_zip_cmd% %NZOGPS_LatestCompile%_Free_Open_GPS_NZ_Autorouting.gmapi.zip "%nzogps_gmapsupp_loc%\Free Open GPS NZ Autorouting.gmapi\Free Open GPS NZ Autorouting.gmap"