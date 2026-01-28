require 'optparse'
require 'optparse/time'
require 'optparse/date'

LINZ_URL="https://data.linz.govt.nz/services;"
FN_123110="layer_123110_cs"
FN_123113="layer_123113_cs"

LAST_FN="LINZ_last_pilot.date"

ROAD_TABLE="nz_addresses_roads_pilot_s"
NZ_ADD="nz_addresses_pilot"

options = {:download => 1, :postgres => 1, :updates => 1, :continue => 0, :from => nil, :until => nil}

def do_options(options)
	if File.exist?(LAST_FN) 
		tline = ""
		File.open(LAST_FN) do |lfile|
			tline = lfile.gets.chomp
		end
		if DateTime.strptime(tline,"%FT%T")
			options[:from] = tline
		end
	end

	parser = OptionParser.new do|opts|
		opts.banner = "Usage: #{$0} [options]"
		opts.on('-d', '--nodownload', 'Don\'t download') do |nodown|
			options[:download] = nil;
		end

		opts.on('-p', '--nopostgres', 'Don\'t load into postgres') do |nopost|
			options[:postgres] = nil;
		end

		opts.on('-u', '--noupdate', 'Don\'t do updates in postgres') do |noupd|
			options[:updates] = nil;
		end

		opts.on('-c', '--continue', 'Continue checking for errors, rather than stopping') do |cont|
			options[:continue] = 1;
		end

		opts.on("-f", "--from FROM", Time, "Specify a start time/date") do |from|
			options[:from] = from.utc.strftime("%FT%T")
		end

		opts.on("-t", "--to TOTIME", Time, "Specify an until time/date") do |to|
			options[:until] = to.utc.strftime("%FT%T")
		end

		opts.on('-h', '--help', 'Displays Help') do
			puts opts
			puts 'note: times are local times, and will be converted to utc'
			exit
		end
	end

	parser.parse!

	abort("No start date specifed, and no valid base date found in #{LAST_FN}") if options[:from] == nil
end

def get_linz_updates(options)
	#need to check these for validity

	linz_key = ENV['nzogps_linz_api_key']
	curl_cmd = ENV['nzogps_curl']
	zip_cmd  = ENV['nzogps_zip_cmd']
	abort("Processing aborted! nzogps_linz_api_key/nzogps_curl/nzogps_zip_cmd environment variable not set!") if !linz_key || !curl_cmd || !zip_cmd

	if (options[:until])
		to_date = options[:until]
	else
		nztime = Time.new
		to_date = nztime.utc.strftime("%FT%T")
		options[:until] = to_date #bit of a hack - store the time here for later
	end

	url1 = "#{LINZ_URL}key=#{linz_key}/wfs/"
	url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames="
	url3 = "-changeset^&viewparams=from:#{options[:from]}Z;to:#{to_date}Z^&outputFormat=csv"
	puts("Getting updates from #{options[:from]} to #{to_date}")
	LOGFILE.puts("Getting updates from #{options[:from]} to #{to_date}")

	dtype = "layer-"
	layer = 123110
	system("#{curl_cmd} -o #{FN_123110}.csv #{url1}#{dtype}#{layer}#{url2}#{dtype}#{layer}#{url3}")
	layer = 123113
	system("#{curl_cmd} -o #{FN_123113}.csv #{url1}#{dtype}#{layer}#{url2}#{dtype}#{layer}#{url3}")

	system("FOR /f %a IN ('WMIC OS GET LocalDateTime ^| FIND \".\"') DO #{zip_cmd} %~na.zip #{FN_123110}.csv #{FN_123113}.csv" )
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

	raw_config = File.read("../config.yml")
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
			exit 77
		end
	end
end

def put_csv_in_postgres(options)
#find ogr command from environment
	ogr_cmd = ENV['nzogps_ogr2ogr']
	abort("Processing aborted! nzogps_ogr2ogrl environment variable not set!") if !ogr_cmd

#check that vrt files with column types exist
	abort("Processing aborted! csv definition file #{FN_123110}.vrt not found!") if !File.file?("#{FN_123110}.vrt")
	abort("Processing aborted! csv definition file #{FN_123113}.vrt not found!") if !File.file?("#{FN_123113}.vrt")

#use ogr to import csv files into postgres
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{FN_123110}.vrt") or abort("Failed to run #{ogr_cmd} on #{FN_123110}")
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{FN_123113}.vrt") or abort("Failed to run #{ogr_cmd} on #{FN_123113}")

