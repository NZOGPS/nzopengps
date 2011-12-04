This script takes the LINZ Data Service official road centre line shape files and converts them to Polish format suitable for copy/pasting into the NZOGPS maps.

Done
  Stage 1: Convert Data
Future:
  Stage 2: Identify differences between LINZ data and NZOGPS data

Inputs:
The LINZ Data Service exports are available from
http://data.linz.govt.nz/layer/818-nz-road-centre-line-electoral/
You can also get NUMBERS although they aren't specifically needed for this step
http://data.linz.govt.nz/layer/779-nz-street-address-electoral/

 -- must export using Map Projection NZGD2000 (EPSG: 4167 Lat/Long) NOT the default option NZGD200 / NZ Transverse Mercator 
These won't be checked into our repository, so each person will need to get it themselves.

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
gem install rgeo
#documentation https://github.com/dazuma/rgeo
gem install rgeo-shapefile
#documetation http://virtuoso.rubyforge.org/rgeo-shapefile/
gem install dbf

Script developed November 2011 using Ruby 1.8.7 p352

###########################
