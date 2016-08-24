tstart = Time.now
print "shape-parser.rb #{tstart}\nLoading library code...\n"

begin
  require 'rgeo/shapefile'
rescue LoadError
  print "Gem missing (rgeo/shapefile). See README.txt\n"
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

tend = Time.new
print "\nDone #{tend} - #{'%.01f' % (tend-tstart)} seconds\n"