# encoding: UTF-8

require 'rubygems'
require 'find'
require 'csv'

#Encoding.default_external = Encoding.find('utf-8')

@reporting = Hash.new(0)

# #####################

@masterZenbuDataHash = Hash.new
def preloadZenbuFile(path)
# loads the downloaded Zenbu file into a Hash indexed by ZID
# zid,name,tags,website,physical_address,phone,opening_hours,longitude,latitude,gisprecision,correctly_placed,created_at,updated_at,updated_by
#  0    1    2     3            4          5           6         7         8         9           10              11         12         13
# 1040845,West Coast Gallery,art gallery,http://www.westcoastgallery.co.nz,"Seaview Road, Piha",09 812 8029,Thu-Sun 11-5pm,174.474306106567,-36.9538529055281,manual,true,Fri Oct 06 16:46:11 NZDT 2006,Tue Oct 31 19:44:03 NZDT 2006,zenbu

	print "Loading Zenbu master data file... "

	if !File.exists?(path) then
		print "EXITING! File not found at #{path}\n"
		exit
	end
	
	CSV.foreach(path, {:encoding => 'UTF-8', :headers => true}) do |row|
#zid,name,tags,website,physical_address,phone,opening_hours,longitude,latitude,gisprecision,correctly_placed,created_at,updated_at,updated_by,version,facebook_page,categories	
	  @masterZenbuDataHash[row['zid']] = row
	end
	
	print "#{@masterZenbuDataHash.size} entries\n"
end

# #####################

require 'iconv' #iconv allows us to convert ("transliterate") or ignore non-ascii characters 
@utf8_to_latin1 = Iconv.new("LATIN1//TRANSLIT//IGNORE", "UTF-8")
@utf8_to_latin1_ignore = Iconv.new("LATIN1//IGNORE", "UTF-8")

def fix_special_chars(s)
	#filter characters that can display poorly on Garmin
	if s.nil? then return nil end

	begin
		s = @utf8_to_latin1.iconv(s)
		return s
	rescue Exception => e  
	  #puts e.message  
	  #puts e.backtrace.inspect 
		#print "Iconv error #{e.message } on '#{s}'\n"
	end
		
	#try the simpler IGNORE algorithm if the above fails
	begin
		s = @utf8_to_latin1_ignore.iconv(s)
		return s
	rescue Exception => e  
	  #puts e.message  
	  #puts e.backtrace.inspect 
      #print "Iconv error #{e.message } on '#{s}'\n"
	end
	
end

# #####################

def processMPpoint(zid,poitypecode)
# zid,name,tags,website,physical_address,phone,opening_hours,longitude,latitude,gisprecision,correctly_placed,created_at,updated_at,updated_by

begin
	
	if !@masterZenbuDataHash.has_key?(zid)
		# p "#{zid} not in data file\n"
		return
	end

	label = @masterZenbuDataHash[zid]['name']||''
	label = fix_special_chars(label)
	label = label.slice(0,80) #only first 80 characters allowed, Garmin limitation
	
	tags = @masterZenbuDataHash[zid]['tags']||''
	tags = fix_special_chars(tags)
	
	website = @masterZenbuDataHash[zid]['website']||''
	phone = tidyPhoneNumber(zid,@masterZenbuDataHash[zid]['phone'])
	
	opening = @masterZenbuDataHash[zid]['opening_hours']||''
	opening = fix_special_chars(opening)
	
	#some customised markup for particular local entries
	label = processPOITypeSpecificRules(label,tags,website,poitypecode,opening)
	
	address = @masterZenbuDataHash[zid]['physical_address']||''
	address = processStandardAddressAbbreviations(address)
	
	longitude = @masterZenbuDataHash[zid]['longitude']
	if longitude == "0.0" then return end
	longitude = sprintf("%.5f",longitude)
	latitude = @masterZenbuDataHash[zid]['latitude']
	if latitude == "0.0" then return end
	latitude = sprintf("%.5f",latitude)
	
#NZ CUSTOMISED
# let's also skip the Chatham Islands POIs, technically NZ but no use for us (and anything else outside standard NZ lon/lat)
# Chatham Islands points have long of -176 (correctly displays in google maps...)
# range long in linz is 166.71 to 178.55
# range lat in linz is -46 to -34 - but Stewart Island is at 47.32
	if latitude.to_f < -47.32 || latitude.to_f > -34 || longitude.to_f < 166 || longitude.to_f > 179 then return end
	
	# look for black, orange, blue markers
	correctly_placed = @masterZenbuDataHash[zid]['correctly_placed']
 	if correctly_placed == '1' then #black marker
 	  @reporting['correct']+=1
 	elsif correctly_placed == '2' then #blue marker
	  return #skip blue markers
 	else
 	  @reporting['incorrect']+=1
	  label = '?' + label # add ? to non correct placed
 	end

