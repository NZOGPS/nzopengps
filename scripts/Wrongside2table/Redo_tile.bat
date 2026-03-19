@echo off
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
if [%1]==[numDBdone] (
	shift
	if [%1]==[] echo tile not specified. Usage process tile tilename & goto :eof
	goto numDBdone
)
if [%1]==[] echo tile not specified. Usage process tile tilename & goto :eof
if [%nzogps_psql_bin%]==[] echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof

pushd TempData
%nzogps_perl_cmd% ..\Code\mp_2_n_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc% -f %1_numberlines.sql
echo %date% %time% > ..\..\DB_sentinels\%1-numberlines.sentinel
popd
:numDBdone
rem %nzogps_wsppl% points to different versions of postprolines depending on version of GEOS
%nzogps_psqlc% -t -v linestable=%1_numberlines -v wrongstable=%1_wrongside -v distance=100 -f Code\%nzogps_wsppl%
%nzogps_psqlc% -t -v linestable=%1_numberlines -v wrongstable=%1_wrongside -v numstable=%1_nums -v outfile='%cd%\Outputs\%1-WrongSide.csv' -f Code\intersect.sql
%nzogps_psqlc% -v linestable=%1_numberlines  -v wrongstable=%1_wrongside -v distance=350 -v outfile='%CD%\Outputs\%1-Sparsest.csv' -f Code\Sparsest.sql
rem if you get a write failure for CSV files you may need to grant write access for the user for the pg server process e.g. NETWORK SERVICE ? Use task manager/details
pushd Outputs
%nzogps_perl_cmd% ..\Code\wrongsidereport.pl %1 > Reports\%1-Wrongside-report.txt
popd
echo Wrongside processing %1 finished %time%
