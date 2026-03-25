require 'optparse'
require 'optparse/time'
require 'optparse/date'
require 'progressbar'
require 'pp'

LINZ_URL="https://data.linz.govt.nz/services;"

ROAD=  {layer: 123110, csfn: "layer_123110_cs",   tbln: "nz_addresses_roads"}
ROAD_S={layer: 123110, csfn: "layer_123110_cs_s", tbln: "nz_addresses_roads_s"}
ADDR=  {layer: 123113, csfn: "layer_123113_cs",   tbln: "nz_addresses"}
SALO=  {layer: 113764, csfn: "layer_113764_cs",   tbln: "nz_suburbs_and_localities"}

LAST_FN="LINZ_last.date"
LAST_SAL="LINZ_last_SAL.date"
SAL_SENTINEL="..\..\LinzDataService\nz-suburbs-and-localities.sentinel"
ADD_SENTINEL="..\database.date"

DEBUG=true

options = {:download => true, :postgres => true, :updates => true, :continue => false, :suburbs => false, :from => nil, :until => nil, :SALfrom => nil, :doaddress => true}

def get_from_date(pfname)
	if File.exist?(pfname) 
		tline = ""
		print "opening #{pfname}\n" if DEBUG
		File.open(pfname) do |lfile|
			tline = lfile.gets.chomp
		end
		if DateTime.strptime(tline,"%FT%T")
			return tline
		end
	end
	return nil
end

def do_options(options)
	options[:SALfrom] = get_from_date(LAST_SAL)
	options[:from] = get_from_date(LAST_FN)

	parser = OptionParser.new do|opts|
		opts.banner = "Usage: #{$0} [options]"
		opts.on('-s', '--suburbs', 'Do suburbs') do |burbs|
			options[:suburbs] = true;
		end

		opts.on('-S', '--suburbs-only', 'Do suburbs and not addresses') do |burbs|
			options[:suburbs] = true
			options[:doaddress] = false
		end

		opts.on('-d', '--nodownload', 'Don\'t download') do |nodown|
			options[:download] = false
		end

		opts.on('-p', '--nopostgres', 'Don\'t load changeset into postgres') do |nopost|
			options[:postgres] = false
		end

		opts.on('-u', '--noupdate', 'Don\'t do updates in postgres') do |noupd|
			options[:updates] = false;
		end

		opts.on('-c', '--continue', 'Continue checking for errors, rather than stopping') do |cont|
			options[:continue] = true;
		end

		opts.on("-f", "--from FROM", Time, "Specify a start time/date") do |from|
			options[:from] = from.utc.strftime("%FT%T")
			options[:SALfrom] = from.utc.strftime("%FT%T")
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

	abort("No start date specified, and no valid base date found in #{LAST_FN}") if options[:doaddress] and options[:from] == nil
	abort("No start date specified, and no valid base date found in #{LAST_SAL}") if options[:suburbs] and options[:SALfrom] == nil
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

	dtype = "layer-"
	files2zip =""
	
	if (options[:doaddress])
		puts("Getting address updates from #{options[:from]} to #{to_date}")
		LOGFILE.puts("Getting address updates from #{options[:from]} to #{to_date} at #{options[:currtime]}")
		print("#{curl_cmd} -o #{ROAD[:csfn]}.csv #{url1}#{dtype}#{ROAD[:layer]}#{url2}#{dtype}#{ROAD[:layer]}#{url3}") if DEBUG
		system("#{curl_cmd} -o #{ROAD[:csfn]}.csv #{url1}#{dtype}#{ROAD[:layer]}#{url2}#{dtype}#{ROAD[:layer]}#{url3}")
		system("#{curl_cmd} -o #{ADDR[:csfn]}.csv #{url1}#{dtype}#{ADDR[:layer]}#{url2}#{dtype}#{ADDR[:layer]}#{url3}")
		files2zip << " #{ROAD[:csfn]}.csv #{ADDR[:csfn]}.csv"
	end
	if (options[:suburbs])
		url3 = "-changeset^&viewparams=from:#{options[:SALfrom]}Z;to:#{to_date}Z^&outputFormat=csv"
		puts("\nGetting #{SALO[:tbln]} updates from #{options[:SALfrom]} to #{to_date}")
		LOGFILE.puts("\nGetting #{SALO[:tbln]} updates from #{options[:SALfrom]} to #{to_date} at #{options[:currtime]}")
		system("#{curl_cmd} -o #{SALO[:csfn]}.csv #{url1}#{dtype}#{SALO[:layer]}#{url2}#{dtype}#{SALO[:layer]}#{url3}")
		files2zip << " #{SALO[:csfn]}.csv"
	end

	shorttime = options[:currtime].gsub(/[\- :]/,"")

	print "Short time is #{shorttime}\n" if DEBUG
	system(" #{zip_cmd} #{shorttime}.zip #{files2zip}" ) 
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

	proj_params = {}
	if ( ENV['nzogps_projdata']) then
		pl_env = ENV['nzogps_projdata'].gsub("\\","/") #easier to use forward slashes than messy escaping
		proj_params ["PROJ_DATA"] = pl_env
		puts("proj_data: ", proj_params, pl_env) if DEBUG
	end
	if ( ENV['nzogps_gdaldata']) then
		pl_env = ENV['nzogps_gdaldata'].gsub("\\","/") #easier to use forward slashes than messy escaping
		proj_params["GDAL_DATA"] = pl_env
		puts("gdal_data: ", proj_params, pl_env) if DEBUG
	end

