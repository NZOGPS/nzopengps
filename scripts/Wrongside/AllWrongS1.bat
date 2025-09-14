@echo off
if xx%nzogps_psql_bin%xx==xxxx echo NZOGPS Environment Variables not set - run setlocals.bat & goto :eof
title Wrongside WaiWel
call Process_tile Waikato
call Process_tile Wellington
title Done wrongside WaiWel