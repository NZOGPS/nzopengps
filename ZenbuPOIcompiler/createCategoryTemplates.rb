# encoding: UTF-8

require 'rubygems'
require 'find'
require 'CSV'

#C:\Ruby192\bin\ruby createCategoryTemplates.rb
=begin
A non-destructive setup script that checks that all the category files are in place
=end
# #####################

@reporting_counts = Hash.new(0)
category_path = '../ZenbuPOIcategories'

# #####################

def createEmptyTemplateFile(path)

	if File.exists?(path) then
		print "Skipping, file already exists #{path}\n"
		return
	end
	
	File.open(path,'w:UTF-8').close
end

# #####################

categories = [
'00 Not For Maps.txt',
'Accommodation - Bed & Breakfast, Inn 0x2b02.txt',
'Accommodation - Camping, RV Park 0x2b03.txt',
'Accommodation - Hotel - Motel 0x2b01.txt',
'Accommodation 0x2b00.txt',
'Attractions - Amusement Theme Park 0x2c01.txt',
'Attractions - Arena Stadium Track Raceway 0x2c08.txt',
'Attractions - Landmark 0x2c04.txt',
'Attractions - Libraries 0x2c03.txt',
'Attractions - Museum, History 0x2c02.txt',
'Attractions - Park 0x2c06.txt',
'Attractions - Vineyard Winery 0x2c0a.txt',
'Attractions - Zoo 0x2c07.txt',
'Attractions 0x2c00.txt',
'Auto - Automobile Club 0x2f0d.txt',
'Auto - Car Dealer, Autoparts 0x2F07.txt',
'Auto - Car Rental 0x2F02.txt',
'Auto - Car Wash 0x2F0E.txt',
'Auto - Fuel, petrol stations 0x2f01.txt',
'Auto - Parking 0x2f0b.txt',
'Auto - Repair 0x2f03.txt',
'Aviation - Airport 0x2f04.txt',
'Aviation - Airport Small 0x5903.txt',
'Aviation - Heliport 0x5904.txt',
'Church place of worship 0x6404.txt',
'Entertainment - Bar 0x2d02.txt',
'Entertainment - Casino 0x2D04.txt',
'Entertainment - Cinema 0x2d03.txt',
'Entertainment - Theatre 0x2d01.txt',
'Entertainment 0x2d.txt',
'First Aid Station 0x4b00.txt',
'Food - Asian 0x2a02.txt',
'Food - Barbecue 0x2a03.txt',
'Food - Cafe, Diner 0x2a0e.txt',
'Food - Chinese 0x2a04.txt',
'Food - Deli, Bakery 0x2a05.txt',
'Food - Fast Food 0x2a07.txt',
'Food - Seafood 0x2a0b.txt',
'Food - French 0x2a0f.txt',
'Food - Italian 0x2a08.txt',
'Food - Pizza 0x2a0a.txt',
'Food 0x2a.txt',
'Govt - Community Center 0x3005.txt',
'Govt - Court 0x3004.txt',
'Govt - Fire stations 0x3008.txt',
'Govt - Hospitals 0x3002.txt',
'Govt - police 0x3001.txt',
'Govt - Public Office Government 0x3003.txt',
'Govt - School 0x2c05.txt',
'GPS Garmin Dealer 0x2f0f.txt',
'Information 0x4c.txt',
'Land - Beach 0x6604.txt',
'Land - Summit 0x6616.txt',
'Man-made place 0x6400.txt',
'Man-made - Building 0x6402.txt',
'Manmade - Cemetery 0x6403.txt',
'Marine - Boat Ramp 0x4700.txt',
'Marine - Marina 0x2F09.txt',
'Recreation - Rest Area, Picnic Area 0x4a00.txt',
'Recreation - Restroom Toilet 0x2f0c.txt',
'Recreation - Scenic Area 0x5200.txt',
'Services - Banks 0x2f06.txt',
'Services - Other 0x2f.txt',
'Services - Post office 0x2f05.txt',
'Services - Telephone 0x2f15.txt',
'Services - Travel agents 0x2f11.txt',
'Shopping - Apparel 0x2e07.txt',
'Shopping - Computer Software 0x2e0b.txt',
'Shopping - Convenience Store 0x2e06.txt',
'Shopping - Department Store 0x2e01.txt',
'Shopping - General Merchandiser 0x2e03.txt',
'Shopping - Home Furnishing 0x2e09.txt',
'Shopping - House & Garden 0x2e08.txt',
'Shopping - Pharmacy 0x2e05.txt',
'Shopping - Shopping Center 0x2e04.txt',
'Shopping - Supermarkets 0x2e02.txt',
'Shopping 0x2e.txt',
'Sport - Bowling 0x2d07.txt',
'Sport - Fitness Center 0x2d0a.txt',
'Sport - Golf 0x2d05.txt',
'Sport - Ice Skating 0x2d08.txt',
'Sport - Skiing centre, resort 0x2D06.txt',
'Sport - Swimming Area (recreation) 0x5400.txt',
'Sport - Swimming Pool (sports) 0x2d09.txt',
'Sport 0x2d00.txt',
'Trailhead 0x6412.txt',
'Transport - Ground transportation 0x2f08.txt',
'Water - Waterfall 0x6508.txt',
'Water Feature - Lake 0x650D.txt'
]

# #####################
if !(File.exists?(category_path) && FileTest.directory?(category_path)) then
	print "The defined category_path folder #{category_path} does not exist. Exiting.\n"
	exit
end

Find.find(category_path) do |path|
	if FileTest.directory?(path)
		next
	else
		
		poitype = File.basename(path,'.*')#e.g. poitype = "Public Office Government 0x3003"
		if poitype.rindex(' ').nil? then
			print "Warning! #{path} does not look like a correct category file\n"
		end
	end
end
  
categories.each{|category|
	path = category_path + '/' + category
	if File.exists?(path) then
		@reporting_counts['category_exists'] += 1
	else
		@reporting_counts['category_missing'] += 1
	end
}

print "Of #{categories.size} defined categories\n"
print "#{@reporting_counts['category_exists']} categories already exist in #{category_path}\n"
print "#{@reporting_counts['category_missing']} are missing from #{category_path}\n\n"

if @reporting_counts['category_missing'] > 0 then
	print "Create the #{@reporting_counts['category_missing']} missing category files (y/n)?"
	user_says = STDIN.gets.chomp
	if user_says == 'y' then
		categories.each{|category|
			path = category_path + '/' + category
			createEmptyTemplateFile(path)
		}
	end
end