=begin

A library that outputs csv files from the LINZ address database. (Probably better to use 5.rb)

=end
WORKING_SRID = 4167
require 'csv'

def process_polish_buffer(buffer)
end

def pre_processing()

  top,right,bottom,left = @bounds
  sql_query = "SELECT * FROM \"nz-street-address-elector\" WHERE ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(#{left}, #{bottom}), ST_Point(#{right} ,#{top})),#{WORKING_SRID}), the_geom);"
  require 'pg'
  require 'yaml'
  
  raw_config = File.read("config.yml")
  app_config = YAML.load(raw_config)
  
  begin
  @conn = PGconn.connect("localhost", 5432, "", "", "nzopengps", "postgres", app_config['postgres']['password'])
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
  
  @output_file_path = File.join(@base, 'outputs', "#{@tile} number.csv") #put outputs in outputs folder
  print "Output : #{@output_file_path}\n"
  CSV.open(@output_file_path, "w") do |csv|
    res  = @conn.exec(sql_query)

    csv << res.fields
    res.values.each{|row|
      csv << row
    }

  end
  
  exit
end

def post_processing()
end