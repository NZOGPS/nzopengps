use strict;
use warnings;
use feature qw "switch say";
use Carp qw(shortmess);
no if $] >= 5.018, warnings => "experimental::smartmatch";
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
my @polygons;
my @namesnot2index;
my %bysufi;
my %bylinzid;
my %bylinznumbid;
my $byid;
my %paperroads;
my %papernumbers;
my %papernumberends;
my %bynodid;

my %debug = (
	sbid			=> 0,
	OEZCheck		=> 0,	# 1 or linzid or regex e.g '3063230|1830369'
	overlaperr		=> 0, #3083691,	# 1 or linzid or regex e.g '3063230|1830369'
	olcheck			=> 0, #3083691,	# 1 or linzid or regex e.g '3063230|1830369'
	ol1numtype		=> 0, #3083691,	# 1 or linzid or regex e.g '3063230|1830369'
	rdoverlap		=> 0,
	readpapernums	=> 0,
	routecheck		=> 0,
	lnidcheck		=> 0,	# >0 is basic >1 is dump
	unnumbered		=> 0,
	addnode			=> 0,
	numberedid0		=> 0,
	rblvlchk		=> 0,
	numpresent		=> 0,
	paper_rd_check	=> 0,
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
	22 => "Walkway",
);

my %polytype = (
	0    => "--Unknown--  ",
	0x2  => "City Area    ",
	0x4  => "Military Area",
	0x5  => "Parking lot  ",
	0x6  => "Parking Bldg ",
	0x7  => "Airport      ",
	0x8  => "Shopping Cntr",
	0x9  => "Marina       ",
	0xa  => "School/Uni	  ",
	0xb  => "Hospital     ",
	0xe  => "Airport Runwy",
	0x13 => "Building     ",
	0x17 => "City Park    ",
	0x18 => "Golf Course  ",
	0x19 => "Sporting Area",
	0x1a => "Cemetery     ",
	0x28 => "Sea/Ocean    ",
	0x3c => "Large Lake   ",
	0x3d => "Large Lake   ",
	0x40 => "Small Lake   ",
	0x41 => "Smallish Lake",
	0x42 => "Major Lake   ",
	0x43 => "Major Lake   ",
	0x44 => "Large Lake   ",
	0x46 => "Major Lake   ",
	0x4a => "Map Selection",
	0x47 => "Large River  ",
	0x4E => "Plantation   ",
	0x50 => "Forest       ",
	0x51 => "Wetland/Swamp",

);
my %sufiroadname;
my %csv_x;
my %csv_y;

sub do_header {
	my $lblcfnd = 0;
	my $codepg = -1;
	while (<>){
		if (/^LblCoding=9/i) {
			$lblcfnd = 1;
		}
		if (/^CodePage=(1252)/i) {
			$codepg = $1;
		}
		if (/^\[END-IMG ID\]$/)	{ #end of header
			last;
		}
	}
	if (!$lblcfnd) {
		print "\nError: LblCoding=9 not found in header\n\n";
	}
	if ($codepg == -1) {
		print "\nError: No CodePage found in header\n\n";
	} else {
		if ($codepg != 1252) {
			print "\nError: Odd CodePage: $codepg found in header\n\n";
		}
	}
}

sub do_polygon {
	my $type;		#1
	my @label;		#2
	my $endlevel = 0;	#3
	my $cityidx;	#4
	my $lineno = $.;	#7
	my @data;
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my @nods;	#11
	my $i;
	while (<>){
		if (/^Type=(.*)$/)			{ $type = $1 };
		if (/^Label([23]?)=(.*)$/)	{ $label[$1?$1-1:0] = $2 };
		if (/^EndLevel=(.*)$/)		{ $endlevel = $1 };
		if (/^CityIdx=(.*)$/)		{ $cityidx = $1 };
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
			push @polygons,[$comment,$type,\@label,$endlevel,$cityidx,$lineno,\@x,\@y];
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
#
# comments are just stored for now. IDs are parsed into the data structure in id_check later.
#
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
	my $linznumid=-1;	#19
	my @data;
	my @numbers; #for now?
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my @nods;	#11
	my $label2;	#12
	my $numnum = 0;	#14
	my $dirindicator;	#16
	my $autonum = -1; #17
	my $dontfind = 0; #20
	my @numarray;
	my @nodarray;
	my $i;

	while (<>){
		if (/^Type=(.*)$/)			{ $type = $1 };
		if (/^Label([23]?)=(.*)$/)	{ $label[$1?$1-1:0] = $2 };
		if (/^EndLevel=(.*)$/)		{ $endlevel = $1 };
		if (/^CityIdx=(.*)$/)		{ $cityidx = $1 };
		if (/^RoadID=(.*)$/)		{ $roadid = $1 };
		if (/^RouteParam=(.*)$/)	{ $routeparam = $1 };
		if (/^Label2=(.*)$/)		{ $label2 = $1 };
		if (/^DirIndicator=(.*)$/)	{ $dirindicator = $1 };
		if (/^DontFind=Y$/)			{ $dontfind = 1 };
		

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
			for $i (@label) {
				if ( defined $1 ) { $i=~s/~\[0x[[:xdigit:]]+\]/SH/};
			}
			parsenums(\@numarray,@numbers);
			parsenods(\@nodarray,\@x,\@y,@nods);
			push @roads,[$comment,$type,\@label,$endlevel,$cityidx,$roadid,$routeparam,$lineno,\@sufi,\@x,\@y,\@numarray,\@nods,$label2,$numnum,\@nodarray,$dirindicator,$autonum,\@linzid,$linznumid,$dontfind];
#			-------------0--------1-------2-----3---------4--------5-------6-----------7--------8------9---10--11---------12----13------14-------15---------16-----------17-------18-------19
			last;
		}
	}
}
	
sub do_poi {
}

