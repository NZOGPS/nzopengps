require 'optparse'
require 'optparse/time'
require 'optparse/date'

LINZ_URL="https://data.linz.govt.nz/services;"
FN_779="layer_779_cs"
FN_818="layer_818_cs"
FN_793="layer_793_cs"

ADDR_TABLE="\"nz-street-address-electoral-2016-07-16\""
ROAD_TABLE="\"nz-road-centre-line-electoral-2016-07-16\""

options = {:download => 1, :postgres => 1, :updates => 1, :from => "2016-07-17T12:00:00", :until => nil}

def do_options(options)
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

		opts.on("-f", "--from FROM", DateTime, "Specify a start time/date") do |from|
			p from
			options[:from] = from.strftime("%FT%T")
		end

		opts.on("-t", "--to TOTIME", DateTime, "Specify an until time/date") do |to|
			options[:until] = to.strftime("%FT%T")
		end

		opts.on('-h', '--help', 'Displays Help') do
			puts opts
			exit
		end
	end

	parser.parse!
end

def get_linz_updates(options)
	#need to check these for validity

	linz_key = ENV['nzogps_linz_api_key']
	curl_cmd = ENV['nzogps_curl']
	abort("Processing aborted! nzogps_linz_api_key or nzogps_curl environment variable not set!") if !linz_key || !curl_cmd

	#curl_cmd = "echo #{curl_cmd}"

	#from_date = "2016-07-17T12:00:00"

	if (options[:until])
		to_date = options[:until]
	else
		nztime = Time.new
		to_date = nztime.utc.strftime("%FT%T")
	end

	url1 = "#{LINZ_URL}key=#{linz_key}/wfs/layer-"
	url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames=layer-"
	url3 = "-changeset^&viewparams=from:#{options[:from]}Z;to:#{to_date}Z^&outputFormat=csv"
	puts url3

	#need to add checks for valid return?
	layer = 779
	system("#{curl_cmd} -o #{FN_779}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 818
	system("#{curl_cmd} -o #{FN_818}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 793
	system("#{curl_cmd} -o #{FN_793}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
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

	#check that csvt files with column types exist
	abort("Processing aborted! csv definition file #{FN_779}.csvt not found!") if !File.file?("#{FN_779}.csvt")
	abort("Processing aborted! csv definition file #{FN_818}.csvt not found!") if !File.file?("#{FN_818}.csvt")
	abort("Processing aborted! csv definition file #{FN_793}.csvt not found!") if !File.file?("#{FN_793}.csvt")

	#use ogr to import csv files into postgres
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\"  #{FN_779}.csv")
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\"  #{FN_818}.csv")
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\"  #{FN_793}.csv")

	#do postprocessing of addresses in postgres
	@conn.exec "ALTER TABLE #{FN_779} ADD COLUMN is_odd boolean"
	@conn.exec "UPDATE #{FN_779} SET is_odd = MOD(range_low,2) = 1"
	@conn.exec "SELECT AddGeometryColumn('','#{FN_779}','the_geom',4167,'POINT',2)"
	@conn.exec "UPDATE #{FN_779} SET the_geom = ST_FlipCoordinates(ST_GeomFromText(shape,4167))" #older versions of ogr don't convert WKT, also coord order is reversed
	@conn.exec "VACUUM ANALYSE #{FN_779}"

	#do postprocessing of road centrelines in postgres
	@conn.exec "SELECT AddGeometryColumn('','#{FN_818}','the_geom',4167,'MultiLineString',2)"
	@conn.exec "UPDATE #{FN_818} SET the_geom = ST_FlipCoordinates(ST_GeomFromText(shape,4167))" #older versions of ogr don't convert WKT, also coord order is reversed
	@conn.exec "VACUUM ANALYSE #{FN_818}"

	#do postprocessing of road centrelines sections in postgres
	@conn.exec "SELECT AddGeometryColumn('','#{FN_793}','the_geom',4167,'LineString',2)"
	@conn.exec "UPDATE #{FN_793} SET the_geom = ST_FlipCoordinates(ST_GeomFromText(shape,4167))" #older versions of ogr don't convert WKT, also coord order is reversed
	@conn.exec "VACUUM ANALYSE #{FN_793}"

	#just export 793 for now
	system("del #{FN_793}.gpx")
	system("#{ogr_cmd} -overwrite -f GPX #{FN_793}.gpx \"PG:user=postgres dbname=nzopengps tables=#{FN_793}\"")

