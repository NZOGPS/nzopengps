start tortoiseproc /command:update /path:".." /closeonend:1
move "C:\Documents and Settings\turner\My Documents\Downloads\lds-new-zealand-2layers-SHP.zip" .
wzunzip lds-new-zealand-2layers-SHP -o lds-nz-street-address-electoral-SHP	*\nz-street-address-elector.*
wzunzip lds-new-zealand-2layers-SHP -o lds-nz-road-centre-line-electoral-SHP	*\nz-road-centre-line-elect.*
perl renzip.pl
:xx
cd ..\scripts\postgres
call update.bat
cd ..
start GenerateNumbers.bat
cd ..\linzdataservice
ruby shape-parser.rb
cd ..\scripts
call dochecks.bat
call colouriseall.bat
call numberlinz.bat