#pilot addresses
	@conn.exec "COMMENT ON TABLE #{FN_123113} IS 'Changeset data for nz_addresses_pilot from #{options[:from]} to #{options[:until]}'"
	@conn.exec "ALTER TABLE #{FN_123113} ADD COLUMN is_odd boolean"
	@conn.exec "ALTER TABLE #{FN_123113} ADD COLUMN linz_numb_id integer"
	@conn.exec "ALTER TABLE #{FN_123113} ADD COLUMN full_road_name_ascii character varying"
	@conn.exec "ALTER TABLE #{FN_123113} ADD COLUMN suburb_locality_ascii character varying"
	@conn.exec "UPDATE #{FN_123113} SET is_odd = MOD(address_number,2) = 1"
	@conn.exec "UPDATE #{FN_123113} SET full_road_name_ascii = unaccent(full_road_name)"
	@conn.exec "UPDATE #{FN_123113} SET suburb_locality_ascii = unaccent(suburb_locality)"

#pilot roads
	@conn.exec "COMMENT ON TABLE #{FN_123110} IS 'Changeset data for nz_addresses_roads_pilot from #{options[:from]} to #{options[:until]}'"
	@conn.exec "ALTER TABLE #{FN_123110} ADD COLUMN full_road_name_ascii character varying"
	@conn.exec "UPDATE #{FN_123110} SET full_road_name_ascii = unaccent(full_road_name)"

	@conn.exec "DROP TABLE IF EXISTS #{FN_123110}_s"
	@conn.exec "CREATE TABLE #{FN_123110}_s
(
	ogc_fid serial PRIMARY KEY,
	__change__ character varying(10),
	road_id integer,
	full_road_name character varying,
	is_land bool,
	wkb_geometry geometry(LineString,4167),
	full_road_name_ascii character varying,
	suburb_locality_ascii character varying,
	territorial_authority_ascii character varying
)"

# split roads into single linestrings
	@conn.exec "INSERT INTO #{FN_123110}_S (__change__,road_id,full_road_name,wkb_geometry,full_road_name_ascii,is_land)
		select nzp.__change__, nzp.road_id, nzp.full_road_name, (st_dump(wkb_geometry)).geom, nzp.full_road_name_ascii, nzp.is_land::bool
		from #{FN_123110} nzp"

# set locality and TA from SAL using within
	@conn.exec "update #{FN_123110}_s rd
		set suburb_locality_ascii = sal.name_ascii, territorial_authority_ascii = sal.territorial_authority_ascii
		from nz_suburbs_and_localities sal
		where st_within(rd.wkb_geometry,sal.wkb_geometry)"

# set locality and TA from SAL using highest overlap
	@conn.exec "update #{FN_123110}_s rd
		set suburb_locality_ascii = name_ascii, territorial_authority_ascii = isect.territorial_authority_ascii
		from (
			SELECT distinct on (rd.ogc_fid) 
				st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
				FROM #{ROAD_TABLE} rd
				join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
				WHERE suburb_locality_ascii is null
				order by rd.ogc_fid, overlap desc
		) as isect
	where rd.ogc_fid = isect.ogc_fid"

	@conn.exec "VACUUM ANALYSE #{FN_123110}"
	@conn.exec "VACUUM ANALYSE #{FN_123113}"

end

def check_for_errors(options)
	error = false

	print "Street Address changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{FN_123113} group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts

	print "Multi Road CL changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{FN_123110} group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts
	
	print "Split Road CL changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{FN_123110}_s group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts
	puts

#road subsections
#
	rs = @conn.exec "SELECT cs.road_id, cs.full_road_name_ascii, cs.__change__ from #{FN_123110} cs "\
		"join #{ROAD_TABLE} rcl on rcl.road_id = cs.road_id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " road ID(s) in road updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['road_id'] + " - " + rs.first['full_road_name_ascii']
		LOGFILE.puts rs.count.to_s + " road ID(s) in road updates for addition already exists in database"
		rs.each do |row|
			LOGFILE.puts row['road_id'] + " - " + row['full_road_name_ascii']
		end
		abort("Processing aborted") unless options[:continue] 
	end

	rs = @conn.exec "SELECT cs.road_id, cs.full_road_name_ascii, cs.__change__ from #{FN_123110} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select road_id from #{ROAD_TABLE} rcl where rcl.road_id = cs.road_id)"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " road ID(s) in road updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['road_id'] + " - " + rs.first['full_road_name_ascii']
		LOGFILE.puts rs.count.to_s + " road ID(s) in road updates for modification/deletion do not already exist in database"
		rs.each do |row|
			LOGFILE.puts row['road_id'] + " - " + row['full_road_name_ascii']
		end
	end

	abort("Processing aborted") if error #should only get here if error in last test, or --continue is used
