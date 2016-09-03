@echo off
if not exist ..\setlocals.bat echo ..\setlocals.bat not found. You need to copy and customise the sample file & goto :eof
if not defined nzogps_base call ..\setlocals.bat
@echo on
%nzogps_git% pull -v
cd ..\scripts\linz_updates
%nzogps_ruby_cmd% temp.rb
cd ..
start %nzogps_donumbers%
cd ..\linzdataservice
%nzogps_ruby_cmd% pg-road-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
call numberlinz.bat