#check that vrt files with column types exist
	abort("Processing aborted! csv definition file #{ROAD[:csfn]}.vrt not found!") if !File.file?("#{ROAD[:csfn]}.vrt")
	abort("Processing aborted! csv definition file #{ADDR[:csfn]}.vrt not found!") if !File.file?("#{ADDR[:csfn]}.vrt")
	abort("Processing aborted! csv definition file #{SALO[:csfn]}.vrt not found!") if !File.file?("#{SALO[:csfn]}.vrt")

#use ogr to import csv files into postgres
	print("ogr2ogr cmd is: ", proj_params, "#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ROAD[:csfn]}.vrt\n") if DEBUG
	if (options[:doaddress])
		system(proj_params, "#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ROAD[:csfn]}.vrt") or abort("Failed to run #{ogr_cmd} on #{ROAD[:csfn]}")
		system(proj_params, "#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{ADDR[:csfn]}.vrt") or abort("Failed to run #{ogr_cmd} on #{ADDR[:csfn]}")
	end
	if (options[:suburbs])
		system(proj_params, "#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\" -lco OVERWRITE=yes  #{SALO[:csfn]}.vrt") or abort("Failed to run #{ogr_cmd} on #{SALO[:csfn]}")
	end
	print "Files uploaded\n" if DEBUG

#suburbs postprocessing
	if (options[:suburbs])
		@conn.exec "COMMENT ON TABLE #{SALO[:csfn]} IS 'Changeset data for #{SALO[:tbln]} from #{options[:from]} to #{options[:until]} at #{options[:currtime]}'"

		@conn.exec "ALTER TABLE #{SALO[:csfn]} ADD COLUMN watery boolean"
		@conn.exec "ALTER TABLE #{SALO[:csfn]} ADD COLUMN updated character varying"
		@conn.exec "ALTER TABLE #{SALO[:csfn]} ADD COLUMN nztm_geometry geometry(geometry,2193)"

		@conn.exec "UPDATE #{SALO[:csfn]} SET watery = false"
		@conn.exec "UPDATE #{SALO[:csfn]} SET watery = true where type = 'Coastal Bay' or type = 'Lake' or type = 'Inland Bay'"
		@conn.exec "UPDATE #{SALO[:csfn]} SET wkb_geometry = st_flipcoordinates(wkb_geometry)"
		@conn.exec "UPDATE #{SALO[:csfn]} SET nztm_geometry = st_buffer(st_transform(wkb_geometry,2193),20)"
		@conn.exec "UPDATE #{SALO[:csfn]} SET updated = '"+options[:until]+"'"
		@conn.exec "VACUUM ANALYSE #{SALO[:csfn]}"
	end

