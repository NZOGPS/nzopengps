@echo off
if not exist ..\..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\..\setlocals.bat
@echo on
pushd ..\linz_updates
%nzogps_ruby_cmd% do_updates.rb -S
if %errorlevel% neq 0 exit /b %errorlevel%
popd
