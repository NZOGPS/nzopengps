=begin

A library that outputs csv files from the LINZ address database. 
Put this file in your numbers directory, where the number checker will use it for finding missing numbering.

=end
WORKING_SRID = 4167

begin
  require 'csv'
rescue LoadError
  puts "Gem missing. Please run: gem install csv\n" 
  exit
end


def process_polish_buffer(buffer)
end

def pre_processing()

  top,right,bottom,left = @bounds
  sql_query = "SELECT  DISTINCT ON (rna_id, linz_numb_id, address_number) address_number, full_road_name_ascii, to_char(shape_x,'9999D999999'), to_char(shape_y,'9999D999999'), rna_id, linz_numb_id FROM nz_addresses WHERE rna_id is not null and ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(#{left}, #{bottom}), ST_Point(#{right} ,#{top})),#{WORKING_SRID}), wkb_geometry);"
  sql_high_query = sql_query.gsub("address_number","address_number_high");
  sql_high_query = sql_high_query.gsub("and ST_Contains","and address_number_high is not null and address_number_high <> 0 and address_number_high <> address_number and ST_Contains");

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
    csv << ["No","Latitude","Longitude","Name","Description","Symbol","LNID"]
    res.values.each{|row|
      i += 1
      next if row[0] == nil
      csv << [i, row[3].strip, row[2].strip, (row[0]+" "+row[1]), row[4], "Waypoint", row[5]?row[5]:0]
    }
    # run extra query for range_high data
#	print "Hi Qry: #{sql_high_query}\n"
    res  = @conn.exec(sql_high_query)
    res.values.each{|row|
      i += 1
      next if row[0] == nil
      csv << [i, row[3].strip, row[2].strip, (row[0]+" "+row[1]), row[4], "Waypoint", row[5]?row[5]:0]
    }
  print "Finish  = #{Time.now}\n"
  @reporting_file.print "Finish  = #{Time.now}\n"

  end
  
  exit
end

def post_processing()
end