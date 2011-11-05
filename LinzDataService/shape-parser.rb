print "shape-parser.rb #{Time.now}\nLoading library code...\n"

begin
  require 'rgeo/shapefile'
rescue LoadError
  print "Gem missing. See README.txt\n"
  exit
end
load "nzogps_library.rb"

path = 'lds-nz-road-centre-line-electoral-SHP/nz-road-centre-line-electoral.shp'

initialise_tile_file_handles

print "Opening #{path}\n"
RGeo::Shapefile::Reader.open(path, :srid => 4167 ) do |file|
  puts "File contains #{file.num_records} records."
  file.each do |record|
    process_geom_record(record)
    progress
  end
end
