Title Generate CSV
setlocal
if [%1]==[PILOT] SET GNPARM=-P

start /low /min %~n01.bat %1
start /low /min %~n02.bat %1
start /low /min %~n03.bat %1

set PROCESSING_LIBRARY=4%GNPARM%
%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 6 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 8 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 5 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 7 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 2 %PROCESSING_LIBRARY%

Title GenCSV Done