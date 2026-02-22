require 'optparse'
require 'optparse/time'
require 'optparse/date'
require 'progressbar'

LINZ_URL="https://data.linz.govt.nz/services;"

ROAD=  {csfn: "layer_123110_cs",   tbln: "nz_addresses_roads_pilot"}
ROAD_S={csfn: "layer_123110_cs_s", tbln: "nz_addresses_roads_pilot_s"}
ADDR=  {csfn: "layer_123113_cs",   tbln: "nz_addresses_pilot"}

LAST_FN="LINZ_last_pilot.date"
DEBUG=true

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

		opts.on('-p', '--nopostgres', 'Don\'t load changeset into postgres') do |nopost|
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
			puts 'note: times are local times, and will be converted to UTC'
			exit
		end
	end

	parser.parse!

	abort("No start date specified, and no valid base date found in #{LAST_FN}") if options[:from] == nil
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
	system("#{curl_cmd} -o #{ROAD[:csfn]}.csv #{url1}#{dtype}#{layer}#{url2}#{dtype}#{layer}#{url3}")
	layer = 123113
	system("#{curl_cmd} -o #{ADDR[:csfn]}.csv #{url1}#{dtype}#{layer}#{url2}#{dtype}#{layer}#{url3}")

	system("FOR /f %a IN ('WMIC OS GET LocalDateTime ^| FIND \".\"') DO #{zip_cmd} %~na_P.zip #{ROAD[:csfn]}.csv #{ADDR[:csfn]}.csv" ) # _P in %~na_P for pilot
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
	print "Connected\n" if DEBUG
end

def put_csv_in_postgres(options)
#find ogr command from environment
	ogr_cmd = ENV['nzogps_ogr2ogr']
	abort("Processing aborted! nzogps_ogr2ogr environment variable not set!") if !ogr_cmd

	proj_lib = {}
	if ( ENV['nzogps_projlib']) then
		pl_env = ENV['nzogps_projlib'].gsub("\\","/") #easier to use forward slashes than messy escaping
		proj_lib = {"PROJ_LIB" => pl_env}
		puts("proj_lib: ",proj_lib,pl_env)
	end
	
#check that vrt files with column types exist
	abort("Processing aborted! csv definition file #{ROAD[:csfn]}.vrt not found!") if !File.file?("#{ROAD[:csfn]}.vrt")
	abort("Processing aborted! csv definition file #{ADDR[:csfn]}.vrt not found!") if !File.file?("#{ADDR[:csfn]}.vrt")

#use ogr to import csv files into postgres
	print("ogr2ogr cmd is: ",proj_lib,"#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ROAD[:csfn]}.vrt\n") if DEBUG

	system(proj_lib,"#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ROAD[:csfn]}.vrt") or abort("Failed to run #{ogr_cmd} on #{ROAD[:csfn]}")
	system(proj_lib,"#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ADDR[:csfn]}.vrt") or abort("Failed to run #{ogr_cmd} on #{ADDR[:csfn]}")
	print "Files uploaded\n" if DEBUG

#pilot addresses
	@conn.exec "COMMENT ON TABLE #{ADDR[:csfn]} IS 'Changeset data for nz_addresses_pilot from #{options[:from]} to #{options[:until]}'"
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} ADD COLUMN is_odd boolean"
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} ADD COLUMN linz_numb_id integer"
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} ADD COLUMN updated character varying"
	rs = @conn.exec "UPDATE #{ADDR[:csfn]} SET is_odd = MOD(address_number,2) = 1"
	print "is_odd: #{rs.cmd_tuples} lines changed \n" if DEBUG
	@conn.exec "UPDATE #{ADDR[:csfn]} SET updated = '"+options[:until]+"'"


