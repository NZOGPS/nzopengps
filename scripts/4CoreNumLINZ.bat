Title NumLINZ0

set PROCESSING_LIBRARY=3d

start /low /min %~n01.bat
start /low /min %~n02.bat

%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
Title NumLINZ0 Done