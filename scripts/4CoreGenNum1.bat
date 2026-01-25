Title GenNum Akl

if [%1]==[PILOT] SET GNPARM=-P

set PROCESSING_LIBRARY=5%GNPARM%
%nzogps_ruby_cmd% parseMP.rb 2 %PROCESSING_LIBRARY%
Title Gen Akl Done