Title NumLINZ0
start /low /min %~n01.bat
start /low /min %~n02.bat

set PROCESSING_LIBRARY=3
%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
Title NumLINZ0 Done