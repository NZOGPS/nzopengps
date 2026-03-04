@echo off
if not exist ..\..\setlocals.bat echo ..\..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\..\setlocals.bat
@echo on
set nzogps_ex_pt=nz-suburbs-and-localities
set nzogps_dl_fn=lds-%nzogps_ex_pt%-CSV.zip
set nzogps_NZSL=..\..\LinzDataService\lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv
if [%1]==[RELOAD] goto reload

pushd ..\..\LinzDataService
@if not exist %nzogps_download%\%nzogps_dl_fn% echo new suburbs download %nzogps_dl_fn% not found. & goto :myeof
move %nzogps_download%\%nzogps_dl_fn% .
del lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.*
%nzogps_unzip_cmd% %nzogps_dl_fn% -olds-%nzogps_ex_pt%-CSV %nzogps_ex_pt%.*
if not exist lds-%nzogps_ex_pt%-CSV\%nzogps_ex_pt%.csv echo suburb files not found in zip file %nzogps_dl_fn% & goto :myeof
%nzogps_perl_cmd% renzip.pl %nzogps_dl_fn%
for %%f in ("%nzogps_NZSL%") do (
	%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
	if errorlevel 1 echo Wrong projection  & goto :eof
)
popd

:reload
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT %nzogps_NZSL%
if errorlevel 0 %nzogps_psql_bin%psql -U postgres -d nzopengps < Code\postproc1.sql
pushd ..
%nzogps_ruby_cmd% slow_query_progress.rb -i id -t nz_suburbs_and_localities -q "SET nztm_geometry = st_buffer(st_transform(wkb_geometry,2193),20)" -l "Create NZTM poly"
popd
if errorlevel 0 %nzogps_psql_bin%psql -U postgres -d nzopengps < Code\postproc2.sql
if errorlevel 0 %nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_NZSL"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %~0"' > ..\linz_updates\LINZ_last_SAL.date
:myeof
