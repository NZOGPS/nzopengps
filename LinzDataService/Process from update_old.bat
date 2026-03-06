@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v
cd ..\scripts\linz_updates
%nzogps_ruby_cmd% do_updates.rb
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..
start %nzogps_donumbers%
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser.rb
cd ..\scripts
call dochecks.bat
rem cd linz_updates
rem %nzogps_psql_bin%\psql -U postgres -d nzopengps -c "select NewRoadBookmarks()"
rem cd ..
call colouriseall.bat
if errorlevel 1 goto :eof
call %nzogps_linznumb%
