@echo off
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
if not exist %nzogps_base%\%1.mp echo %nzogps_base%\%1.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
echo Loop finding processing %1

..\mp_2_sql.pl %nzogps_base%\%1.mp
%nzogps_psqlc% -f %1.sql
%nzogps_psqlc% -v linestable=%1 -v nodedtable=%1_noded_loops -v outfile='%nzogps_base%\scripts\loopy\%1-loops.csv' -f loopy1.sql
