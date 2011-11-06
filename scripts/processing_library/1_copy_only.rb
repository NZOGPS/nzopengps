=begin

A library that simply copies the input to the output with no change

=end

def process_polish_buffer(buffer)
	buffer.each{|line|
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