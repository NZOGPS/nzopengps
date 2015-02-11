=begin

A library that mostly copies the input to the output, except tweaking the headers, and capitalising labels ready for 7 bit label coding.

=end

def process_polish_buffer(buffer)
	buffer.each{|line|
		if not (line =~ /CodePage=/i or line =~ /LblCoding=/i) then
			if line =~ /(Label[23]?\=)(.*)/ then
				label = $1
				labelval = $2
				if labelval =~ /~\[.*\]/ then
					print "Line: #{labelval}\n" unless labelval.gsub!(/~\[0x04\]/,"~[0x2d]") or labelval.gsub!(/~\[0x1c\]/,"~[0x1b2c]")
				end
				labelval.gsub!(/\w+/) do |word|					
					word.upcase! unless word =~ /Label[23]?\=/
					word
				end
				line = "#{label}#{labelval}"
			end		
			@output_file.print "#{line}\n"
		end
	}
end

def pre_processing()
  @output_file = File.open(@output_file_path, "w")
  print "Output : #{@output_file_path}\n"

end

def post_processing()
  @output_file.close
end