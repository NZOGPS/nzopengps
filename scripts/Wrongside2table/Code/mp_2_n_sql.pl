use strict;
use warnings;
use feature qw "switch say";
use File::Basename;
use Cwd;
use Getopt::Std;
use Data::Dumper;

my $basefile;
my $basedir;
my $basesuff;

my $paperdir = "PaperRoads";
my $linzpaper = "LinzDataService\\$paperdir";
my $nzogps = "nzopengps";
my $maxlbl = 3;
my $comment;
my @roads;
my @polys;
my @pois;
my $polyelms;
my %cities;
my @namesnot2index;
my %bysufi;
my %bylinzid;
my $byid;
my %papernumbers;

my %debug = (
	sbid			=> 0,
	overlaperr		=> 0,
	olcheck			=> 0,
	ol1numtype		=> 0,
	readpapernums	=> 0,
	unnumbered		=> 0,
	addnode			=> 0,
);

my %cmdopts=();

my %roadtype = (
	1 => "Major Hwy",
	2 => "Prcpl Hwy",
	3 => "Other Hwy",
	4 => "Arterial",
	5 => "Collector",
	6 => "Residential",
	7 => "Alleyway",
	8 => "Hwy Ramp LS",
	9 => "Hwy Ramp HS",
	10 => "Unpaved Rd",
	11 => "Connector",
	12 => "Roundabout",
);

my %sufiroadname;
my %x;
my %y;

sub do_header {
	my $found = 0;
	while (<>){
		if (/^LblCoding=9/i) {
			$found = 1;
		}
		if (/^\[END-IMG ID\]$/)	{ #end of header
			last;
		}
	}
	print "\nError: LblCoding=9 found in header\n\n" unless $found;
}

sub do_cities {
	# assume a lot, e.g. cn=x, rn = m
	while (1){
		my $ctcty;
		my $cityn = (<>); # CityN=xxx or [END-Cities]
		return if ($cityn =~ /^\[END-Cities\]$/);
		unless ($cityn =~ /^City(\d+)=(.+)/) { die "CityN=xxx not found in Cities: $cityn\n"; }
		my $ctnum = $1;
		my $ctnam = $2;
		my $regn = (<>); # RegionIdxnnn=mm 
		unless ($regn =~ /^RegionIdx(\d+)=(\d+)/) { die "RegionIdxnnn=mm not found in Cities: $regn\n"; } 
		my $ctidx = $1;
		my $ctidn = $2;
		if ( $ctidx != $ctnum ){ die "Odd - $ctidx != $ctnum - $cityn,$regn" }#maybe odd formatting as \ns not stripped
		if ( defined $cities{$ctidx}) {die "city idx $ctidx already defined before $cityn"}
		if ($ctnam =~ /(.*), (.*)/){
			$ctnam = $1;
			$ctcty = $2;
		} else {
			$ctcty = '';
		}
		$cities{$ctidx}=[$ctidn,$ctnam,$ctcty];
	}
}

