@echo on
setlocal
set nzogps_nzsl=nz_suburbs_and_localities
set nzogps__taa=territorial_authority_ascii
set nzogps__sla=suburb_locality_ascii
set nzogps_nzta=regional_council
set nzogps_nzad=nz_addresses
set nzogps_nzrd=nz_addresses_roads
set nzogps_nzrd_s=%nzogps_nzrd%_s
set nzogps_nzadf=..\..\LinzDataService\%nzogps_nzad:_=-%\%nzogps_nzad:_=-%.csv
set nzogps_nzrdf=..\..\LinzDataService\%nzogps_nzrd:_=-%\%nzogps_nzrd:_=-%.csv
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
if not [%nzogps_projlib%] == [] set proj_lib=%nzogps_projlib%
echo proj lib is %proj_lib%
if [%1]==[REDO] goto redosal
if [%1]==[REDO2] goto redosal2
%nzogps_ruby_cmd% -e 'puts File.mtime(ENV["nzogps_nzadf"]).utc.strftime("%%FT%%T")+"\n#note time is in UTC\n#set by %~0"' > ..\linz_updates\LINZ_last.date

if not exist ..\..\setlocals.bat echo setlocals.bat not found. You need to copy and customise the sample file
if not defined nzogps_ogr2ogr call ..\..\setlocals.bat

%nzogps_psql_bin%pg_isready 
if errorlevel 1 %nzogps_psql_bin%pg_ctl start -D %nzogps_psql_data%
%nzogps_psql_bin%pg_isready 
if errorlevel 1 echo Error - Can't start PostGres  & pause & exit /b 1

%nzogps_psqlc% -c "SELECT ST_ASTEXT(ST_POINT(45,45))" | grep -q "POINT(45 45)"
if errorlevel 1 echo Error - No PostGIS installed?  & pause & exit /b 1

for %%f in ("%nzogps_nzadf%" "%nzogps_nzrdf%") do (
%nzogps_grep_cmd% -q  "EPSG:4167" %%~dpnf.vrt
if errorlevel 1 echo Wrong projection  & pause & exit /b 1
)

@echo %time%
rem addresses ~1 min on garys on 2026/01/25 / 2:10 on elecst11 on 26/03/18
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT "%nzogps_nzadf%"

@echo %time%
rem roads ~ 7 sec on garys on 2026/02/22
%nzogps_ogr2ogr% --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -lco OVERWRITE=yes -lco GEOMETRY_NAME=wkb_geometry -oo GEOM_POSSIBLE_NAMES=WKT -nlt MULTILINESTRING "%nzogps_nzrdf%"

@echo %time%
%nzogps_psqlc% -c "SELECT count(*) as %nzogps_nzsl% from %nzogps_nzsl%"
if errorlevel 1 echo Error - %nzogps_nzsl% table not found. & pause & exit /b 1

%nzogps_psqlc% -c "SELECT count(*) as %nzogps_nzta% from %nzogps_nzta%"
if errorlevel 1 echo Error - %nzogps_nzta% table not found. & pause & exit /b 1
@echo %time%
%nzogps_psqlc% -v ADD_TBL=%nzogps_nzad% -v ROAD_TBL=%nzogps_nzrd% -f postproc1.sql
:redosal
REM update :ROAD_TBL_S rd
REM set suburb_locality_ascii = sal.name_ascii,
REM territorial_authority_ascii = sal.territorial_authority_ascii
REM from nz_suburbs_and_localities sal where st_within(rd.wkb_geometry,sal.wkb_geometry) and watery is not true;
pushd ..
ruby slow_query_progress.rb -i ogc_fid -t %nzogps_nzrd_s% -q " set %nzogps__sla% = sal.name_ascii,%nzogps__taa% = sal.%nzogps__taa% from %nzogps_nzsl% sal" -w "st_within(sqptbl.wkb_geometry,sal.wkb_geometry) and watery is not true "
REM 15 min on elecst11 on 26/03/19
popd

REM update :ROAD_TBL_S rd
	REM set suburb_locality_ascii = name_ascii,
	    REM territorial_authority_ascii = isect.territorial_authority_ascii
	REM from (
		REM SELECT distinct on (rd.ogc_fid) 
			REM st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
			REM FROM :ROAD_TBL_S rd
			REM join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
			REM WHERE suburb_locality_ascii is null and watery is not true
			REM order by rd.ogc_fid, overlap desc
	REM ) as isect
REM where rd.ogc_fid = isect.ogc_fid;
:redosal2
pushd ..
ruby slow_query_progress.rb -i ogc_fid -t %nzogps_nzrd_s% -q ^
"set %nzogps__sla% = name_ascii,%nzogps__taa% = isect.%nzogps__taa% from ( SELECT distinct on (rd.ogc_fid) st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.%nzogps__taa% ^
FROM %nzogps_nzrd_s% rd join %nzogps_nzsl% sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry) where %nzogps__sla% is null and watery is not true ^
order by rd.ogc_fid, overlap desc) as isect" -w  "sqptbl.ogc_fid = isect.ogc_fid"
popd
%nzogps_psqlc% -v ADD_TBL=%nzogps_nzad% -v ROAD_TBL=%nzogps_nzrd% -v ROAD_TBL_S=%nzogps_nzrd_s% -f postproc2.sql
echo %time%
rem call add_burbs.bat 
%nzogps_touch_cmd% ../database.date
