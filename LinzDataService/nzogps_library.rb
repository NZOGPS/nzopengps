#!/usr/bin/ruby
#encoding: UTF-8

=begin
  a bunch of methods and common code for handling conversion of LINZ shape file geometry records to Polish format
=end


@@roadextensions = {
  "NORTH" => "N",
  "EAST" => "E",
  "SOUTH" => "S",
  "WEST" => "W",
  "NORTHEAST" => "NE",
  "SOUTHEAST" => "SE",
  "NORTHWEST" => "NW",
  "SOUTHWEST" => "SW",
  "UPPER" => "UPR",
  "LOWER" => "LWR",
  "CENTRAL" => "CTRL",
  "EXTENSION" => "EXT"
}
@@addr_Match = {}
@@addr_Match['directions'] = '\b(?:' + @@roadextensions.keys.join("|") + "|" + @@roadextensions.values.join("|") + ')\b'
@@addr_Match['streetwithdirection'] = /(.*)\s(#{@@addr_Match['directions']})$/i

# point may not be nzpost, but is standard?
#"POINT" => "PT",
@@roadprepositions = {
  "MOUNT" => "MT",
  "SAINT" => "ST"
}

@@contractions = {
  "ACCESS" => "ACCS",
  "AVENUE" => "AVE",
  "BAY" => "BAY",
  "BEACH" => "BCH",
  "BEND" => "BND",
  "BOULEVARD" => "BLVD",
  "CENTRE" => "CTR",
  "CIRCLE" => "CIR",
  "CIRCUS" => "CRCS",
  "CLOSE" => "CL",
  "COMMON" => "CMN",
  "COURT" => "CRT",
  "CRESCENT" => "CRES",
  "CREST" => "CRST",
  "DOWNS" => "DOWNS",
  "DRIVE" => "DR",
  "ESPLANADE" => "ESP",
  "FAIRWAY" => "FAWY",
  "GARDENS" => "GDNS",
  "GLADE" => "GLD",
  "GLEN" => "GLN",
  "GREEN" => "GRN",
  "GROVE" => "GRV",
  "HEAD" => "HEAD",
  "HEIGHTS" => "HTS",
  "HIGHWAY" => "HWY",
  "LEADER" => "LEDR",
  "LEIGH" => "LGH",
  "MOUNT" => "MT",
  "OAKS" => "OAKS",
  "PAKU" => "PAKU",
  "PARADE" => "PDE",
  "PARK" => "PK",
  "PLACE" => "PL",
  "POINT" => "PT",
  "PROMENADE" => "PROM",
  "QUAY" => "QY",
  "ROAD" => "RD",
  "SQUARE" => "SQ",
  "STRAND" => "STRD",
  "STREET" => "ST",
  "TERRACE" => "TCE",
  "TRACK" => "TRK",
  "VALLEY" => "VLY",
  "VILLAGE" => "VLG",
  "VILLAS" => "VLLS",
  "VISTA" => "VIS",
  "WALK" => "WLK",
  "MOTORWAY" => "MWY" #the one unofficial abbreviation we will accept
}


def doContractions(streetname)
	demacron = {
				"\u0100" => 'A',
				"\u0101" => 'a',
				"\u0112" => 'E',
				"\u0113" => 'e',
				"\u012A" => 'I',
				"\u012B" => 'i',
				"\u014C" => 'O',
				"\u014D" => 'o',
				"\u016A" => 'U',
				"\u016B" => 'u'
			}

	if streetname.nil? then return '' end
	streetname.force_encoding("UTF-8") #I guess that rgeo::shapefile doesn't read or set the encoding correctly
	streetname = streetname.encode("ASCII", :fallback => demacron )
	streetname = streetname.strip.upcase
  #streetname = streetname.gsub(/\-/, ' ')#why remove -s?

  #streets that start with THE and are just one word after that shouldn't be contracted
  if (streetname =~ /^THE (\w*)$/i) then return streetname end 

  # needs to be above for sufi comparison, below for sufi checking... why? dunno.
  if (streetname =~ /^SH (.*)$/i) then streetname = 'STATE HIGHWAY ' + $1 	end 
  #if (streetname =~ /^STATE HIGHWAY (.*)$/i) then streetname = 'SH ' + $1 	end # this way wrong, majority other way

  if (md = @@addr_Match['streetwithdirection'].match(streetname)) then
    streetname = md[1]
    streetext = md[2]
  end

  @@contractions.each_pair{|key,value|
    #streetname = streetname.sub(/\b#{key}\b/, value) # incorrectly handles case of 'avenue road' - contracts both.
    #if (streetname =~ /^.+\b#{key}\b.*$/i) then streetname = streetname.sub(/\b#{key}\b/, value) end # contracts all words that look like a contraction not just last one
    if (streetname =~ /^.+\b#{key}$/i) then streetname = streetname.sub(/\b#{key}$/, value) end
  }

  @@roadprepositions.each_pair{|key,value|
    if (streetname =~ /^#{key}\b.*$/i) then streetname = streetname.sub(/^#{key}\b/, value) end
  }

  if (streetext) then
    @@roadextensions.each_pair{|key,value|
      if (streetext =~ /^.*\b#{key}$/i) then streetext = streetext.sub(/\b#{key}$/, value) end
    }
    streetname = streetname + ' ' + streetext
  end


  #if (streetname =~ /(.*)\bSOUTH$/) then streetname = $1 + "S" end
  #if (streetname =~ /(.*)\bNORTH$/) then streetname = $1 + "N" end
  #if (streetname =~ /^SOUTH\b(.*)/) then streetname = "S" + $1 end
  #if (streetname =~ /^NORTH\b(.*)/) then streetname = "N" + $1  end
  #  
  #if (streetname =~ /(.*)\bEAST$/) then streetname = $1 + "E" end
  #if (streetname =~ /(.*)\bWEST$/) then streetname = $1 + "W" end
  #if (streetname =~ /^EAST\b(.*)/) then streetname = "E" + $1 end
  #if (streetname =~ /^WEST\b(.*)/) then streetname = "W" + $1  end
    
  return streetname
end



def convertGeometrytoPolish(record)
  record.geometry.map{|line|'Data0=' + line.points.map{|p| "(#{p.y},#{p.x})"}.join(',')}
end



##################

def initialise_tile_file_handles

directory_name = 'outputslinz'
if !FileTest::directory?(directory_name)
  Dir::mkdir(directory_name)
end

print "Opening output files in #{directory_name} folder\n"
splitTiles = ['Northland', 'Auckland', 'Waikato', 'Central', 'Wellington', 'Tasman', 'Canterbury', 'Southland', 'Chathams', 'LINZ-NZ-ALL']
@tileFH = {}

splitTiles.each{|tile|
	@tileFH[tile] = File.open(File.join(directory_name,"#{tile}-LINZ.mp"), "w")
	
@tileFH[tile].print <<EOF
; Generated by Zenbu
[IMG ID]
Elevation=M
Preprocess=F
TreSize=1500
TreMargin=0.00000
RgnLimit=1024
POIIndex=Y
MG=Y
Numbering=Y
Routing=Y
Copyright=NZ OPEN MAP PROJECT
Levels=5
Level0=24
Level1=22
Level2=20
Level3=17
Level4=15
Zoom0=0
Zoom1=1
Zoom2=2
Zoom3=3
Zoom4=4
[END-IMG ID]

[Countries]
Country1=New Zealand~[0x1d]NZ
[END-Countries]

[Regions]
Region1=Auckland
CountryIdx1=1
Region2=Bay of Plenty
CountryIdx2=1
Region3=Canterbury
CountryIdx3=1
Region4=Gisborne
CountryIdx4=1
Region5=Hawke's Bay
CountryIdx5=1
Region6=Manawatu-Wanganui
CountryIdx6=1
Region7=Marlborough
CountryIdx7=1
Region8=Nelson
CountryIdx8=1
Region9=Northland
CountryIdx9=1
Region10=Otago
CountryIdx10=1
Region11=Southland
CountryIdx11=1
Region12=Taranaki
CountryIdx12=1
Region13=Tasman
CountryIdx13=1
Region14=Waikato
CountryIdx14=1
Region15=Wellington
CountryIdx15=1
Region16=West Coast
CountryIdx16=1
[END-Regions]

EOF

#'
	
	
}

end

# ###############
def identify_tile_from_wkt_envelope(record)
  #slightly nasty method of identifying tile(s) that record intersects
  
  bounds = record.geometry.envelope # [(MINX, MINY), (MAXX, MINY), (MAXX, MAXY), (MINX, MAXY), (MINX, MINY)]
  if bounds.to_s =~ /POLYGON\s?\(\((.*) (.*),.*,(.*) (.*),.*,.*\)\)/ then
    minx = $1.to_f
    miny = $2.to_f
    maxx = $3.to_f
    maxy = $4.to_f
    #print "#{i} #{sufi} minx #{minx} miny #{miny} maxx #{maxx} maxy #{maxy}\n"
  else
    raise "bounds unrecognised #{bounds} #{record.attributes.inspect}\n"
  end

  tiles = []

  #skip chathams
  if (minx < 166 || minx > 179 || miny < -48 || miny > -34) then
    tiles << "Chathams"
  else

    if ((maxy >= -36.38880)) then tiles << "Northland" end
    if ((miny <= -36.38880) && (miny >= -37.105228)) then tiles << "Auckland" end
    if ((miny <= -37.105228) && (miny >= -38.638100)) then tiles << "Waikato" end
    if ((miny <= -38.638100) && (miny >= -40.170971)) then tiles << "Central" end
    if (((miny <= -40.170971) && (miny >= -41.703838)) && (minx >= 174.3)) then tiles << "Wellington" end
    if (((miny <= -40.407970) && (miny >= -42.731949)) && (maxx <= 174.3)) then tiles << "Tasman" end
    if ((miny <= -42.731949) && (miny >=  -44.55553)) then tiles << "Canterbury" end
    if ((miny <=  -44.555530) && (miny >= -47.379910)) then tiles << "Southland" end
    #bastardised way of doing it, once for max and min each
    if ((maxy <= -36.38880) && (maxy >= -37.105228)) then tiles << "Auckland" end 
    if ((maxy <= -37.105228) && (maxy >= -38.638100)) then tiles << "Waikato" end 
    if ((maxy <= -38.638100) && (maxy >= -40.170971)) then tiles << "Central" end
    if (((maxy <= -40.170971) && (maxy >= -41.703838)) && (minx >= 174.3)) then tiles << "Wellington" end 
    if (((maxy <= -40.407970) && (maxy >= -42.731949)) && (maxx <= 174.3)) then tiles << "Tasman" end 
    if ((maxy <= -42.731949) && (maxy >=  -44.55553)) then tiles << "Canterbury" end
    if ((maxy <=  -44.555530) && (maxy >= -47.379910)) then tiles << "Southland" end 

  end #skip chathams

  return tiles.uniq
end



def process_geom_record(record)

  linzid = record.attributes['id']
  streetname = record.attributes['name']
  streetname = doContractions(streetname)

  suburb = record.attributes['locality']
  region = record.attributes['territoria']

  polishformatarray = convertGeometrytoPolish(record)

  #routeParam = 2 #yellow in GPSMapEdit
  #routeParam = 4 #light blue in GPSMapEdit
  routeParam = 7 #red in GPSMapEdit

  tiles = identify_tile_from_wkt_envelope(record)
  tiles << 'LINZ-NZ-ALL' #catch all tile

  tiles.each{|tile|

    polishformatarray.each{|polishformat|

      @tileFH[tile].print <<POIEND
;linzid=#{linzid}
[POLYLINE]
Type=0x6
Label=#{streetname}
EndLevel=1
#{polishformat}
RouteParam=#{routeParam},0,0,0,0,0,0,0,0,0,0,0
[END]

POIEND
    }

  }#eachtile

end

@total_count = 0
def progress
  @total_count += 1;
  limit = 1000
  if @total_count % limit == 0
    STDERR.print "."
    STDERR.print "\n #{@total_count}\t" if @total_count % (limit * 5) == 0
    STDERR.flush
  end
end