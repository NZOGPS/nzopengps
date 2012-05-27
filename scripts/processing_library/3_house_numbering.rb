print "processing_library 3 adds house numbering\n"
=begin
This script uses the LINZ Data Service official number shape files to add Polish format numbering to our tiles

Requirements:
Ruby 1.87+, 1.93 recommeneded

Ruby Windows Installation Instructions:
Get the latest installer from http://rubyinstaller.org/downloads/
You will also need the DEVELOPMENT KIT on that page. Instructions for devkit install here
https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
(These instructions could do with expansion...)

Postgres >=8.4
http://www.postgresql.org/
Postgis (installed using PostgreSQL StackBuilder which comes with Postgres)
http://postgis.refractions.net/

Rubygems
These are libraries that we must install to run this script. Run the following from command line.
gem install pg
gem install progressbar

Inputs:
The LINZ Data Service exports are available from
NUMBERS
http://data.linz.govt.nz/layer/779-nz-street-address-electoral/
You can also get ROADS although they aren't specifically needed for this step
http://data.linz.govt.nz/layer/818-nz-road-centre-line-electoral/

 -- must export using Map Projection NZGD2000 (EPSG: 4167 Lat/Long) NOT the default option NZGD200 / NZ Transverse Mercator 
These won't be checked into our repository, so each person will need to get it themselves.

###

Open pgAdmin
Edit->New object->New Database
Name: nzopengps
template: template_postgis

Now use the "PostGIS Shapefile and DBF Loader" application to import these shape files
Shapefile: nz-street-address-elector.shp (the one downloaded above)
Username: postgres
Password: #master password entered during install
Database: nzopengps

Test Connection... 
Connection succeeded

Configuration
SRID: 4167
Options -> DBF File Character Encoding -> UTF-8
Destination Table: nz-street-address-elector

Import

