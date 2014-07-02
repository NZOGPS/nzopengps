=begin

A library that outputs csv files from the LINZ address database. 
Put this file in your numbers directory, where the number checker will use it for finding missing numbering.

=end
WORKING_SRID = 4167
require 'csv'

def process_polish_buffer(buffer)
end

def pre_processing()

  top,right,bottom,left = @bounds
  sql_query = "SELECT  DISTINCT ON (rna_id, range_low) range_low, road_name, to_char(st_x(the_geom),'9999D999999'), to_char(st_y(the_geom),'9999D999999'), rna_id FROM \"nz-street-address-electoral\" WHERE ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(#{left}, #{bottom}), ST_Point(#{right} ,#{top})),#{WORKING_SRID}), the_geom);"
  sql_high_query = sql_query.gsub("range_low","range_high");
  sql_high_query = sql_high_query.gsub("WHERE ST_Contains","WHERE range_high is not null and range_high <> range_low and ST_Contains");
  require 'pg'
  require 'yaml'
  
  raw_config = File.read("config.yml")
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
  
  @output_file_path = File.join(@base, 'outputs', "#{@tile}-numbers-linzid.csv") #put outputs in outputs folder
  print "Output : #{@output_file_path}\n"
  CSV.open(@output_file_path, "w") do |csv|
    res  = @conn.exec(sql_query)
    i = 0
    csv << ["No","Latitude","Longitude","Name","Description","Symbol"]
    res.values.each{|row|
      i += 1
      next if row[0] == nil
      csv << [i, row[3].strip, row[2].strip, (row[0]+" "+row[1]), row[4], "Waypoint"]
    }
    # run extra query for range_high data
    res  = @conn.exec(sql_high_query)
    res.values.each{|row|
      i += 1
      next if row[0] == nil
      csv << [i, row[3].strip, row[2].strip, (row[0]+" "+row[1]), row[4], "Waypoint"]
    }
  print "Finish  = #{Time.now}\n"
  @reporting_file.print "Finish  = #{Time.now}\n"

  end
  
  exit
end

def post_processing()
end