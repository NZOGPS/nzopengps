=begin

read the LINZ Data Service output tile and the NZOGPS tile and report on the difference

=end

def process_polish_buffer(buffer)
  linzid, street_name, first_lat, first_lon = nil
  
	buffer.each{|line|
    if line =~ /;linzid\=(\d*)/ then
      linzid = $1
    elsif line =~ /Label\=(.*)/ then
      street_name = $1
    elsif line =~ /Data0\=\(([-.\d]+),([-.\d]+)\).*/ then
      first_lat = $1
      first_lon = $2
    end
	}
  
  if linzid then
    @nzogps_file_ids[linzid] = "#{street_name}\t#{first_lat},#{first_lon}"
  end
  
end

def pre_processing()
  
  @nzogps_file_ids = {}
  @linz_file_ids = {}
  linz_data_service_file = File.join(@base, '..', 'LinzDataService', 'outputslinz', "#{@tile}-LINZ.mp")
  if !File.exists?(linz_data_service_file) then
    raise "Unable to find required LINZ data file at #{linz_data_service_file}\n"
  end
  
  linzid, street_name, first_lat, first_lon = nil
  File.open(linz_data_service_file).each{|line|
    if line =~ /;linzid\=(\d+)/ then
      linzid = $1
    elsif line =~ /Label\=(.*)/ then
      street_name = $1
    elsif line =~ /Data0\=\(([-.\d]+),([-.\d]+)\).*/ then
      first_lat = $1
      first_lon = $2
    end
    
    if (line =~ /^\[END(.*)/) then
      if linzid && street_name then
        @linz_file_ids[linzid] = "#{street_name}\t#{first_lat},#{first_lon}"
      end
      linzid, street_name = nil
    end
  }
  print "#{@linz_file_ids.size} distinct ids found in #{linz_data_service_file}\n"

  @paper_road_ids = {}
  paper_roads_file = File.join(@base, '..', 'LinzDataService', 'PaperRoads', "#{@tile}.txt")
  File.open(paper_roads_file).each{|line|
    linzid = line.split("\t")[0]
    @paper_road_ids[linzid] = true
  }
  print "#{@paper_road_ids.size} distinct ids found in #{paper_roads_file}\n"
  
end

def post_processing()
  
  @reporting_file.print "#############################\n\n"
  
  in_linz_but_missing_from_nzogps = @linz_file_ids.keys - @nzogps_file_ids.keys - @paper_road_ids.keys
  print "#{in_linz_but_missing_from_nzogps.size} LINZ ids are missing from NZOGPS #{@tile}\n"
  @reporting_file.print "#{in_linz_but_missing_from_nzogps.size} LINZ ids are missing from NZOGPS #{@tile}\n"
  
  in_linz_but_missing_from_nzogps.each{|x|
    @reporting_file.print ";linzid=#{x}\t#{@linz_file_ids[x]}\n"
  }
  
  @reporting_file.print "#############################\n\n"
  
  in_nzogps_but_missing_from_linz = @nzogps_file_ids.keys - @linz_file_ids.keys - @paper_road_ids.keys
  print "#{in_nzogps_but_missing_from_linz.size} LINZ ids are in NZOGPS #{@tile} but missing from LINZ\n"
  @reporting_file.print "#{in_nzogps_but_missing_from_linz.size} LINZ ids are in NZOGPS #{@tile} but missing from LINZ\n"
  
  in_nzogps_but_missing_from_linz.each{|x|
    @reporting_file.print ";linzid=#{x}\t#{@nzogps_file_ids[x]}\n"
  }
  
  @reporting_file.print "#############################\n\n"
  
  print "See #{@reporting_file_path} for full results\n"
end