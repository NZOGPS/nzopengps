require 'optparse'
require 'optparse/time'
require 'optparse/date'
require 'progressbar'
require 'pp'

DEBUG=false
options = {:table => nil, :id => nil, :query => nil, :label => "running",}

def do_options(options)
print "do_options\n" if DEBUG
	parser = OptionParser.new do|opts|
		opts.banner = "Usage: #{$0} [options]"
		
		opts.on('-t', '--table TABLE','table to process') do |table|
			options[:table] = table;
		end

		opts.on('-i', '--id ID', 'key id') do |id|
			options[:id] = id
		end

		opts.on('-q', '--query QUERY', 'query') do |query|
			options[:query] = query
		end

		opts.on('-l', '--label LABEL', 'label') do |label|
			options[:label] = label
		end

		opts.on('-h', '--help', 'Displays Help') do
			puts opts
			exit
		end
	end
	parser.parse!
end

def pg_connect()
	begin
		require 'pg'
	rescue LoadError
		puts "Gem missing. Please run: gem install pg\n" 
		exit
	end

	begin
		require 'yaml'
	rescue LoadError
		puts "Gem missing. Please run: gem install yaml\n" 
		exit
	end

	raw_config = File.read("config.yml")
	app_config = YAML.load(raw_config)

	begin
		@conn = PG.connect(app_config['postgres']['host'], 5432, "", "", "nzopengps", "postgres", app_config['postgres']['password'])
		rescue
			if $! == 'Invalid argument' then
			retry #bollocks error
		end

		print "An error occurred connecting to database: ",$!, "\nTry again (y/n)?"
		user_says = STDIN.gets.chomp
		if user_says == 'y' then
			retry
		else
			print "Could not connect to database. Exiting.\n"
			exit 77
		end
	end
	print "Connected\n" if DEBUG
end

def doit(options)
print options.to_s+"\n" if DEBUG
#return
	rs = @conn.exec ("SELECT #{options[:id]} FROM #{options[:table]}")
	rdscnt = rs.num_tuples
	print "rdscnt is #{rdscnt}\n" if DEBUG
	within_set=0

	if rdscnt > 0 then
		@pbar = ProgressBar.create(:title=>options[:label], :total=>rdscnt, :length=>100)
		rs.each do |eachval|
			print "eachval is: " + eachval.to_s + "\n" if DEBUG
			sqlcmd = "update #{options[:table]} sqtbln #{options[:query]} where sqtbln.#{options[:id]} = #{eachval[options[:id]]}"
			print sqlcmd+"\n" if DEBUG
			rs2 = @conn.exec (sqlcmd)
			@pbar.increment
			within_set += rs2.cmd_tuples
		end
	end
	print "#{within_set} lines processed\n" if DEBUG
end

do_options(options)
pg_connect()
doit(options)