=begin

A library that mostly copies the input to the output, except tweaking the headers, and decapitalising labels ready for 9 bit label coding.

=end
	puts "in decapitalise"

def set_paths(myio)
	myio.ipath = '..'
	myio.opath = 'outputs'
	myio.ifileadd = ''
	myio.ofileadd = ''
end

def process_polish_buffer(buffer)
	buffer.each{|line|
		if line =~ /\[IMG ID\]/ then
			line = "[IMG ID]\nCodePage=1252\nLblCoding=9"
		end
		if line =~ /Copyright=/ then
			line = 'Copyright=NZ Open GPS Map Project'
		end
		if line =~ /Label[23]?\=(.*)/ then
			labelval = $1
			if line =~ /~\[.*\]/ then
				print "Line: #{line}\n" unless line.gsub!(/~\[0x2d\]/,"~[0x04]") or line.gsub!(/~\[0x1b2c\]/,"~[0x1c]")
			end
			if not labelval =~ /[a-z]/ then #ignores lowercase in Label=...
				line.gsub!(/\w+/) do |word|					
					word.capitalize!
					if word.length > 3 and word[0,2] == "Mc" then
						word[2] = word[2].upcase
					end
					if word=='And' then 
						word.downcase!
					end
					word
				end
			end
		end
		line.gsub!('\'S ','\'s ') #decapitalise s in Bob's but leave S in O'Sheas
		
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