ROAD_TABLE="nz_roads_subsections_addressing"

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
		#print "#{rec["id"]} #{rec["name"]}\n"
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
		@conn = PG.connect(app_config['postgres']['host'], 5432, "", "", "nzopengps", "postgres", app_config['postgres']['password'])
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

rs = @conn.exec("SELECT road_id as id, road_section_id as rsid, address_range_road_id as addrid, case full_road_name_ascii when '' then road_type else full_road_name_ascii end as name,left_suburb_locality_ascii as locality,left_territorial_authority as territoria,st_astext(wkb_geometry) as wkt from #{ROAD_TABLE} where geometry_class = 'Addressing Road'")
puts "Database contains #{rs.count} Addressing Roads."
rs.each do |record|
	rgeorec=RecEnv.new(record)
	process_geom_record(rgeorec)
	progress
end

tend = Time.new
print "\nDone #{tend} - #{'%.01f' % (tend-tstart)} seconds\n"