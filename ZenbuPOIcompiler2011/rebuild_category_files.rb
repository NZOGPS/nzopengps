# encoding: UTF-8
#C:\Ruby192\bin\ruby process.rb

load 'routines.rb'
checkRubyVersion

print "Rewrite the category files in ZenbuPOIcategories2011 utilising the data in category_override_summary.csv? (y/n)"
user_says = STDIN.gets.chomp
if user_says == 'y' then
	rewriteCategoryFilesFromEditedOverrideSummaryFile
end

