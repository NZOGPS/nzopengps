# encoding: UTF-8
#C:\Ruby192\bin\ruby process.rb

load 'routines.rb'
load 'category_match.rb'
checkRubyVersion

# zenbu_data_file = 'zenbusample.csv'
zenbu_data_file = 'zenbuNZ.csv'
preloadZenbuFile(zenbu_data_file)

loadCategoriesFromCategoryFiles('../ZenbuPOIcategories2011') #creates @category_hash
loadCategoriesFromZenbu #creates @category_hash_from_zenbu

print "\nDoing Polish Format (MP) output\n"

#NZ CUSTOMISED
@mpfileoutA = File.open("../NZPOIs3A.mp", "w")
@mpfileoutB = File.open("../NZPOIs3B.mp", "w")
printMPHeader(@mpfileoutA,'64000012')
printMPHeader(@mpfileoutB,'64000021')

@masterZenbuDataHash.keys.sort.each{|zid|
	if @category_hash.has_key?(zid) then
		#nzogps classified
		poitypecode = @category_hash[zid]
	else
		#zenbu classified
		poitypecode = @category_hash_from_zenbu[zid]
	end
	
	processMPpoint(zid,poitypecode)
}

@mpfileoutA.close
@mpfileoutB.close

writeCategoryOverrideSummaryFile

# #####################
print <<POIEND

Zenbu Total POIs #{@masterZenbuDataHash.size}
POIs added to maps - 
  ! Placed #{@reporting['correct']}
  ? Placed #{@reporting['incorrect']}
  - Not used #{@notforuseZIDs.size}

category_from_zenbu = #{@reporting['category_from_zenbu']}
category_from_nzogps = #{@category_hash.size}

POIEND
