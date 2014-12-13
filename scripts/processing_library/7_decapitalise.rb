=begin

A library that simply copies the input to the output with no change

=end

def process_polish_buffer(buffer)
	buffer.each{|line|
		if line =~ /\[IMG ID\]/ then
			line = "[IMG ID]\nCodePage=1252\nLblCoding=9"
		end
		if line =~ /Copyright=/ then
			line = 'Copyright=NZ Open GPS Map Project'
		end
		if line =~ /Label\=/ then
			if line =~ /~\[.*\]/ then
				print "Line: #{line}\n" unless line.gsub!(/~\[0x2d\]/,"~[0x04]") or line.gsub!(/~\[0x1b2c\]/,"~[0x1c]")
			end
			line.gsub!(/\w+/) do |word|
				word.capitalize
			end
		end
		@output_file.print "#{line}\n"
	}
end

def pre_processing()
  @output_file = File.open(@output_file_path, "w")
  print "Output : #{@output_file_path}\n"

end

def post_processing()
  @output_file.close
end