#New (2026) addresses
	if (options[:doaddress])
		@conn.exec "COMMENT ON TABLE #{ADDR[:csfn]} IS 'Changeset data for #{ADDR[:tbln]} from #{options[:from]} to #{options[:until]} at #{options[:currtime]}'"
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

#New (2026) roads
		@conn.exec "COMMENT ON TABLE #{ROAD[:csfn]} IS 'Changeset data for nz_addresses_roads from #{options[:from]} to #{options[:until]} at #{options[:currtime]}'"

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
			road_name_label character varying,
			is_land bool,
			full_road_name_ascii character varying,
			road_name_label_ascii character varying,
			suburb_locality_ascii character varying,
			territorial_authority_ascii character varying,
			updated character varying,
			wkb_geometry geometry(LineString,4167)
		)"
		@conn.exec "COMMENT ON TABLE #{ROAD_S[:csfn]} IS 'Changeset data for nz_addresses_roads split into LineStrings from #{options[:from]} to #{options[:until]} at #{options[:currtime]}'"
		print "Tables modified\n" if DEBUG

# split roads into single linestrings
		@conn.exec "INSERT INTO #{ROAD_S[:csfn]} (__change__, road_id, full_road_name, road_name_label, is_land, full_road_name_ascii, road_name_label_ascii, updated, wkb_geometry)
			select nzp.__change__, nzp.road_id, nzp.full_road_name, nzp.road_name_label, is_land::bool, nzp.full_road_name_ascii, nzp.road_name_label_ascii, '#{options[:until]}',(st_dump(wkb_geometry)).geom
			from #{ROAD[:csfn]} nzp"
		print "Roads split\n" if DEBUG

#### What about if road is in updated SAL?

# set locality and TA from SAL using within
		rs = @conn.exec ("SELECT ogc_fid FROM #{ROAD_S[:csfn]}")
		rdscnt = rs.num_tuples
		print "rdscnt is #{rdscnt}\n" if DEBUG
		within_set=0

		if rdscnt > 0 then
			@pbar = ProgressBar.create(:title=>"Locale  within", :total=>rdscnt, :length=>100)
			rs.each do |eachrd_s|
		#		print "eachrd_s is: " + eachrd_s.to_s + "\n"
				rs2 = @conn.exec "update #{ROAD_S[:csfn]} rd
					set suburb_locality_ascii = sal.name_ascii, territorial_authority_ascii = sal.territorial_authority_ascii
					from nz_suburbs_and_localities sal
					where rd.ogc_fid = #{eachrd_s['ogc_fid']} and st_within(rd.wkb_geometry,sal.wkb_geometry)"
				@pbar.increment
				within_set += rs2.cmd_tuples
			end
		end
		print "#{within_set} road lines suburbanised by within\n" if DEBUG

	# set locality and TA from SAL using highest overlap
		rs = @conn.exec ("SELECT ogc_fid FROM #{ROAD_S[:csfn]} WHERE suburb_locality_ascii is null" )
		rdscnt = rs.num_tuples
		print "rdscnt is #{rdscnt}\n" if DEBUG

		if rdscnt > 0 then
			nearest_set=0
			@pbar = ProgressBar.create(:starting_at => 0, :title=>"Locale nearest", :total=>rdscnt, :length=>100)
			rs.each do |eachrd_s|
				rs2 = @conn.exec "update #{ROAD_S[:csfn]} rd
					set suburb_locality_ascii = name_ascii, territorial_authority_ascii = isect.territorial_authority_ascii
					from (
						SELECT distinct on (rd.ogc_fid) 
							st_length(st_intersection(rd.wkb_geometry,sal.wkb_geometry)) as overlap, rd.ogc_fid, name_ascii, sal.territorial_authority_ascii 
							FROM #{ROAD_S[:csfn]} rd
							join nz_suburbs_and_localities sal on st_intersects(rd.wkb_geometry,sal.wkb_geometry)
							where rd.ogc_fid = #{eachrd_s['ogc_fid']}
							order by rd.ogc_fid, overlap desc
					) as isect
					where rd.ogc_fid = #{eachrd_s['ogc_fid']}"
				@pbar.increment
			nearest_set += rs2.cmd_tuples
			end
			print "#{nearest_set} road lines suburbanised by best fit\n" if DEBUG
		end

		rs = @conn.exec ("SELECT ogc_fid FROM #{ROAD_S[:csfn]} WHERE suburb_locality_ascii is null" )
		rdscnt = rs.num_tuples
		print "#{rdscnt} roads not suburbanised\n" if DEBUG
		print  "Suburb assignment: #{within_set} set by within, #{nearest_set} set by nearest, #{rdscnt} not set\n"

		@conn.exec "VACUUM ANALYSE #{ROAD[:csfn]}"
		@conn.exec "VACUUM ANALYSE #{ROAD_S[:csfn]}"
		@conn.exec "VACUUM ANALYSE #{ADDR[:csfn]}"
	end
