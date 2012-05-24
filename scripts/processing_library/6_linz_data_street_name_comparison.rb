=begin

read the LINZ Data Service output tile and the NZOGPS tile and report on the difference in street names

expects that the LinzDataService data has been processed already to form the -LINZ.mp tiles
=end

require '..\linzdataservice\nzogps_library.rb'

def process_polish_buffer(buffer)
  linzid, street_name, street_name_2, first_lat, first_lon  = nil
  
	buffer.each{|line|
    if line =~ /;linzid\=(\d*)/ then
      linzid = $1
    elsif line =~ /Label\=(.*)/ then
      street_name = $1
    elsif line =~ /Label2\=(.*)/ then
      street_name_2 = $1
    elsif line =~ /Data0\=\(([-.\d]+),([-.\d]+)\).*/ then
      first_lat = $1
      first_lon = $2
    end
	}
  
  if !@linz_street_names_by_linzid.has_key?(linzid) then
    return
  end
  
  official_street_name = @linz_street_names_by_linzid[linzid]
  match = false
  
  #standardise whitespace and case
  official_street_name = official_street_name.squeeze(' ').strip.upcase
  street_name = "#{street_name}".squeeze(' ').strip.upcase
  street_name_2 = "#{street_name_2}".squeeze(' ').strip.upcase
  
  if (official_street_name == street_name)||(official_street_name == doContractions(street_name)) then
    match = true
  elsif (official_street_name == street_name_2)||(official_street_name == doContractions(street_name_2)) then
    match = true
  elsif street_name =~ /~\[0x2d\](.+)/i || street_name_2 =~ /~\[0x2d\](.+)/i then
    highway_number = $1
    if official_street_name =~ /STATE HIGHWAY #{highway_number}/ then
      match = true
    end
  end
	if !match then
		if @acceptables[official_street_name] then
			@acceptables[official_street_name].each{|alternate|
				if street_name == alternate then
					match = true
					break
				end
				if street_name_2 == alternate then
					match = true
					break
				end
			}
		end
  end
  
  if !match then 
    print "#{linzid}\t#{street_name}\t#{street_name_2}\t#{official_street_name}\t#{first_lat},#{first_lon}\n"
    @reporting_file.print "#{linzid}\t#{street_name}\t#{street_name_2}\t#{official_street_name}\t#{first_lat},#{first_lon}\n"
  end
  
end

def pre_processing()
  
  @linz_street_names_by_linzid = {}
  linz_data_service_file = File.join(@base, '..', 'LinzDataService', 'outputslinz', "#{@tile}-LINZ.mp")
  if !File.exists?(linz_data_service_file) then
    raise "Unable to find required LINZ data file at #{linz_data_service_file}\n"
  end
  
  linzid, street_name = nil
  File.open(linz_data_service_file).each{|line|
    if line =~ /;linzid\=(\d+)/ then
      linzid = $1
    elsif line =~ /Label\=(.*)/ then
      street_name = $1
    end
    
    if (line =~ /^\[END(.*)/) then
      if linzid && street_name then
        @linz_street_names_by_linzid[linzid] = street_name
      end
      linzid, street_name = nil
    end
  }
  print "#{@linz_street_names_by_linzid.size} distinct linz ids found in #{linz_data_service_file}\n"
  
	alternates_file = 'acceptable.names'
	@acceptables = Hash.new
	if File.exists?(alternates_file) then
		File.open(alternates_file).each{|line|
			if line =~ /(.+),(.*)/ then
				(@acceptables[$1] ||=[]) << $2
			end
		}
	end

	print "linzid\tstreet_name\tstreet_name_2\tofficial_street_name\n"
	@reporting_file.print "linzid\tstreet_name\tstreet_name_2\tofficial_street_name\n"
end

def post_processing()
  
  @reporting_file.print "#############################\n\n"
  
end