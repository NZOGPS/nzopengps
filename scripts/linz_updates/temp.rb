LINZ_URL="https://data.linz.govt.nz/services;"
FN_779="layer_779_cs"
ADDR_TABLE="\"nz-street-address-electoral-2016-07-16\""

def get_linz_updates()
	#need to check these for validity

	linz_key = ENV['nzogps_linz_api_key']
	curl_cmd = ENV['nzogps_curl']
	abort("Processing aborted! nzogps_linz_api_key or nzogps_curl environment variable not set!") if !linz_key || !curl_cmd

	#curl_cmd = "echo #{curl_cmd}"

	from_date = "2016-07-17T12:00:00"
	#to_date = "2016-08-13T02:06:09.394426"

	nztime = Time.new
	to_date = nztime.utc.strftime("%FT%T")

	url1 = "#{LINZ_URL}key=#{linz_key}/wfs/layer-"
	url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames=layer-"
	url3 = "-changeset^&viewparams=from:#{from_date}Z;to:#{to_date}Z^&outputFormat=csv"

	#need to add checks for valid return?
	layer = 779
	system("#{curl_cmd} -o #{FN_779}.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 818
	#system("#{curl_cmd} -o layer-#{layer}-cs.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 793
	#system("#{curl_cmd} -o layer-#{layer}-cs.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
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
	ogr_cmd = ENV['nzogps_ogr2ogr']
	abort("Processing aborted! nzogps_ogr2ogrl environment variable not set!") if !ogr_cmd
	abort("Processing aborted! csv definition file #{FN_779}.csvt not found!") if !File.file?("#{FN_779}.csvt")
	
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -overwrite -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\"  #{FN_779}.csv")

	@conn.exec "ALTER TABLE #{FN_779} ADD COLUMN is_odd boolean"
	@conn.exec "SELECT AddGeometryColumn('','#{FN_779}','the_geom',4167,'POINT',2)"
	@conn.exec "UPDATE #{FN_779} SET is_odd = MOD(range_low,2) = 1"
	@conn.exec "UPDATE #{FN_779} SET the_geom = ST_FlipCoordinates(ST_GeomFromText(shape,4167))" #ogr doesn't convert WKT, and also coord order is reversed
end

def check_for_errors()
	rs = @conn.exec "SELECT sae.gid, cs.id, cs.address, cs.__change__ "\
	"from #{FN_779} cs join #{ADDR_TABLE} sae on sae.id = cs.id where cs.__change__ = 'INSERT'"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in updates for addition already exists in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['address']
		abort("Processing aborted")
	end

	rs = @conn.exec "SELECT cs.id, cs.address, cs.__change__ from #{FN_779} cs "\
		"where cs.__change__ in ('UPDATE','DELETE') and not exists( select id from #{ADDR_TABLE} sae where sae.id = cs.id)"
	if rs.count > 0 then
		STDERR.puts rs.count.to_s + " ID(s) in updates for modification/deletion do not already exist in database"
		STDERR.puts "\tFirst ID: " + rs.first['id'] + " - " + rs.first['address']
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
		"FROM layer_779_cs ) AS subquery WHERE sae.id=subquery.id"
end

get_linz_updates()
pg_connect()
put_csv_in_postgres()
check_for_errors()
do_updates()

