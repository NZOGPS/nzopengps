Title GenNum CenSthCanTasNth
if [%1]==[PILOT] SET GNPARM=-P

set PROCESSING_LIBRARY=5%GNPARM%

%nzogps_ruby_cmd% parseMP.rb 4 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 8 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 7 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 6 %PROCESSING_LIBRARY%
%nzogps_ruby_cmd% parseMP.rb 1 %PROCESSING_LIBRARY%
Title Gen CSCTN Done