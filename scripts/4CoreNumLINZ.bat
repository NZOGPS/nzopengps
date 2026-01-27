Title NumLINZ0
if [%1]==[PILOT] SET LNPARM=-P

set LN_PROCESSING_LIBRARY=3d%LNPARM%

start /low /min %~n01.bat
start /low /min %~n02.bat

%nzogps_ruby_cmd% parseMP.rb 1 %LN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %LN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %LN_PROCESSING_LIBRARY%
Title NumLINZ0 Done