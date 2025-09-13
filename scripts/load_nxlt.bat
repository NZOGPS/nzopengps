set nzogps_NXLT=..\LinzDataService\CityXlate\%1_xlt_rsa_sal.csv
if exist %nzogps_NXLT% echo it exists && %nzogps_ogr2ogr% -overwrite --config PG_USE_COPY TRUE -f "PostgreSQL" "PG:host=localhost user=postgres  dbname=nzopengps" -oo autodetect_type=yes %nzogps_NXLT%
