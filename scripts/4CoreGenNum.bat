Title Generate CSV

if [%1]==[PILOT] SET GNPARM=-P

start /low /min %~n01.bat
start /low /min %~n02.bat
start /low /min %~n03.bat

set GN_PROCESSING_LIBRARY=4%GNPARM%
%nzogps_ruby_cmd% parseMP.rb 1 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 6 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 8 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 5 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 7 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %GN_PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 2 %GN_PROCESSING_LIBRARY%

Title GenCSV Done