#booleanise is_land
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} RENAME COLUMN is_land TO is_land_txt"
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} ADD COLUMN is_land boolean"
	@conn.exec "UPDATE #{ADDR[:csfn]} SET is_land = is_land_txt::BOOLEAN"
	@conn.exec "ALTER TABLE #{ADDR[:csfn]} DROP COLUMN is_land_txt"

	@conn.exec "UPDATE #{ADDR[:csfn]} SET wkb_geometry = st_flipcoordinates(wkb_geometry)"
	rs = @conn.exec "UPDATE #{ADDR[:csfn]} SET address_number_high = NULL where address_number_high = 0"
	print "add_num_high: #{rs.cmd_tuples} lines changed \n" if DEBUG
	@conn.exec "UPDATE #{ADDR[:csfn]} SET updated = '"+options[:until]+"'"


	print "Addresses done\n" if DEBUG

#pilot roads
	@conn.exec "COMMENT ON TABLE #{ROAD[:csfn]} IS 'Changeset data for nz_addresses_roads_pilot from #{options[:from]} to #{options[:until]}'"

	@conn.exec "ALTER TABLE #{ROAD[:csfn]} RENAME COLUMN is_land TO is_land_txt"
	@conn.exec "ALTER TABLE #{ROAD[:csfn]} ADD COLUMN is_land boolean"
	rs = @conn.exec "UPDATE #{ROAD[:csfn]} SET is_land = is_land_txt::BOOLEAN"
	@conn.exec "ALTER TABLE #{ROAD[:csfn]} DROP COLUMN is_land_txt"
	print "is_land: #{rs.cmd_tuples} lines booleanised\n" if DEBUG

	@conn.exec "UPDATE #{ROAD[:csfn]} SET wkb_geometry = st_flipcoordinates(wkb_geometry)"

	@conn.exec "DROP TABLE IF EXISTS #{ROAD_S[:csfn]}"
	print "table dropped\n" if DEBUG

	@conn.exec "CREATE TABLE #{ROAD_S[:csfn]}
	(
		ogc_fid serial PRIMARY KEY,
		__change__ character varying(10),
		road_id integer,
		full_road_name character varying,
		is_land bool,
		full_road_name_ascii character varying,
		road_name_label_ascii character varying,
		suburb_locality_ascii character varying,
		territorial_authority_ascii character varying,
		updated character varying,
		wkb_geometry geometry(LineString,4167)
	)"
	@conn.exec "COMMENT ON TABLE #{ROAD_S[:csfn]} IS 'Changeset data for nz_addresses_roads_pilot split into LineStrings from #{options[:from]} to #{options[:until]}'"
	print "Tables modified\n" if DEBUG

# split roads into single linestrings
	@conn.exec "INSERT INTO #{ROAD_S[:csfn]} (__change__, road_id, full_road_name, is_land, full_road_name_ascii, road_name_label_ascii, wkb_geometry)
		select nzp.__change__, nzp.road_id, nzp.full_road_name, nzp.is_land::bool, nzp.full_road_name_ascii, nzp.road_name_label_ascii, (st_dump(wkb_geometry)).geom
		from #{ROAD[:csfn]} nzp"
	print "Roads split\n" if DEBUG

# set locality and TA from SAL using within
	rs = @conn.exec "update #{ROAD_S[:csfn]} rd
		set suburb_locality_ascii = sal.name_ascii, territorial_authority_ascii = sal.territorial_authority_ascii
		from nz_suburbs_and_localities sal
		where st_within(rd.wkb_geometry,sal.wkb_geometry)"
	print "#{rs.cmd_tuples} road lines suburbanised by within\n" if DEBUG

# set locality and TA from SAL using highest overlap
	rs = @conn.exec "update #{ROAD_S[:csfn]} rd
		set suburb_locality_ascii = name_ascii, territorial_authority_ascii = isect.territorial_authority_ascii
		from (
			SELECT distinct on (rd.ogc_fid) 
				st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
				FROM #{ROAD_S[:tbln]} rd
				join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
				WHERE suburb_locality_ascii is null
				order by rd.ogc_fid, overlap desc
		) as isect
		where rd.ogc_fid = isect.ogc_fid"
	print "#{rs.cmd_tuples} road lines suburbanised by best fit\n" if DEBUG


	@conn.exec "VACUUM ANALYSE #{ROAD[:csfn]}"
	@conn.exec "VACUUM ANALYSE #{ROAD_S[:csfn]}"
	@conn.exec "VACUUM ANALYSE #{ADDR[:csfn]}"

