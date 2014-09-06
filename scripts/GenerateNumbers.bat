rem this file is suitable for running on single core processors
rem On a multicore processor, you would probably be better to split this into multiple files
rem e.g. start /low /min generate1.bat
rem      start /low /min generate2.bat etc
rem I have 1=akl gdb ~ 3:40, 2= wgtn+waik gdb ~ 1:40+1:40=3:30 3=other gdbs

set PROCESSING_LIBRARY=4
%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 6 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 8 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 5 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 7 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 2 %PROCESSING_LIBRARY%
set PROCESSING_LIBRARY=5
%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 6 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 8 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 5 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 7 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 2 %PROCESSING_LIBRARY%
pause