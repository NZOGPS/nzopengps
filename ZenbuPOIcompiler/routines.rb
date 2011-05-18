# encoding: UTF-8

require 'rubygems'
require 'find'
require 'CSV'

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
	
	CSV.foreach(path, {:encoding => 'UTF-8'}) do |row| #:headers => true would skip the first row but will return rows as FasterCSV::Row objects instead of Arrays = PITA
	  zid = row[0]
 	  row.slice!(0) # remove zid from array as don't need it on right side of hash
	  @masterZenbuDataHash[zid] = row unless zid == 'zid'
	  
	  #now masterZenbuDataHash['zid'][n] is field (n-1) eg. n=1=name and n=2=tags so masterZenbuDataHash['zid'][0] is the name
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
#  0    1    2     3            4          5           6         7         8         9           10              11         12         13

begin
	
	if !@masterZenbuDataHash.has_key?(zid)
		# p "#{zid} not in data file\n"
		return
	end

	label = "#{@masterZenbuDataHash[zid][0]}"
	label = fix_special_chars(label)
	label = label.slice(0,80) #only first 80 characters allowed, Garmin limitation
	
	tags = "#{@masterZenbuDataHash[zid][1]}"
	tags = fix_special_chars(tags)
	
	website = "#{@masterZenbuDataHash[zid][2]}"
	phone = tidyPhoneNumber(zid,@masterZenbuDataHash[zid][4])
	
	opening = "#{@masterZenbuDataHash[zid][5]}"
	opening = fix_special_chars(opening)
	
	#some customised markup for particular local entries
	label = processPOITypeSpecificRules(label,tags,website,poitypecode,opening)
	
	address = "#{@masterZenbuDataHash[zid][3]}"
	address = processStandardAddressAbbreviations(address)
	
	longitude = @masterZenbuDataHash[zid][6]
	if longitude == "0.0" then return end
	longitude = sprintf("%.5f",longitude)
	latitude = @masterZenbuDataHash[zid][7]
	if latitude == "0.0" then return end
	latitude = sprintf("%.5f",latitude)
	
#NZ CUSTOMISED
# let's also skip the Chatham Islands POIs, technically NZ but no use for us (and anything else outside standard NZ lon/lat)
# Chatham Islands points have long of -176 (correctly displays in google maps...)
# range long in linz is 166.71 to 178.55
# range lat in linz is -46 to -34 - but Stewart Island is at 47.32
	if latitude.to_f < -47.32 || latitude.to_f > -34 || longitude.to_f < 166 || longitude.to_f > 179 then return end
	
	# look for black, orange, blue markers
	correctly_placed = @masterZenbuDataHash[zid][9]
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

def guessPOItypeCode(zid)
#attempt to best guess a POI type code from name and tags
		thistags = @masterZenbuDataHash[zid][1]
		thisname = @masterZenbuDataHash[zid][0]
		
		if thistags =~ /toilet/i
			category = '0x2f0c'
		elsif thistags =~ /restaurant/i || thisname =~ /restaurant/i
			if thistags =~ /(thai|japanese)/i
				category = '0x2a02'
			elsif thistags =~ /chinese/i
				category = '0x2a04'
			elsif thistags =~ /french/i
				category = '0x2a0f'
			elsif thistags =~ /italian/i
				category = '0x2a08'
			else
				category = '0x2a'
			end
		elsif thistags =~ /b\&b/i
			category = '0x2b02'
		elsif thistags =~ /motel/i
			category = '0x2b01'
		elsif thistags =~ /hotel/i
			category = '0x2b01'
		elsif thistags =~ /accommodation/i
			category = '0x2b00'
		elsif thistags =~ /Camping/i
			category = '0x2b03'
		elsif thistags =~ /bakery/i
			category = '0x2a05'
		elsif thistags =~ /museum/i
			category = '0x2c02'
		elsif thistags =~ /Funeral director/i
			category = '0x2f'
		elsif thistags =~ /library/i
			category = '0x2c03'
		elsif thistags =~ /(\bbank\b|\batm\b)/i
			category = '0x2f06'
		elsif thistags =~ /winery/i
			category = '0x2c0a'
		elsif thistags =~ /travel agent/i
			category = '0x2f11'
		elsif thistags =~ /car rental/i
			category = '0x2F02'
		elsif thistags =~ /\bbar\b/i
			category = '0x2d02'
		elsif thistags =~ /cafe/i #cafes should look for é too
			category = '0x2a0e'
		elsif thistags =~ /parking/i
			category = '0x2f0b'
		elsif thistags =~ /marina/i
			category = '0x2F09'
		elsif thistags =~ /\b(church|mosque)\b/i
			category = '0x6404'
		elsif thistags =~ /\bpark\b/i
			category = '0x2c06'
		elsif thistags =~ /Speed Camera/i
			category = '00 Not For Maps'
		elsif thistags =~ /swimming pool/i
			category = '0x2d09'
		elsif thistags =~ /Petrol Station/i
			category = '0x2f01'
		elsif thistags =~ /supermarket/i
			category = '0x2e02'
		elsif thistags =~ /cemetery/i
			category = '0x6403'
		elsif thistags =~ /fast food/i
			category = '0x2a07'
		elsif thistags =~ /visitor information/i
			category = '0x4c'
		elsif thistags =~ /antique/i
			category = '0x2e'
		elsif thistags =~ /fresh fruit/i
			category = '0x2e'
		elsif thistags =~ /butcher/i
			category = '0x2e'
		elsif thistags =~ /liquor.*beer/i
			category = '0x2e'
		elsif thistags =~ /\b(clothes|footwear|shoes|Menswear)\b/i
			category = '0x2e07'
		elsif thistags =~ /\b(furniture|beds)\b/i
			category = '0x2e09'
		elsif thistags =~ /convenience store/i
			category = '0x2e'
		elsif thistags =~ /superette/i
			category = '0x2e'
		elsif thistags =~ /boat ramp/i
			category = '0x4700'
		elsif thistags =~ /hairdresser/i
			category = '0x2f'
		elsif thistags =~ /car dealer/i
			category = '0x2F07'
		elsif thistags =~ /ski field/i
			category = '0x2D06'
		elsif thistags =~ /take-?away/i # || thisname =~ /take[\s-]?away/i #name or tags has takeaway
			category = '0x2a07'
		elsif thistags =~ /pharmacy/i
			category = '0x2e05'
		elsif thistags =~ /clothing/i
			category = '0x2e07'
		elsif thistags =~ /rest area/i
			category = '0x4a00'
		else
			category = '0x2f' #other services, catch all
		end
		
		return category
