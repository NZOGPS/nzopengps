@echo off
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
start /low /min AllWrongS1.bat
start /low /min AllWrongS2.bat
call Process_tile Auckland
call Process_tile Southland
title Done wrongside AkSth