sub do_polygon {
	my $comment = shift;	#0
	my $type;		#1
	my $label;		#2
	my $endlevel = 0;	#3
	my $cityidx;	#4
	my $coordstr;
	my @coords;
	my @x;	#5
	my @y;	#6
	while (<>){
		if (/^Type=(.*)$/)         { $type = $1 };
		if (/^Label=(.*)$/)        { $label = $1 };
		if (/^EndLevel=(.*)$/)     { $endlevel = $1 };
		if (/^Data(\d+)=(.*)$/)	{ # bit of work here...
			my $level = $1;
			my $coordstr = $2;
			my @xi;
			my @yi;
			if (! ($coordstr =~ s/^\(// )){
				print "Error - leading ( not found in coords- line $.\n";
			}
			if (! ($coordstr =~ s/\)$// )){
				print "Error - trailing ( not found in coords- line $.\n";
			}
			$coordstr =~ s/\),\(/\#/g;
			@coords = split(/\#/,$coordstr);
			for (@coords){
				if (/^(-*\d+\.\d+),(-*\d+\.\d+)$/){
					push @xi,$1;
					push @yi,$2;
				} else {
					print "invalid coord: $_ line $.\n";
				}
			}
			push @x, \@xi;
			push @y, \@yi;
			$polyelms++;
		}
		if (/^\[END\]$/)	{ #end of def - collect everything up and exit
			push @polys,[$comment,$type,$label,$endlevel,$cityidx,\@x,\@y];	
			last;
		}
	}
}

sub parsenums{
	my $na = shift;
	my @nums = @_;
	my @num1;
	my $i;

	for ($i=0; $i<$#nums;$i+=2) { #even elements only, since odd ones are index			
		@num1 = split /,/,$nums[$i+1];	
		if ($#num1 != 6){
			print "Error: odd number of parameters ($#num1) in numbers line: $nums[$i+1]\n";
			return;
		} else {
#			na[i] contains 7 node vals (index into coords, LHType,LHStart,LHEnd,RHType,RHStart,RHEnd, index,num string
			push @$na,[@num1,$i/2+1,$nums[$i+1]];
		}
	}
}

sub parsenods{
	my $na = shift;
	my $x = shift;
	my $y = shift;
	my @nods = @_;
	my @nod1;
	my $i;
	
	for ($i=0; $i<$#nods;$i+=2) { #even elements only, since odd ones are index			
		@nod1 = split /,/,$nods[$i+1];	
		if ($#nod1 != 2){
			print "Error: odd number of parameters ($#nod1) in nodes line: $nods[$i+1]\n";
			return;
		} else {
#			print "adding: @nod1,$$x[$nod1[0]],$$y[$nod1[0]]\n";
#			na[i]contains index into coords, node id, is_external, lon, lat
			push @$na,[@nod1,$$x[$nod1[0]],$$y[$nod1[0]]];
		}
	}
}

sub do_polyline{
	my $comment = shift;	#0
	my $type;		#1
	my @label;		#2
	my $endlevel = 0;	#3
	my $cityidx;	#4
	my $roadid;		#5
	my $routeparam;	#6
	my $lineno = $.;	#7
	my @sufi=(-1,-1,-1);	#8
	my @linzid=(-1,-1,-1);	#18
	my @data;
	my @numbers; #for now?
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my @nods;	#11
	my $label2;	#12
	my $numnum = 0;	#14
	my $dirindicator;  #16
	my $autonum = -1; #17
	my @numarray;
	my @nodarray;
	my $i;

	while (<>){
		if (/^Type=(.*)$/)         { $type = $1 };
		if (/^Label([23]?)=(.*)$/)        { $label[$1?$1-1:0] = $2 };
		if (/^EndLevel=(.*)$/)     { $endlevel = $1 };
		if (/^CityIdx=(.*)$/)      { $cityidx = $1 };
		if (/^RoadID=(.*)$/)       { $roadid = $1 };
		if (/^RouteParam=(.*)$/)   { $routeparam = $1 };
		if (/^Label2=(.*)$/)       { $label2 = $1 };
		if (/^DirIndicator=(.*)$/) { $dirindicator = $1 };

		if (/^Numbers(\d+)=(.*)$/)	{ 
			push @numbers,($1,$2);
			if ($1 > $numnum) {$numnum = $1} 
		}
		if (/^Nod(\d+)=(.*)$/)	{ push @nods,($1,$2)};
		if (/^Data(\d+)=(.*)$/)	{ # bit of work here...
			my $level = $1;
			my $coordstr = $2;
			if (! ($coordstr =~ s/^\(// )){
				print "Error - leading ( not found in coords- line $.\n";
			}
			if (! ($coordstr =~ s/\)$// )){
				print "Error - trailing ( not found in coords- line $.\n";
			}
			$coordstr =~ s/\),\(/\#/g;
			@coords = split(/\#/,$coordstr);
			for (@coords){
				if (/^(-*\d+\.\d+),(-*\d+\.\d+)$/){
					push @x,$1;
					push @y,$2;
				} else {
					print "invalid coord: $_ line $.\n";
				}
			}
		}
		if (/^\[END\]$/)	{ #end of def - collect everything up and exit
			for  $i (@label) {
				$i=~s/~\[0x[[:xdigit:]]+\]/SH/ if defined($i);
			}
			parsenums(\@numarray,@numbers);
			parsenods(\@nodarray,\@x,\@y,@nods);
			push @roads,[$comment,$type,\@label,$endlevel,$cityidx,$roadid,$routeparam,$lineno,\@sufi,\@x,\@y,\@numarray,\@nods,$label2,$numnum,\@nodarray,$dirindicator,$autonum,\@linzid];
#			--------------------0-------------1-------2----------3------------4----------5----------6----------------7---------8--- ----9----10---11-------------12--------13--------14----------15--------------16---------------17-----------18-------			
			last;
		}
	}
}
	
sub do_poi {
	my $comment = shift;	#0
	my $type;		#1
	my @label;		#2
	my $endlevel = 0;	#3
	my $cityidx;	#4
	my $iscity;		#5
	my $phone;		#6
	my $lineno = $.;	#7
	my @data;
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my $i;

	while (<>){
		if (/^Type=(.*)$/)         { $type = $1 };
		if (/^Label([23]?)=(.*)$/) { $label[$1?$1-1:0] = $2 };
		if (/^EndLevel=(.*)$/)     { $endlevel = $1 };
		if (/^CityIdx=(.*)$/)      { $cityidx = $1 };
		if (/^City=(.*)$/)         { $iscity = $1 };
		if (/^Phone=(.*)$/)        { $phone = $1 };

		if (/^Data(\d+)=(.*)$/)	{ # bit of work here...
			my $level = $1;
			my $coordstr = $2;
			if (! ($coordstr =~ s/^\(// )){
				print "Error - leading ( not found in coords- line $.\n";
			}
			if (! ($coordstr =~ s/\)$// )){
				print "Error - trailing ( not found in coords- line $.\n";
			}
			$coordstr =~ s/\),\(/\#/g;
			@coords = split(/\#/,$coordstr);
			for (@coords){
				if (/^(-*\d+\.\d+),(-*\d+\.\d+)$/){
					push @x,$1;
					push @y,$2;
				} else {
					print "invalid coord: $_ line $.\n";
				}
			}
		}
		if (/^\[END\]$/)	{ #end of def - collect everything up and exit
			push @pois,[$comment,$type,\@label,$endlevel,$cityidx,$iscity,$phone,$lineno,\@x,\@y];
#			----------------0------1-------2----------3------4--------5------6------7-----8----9----10---11-------------12--------13--------14----------15--------------16---------------17-----------18-------			
			last;
		}
	}
}


sub dump_id2 {
	my $ridptr = shift;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{'dumpid2'}) { print "dump_id2: $ridptr, $nodno, $nodn2\n" }
	my @road = @$ridptr;
	my @x = @{$road[9]};
	my @y = @{$road[10]};
	my $roadname = $road[2][0];
	my $i;
		
	if ( $roadname eq ""){
		$roadname = "unnamed";
	}
	for $i (1..2) {
		if ($road[2][$i]){
			$roadname .= " / " . $road[2][$i];
		}
	} 
	
	if ( $nodn2 < 0 ){
		print "Road is $roadname, Line $road[7], Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "Road is $roadname, Line $road[7], Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
	}
}


sub id_check {
	my $road;
	my $cmt;
	my @lines;
	my $line;
	my $autonum;
	my $ancnt;
	my $noancnt;
	my $i;
	
	# parse comments, and...
	print "Check for valid sufis/linzids...\n";
	for $road (@roads) {
		$cmt = $$road[0];
		@lines = split/\n/,$cmt;
		$autonum = 0;
		for $line (@lines){
#			print "comment line is: $line\n";

			if ($line=~/^sufi([23]?)=(\d+)/) {
				my $i = $1?$1-1:0;
				if ($$road[8][$i]==-1){
					$$road[8][$i]=$2;
				} else {
					if ($2==$$road[8][$i]){
						print "Warning: multiple copies of same sufi${1}\n";
					} else {
						print " * Error: multiple sufi${1}s $2,$$road[8][$i]\n";
					}
					dump_id2($road,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/sufi=/i) {
					print "Warning: odd sufi definition: $line\n";
					dump_id2($road,0,-1);
					print "\n";
				}
			}

			if ($line=~/^linzid([23]?)=(\d+)/) {
				my $i = $1?$1-1:0;
				if ($$road[18][$i]==-1){
					$$road[18][$i]=$2;
				} else {
					if ($2==$$road[18][$i]){
						print "Warning: multiple copies of same linzid${1}\n";
					} else {
						print " * Error: multiple linzid${1}s $2,$$road[18][$i]\n";
					}
					dump_id2($road,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/linzid=/i) {
					print "Warning: odd linzid definition: $line\n";
					dump_id2($road,0,-1);
					print "\n";
				}
			}

			if ($line=~/Auto-numbered=(\d+)/){
				if ($$road[17]==-1){
					$$road[17]=$1;
					$autonum = 1;
				} else {
					print "Warning: multiple Autonumber lines\n";
					dump_id2($road,0,-1);
				}
			}
		}

		if ($$road[18][0]==-1){
			for $i (2..$maxlbl){
				if ($$road[18][$i-1]!=-1){
					print "Warning: linzid$i is set, but linzid is not\n";
					dump_id2($road,0,-1);
				}
			}
		}

		if ($$road[8][0]==-1){
			for $i (2..$maxlbl){
				if ($$road[8][$i-1]!=-1){
					print "Warning: sufi$i is set, but sufi is not\n";
					dump_id2($road,0,-1);
				}
			}
		}

		$autonum ? $ancnt++ : $noancnt++;
	}
	print sprintf "%s roads autonumbered, %s roads manually numbered.\n", $ancnt ? $ancnt : "No", $noancnt ? $noancnt : "no";
}

sub sort_by_id {
	#must call id_check first to populate sufi & linzid field
	my $sufi;
	my $linzid;
	my $idn;
	my $i = 0;
	
	if ($debug{'sbid'}){print "Sort By ID\n"};
	for my $road (@roads) {
		for $idn (0..$maxlbl-1){
			$sufi = $$road[8][$idn];
			$linzid = $$road[18][$idn];
			if (($idn == 0) || ($sufi!=-1)){ 
				if (exists($bysufi{$sufi})){
					if ($debug{'sbid'}){print "in sbid - another road for sufi $sufi\n"}
					push(@{$bysufi{$sufi}},[$i,$idn]);
				} else {
					if ($debug{'sbid'}){print "in sbid - new sufi $sufi\n"};
					$bysufi{$sufi}[0]=[$i,$idn];
				}
			}
			if (($idn == 0) || ($linzid!=-1)){ 
				if (exists($bylinzid{$linzid})){
					if ($debug{'sbid'}){print "in sbid - another road for linzid $linzid\n"};
				push(@{$bylinzid{$linzid}},[$i,$idn]);
				} else {
					if ($debug{'sbid'}){print "in sbid - new linzid $linzid\n"};
					$bylinzid{$linzid}[0]=[$i,$idn];
				}
			}
		}
		$i++;
	}
}

sub nolinzidset {
	my $dec;
	
	print "Check for roads with no linzid set:\n";
	if ( exists($bylinzid{-1})){
		my @nolinzid = @{$bylinzid{-1}};
		for my $j (@nolinzid){
			$dec = oct(${$roads[$j->[0]]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( ${$roads[$j->[0]]}[2][0] ne "") {
					print "Type is ${$roads[$j->[0]]}[1]/$roadtype{$dec}, ";
					dump_id2($roads[$j->[0]],0,-1);
				}
			}
		}
	} else {
		print "None found\n";
	}
}

sub write_city_sql {
	my $cityidx;
	my @vals;
	my $citynam;
	my $citycty;
	my $tablename = $basefile.'_cities';
	my $ldr = ' ';
	open(SQLFILE, '>', "${tablename}.sql") or die "can't create sql file\n";
	print SQLFILE "DROP TABLE IF EXISTS ${tablename};\n";
	print SQLFILE "CREATE TABLE ${tablename} (\"cityid\"  int PRIMARY KEY,\n";
	print SQLFILE "\"label\" varchar(100),\n";
	print SQLFILE "\"city\" varchar(30),\n";
	print SQLFILE "\"rgnidx\" integer,\n";
	print SQLFILE "\"stbound\" geometry(Polygon,4167));\n";
	print SQLFILE "INSERT INTO ${tablename} ";
	print SQLFILE "(\"cityid\",\"label\",\"city\",\"rgnidx\")";
	print SQLFILE " VALUES \n";
	for $cityidx (keys %cities){
		@vals = @{$cities{$cityidx}};
		# print "city $cityidx - $vals[0] - $vals[1] - $vals[2]\n";
		$citynam = $vals[1];
		$citynam =~ s/\'/\'\'/g; #double quotes to escape them in sql
		if ($vals[2] ne '') { #manually quote name, or set it to null
			$citycty = "'$vals[2]'"
		} else {
			$citycty ='\'\'';
		}
		print SQLFILE "$ldr($cityidx,'$citynam',$citycty,$vals[0])\n";
		$ldr =',';
	}
	print SQLFILE ";\n";
}
sub write_poly_sql {
	my $poly;
	my @x;
	my @y;
	my @xi;
	my @yi;
	my $i;
	my $areaname;
	my $j;
	my $ldr = ' ';
	my $id = 1;
	my $tablename = $basefile.'_polys';
	open(SQLFILE, '>', "${tablename}.sql") or die "can't create sql file\n";
	print SQLFILE "DROP TABLE IF EXISTS ${tablename};\n";
	print SQLFILE "CREATE TABLE ${tablename} (\"polyid\"  int PRIMARY KEY,\n";
	print SQLFILE "\"label\" varchar(100),\n";
	print SQLFILE "\"type\" varchar(10));\n";
	print SQLFILE "SELECT AddGeometryColumn('','${tablename}','the_geom','4167','POLYGON',2);\n";
	print SQLFILE "INSERT INTO ${tablename} ";
	print SQLFILE "(\"polyid\",\"label\",\"type\",the_geom)";
	print SQLFILE " VALUES \n ";
	for $poly (@polys){
		@x = @{$$poly[5]};
		@y = @{$$poly[6]};

# need to write out non-numbered lines for city index checking?
		if (defined($$poly[2])){
			$areaname = $$poly[2];
			$areaname =~ s/\'/\'\'/g;
		} else {
			$areaname = '';
		}

		print SQLFILE "$ldr($id,'$areaname','$$poly[1]',";
		print SQLFILE "ST_GeomFromText('POLYGON((";
		while (@x){
			@xi = @{pop @x};
			@yi = @{pop @y};
			for ($i=0;$i<=$#xi;$i++){
				print SQLFILE "$yi[$i] $xi[$i],";
			}
			print SQLFILE "$yi[0] $xi[0]"; # close polygon
			if (@x){
				print SQLFILE "),("
			}
		}
		print SQLFILE "))',4167))\n";
		$ldr = ','; #leading char is , after first line
		$id++;
	}
	print SQLFILE ";\n";
}

sub write_line_sql {
	my $road;
	my @x;
	my @y;
	my @nums;
	my $i;
	my $rdname;
	my $cityidx;
	my $j;
	my $ldr = ' ';
	my $jmax;
	my $first = 1;
	my $tablename = "${basefile}_numberlines";
	open( SQLFILE, '>', "${tablename}.sql") or die "can't create sql file\n";
	print SQLFILE "DROP TABLE  IF EXISTS ${tablename};\n";
	print SQLFILE "CREATE TABLE ${tablename} (";
	print SQLFILE "\"gid\" serial PRIMARY KEY,\n";
	print SQLFILE "\"roadid\" integer,\n";
	print SQLFILE "\"label\" varchar(100),\n";
	print SQLFILE "\"type\" varchar(10),\n";
	print SQLFILE "\"linzid\" integer,\n";
	print SQLFILE "\"cityidx\" integer,\n";
	print SQLFILE "\"nnum\" integer,\n";
	print SQLFILE "\"ltype\" character(1),\n";
	print SQLFILE "\"lstart\" integer,\n";
	print SQLFILE "\"lend\" integer,\n";
	print SQLFILE "\"rtype\" character(1),\n";
	print SQLFILE "rstart integer,\n";
	print SQLFILE "rend integer,\n";
	print SQLFILE "the_geom geometry(LineString,4167));\n";

	print SQLFILE "INSERT INTO ${tablename} ";
	print SQLFILE "(\"roadid\",\"label\",\"type\",linzid,\"cityidx\",\"nnum\",\"ltype\",\"lstart\",\"lend\",\"rtype\",\"rstart\",\"rend\",the_geom)";
	print SQLFILE " VALUES \n";

	for $road (@roads){
		next if !defined($$road[5]); #ignore non-routing lines 
		# if ($$road[5] ~~ [9536,614,27604]){
			# print Dumper $road;
			# print "\$#nums is $#nums\n";
		# }
		@x = @{$$road[9]};
		@y = @{$$road[10]};
		@nums = @{$$road[11]};
		if (defined ($$road[2][0])){
			$rdname = $$road[2][0];
			$rdname =~ s/\'/\'\'/g;
		} else {
			$rdname = '';
		}
		if (defined $$road[4]) {
			$cityidx = $$road[4];
		} else {
			$cityidx = 0;
		}
		for ($i=0;$i<=$#nums;$i++){
		# if ($$road[5] ~~ [9536,614,27604]){
			# print "\$i is $i\n";
		# }
			print SQLFILE "$ldr('$$road[5]','$rdname','$$road[1]','$$road[18][0]',$cityidx,'$i',";
			$ldr = ','; #leading char is , after first line
			for ($j=1;$j<7;$j++){
				print SQLFILE "'$nums[$i][$j]'";
				if ($j<6){
					print SQLFILE ",";
				}
			}
			print SQLFILE ",ST_GeomFromText('LINESTRING(";
			# for geom
			$jmax = $i==$#nums?$#x:$nums[$i+1][0];
			for ($j=$nums[$i][0];$j<=$jmax;$j++){
				print SQLFILE "$y[$j] $x[$j]";
				if ($j<$jmax){
					print SQLFILE ",";
				}
			}
			print SQLFILE ")',4167))\n";
		}
	}
	print SQLFILE ";\n";
}

sub write_poi_sql {
	my $poi;
	my @x;
	my @y;
	my @nums;
	my $i;
	my $poiname;
	my $cityidx;
	my $phone;
	my $iscity;
	my $ldr = ' ';
	my $first = 1;
	my $tablename = "${basefile}_pois";
	open( SQLFILE, '>', "${tablename}.sql") or die "can't create sql file\n";
	print SQLFILE "DROP TABLE  IF EXISTS ${tablename};\n";
	print SQLFILE "CREATE TABLE ${tablename} (";
	print SQLFILE "\"gid\" serial PRIMARY KEY,\n";
	print SQLFILE "\"label\" varchar(100),\n";
	print SQLFILE "\"type\" varchar(10),\n";
	print SQLFILE "\"iscity\" varchar(10),\n";
	print SQLFILE "\"phone\" varchar(100),\n";
	print SQLFILE "\"cityidx\" integer,\n";
	print SQLFILE "the_geom geometry(Point,4167));\n";

	print SQLFILE "INSERT INTO ${tablename} ";
	print SQLFILE "(\"label\",\"type\",iscity,phone,cityidx,the_geom)";
	print SQLFILE " VALUES \n";

	for $poi (@pois){
		@x = @{$$poi[8]};
		@y = @{$$poi[9]};
		if (defined ($$poi[2][0])){
			$poiname = $$poi[2][0];
			$poiname =~ s/\'/\'\'/g;
		} else {
			$poiname = '';
		}

		if (defined $$poi[4]) {
			$cityidx = $$poi[4];
		} else {
			$cityidx = 0;
		}

		if (defined $$poi[6]) {
			$phone = $$poi[6];
		} else {
			$phone = '';
		}

		if (defined $$poi[5]) {
			$iscity = $$poi[5];
		} else {
			$iscity = '';
		}

		print SQLFILE "$ldr('$poiname','$$poi[1]','$iscity','$phone',$cityidx";
		$ldr = ','; #leading char is , after first line
		print SQLFILE ",ST_GeomFromText('POINT(";
		# for geom
		print SQLFILE "$y[0] $x[0]";
		print SQLFILE ")',4167))\n"
	}
	print SQLFILE ";\n";
}


##### Main program starts...

getopts("clsxpi", \%cmdopts);
if (!($cmdopts{s} or $cmdopts{l})){
	$cmdopts{l}=1;
}

# die "Under development - do not use!" unless $cmdopts{x};

die "No filename specified" if (!defined $ARGV[0]);
($basefile, $basedir, $basesuff) = fileparse($ARGV[0],qr/\.[^.]*/);
$basedir = Cwd::realpath($basedir);
if ($basedir =~ m|/$nzogps(.*)$|) {
	if ($1 ne ""){
		$basedir =~ s/$1//;
	}
	$basedir .= '/';
} else {
	print STDERR "$nzogps not found in path. Unlikely to find numbering files...\n";
}
$basefile = lc $basefile;

while (<>){
	
	if (/\[IMG ID\]$/){
		do_header;
		$comment = "";
	} 

	if (/\[Cities\]/){
		do_cities;
	}
	if (/;(.*)/){	#comment
		$comment .= $1."\n";
	}
	
	if (/^\[POLYGON\]$/ || /^\[RGN80\]$/){
		do_polygon;
		$comment = "";
	}
	
	if (/^\[POLYLINE\]$/ || /^\[RGN40\]$/){
		do_polyline($comment);
		$comment = "";
	}
	
	if (/^\[POI\]$/ || /^\[RGN20\]$/){
		do_poi;
		$comment = "";
	}
}

id_check;

if ($cmdopts{s}){
	$byid = \%bysufi;
} else {
	$byid = \%bylinzid;
}

if ($cmdopts{p}){
	print STDERR "Doing polygons\n";
	print STDERR "$#polys Polygons $polyelms Polygon Elements\n",
	write_poly_sql();
} else {
	print STDERR "Doing lines\n";
	write_line_sql();
}

if ($cmdopts{c}){
	my $ccnt = keys %cities;
	print STDERR "$ccnt cities\n";
	write_city_sql();
}

if ($cmdopts{i}){
	my $icnt =  $#pois;
	print STDERR "$icnt POI\n";
	write_poi_sql();
}
