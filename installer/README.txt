This installer directory is setup so that anyone can compile the maps without major setup requirements. 
All file paths are relative (except to the compiler executables) so few local changes are required.

============
PREREQUISITES
============
You must have the following software installed on your system

Inno Setup http://www.jrsoftware.org/isinfo.php
cGPSmapper http://cgpsmapper.com/

============
SETUP
============

Make a copy of the BatchCompile.sample file named BatchCompile.bat
Because BatchCompile.bat contains references to your local file structures it will not be checked in to SVN.

Edit the two lines at the top of BatchCompile.bat
These must point to the directories where Inno Setup and cGPSmapper are installed. The defaults may be sufficient.

set cgpsmapperLocation="C:\Program Files\cgpsmapper"
set innoSetupLocation="C:\Program Files\Inno Setup 5"

============
EXECUTION
============
Double-click BatchCompile.bat to compile the maps and then build the installer.
All compilation files go into the installer/tmp directory so won't be checked back in to SVN