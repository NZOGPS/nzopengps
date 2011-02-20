# encoding: UTF-8
#C:\Ruby192\bin\ruby process.rb

load 'routines.rb'

# zenbu_data_file = 'zenbusample.csv'
zenbu_data_file = 'zenbuNZ.csv'
preloadZenbuFile(zenbu_data_file)

loadCategories('../ZenbuPOIcategories')
loadZIDsNotForMaps('../ZenbuPOIcategories/00 Not For Maps.txt')
loadConfirmedGuesses('guesses_confirmed.txt')
rewriteCategoryFiles() if @reporting['confirmed_guesses'] > 0

print "\nDoing Polish Format (MP) output\n"

#NZ CUSTOMISED
@mpfileoutA = File.open("../NZPOIs3A.mp", "w")
@mpfileoutB = File.open("../NZPOIs3B.mp", "w")
printMPHeader(@mpfileoutA,'64000012')
printMPHeader(@mpfileoutB,'64000021')

@guessed_codes = CSV.open("guesses_unconfirmed.txt", "w:UTF-8", {:col_sep => "\t"})

@masterZenbuDataHash.keys.sort.each{|zid|
	if @category_hash.has_key?(zid) then
		#previously classified
		poitypecode = @category_hash[zid]
	else
		poitypecode = guessPOItypeCode(zid)
		@reporting['poi_type_guessed'] += 1
		@guessed_codes << [zid,poitypecode,@category_name_table[poitypecode],@masterZenbuDataHash[zid]].flatten
	end
	
	processMPpoint(zid,poitypecode)
}

@mpfileoutA.close
@mpfileoutB.close

# #####################
print <<POIEND

Zenbu Total POIs #{@masterZenbuDataHash.size}
POIs added to maps - 
  ! Placed #{@reporting['correct']}
  ? Placed #{@reporting['incorrect']}
  - Not used #{@notforuseZIDs.size}

poi_type_guessed = #{@reporting['poi_type_guessed']}
confirmed_guesses = #{@reporting['confirmed_guesses']}

POIEND

if @reporting['poi_type_guessed'] > 0 then
	print "To finalise the guessed POI type codes\n"
	print "check the content of guesses_unconfirmed.txt\n"
	print "edit the type code in column 2 if necessary\n"
	print "copy into guesses_confirmed.txt\n"
	print "Run this script one more time\n"
end