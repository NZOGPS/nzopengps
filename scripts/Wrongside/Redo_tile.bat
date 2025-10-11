@echo on
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps

cd TempData
%nzogps_perl_cmd% ..\Code\mp_2_n_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc% -f %1_numberlines.sql
cd ..
%nzogps_psqlc% -v linestable=%1_numberlines -v distance=100 -f Code\%nzogps_wsppl%
%nzogps_psqlc% -v linestable=%1_numberlines  -v numstable=%1_nums -v outfile='%nzogps_base%\scripts\wrongside\Outputs\%1-WrongSide.csv' -f Code\intersect.sql
%nzogps_psqlc% -v linestable=%1_numberlines -v distance=350 -v outfile='%nzogps_base%\scripts\wrongside\Outputs\%1-Sparsest.csv' -f Code\Sparsest.sql
rem if you get a write failure for CSV files you may need to grant write access for the user for the pg server process e.g. NETWORK SERVICE ? Use task manager/details
cd Outputs
%nzogps_perl_cmd% ..\Code\wrongsidereport.pl %1 > %1-Wrongside-report.txt
cd ..
echo Wrongside processing %1 finished %time%