end

def check_for_errors(options)
	error = false
	if (options[:suburbs])
		print "Suburbs and Localities changes: "
		rs = @conn.exec "select __change__,count (__change__) from #{SALO[:csfn]} group by __change__ order by __change__"
		rs.each do |row|
			print "%s %s " % [row['__change__'],row['count']]
		end
		puts
puts <<THEEND
 #     #                                 #####                              ###     
 ##    # ###### ###### #####   ####     #     # #    # ######  ####  #    # ###     
 # #   # #      #      #    # #         #       #    # #      #    # #   #  ###     
 #  #  # #####  #####  #    #  ####     #       ###### #####  #      ####    #      
 #   # # #      #      #    #      #    #       #    # #      #      #  #           
 #    ## #      #      #    # #    #    #     # #    # #      #    # #   #  ###     
 #     # ###### ###### #####   ####      #####  #    # ######  ####  #    # ###     
                                                                                    
                                               #                             #####  
 #    #   ##   ##### ###### #####  #   #      #  #    # ###### ##### #    # #     # 
 #    #  #  #    #   #      #    #  # #      #   ##   #     #    #   ##  ##       # 
 #    # #    #   #   #####  #    #   #      #    # #  #    #     #   # ## #    ###  
 # ## # ######   #   #      #####    #     #     #  # #   #      #   #    #    #    
 ##  ## #    #   #   #      #   #    #    #      #   ##  #       #   #    #         
 #    # #    #   #   ###### #    #   #   #       #    # ######   #   #    #    #    
THEEND
		
	end

	if (options[:doaddress])
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
	end

	if (options[:suburbs])
		rs = @conn.exec "SELECT cs.id, cs.name_ascii, cs.__change__ from #{SALO[:csfn]} cs "\
			"where cs.__change__ in ('UPDATE','DELETE') and not exists( select id from #{SALO[:tbln]} sal where sal.id = cs.id)"
		if rs.count > 0 then
			error = true
			STDERR.puts rs.count.to_s + " suburb ID(s) in suburb updates for modification/deletion do not already exist in database"
			STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['name_ascii']
			LOGFILE.puts rs.count.to_s + " suburb ID(s) in suburb updates for modification/deletion do not already exist in database"
			rs.each do |row|
				LOGFILE.puts row['id'] + " - " + row['name_ascii']
			end
			abort("Processing aborted") unless options[:continue] 
		end
	end
	print "after suburb check\n" if DEBUG

