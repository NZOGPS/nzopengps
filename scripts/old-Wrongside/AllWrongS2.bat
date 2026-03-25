@echo off
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
title Wrongside CCTN
call Process_tile Canterbury
call Process_tile Central
call Process_tile Tasman
call Process_tile Northland
title Done wrongside CCTN