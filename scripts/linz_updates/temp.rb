
def get_linz_updates()
	linz_url="https://data.linz.govt.nz/services;"
	#need to check these for validity

	linz_key = ENV['nzogps_linz_api_key']
	curl_cmd = ENV['nzogps_curl']
	abort("Processing aborted! nzogps_linz_api_key or nzogps_curl environment variable not set!") if !linz_key || !curl_cmd

	#curl_cmd = "echo #{curl_cmd}"

	from_date = "2016-07-30T02:06:14.066745"
	to_date = "2016-08-13T02:06:09.394426"

	nztime = Time.new
	to_date = nztime.utc.strftime("%FT%T")

	url1 = "#{linz_url}key=#{linz_key}/wfs/layer-"
	url2 = "-changeset?SERVICE=WFS^&VERSION=2.0.0^&REQUEST=GetFeature^&typeNames=layer-"
	url3 = "-changeset^&viewparams=from:#{from_date}Z;to:#{to_date}Z^&outputFormat=csv"

	#need to add checks for valid return
	layer = 779
	system("#{curl_cmd} -o layer-#{layer}-cs.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 818
	#system("#{curl_cmd} -o layer-#{layer}-cs.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
	layer = 793
	#system("#{curl_cmd} -o layer-#{layer}-cs.csv #{url1}#{layer}#{url2}#{layer}#{url3}")
end

def put_csv_in_postgres()
	ogr_cmd = ENV['nzogps_ogr2ogr']
	abort("Processing aborted! nzogps_ogr2ogrl environment variable not set!") if !ogr_cmd
	
	#need to add checks for valid return
	system("#{ogr_cmd} --config PG_USE_COPY TRUE -lco OVERWRITE=YES -f \"PostgreSQL\" \"PG:host=localhost user=postgres  dbname=nzopengps\"  layer-779-cs.csv")
	@conn.exec "ALTER TABLE \"layer_779_cs\" ADD COLUMN is_odd boolean"
	@conn.exec "SELECT AddGeometryColumn('','layer_779_cs','the_geom',4167,'POINT',2)"
	#PROBLEM - ogr is creating text fields. I can't remember how to make it make numbers...
#	@conn.exec "UPDATE \"layer_779_cs\" SET is_odd = MOD(range_low,2) = 1"
	@conn.exec "UPDATE \"layer_779_cs\" SET the_geom = ST_FlipCoordinates(ST_GeomFromText(shape,4167))"
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

#get_linz_updates()
pg_connect()
put_csv_in_postgres()
