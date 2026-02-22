@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v
cd ..\scripts\linz_updates
%nzogps_ruby_cmd% do_updates_pilot.rb
if %errorlevel% neq 0 exit /b %errorlevel%
cd ..
start %nzogps_donumbers% PILOT
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser-pilot.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat PILOT
if errorlevel 1 goto :eof
call %nzogps_linznumb% PILOT