end

def check_for_errors()
	rs = @conn.exec "SELECT sae.gid, cs.id, cs.address, cs.__change__ "\
	"from #{FN_779} cs join #{ADDR_TABLE} sae on sae.id = cs.id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in address updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['address']
		abort("Processing aborted")
	end

	rs = @conn.exec "SELECT cs.id, cs.address, cs.__change__ from #{FN_779} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select id from #{ADDR_TABLE} sae where sae.id = cs.id)"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in address updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['address']
		abort("Processing aborted")
	end

	rs = @conn.exec "SELECT cs.id, cs.name, cs.__change__ "\
	"from #{FN_818} cs join #{ROAD_TABLE} rcl on rcl.id = cs.id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in road updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['name']
		abort("Processing aborted")
	end

	rs = @conn.exec "SELECT cs.id, cs.name, cs.__change__ from #{FN_818} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select id from #{ROAD_TABLE} rcl where rcl.id = cs.id)"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in road updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['name']
		abort("Processing aborted")
	end

end

def do_updates()
	@conn.exec "DELETE FROM #{ADDR_TABLE} sae USING #{FN_779} cs WHERE sae.id = cs.id AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ADDR_TABLE} "\
		"(id,rna_id,rcl_id,address,house_numb,range_low,range_high,is_odd,road_name,locality,territoria,road_name_,address_ut,locality_u,the_geom)"\
		"SELECT id,rna_id,rcl_id,address,house_number,range_low,range_high,is_odd,road_name,locality,territorial_authority,road_name_utf8,address_utf8,locality_utf8,the_geom "\
		"FROM #{FN_779} where __change__ = 'INSERT'"

	@conn.exec "UPDATE #{ADDR_TABLE} sae "\
		"SET rna_id=subquery.rna_id, rcl_id=subquery.rcl_id, address=subquery.address, house_numb=subquery.house_number,"\
			"range_low=subquery.range_low, range_high=subquery.range_high,is_odd=subquery.is_odd,"\
			"road_name=subquery.road_name, locality=subquery.locality, territoria=subquery.territorial_authority,"\
			"road_name_=subquery.road_name_utf8, address_ut=subquery.address_utf8, locality_u=subquery.locality_utf8, the_geom=subquery.the_geom "\
		"FROM (SELECT id,rna_id,rcl_id,address,house_number,range_low,range_high,is_odd,road_name,locality,territorial_authority,road_name_utf8,address_utf8,locality_utf8,the_geom "\
		"FROM #{FN_779} where __change__ = 'UPDATE') AS subquery WHERE sae.id=subquery.id"

	@conn.exec "DELETE FROM #{ROAD_TABLE} rcl USING #{FN_818} cs WHERE rcl.id = cs.id AND cs.__change__ = 'DELETE'"

	@conn.exec "INSERT INTO #{ROAD_TABLE} "\
		"(id,name,locality,territoria,name_utf8,locality_u,the_geom)"\
		"SELECT id,name,locality,territorial_authority,name_utf8,locality_utf8,the_geom "\
		"FROM #{FN_818} where __change__ = 'INSERT'"

	@conn.exec "UPDATE #{ROAD_TABLE} rcl "\
		"SET id=subquery.id, name=subquery.name, locality=subquery.locality, territoria=subquery.territorial_authority, "\
			"name_utf8=subquery.name_utf8, locality_u=subquery.locality_utf8, the_geom=subquery.the_geom "\
		"FROM (SELECT id,name,locality,territorial_authority,name_utf8,locality_utf8,the_geom "\
		"FROM #{FN_818} where __change__ = 'UPDATE') AS subquery WHERE rcl.id=subquery.id"

end
do_options(options)

if (options[:download]) 
	get_linz_updates(options)
end

pg_connect()

if (options[:postgres]) 
	put_csv_in_postgres()
	check_for_errors()
end

if (options[:updates]) 
	do_updates()
end
