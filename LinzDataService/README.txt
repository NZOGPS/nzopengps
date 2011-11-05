This script takes the LINZ Data Service official road centre line shape files and converts them to Polish format suitable for copy/pasting into the NZOGPS maps.

Done
  Stage 1: Convert Data
Future:
  Stage 2: Identify differences between LINZ data and NZOGPS data

Inputs:

LINZ Data Service exports from
http://data.linz.govt.nz/layer/818-nz-road-centre-line-electoral/
 -- must export using Map Projection NZGD2000 (EPSG: 4167 Lat/Long) NOT the default option NZGD200 / NZ Transverse Mercator 

Extract into folder LinzDataService/lds-nz-road-centre-line-electoral-SHP
 
Outputs:
Polish format LINZ files

Requirements:
Ruby 1.87+, 1.93 recommeneded

Ruby Windows Installation Instructions:
Get the latest installer from http://rubyinstaller.org/downloads/
You will also need the DEVELOPMENT KIT on that page. Instructions for devkit install here
https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
(These instructions could do with expansion...)

Rubygems
These are libraries that we must install to run this script. Run the following from command line.
gem install rgeo #https://github.com/dazuma/rgeo
gem install rgeo-shapefile #http://virtuoso.rubyforge.org/rgeo-shapefile/
gem install dbf

Script developed November 2011 using Ruby 1.8.7 p352

###########################
Processing
Download and extract the current complete Zenbu export file
www.zenbu.co.nz/export/all
into ZenbuPOIcompiler2011

The batch files contain the calls which need to be executed, in the designated order
0-PullSVNpoiFiles.bat
1-Process.bat
2-SVN commit.bat
####
NOTES

routines.rb contains all the methods
process.rb is the simple process

The text "#NZ CUSTOMISED" is used to mark code that has NZ specific functionality (particularly for anyone wanting to use this for other Zenbu country data (2010 Cook Islands only))