end

def check_for_errors(options)
	error = false

	print "Street Address changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{ADDR[:csfn]} group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts

	print "Multi Road CL changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{ROAD[:csfn]} group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts
	
	print "Split Road CL changes: "
	rs = @conn.exec "select __change__,count (__change__) from #{ROAD_S[:csfn]} group by __change__ order by __change__"
	rs.each do |row|
		print "%s %s " % [row['__change__'],row['count']]
	end
	puts
	puts

#road subsections
#
	rs = @conn.exec "SELECT cs.address_id, cs.full_address, cs.__change__ from #{ADDR[:csfn]} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select address_id from #{ADDR[:tbln]} addr where addr.address_id = cs.address_id)"
	if rs.count > 0 then
		error = true
		STDERR.puts rs.count.to_s + " address ID(s) in address updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['address_id'] + " - " + rs.first['full_address']
		LOGFILE.puts rs.count.to_s + " address ID(s) in address updates for modification/deletion do not already exist in database"
		rs.each do |row|
			LOGFILE.puts row['address_id'] + " - " + row['full_address']
		end
		abort("Processing aborted") unless options[:continue] 
	end

	rs = @conn.exec "SELECT cs.road_id, cs.full_road_name_ascii, cs.__change__ from #{ROAD_S[:csfn]} cs "\
		"join #{ROAD_S[:tbln]} rcl on rcl.road_id = cs.road_id where cs.__change__ = 'INSERT'"
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

	rs = @conn.exec "SELECT cs.road_id, cs.full_road_name_ascii, cs.__change__ from #{ROAD_S[:csfn]} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select road_id from #{ROAD_S[:tbln]} rcl where rcl.road_id = cs.road_id)"
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

def do_updates(options)

#road table
	@conn.exec "DELETE FROM #{ROAD_S[:tbln]} rcl USING #{ROAD_S[:csfn]} cs
		WHERE rcl.road_id = cs.road_id
		AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ROAD_S[:tbln]} "\
		"( wkb_geometry, road_id, full_road_name, is_land,"\
		" full_road_name_ascii, road_name_label_ascii,"\
		" suburb_locality_ascii, territorial_authority_ascii, updated )"\
	"SELECT "\
		"wkb_geometry, road_id, full_road_name, is_land, "\
		" full_road_name_ascii, road_name_label_ascii,"\
		" suburb_locality_ascii, territorial_authority_ascii, updated "\
	"FROM #{ROAD_S[:csfn]} where __change__ = 'INSERT'"

#up to here. What to do? Does update for split lines mean deleting first?

	@conn.exec "UPDATE #{ROAD_S[:tbln]} rcl SET "\
		"road_id=subquery.road_id, full_road_name=subquery.full_road_name, is_land=subquery.is_land, updated=subquery.updated, "\
		"full_road_name_ascii=subquery.full_road_name_ascii, road_name_label_ascii=subquery.road_name_label_ascii, "\
		"suburb_locality_ascii=subquery.suburb_locality_ascii, territorial_authority_ascii=subquery.territorial_authority_ascii, wkb_geometry=subquery.wkb_geometry "\
	"FROM ( SELECT "\
		"road_id, full_road_name, is_land, updated,"\
		"full_road_name_ascii, road_name_label_ascii,"\
		"suburb_locality_ascii, territorial_authority_ascii, wkb_geometry "\
	"FROM #{ROAD_S[:csfn]} where __change__ = 'UPDATE') AS subquery WHERE rcl.road_id=subquery.road_id"