end

def do_updates()

#road table
	@conn.exec "DELETE FROM #{ROAD_TABLE} rcl USING #{FN_3383} cs
					WHERE rcl.road_id = cs.road_id
					AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ROAD_TABLE} "\
		"( wkb_geometry, road_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name,road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii ) "\
	"SELECT "\
		"st_flipcoordinates(wkb_geometry), road_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name,road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii "\
	"FROM #{FN_3383} where __change__ = 'INSERT'"

	@conn.exec "UPDATE #{ROAD_TABLE} rcl SET "\
		"wkb_geometry=st_flipcoordinates(subquery.wkb_geometry), road_id=subquery.road_id, road_section_id=subquery.road_section_id, geometry_class=subquery.geometry_class, road_type=subquery.road_type, road_section_type=subquery.road_section_type, address_range_road_id=subquery.address_range_road_id, road_id=subquery.road_id, full_road_name=subquery.full_road_name, road_name_label=subquery.road_name_label, "\
		"road_name_prefix=subquery.road_name_prefix, road_name_body=subquery.road_name_body, road_name_type=subquery.road_name_type, road_name_suffix=subquery.road_name_suffix, secondary_road_name=subquery.secondary_road_name, full_route_name=subquery.full_route_name, secondary_route_name=subquery.secondary_route_name, tertiary_route_name=subquery.tertiary_route_name, "\
		"left_suburb_locality=subquery.left_suburb_locality, right_suburb_locality=subquery.right_suburb_locality, left_town_city=subquery.left_town_city, right_town_city=subquery.right_town_city, left_territorial_authority=subquery.left_territorial_authority, right_territorial_authority=subquery.right_territorial_authority, full_road_name_ascii=subquery.full_road_name_ascii, road_name_label_ascii=subquery.road_name_label_ascii, "\
		"road_name_body_ascii=subquery.road_name_body_ascii, secondary_road_name_ascii=subquery.secondary_road_name_ascii, left_suburb_locality_ascii=subquery.left_suburb_locality_ascii, right_suburb_locality_ascii=subquery.right_suburb_locality_ascii, left_town_city_ascii=subquery.left_town_city_ascii, right_town_city_ascii=subquery.right_town_city_ascii "\
	"FROM ( SELECT "\
		"wkb_geometry, road_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name, road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii "\
	"FROM #{FN_3383} where __change__ = 'UPDATE') AS subquery WHERE rcl.road_id=subquery.road_id"

#aims address reference
	@conn.exec "DELETE FROM #{AIMS_AR} aar USING #{FN_53331} arcs
			WHERE aar.address_reference_id = arcs.address_reference_id
			AND arcs.__change__ = 'DELETE';"

	@conn.exec "UPDATE  #{AIMS_AR} aar SET "\
		"address_id=subquery.address_id, address_reference_object_type=subquery.address_reference_object_type, "\
		"address_reference_object_value=subquery.address_reference_object_value "\
	"FROM ( SELECT "\
		"address_reference_id, address_id, address_reference_object_type, address_reference_object_value "\
	"FROM #{FN_53331} where __change__ = 'UPDATE') AS subquery WHERE aar.address_reference_id = subquery.address_reference_id";

	@conn.exec "INSERT INTO #{AIMS_AR} "\
		"( address_id, address_reference_object_type, address_reference_object_value )"\
	"SELECT "\
		"address_id, address_reference_object_type, address_reference_object_value "\
	"FROM #{FN_53331} arcs where __change__ = 'INSERT'";

