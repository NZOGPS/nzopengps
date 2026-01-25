Title GenNum WaiWgtn
if [%1]==[PILOT] SET GNPARM=-P

set PROCESSING_LIBRARY=5%GNPARM%

%nzogps_ruby_cmd% parseMP.rb 3 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 5 %PROCESSING_LIBRARY%
Title Gen WaiWgtn Done