ROAD_TABLE="\"nz-road-centre-line-electoral\""

tstart = Time.new
print "pg-road-parser.rb #{tstart}\nLoading library code...\n"

begin
  require 'rgeo'
rescue LoadError
  print "Gem missing (rgeo/shapefile). See README.txt\n"
  exit
end

class RecEnv
	def initialize(rec)
		@attributes = Hash.new
		@attributes = rec
		fac = RGeo::Cartesian.factory
		@geometry=fac.parse_wkt(rec['wkt'])
	end
	attr_accessor :attributes, :geometry
end

def pg_connect()
	begin
		require 'pg'
	rescue LoadError
		puts "Gem missing. Please run: gem install pg\n" 
		exit
	end

	begin
	  require 'yaml'
	rescue LoadError
		puts "Gem missing. Please run: gem install yaml\n" 
		exit
	end
  
	raw_config = File.read("../scripts/config.yml")
	app_config = YAML.load(raw_config)

	begin
		@conn = PGconn.connect(app_config['postgres']['host'], 5432, "", "", "nzopengps", "postgres", app_config['postgres']['password'])
		rescue
			if $! == 'Invalid argument' then
			retry #bollocks error
		end

		print "An error occurred connecting to database: ",$!, "\nTry again (y/n)?"
		user_says = STDIN.gets.chomp
		if user_says == 'y' then
			retry
		else
			print "Could not connect to database. Exiting.\n"
			exit
		end
	end
end

load "nzogps_library.rb"

initialise_tile_file_handles
pg_connect

rs = @conn.exec("SELECT id,name,locality,territoria,st_astext(the_geom) as wkt from #{ROAD_TABLE}")
puts "Database contains #{rs.count} records."
rs.each do |record|
	rgeorec=RecEnv.new(record)
	process_geom_record(rgeorec)
	progress
end

tend = Time.new
print "\nDone #{tend} - #{'%.01f' % (tend-tstart)} seconds\n"