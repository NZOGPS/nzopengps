=begin

read the LINZ Data Service output tile and the NZOGPS tile and report on the difference

=end

def process_polish_buffer(buffer)
	linzid, linzid2, linzid3, numbid, street_name, label2, label3, first_lat, first_lon = nil

	buffer.each {|line|
		if line =~ /;linzid\=(\d+)/ then
			linzid = $1
		elsif line =~ /;linzid2\=(\d+)/ then
			linzid2 = $1
		elsif line =~ /;linzid3\=(\d+)/ then
			linzid3 = $1
		elsif line =~ /Label\=(.*)/ then
			street_name = $1
		elsif line =~ /Label2\=(.*)/ then
			label2 = $1
		elsif line =~ /Label3\=(.*)/ then
			label3 = $1
		elsif line =~ /;linznumbid\=(\d+)/ then
			numbid = $1
			#print "LNI found: #{line}\n"
		elsif line =~ /Data0\=\(([-.\d]+),([-.\d]+)\).*/ then
			first_lat = $1
			first_lon = $2
		end
	}

	if linzid then
		@nzogps_file_ids[linzid] = "#{street_name}\t#{first_lat},#{first_lon}"
	end
	if linzid2 then
		@nzogps_file_ids[linzid2] = "#{label2}\t#{first_lat},#{first_lon}"
	end
	if linzid3 then
		@nzogps_file_ids[linzid3] = "#{label3}\t#{first_lat},#{first_lon}"
	end
	if numbid then
		@nzogps_file_num_ids[numbid] = "#{street_name}\t#{first_lat},#{first_lon}"
		@nzogps_file_num_id_ids[numbid] = "#{linzid}"
	end

end