######
Open pgAdmin
In the Object Browser -> select Databases / nzopengps
Menu -> Tools -> Query tool
Paste in the following between =====
=====
ALTER TABLE "nz-street-address-elector" ADD COLUMN range_low integer;
ALTER TABLE "nz-street-address-elector" ADD COLUMN is_odd boolean;
--house_numb: 8
UPDATE "nz-street-address-elector" SET range_low = cast(house_numb AS INTEGER) WHERE house_numb ~* E'^\\d+$';
--house_numb: 8A
UPDATE "nz-street-address-elector" SET range_low = cast(substring(house_numb FROM E'^(\\d+)\\w$') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\\w$';
--house_numb: 8-10
UPDATE "nz-street-address-elector" SET range_low = cast(substring(house_numb FROM E'^(\\d+)[A-Z]?\-\\d+[A-Z]?$') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^(\\d+)[A-Z]?\-\\d+[A-Z]?$';
--house_numb: 1A/10
UPDATE "nz-street-address-elector" SET range_low = cast(substring(house_numb FROM E'^\\d+\/(\\d+)\-?') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\/(\\d+)\-?';
--house_numb: 1/10 and 1/10-5/10
UPDATE "nz-street-address-elector" SET range_low = cast(substring(house_numb FROM E'^\\d+\/(\\d+)\-?') AS INTEGER) WHERE range_low IS NULL AND house_numb ~* E'^\\d+\/(\\d+)\-?';
--set is_odd
UPDATE "nz-street-address-elector" SET is_odd = MOD(range_low,2) = 1;

--now add indexes for speed
CREATE INDEX idx_rna_id ON "nz-street-address-elector" USING btree (rna_id);
CREATE INDEX idx_rna_id_is_odd ON "nz-street-address-elector" USING btree (rna_id,is_odd);
=====
Menu -> Query -> Execute

This is updating 1.6 million records, it will take some time...

######
copy config.yml.sample to config.yml and put your Postgres password in there

#####
now run this.
e.g for Northland
ruby parseMP.rb 1 3

=end
require 'progressbar'

# CONFIGURABLE VARIABLES
STRIP_PREVIOUS_NUMBERING = false; print "STRIP_PREVIOUS_NUMBERING=#{STRIP_PREVIOUS_NUMBERING}\n"
ONLY_ADD_NUMBERING_TO_SECTIONS_WITHOUT_ANY = true; print "ONLY_ADD_NUMBERING_TO_SECTIONS_WITHOUT_ANY=#{ONLY_ADD_NUMBERING_TO_SECTIONS_WITHOUT_ANY}\n"

ALLOWED_ROAD_TYPES_FOR_NUMBERING = ['0x1','0x2','0x3','0x4','0x5','0x6','0x7','0xa']
#AUTONUMBERDATESTRING = Time.now.strftime(";Auto-numbered=%Y%m%d")

###############
WORKING_SRID = 4167
#K = 200 # buffer distance to search inside, not currently used
STREET_ADDRESS_TABLE = "\"nz-street-address-elector\""
STREET_ADDRESS_TABLE_INDEX_NAME = 'the_geom'

def pre_processing()

  ###############
  @output_file = File.open(@output_file_path, "w")
  print "Output : #{@output_file_path}\n"

  @i = 0
  @stats = Hash.new(0) 

  ###########
  
  #pre process entire file to count numbers of road ids - allows optimisation of query later
  print "Preprocessing #{@this_file} - counting road segments\n"
  @countOfSegmentsInRoadOnThisTile = Hash.new(0)
  @rough_total_segment_count = 0
  File.open(@this_file).each_with_index {|line,i|
    if (line =~ /^\;linzid\=(.*)/) then
      id_set = $1
      @countOfSegmentsInRoadOnThisTile[id_set]+= 1
    elsif (line =~ /^\[END(.*)/) then
      @rough_total_segment_count += 1
    end
  }
  @pbar = ProgressBar.new("Progress", @rough_total_segment_count)


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
  check_postgresql_version
  check_postgis_version
end

#################

def post_processing

@reporting_file.print <<EOF
================================
Stats
================================
EOF
@stats.keys.sort.each{|key|
@reporting_file.print "#{key}\t#{@stats[key]}\n"
print "#{key}\t#{@stats[key]}\n"
}
@reporting_file.print "================================\n"

end

#################

def process_polish_buffer(buffer)
  @stats["count_of_sections"]+=1
  @pbar.inc
  
	@i += 1
	attributes = {}
	section = ''
	id_set = nil
	nodPointerArray = []
	hasNumbering = false

	buffer.each{|line|
	if (line =~ /^\[END(.*)/) then
		#section end
	elsif (line =~ /^\[([\w\s]+)\]$/) then
		section = $1
	elsif line =~ /^\;linzid\=(.*)/ then
		id_set = $1
	elsif (line =~ /^Nod(\d+)\=(\d+)\,.*$/) then
		nodPointerArray << $2 #presumes they come in ordered - safe as long as gpsmapedit has just saved the file
	elsif (line =~ /Numbers\d+/) then
		hasNumbering = true
	else 
	# ##############################################################################################
		tokens = line.split(/\=/)
		attributes[tokens[0]] = tokens[1]
	# ##############################################################################################
	end
	}

	run_numberer = false
	if section == 'POLYLINE' && id_set && id_set != '0' then
		if !ALLOWED_ROAD_TYPES_FOR_NUMBERING.include?(attributes['Type']) then
			#bad road type for numbering
      @stats["count_of_sections_with_bad_road_type_ignored"]+=1
		elsif ONLY_ADD_NUMBERING_TO_SECTIONS_WITHOUT_ANY && hasNumbering then
			#has numbering and we're only adding to sections without it
      @stats["count_of_sections_with_numbering_already"]+=1
		else
			run_numberer = true
		end
	end
	
	#################
	numberingCount = 0
	if run_numberer then
    #print "run_numberer #{id_set}\n"
		#NodX refers to the routing nodes, need to do one NumbersX line for each section between nodes (ie. NodXMAX-1 as NumbersX-1 has numbers up to last node)
		
		#strip previous numbering
		if STRIP_PREVIOUS_NUMBERING then
			buffer.delete_if {|line| line =~ /Numbers\d+/ }
		end
		
		data0 = attributes['Data0']
		if data0.nil? then print "Line #{@i} data0=nil\n";return; end
		data0 = data0.sub(/^\(/,'')
		data0 = data0.sub(/\)$/,'')
		data0array = data0.split(/\)\,\(/)
		
		#print data0array.join('|'), "\n"
		#print nodPointerArray.join('-'), "\n"
		
		numberingArray = []
		
		if nodPointerArray.size > 60 then
			print "#{id_set} has more than 60 routing nodes\n"
		elsif nodPointerArray.size == 0 then
			print "#{id_set} has 0 routing nodes. Have you generated routing graph and saved with gpsmapedit?\n"
		elsif nodPointerArray.size == 2 && @countOfSegmentsInRoadOnThisTile[id_set] == '1' then
			numberingArray << nearest_address_working_single_section(id_set,attributes['Data0'])
		else
			1.step(nodPointerArray.size-1, 1) { |i| 
				sectionStartPointIndexPointer = nodPointerArray[i-1].to_i
				sectionEndPointIndexPointer = nodPointerArray[i].to_i
				polishData = '(' + data0array.slice(sectionStartPointIndexPointer..sectionEndPointIndexPointer).join('),(') + ')'
				numberingArray << nearest_address_working(id_set,polishData,sectionStartPointIndexPointer)
			}
		end
    
    
		numberBuffer = []
		numberingArray.each{|numbering|
			if numbering =~ /fail/ then
				#print "FAIL #{id_set} #{numbering}\n"
				#do nothing
			else
				#print "SUCC #{id_set} #{numbering}\t#{attributes['Type']}\n"
				numberingCount += 1
				numberBuffer << "Numbers#{numberingCount}=#{numbering}"
			end
		}
			
		@stats["count_of_sections_needing_numbering"]+=1
		if numberingCount == 0 then
			@stats["count_of_sections_numbering_attempted_but_zero_added"]+=1
		else
			@stats["count_of_sections_numbering_attempted_and_added"]+=1
		end
	else
		@stats["count_of_sections_no_numbering_attempted"]+=1
	end
	
	
	#################
	if numberingCount == 0 then
		print_buffer(buffer)
	else
		print_buffer_with_additions(buffer, numberBuffer) #print_buffer_with_additions not print_buffer_with_updates because ordering of NumbersX is important (GPSMapEdit strips lines out of order)
	end

end #process_polish_buffer



###############################

def print_buffer(buffer)
  buffer.each{|line|
    @output_file.print "#{line}\n"
  }
end

############
def print_buffer_with_additions(buffer,updates)
print_buffer(buffer) and return unless updates #avoid nils

buffer.each{|line|
if (line =~ /^\[END(.*)/) then
	#section end
	unless updates.empty? then
		#add update just before section end
		updates.each{|update|
			@output_file.print "#{update}\n"
		}
	end
end

@output_file.print "#{line}\n"

}

end

############

def parity_of(number)
	if (number.to_i % 2 == 0) then
		return 'E'
	else
		return 'O'
	end
end

############
def return_neat_result(sql_query)
#print "sql_query = \"#{sql_query}\"\n###################\n"

res  = @conn.exec(sql_query)

if res.num_tuples == 1 then
	range_low = res.entries[0]["range_low"]
	parity = parity_of(range_low)
	return [range_low, parity]
else
	return nil
end

end

############

#########################
def extract_xy_from_point_geometry(point)
	begin
		sql_query = "SELECT ST_X(#{point}), ST_Y(#{point});"
		res  = @conn.exec(sql_query)
		#SELECT ST_X(point), ST_Y(point);

		if res.num_tuples == 1 then
			x = res.entries[0]['st_x'].to_f
			y = res.entries[0]['st_y'].to_f
			return [x,y]
		end
	
	rescue Exception => e
    print "extract_xy_from_point_geometry error sql_query = \"#{sql_query}\"\n###################\n"
    print "#{e.message}\n"
		#print "res.entries[0]['st_x'] = #{res.entries[0]['st_x']}\n"
		#exit
		return nil
	end
end

############
def get_dx_dy(point1,point2,k)
#what we want to do is create a polygon using the road as one side, and another side a mirror of that but shifted off to one side
#here we figure out the 'slope' of the line so that we can decide which way is UP/DOWN to the LEFT/RIGHT 
  point1x, point1y = extract_xy_from_point_geometry(point1)
  point2x, point2y = extract_xy_from_point_geometry(point2)

  if (point1y == point2y) then
    # flat horizontal line
    dx = 0
    dy = k
  elsif (point1x == point2x) then
    # flat vertical line
    dx = k
    dy = 0
  else
    m = ((point2y-point1y).to_f/(point2x-point1x).to_f)
    dx = k*m / Math.sqrt(m*m+1)
    dy = dx*-1/m
  end

  y1_gt_y2 = point1y>point2y
  x1_gt_x2 = point1x>point2x

  if (y1_gt_y2 && x1_gt_x2) || (x1_gt_x2 && !y1_gt_y2) then
  #if (point1x > point2x) then #20111205 I'm pretty sure this simple test is correct. Who knows what I was thinking when I wrote the above in 2008.
    #right is up
    left1x = dx
    left1y = dy
    
    right1x = -dx
    right1y = -dy
  else
    #right is down
    right1x = dx
    right1y = dy
    
    left1x = -dx
    left1y = -dy
  end

  return [left1x,left1y,right1x,right1y]

end

#############

def nearest_address_sql_fullside(rna_id,point1x,point1y,point2x,point2y,side1x,side1y,side2x,side2y,originalside)
  sql_query = <<-EOS
SELECT range_low, rna_id, ST_Distance(ST_SetSRID(ST_MakePoint(#{point1x},#{point1y}), #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE
#{STREET_ADDRESS_TABLE_INDEX_NAME} @ ST_GeomFromText( 'POLYGON((#{originalside},#{point2x} #{point2y},#{side2x} #{side2y},#{side1x} #{side1y},#{point1x} #{point1y}))', #{WORKING_SRID} )
AND rna_id = #{rna_id}
ORDER BY distance
LIMIT 1;
  EOS

end

#############

def convert_data0_to_wkt(data0)
data0 = data0.slice(1,data0.length-2) #strip first & last ()s
points = data0.split('),(')

postgis_compatible = ''
points.each{|point|
  pointy,pointx = point.split(',')
  postgis_compatible += ",#{pointx} #{pointy}"
}
postgis_compatible = 'LINESTRING(' + postgis_compatible.slice(1,postgis_compatible.length-1) + ')'

wkt = "ST_GeomFromText('#{postgis_compatible}', #{WORKING_SRID})"
return wkt

end

#############
def geomAsText(text,srid=WORKING_SRID)
#I'm having trouble passing the geoms around so using txt as intermediate. nasty but works.
	return "ST_SetSRID(ST_GeomFromText('#{text}'),#{srid})"
end
#############

def startPoint(geometry)
# ST_StartPoint(geometry)
#     Returns the first point of the LineString geometry as a point.

  sql_query = "SELECT ST_AsText(ST_StartPoint(#{geometry}));"
	return geomAsText(get_first_result(sql_query))

end

#############

def endPoint(geometry)
# ST_EndPoint(geometry)
#     Returns the last point of the LineString geometry as a point.

  sql_query = "SELECT ST_AsText(ST_EndPoint(#{geometry}));"
	return geomAsText(get_first_result(sql_query))

end

#############
def lineLength(geometry)
#ST_Length(geometry)
#    The length of this Curve in its associated spatial reference.

sql_query = "SELECT ST_Length(#{geometry});"
return get_first_result(sql_query).to_f

end
########
def get_first_result(sql_query)
  #print "sql_query = \"#{sql_query}\"\n###################\n"
  res  = @conn.exec(sql_query)
  if res.num_tuples == 1 then
    return res.entries[0][res.fields[0]] #postgres 8.3
    #return res.entries[0][0] #postgres 8.1
  end

  return nil

end

#############
def create_side_polygon_geom(linegeom,dx,dy)
#ST_Translate(geometry, float8, float8, float8)
#   Translates the geometry to a new location using the numeric parameters as offsets. Ie: translate(geom, X, Y, Z).

sql_query = "SELECT ST_AsText(#{linegeom});"
line_astext = get_first_result(sql_query)

translated_line = "ST_Reverse(ST_Translate(#{linegeom},#{dx},#{dy}))"
sql_query = "SELECT ST_AsText(#{translated_line});"
translated_line_astext = get_first_result(sql_query)

first_point = "ST_StartPoint(#{linegeom})"
sql_query = "SELECT ST_AsText(#{first_point});"
first_point_astext = get_first_result(sql_query)

line_astext_points = line_astext.slice(11,line_astext.length-12)
translated_line_astext_points = translated_line_astext.slice(11,translated_line_astext.length-12)
first_point_astext_point = first_point_astext.slice(6,first_point_astext.length-7)

#print "#{line_astext_points}\n#{translated_line_astext_points}\n#{first_point_astext_point}\n"
#exit

#polygon = "ST_GeomFromText( 'POLYGON((#{line_astext_points}, #{translated_line_astext_points}, #{first_point_astext_point}))', #{WORKING_SRID} )"
#sql_query = "INSERT INTO testshapes (\"shape\") VALUES (ST_SetSRID(#{polygon}, 2193));"
#get_first_result(sql_query)

polygon = "'POLYGON((#{line_astext_points}, #{translated_line_astext_points}, #{first_point_astext_point}))'"
sql_query = "SELECT #{polygon};"

return geomAsText(get_first_result(sql_query))



end
#############
def get_nearest_address_inside_polygon(rna_id,polygon_geom,first_point)
#ST_Contains(geometry A, geometry B)
#    Returns 1 (TRUE) if Geometry A "spatially contains" Geometry B.
  sql_query = <<-EOS
SELECT range_low, rna_id, ST_Distance(#{first_point},#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE
ST_Contains(#{polygon_geom}, #{STREET_ADDRESS_TABLE_INDEX_NAME})
AND rna_id = #{rna_id}
ORDER BY distance
LIMIT 1;
EOS

end

#########################

def get_odd_or_not_count(rna_id,polygon_geom,is_odd)
  sql_query = <<-EOS
SELECT count(*)
FROM #{STREET_ADDRESS_TABLE} WHERE
ST_Contains(#{polygon_geom}, #{STREET_ADDRESS_TABLE_INDEX_NAME})
AND is_odd = #{is_odd}
AND rna_id = '#{rna_id}';
EOS

end
##############
def get_odd_even_counts(rna_id,polygon_geom)

odd = get_first_result(get_odd_or_not_count(rna_id,polygon_geom,true)).to_i
even = get_first_result(get_odd_or_not_count(rna_id,polygon_geom,false)).to_i
return [odd,even]

end
###

##############
def count_houses_on_street(rna_id)

  sql_query = "SELECT COUNT(*) FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = '#{rna_id}';"
  return get_first_result(sql_query).to_i

end
###
def get_low_high_on_street(rna_id)

sql_query = "SELECT min(range_low) FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = TRUE;"
min_odd = get_first_result(sql_query).to_i

sql_query = "SELECT min(range_low) FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = FALSE;"
min_even = get_first_result(sql_query).to_i

sql_query = "SELECT max(range_low) FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = TRUE;"
max_odd = get_first_result(sql_query).to_i

sql_query = "SELECT max(range_low) FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = FALSE;"
max_even = get_first_result(sql_query).to_i

return [min_odd,min_even,max_odd,max_even]
end
###
def get_low_high_odds_evens_plus_distance_on_street(rna_id,first_point)
  
sql_query = "SELECT range_low, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = TRUE ORDER BY range_low ASC LIMIT 1;"
min_odd, min_odd_distance = get_number_and_distance(sql_query)

sql_query = "SELECT range_low, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = FALSE ORDER BY range_low ASC LIMIT 1;"
min_even, min_even_distance = get_number_and_distance(sql_query)

sql_query = "SELECT range_low, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = TRUE ORDER BY range_low DESC LIMIT 1;"
max_odd, max_odd_distance = get_number_and_distance(sql_query)

sql_query = "SELECT range_low, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance FROM #{STREET_ADDRESS_TABLE} WHERE rna_id = #{rna_id} AND is_odd = FALSE ORDER BY range_low DESC LIMIT 1;"
max_even, max_even_distance = get_number_and_distance(sql_query)


return [min_odd,min_odd_distance,min_even,min_even_distance,max_odd,max_odd_distance,max_even,max_even_distance]
end
###
def get_number_and_distance(sql_query)
  res  = @conn.exec(sql_query)
  if res.num_tuples == 1 then
  	return res.entries[0]["range_low"].to_i,  res.entries[0]["distance"].to_f
  end

  return 0,0
end




def nearest_address_working_single_section(rna_id,data0)

  # Q which side is right, which left?
  # Q is it odds and evens or mixed?
  # Q is the nearest point low or high? ok for odds/evens not for mixed. 

  count_of_houses_on_street = count_houses_on_street(rna_id)
  if count_of_houses_on_street == 0 then
    return ";fail-no_houses_on_street-nearest_address_working_single_section"
  end
  
  wkt = convert_data0_to_wkt(data0)
  #print "data0 = #{data0}\n"
  #print "wkt = #{wkt}\n"
  
  first_point = startPoint(wkt)
  last_point = endPoint(wkt)

  leftx,lefty,rightx,righty = get_dx_dy(first_point, last_point, lineLength(wkt))
  #leftx,lefty,rightx,righty = get_dx_dy(first_point, last_point, K)
  
  right_polygon_geom = create_side_polygon_geom(wkt,rightx,righty)
  left_polygon_geom = create_side_polygon_geom(wkt,leftx,lefty)

  left_odd_count, left_even_count = get_odd_even_counts(rna_id,left_polygon_geom)
  right_odd_count, right_even_count = get_odd_even_counts(rna_id,right_polygon_geom)

  #min_odd,min_even,max_odd,max_even = get_low_high_on_street(rna_id)
    
  if (left_odd_count > 0 && right_odd_count > 0) && (left_even_count > 0 && right_even_count > 0) then
    # is probably mixed

    right_first, right_first_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,right_polygon_geom,first_point))
    right_last, right_last_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,right_polygon_geom,last_point))

    left_first, left_first_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,left_polygon_geom,first_point))
    left_last, left_last_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,left_polygon_geom,last_point))

    #return ";fail-odds and evens on both sides| counts are left odd,even = #{left_odd_count},#{left_even_count} right odd,even = #{right_odd_count},#{right_even_count}"
    
    left_first_parity = 'B'
    right_first_parity = 'B'
    
  else
    # is probably odds/evens
  min_odd,min_odd_distance,min_even,min_even_distance,max_odd,max_odd_distance,max_even,max_even_distance = get_low_high_odds_evens_plus_distance_on_street(rna_id,first_point)
  #print "odds low,hi  #{min_odd},#{max_odd} | evens low,hi = #{min_even},#{max_even}\n"
  #print "distance low,hi  #{min_odd_distance},#{max_odd_distance} | evens low,hi = #{min_even_distance},#{max_even_distance}\n"

    if right_odd_count > 1 then
      #evens on left
      #is min_even closer than max_even?
      if min_even_distance < max_even_distance then
        left_first = min_even
        left_last = max_even
      else
        left_first = max_even
        left_last = min_even
      end
      
      #odds on right
      #is min_odd closer than max_odd?
      if min_odd_distance < max_odd_distance then
        right_first = min_odd
        right_last = max_odd
      else
        right_first = max_odd
        right_last = min_odd
      end
      
      left_first_parity = 'E'
      right_first_parity = 'O'
    else
      #odds on left
      #is min_even closer than max_even?
      if min_odd_distance < max_odd_distance then
        left_first = min_odd
        left_last  = max_odd
      else                  
        left_first = max_odd
        left_last  = min_odd
      end
      
      #evens on right
      #is min_odd closer than max_odd?
      if min_even_distance < max_even_distance then
        right_first = min_even
        right_last  = max_even
      else                    
        right_first = max_even
        right_last  = min_even
      end
      
      left_first_parity = 'O'
      right_first_parity = 'E'
    
    end
    
  end

  numberIndex = 0
  return cleanseNumbers(numberIndex,left_first_parity,left_first,left_last,right_first_parity,right_first,right_last)
    
  #check_parity_of_neighbours(rna_id,first_point) #stupid method, useless

end

##########

def nearest_address_working(rna_id,data0,numberIndex = 1)
# numberIndex

  count_of_houses_on_street = count_houses_on_street(rna_id)
  if count_of_houses_on_street == 0 then
    return ";fail-no_houses_on_street-nearest_address_working"
  end

  wkt = convert_data0_to_wkt(data0)
  #print "data0 = #{data0}\n"
  #print "wkt = #{wkt}\n"

  first_point = startPoint(wkt)
  last_point = endPoint(wkt)
  #print "#{first_point}, #{last_point}\n########\n"

  # use fixed K or variable for line length? variable may well cause problems with super long roads, eg state highways
  leftx,lefty,rightx,righty = get_dx_dy(first_point, last_point, lineLength(wkt))
  #leftx,lefty,rightx,righty = get_dx_dy(first_point, last_point, K)

  #print "#{leftx}, #{lefty}, #{rightx}, #{righty}\n########\n"

  right_polygon_geom = create_side_polygon_geom(wkt,rightx,righty)
  #print "#{right_polygon_geom}\n########\n"
  #exit

  left_polygon_geom = create_side_polygon_geom(wkt,leftx,lefty)
  #print "#{left_polygon_geom}\n########\n"
  #exit

  #right_first = get_nearest_address_inside_polygon(rna_id,right_polygon_geom,first_point)
  right_first, right_first_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,right_polygon_geom,first_point))
  right_last, right_last_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,right_polygon_geom,last_point))

  left_first, left_first_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,left_polygon_geom,first_point))
  left_last, left_last_parity = return_neat_result(get_nearest_address_inside_polygon(rna_id,left_polygon_geom,last_point))

  #Todo - make output 0 if nil

  nearest_number = get_nearest_address_inside_buffer(rna_id,wkt,first_point)

  left_odd_count, left_even_count = get_odd_even_counts(rna_id,left_polygon_geom)
  right_odd_count, right_even_count = get_odd_even_counts(rna_id,right_polygon_geom)

  if (right_first.nil?) && (right_last.nil?) && (left_first.nil?) && (left_last.nil?) then
    return ";fail-no_numbers_on_this_road_section"
  elsif (left_odd_count > 1 && right_odd_count > 1) || (left_even_count > 1 && right_even_count > 1) then
    return ";fail-odds and evens on both sides| counts are left odd,even = #{left_odd_count},#{left_even_count} right odd,even = #{right_odd_count},#{right_even_count}"
  elsif nearest_number.nil? then
    return ";fail-weird no address within buffer"
  #this check gives heaps of false positives. scrap it.
  #elsif [right_first,right_last,left_first,left_last].index(nearest_number).nil? then
  #	#means the nearest address is not one of these, not a definitive check but certainly suspect
  #	return ";fail-nearest is #{nearest_number} which isn't left #{left_first},#{left_last} or right #{right_first},#{right_last}"

  elsif (left_last_parity != left_first_parity) || (right_last_parity != right_first_parity) || (left_last_parity == right_first_parity) then
    return ";fail-sanity-paritycheck" + "Numbers#{numberIndex}=0,#{left_first_parity},#{left_first},#{left_last},#{right_first_parity},#{right_first},#{right_last}"
  else
    #print "index,leftstyle,leftfirst,leftlast,right_style,right_first,right_last\n"
    return cleanseNumbers(numberIndex,left_first_parity,left_first,left_last,right_first_parity,right_first,right_last)
  end

  return nil
