These scripts takes the LINZ Data Service official road centre line data and converts it to Polish format suitable for copy/pasting into the NZOGPS maps.

Done
  Stage 1: Convert Data
  Stage 2: Identify differences between LINZ data and NZOGPS data

There area two options. Do a full download, or do an update. 

To do a full download:

Inputs:
The LINZ Data Service exports are available from
https://data.linz.govt.nz/layer/53383-nz-roads-subsections-addressing/history/
https://data.linz.govt.nz/layer/53353-nz-street-address/

Select both of these data sets.
 -- Select CSV output format
 -- you must export using Map Projection NZGD2000 (EPSG: 4167 Lat/Long) NOT the default option NZGD200 / NZ Transverse Mercator 
These won't be checked into our repository, so each person that wants to generate files will need to get the data for themselves.

Then run the script 'process from download'. This will 

Outputs:
Polish format LINZ files

Requirements:
Ruby 1.87+, 1.93 recommended

Ruby Windows Installation Instructions:
Get the latest installer from http://rubyinstaller.org/downloads/
You will also need the DEVELOPMENT KIT on that page. Instructions for devkit install here
https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
(These instructions could do with expansion...)

Rubygems
These are libraries that we must install to run this script. Run the following from command line.

gem install progressbar -v 0.21
#documentation https://github.com/jfelchner/ruby-progressbar
#newer versions have different syntax, so you need to install an old version

gem install rgeo
#documentation https://github.com/dazuma/rgeo

#maybe? Not sure if still needed?
gem install dbf

Script developed November 2011 using Ruby 1.8.7 p352

###########################