def pre_processing()

	@nzogps_file_ids = {}
	@linz_file_ids = {}
	@nzogps_file_num_ids = {}
	@linz_file_num_ids = {}
	@nzogps_file_num_id_ids = {}
	@linz_file_num_id_ids = {}

	linz_data_service_file = File.join(@base, '..', 'LinzDataService', 'outputslinz', "#{@tile}-LINZ.mp")
	if !File.exists?(linz_data_service_file) then
		raise "Unable to find required LINZ data file at #{linz_data_service_file}\n"
	end

	linzid, numbid, street_name, first_lat, first_lon = nil
	File.open(linz_data_service_file).each{|line|
		if line =~ /;linzid\=(\d+)/ then
			linzid = $1
		elsif line =~ /;linznumbid\=(\d+)/ then
			numbid = $1
			#print "LNI found: #{numbid} in #{line}"
		elsif line =~ /Label\=(.*)/ then
			street_name = $1
		elsif line =~ /Data0\=\(([-.\d]+),([-.\d]+)\).*/ then
			first_lat = $1
			first_lon = $2
		end

		if (line =~ /^\[END(.*)/) then
			if linzid && street_name then
				@linz_file_ids[linzid] = "#{street_name}\t#{first_lat},#{first_lon}"
				#print "set linzid #{linzid} - #{numbid} - #{street_name}\n"
			end
			if numbid && street_name then
				@linz_file_num_ids[numbid] = "#{street_name}\t#{first_lat},#{first_lon}"
				@linz_file_num_id_ids[numbid] = "#{linzid}"
				#print "set numbid #{numbid} - #{street_name} - #{linzid}\n"
			end
			linzid, numbid, street_name = nil
		end
	}
	print "#{@linz_file_ids.size} distinct linz ids, #{@linz_file_num_ids.size} number range ids found in #{linz_data_service_file}\n"

	@paper_road_ids = {}

	paper_roads_file = File.join(@base, '..', 'LinzDataService', 'PaperRoads', "#{@tile}.txt")
	File.open(paper_roads_file).each{|line|
		linzid = line.split("\t")[0]
		@paper_road_ids[linzid] = true
	}
	print "#{@paper_road_ids.size} distinct ids found in #{paper_roads_file}\n"

	@extra_road_ids = {}
	extra_roads_file = File.join(@base, '..', 'LinzDataService', 'PaperRoads', "#{@tile}-extras.txt")
	if File.file?(extra_roads_file) then
		File.open(extra_roads_file).each {|line|
			linzid = line.split("\t")[0]
			@extra_road_ids[linzid] = true
		}
		print "#{@extra_road_ids.size} distinct ids found in #{extra_roads_file}\n"
	end
	@extra_road_ids["0"] = true		# linzid=0 are 'our' roads

	#not sure yet if we need paper num ids
	@paper_numb_ids = {}

end

def post_processing()

#linzids
	@reporting_file.print "#############################\n\n"

	in_linz_but_missing_from_nzogps = @linz_file_ids.keys - @nzogps_file_ids.keys - @paper_road_ids.keys
	print "#{in_linz_but_missing_from_nzogps.size} LINZ ids are missing from NZOGPS #{@tile}\n"
	@reporting_file.print "#{in_linz_but_missing_from_nzogps.size} LINZ ids are missing from NZOGPS #{@tile}\n"

	in_linz_but_missing_from_nzogps.each{|x|
		@reporting_file.print ";linzid=#{x}\t#{@linz_file_ids[x]}\n"
	}

	@reporting_file.print "#############################\n\n"

	in_nzogps_but_missing_from_linz = @nzogps_file_ids.keys - @linz_file_ids.keys - @extra_road_ids.keys
	print "#{in_nzogps_but_missing_from_linz.size} LINZ ids are in NZOGPS #{@tile} but missing from LINZ\n"
	@reporting_file.print "#{in_nzogps_but_missing_from_linz.size} LINZ ids are in NZOGPS #{@tile} but missing from LINZ\n"

	in_nzogps_but_missing_from_linz.each{|x|
		@reporting_file.print ";linzid=#{x}\t#{@nzogps_file_ids[x]}\n"
	}

#numbering ids
	@reporting_file.print "#############################\n\n"

	numbid_in_linz_but_missing_from_nzogps = @linz_file_num_ids.keys - @nzogps_file_num_ids.keys - @paper_numb_ids.keys
	print "#{numbid_in_linz_but_missing_from_nzogps.size} Number range ids are missing from NZOGPS #{@tile}\n"
	@reporting_file.print "#{numbid_in_linz_but_missing_from_nzogps.size} Number range ids are missing from NZOGPS #{@tile}\n"

	numbid_in_linz_but_missing_from_nzogps.each{|x|
		@reporting_file.print ";linznumbid=#{x}\t#{@linz_file_num_ids[x]}\n"
	}

	@reporting_file.print "#############################\n\n"

	numbid_in_nzogps_but_missing_from_linz = @nzogps_file_num_ids.keys - @linz_file_num_ids.keys
	print "#{numbid_in_nzogps_but_missing_from_linz.size} Number range ids are in NZOGPS #{@tile} but missing from LINZ\n"
	@reporting_file.print "#{numbid_in_nzogps_but_missing_from_linz.size} Number range ids are in NZOGPS #{@tile} but missing from LINZ\n"

	numbid_in_nzogps_but_missing_from_linz.each{|x|
		@reporting_file.print ";linznumbid=#{x}\t#{@nzogps_file_num_ids[x]}\n"
	}

	@reporting_file.print "#############################\n\n"

	errcnt = 0
	@nzogps_file_num_ids.keys.each{|x|
		unless @nzogps_file_num_id_ids[x].nil? || @linz_file_num_id_ids[x].nil? || @nzogps_file_num_id_ids[x] == @linz_file_num_id_ids[x]
			@reporting_file.print ";linznumbid=#{x} has inconsistent LINZ Ids! nzogps: #{@nzogps_file_num_id_ids[x]} linz: #{@linz_file_num_id_ids[x]}\t#{@nzogps_file_num_ids[x]}\n"
			errcnt += 1
		end
	}

	if errcnt > 0 then
		print "#{errcnt} numbering ID(s) with inconsistent LINZ IDs\n"
		@reporting_file.print "#############################\n\n"
	end
	
	print "See #{@reporting_file_path} for full results\n"
end