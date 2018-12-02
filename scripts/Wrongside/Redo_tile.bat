@echo off
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps

mp_2_n_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc%   -f %1_numberlines.sql
%nzogps_psqlc% -v linestable=%1_numberlines -v distance=100 -f postpro-lines.sql
%nzogps_psqlc% -v linestable=%1_numberlines  -v numstable=%1_nums -v outfile='%nzogps_base%\scripts\wrongside\%1-WrongSide.csv' -f intersect.sql
%nzogps_psqlc% -v linestable=%1_numberlines -v distance=350 -v outfile='%nzogps_base%\scripts\wrongside\%1-Sparsest.csv' -f Sparsest.sql
perl wrongsidereport.pl %1 > %1-Wrongside-report.txt