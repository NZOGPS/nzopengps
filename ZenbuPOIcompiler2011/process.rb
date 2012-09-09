# encoding: UTF-8
#C:\Ruby192\bin\ruby process.rb

load 'routines.rb'
load 'category_match.rb'
checkRubyVersion

#optional debug file
@debug = File.open("debug.txt", "w")

# zenbu_data_file = 'zenbusample.csv'
zenbu_data_file = 'zenbuNZ.csv'
preloadZenbuFile(zenbu_data_file)

GUESS_FROM_TAGS = true #true/false. TRUE => if there is no category script will attempt to guess category from tags
loadCategoriesFromCategoryFiles('../ZenbuPOIcategories2011') #creates @categories_from_nzogps
loadCategoriesFromZenbu #creates @categories_from_zenbu

print "\nDoing Polish Format (MP) output\n"

#NZ CUSTOMISED
@mpfileoutA = File.open("../NZPOIs3A.mp", "w")
@mpfileoutB = File.open("../NZPOIs3B.mp", "w")
@mpfileoutC = File.open("../NZPOIs3C.mp", "w")
printMPHeader(@mpfileoutA,'64000012')
printMPHeader(@mpfileoutB,'64000021')
printMPHeader(@mpfileoutC,'64000022')

@masterZenbuDataHash.keys.sort.each{|zid|
	if @categories_from_nzogps.has_key?(zid) then
		#nzogps classified
		poitypecode = @categories_from_nzogps[zid]
	else
		#zenbu classified
		poitypecode = @categories_from_zenbu[zid]
	end
	
	processMPpoint(zid,poitypecode)
}

@mpfileoutA.close
@mpfileoutB.close
@mpfileoutC.close

writeCategoryOverrideSummaryFile

# #####################
print <<POIEND

Zenbu Total POIs #{@masterZenbuDataHash.size}
POIs added to maps - 
  ! Placed #{@reporting['correct']}
  ? Placed #{@reporting['incorrect']}
  - Not used #{@notforuseZIDs.size}

category_from_nzogps = #{@categories_from_nzogps.size}
category_from_zenbu = #{@reporting['category_from_zenbu']}
category_from_zenbu_category = #{@reporting['category_from_zenbu_category']}
category_from_zenbu_tags = #{@reporting['category_from_zenbu_tags']}
category_from_zenbu_default = #{@reporting['category_from_zenbu_default']}

POIEND
