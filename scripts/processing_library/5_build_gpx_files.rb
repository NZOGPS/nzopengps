=begin

A library that outputs gpx files
and prints the command to be used for running gdb conversion with GPSbabel http://www.gpsbabel.org/

=end
WORKING_SRID = 4167
require 'cgi'
begin
  require 'progressbar'
rescue LoadError
  puts "Gem missing. Please run: gem install progressbar\n" 
  exit
end

begin
  require 'pg'
rescue LoadError
  puts "Gem missing. Please run: gem install pg\n" 
  exit
end

def load_config

  require 'yaml'
  config_path = "config.yml"
  if File.exist?(config_path)
    raw_config = File.read(config_path)
    @app_config = YAML.load(raw_config)
  else
    print "#{config_path} missing.\n"
    exit
  end
  
  if @app_config['gpsbabel']['execute_inline'] == true then
    @gpsbabel_path = @app_config['gpsbabel']['path']
    if @gpsbabel_path.empty? then
      print "GPSbabel path not found in #{config_path}.\n"
    elsif !File.exist?(@gpsbabel_path) then
      print "GPSbabel not found at provided path #{@gpsbabel_path}.\n"
    else
      @do_compile = true
      print "Do inline gdb compilation? Yes. Using: #{@gpsbabel_path}\n"
    end
  else
    print "Do inline gdb compilation? No.\n"
  end

end

def process_polish_buffer(buffer)
end

def pre_processing()

  load_config()

  top,right,bottom,left = @bounds
  sql_query = "SELECT address, to_char(st_x(the_geom),'9999D999999'), to_char(st_y(the_geom),'9999D999999'), rna_id FROM \"nz-street-address-elector\" WHERE ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(#{left}, #{bottom}), ST_Point(#{right} ,#{top})),#{WORKING_SRID}), the_geom);"
  require '..\linzdataservice\nzogps_library.rb'
  
  begin
  @conn = PGconn.connect("localhost", 5432, "", "", "nzopengps", "postgres", @app_config['postgres']['password'])
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
  
  @output_file_path = File.join(@base, 'outputs', "#{@tile}-numbers.gpx") #put outputs in outputs folder

  File.open(@output_file_path, "w") do |f|
    f.print <<-eos
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="Zenbu - http://www.zenbu.co.nz" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
    eos
    
    print "Running database query...\n"
    res  = @conn.exec(sql_query)
    print "Creating #{@output_file_path}\n"
    @pbar = ProgressBar.new("Progress", res.num_tuples) 

    res.values.each{|row|
      @pbar.inc
      address = doContractions(row[0]).gsub(/\w+/) do |word|
        word.capitalize
      end

      lon = row[1].strip
      lat = row[2].strip
      linzid = row[3]
      f.print <<-eos
<wpt lat="#{lat}" lon="#{lon}">
<name>#{CGI::escapeHTML(address)}</name>
<desc>#{linzid}</desc>
</wpt>
      eos
    }
    f.print <<-eos
</gpx>
    eos

  end
  
  print "Finish Database query = #{Time.now}\n"
  @reporting_file.print "Finish Database query = #{Time.now}\n"

  if @do_compile then
    print "\nCompile to gdb with\n"
    gdb_path = File.join(File.dirname(@output_file_path),File.basename(@output_file_path, '.gpx'))
    gpsbabel_exec_command = "\"#{@gpsbabel_path}\" -i gpx -o gdb -f \"#{@output_file_path}\" -F \"#{gdb_path}.gdb\""
    
    print "#{gpsbabel_exec_command}\nCompiling...\n"
    system(gpsbabel_exec_command)
  end
  
  exit
end

def post_processing()
end