require 'optparse'
require 'optparse/time'
require 'optparse/date'

LINZ_URL="https://data.linz.govt.nz/services;"
FN_3353="layer_3353_cs"
FN_3383="layer_3383_cs"

LAST_FN="LINZ_last.date"

ADDR_TABLE="nz_street_address"
ROAD_TABLE="nz_roads_subsections_addressing"

options = {:download => 1, :postgres => 1, :updates => 1, :continue => 0, :from => nil, :until => nil}

def do_options(options)
	if File.exists?(LAST_FN) 
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

	url1 = "#{LINZ_URL}key=#{linz_key}/wfs/layer-"
	url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames=layer-"
	url3 = "-changeset^&viewparams=from:#{options[:from]}Z;to:#{to_date}Z^&outputFormat=csv"
	puts("Getting updates from #{options[:from]} to #{to_date}")
	LOGFILE.puts("Getting updates from #{options[:from]} to #{to_date}")

	layer = 3353
	system("#{curl_cmd} -o #{FN_3353}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 3383
	system("#{curl_cmd} -o #{FN_3383}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	system("FOR /f %a IN ('WMIC OS GET LocalDateTime ^| FIND \".\"') DO #{zip_cmd} %~na.zip #{FN_3353}.csv #{FN_3383}.csv")
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

def put_csv_in_postgres()
	#find ogr command from environment
	ogr_cmd = ENV['nzogps_ogr2ogr']
	abort("Processing aborted! nzogps_ogr2ogrl environment variable not set!") if !ogr_cmd

	#check that vrt files with column types exist
	abort("Processing aborted! csv definition file #{FN_3353}.vrt not found!") if !File.file?("#{FN_3353}.vrt")
	abort("Processing aborted! csv definition file #{FN_3383}.vrt not found!") if !File.file?("#{FN_3383}.vrt")

	#use ogr to import csv files into postgres
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{FN_3353}.vrt") or abort("Failed to run #{ogr_cmd} on #{FN_3353}")
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{FN_3383}.vrt") or abort("Failed to run #{ogr_cmd} on #{FN_3353}")

	#do postprocessing of addresses in postgres
	@conn.exec "ALTER TABLE #{FN_3353} ADD COLUMN is_odd boolean"
	@conn.exec "UPDATE #{FN_3353} SET is_odd = MOD(address_number,2) = 1"
	@conn.exec "ALTER TABLE #{FN_3353}  ADD COLUMN rna_id integer;"
	@conn.exec "UPDATE #{FN_3353} SET rna_id = nz_roads_subsections_addressing.road_id from nz_roads_subsections_addressing where nz_roads_subsections_addressing.road_section_id = #{FN_3353}.road_section_id"
	@conn.exec "UPDATE #{FN_3353} SET rna_id = #{FN_3383}.road_id from #{FN_3383} where #{FN_3383}.road_section_id = #{FN_3353}.road_section_id"
	@conn.exec "ALTER TABLE #{FN_3353}  ADD COLUMN linz_numb_id integer;"
	@conn.exec "UPDATE #{FN_3383} SET address_range_road_id = null WHERE address_range_road_id = 0" #in case a.r.r.i is zero rather than blank.
	@conn.exec "UPDATE #{FN_3353} SET linz_numb_id = nz_roads_subsections_addressing.address_range_road_id from nz_roads_subsections_addressing where nz_roads_subsections_addressing.road_section_id = #{FN_3353}.road_section_id"
	@conn.exec "UPDATE #{FN_3353} SET linz_numb_id = #{FN_3383}.address_range_road_id from #{FN_3383} where #{FN_3383}.road_section_id = #{FN_3353}.road_section_id"
	
	@conn.exec "VACUUM ANALYSE #{FN_3353}"

	#do postprocessing of road centrelines in postgres
	@conn.exec "VACUUM ANALYSE #{FN_3383}"

end

def check_for_errors(options)
	error = false
	print "Address changes: "
	rs = @conn.exec "select  __change__,count  (__change__)  from #{FN_3353} group by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts

	print "Road CL changes: "
	rs = @conn.exec "select  __change__,count  (__change__)  from #{FN_3383} group by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts
	
#addresses
#
	rs = @conn.exec "SELECT cs.address_id, cs.full_address_ascii, cs.__change__ from #{FN_3353} cs "\
		"join #{ADDR_TABLE} sae on sae.address_id = cs.address_id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " ID(s) in address updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['address_id'] + " - " + rs.first['full_address_ascii']
		LOGFILE.puts rs.count.to_s + " ID(s) in address updates for addition already exists in database"
		rs.each do |row|
			LOGFILE.puts row['address_id'] + " - " + row['full_address_ascii']
		end
		abort("Processing aborted") unless options[:continue] 
	end

	rs = @conn.exec "SELECT cs.address_id, cs.full_address_ascii, cs.__change__ from #{FN_3353} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select address_id from #{ADDR_TABLE} sae where sae.address_id = cs.address_id)"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " ID(s) in address updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['address_id'] + " - " + rs.first['full_address_ascii']
		LOGFILE.puts rs.count.to_s + " ID(s) in address updates for modification/deletion do not already exist in database"
		rs.each do |row|
			LOGFILE.puts row['address_id'] + " - " + row['full_address_ascii']
		end
		abort("Processing aborted") unless options[:continue] 
	end

#road subsections
#
	rs = @conn.exec "SELECT cs.road_section_geometry_id, cs.road_name_label_ascii, cs.__change__ from #{FN_3383} cs "\
		"join #{ROAD_TABLE} rcl on rcl.road_section_geometry_id = cs.road_section_geometry_id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " ID(s) in road updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['road_section_geometry_id'] + " - " + rs.first['road_name_label_ascii']
		LOGFILE.puts rs.count.to_s + " ID(s) in road updates for addition already exists in database"
		rs.each do |row|
			LOGFILE.puts row['road_section_geometry_id'] + " - " + row['road_name_label_ascii']
		end
		abort("Processing aborted") unless options[:continue] 
	end

	rs = @conn.exec "SELECT cs.road_section_geometry_id, cs.road_name_label_ascii, cs.__change__ from #{FN_3383} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select road_section_geometry_id from #{ROAD_TABLE} rcl where rcl.road_section_geometry_id = cs.road_section_geometry_id)"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " ID(s) in road updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['road_section_geometry_id'] + " - " + rs.first['road_name_label_ascii']
		LOGFILE.puts rs.count.to_s + " ID(s) in road updates for modification/deletion do not already exist in database"
		rs.each do |row|
			LOGFILE.puts row['road_section_geometry_id'] + " - " + row['road_name_label_ascii']
		end
	end

	abort("Processing aborted") if error #should only get here if error in last test, or --continue is used
end

def do_updates()
	@conn.exec "DELETE FROM #{ADDR_TABLE} sae USING #{FN_3353} cs WHERE sae.address_id = cs.address_id AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ADDR_TABLE} "\
		"( wkb_geometry, address_id, change_id, address_type, unit_value, address_number, address_number_suffix, address_number_high, "\
		"water_route_name, water_name, suburb_locality, town_city, full_address_number, full_road_name, full_address, road_section_id, "\
		"gd2000_xcoord, gd2000_ycoord, water_route_name_ascii, water_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, shape_x, shape_y, is_odd, rna_id, linz_numb_id ) "\
	"SELECT "\
		"st_flipcoordinates(wkb_geometry), address_id, change_id, address_type, unit_value, address_number, address_number_suffix, address_number_high, "\
		"water_route_name, water_name, suburb_locality, town_city, full_address_number, full_road_name, full_address, road_section_id, "\
		"gd2000_xcoord, gd2000_ycoord, water_route_name_ascii, water_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, gd2000_xcoord, gd2000_ycoord, is_odd, rna_id, linz_numb_id "\
	"FROM #{FN_3353} where __change__ = 'INSERT'"
# note gd2000_x/ycoord twice

	@conn.exec "UPDATE #{ADDR_TABLE} sae SET "\
		"wkb_geometry=st_flipcoordinates(subquery.wkb_geometry), address_id=subquery.address_id, change_id=subquery.change_id, address_type=subquery.address_type, unit_value=subquery.unit_value, "\
		"address_number=subquery.address_number, address_number_suffix=subquery.address_number_suffix, address_number_high=subquery.address_number_high, "\
		"water_route_name=subquery.water_route_name, water_name=subquery.water_name, suburb_locality=subquery.suburb_locality, town_city=subquery.town_city, "\
		"full_address_number=subquery.full_address_number, full_road_name=subquery.full_road_name, full_address=subquery.full_address, road_section_id=subquery.road_section_id, "\
		"gd2000_xcoord=subquery.gd2000_xcoord, gd2000_ycoord=subquery.gd2000_ycoord, water_route_name_ascii=subquery.water_route_name_ascii, water_name_ascii=subquery.water_name_ascii, "\
		"suburb_locality_ascii=subquery.suburb_locality_ascii, town_city_ascii=subquery.town_city_ascii, full_road_name_ascii=subquery.full_road_name_ascii, "\
		"full_address_ascii=subquery.full_address_ascii, shape_x=subquery.gd2000_xcoord, shape_y=subquery.gd2000_ycoord, is_odd=subquery.is_odd, rna_id=subquery.rna_id, linz_numb_id=subquery.linz_numb_id "\
	"FROM ( SELECT "\
		"wkb_geometry, address_id, change_id, address_type, unit_value, address_number, address_number_suffix, address_number_high, "\
		"water_route_name, water_name, suburb_locality, town_city, full_address_number, full_road_name, full_address, road_section_id, "\
		"gd2000_xcoord, gd2000_ycoord, water_route_name_ascii, water_name_ascii, suburb_locality_ascii, "\
		"town_city_ascii, full_road_name_ascii, full_address_ascii, is_odd, rna_id, linz_numb_id "\
	"FROM #{FN_3353} where __change__ = 'UPDATE') AS subquery WHERE sae.address_id=subquery.address_id"

	@conn.exec "DELETE FROM #{ROAD_TABLE} rcl USING #{FN_3383} cs WHERE rcl.road_section_geometry_id = cs.road_section_geometry_id AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ROAD_TABLE} "\
		"( wkb_geometry, road_section_geometry_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name,road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii ) "\
	"SELECT "\
		"st_flipcoordinates(wkb_geometry), road_section_geometry_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name,road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii "\
	"FROM #{FN_3383} where __change__ = 'INSERT'"

	@conn.exec "UPDATE #{ROAD_TABLE} rcl SET "\
		"wkb_geometry=st_flipcoordinates(subquery.wkb_geometry), road_section_geometry_id=subquery.road_section_geometry_id, road_section_id=subquery.road_section_id, geometry_class=subquery.geometry_class, road_type=subquery.road_type, road_section_type=subquery.road_section_type, address_range_road_id=subquery.address_range_road_id, road_id=subquery.road_id, full_road_name=subquery.full_road_name, road_name_label=subquery.road_name_label, "\
		"road_name_prefix=subquery.road_name_prefix, road_name_body=subquery.road_name_body, road_name_type=subquery.road_name_type, road_name_suffix=subquery.road_name_suffix, secondary_road_name=subquery.secondary_road_name, full_route_name=subquery.full_route_name, secondary_route_name=subquery.secondary_route_name, tertiary_route_name=subquery.tertiary_route_name, "\
		"left_suburb_locality=subquery.left_suburb_locality, right_suburb_locality=subquery.right_suburb_locality, left_town_city=subquery.left_town_city, right_town_city=subquery.right_town_city, left_territorial_authority=subquery.left_territorial_authority, right_territorial_authority=subquery.right_territorial_authority, full_road_name_ascii=subquery.full_road_name_ascii, road_name_label_ascii=subquery.road_name_label_ascii, "\
		"road_name_body_ascii=subquery.road_name_body_ascii, secondary_road_name_ascii=subquery.secondary_road_name_ascii, left_suburb_locality_ascii=subquery.left_suburb_locality_ascii, right_suburb_locality_ascii=subquery.right_suburb_locality_ascii, left_town_city_ascii=subquery.left_town_city_ascii, right_town_city_ascii=subquery.right_town_city_ascii "\
	"FROM ( SELECT "\
		"wkb_geometry, road_section_geometry_id, road_section_id, geometry_class, road_type, road_section_type, address_range_road_id, road_id, full_road_name, road_name_label, "\
		"road_name_prefix, road_name_body, road_name_type, road_name_suffix, secondary_road_name, full_route_name, secondary_route_name, tertiary_route_name, "\
		"left_suburb_locality, right_suburb_locality, left_town_city, right_town_city, left_territorial_authority, right_territorial_authority, full_road_name_ascii, road_name_label_ascii, "\
		"road_name_body_ascii, secondary_road_name_ascii, left_suburb_locality_ascii, right_suburb_locality_ascii, left_town_city_ascii, right_town_city_ascii "\
	"FROM #{FN_3383} where __change__ = 'UPDATE') AS subquery WHERE rcl.road_section_geometry_id=subquery.road_section_geometry_id"

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
	put_csv_in_postgres()
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