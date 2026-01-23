@echo off
rem get it from https://datafinder.stats.govt.nz/data/category/annual-boundaries/
if not exist ..\..\setlocals.bat echo ..\..\setlocals.bat not found. You need to copy and customise the setlocals sample file & goto :eof
if not defined nzogps_base call ..\..\setlocals.bat
@echo on
setlocal
set nzogps_rctbl=regional-council
set nzogps_rcutbl=regional_council
set nzogps_here=%CD%
set nzogps_dlyr=2026
set PROJ_LIB=

cd ..\..\LinzDataService
set nzogps_ex_pt=%nzogps_rctbl%-%nzogps_dlyr%
set nzogps_dl_fn=statsnz-%nzogps_ex_pt%-CSV.zip
@if not exist %nzogps_download%\%nzogps_dl_fn% echo regions download %nzogps_dl_fn% not found. & cd %nzogps_here% & goto :eof
move %nzogps_download%\%nzogps_dl_fn% .
if exist statsnz-%nzogps_ex_pt%-CSV del statsnz-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -ostatsnz-%nzogps_ex_pt%-CSV %nzogps_ex_pt%*.*
if not exist statsnz-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo suburb files not found in zip file %nzogps_dl_fn% & goto :myeof
%nzogps_perl_cmd% renzip.pl %nzogps_dl_fn%
:myeof
cd %nzogps_here%
set nzogps_NZRC=..\..\LinzDataService\statsnz-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv
for %%f in ("%nzogps_NZRC%") do (
	%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
	if errorlevel 1 echo Wrong projection  & goto :eof
)
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -nln %nzogps_rctbl% -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT %nzogps_NZRC%

%nzogps_psql_bin%psql -U postgres -d nzopengps -c "alter table %nzogps_rcutbl% rename column REGC%nzogps_dlyr%_V1_00 to REGC_00"
%nzogps_psql_bin%psql -U postgres -d nzopengps -c "alter table %nzogps_rcutbl% rename column REGC%nzogps_dlyr%_V1_00_NAME to REGC_NAME"
%nzogps_psql_bin%psql -U postgres -d nzopengps -c "alter table %nzogps_rcutbl% rename column REGC%nzogps_dlyr%_V1_00_NAME_ASCII to REGC_NAME_ASCII"

set nzogps_NZRC=..\..\LinzDataService\Regions\nzogps_regions.csv
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes %nzogps_NZRC%

%nzogps_psql_bin%psql -U postgres -d nzopengps -f ..\..\LinzDataService\Regions\nzogps_regions.sql