end

# #####################

@category_hash = Hash.new
@category_name_table = Hash.new
@category_path_table = Hash.new

def loadCategories(p)
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
def loadConfirmedGuessesIfRequired(path)
	
	if File.exists?(path) then
		previously_guessed_categories = CSV.read(path, {:encoding => 'UTF-8', :col_sep => "\t"})
		if previously_guessed_categories.size > 0
			print "Use previously guessed categories (#{previously_guessed_categories.size} entries) (y/n)?" #file 'guessed_categories.txt'
			user_says = STDIN.gets.chomp
			if user_says == 'y' then
				loadConfirmedGuesses(path)
			end
		end
	end
	
end
# #####################
def loadConfirmedGuesses(path)
	print "Loading confirmed category guesses... "
		
	if !File.exists?(path) then #create the guess file if it doesn't exist
		File.open(path,'w:UTF-8').close
	end
	
	#print "external_encoding #{File.open(path, 'r:UTF-8').external_encoding}\n"
	CSV.foreach(path, {:encoding => 'UTF-8', :col_sep => "\t"}) do |row|
		zid = row[0]
		category = row[1]

		if @category_hash.has_key?(zid) then
			#print "#{zid} in multiple categories #{category} and #{@category_hash[zid]}. Using #{@category_hash[zid]}\n"
			#just skip it, already confirmed
			next
		end

		@category_hash[zid] = category
		@reporting['confirmed_guesses'] += 1
	end

	print "#{@reporting['confirmed_guesses']}\n"
end

# #####################
def rewriteCategoryFiles()
	
	print "Updating category files... "
	output_category_files_pointer = Hash.new
	
	#open all the files for each category
	@category_path_table.each_pair{|category,path|
		output_category_files_pointer[category] = CSV.open(path, 'w')
	}
	
	#go through the entire list of assigned categories (including guesses)
	@category_hash.each_pair{|zid,category|
		output_category_files_pointer[category] << [zid]
	}
end

# #####################
@guessed_categories = Hash.new
def rewriteGuessFile(guess_file)

	#now we'll write out the guess_file, but making sure we don't clobber any existing guesses that haven't been confirmed yet

	if File.exists?(guess_file) then
		CSV.foreach(guess_file, {:encoding => 'UTF-8', :col_sep => "\t"}) do |row|
			zid = row[0]
			category = row[1]

			if @category_hash.has_key?(zid) then
				#already confirmed so skip it
				next
			end

			@guessed_categories[zid] = category
		end
	end

	guess_file_out = CSV.open(guess_file, "w:UTF-8", {:col_sep => "\t"})
	@guessed_categories.each{|zid,poitypecode|
		guess_file_out << [zid,poitypecode,@category_name_table[poitypecode],@masterZenbuDataHash[zid]].flatten
	}
end
# #####################
#NZ CUSTOMISED
