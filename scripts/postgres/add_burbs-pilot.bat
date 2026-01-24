@echo off
setlocal

set nzogps_nzsl=nz_suburbs_and_localities
set nzogps_nzta=regional_council

%nzogps_psqlc% -c "SELECT count(*) as %nzogps_nzsl% from %nzogps_nzsl%"
if errorlevel 1 echo Error - %nzogps_nzsl% table not found. & pause & exit /b 1

%nzogps_psqlc% -c "SELECT count(*) as %nzogps_nzta% from %nzogps_nzta%"
if errorlevel 1 echo Error - %nzogps_nzta% table not found. & pause & exit /b 1

%nzogps_psqlc% -v NZSL_TBL=%nzogps_nzsl% -f add_burbs-pilot.sql