#new addresses
	@conn.exec "DELETE FROM #{ADDR[:tbln]} nza USING #{ADDR[:csfn]} nacs 
		WHERE nza.address_id = nacs.address_id 
		AND nacs.__change__ = 'DELETE'"

	@conn.exec "UPDATE  #{ADDR[:tbln]} nza SET "\
		"address_id=subquery.address_id, road_id=subquery.road_id, "\
		"full_address_number=subquery.full_address_number, full_road_name=subquery.full_road_name, full_address=subquery.full_address, "\
		"territorial_authority=subquery.territorial_authority, unit=subquery.unit, "\
		"address_number=subquery.address_number, address_number_suffix=subquery.address_number_suffix, address_number_high=subquery.address_number_high, "\
		"road_name=subquery.road_name, road_name_type=subquery.road_name_type, road_name_suffix=subquery.road_name_suffix, "\
		"suburb_locality=subquery.suburb_locality, town_city=subquery.town_city, is_land=subquery.is_land, address_lifecycle=subquery.address_lifecycle, "\
		"shape_x=subquery.st_x, shape_y=subquery.st_y, "\
		"full_road_name_ascii=subquery.full_road_name_ascii, full_address_ascii=subquery.full_address_ascii, territorial_authority_ascii=subquery.territorial_authority_ascii, "\
		"road_name_ascii=subquery.road_name_ascii, suburb_locality_ascii=subquery.suburb_locality_ascii, town_city_ascii=subquery.town_city_ascii, "\
		"is_odd=subquery.is_odd, linz_numb_id=subquery.linz_numb_id, updated=subquery.updated, "\
		"wkb_geometry=subquery.wkb_geometry "\
	"FROM ( SELECT "\
		"address_id, road_id, "\
		"full_address_number, full_road_name, full_address, "\
		"territorial_authority, unit, "\
		"address_number, address_number_suffix, address_number_high, "\
		"road_name, road_name_type, road_name_suffix, "\
		"suburb_locality, town_city, is_land, address_lifecycle, "\
		"st_x(wkb_geometry), st_y(wkb_geometry), "\
		"full_road_name_ascii, full_address_ascii, territorial_authority_ascii, "\
		"road_name_ascii, suburb_locality_ascii, town_city_ascii, "\
		"is_odd, linz_numb_id, updated, "\
		"wkb_geometry "\
	"FROM #{ADDR[:csfn]} nacs where __change__ = 'UPDATE') AS subquery WHERE subquery.address_id = nza.address_id";

	@conn.exec "INSERT INTO #{ADDR[:tbln]} "\
		"( address_id, road_id, "\
		"full_address_number, full_road_name, full_address, "\
		"territorial_authority, unit, "\
		"address_number, address_number_suffix, address_number_high, "\
		"road_name, road_name_type, road_name_suffix, "\
		"suburb_locality, town_city, address_lifecycle, "\
		"shape_x, shape_y, "\
		"full_road_name_ascii, full_address_ascii, territorial_authority_ascii, "\
		"road_name_ascii, suburb_locality_ascii, town_city_ascii, "\
		"is_odd, is_land, linz_numb_id, updated, "\
		" wkb_geometry )"\
	"SELECT "\
		"address_id, road_id, "\
		"full_address_number, full_road_name, full_address, "\
		"territorial_authority, unit, "\
		"address_number, address_number_suffix, address_number_high, "\
		"road_name, road_name_type, road_name_suffix, "\
		"suburb_locality, town_city, address_lifecycle, "\
		"st_x(wkb_geometry), st_y(wkb_geometry), "\
		"full_road_name_ascii, full_address_ascii, territorial_authority_ascii, "\
		"road_name_ascii, suburb_locality_ascii, town_city_ascii, "\
		"is_odd, is_land, linz_numb_id, updated, "\
		"wkb_geometry "\
	"FROM #{ADDR[:csfn]} nacs where __change__ = 'INSERT';"

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
	do_updates(options)
end

if (options[:download] && options[:postgres] && options[:updates])
	File.open(LAST_FN, 'w') do |file| 
		file.puts "#{options[:until]}"
		file.puts "# time is in UTC"
		file.puts "# set by #{__FILE__}"
	end
end

LOGFILE.close