#road subsections
	if (options[:doaddress])
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
		if rs.count > 0 
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
	print "end of c_f_e\n" if DEBUG
end

def update_table_comment(table_name,curtime)
	print "upd_tbl_cmt: #{table_name}\n" if DEBUG
	tblcmt = ''
	rs = @conn.exec "SELECT obj_description('public.#{table_name}'::regclass, 'pg_class')" #get table comment
	if rs.count > 0 
		tblintro = ' Table updated: '
		tblcmt = rs.first['obj_description']
		print "upd_tbl_cmt: tblcmt1 is #{tblcmt}\n" if DEBUG
		if tblcmt =~ /#{tblintro}/ 
			tblcmt.sub!(/#{tblintro}[0-9\- :]+ by [a-zA-z_.]+/,"#{tblintro}#{curtime} by #{$0}")
		else
			print "upd_tbl_cmt: else\n" if DEBUG
			tblcmt += "#{tblintro}#{curtime} by #{$0}"
		end
		print "upd_tbl_cmt: tblcmt2 is #{tblcmt}\n" if DEBUG
		@conn.exec "COMMENT ON TABLE #{table_name} IS '#{tblcmt}'"
	end
end
	
def do_updates(options)
#suburbs
	print "in do_updates\n" if DEBUG
	if (options[:suburbs])
		rs = @conn.exec "DELETE FROM #{SALO[:tbln]} sal USING #{SALO[:csfn]} cs
			WHERE sal.id = cs.id
			AND ( cs.__change__ = 'DELETE' or cs.__change__ = 'UPDATE')"
		print rs.count.to_s + " suburbs lines deleted\n" if DEBUG

		@conn.exec "INSERT INTO #{SALO[:tbln]} "\
			"(id, name, name_ascii, additional_name, additional_name_ascii, type, major_name, major_name_ascii, major_name_type,"\
			" population_estimate, territorial_authority, territorial_authority_ascii, wkb_geometry, watery, updated, nztm_geometry )"\
		"SELECT "\
			" id, name, name_ascii, additional_name, additional_name_ascii, type, major_name, major_name_ascii, major_name_type, "\
			" population_estimate, territorial_authority, territorial_authority_ascii, wkb_geometry, watery, updated, nztm_geometry  "\
		"FROM #{SALO[:csfn]} where __change__ = 'UPDATE' or __change__ = 'INSERT'"
		update_table_comment(SALO[:tbln],options[:currtime])
	end

#road table
if (options[:doaddress])
		@conn.exec "DELETE FROM #{ROAD_S[:tbln]} rcl USING #{ROAD_S[:csfn]} cs
			WHERE rcl.road_id = cs.road_id
			AND cs.__change__ = 'DELETE'"

		@conn.exec "INSERT INTO #{ROAD_S[:tbln]} "\
			"( wkb_geometry, road_id, full_road_name, road_name_label, is_land,"\
			" full_road_name_ascii, road_name_label_ascii,"\
			" suburb_locality_ascii, territorial_authority_ascii, updated )"\
		"SELECT "\
			"wkb_geometry, road_id, full_road_name, road_name_label, is_land, "\
			" full_road_name_ascii, road_name_label_ascii,"\
			" suburb_locality_ascii, territorial_authority_ascii, updated "\
		"FROM #{ROAD_S[:csfn]} where __change__ = 'INSERT'"

	#up to here. What to do? Does update for split lines mean deleting first? YES!

		# @conn.exec "UPDATE #{ROAD_S[:tbln]} rcl SET "\
			# "road_id=subquery.road_id, full_road_name=subquery.full_road_name, road_name_label=subquery.road_name_label, is_land=subquery.is_land, updated=subquery.updated, "\
			# "full_road_name_ascii=subquery.full_road_name_ascii, road_name_label_ascii=subquery.road_name_label_ascii, "\
			# "suburb_locality_ascii=subquery.suburb_locality_ascii, territorial_authority_ascii=subquery.territorial_authority_ascii, wkb_geometry=subquery.wkb_geometry "\
		# "FROM ( SELECT "\
			# "road_id, full_road_name, road_name_label, is_land, updated,"\
			# "full_road_name_ascii, road_name_label_ascii,"\
			# "suburb_locality_ascii, territorial_authority_ascii, wkb_geometry "\
		# "FROM #{ROAD_S[:csfn]} where __change__ = 'UPDATE') AS subquery WHERE rcl.road_id=subquery.road_id"

		@conn.exec "DELETE FROM #{ROAD_S[:tbln]} rcl USING #{ROAD_S[:csfn]} cs
			WHERE rcl.road_id = cs.road_id
			AND cs.__change__ = 'UPDATE'"

		@conn.exec "INSERT INTO #{ROAD_S[:tbln]} "\
			"( wkb_geometry, road_id, full_road_name, road_name_label, is_land,"\
			" full_road_name_ascii, road_name_label_ascii,"\
			" suburb_locality_ascii, territorial_authority_ascii, updated )"\
		"SELECT "\
			"wkb_geometry, road_id, full_road_name, road_name_label, is_land, "\
			" full_road_name_ascii, road_name_label_ascii,"\
			" suburb_locality_ascii, territorial_authority_ascii, updated "\
		"FROM #{ROAD_S[:csfn]} where __change__ = 'UPDATE'"

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
		update_table_comment(ADDR[:tbln],options[:currtime])
		update_table_comment(ROAD_S[:tbln],options[:currtime])

puts <<THEEND
 #     #                                 #####                              ###                      
 ##    # ###### ###### #####   ####     #     # #    # ######  ####  #    # ###                      
 # #   # #      #      #    # #         #       #    # #      #    # #   #  ###                      
 #  #  # #####  #####  #    #  ####     #       ###### #####  #      ####    #                       
 #   # # #      #      #    #      #    #       #    # #      #      #  #                            
 #    ## #      #      #    # #    #    #     # #    # #      #    # #   #  ###                      
 #     # ###### ###### #####   ####      #####  #    # ######  ####  #    # ###                      
                                                                                                     
                                                                                              #####  
 #####   ##   #####  #      ######     ####   ####  #    # #    # ###### #    # #####  ####  #     # 
   #    #  #  #    # #      #         #    # #    # ##  ## ##  ## #      ##   #   #   #            # 
   #   #    # #####  #      #####     #      #    # # ## # # ## # #####  # #  #   #    ####     ###  
   #   ###### #    # #      #         #      #    # #    # #    # #      #  # #   #        #    #    
   #   #    # #    # #      #         #    # #    # #    # #    # #      #   ##   #   #    #         
   #   #    # #####  ###### ######     ####   ####  #    # #    # ###### #    #   #    ####     #      
THEEND

	end
end

# Start of processing
#
LOGFILE = File.new("update.log","w")

options[:currtime] = Time.now.strftime("%F %H:%M:%S")

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
	print "OE\n" if DEBUG
	do_updates(options)
end

if (options[:download] && options[:postgres] && options[:updates])
	if (options[:doaddress])
		File.open(LAST_FN, 'w') do |file| 
			file.puts "#{options[:until]}"
			file.puts "# time is in UTC"
			file.puts "# set by #{__FILE__}"
		end
		File.open(ADD_SENTINEL, 'a') do |file| 
			file.puts "#address database updated by #{__FILE__} until: #{options[:until]} at #{options[:currtime]}"
		end
	end
	if (options[:suburbs])
		File.open(LAST_SAL, 'w') do |file| 
			file.puts "#{options[:until]}"
			file.puts "# time is in UTC"
			file.puts "# set by #{__FILE__}"
		end
		File.open(SAL_SENTINEL, 'a') do |file| 
			file.puts "#suburbs database updated by #{__FILE__} until: #{options[:until]} at #{options[:currtime]}"
		end
	end
end

LOGFILE.close