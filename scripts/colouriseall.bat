setlocal
if [%1]==[PILOT] SET GNPARM=-P

perl colourisenodise.pl Northland%GNPARM%
if errorlevel 1 exit /b %errorlevel%
perl colourisenodise.pl Auckland%GNPARM%
perl colourisenodise.pl Waikato%GNPARM%
perl colourisenodise.pl Central%GNPARM%
perl colourisenodise.pl Wellington%GNPARM%
perl colourisenodise.pl Tasman%GNPARM%
perl colourisenodise.pl Canterbury%GNPARM%
perl colourisenodise.pl Southland%GNPARM%