sub dump_id2 {
	my $ridptr = shift;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{'dumpid2'}) { print "dump_id2: $ridptr, $nodno, $nodn2\n" }
	my @road = @$ridptr;
	my @x = @{$road[9]};
	my @y = @{$road[10]};
	my $roadname = $road[2][0] || "unnamed";
	my $i;

	for $i (1..2) {
		if ($road[2][$i]){
			$roadname .= " / " . $road[2][$i];
		}
	} 

	if ( not defined $nodno ) {
		print shortmess();
		return;
	}
	if ( $nodn2 < 0 ){
		print "Road is $roadname, Line $road[7], Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "Road is $roadname, Line $road[7], Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
	}
}
sub dump_poly2 {
	my $pidptr = shift;
	my $ptype;
	my $ptypename;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{'dumppoly2'}) { print "dump_poly2: $pidptr, $nodno, $nodn2\n" }
	my @poly = @$pidptr;
	my @x = @{$poly[6]};
	my @y = @{$poly[7]};
	my $polyname = $poly[2][0] || "unnamed";
	my $i;
	my $space = '';
	$ptype = hex($poly[1]);
	if ( $ptype < 0x10 ) { $space = ' '; }
	$ptypename = $polytype{$ptype} || $polytype{0};
	if ( not defined $nodno ) {
		print shortmess();
		return;
	}
	if ( $nodn2 < 0 ){
		print "$poly[1]$space/$ptypename Polygon is $polyname, Line $poly[5], Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "$poly[1]$space/$ptypename Polygon is $polyname, Line $poly[5], Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
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
	my $lnidcnt;
	my $i;
#
# parse comments, set linzid, sufi, count autonumber lines, check for errors
#
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
				my $i = $1?$1-1:0;	#set id value - none->0
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

			if ($line=~/^linznumbid=(\d+)/) {
				if ($$road[19]==-1){
					$$road[19]=$1;
					$lnidcnt++;
				} else {
					if ($1==$$road[19]){
						print "Warning: multiple copies of same linznumbid${1}\n";
					} else {
						print " * Error: multiple linznumbids $1,$$road[19]\n";
					}
					dump_id2($road,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/linznumbid=/i) {
					print "Warning: odd linznumbid definition: $line\n";
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
	print sprintf "%s roads autonumbered, %s roads manually numbered, %s roads with linznumids.\n", $ancnt ? $ancnt : "No", $noancnt ? $noancnt : "no", $lnidcnt ? $lnidcnt : "no";
}

sub sort_by_id {
#
# must call id_check first to populate sufi & linzid field
# this populates @bysufi @bylinzid and @bylinznumbid
#
	my $sufi;
	my $linzid;
	my $linznumbid;
	my $idn;
	my $i = 0;
	
	if ($debug{'sbid'}){print "Sort By ID\n"};
	for my $road (@roads) {
		for $idn (0..$maxlbl-1){
			$sufi = $$road[8][$idn];
			$linzid = $$road[18][$idn];
			$linznumbid = $$road[19];

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
				if ($linznumbid > 0) {
					if ($linzid == 0){
						print "Error: Linznumbid $linznumbid on linzid=0 road\n";
						dump_id2($road,0,-1);
					}
					if (exists($bylinznumbid{$linzid}{$linznumbid})){
						if ($debug{'sbid'}){print "in sbid - another road for linzid $linzid\n"};
						push(@{$bylinznumbid{$linzid}{$linznumbid}},[$i,$idn]);
					} else {
						if ($debug{'sbid'}){print "in sbid - new linzid $linzid\n"};
						$bylinznumbid{$linzid}{$linznumbid}[0]=[$i,$idn];
					}
				}
			}
		}
		$i++;
	}
}


sub nosufiset {
	my $dec;
	
	print "Check for roads with no sufi set:\n";
	if ( exists($bysufi{-1})){
		my @nosufi = @{$bysufi{-1}};
		for my $j (@nosufi){
			$dec = oct(${$roads[$j->[0]]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( defined ${$roads[$j->[0]]}[2][0] && ${$roads[$j->[0]]}[2][0] ne "") {
					print "Type is ${$roads[$j->[0]]}[1]/$roadtype{$dec}, ";
					dump_id2($roads[$j->[0]],0,-1);
				}
			}
		}
	} else {
		print "None found\n";
	}
}


sub nolinzidset {
	my $dec;
	
	print "Check for roads with no linzid set...";
	if ( exists($bylinzid{-1})){
		print "\n"; # keep the 'none found' on the same line
		my @nolinzid = @{$bylinzid{-1}};
		for my $j (@nolinzid){
			$dec = oct(${$roads[$j->[0]]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( defined ${$roads[$j->[0]]}[2][0] && ${$roads[$j->[0]]}[2][0] ne "") {
					print "Type is ${$roads[$j->[0]]}[1]/$roadtype{$dec}, ";
					dump_id2($roads[$j->[0]],0,-1);
				}
			}
		}
	} else {
		print "none found\n"; #bug? Never appears...
	}
}


sub dump_by_id{
	while( my( $key, $value ) = each( %{$byid} ) ) {
		for my $j (@$value){
			print "$key is - $j->[0] - ${$roads[$j->[0]]}[2][0] ${$roads[$j->[0]]}[5]\n";
		}
		print "\n";
	}
}


sub overlap_err{
	my $beg   = shift; #start number
	my $lst   = shift; #end number
	my $road  = shift; #road pointer
	my $red   = shift; #reference to 'set numbers' hash
	my $isend = shift; #is this an end node? 1/2 -> which
	my $nid   = shift; #node ID - not sure if this is the best way to bring it in...
	my $nno   = shift; #numbering number
	my $x1; my $y1;
	my $lasta = $nid; 
	my $lastb = 0;
	my $lbcoord = 0;
	my $rangestr;
	my $debugthis = 0;

	$debugthis = $debug{'overlaperr'} && ( $debug{'overlaperr'} == 1 || grep {/$debug{'overlaperr'}/} $$road[18][0] );

	if ($debugthis){print "overlap_err: beg:$beg lst:$lst isend:$isend nid:$nid nno:$nno red(1):$$red[1] red(2):$$red[2] red(3):$$red[3] red(0,14): $$red[0][14]\n"}
	if ($lst == $beg){
		if ( $isend and $$red[2]){ #both nodes are ends
			# have to convolve $nid and $isend to get right end...
			if ( $isend & 1 ){
				$x1 = $$road[9][$nid];
				$y1 = $$road[10][$nid];
				if ($debugthis){print "overlap_err: isend=1 x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
					if ($debugthis){print "overlap_err: red2=1 x2,y2= $$red[0][9][$$red[1]],$$red[0][10][$$red[1]]\n"}
					if (($x1 == $$red[0][9][$$red[1]])&&($y1 == $$red[0][10][$$red[1]])){
						if ($debugthis){print "match 1,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0][14]-1){ #stored numberx < max numbers
						$lastb = $$red[0][11][$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0][9]}; #last node
					}
					if ($debugthis){print "overlap_err: red2=2 lastb=$lastb x2,y2= $$red[0][9][$lastb],$$red[0][10][$lastb]\n"}
					if (($x1 == $$red[0][9][$lastb])&&($y1 == $$red[0][10][$lastb])){
						if ($debugthis){print "match 1,2\n"}
						return 0;
					}
				}
			}
			if ( $isend & 2 ){
				if (($nno+1) < $$road[14]){ #this node numberx < max numbers
					$lasta = $$road[11][$nno+1][0];
					if ($debugthis){print "overlap_err: red2=2,isend=2,set lasta=road[11][$nid+1][0]=$lasta\n"}
				} else {
					$lasta = $#{$$road[9]}; #last node
				}
				
				$x1 = $$road[9][$lasta];
				$y1 = $$road[10][$lasta];
				if ($debugthis){print "overlap_err: isend=2 nid=$nid, road(14)=$$road[14],lasta=$lasta x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
					if ($debugthis) {print "overlap_err: red2=1 x2,y2= $$red[0][9][$$red[1]],$$red[0][10][$$red[1]]\n"}
					if (($x1 == $$red[0][9][$$red[1]])&&($y1 == $$red[0][10][$$red[1]])){
						if ($debugthis){print "match 2,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0][14]-1){ #stored numberx < max numbers
						$lastb = $$red[0][11][$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0][9]}; #last node
					}
					if($debugthis){print "overlap_err: red2=2 lastb = $lastb x2,y2= $$red[0][9][$lastb],$$red[0][10][$lastb]\n"}
					if (($x1 == $$red[0][9][$lastb])&&($y1 == $$red[0][10][$lastb])){
						if ($debugthis){print "match 2,2\n"}
						return 0;
					}
				}
			}
		}
		print "RoadID $$road[5]: number $beg already set in RoadID $$red[0][5]\n";
		$rangestr = "$beg";
	} else {
		print "RoadID $$road[5]: numbers $beg to $lst already set in RoadID $$red[0][5] (at least)\n";
		$lastb = $$red[1]; #changed from 3 to 1
		$rangestr = "$beg to $lst";
	}
	print "previous definition:\n";
	if($debugthis){print sprintf "overlap_err: node: %s\n", defined($lastb) ? $lastb : "(undefined)"}
#	$lbcoord = $$red[0][11][$lastb][0]; wrong - coord is stored, not number index
	dump_id2($$red[0],$lastb,-1);
	local $, = ',';
	print MISSFILE $$red[0][10][$lastb],$$red[0][9][$lastb],"Previous Overlap of $rangestr","$$red[0][2][0]\n";
	return (1,$lasta);
}	


sub overlap_one_numtype {
	my $beg = shift; #start number
	my $end = shift; #end number
	my $dif = shift; #difference - 2 for odd/even, 1 for both
	my $nid = shift; #ID of this node
	my $nno = shift; #current numbering number
	my $road = shift; #road ID
	my $srf = shift; #reference to 'set numbers' hash
	
	my $ste; #start of error numbers...
	my $isend = 0;
	my $i;
	my $err = 0;
	my $iserr = 0;
	my $errnod = 0;
	my $debugthis = 0;
	
	$debugthis = $debug{'ol1numtype'} && ( $debug{'ol1numtype'} == 1 || grep {/$debug{'ol1numtype'}/} $$road[18][0] );
	
	if ($debugthis){print "overlap_one_numtype: beg: $beg end: $end dif: $dif nid: $nid nno: $nno road: $$road[2][0]\n"}
	if ($debugthis) {
		print "numset is: ";
		for my $no ( sort {$a <=> $b} keys %$srf){
			print " $no,";
		}
		print "\n";
	}
	
	if ( $beg > $end ){ 
		$dif = -$dif;
	}
	$i = $beg - $dif;
	do {
		$i += $dif;
		if ($i == $beg) {$isend |= 1};
		if ($i == $end) {$isend |= 2};
		if (exists $$srf{$i}){
			if ( ! $ste ){
				if ($debugthis){print "overlap_one_numtype: setting ste to $i\n";}
				$ste = $i;
				$err++;
			}
		} else {
			if ( $ste ){
				if ($i == $beg + $dif) {$isend |= 1}; #first point was overlap, second isn't
				($iserr,$errnod) = overlap_err($ste,$i-$dif,$road,$$srf{$ste},$isend,$nid,$nno);
				if (!$iserr){
					$err--;
				}
				$ste = 0;
			}	
			$$srf{$i} = [$road,$nid,$isend,$nno];
		}
	} until ( $i == $end );

	if ($debugthis){print "overlap_one_numtype: isend is $isend\n"}	 
	$isend = 0;
	if ( $ste ){
		if ( $ste == $i){
			$isend |= 2;
		}
		if ($debugthis){print "overlap_one_numtype, end - ste: $ste i: $i isend: $isend\n"}
		($iserr,$errnod) = overlap_err($ste,$i,$road,$$srf{$ste},$isend,$nid,$nno);
		if (!$iserr){
			$err--;
		}
	}
	
	if ($debugthis){print sprintf "overlap_one_numtype returning %s, %s\n",$err || "(undef)", $errnod || "(undef)"}
	return ($err,$errnod);
}


sub overlap_one_side { 
	if ($debug{'ol1side'}){print "overlap_one_side: @_\n"}
	my @n = @_;
	my $i;
	
	given ($n[0]) {	
		when (/[N]/){
			return 0;
		}
		when (/[E]/){
			if ( $n[1]%2 || $n[1]<=0 ) {
				return 0;
			}
			if ( $n[2]%2 || $n[2]<=0 ) {
				return 0;
			}
			return overlap_one_numtype($n[1],$n[2],2,$n[3],$n[4],$n[5],$n[6]);
		}
		when (/[O]/){
			if (($n[1]+1)%2 || $n[1]<=0 ) { 
				return 0;
			}
			if (($n[2]+1)%2 || $n[2]<=0 ) {
				return 0;
			}
			return overlap_one_numtype($n[1],$n[2],2,$n[3],$n[4],$n[5],$n[6]);
		}
		when (/[B]/){
			if ( $n[1]<=0 ) { 
				return 0;
			}
			if ( $n[2]<=0 ) {
				return 0;
			}
			return overlap_one_numtype($n[1],$n[2],1,$n[3],$n[4],$n[5],$n[6]);
		}
		default {
			return 0; #no point reiterating error
		}
	}
}	

sub overlap_one_numbered_section {
	my $road;
	my $rid;
	my $nptr;
	my @numa;
	my $i;
	my $l; my $r;
	my $errnod;
	my %numset;
	my $debugthis = 0;
	
	my $roadlstp = shift;

	for my $jp (@$roadlstp){ #for each road of this id
		my $j = $jp->[0];
		if ($debug{'olcheck'} == 1){print "overlap_1ns: j = $j\n"};
		$road = $roads[$j];
		$debugthis = $debug{'olcheck'} && ( $debug{'olcheck'} == 1 || grep {/$debug{'olcheck'}/} $$road[18][0] );
		if ($debugthis){print "overlap_1ns - Road: ${$road}[2][0], RoadID: ${$road}[5]\n"}
		$rid = $$road[5];
		@numa = @{$$road[11]};

		for ($i=0; $i<$$road[14];$i++) {	# for each numbered segment
			$nptr = $numa[$i];
			($l,$errnod) = overlap_one_side(@$nptr[1..3],$$nptr[0],$i,$road,\%numset);
			local $, = ',';
			if ($l) { 
				if ($debugthis){print sprintf "overlap_1ns LHS - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
				print "conflicting definition:\n";
				dump_id2($road,$errnod,-1); 
				print "\n";
				print MISSFILE $$road[10][$errnod],$$road[9][$errnod],"Conflicting Overlap","$$road[2][0]\n";
			}
			($r,$errnod) = overlap_one_side(@$nptr[4..6],$$nptr[0],$i,$road,\%numset);
			if ($r) { 
				if ($debugthis){print sprintf "overlap_1ns RHS - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
				print "conflicting definition:\n";
				dump_id2($road,$errnod,-1); 
				print "\n";
				print MISSFILE $$road[10][$errnod],$$road[9][$errnod],"Conflicting Overlap","$$road[2][0]\n";
			}
		}
	}
}

sub overlap_check {
	my @numprm;

	print "Check for overlaps on number ranges...\n";
	while( my( $idval, $roadlstp ) = each( %{$byid} ) ) { # for each id, roadlstp is 1-3 e.g linzid, linzid2...
		if ($debug{'olcheck'} && ( $debug{'olcheck'} == 1 || grep {/$debug{'olcheck'}/} $idval )){
			print "overlap_check: id = $idval\n"
		};
		next if $idval == 0 || $idval == -1;	# ignore sufi=0 and no sufi roads
		if ( defined $bylinznumbid{$idval} ) { 
			for (values %{$bylinznumbid{$idval}}) {
				overlap_one_numbered_section($_);
			}
		} else {
			overlap_one_numbered_section($roadlstp);
		}
	}
}


sub OEZ_check_one_side { 
#	print "Check one side zero: @_\n";
	my @n = @_;
	my $error = 0;
	given ($n[0]) {
		when (/[BOEN]/){
			# do nothing - as expected
		}
		default {
			print "* Error - Unrecognised numbering type: $n[0]\n";
			$error = 1;
		}
	}
	if ($n[0] ne 'N') {
		if ($n[1]<=0) {
			print "Warning - Number[$n[4]] from $n[1] to $n[2]\n";
			$error |= 1;
		}
		if ($n[2]<=0) {
			print "Warning - Number[$n[4]] from $n[1] to $n[2]\n";
			$error |= 2;
		}
	}
	if ($n[0] eq "E"){
		if ($n[1]>0 && $n[1]%2) { # >0 to avoid reiterating for -1
			print "Warning - Number[$n[4]]: $n[1] is not even\n";
			$error |= 1;
		}
		if ($n[2]>0 && $n[2]%2) {
			print "Warning - Number[$n[4]]: $n[2] is not even\n";
			$error |= 2;
		}
	}
	if ($n[0] eq "O"){
		if (($n[1]+1)%2) { 
			print "Warning - Number[$n[4]]: $n[1] is not odd\n";
			$error |= 1;
		}
		if (($n[2]+1)%2) {
			print "Warning - Number[$n[4]]: $n[2] is not odd\n";
			$error |= 2;
		}
	}
	return $error;
}	


sub odd_even_zero_check {
	my @numa;
	my @numprm;
	my $i;
	my $nptr;
	my $l; my $r; my $stend;
	my $n1; my $n2;
	my $debugthis = 0;
	
	print "Check numbers for incorrect odd/even values...\n";
	
	for my $road (@roads) {
		$debugthis = $debug{'OEZCheck'} && ( $debug{'OEZCheck'} eq '1' || grep {/$debug{'OEZCheck'}/} $$road[18][0] );
		@numa = @{$$road[11]};
		if ($debugthis){ print "OEZCh-Label: $$road[2][0]\n" }#label
		for ($i=0; $i<$$road[14];$i++) {	
			$nptr = $numa[$i];
			if ($debugthis){ print "OEZCh index: $i nptr: @$nptr\n"}
			$l = OEZ_check_one_side(@$nptr[1..3,8,7]); #returns bitmask start = 1 end = 2
			$r = OEZ_check_one_side(@$nptr[4..6,8,7]);
			$stend = $l | $r;
			$n2 = -1;
			if ( $stend & 1 ){
				if ($debugthis){ print "OEZCh-l,r,s: $l, $r, $stend\n"}
				$n1 = $$nptr[0];
				if ( $stend & 2 ){
					if ( $i >= ($$road[14]-1)){
						$n2 = $#{$$road[9]}; #last node
					} else {
						$n2 = ${$numa[$i+1]}[0];
					}
				}
			} else { # only end 2
				if ($debugthis){ print "OEZCh-l,r,s: $l, $r, $stend\n"}
				if ( $i >= ($$road[14]-1)){
						$n1 = $#{$$road[9]}; #last node
					} else {
						$n1 = ${$numa[$i+1]}[0];
					}
			}
			if ( $stend ){			
				if ($debugthis){ print "OEZ - nodes $n1, $n2\n"}
				dump_id2($road,$n1,$n2);
				print "\n";
			}
		}
	}
}


sub routing_check {
	my @routeprm;
	my $diri;
	my $dirr;
	my $roundabout;
	my $motorway;
	my $walkway;
	my $speed7;

	print "Check correct routing: roundabouts 1-way, walkways=no cars, motorways=no bikes/peds, no speed 7\n";
	for my $road(@roads) {
		if ($debug{'routecheck'}){ print sprintf "in routing_check. Road is %s\n", $$road[2][0] ? $$road[2][0] : "(unnamed)"}

		$motorway   = (oct($$road[1])==0x1);
		$walkway    = (oct($$road[1])==0x16);
		$roundabout = (oct($$road[1])==0xc);

		if ( defined $$road[6]) { 
		if ($debug{'routecheck'}){ print sprintf "routing_check: it has routing\n"}
			@routeprm = split /,/,$$road[6];
			$speed7 =(oct($routeprm[0])==0x7);
			$dirr = $routeprm[2];
		} else {
			undef $dirr;
			undef $speed7;
		}

		$diri = $$road[16];

		if ($diri and !$dirr) {
			print "Warning - road has dirindicator set, but routing is not one-way\n";
			dump_id2($road,0,-1); 
			print "\n";
		}
		if ($dirr and !$diri) {
			print "Warning - road has one-way routing but dirindicator is not set\n";
			dump_id2($road,0,-1); 
			print "\n";
		}

		if ($speed7) {
			print "Warning - road has no speed limit (speed 7) set\n";
			dump_id2($road,0,-1); 
			print "\n";
		}

		next if !$motorway and !$walkway and !$roundabout;
		if ($roundabout) {
			if (!$dirr and !$diri){
				print "Error - roundabout does not have both dirindicator and one-way routing set\n";
				dump_id2($road,0,-1); 
				print "\n";
			}
		}
		if ($motorway) { 
			if (!$routeprm[9] or !$routeprm[10]){
				print "Error - Motorway allows Pedestrians or Bikes\n";
				dump_id2($road,0,-1); 
				print "\n";
			}
		}
		if ($walkway) { 
			if (!$routeprm[4] or !$routeprm[5] or !$routeprm[6] or !$routeprm[7] or !$routeprm[8] or !$routeprm[11]){
				print "Error - Walkway allows Vehicles\n";
				dump_id2($road,0,-1); 
				print "\n";
			}
		}
	}	
}


sub dump_by_roadid {
	my $rid = shift;
	my $all = ! defined $rid;

	print sprintf "Dump by RoadID (%s)\n",$all ? "all" : $rid;
	
	for (@roads) {
		my @x; my @y;
		my @numbers;
		my $anum;
		my @nods; 
		my $i;
		my $id;
		my $label;
		
		$id = $cmdopts{l} ? $$_[18] : $$_[8];
		my @slice =($id->[0],$id->[1],$id->[2]);
		$label = $$_[2][0] ? $$_[2][0] : "(none)";
		if ($all or ( grep /$rid/,@slice) or (grep /$rid/,$label)){
			print "\{\n";
				print "\tType:      $$_[1]";
				if ( defined $roadtype{hex($$_[1])} ){ print  "- $roadtype{hex($$_[1])}\n"} else { print "\n" }
				print sprintf "\tLabel:     $label\n";
				for $i(2..3) {
					if (defined $$_[2][$i-1] ){
						print "\tLabel$i:    $$_[2][$i-1]\n";
					}
				}	
				print "\tEndLevel:  $$_[3]\n";
				print sprintf "\tCityIdx:   %s\n", $$_[4] ? $$_[4] : "(none)";
				print sprintf "\tRoadId:    %s\n", $$_[5] ? $$_[5] : "(none)";
				print sprintf "\tRoutePrm:  %s\n", $$_[6] ? $$_[6] : "(none)";
				print "\tLine No:   $$_[7]\n";
				print "\tsufi:      $$_[8][0]\n";
				for $i(2..3) {
					if ($$_[8][$i-1]>=0){
						print "\tsufi$i:     $$_[8][$i-1]\n";
					}
				}
				print "\tlinzid:    $$_[18][0]\n";
				for $i(2..3) {
					if ($$_[18][$i-1]>=0){
						print "\tlinzid$i:   $$_[18][$i-1]\n";
					}
				}
				print "\tlinznumid: $$_[19]\n";
				print "\tNumnum:    $$_[14]\n";
				print sprintf "\tDirindic:  %s\n", $$_[16] ? $$_[16] : "-";
				print "\tComment:\n";
				for ( split/\n/,$$_[0]){
					print "\t\t$_\n";
				}
				print "\tData:\n";
					@x = @{$$_[9]};
					@y = @{$$_[10]};
					for ($i=0;$i<$#x;$i++){
						print "\t\t$x[$i],$y[$i]\n";
					}
				print "\tNumbers:\n";
					@numbers = @{$$_[11]};
					if ( @numbers ) {
						for $anum (@numbers) {
							print "\t\t";
							for (@{$anum}){
								print; print "   ";
							}
							print "\n";
						}
					}
				print "\tNods:\n";
					@nods = @{$$_[12]};
					for ($i=0;$i<$#nods/2;$i++){
						print "\t\t$nods[$i*2]: $nods[$i*2+1]\n";
					}
			print "\}\n";
		}
	}
}

sub road_overlap{
	my %nodids;
	my %done;
	my @n1;
	my $n2;
	my $rdn;
	my $i; my $j; my $k; my $l;
	my $road;
	my $x; my $y; my $m; my $n;
	
	print "Check roads for multiple interconnect points\n";
	for $road (@roads) {
		$rdn = defined $$road[2][0] ? $$road[2][0] : "(blank)";
		if ($debug{'rdoverlap'}){ print "$rdn\n" }
		@n1 = @{$$road[15]};
		for $n2 (@n1){
			if ($debug{'rdoverlap'}){ print "adding $rdn to node $$n2[1]\n" }
			push @{$nodids{$$n2[1]}},$road;
		}
	}

	while( my( $nodv, $roads ) = each( %nodids ) ) {
		if ($debug{'rdoverlap'}){ print "node $nodv\n" }
		for $i(0..$#$roads){
			for $k (0..$#{$$roads[$i][15]}){
				if ( defined $$roads[$i][15][$k][1] && $$roads[$i][15][$k][1]==$nodv ){
					$x = $$roads[$i][15][$k][3];
					$y = $$roads[$i][15][$k][4];
					$n = $$roads[$i][15][$k][0];
				}
			} 
			if ($debug{'rdoverlap'}){ print sprintf "connects to %s - $#{$$roads[$i][15]} nodes\n",defined $$roads[$i][2][0] ? $$roads[$i][2][0] : "(blank)"}
			for $j($i+1..$#$roads){
				if ($debug{'rdoverlap'}){ print sprintf "check against %s - $#{$$roads[$j][15]} nodes\n", defined $$roads[$j][2][0] ? $$roads[$j][2][0] : "(blank)"}
				for $l(0..$#{$$roads[$j][15]}){
					if ( defined $$roads[$j][15][$l][1] && $$roads[$j][15][$l][1]==$nodv ){
						$m = $$roads[$j][15][$l][0];
					}
				}
				for $k (0..$#{$$roads[$i][15]}){
					next if $$roads[$i][15][$k][1]==$nodv;
					if ($debug{'rdoverlap'}){ print "check node $$roads[$i][15][$k][0]\n" }
					for $l(0..$#{$$roads[$j][15]}){
						if ($debug{'rdoverlap'}){ print "compare to node $$roads[$j][15][$l][0]\n" }
						if ( $$roads[$i][15][$k][1]==$$roads[$j][15][$l][1]){
							if ( defined $$roads[$i][15][$k][1] && defined $$roads[$i][15][$k][0] && defined $done{$nodv}){
							if (($$roads[$i][15][$k][1]!=$nodv) && ($done{$nodv}!=$$roads[$i][15][$k][1])){
								if ($debug{'rdoverlap'}){ print "done is:$done{$nodv}\n"}
								if ((abs($$roads[$i][15][$k][0]-$n)==1) && (abs($$roads[$j][15][$l][0]-$m)==1)){
								$done{$$roads[$i][15][$k][1]}=$nodv;
								print "Roads $$roads[$i][2][0] and $$roads[$j][2][0] have two common nodes:\n";
								if ($debug{'rdoverlap'}){ print "m: $m n: $n k0: $$roads[$i][15][$k][0] l0: $$roads[$j][15][$l][0]\n" }
								print "$$roads[$i][15][$k][1] at $$roads[$i][15][$k][3],$$roads[$i][15][$k][4] and \n";
								print "$nodv at $x,$y\n\n";
							}}}
						}
					}
				}
			}
		}
	}
}


sub addnode {
	my $uref = shift;
	my $nnum = shift;
	my $numi = shift;
	my $nodi = shift;
	my $i = 0;
	
	if ($debug{'addnode'}){print "\t\taddnode: $nnum, $numi, $nodi\n";}
	while ($i <= $#{$uref}){
		last if $$uref[$i][0]>= $nnum;
		$i++;
	}	
	if ($debug{'addnode'}){print "\t\taddnode: i is $i\n";}
	if (defined($$uref[$i]) and $$uref[$i][0] == $nnum){
		if ($debug{'addnode'}){print "\t\taddnode: editing existing\n";}
		if ($numi != -1 and $$uref[$i][1] == -1){ # probably redundant , since I add the numbers first...
			if ($debug{'addnode'}){print "\t\taddnode: change uref[$i][1] to $numi\n";}
			$$uref[$i][1] = $numi;
			return;
		}
			if ($nodi != -1 and $$uref[$i][2] == -1){ 
			if ($debug{'addnode'}){print "\t\taddnode: change uref[$i][2] to $nodi\n";}
			$$uref[$i][2] = $nodi;
			return;
		}
		print "ERROR in addnode: weird combination/logic? i=$i numi=$numi nodi=$nodi uref[i] = $$uref[$1][0],$$uref[$1][1],$$uref[$1][2]\n";
	} else {
		if ($debug{'addnode'}){print "\t\taddnode: splicing at i=$i\n";}	
		splice(@{$uref},$i,0,[$nnum,$numi,$nodi]);
	} 
}


sub unnumbered_node_check {
	my $road;
	my @numbers;
	my @nods; 
	my $i;
	my $isnum;
	my $uncnt = 0;

	#	numbering is actually from a numbered node to the next routing node, not next numbered node. 
	#	so we need to check for nodes which are routing nodes after a numbering node starts numbering.
	
	print "Check for routing nodes without numbering in the middle of a numbered segment\n";
	for $road (@roads) {

		my @used; #scoped in loop to clear each iteration
		if ($debug{'unnumbered'}){print "in unnumbered_node_check. Road is $$road[2][0]\n";}
		@numbers = @{$$road[11]};
		@nods = @{$$road[15]};
		
		if ($debug{'unnumbered'}){print "Numbers\n";}
		for ($i=0;$i<=$#numbers;$i++){
			if ($debug{'unnumbered'}){print "\t$i: @{$numbers[$i]}\n";}
			addnode(\@used,$numbers[$i][0],$i,-1);
		}
		if ($debug{'unnumbered'}){print "Nods:\n";}
		for ($i=0;$i<=$#nods;$i++){
			if ($debug{'unnumbered'}){print "\t$i : $nods[$i][0] $nods[$i][1]\n";}
			addnode(\@used,$nods[$i][0],-1,$i);
		}
		if ($debug{'unnumbered'}){
			print "\tused array:\n";
			for (@used) {
				print "\t\t@{$_} $$road[9][$$_[0]]\,$$road[10][$$_[0]]\n";
			}
		}
		$i=0;
		$isnum=0;
		while ($i < $#used){
			if ($used[$i][1]!=-1){
				if ($numbers[$used[$i][1]][1] eq "N" and $numbers[$used[$i][1]][4] eq "N"){
					if ($debug{'unnumbered'}){print "Node $used[$i][1] is not numbered :\n";}
					$isnum = 0;
				} else {
					if ($debug{'unnumbered'}){print "Node $used[$i][1] is numbered :\n";}
					$isnum = 1;
				}
			} else {		#used[i][1]=-1
				if ($isnum){
					local $, = ',';
					print "Error: unnumbered node. Road is $$road[2][0]\t node $used[$i][0] at \t$$road[9][$used[$i][0]],$$road[10][$used[$i][0]]\n";
					print MISSFILE $$road[10][$used[$i][0]],$$road[9][$used[$i][0]],"Missing Numbering","$$road[2][0]\n";
					$uncnt++;
				}
			}
			$i++;
		}
	}
	print sprintf "%s incorrectly numbered node%s",$uncnt ? $uncnt : "No",$uncnt==1?"\n":"s\n";
}	


sub rbout_level_check {
	my $road;
	my @nods;
	my @routeprm;
	my $rbclass;
	my @nodid;
	my $hiclass;
	my $hiroad;
	my @hinode;

	print "Check roundabouts are high enough level...\n";
	for $road (@roads) {	# go through all roads - put node ids into %bynodid
		@nods = @{$$road[15]};
		for (@nods) {
			@nodid = @{$_};
			if($debug{'rblvlchk'}>3){
				print "@{$_}\n"
			}
			if ( defined ${$_}[1] ) {
				if ( $bynodid{${$_}[1]}){
					if($debug{'rblvlchk'}>2){
						print "Adding road id $$road[5] - ($$road[2][0]) to node ${$_}[1]\n";
					}
					push @{$bynodid{${$_}[1]}},$road;
				} else {
					$bynodid{${$_}[1]} = [$road];
				}
			}
		}
	}

	if($debug{'rblvlchk'}>1){
		print "Roads connected to node 19047:\n";
		print "$bynodid{19047}\n";
		for (@{$bynodid{19047}}){
			print "${$_}[2][0]\n";
		}
	}

	for $road (@roads) {	# go back through roads
		if(oct($$road[1])==0xc){	# this time only look at roundabouts
			@routeprm = split /,/,$$road[6];
			$rbclass = $routeprm[1];
			$hiclass = $rbclass;
			undef $hiroad;
			undef @hinode;
			if($debug{'rblvlchk'}>1){
				print "checking road id $$road[5] - class $rbclass\n"
			}			
			@nods = @{$$road[15]};
			for (@nods) {			# for each node
				@nodid = @{$_};
				if ( defined ${$_}[1]){
					for (@{$bynodid{${$_}[1]}}){
						my $road2 = $_;
						if ( defined $$road2[6] ) {
							@routeprm = split /,/,$$road2[6];
							if ( $routeprm[1] > $hiclass ){
								$hiclass = $routeprm[1];
								@hinode = @nodid;
								$hiroad = $road2;
							}
						}
					}
				}
			}
			if ($rbclass < 1){
				print "roundabout id $$road[5] class $rbclass is too low at $nodid[3],$nodid[4]\n";
				print MISSFILE "$nodid[4],$nodid[3],Low class RBout-$rbclass,Road Id $$road[5]\n";
			} else {
				if (@hinode){
					print "road id $$hiroad[5] - class $hiclass is higher class than roundabout id $$road[5] class $rbclass at $hinode[3],$hinode[4]\n";
					print MISSFILE "$hinode[4],$hinode[3],Low class RBout-$hiclass,Road Id $$road[5]\n";
				}
			}
		}
	}
}


sub lnid_check {
	my %rdids;
	my %usedrnids;
	
	print "Check LinzNumbIDs are valid...\n";
	for my $linzid (keys %bylinznumbid){
		if ($debug{'lnidcheck'}>0) {print "linzid is $linzid\n"}
		if ($debug{'lnidcheck'}>1){
			print Dumper($bylinznumbid{$linzid});
			print Dumper($bylinzid{$linzid});
		}
		for my $rdptr (@{$bylinzid{$linzid}}){
			if ($debug{'lnidcheck'}>0) {print "\troad [$rdptr->[0]], defined in linzid$rdptr->[1]\n"}
			$rdids{$rdptr->[0]} = 1;
		}
		for my $lnid (keys %{$bylinznumbid{$linzid}}){
			if ($debug{'lnidcheck'}>0) {print "\tlinznumbid is $lnid\n"}
			if ($usedrnids{$lnid}){
				if ( $usedrnids{$lnid}->[0] != $linzid ){
					print "Error! Linznumbid $lnid associated with two different Linzids\n";
					print "Linzid $linzid : ";
					dump_id2($roads[$bylinznumbid{$linzid}{$lnid}[0][0]],0,-1);
					print "Linzid $usedrnids{$lnid}->[0] : ";
					dump_id2($roads[$usedrnids{$lnid}->[1]],0,-1);
				}
			} else {
				$usedrnids{$lnid} = [$linzid,$bylinznumbid{$linzid}{$lnid}[0][0]];
			}
			for my $rdptr (@{$bylinznumbid{$linzid}{$lnid}}){
				if ($debug{'lnidcheck'}>0) {print "\t\troad [$rdptr->[0]], defined in linzid$rdptr->[1]\n"}
				if ($rdids{$rdptr->[0]}){
					delete $rdids{$rdptr->[0]}
				} else {
					print "Strange error: road [$rdptr->[0]], linzid$rdptr->[1], has linznumbid $lnid but wasn't set in bylinzid\n";
					dump_id2($roads[$rdptr->[0]],0,-1);
				}
			}
		}
		if($debug{'lnidcheck'}>1){
			print "rdids is:\n";
			print Dumper(%rdids);
		}
		if (keys %rdids){
			print "Warning: linzid $linzid has sections with linznumbids defined. The following road ids have no linznumbid\n";
			for my $key (keys %rdids) {
				dump_id2($roads[$key],0,-1);
			}
			undef %rdids;
		}
	}
	if($debug{'lnidcheck'}>0){
		print "Used rnids:\n";
		for my $rnid(sort keys %usedrnids){
			print "linznumid: $rnid, linzid: ${usedrnids{$rnid}->[0]}, road[${usedrnids{$rnid}->[1]}]\n";
		}
	}
}


sub read_roads_not_2_index {
	my $fn;
	if (defined ($cmdopts{l})){
		$fn = "$basedir\\$linzpaper\\IgnoreIndexing.txt";
	} else {
		$fn = "$basedir\\$paperdir\\IgnoreIndexing.txt";
	}
	if ( !open INF, $fn ){
		print "File $fn not found\n";
		return;
	}

	while (<INF>){
		chomp;
#		print "$_\n";
		next if $_ eq "";
		next if substr($_,1,1) eq "#";
		push @namesnot2index,$_;
	}
	close INF;
}


sub no_city_index {
	print "check for unindexed roads...\n";
	ROAD: for my $road (@roads) {
		next ROAD if oct($$road[1]) > 12; # 0xc - don't check railways, rivers, etc...
		my $idx = $$road[4];
		my $label = $$road[2][0];
		my $dontfind = $$road[20];
		my $linzid = $$road[18][0];
		if (defined($label)){
			if (!defined($idx)) {
				for (@namesnot2index) {
					if ( uc($label) eq uc ) {
						if ($linzid == 0 && !$dontfind) {
							print "Indexed don't find name: \t";
							dump_id2($road,0,-1);
							print MISSFILE "$$road[10][0],$$road[9][0],\"Indexed Do not find\",\"$$road[2][0]\"\n";
						}
						next ROAD 
					}
				} 
				next ROAD if ( $linzid == 0 && $dontfind ); # OK to not index if linzid=0 and DontFind=Y
				print "Unindexed road:\t";
					dump_id2($road,0,-1);
					print MISSFILE "$$road[10][0],$$road[9][0],\"UnIndexed road\",\"$$road[2][0]\"\n";
			} else {
				for (@namesnot2index) {
					if ( uc($label) eq uc ) {
						if ($linzid == 0 && !$dontfind) {
							print "Indexed don't find name: \t";
							dump_id2($road,0,-1);
							print MISSFILE "$$road[10][0],$$road[9][0],\"Indexed Do not find\",\"$$road[2][0]\"\n";

						}
					}
				}
				
			}
		}
	}
	
}


sub numbered_id0 {
	my $i;
	my $dec;
	my $numptr;
	my $isnum;
	
	print "Check for numbering on ".($cmdopts{l}?"Linzid":"Sufi")."=0 roads...\n";
	if ( exists(${$byid}{0})){ #of course it does, but...
		my @id0 = @{${$byid}{0}};
		for $i (@id0){
			$isnum = -1;
			$dec = oct(${$roads[$i->[0]]}[1]);
			if ($debug{'numberedid0'}){print "numbered_id0 - type is $dec\n";}
			if ( $dec <= oct("0xC") or $dec == oct("0x16")) {	#<+roundabout
				$numptr = ${$roads[$i->[0]]}[11];
				if ( @{$numptr} ) {
					for (@{$numptr}) {
					if ($debug{'numberedid0'}){print "numbered_id0 - ${$_}[1],${$_}[4] \n";}
						if (${$_}[1] ne "N" or ${$_}[4] ne "N"){ $isnum = ${$_}[0] }
						if ($isnum >= 0){
							print "Type is ${$roads[$i->[0]]}[1]/$roadtype{$dec}, ";
							dump_id2($roads[$i->[0]],$isnum,-1);
						}
					}
				}
			}
		}
	} else {
		print "None found\n";
	}
}


sub levels_check{
	my %roads_for_level_3 = (
		0x01 => 1, #major highway
		0x02 => 1, #principal highway
		0x1e => 1, #international border
	);
	my %polys_for_level_3 = (
		0x3c => 1, #large lake
		0x3d => 1, #large lake
		0x42 => 1, #major lake
		0x43 => 1, #major lake
		0x44 => 1, #large lake
		0x46 => 1, #major lake
	);
	print "check for roads of type=0 or too low a level...\n";
	for my $road (@roads) {
		my $level = $$road[3];
		my $type = $$road[1];
		if (oct($type) == 0 ) {
			print "Road has type = 0: \t";
			dump_id2($road,0,-1);
		}
		if ($level < 1) {
			print "Road on level 0 only:\t";
			dump_id2($road,0,-1);
		} else {
			if ( $roads_for_level_3{$type} && $level < 3 ){
				print "Road on level$level only:\t";
				dump_id2($road,0,-1);
			}
		}
	}	
	print "check for polygons on too low a level...\n";
	for my $poly (@polygons) {
		my $level = $$poly[3];
		my $ptype = hex($$poly[1]);
		my $ptypename = $polytype{$ptype} || $polytype{0};
		my $pname = $$poly[2][0] || "unnamed";
		if ($level < 1) {
			print "Polygon on level 0 only:\t";
			dump_poly2($poly,0,-1);
			print MISSFILE "$$poly[7][0],$$poly[6][0],$ptypename on level0 only,$pname\n";
		} else {
			if ( $polys_for_level_3{$ptype} && $level < 3 ){
				print "Polygon on level$level only:\t";
				dump_poly2($poly,0,-1);
				print MISSFILE "$$poly[7][0],$$poly[6][0],Large $ptypename on level$level only,$pname\n";
			}
		}
	}	
}
	
	
sub read_number_csv {
	my $header = "No,Latitude,Longitude,Name,Description,Symbol,LNID";
	my $hline;
	my @aline;
	my $f1 = shift;
	my $d1 = shift;
	my $fn;
	my $idformat;
	my $idval;
	my $lnid;
	my $count;
	my $numsufi;
	my $number;
	my $road;
	my $idnm;
		
	if (defined ($cmdopts{s})){
		$idnm = "Sufi";
		$idformat = "(\"?)(\\d{13})\1";
		$fn = "${d1}numbers\\$f1-numbers.csv";
	} else {
		$idnm = "Linzid";
		$idformat = "(\"?)(\\d+)\\1";
		$fn = "${d1}numbers\\$f1-numbers-linzid.csv";
	}
	
	open INF, $fn or die "Can't open file $fn\n";
	print "Reading csv numbers from $fn\n";
	$hline = <INF>;
	chomp $hline;
	if ($hline ne $header){
		print "expected header not found in CSV file. Expected:\n$header\nfound:\n$hline\n\n";
		die;
	}
	while (<INF>){
		chomp;
		@aline = split /,/;
		if ($#aline != 6){
			die "unexpected number of values in CSV file: $#aline, line $.\nLine is: $_\n";
		}
		$count++;
		if ($aline[3]=~/(\"?)(\d+) (.*)(\.\d+)?\1/){ #digits for the number, road name, optional .digits for multiples
			$number = $2;
			$road = $3;
#			print "read num csv: $number $road ($1) from $aline[3]\n";
		} else {
			die "odd address in CSV file: $aline[3] line $.\nLine is: $_\n";
		}

		if ($aline[6]=~/(\d+)/) { #digits for linz_num_id
			$lnid = $1;
				# do checks here? or below? ...
				# hmmm
		} else {
			die "Non-numeric linz_num_id in CSV file: $aline[6] line $.\nLine is: $_\n";
		}	
			
		if ($aline[4]=~/$idformat/){ 
			$idval = $2;
			if (defined($sufiroadname{$idval})){
				if ($sufiroadname{$idval} ne $road){
					print "error: different road names for $idnm $idval: $road and $sufiroadname{$idval}\n";
				}
			} else {
				$sufiroadname{$idval}=$road;
				if ($debug{'readcsvnums'}){print "read_number_csv: setting sufiroadname($idval) to $road\n";} 
			}
			if ($lnid == 0) {
				if (grep /\d{5,}/,keys %{$csv_x{$idval}} ) {
					print "Error in CSV file: Line $.: Section with no Num ID on Road ID $idval - $sufiroadname{$idval} which has sections with a Num ID\n";
				}
			} else {
				if (exists $csv_x{$idval}{0}) {
					print "Error in CSV file: Line $.: Num ID $lnid on Road ID $idval - $sufiroadname{$idval} which has sections with no Num ID\n";
				}
			}
	
			if (defined($csv_x{$idval}{$lnid}{$number})){
				print "warning: multiple definitions for $number $sufiroadname{$idval} ($idval)\n";
				print "prev: $csv_y{$idval}{$lnid}{$number},$csv_x{$idval}{$lnid}{$number} - current $aline[1],$aline[2] line $.\n";
			} else {
				$csv_x{$idval}{$lnid}{$number}=$aline[2];
				$csv_y{$idval}{$lnid}{$number}=$aline[1];
				if ($debug{'readcsvnums'}){print "read_number_csv: x,y($idval,$number) = $aline[2],$aline[1]\n";} 
			}
		} else {
			die "odd $idnm: $aline[4] line $.\nLine is: $_\n";
		}
	}

	close INF;
	$numsufi = keys %sufiroadname;
	print "$count lines, $numsufi ${idnm}s\n";
}

sub read_paper_roads {
	my $f1 = shift;
	my $d1 = shift;
	my $fn;
	my $idval;
	my @chunks;

	if (defined ($cmdopts{l})){
		$fn = "$d1$linzpaper\\${f1}.txt";
	} else {
		$fn = "$d1$paperdir\\${f1}.txt";
	}

	if ( !open INF, $fn ){
		print STDERR "Paper roads file $fn not found\n";
		return;
	}

	print "reading paper roads from $fn\n";
	while (<INF>){
		chomp;

		@chunks = split/\t/;
		$idval = $chunks[0];
		next if not defined $idval; #blank line?
		if ($idval !~ /^\d{7}(\/\d{7})?$/){
			print "Warning - in paper roads file, line $. - $idval is not a 7 digit ID, or a 7 digit / 7 digit ID/Num ID\n";
		}
		if (defined ($paperroads{$idval})) {
			print "Warning - in paper roads file - Multiple definitions for id $idval on lines $paperroads{$idval}{lnum} and $.\n";
		}
		$paperroads{$idval}{lnum}=$.;
		$paperroads{$idval}{line}=$_;
	}
	close INF;
	if ($debug{'read_paper_roads'}) {print Dumper %paperroads}
}

sub paper_rd_check{
	my $rdid;
	my $rdsegp0;
	my $idval;

	print "check if paper roads in paper road file are in map\n";
	foreach $idval ( sort ({$paperroads{$a}{lnum} <=> $paperroads{$b}{lnum}} keys %paperroads )){
		if ($debug{'paper_rd_check'}) { print "check paper roads for sufi/linzid $idval - line $paperroads{$idval}{lnum} - $paperroads{$idval}{line}\n"}
		if (defined($byid->{$idval})){
			print "ID $idval in paper roads file found in map\n";
			print "Paper road line $paperroads{$idval}{lnum} is: $paperroads{$idval}{line}\n";
		#	print Dumper $byid->{$idval};
			$rdid = ${$byid->{$idval}}[0];
			dump_id2($roads[$rdid->[0]],0,-1);
			print "\n";
		}
	}
}

sub read_paper_road_numbers {
	my $f1 = shift;
	my $d1 = shift;
	my $idval;
	my @chunks;
	my $type;
	my $start;
	my $end;
	my $i;
	my $j;
	my $error;
	my $fn;
	my $chaff;


	if (defined ($cmdopts{l})){
		$fn = "$d1$linzpaper\\${f1}PaperNumbers.txt";
	} else {
		$fn = "$d1$paperdir\\${f1}PaperNumbers.txt";
	}

	if ( !open INF, $fn ){
		print STDERR "Paper numbers file $fn not found\n";
		return;
	}

	print "reading paper numbers from $fn\n";

	while (<INF>){
		chomp;
		$i = 1;
		my @nums;
		my @ends;
		@chunks = split/\t/;
		$idval = $chunks[0];
		next if not defined $idval; #blank line?
		if ($idval !~ /^\d{7}(\/\d{7})?$/){
			print "Warning - in paper numbers file, line $. - $idval is not a 7 digit ID, or a 7 digit / 7 digit ID/Num ID\n";
		}
		if (defined ($papernumbers{$idval})) {
			print "Warning - in paper numbers file - Multiple definitions for id $idval\n";
		}

		while ($i <= $#chunks and $chunks[$i]=~/([OBE])\,(\d+),(\d+)(.*)/ ) {
			($type,$start,$end,$chaff)=($1,$2,$3,$4);
			if ($debug{'readpapernums'}){
				print "valid number line for $idval, chunk[$i] is $chunks[$i] \n";
				print "i: $i Type: $type Start: $start End: $end Chaff: \"$chaff\"\n";
			}
			if ($chaff ne '') {
				print "Warning - in paper numbers file, line $. - extra characters \"$chaff\" after end number $end\n";
				if (substr($chaff,0,1) eq ' ') { print "\tDid you use a space instead of a tab?\n"; }
			}
			if ($start<=0) {
				print "Warning - in paper numbers file, line $. - Start number $start is zero or negative\n";
				$error |= 1;
			}
			if ($end<=0) {
				print "Warning - in paper numbers file, line $. - End number $end is zero or negative\n";
				$error |= 1;
			}
			if ($type eq "E"){
				if ($start>0 && $start%2) { # >0 to avoid reiterating for -1
					print "Warning - in paper numbers file, line $. - $start is not even\n";
					$error |= 1;
				}
				if ($end>0 && $end%2) { # >0 to avoid reiterating for -1
					print "Warning - in paper numbers file, line $. - $end is not even\n";
					$error |= 1;
				}
			}
			if ($type eq "O"){
				if ($start>0 && !($start%2)) { 
					print "Warning - in paper numbers file, line $. - $start is not odd\n";
					$error |= 1;
				}
				if (($end+1)%2) {
					print "Warning - in paper numbers file, line $. - $end is not odd\n";
					$error |= 2;
				}
			}
			if ($start > $end) {
				print "Warning - in paper numbers file, line $. - $end is less than $start. Please put your numbers in ascending order\n";
				$error |= 2;
			}
			$i++;
			if (!$error){
				$j = $start;
				if ($start != $end){
					push @ends,$start;
				}
				if ($debug{'readpapernums'}){ print "adding: " };
				while ($j <= $end){
					push @nums,$j;
					if ($debug{'readpapernums'}){ print "$j " };
					$j++;
					if ($type =~/[OE]/){
						$j++;
					}
				}
				push @ends,$end;
				if ($debug{'readpapernums'}){ print "to numbers\n" };
				$papernumbers{$idval}=\@nums;
				$papernumberends{$idval}{lnum}=$.;
				$papernumberends{$idval}{line}=$_;
				$papernumberends{$idval}{nums}=\@ends;
			}
		}
		if ($i==1 && /\S/){
			print "Warning! - No valid numbering found for $_ on line $.\n";
		} 
	}
	close INF;

	if ($debug{'readpapernums'}){
		foreach $idval ( keys %papernumbers ){
			print "paper numbers for sufi/linzid ",$idval," are:\n";
			for ( @{$papernumbers{$idval}} ){
				print " $_";
			}
			print "\n";
		}
		foreach $idval ( keys %papernumberends ){
			print "paper number ends for sufi/linzid ",$idval," are:\n";
			for ( @{$papernumberends{$idval}} ){
				print " $_";
			}
			print "\n";
		}
	}
}

sub numberisinpaperfile {
	my $num = shift;
	my $idval = shift;
	return 0 if ! exists($papernumbers{$idval});
	my @paper = @{$papernumbers{$idval}};
	for ( @paper ) {
		return 1 if $num == $_;
	}
	return 0;
}

sub findnumberinseg {
	my $number = shift;
	my $odd = $number % 2;
	my $type = shift;
	my $a = shift;
	my $b = shift;
	if ($a > $b){
		my $temp = $b;
		$b = $a;
		$a = $temp;
	} 
#	print "FNIS: looking for $number in $type between $a and $b\n";

	given ($type){
		when ("N"){
			return 0;
		}
		when ("B"){
			return 1 if ($a <= $number and $number <= $b);
			return 0;
		}
		when ("E"){
			if ($odd) {
				return 0;
			}
			return 1 if ($a <= $number and $number <= $b);
			return 0;
		}
		when ("O"){
			if ( not $odd) {
				return 0;
			}
			return 1 if ($a <= $number and $number <= $b);
			return 0;
		}
	}
	return 0 # why not...
}

sub paper_number_check{
	my $idval;
	my $roads;
	my $num;
	my $rdsegptr;
	my $numseg;

	# check that paper numbers are still valid, i.e. that the range ends are not numbered in the map
	{ print "check if paper numbers in paper number file are in map\n" }
	foreach $idval ( keys %papernumberends ){
		if ($debug{'paper_number_check'}) { print "check paper number ends for sufi/linzid ",$idval,"\n" }
		for $num ( @{$papernumberends{$idval}{nums}} ){
			if ($debug{'paper_number_check'}) { print "checking: $num\n"}
			# the hard bit
			if (defined($byid->{$idval})){
				if ($debug{'paper_number_check'}) { print "ID $idval found in map\n" }
				for $rdsegptr (@{$byid->{$idval}}){
					for $numseg( @{$roads[$rdsegptr->[0]][11]} ){
						if ( findnumberinseg($num,@{$numseg}[1..3])) {
							print "Number $num found in paper number file for ID $idval on line $papernumberends{$idval}{lnum}\n";
							print "Line is: $papernumberends{$idval}{line}\n";
							dump_id2($roads[$rdsegptr->[0]],${$numseg}[0],-1);
							print "\n";
						}
					}
				}
				
			} else {
				if ($debug{'paper_number_check'}) { print "ID $idval found in paper numbers file, but not found in map\n"}
			}
		}
	}	
}

sub check_for_number_present{
	my $onerdid;
	my $onelnid;
	my $number;
	my $rdsegptr;
	my $numseg;
	my @numa;
	my $missnum = 0;
	my $missid;
	my $missthis;
	my $manual;
	my $idnm;
	
	if (defined ($cmdopts{l})){
		$idnm = "Linzid";
	} else {
		$idnm = "Sufi";
	}

	print "check for house numbers with no corresponding $idnm on the map...\n";
	foreach $onerdid ( keys %sufiroadname ){
		if (!defined($byid->{$onerdid})){
			foreach $onelnid ( keys %{$csv_x{$onerdid}}){
				for $number  ( keys %{$csv_x{$onerdid}{onelnid}}){
				if ( numberisinpaperfile($number,$onerdid)){
						delete $csv_x{$onerdid}{onelnid}{$number};
						delete $csv_y{$onerdid}{onelnid}{$number};
					}
				}
			}
			my @nums = sort{ $a <=> $b } keys %{$csv_x{$onerdid}{onelnid}};
			if ($#nums >= 0 ){
				print "$sufiroadname{$onerdid}\t$onerdid\tnot found in map.\t$nums[0]\t$csv_y{$onerdid}{onelnid}{$nums[0]},$csv_x{$onerdid}{onelnid}{$nums[0]}";
				if ($#nums > 0 ){
					print "\t$nums[$#nums]\t$csv_y{$onerdid}{onelnid}{$nums[$#nums]},$csv_x{$onerdid}{onelnid}{$nums[$#nums]}\n";
				} else {
					print "\n";
				}
# comment out next 4 lines to temporarily stop saving missing numbers on missing roads to CSV (if there are heaps of them)
				local $, = ',';
				for my $i(0..$#nums) {
					print MISSFILE $csv_x{$onerdid}{onelnid}{$nums[$i]},$csv_y{$onerdid}{onelnid}{$nums[$i]},"$nums[$i] $sufiroadname{$onerdid}","$onerdid\n";
				}
			}
		}
	}

	print "check for house numbers missing from the map...\n";
	
	foreach $onerdid ( keys %sufiroadname ){
		if (defined($byid->{$onerdid})){
			$missthis = 0;
			$manual = 0;
			foreach $onelnid ( keys %{$csv_x{$onerdid}}){
				NUM: for $number ( sort {$a <=> $b} keys %{$csv_x{$onerdid}{$onelnid}}){
				if ($debug{'numpresent'}==$onerdid){ print "numpres: $number\n"; }
				for $rdsegptr (@{$byid->{$onerdid}}){
					if ($roads[$rdsegptr->[0]][17]==-1) {$manual = 1};
					for $numseg( @{$roads[$rdsegptr->[0]][11]} ){
						next NUM if findnumberinseg($number,@{$numseg}[1..3]);
						next NUM if findnumberinseg($number,@{$numseg}[4..6]);
					}
				}
				
					next NUM if numberisinpaperfile($number,$onerdid,$onelnid);
				local $, = ',';
				print "$number $sufiroadname{$onerdid} not found. ";
				print "$idnm is $onerdid. ";
					print "LINZ Num ID is $onelnid. " if $onelnid != 0;
					print "Should be ~ $csv_y{$onerdid}{$onelnid}{$number},$csv_x{$onerdid}{$onelnid}{$number}";
				print $manual ? " *Manual*\n" : "\n";
					print MISSFILE $csv_x{$onerdid}{$onelnid}{$number},$csv_y{$onerdid}{$onelnid}{$number},"$number $sufiroadname{$onerdid}","$onerdid\n";
				$missnum++;
				if ($missthis == 0){
					$missid++;
					$missthis++;
				} 
				}
			}
		} 
	}
	print $missnum?$missnum:"No";
	print " missing number";
	print $missnum!=1?"s ":" ";
	print $missnum?("on $missid road",$missid!=1?"s\n":"\n"):"YAY!!!\n";
}

sub usage {
	die "Usage: $0 -l -s -p \\path\\mapfile.mp\n\t-l is for linzids (default)\n\t-s is for sufis (redundant)\n\t-p checks paper number files\n";
}

##### Main program starts...

getopts("lsxp", \%cmdopts);
if (!($cmdopts{s} or $cmdopts{l})){
	$cmdopts{l}=1;
}

# die "Under development - do not use!" unless $cmdopts{x};

usage() if (! defined $ARGV[0] || $ARGV[0] eq "");
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

while (<>){
	
	if (/\[IMG ID\]$/){
		do_header;
		$comment = "";
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

open(MISSFILE, '>', "${basefile}_missing.csv") or die "can't create missing csv file\n";

id_check;
routing_check;
odd_even_zero_check;
sort_by_id;

#dump_by_roadid(); # does all
#dump_by_roadid("aihop");
#dump_by_roadid(1775424);
#dump_by_roadid(15441); #parkinson - canterbury

if ($cmdopts{l}) {
	print "Using LINZ Ids\n";
	nolinzidset;
} else {
	print "Using Sufis\n";
	nosufiset;
}

levels_check;

if ($cmdopts{s}){
	$byid = \%bysufi;
} else {
	$byid = \%bylinzid;
}	

if (!$cmdopts{p}){
	numbered_id0;

	road_overlap;
	overlap_check;

	unnumbered_node_check;

	rbout_level_check;
	lnid_check;

	read_roads_not_2_index;
	no_city_index;
}

read_number_csv($basefile,$basedir);
read_paper_road_numbers($basefile,$basedir);

if ($cmdopts{p}){
	read_paper_roads($basefile,$basedir);
	paper_number_check;
	paper_rd_check;
} else {
	check_for_number_present;
}