#NZ CUSTOMISED
# choose output file based on rudimentary North Island / South Island definition
if latitude.to_f > -40.4 then mpfileoutref = @mpfileoutA #higher than top of south
elsif latitude.to_f < -41.7 then mpfileoutref = @mpfileoutB # lower than bottom of north
elsif longitude.to_f > 174.5 then mpfileoutref = @mpfileoutA # more east than most east of south
else mpfileoutref = @mpfileoutB end #everything else

	streetdesc = "#{address}/ #{tags}"
	streetdesc = streetdesc.slice(0,80)
	
	# zip_hours always in UPCASE and seems to truncate streetdesc
	zip_hours = "#{opening}"
	#zip_hours = zip_hours.slice(0,80)
	zip_hours = zip_hours.slice(0,40) #trying smaller slot for hours to stop it truncating streetdesc
	
mpfileoutref.print <<POIEND
;#{zid}
[POI]
Type=#{poitypecode}
Label=#{label}
StreetDesc=#{streetdesc}
POIEND

mpfileoutref.print "Phone=#{phone}\n" unless phone.nil? || phone.empty?
mpfileoutref.print "zip=#{zip_hours}\n" unless zip_hours.nil? || zip_hours.empty?

mpfileoutref.print <<POIEND
Data0=(#{latitude},#{longitude})
[END]

POIEND
# EndLevel=1 # level where POIs stop displaying, probably done automatically by compiler

rescue
	print "Error processing processMPpoint(#{zid},#{poitypecode})\n" unless zid == 'zid'
end

end

# #####################

def tidyPhoneNumber(zid,phonenumber)
#format phone numbers in Garmin friendly way - leading country code, nothing but numbers

	if phonenumber.nil? || phonenumber.empty? then return "" end
		
	#attempt to fix some common cases
	
	if phonenumber =~ /(.*)\s\bor\b/i then #if the number contains the text ' or ' then try to grab the 1st number on left hand side of 'or'
		#print "Phone OR #{zid} #{phonenumber} #{$1}\n"
		phonenumber = $1
	elsif phonenumber =~ /(.+)\s\b\(.+\)/i then #contains bracketed number too
		#print "Phone ()s #{zid} #{phonenumber} #{$1}\n"
		phonenumber = $1
	elsif phonenumber =~ /^phone(.*)/i then #starts with "phone", common misentry
		phonenumber = $1
	end
	phonenumber = phonenumber.gsub(/[^\d\w]/,'')
	
	#NZ CUSTOMISED
	if phonenumber =~ /^(0800|0508|0900)/ then
		#freephone, do nothing
	elsif phonenumber =~ /^64(\d{8})/ then
		phonenumber = '+' + $1
	elsif phonenumber =~ /^0(\d{8})/ then
		phonenumber = '+64' + $1 #add country code
	else
		#print "Phone number probably won't work as unrecognised format - #{zid} #{phonenumber}\n"
		phonenumber = ''
	end
	return phonenumber
end

# #####################

def processPOITypeSpecificRules(label,tags,website,poitypecode,opening)
#NZ CUSTOMISED

  case poitypecode
  when "0x2f01" # petrol stations 0x2f01.txt
  
  	#make sure garage names have the brand in the name for easy identification
  	if website =~ /\.Bp\./i && label !~ /^BP/i then
  	  label = "BP " + label
  	end
  	if website =~ /\.Shell\./i && label !~ /^Shell/i then
  	  label = "Shell " + label
  	end
  	if website =~ /\.Mobil\./i && label !~ /^Mobil/i then
  	  label = "Mobil " + label
  	end
  	if website =~ /\.Caltex\./i && label !~ /^Caltex/i then
  	  label = "Caltex " + label
  	end
  	
  when "0x2f06" # banks 0x2f06.txt
  	#custom suffix to identify banks and atms
  	if tags =~ /\bbank\b/i && tags =~ /\bATM\b/i then
  	  label += " (B&A)"
  	elsif tags =~ /\bbank\b/i then
  	  label += " (B)"
  	elsif tags =~ /\bATM\b/i then
  	  label += " (A)" if label !~ /\bATM\b/i
  	end
  
  when "0x2b03" # Accommodation - Camping, RV Park 0x2b03.txt
  	#custom suffix to identify DOC (department of conservation) campsites
  	if website =~ /\.doc\./i && label !~ /^doc/i then
  	  label += " (DOC)"
  	end
  end
  
  #custom suffix to identify 24hr establishments such as petrol stations
  if opening =~ /24/ then
  	label += " 24hr"
  end
  
  label = label.upcase
	return label
end

# #####################

def processStandardAddressAbbreviations(address)
	address = address.gsub(/\bStreet\b/i,'St')
	address = address.gsub(/\bRoad\b/i,'Rd')
	address = address.gsub(/\bSquare\b/i,'Sq')
	address = address.gsub(/\bQuay\b/i,'Qy')
	address = address.gsub(/\bAvenue\b/i,'Ave')
	address = address.gsub(/\bCrescent\b/i,'Cres')
	address = address.gsub(/\bDrive\b/i,'Dr')
	address = address.gsub(/\bFloor\b/i,'Fl')
	address = address.gsub(/\bLevel\b/i,'L')
	address = address.gsub(/\bBuilding\b/i,'Blg')
	address = address.gsub(/\bCentre\b/i,'Ctr')
	address = address.gsub(/\bApartment\b/i,'Apt')
	address = address.gsub(/\bInternational\b/i,'Intl')
	address = address.gsub(/\bNational\b/i,'Ntl')
	
#NZ CUSTOMISED
	address = address.gsub(/\bChristchurch\b/i,'Chc')
	address = address.gsub(/\bAuckland\b/i,'Akl')
	address = address.gsub(/\bWellington\b/i,'Wlg')
	address = address.gsub(/\bDunedin\b/i,'Dud')
	address = address.gsub(/\bHamilton\b/i,'Hmtn')
	address = address.gsub(/\bGisborne\b/i,'Gsb')
	address = address.gsub(/\bNewmarket\b/i,'Nwmkt')
	return address
end

# #####################

def printMPHeader(mpfileoutref,mapid)
#NZ CUSTOMISED

if mapid == "64000012" then #North Island - 14/01/2009 9:53:47 a.m. rc8 said I also increased the TRE size on the A file from 1500 to 2500 - to speed up processing speed.
	tresize='2500'
else
	tresize='1500'
end

mpfileoutref.print <<POIEND
; Generated by Zenbu

[IMG ID]
ID=#{mapid}
Name=POI Zenbu
Elevation=M
Preprocess=F
TreSize=#{tresize}
TreMargin=0.00000
RgnLimit=1024
POIOnly=Y
Transparent=Y
POIIndex=Y
Levels=3
Level0=24
Level1=20
Level2=17
Zoom0=0
Zoom1=4
Zoom2=7
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

POIEND

#'


if mapid == "64000012" then #North Island
mpfileoutref.print <<POIEND
[POI]
Type=0x2800
Label=NI POI from www.zenbu.co.nz
EndLevel=1
Data0=(-34.5,178.5)
[END]

POIEND

else

mpfileoutref.print <<POIEND
[POI]
Type=0x2800
Label=SI POI from www.zenbu.co.nz
EndLevel=1
Data0=(-47,173)
[END]

POIEND
end

=begin
notes from cGPSmapper manual

LBLcoding=x
6 compressed label coding (smallest maps)
9 full-byte (8-bit) coding (supports national characters, depending on the GPS firmware)
10 Unicode / MBCS (depending on the GPS firmware)
Default = 6

Codepage=xx
<>0 full-byte (8-bit) character coding with the specified codepage is used (depending on the GPS firmware)
0 single-byte coding
Note: All labels must be written in CAPITALS if a codepage is used
Note: The delimiters for road numbers (refer to section 4.2.6, on page 30, for details) are different if full-byte coding is used.
Note: Special codes are different for 8-bit coding!
Default = 0

indexing only works on 1st char
CodePage=1252
LblCoding=9
=end

end

# #####################

@category_hash = Hash.new
@category_name_table = Hash.new
@category_path_table = Hash.new

def loadCategoriesFromCategoryFiles(p)
#process each file in the ZenbuPOIcategories folder
print "Loading categories... "

	if !File.exists?(p) then
		print "path to categories not found #{p}\n"
		return
	end
	
	Find.find(p) do |path|
	  if FileTest.directory?(path)
	    next # don't do anything with dirs in this folder
	  elsif path =~ /01 Speed Cameras/
	  	next
	  elsif path =~ /\.zip$/
	  	next
	  elsif path =~ /\.svn/
	  	next
	  else
	    #p path
	    loadSingleCategory(path)
	  end
	end

print "#{@category_hash.size} unique ZIDs categorised in #{@category_name_table.size} category files\n"
end
# #####################

@category_hash_from_zenbu = Hash.new
def loadCategoriesFromZenbu
	print "Loading categories from Zenbu... "
	@masterZenbuDataHash.each_pair{|zid,data|
		if !@category_hash.has_key?(zid) then #ignore Zenbu if override exists in NZOGPS
			@reporting['category_from_zenbu']+=1
		end
		category = assignCategoryFromZenbuCategory(data)
		@category_hash_from_zenbu[zid] = category
	}
	print "#{@reporting['category_from_zenbu']} unique ZIDs categorised\n"
end

# #####################

@notforuseZIDs = Hash.new

def loadSingleCategory(path)
	
	if !File.exists?(path) then
		return
	end
	
	#extract POI type code from filename
	poitype = File.basename(path,'.*')#e.g. poitype = "Public Office Government 0x3003"
	space_index = poitype.rindex(' ')
	if space_index.nil? then return end #not a category path we recognise
	category = poitype.slice(space_index+1,6)
	@category_name_table[category] = poitype
	@category_path_table[category] = path
	

	File.open(path){|infile|
		while (line = infile.gets)
			line = line.strip
			if line =~ /^(\d{7,8})\b.*/ # if it looks like a zid then anything else, grab zid
				zid = $1

				# this next test says, if this is in duplicate handling but the category doesn't match, skip it (thereby removing it from this list)
#				if (@duplicateHandling.has_key?(zid) && poitype != @duplicateHandling[zid])
#					print "Removing #{zid} from #{poitype} - dupe handled\n"
#					next
#				end
				
				if @category_hash.has_key?(zid) then
					print "#{zid} in multiple categories #{category} and #{@category_hash[zid]}. Using #{@category_hash[zid]}\n"
					next
				end
				
				if category == '0x00' then
					if (@masterZenbuDataHash.delete(zid)) then
						@notforuseZIDs[zid] = 1
					end
				end
				
				@category_hash[zid] = category
			end
		end
	}
	
end

# #####################
def checkRubyVersion
	if RUBY_VERSION.to_f < 1.9 then
		print "Requires Ruby 1.9 (you have #{RUBY_VERSION})\n"
		exit
	end
end

# #####################
@override_summary_file_path = 'category_override_summary.csv'

def writeCategoryOverrideSummaryFile
	out = CSV.open(@override_summary_file_path, 'w')
	out << ['zid','name','tags', 'override_category', 'override_category_desc', 'zenbu_category', 'zenbu_category_desc']
	no_match = Hash.new(0)
	@category_hash_from_zenbu.each{|zid,category|
		if !@category_hash.has_key?(zid) then next end
		if @category_hash[zid] != category then
			no_match["#{@category_hash[zid]} #{@garmin_category_descriptions[@category_hash[zid]]} <-> #{category} #{@garmin_category_descriptions[category]}"] += 1 
			out << [zid, @masterZenbuDataHash[zid]['name'], @masterZenbuDataHash[zid]['tags'], @category_hash[zid], @garmin_category_descriptions[@category_hash[zid]], category, @garmin_category_descriptions[category]]
		end
		};nil
	out.close
=begin
#print out counts of non-matches bewteen override file and zenbu category
no_match.sort{|a,b| a[1]<=>b[1]}.each { |elem|
	print "#{elem[0]} = #{elem[1]}\n"
};nil
=end
end
# #####################
def rewriteCategoryFilesFromEditedOverrideSummaryFile

rewrite = Hash.new()
CSV.foreach(@override_summary_file_path, {:encoding => 'UTF-8', :headers => true}) do |row|
#'zid','name','tags', 'override_category', 'override_category_desc', 'zenbu_category', 'zenbu_category_desc'
	lookup = "#{row['override_category_desc']} #{row['override_category']}.txt"
	rewrite[lookup] = rewrite[lookup].nil? ? [] : rewrite[lookup] + [row['zid']]
end

category_path = '../ZenbuPOIcategories2011'
rewrite.each_pair{|category,list|
	path = category_path + '/' + category
	print "Rewriting #{category} with #{list.size} ZIDs\n"
	out = File.open(path,'w:UTF-8')
	list.sort.each{|zid|
		out.print "#{zid}\n"
	}
};nil

end
# #####################
#NZ CUSTOMISED