end

#########################
def cleanseNumbers(numberIndex,left_first_parity,left_first,left_last,right_first_parity,right_first,right_last)

	if (right_first == 0 && right_last == 0) || (right_first.nil? && right_last.nil?) then
		right_first_parity = 'N'
		right_first = -1
		right_last  = -1
	end
	if (left_first == 0 && left_last == 0) || (left_first.nil? && left_last.nil?) then
		left_first_parity = 'N'
		left_first = -1
		left_last  = -1
	end
	return "#{numberIndex},#{left_first_parity},#{left_first},#{left_last},#{right_first_parity},#{right_first},#{right_last}"
end

#########################

def get_nearest_address_inside_buffer(rna_id,polygon_geom,first_point)

  sql_query = <<-EOS
SELECT range_low, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}), #{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance 
FROM #{STREET_ADDRESS_TABLE} WHERE
ST_Intersects(ST_Buffer(#{STREET_ADDRESS_TABLE_INDEX_NAME},100),#{polygon_geom})
AND rna_id = #{rna_id}
ORDER BY distance
LIMIT 1;
  EOS

res  = @conn.exec(sql_query)

if res.num_tuples == 1 then
	range_low = res.entries[0]["range_low"]
	return range_low
else
	return nil
end

end
#########################

def get_srid(polygon_geom)
#ST_SRID(geometry)
#    Returns the integer SRID number of the spatial reference system of the geometry.
  sql_query = <<-EOS
SELECT ST_SRID(#{polygon_geom});
  EOS

end
#############
#########################

def check_parity_of_neighbours(rna_id,first_point)

# find the nearest address, doesn't really matter which
  sql_query = <<-EOS
SELECT range_low, is_odd, longitude, latitude, ST_Distance(ST_SetSRID(#{first_point}, #{WORKING_SRID}),#{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance 
FROM #{STREET_ADDRESS_TABLE} WHERE
rna_id = #{rna_id}
ORDER BY distance
LIMIT 1;
  EOS

res  = @conn.exec(sql_query)

if res.num_tuples == 1 then
	range_low_a = res.entries[0]["range_low"]
	parity_a = res.entries[0]["is_odd"]
	longitude_a = res.entries[0]["longitude"]
	latitude_a = res.entries[0]["latitude"]
else
	return nil
end

# now check if its nearest neighbour is of the same parity
  sql_query = <<-EOS
SELECT range_low, is_odd, ST_Distance(ST_SetSRID(ST_MakePoint(#{longitude_a},#{latitude_a}), #{WORKING_SRID}), #{STREET_ADDRESS_TABLE_INDEX_NAME}) AS distance 
FROM #{STREET_ADDRESS_TABLE} WHERE
rna_id = #{rna_id} and
range_low != #{range_low_a}
ORDER BY distance
LIMIT 1;
  EOS

res  = @conn.exec(sql_query)

if res.num_tuples == 1 then
	range_low_b = res.entries[0]["range_low"]
	parity_b = res.entries[0]["is_odd"]
else
	return nil
end

	print "PARITY CHECK #{range_low_a}, #{parity_a}, #{range_low_b}, #{parity_b}. SAME = #{parity_a==parity_b}\n"

end
#########################


def print_sql_and_results(sql_query)

#print "#{sql_query}\n###################\n"

res  = @conn.exec(sql_query)

	res.each do |row|
		row.each do |column|
			print column
			(20-column.length).times{print " "}
		end
	puts
	end
	print "###################\n"
	
end

##########

def print_neat_result(sql_query)

res  = @conn.exec(sql_query)

if res.num_tuples == 1 then
	range_low = res.entries[0]["range_low"]
	parity = parity_of(range_low)
	print "#{range_low}, #{parity}\n"
else
	return nil
end

print "###################\n"
	
end
#########################
def check_postgis_version
  begin
    sql_query = "SELECT PostGIS_full_version();"
    res  = @conn.exec(sql_query)
    print res.entries[0].to_s
  
  rescue Exception => e
    print "#{e.message}\n"
    print "Postgis not installed\n"
    exit
  end
end
#########################
def check_postgresql_version
  begin
    sql_query = "SELECT version();"
    res  = @conn.exec(sql_query)
    print res.entries[0].to_s
  
  rescue Exception => e
    print "#{e.message}\n"
    print "Postgresql not installed\n"
    exit
  end
end