#new addresses
	@conn.exec "DELETE FROM #{NZ_ADD} nza USING #{FN_105689} nacs 
					WHERE nza.address_id = nacs.address_id 
					AND nacs.__change__ = 'DELETE'"


	@conn.exec "UPDATE  #{NZ_ADD} nza SET "\
		"wkb_geometry=st_flipcoordinates(subquery.wkb_geometry), "\
		"address_id=subquery.address_id, source_dataset=subquery.source_dataset, change_id=subquery.change_id, "\
		"full_address_number=subquery.full_address_number, full_road_name=subquery.full_road_name, full_address=subquery.full_address, road_section_id=subquery.road_section_id, "\
		"territorial_authority=subquery.territorial_authority, unit_type=subquery.unit_type, unit_value=subquery.unit_value, level_type=subquery.level_type, level_value=subquery.level_value, "\
		"address_number_prefix=subquery.address_number_prefix, address_number=subquery.address_number, address_number_suffix=subquery.address_number_suffix, address_number_high=subquery.address_number_high, "\
		"road_name_prefix=subquery.road_name_prefix, road_name=subquery.road_name, road_type_name=subquery.road_type_name, road_suffix=subquery.road_suffix, "\
		"water_name=subquery.water_name, water_body_name=subquery.water_body_name, suburb_locality=subquery.suburb_locality, town_city=subquery.town_city, "\
		"address_class=subquery.address_class, address_lifecycle=subquery.address_lifecycle, "\
		"gd2000_xcoord=subquery.gd2000_xcoord, gd2000_ycoord=subquery.gd2000_ycoord, "\
		"road_name_ascii=subquery.road_name_ascii, water_name_ascii=subquery.water_name_ascii, water_body_name_ascii=subquery.water_body_name_ascii, suburb_locality_ascii=subquery.suburb_locality_ascii, "\
		"town_city_ascii=subquery.town_city_ascii, full_road_name_ascii=subquery.full_road_name_ascii, full_address_ascii=subquery.full_address_ascii, shape_x=subquery.gd2000_xcoord, shape_y=subquery.gd2000_ycoord, "\
		"is_odd=subquery.is_odd, rna_id=subquery.rna_id, linz_numb_id=subquery.linz_numb_id "\
	"FROM ( SELECT "\
		"wkb_geometry, "\
		"address_id, source_dataset, change_id, "\
		"full_address_number, full_road_name, full_address, road_section_id, "\
		"territorial_authority, unit_type, unit_value, level_type, level_value, "\
		"address_number_prefix, address_number, address_number_suffix, address_number_high, "\
		"road_name_prefix, road_name, road_type_name, road_suffix, "\
		"water_name, water_body_name, suburb_locality, town_city, "\
		"address_class, address_lifecycle, "\
		"gd2000_xcoord, gd2000_ycoord, "\
		"road_name_ascii, water_name_ascii, water_body_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, "\
		"is_odd, rna_id, linz_numb_id "\
	"FROM #{FN_105689} nacs where __change__ = 'UPDATE') AS subquery WHERE subquery.address_id = nza.address_id";

	@conn.exec "INSERT INTO #{NZ_ADD} "\
		"( wkb_geometry, "\
		"address_id, source_dataset, change_id, "\
		"full_address_number, full_road_name, full_address, road_section_id, "\
		"territorial_authority, unit_type, unit_value, level_type, level_value, "\
		"address_number_prefix, address_number, address_number_suffix, address_number_high, "\
		"road_name_prefix, road_name, road_type_name, road_suffix, "\
		"water_name, water_body_name, suburb_locality, town_city, "\
		"address_class, address_lifecycle, "\
		"gd2000_xcoord, gd2000_ycoord, "\
		"road_name_ascii, water_name_ascii, water_body_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, shape_x, shape_y, "\
		"is_odd, rna_id, linz_numb_id ) "\
	"SELECT "\
		"st_flipcoordinates(wkb_geometry), "\
		"address_id, source_dataset, change_id, "\
		"full_address_number, full_road_name, full_address, road_section_id, "\
		"territorial_authority, unit_type, unit_value, level_type, level_value, "\
		"address_number_prefix, address_number, address_number_suffix, address_number_high, "\
		"road_name_prefix, road_name, road_type_name, road_suffix, "\
		"water_name, water_body_name, suburb_locality, town_city, "\
		"address_class, address_lifecycle, "\
		"gd2000_xcoord, gd2000_ycoord, "\
		"road_name_ascii, water_name_ascii, water_body_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, gd2000_xcoord, gd2000_ycoord, "\
		"is_odd, rna_id, linz_numb_id "\
	"FROM #{FN_105689} nacs where __change__ = 'INSERT';"

end

# Start of processing
#
LOGFILE = File.new("update.log","w")

do_options(options)

if (options[:download]) 
	get_linz_updates(options)
end

pg_connect()

if (options[:postgres]) 
	put_csv_in_postgres(options)
	check_for_errors(options)
end

if (options[:updates]) 
	do_updates()
end

if (options[:download] && options[:postgres] && options[:updates])
	File.open(LAST_FN, 'w') do |file| 
		file.puts "#{options[:until]}"
		file.puts "# time is in UTC"
		file.puts "# set by #{__FILE__}"
	end
end

LOGFILE.close