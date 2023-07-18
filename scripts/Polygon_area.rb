=begin

A program to read Polish polygons, and re-type them based on area
I use postgres calls to calculate the area

=end

WORKING_SRID = 4167
NZTM_SRID = 2193
QRY_START = 'SELECT ST_Area(ST_Transform(ST_Flipcoordinates(ST_GeomFromText(\'POLYGON('
#require 'cgi'
#begin
# require 'progressbar'
#rescue LoadError
#  puts "Gem missing. Please run: gem install progressbar\n" 
#  exit
#end

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
  
end


def initialise()

  load_config()
  
  begin
  @conn = PG.connect(@app_config['postgres']['host'], 5432, "", "", "nzopengps", "postgres", @app_config['postgres']['password'])
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

def doit()

	File.open(@output_file_path, "w") do |f|
		res  = @conn.exec(sql_query)

		res.values.each{|row|
			@pbar.increment
			address = "#{row[0]} #{doContractions(row[1])}, #{row[2]}"

			lon = row[3].strip
			lat = row[4].strip
		}
	end
end

def do_poly()
	lakes = {
		0x3c => [3,1.0,"Large Lake"],
		0x3e => [2,0.2,"Medium Lake"],
		0x40 => [1,0.0,"Small Lake"]
	}

	type = ""
	label = ""
	endlevel = ""
	startlevel = ""
	data = ""
	area = ""
	first = true
	extralines = Array.new
	
	@fh.each do |line|
		if matchdata = line.match(/^Type=(.*)/) then
			type = matchdata[1]
		end
		if matchdata = line.match(/^Label=(.*)/) then
			label = matchdata[1]
		end
		if matchdata = line.match(/^EndLevel=(.*)/) then
			endlevel = matchdata[1]
		end
		if matchdata = line.match(/^Data(\d+)=(.*)/) then
			if first then
				startlevel = matchdata[1]
				data = matchdata[2]
				query = data.dup # make a copy, otherwise it will overwrite
				if matchdata = query.match(/\(([\d\.\,\-]+)\)/) then  #need point 1 to close the polygon
					point1 = matchdata[1]
					point1.gsub!(","," ")
				end
				query.gsub!("),(","@")	#change ),( to @ temporarily
				query.gsub!(","," ")	#change , between nos to space
				query.gsub!("@",",")	#change @ back to comma
				query.gsub!(")",",#{point1})")	#add point1 to the end to close the ring
				query = "#{QRY_START}#{query})',#{WORKING_SRID})),#{NZTM_SRID}))"
			#	@ofh.puts "Query is #{query}"
				res  = @conn.exec(query)
				area = res.values[0][0].to_f/1000000;
			#	@ofh.puts "Area is #{area}"
				first = false
			else
				extralines.push(line)
			end
		end
		break if /\[END\]/ =~ line
	end
# 
#	To do: Lakes - S/M/L by area
#	Airstrips - Unnamed -> level1, named -> level2?
#	Rivers?
#
#	Print out summary of used types?
#
	@ofh.puts ";Area = #{area}" if not area == 0
	@ofh.puts "[POLYGON]"
	@ofh.puts "Type=#{type}" if not type.empty? 
	@ofh.puts "Label=#{label}"if not label.empty?
	@ofh.puts "EndLevel=#{endlevel}"if not endlevel.empty?
	@ofh.puts "Data#{startlevel}=#{data}"if not data.empty?
	extralines.each do |line|
		@ofh.puts line
	end
	@ofh.puts "[END]"
end

if ARGV.length != 1
	puts "Usage: #{$0} filename"
	exit;
end

filename = ARGV[0]
puts "Processing #{filename}"
@fh = open filename
ofn = File.basename(filename,'.mp') + '_pp.mp'
puts "Output to #{ofn}"
@ofh = open ofn, "w"
initialise;

@fh.each do |line|
	if /\[POLYGON\]/ =~ line then
		do_poly()
	else
		@ofh.puts line
	end
end

@fh.close
@ofh.close
