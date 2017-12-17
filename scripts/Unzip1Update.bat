rem %nzogps_unzip_cmd% -ooutputs %1 *-report-?.txt
%nzogps_unzip_cmd% -o..\LinzDataService\outputslinz %1 *-LINZ-V4.mp
%nzogps_unzip_cmd% -o..\Numbers %1 *-numbers.gdb *-numbers-linzid.csv
%nzogps_unzip_cmd% -ooutputs %1 %~n1_20??-??-??.csv

