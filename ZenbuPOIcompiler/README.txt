Inputs:
a Zenbu full export file
www.zenbu.co.nz/export

Outputs:
Polish format POI files

Requirements:
Ruby 1.92+
Available for Windows from http://rubyinstaller.org/downloads/
Developed February 2011 using
http://rubyforge.org/frs/download.php/73722/rubyinstaller-1.9.2-p136.exe

###########################
Processing
Download and extract the current complete Zenbu export file
www.zenbu.co.nz/export/all

The batch files contain the calls which need to be executed, in the designated order
0-PullSVNpoiFiles.bat
1-Process.bat
2-SVN commit.bat
####
NOTES

routines.rb contains all the methods
process.rb is the simple process

The text "#NZ CUSTOMISED" is used to mark code that has NZ specific functionality (particularly for anyone wanting to use this for other Zenbu country data (2010 Cook Islands only))
