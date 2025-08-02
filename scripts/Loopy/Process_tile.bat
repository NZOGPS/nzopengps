@echo off
setlocal
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
for /F "delims=-_ tokens=1 usebackq" %%f IN (`%nzogps_perl_cmd% -e "print lc(pop)" %1`) DO set loopy_f=%%~nf
if not exist %nzogps_base%\%loopy_f%.mp echo %nzogps_base%\%loopy_f%.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
echo Loop finding processing %loopy_f%

cd sql
..\..\wrongside\mp_2_n_sql2.pl %nzogps_base%\%loopy_f%.mp
%nzogps_psqlc% -f %loopy_f%_numberlines.sql
%nzogps_psqlc% -v linestable=%loopy_f%_numberlines -v nodedtable=%loopy_f%_noded_loops -v outfile='%nzogps_base%\scripts\loopy\outputs\%loopy_f%-loops.csv' -f ..\loopy.sql
rem cd ..
