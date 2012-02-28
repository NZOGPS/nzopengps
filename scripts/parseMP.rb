# encoding: UTF-8

require 'rubygems'
require 'find'
require 'csv'
require 'fileutils'

# #####################
def checkRubyVersion
	if RUBY_VERSION.to_f < 1.9 then
		print "Requires Ruby 1.9 (you have #{RUBY_VERSION})\n"
		exit
	end
end

# #####################################
def choose_tile(tile_reference)
  case tile_reference
    when "1"
  @tile = 'Northland';@bounds = [-34.039501, 174.858505, -35.572380, 171.921432];@tileregion = 1
    when "2"
  @tile = 'Auckland';@bounds = [-35.572380, 176.104294, -37.105228, 173.259384];@tileregion = 2
    when "3"
  @tile = 'Waikato';@bounds = [-37.105228, 179.505753, -38.638100, 174.095657];@tileregion = 3
    when "4"
  @tile = 'Central';@bounds = [-38.638100, 178.323730, -40.170971, 173.695114];@tileregion = 4
    when "5"
  @tile = 'Wellington';@bounds = [-40.170971, 176.974762, -41.703838, 174.561661];@tileregion = 5
    when "6"
  @tile = 'Tasman';@bounds = [-40.407970, 174.561661, -42.732010, 170.839737];@tileregion = 6
    when "7"
  @tile = 'Canterbury';@bounds = [-42.731949, 173.600006, -45.055931, 167.000000];@tileregion = 7
    when "8"
  @tile = 'Southland';@bounds = [-45.055931, 171.464127, -47.450901, 166.121124];@tileregion = 8
    when "0"
  @tile = 'sample';@bounds = [-34.039501, 179.505753, -47.450901, 166.121124];@tileregion = 0
    else
      raise ArgumentError.new("tile reference argument missing")
  # bounds = [N, E, S, W] an array of lat,lng coordinates
  end
end

# #####################################
def load_processing_library(processing_library)

  scripts_filename_array = Dir.entries('processing_library')
  scripts_filename_array.each{|script_name|
    if script_name =~ /^#{processing_library}_/ then
      print "processing_library = #{script_name}\n"
      load "processing_library/#{script_name}"
      return
    end
  }
  raise ArgumentError.new("library argument missing")

end
# #####################################
def load_paths(processing_library)
  @base = File.expand_path(File.dirname(__FILE__)) #this folder
  #print "@base = #{@base}\n"

  input_folder = File.join(@base, '..') #look for inputs in parent folder
  output_folder = File.join(@base, 'outputs') #put outputs in outputs folder
  if !File.exists?(input_folder) then raise "input folder missing #{input_folder}\n" end
  if !File.exists?(output_folder) then FileUtils.mkdir output_folder end

  @this_file = File.join(input_folder,"#{@tile}.mp")
  if !File.exists?(@this_file) then raise "input missing #{@this_file}\n" end
  
  @output_file_path = File.join(output_folder,"#{@tile}.mp")
  @reporting_file_path = File.join(output_folder,"#{@tile}-report-#{processing_library}.txt")

  @reporting_file = File.open(@reporting_file_path, "w")
  print "Parsing: #{@this_file}\n"
end
# #####################################

def run_parse
  print "Tile = #{@tile}\n"
  startTime = Time.now
  print "Start = #{startTime}\n"

  @reporting_file.print "Start = #{startTime}\n"
  
  pre_processing()
  # #####################################

  buffer = []
  File.open(@this_file).each_with_index {|line,i|
    line = line.chop
    buffer << line
    if (line =~ /^\[END(.*)/) then
      process_polish_buffer(buffer)#end of a section. process the buffer
      buffer = [] #reset buffer
    end
  }

  # #####################################
  post_processing()

  print "End = #{Time.now}\n"
  print "Processing time = #{Time.now - startTime}\n"
  @reporting_file.print "End = #{Time.now}\n"
  @reporting_file.print "Processing time = #{Time.now - startTime}\n"
end
# #####################################

=begin
choose processing routine
the processing_library files are separated for running distinct tasks
each implements 3 routines
pre_processing (runs before all processing)
post_processing (runs after all processing)
process_polish_buffer (to process one polish block of text)
=end

checkRubyVersion

#processing_library = 1 #simple template, only copies data
begin
  library = ARGV[1]
  tile = ARGV[0]
  print "library=#{library}; tile=#{tile}\n"
  
  choose_tile(tile)
  load_paths(library)
  
  load_processing_library(library)
  
rescue ArgumentError => e
  print "################################\n"
  print "Arguments missing or incorrect: #{e.message}\n"
  print "################################\n"
  print "Usage: ruby parseMP.rb tile library\n"
  print "  e.g. ruby parseMP.rb 1 1\n"
  print "  tile must be a number 1-8 referencing the tile to process 1=Northland .. 8=Southland\n"
  print "  library must be a number to choose the code library that we run from the processing_library folder"
  exit
end

run_parse
