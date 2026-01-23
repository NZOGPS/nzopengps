@echo off
if not exist ..\..\setlocals.bat echo ..\..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\..\setlocals.bat
@echo on
set nzogps_here=%CD%
cd ..\..\LinzDataService
set nzogps_ex_pt=nz-suburbs-and-localities
set nzogps_dl_fn=lds-%nzogps_ex_pt%-CSV.zip
@if not exist %nzogps_download%\%nzogps_dl_fn% echo new suburbs download %nzogps_dl_fn% not found. & goto :myeof
move %nzogps_download%\%nzogps_dl_fn% .
del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%.*
if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo suburb files not found in zip file %nzogps_dl_fn% & goto :myeof
%nzogps_perl_cmd% renzip.pl %nzogps_dl_fn%
:myeof
cd %nzogps_here%
set nzogps_NZSL=..\..\LinzDataService\lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv
for %%f in ("%nzogps_NZSL%") do (
	%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
	if errorlevel 1 echo Wrong projection  & goto :eof
)
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT %nzogps_NZSL%
%nzogps_psql_bin%psql -U postgres -d nzopengps < Code\postproc.sql