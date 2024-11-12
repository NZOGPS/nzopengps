@echo off
setlocal
if xx%1xx==xxxx echo tile not specified. Usage process tile tilename & goto :eof
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
for /F "usebackq" %%f IN (`%nzogps_perl_cmd% -e "print lc(pop)" %1`) DO set loopy_fn=%%~nf
if not exist %nzogps_base%\%loopy_fn%.mp echo %nzogps_base%\%loopy_fn%.mp not found & goto :eof
set nzogps_psqlc=%nzogps_psql_bin%psql -U postgres -d nzopengps
echo Loop finding processing %loopy_fn%

rem ..\mp_2_sql.pl %nzogps_base%\%loopy_fn%.mp
..\wrongside\mp_2_n_sql2.pl %nzogps_base%\%loopy_fn%.mp
%nzogps_psqlc% -f %loopy_fn%_numberlines.sql
%nzogps_psqlc% -v linestable=%loopy_fn%_numberlines -v nodedtable=%loopy_fn%_noded_loops -v outfile='%nzogps_base%\scripts\loopy\%loopy_fn%-loops.csv' -f loopy1.sql
