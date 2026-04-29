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
#my @roads;
my @roadsh;
my @polygons;
my @namesnot2index;
my %bylinzid;
my %bylinznumbid;
my $byid;
my %paperroads;
my %papernumbers;
my %papernumberends;
my %bynodid;

my %csvroadname;
my %csv_x;
my %csv_y;

my %debug = (
	sbid			=> 0,
	dumpid3			=> 0,
	OEZCheck		=> 0,	# 1 or linzid or regex e.g '3063230|1830369'
	OEZCheck1s		=> 0,
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
	0x1  => "Large Urban  ",
	0x2  => "City Area    ",
	0x4  => "Military Area",
	0x5  => "Parking lot  ",
	0x6  => "Parking Bldg ",
	0x7  => "Airport      ",
	0x8  => "Shopping Cntr",
	0x9  => "Marina       ",
	0xa  => "School/Uni	  ",
	0xb  => "Hospital     ",
	0xc  => "Industrial   ",
	0xe  => "Airport Runwy",
	0x13 => "Building     ",
	0x17 => "City Park    ",
	0x18 => "Golf Course  ",
	0x19 => "Sporting Area",
	0x1a => "Cemetery     ",
	0x28 => "Sea/Ocean    ",
	0x3c => "Large Lake   ",
	0x3d => "Large Lake   ",
	0x33 => "Medium Lake  ",
	0x40 => "Small Lake   ",
	0x41 => "Smallish Lake",
	0x42 => "Major Lake   ",
	0x43 => "Major Lake   ",
	0x44 => "Large Lake   ",
	0x46 => "Major Lake   ",
	0x4a => "Map Selection",
	0x47 => "Large River  ",
	0x48 => "Medium River ",
	0x4E => "Plantation   ",
	0x50 => "Forest       ",
	0x51 => "Wetland/Swamp",
);


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
	my %thispoly;
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
			%thispoly = (
				comment		=> $comment,
				type		=> $type,
				label		=> \@label,
				endlevel	=> $endlevel,
				cityidx		=> $cityidx,
				lineno		=> $lineno,
				x			=> \@x,
				y			=> \@y,
			);

#			push @polygons,[$comment,$type,\@label,$endlevel,$cityidx,$lineno,\@x,\@y];
			push @polygons, \%thispoly;
			last;
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
	my @dummy=(-1,-1,-1);	#8
	my @linzid=(-1,-1,-1);	#18
	my $linznumbid=-1;	#19
	my @data;
	my @numbers; #for now?
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my @nods;	#11
	my $numnum = 0;	#14
	my $dirindicator;	#16
	my $autonum = -1; #17
	my $dontfind = 0; #20
	my @numarray;
	my @nodarray;
#	my $i;
	my %thisrd;

	while (<>){
		if (/^Type=(.*)$/)			{ $type = $1 };
		if (/^Label([23]?)=(.*)$/)	{ $label[$1?$1-1:0] = $2 };
		if (/^EndLevel=(.*)$/)		{ $endlevel = $1 };
		if (/^CityIdx=(.*)$/)		{ $cityidx = $1 };
		if (/^RoadID=(.*)$/)		{ $roadid = $1 };
		if (/^RouteParam=(.*)$/)	{ $routeparam = $1 };
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
			for my $i (@label) {
				if ( defined $1 ) { $i=~s/~\[0x[[:xdigit:]]+\]/SH/};
			}
			parsenums(\@numarray,@numbers);
			parsenods(\@nodarray,\@x,\@y,@nods);
			
			%thisrd = (
				lineno		=> $lineno,
				comment		=> $comment,
				type		=> $type,
				label		=> \@label,
				endlevel	=> $endlevel,
				cityidx		=> $cityidx,
				roadid		=> $roadid,
				x			=> \@x,
				y			=> \@y,
				numarray	=> \@numarray,
				nods		=> \@nods,
				numnum		=> $numnum,
				nodarray	=> \@nodarray,
				dirindic	=> $dirindicator,
				autonum		=> $autonum,
				routeparam	=> $routeparam,
				linzid		=> \@linzid,
				linznumbid	=> $linznumbid,
				dontfind	=> $dontfind
			);

			push @roadsh,\%thisrd;

#			push @roads,[$comment,$type,\@label,$endlevel,$cityidx,$roadid,$routeparam,$lineno,\@dummy,\@x,\@y,\@numarray,\@nods,$label2,$numnum,\@nodarray,$dirindicator,$autonum,\@linzid,$linznumbid,$dontfind];
#			-------------0--------1-------2-----3---------4--------5-------6-----------7--------8------9---10--11---------12----13------14-------15---------16-----------17-------18-------19
			last;
		}
	}
}


sub do_poi {
}


sub dump_id3 {
	my $ridptr = shift;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{dumpid3}) { print "dump_id3: $ridptr, $nodno, $nodn2\n" }

	my @x = @{$ridptr->{x}};
	my @y = @{$ridptr->{y}};
	my $roadname = $ridptr->{label}[0] || "unnamed";
#	my $i;

	for my $i (1..2) {
		if ($ridptr->{label}[$i]){
			$roadname .= " / " . $ridptr->{label}[$i];
		}
	} 

	if ( not defined $nodno ) {
		print shortmess();
		return;
	}

	if ( $nodn2 < 0 ){
		print "Road is $roadname, Line $ridptr->{lineno}, Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "Road is $roadname, Line $ridptr->{lineno}, Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
	}
}


sub dump_poly2 {
	my $pidptr = shift;
	my $ptype;
	my $ptypename;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{'dumppoly2'}) { print "dump_poly2: $pidptr, $nodno, $nodn2\n" }
#	my $polyhp = @$pidptr;
	my @x = @{$pidptr->{x}};
	my @y = @{$pidptr->{y}};
my $polyname = $pidptr->{label}[0] || "unnamed";
	my $i;
	my $space = '';
	$ptype = hex($pidptr->{type});
	if ( $ptype < 0x10 ) { $space = ' '; }
	$ptypename = $polytype{$ptype} || $polytype{0};
	if ( not defined $nodno ) {
		print shortmess();
		return;
	}
	if ( $nodn2 < 0 ){
		print "$ptype$space/$ptypename Polygon is $polyname, Line $pidptr->{lineno}, Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "$ptype$space/$ptypename Polygon is $polyname, Line $pidptr->{lineno}, Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
	}
}


sub id_check {
#	my $roadhp;
	my $cmt;
	my @lines;
#	my $line;
	my $autonum;
	my $ancnt;
	my $noancnt;
	my $lnidcnt;
#	my $i;
#
# parse comments, set linzid, count autonumber lines, check for errors
#
	print "Check for valid linzids...\n";
#	print Dumper(@roadsh);
	for my $roadhp (@roadsh) {
		$cmt = $roadhp->{comment};
		@lines = split/\n/,$cmt;
		$autonum = 0;
		for my $line (@lines){
#			print "comment line is: $line\n";

			if ($line=~/^linzid([23]?)=(\d+)/) {
				my $i = $1?$1-1:0;	#set id value - none->0
				if ($roadhp->{linzid}[$i]==-1){
					$roadhp->{linzid}[$i]=$2;
				} else {
					if ($2==$roadhp->{linzid}[$i]){
						print "Warning: multiple copies of same linzid${1}\n";
					} else {
						print " * Error: multiple linzid${1}s $2,$roadhp->{name}[$i]\n";
					}
					dump_id3($roadhp,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/linzid=/i) {
					print "Warning: odd linzid definition: $line\n";
					dump_id3($roadhp,0,-1);
					print "\n";
				}
			}

			if ($line=~/^linznumbid=(\d+)/) {
				if ($roadhp->{linznumbid}==-1){
					$roadhp->{linznumbid}=$1;
					$lnidcnt++;
				} else {
					if ($1==$$roadhp->{linznumbid}){
						print "Warning: multiple copies of same linznumbid${1}\n";
					} else {
						print " * Error: multiple linznumbids $1,$roadhp->{linznumbid}\n";
					}
					dump_id3($roadhp,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/linznumbid=/i) {
					print "Warning: odd linznumbid definition: $line\n";
					dump_id3($roadhp,0,-1);
					print "\n";
				}
			}

			if ($line=~/Auto-numbered=(\d+)/){
				if ($roadhp->{autonum}==-1){
					$roadhp->{autonum}=$1;
					$autonum = 1;
				} else {
					print "Warning: multiple Autonumber lines\n";
					dump_id3($roadhp,0,-1);
				}
			}
		}

		if ($roadhp->{linzid}[0]==-1){
			for my $i (2..$maxlbl){
				if ($roadhp->{linzid}[$i-1]!=-1){
					print "Warning: linzid$i is set, but linzid is not\n";
					dump_id3($roadhp,0,-1);
				}
			}
		}

		$autonum ? $ancnt++ : $noancnt++;
	}
	print sprintf "%s roads autonumbered, %s roads manually numbered, %s roads with linznumbids.\n", $ancnt ? $ancnt : "No", $noancnt ? $noancnt : "no", $lnidcnt ? $lnidcnt : "no";
}

sub sort_by_id {
#
# must call id_check first to populate linzid field
# this populates @bylinzid and @bylinznumbid
#
	my $linzid;
	my $linznumbid;
#	my $idn;
	my $i = 0;
	
	if ($debug{'sbid'}){print "Sort By ID\n"};
	for my $roadhp (@roadsh) {
		for my $idn (0..$maxlbl-1){
			$linzid = $roadhp->{linzid}[$idn];
			$linznumbid = $roadhp->{linznumbid};

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
						dump_id3($roadhp,0,-1);
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


sub nolinzidset {
	my $type;
	my $dec;
	
	print "Check for roads with no linzid set...";
	if ( exists($bylinzid{-1})){
		print "\n"; # keep the 'none found' on the same line
		my @nolinzid = @{$bylinzid{-1}};
		for my $j (@nolinzid){
			# print "nolinzidset: j is $j\n";
			$type = $roadsh[$j->[0]]->{type};
			$dec = oct($type);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( defined $roadsh[$j->[0]]->{label}[0] && $roadsh[$j->[0]]->{label}[0] ne "") {
					print "Type is $type/$roadtype{$dec}, ";
					dump_id3($roadsh[$j->[0]],0,-1);
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
			my $lbl = $roadsh[$j->[0]]->{label}[0] ? $roadsh[$j->[0]]->{label}[0] : "-blank-";
			print "$key is - $j->[0] - $lbl $roadsh[$j->[0]]->{roadid}\n";
		}
		print "\n";
	}
}


sub overlap_err{
	my $beg    = shift; #start number
	my $lst    = shift; #end number
	my $roadhp = shift; #road pointer
	my $red    = shift; #reference to 'set numbers' hash - set in ol1nt $$srf{$i} = [$roadhp,$nid,$isend,$nno];
	my $isend  = shift; #is this an end node? 1/2 -> which
	my $nid    = shift; #node ID - not sure if this is the best way to bring it in...
	my $nno    = shift; #numbering number
	my $missf  = shift; #file pointer
	my $x1; my $y1;
	my $lasta = $nid; 
	my $lastb = 0;
	my $lbcoord = 0;
	my $rangestr;
	my $debugthis = 0;

	$debugthis = $debug{'overlaperr'} && ( $debug{'overlaperr'} == 1 || grep {/$debug{'overlaperr'}/} $roadhp->{linzid}[0] );

	if ($debugthis){
		print "overlap_err: beg:$beg lst:$lst isend:$isend nid:$nid nno:$nno red: $red red0: $$red[0] roadhp: $roadhp\n";
		print "roadhp is: \n";
		print Dumper($roadhp);
		print "red is:\n";
		print Dumper($red);
		print "overlap_err: beg:$beg lst:$lst isend:$isend nid:$nid nno:$nno red(1):$$red[1] red(2):$$red[2] red(3):$$red[3] red(0,14): $$red[0]->{numnum}\n";
	}

	if ($lst == $beg){
		if ( $isend and $$red[2]){ #both nodes are ends
			# have to convolve $nid and $isend to get right end...
			if ( $isend & 1 ){
				$x1 = $roadhp->{x}[$nid];
				$y1 = $roadhp->{y}[$nid];
				if ($debugthis){print "overlap_err: isend=1 x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
					if ($debugthis){print "overlap_err: red2=1 x2,y2= $$red[0]->{x}[$$red[1]],$$red[0]->{y}[$$red[1]]\n"}
					if (($x1 == $$red[0]->{x}[$$red[1]])&&($y1 == $$red[0]->{y}[$$red[1]])){
						if ($debugthis){print "match 1,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0]->{numnum}-1){ #stored numberx < max numbers
						$lastb = $$red[0]->{numarray}[$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0]->{x}}; #last node
					}
					if ($debugthis){print "overlap_err: red2=2 lastb=$lastb x2,y2= $$red[0]->{x}[$lastb],$$red[0]->{y}[$lastb]\n"}
					if (($x1 == $$red[0]->{x}[$lastb])&&($y1 == $$red[0]->{y}[$lastb])){
						if ($debugthis){print "match 1,2\n"}
						return 0;
					}
				}
			}
			if ( $isend & 2 ){
				if (($nno+1) < $roadhp->{numnum}){ #this node numberx < max numbers
					$lasta = $roadhp->{numarray}[$nno+1][0];
					if ($debugthis){print "overlap_err: red2=2,isend=2,set lasta=road[11][$nid+1][0]=$lasta\n"}
				} else {
					$lasta = $#{$roadhp->{x}}; #last node
				}
				
				$x1 = $roadhp->{x}[$lasta];
				$y1 = $roadhp->{y}[$lasta];
				if ($debugthis){print "overlap_err: isend=2 nid=$nid, road(14)=$roadhp->{numnum},lasta=$lasta x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
					if ($debugthis) {print "overlap_err: red2=1 x2,y2= $$red[0]->{x}[$$red[1]],$$red[0]->{y}[$$red[1]]\n"}
					if (($x1 == $$red[0]->{x}[$$red[1]])&&($y1 == $$red[0]->{y}[$$red[1]])){
						if ($debugthis){print "match 2,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0]->{numnum}-1){ #stored numberx < max numbers
						$lastb = $$red[0]->{numarray}[$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0]->{x}}; #last node
					}
					if($debugthis){print "overlap_err: red2=2 lastb = $lastb x2,y2= $$red[0]->{x}[$lastb],$$red[0]->{y}[$lastb]\n"}
					if (($x1 == $$red[0]->{x}[$lastb])&&($y1 == $$red[0]->{y}[$lastb])){
						if ($debugthis){print "match 2,2\n"}
						return 0;
					}
				}
			}
		}
		print "RoadID $roadhp->{roadid}: number $beg already set in RoadID $$red[0]->{roadid}\n";
		$rangestr = "$beg";
	} else {
		print "RoadID $roadhp->{roadid}: numbers $beg to $lst already set in RoadID $$red[0]->{roadid} (at least)\n";
		$lastb = $$red[1]; #changed from 3 to 1
		$rangestr = "$beg to $lst";
	}
	print "previous definition:\n";
	if($debugthis){print sprintf "overlap_err: node: %s\n", defined($lastb) ? $lastb : "(undefined)"}
#	$lbcoord = $$red[0]->{numarray}[$lastb][0]; wrong - coord is stored, not number index
	dump_id3($$red[0],$lastb,-1);
	local $, = ',';
	print $missf $$red[0]->{y}[$lastb],$$red[0]->{x}[$lastb],"Previous Overlap of $rangestr","$$red[0]->{label}[0]\n";
	return (1,$lasta);
}	


sub overlap_one_numtype {
	my $beg    = shift; #start number
	my $end    = shift; #end number
	my $dif    = shift; #difference - 2 for odd/even, 1 for both
	my $nid    = shift; #ID of this node
	my $nno    = shift; #current numbering number
	my $roadhp = shift; #road ID
	my $srf    = shift; #reference to 'set numbers' hash
	my $missf  = shift; #csv file

	my $ste; #start of error numbers...
	my $isend = 0;
	my $i;
	my $err = 0;
	my $iserr = 0;
	my $errnod = 0;
	my $debugthis = 0;

	$debugthis = $debug{'ol1numtype'} && ( $debug{'ol1numtype'} == 1 || grep {/$debug{'ol1numtype'}/} $roadhp->{linzid}[0] );

	if ($debugthis){print "overlap_one_numtype: beg: $beg end: $end dif: $dif nid: $nid nno: $nno road: $roadhp->{label}[0]\n"}
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
				if ($debugthis){print "ol1nt: oe1 srf:\n"; print Dumper($srf)};
				($iserr,$errnod) = overlap_err($ste,$i-$dif,$roadhp,$$srf{$ste},$isend,$nid,$nno, $missf);
				if (!$iserr){
					$err--;
				}
				$ste = 0;
			}	
			$$srf{$i} = [$roadhp,$nid,$isend,$nno];
		}
	} until ( $i == $end );

	if ($debugthis){print "overlap_one_numtype: isend is $isend\n"}	 
	$isend = 0;
	if ( $ste ){
		if ( $ste == $i){
			$isend |= 2;
		}
		if ($debugthis){print "overlap_one_numtype, end - ste: $ste i: $i isend: $isend\n"}
		if ($debugthis){print "ol1nt: oe2 srf:\n"; print Dumper($srf)};
		($iserr,$errnod) = overlap_err($ste,$i,$roadhp,$$srf{$ste},$isend,$nid,$nno, $missf);
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
			return overlap_one_numtype($n[1],$n[2],2,@n[3..7]);
		}
		when (/[O]/){
			if (($n[1]+1)%2 || $n[1]<=0 ) { 
				return 0;
			}
			if (($n[2]+1)%2 || $n[2]<=0 ) {
				return 0;
			}
			return overlap_one_numtype($n[1],$n[2],2,@n[3..7]);
		}
		when (/[B]/){
			if ( $n[1]<=0 ) { 
				return 0;
			}
			if ( $n[2]<=0 ) {
				return 0;
			}
			return overlap_one_numtype($n[1],$n[2],1,@n[3..7]);
		}
		default {
			return 0; #no point reiterating error
		}
	}
}	

sub overlap_one_numbered_section {
	my $roadhp;
	my $rid;
	my $nptr;
	my @numa;
	my $i;
	my $l; my $r;
	my $errnod;
	my %numset;
	my $debugthis = 0;
	my $roadlstp = shift;
	my $missf = shift;

	for my $jp (@$roadlstp){ #for each road of this id
		my $j = $jp->[0];
		if ($debug{'olcheck'} == 1){print "overlap_1ns: j = $j\n"};
		$roadhp = $roadsh[$j];
		$debugthis = $debug{'olcheck'} && ( $debug{'olcheck'} == 1 || grep {/$debug{'olcheck'}/} $roadhp->{linzid}[0] );
		if ($debugthis){print "overlap_1ns - Road: $roadhp->{label}[0], RoadID: $roadhp->{roadid}\n"}
		$rid = $roadhp->{roadid};
		@numa = @{$roadhp->{numarray}};

		for ($i=0; $i<$roadhp->{numnum};$i++) {	# for each numbered segment
			$nptr = $numa[$i];
			($l,$errnod) = overlap_one_side(@$nptr[1..3],$$nptr[0],$i,$roadhp,\%numset,$missf);
			local $, = ',';
			if ($l) { 
				if ($debugthis){print sprintf "overlap_1ns LHS - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
				print "conflicting definition:\n";
				dump_id3($roadhp,$errnod,-1); 
				print "\n";
				print $missf $roadhp->{y}[$errnod],$roadhp->{x}[$errnod],"Conflicting Overlap","$roadhp->{label}[0]\n";
			}
			($r,$errnod) = overlap_one_side(@$nptr[4..6],$$nptr[0],$i,$roadhp,\%numset,$missf);
			if ($r) { 
				if ($debugthis){print sprintf "overlap_1ns RHS - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
				print "conflicting definition:\n";
				dump_id3($roadhp,$errnod,-1); 
				print "\n";
				print $missf $roadhp->{y}[$errnod],$roadhp->{x}[$errnod],"Conflicting Overlap","$roadhp->{label}[0]\n";
			}
		}
	}
}

sub overlap_check {
	my $missf = shift;
	my @numprm;

	print "Check for overlaps on number ranges...\n";
	while( my( $idval, $roadlstp ) = each( %{$byid} ) ) { # for each id, roadlstp is 1-3 e.g linzid, linzid2...
		if ($debug{'olcheck'} && ( $debug{'olcheck'} == 1 || grep {/$debug{'olcheck'}/} $idval )){
			print "overlap_check: id = $idval\n"
		};
		next if $idval == 0 || $idval == -1;	# ignore linzid=0 and no linzid roads
		if ( defined $bylinznumbid{$idval} ) { 
			for (values %{$bylinznumbid{$idval}}) {
				overlap_one_numbered_section($_,$missf);
			}
		} else {
			overlap_one_numbered_section($roadlstp,$missf);
		}
	}
}


sub OEZ_check_one_side { 
#	print "Check one side zero: @_\n";
	my @n = @_;
	my $error = 0;
	my $errmsg = "";
	my $debugthis = 0;

	$debugthis = $debug{'OEZCheck1s'};
	given ($n[0]) {
		when (/[BOEN]/){
			# do nothing - as expected
		}
		default {
			my $errmsgp = "* Error - Unrecognised numbering type: $n[0]";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error = 1;
		}
	}
	if ($n[0] ne 'N') {
		if ($n[1]<=0) {
			my $errmsgp = "Warning - Number[$n[4]] from $n[1] to $n[2]";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 1;
		}
		if ($n[2]<=0) {
			my $errmsgp = "Warning - Number[$n[4]] from $n[1] to $n[2]";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 2;
		}
	}
	if ($n[0] eq "E"){
		if ($n[1]>0 && $n[1]%2) { # >0 to avoid reiterating for -1
			my $errmsgp = "Warning - Number[$n[4]]: $n[1] is not even";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 1;
		}
		if ($n[2]>0 && $n[2]%2) {
			my $errmsgp = "Warning - Number[$n[4]]: $n[2] is not even";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 2;
		}
	}
	if ($n[0] eq "O"){
		if (($n[1]+1)%2) { 
			my $errmsgp = "Warning - Number[$n[4]]: $n[1] is not odd";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 1;
		}
		if (($n[2]+1)%2) {
			my $errmsgp = "Warning - Number[$n[4]]: $n[2] is not odd";
			print $errmsgp,"\n";
			$errmsg .= $errmsgp;
			$error |= 2;
		}
	}
	if ($debugthis && $error) {print "OEZ_check_one_side returning $error, $errmsg\n";}
	return ($error,$errmsg);
}


sub odd_even_zero_check {
	my $missf = shift;
	my @numa;
	my @numprm;
	my $i;
	my $nptr;
	my $l; my $r; my $stend;
	my $n1; my $n2;
	my $lerrmsg; my $rerrmsg;
	my $rdn;
	my $debugthis = 0;
	
	print "Check numbers for incorrect odd/even values...\n";
	
	for my $roadhp (@roadsh) {
		$rdn = defined $roadhp->{label}[0] ? $roadhp->{label}[0] : "(blank)";
		$debugthis = $debug{'OEZCheck'} && ( $debug{'OEZCheck'} eq '1' || grep {/$debug{'OEZCheck'}/} $roadhp->{linzid}[0] );
		@numa = @{$roadhp->{numarray}};
		if ($debugthis){ print "OEZCh-Label: $roadhp->{label}[0]\n" }#label
		for ($i=0; $i<$roadhp->{numnum};$i++) {
			$nptr = $numa[$i];
			if ($debugthis){ print "OEZCh index: $i nptr: @$nptr\n"}
			($l,$lerrmsg) = OEZ_check_one_side(@$nptr[1..3,8,7]); #returns bitmask start = 1 end = 2
			($r,$rerrmsg) = OEZ_check_one_side(@$nptr[4..6,8,7]);
			$stend = $l | $r;
			$n2 = -1;
			if ( $stend & 1 ){
				if ($debugthis){ print "OEZCh-l,r,s: $l, $r, $stend\n"}
				$n1 = $$nptr[0];
				if ( $stend & 2 ){
					if ( $i >= ($roadhp->{numnum}-1)){
						$n2 = $#{$roadhp->{x}}; #last node
					} else {
						$n2 = ${$numa[$i+1]}[0];
					}
				}
			} else { # only end 2
				if ($debugthis){ print "OEZCh-l,r,s: $l, $r, $stend\n"}
				if ( $i >= ($roadhp->{numnum}-1)){
						$n1 = $#{$roadhp->{x}}; #last node
					} else {
						$n1 = ${$numa[$i+1]}[0];
					}
			}
			if ( $stend ){
				if ($debugthis){ print "OEZ - nodes $n1, $n2\n"}
				dump_id3($roadhp,$n1,$n2);
				print "\n";
				print $missf "$roadhp->{y}[$n1],$roadhp->{x}[$n1],$lerrmsg$rerrmsg,$rdn\n";
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
	for my $roadhp(@roadsh) {
		if ($debug{'routecheck'}){ print sprintf "in routing_check. Road is %s\n", $roadhp->{label}[0] ? $roadhp->{label}[0] : "(unnamed)"}

		$motorway   = (oct($roadhp->{type})==0x1);
		$walkway    = (oct($roadhp->{type})==0x16);
		$roundabout = (oct($roadhp->{type})==0xc);

		if ( defined $roadhp->{routeparam}) { 
			if ($debug{'routecheck'}){ print sprintf "routing_check: it has routing\n"}
			@routeprm = split /,/,$roadhp->{routeparam};
			$speed7 =(oct($routeprm[0])==0x7);
			$dirr = $routeprm[2];
		} else {
			undef $dirr;
			undef $speed7;
		}

		$diri = $roadhp->{dirindic};

		if ($diri and !$dirr) {
			print "Warning - road has dirindicator set, but routing is not one-way\n";
			dump_id3($roadhp,0,-1); 
			print "\n";
		}
		if ($dirr and !$diri) {
			print "Warning - road has one-way routing but dirindicator is not set\n";
			dump_id3($roadhp,0,-1); 
			print "\n";
		}

		if ($speed7) {
			print "Warning - road has no speed limit (speed 7) set\n";
			dump_id3($roadhp,0,-1); 
			print "\n";
		}

		next if !$motorway and !$walkway and !$roundabout;
		if ($roundabout) {
			if (!$dirr and !$diri){
				print "Error - roundabout does not have both dirindicator and one-way routing set\n";
				dump_id3($roadhp,0,-1); 
				print "\n";
			}
		}
		if ($motorway) { 
			if (!$routeprm[9] or !$routeprm[10]){
				print "Error - Motorway allows Pedestrians or Bikes\n";
				dump_id3($roadhp,0,-1); 
				print "\n";
			}
		}
		if ($walkway) { 
			if (!$routeprm[4] or !$routeprm[5] or !$routeprm[6] or !$routeprm[7] or !$routeprm[8] or !$routeprm[11]){
				print "Error - Walkway allows Vehicles\n";
				dump_id3($roadhp,0,-1); 
				print "\n";
			}
		}
	}	
}


sub dump_by_roadid {
	my $rid = shift;
	my $all = ! defined $rid;

	print sprintf "Dump by RoadID (%s)\n",$all ? "all" : $rid;
	
	for (@roadsh) {
		my @x; my @y;
		my @numbers;
#		my $anum;
		my @nods; 
#		my $i;
		my $id;
		my $label;
		
		$id = $$_->{linzid};
		my @slice =($id->[0],$id->[1],$id->[2]);
		$label = $$_[2][0] ? $$_[2][0] : "(none)";
		if ($all or ( grep /$rid/,@slice) or (grep /$rid/,$label)){
			print "\{\n";
				print "\tType:      $$_[1]";
				if ( defined $roadtype{hex($$_[1])} ){ print  "- $roadtype{hex($$_[1])}\n"} else { print "\n" }
				print sprintf "\tLabel:     $label\n";
				for my $i(2..3) {
					if (defined $$_[2][$i-1] ){
						print "\tLabel$i:    $$_[2][$i-1]\n";
					}
				}	
				print "\tEndLevel:  $$_[3]\n";
				print sprintf "\tCityIdx:   %s\n", $$_[4] ? $$_[4] : "(none)";
				print sprintf "\tRoadId:    %s\n", $$_[5] ? $$_[5] : "(none)";
				print sprintf "\tRoutePrm:  %s\n", $$_[6] ? $$_[6] : "(none)";
				print "\tLine No:   $$_[7]\n";
				print "\tlinzid:    $$_[18][0]\n";
				for my $i(2..3) {
					if ($$_[18][$i-1]>=0){
						print "\tlinzid$i:   $$_[18][$i-1]\n";
					}
				}
				print "\tlinznumbid: $$_->{linznumbid}\n";
				print "\tNumnum:    $$_[14]\n";
				print sprintf "\tDirindic:  %s\n", $$_[16] ? $$_[16] : "-";
				print "\tComment:\n";
				for ( split/\n/,$$_[0]){
					print "\t\t$_\n";
				}
				print "\tData:\n";
					@x = @{$$_[9]};
					@y = @{$$_[10]};
					for (my $i=0;$i<$#x;$i++){
						print "\t\t$x[$i],$y[$i]\n";
					}
				print "\tNumbers:\n";
					@numbers = @{$$_[11]};
					if ( @numbers ) {
						for my $anum (@numbers) {
							print "\t\t";
							for (@{$anum}){
								print; print "   ";
							}
							print "\n";
						}
					}
				print "\tNods:\n";
					@nods = @{$$_[12]};
					for (my $i=0;$i<$#nods/2;$i++){
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
#	my $n2;
	my $rdn;
#	my $i; my $j; my $k; my $l;
#	my $roadhp;
	my $x; my $y; my $m; my $n;
	
	print "Check roads for multiple interconnect points\n";
	for my $roadhp (@roadsh) {
		$rdn = defined $roadhp->{label}[0] ? $roadhp->{label}[0] : "(blank)";
		if ($debug{'rdoverlap'}){ print "$rdn\n" }
		@n1 = @{$roadhp->{nodarray}};
		for my $n2 (@n1){
			if ($debug{'rdoverlap'}){ print "adding $rdn to node $$n2[1]\n" }
			push @{$nodids{$$n2[1]}},$roadhp;
		}
	}

	while( my( $nodv, $eachrd ) = each( %nodids ) ) {
		if ($debug{'rdoverlap'}){ print "node $nodv\n" }
		for my $i(0..$#$eachrd){
			for my $k (0..$#{$$eachrd[$i]->{nodarray}}){
				if ( defined $$eachrd[$i]->{nodarray}[$k][1] && $$eachrd[$i]->{nodarray}[$k][1]==$nodv ){
					$x = $$eachrd[$i]->{nodarray}[$k][3];
					$y = $$eachrd[$i]->{nodarray}[$k][4];
					$n = $$eachrd[$i]->{nodarray}[$k][0];
				}
			} 
			if ($debug{'rdoverlap'}){ print sprintf "connects to %s - $#{$$eachrd[$i]->{nodarray}} nodes\n",defined $$eachrd[$i][2][0] ? $$eachrd[$i][2][0] : "(blank)"}
			for my $j($i+1..$#$eachrd){
				if ($debug{'rdoverlap'}){ print sprintf "check against %s - $#{$$eachrd[$j]->{nodarray}} nodes\n", defined $$eachrd[$j][2][0] ? $$eachrd[$j][2][0] : "(blank)"}
				for my $l(0..$#{$$eachrd[$j]->{nodarray}}){
					if ( defined $$eachrd[$j]->{nodarray}[$l][1] && $$eachrd[$j]->{nodarray}[$l][1]==$nodv ){
						$m = $$eachrd[$j]->{nodarray}[$l][0];
					}
				}
				for my $k (0..$#{$$eachrd[$i]->{nodarray}}){
					next if $$eachrd[$i]->{nodarray}[$k][1]==$nodv;
					if ($debug{'rdoverlap'}){ print "check node $$eachrd[$i]->{nodarray}[$k][0]\n" }
					for my $l(0..$#{$$eachrd[$j]->{nodarray}}){
						if ($debug{'rdoverlap'}){ print "compare to node $$eachrd[$j]->{nodarray}[$l][0]\n" }
						if ( $$eachrd[$i]->{nodarray}[$k][1]==$$eachrd[$j]->{nodarray}[$l][1]){
							if ( defined $$eachrd[$i]->{nodarray}[$k][1] && defined $$eachrd[$i]->{nodarray}[$k][0] && defined $done{$nodv}){
							if (($$eachrd[$i]->{nodarray}[$k][1]!=$nodv) && ($done{$nodv}!=$$eachrd[$i]->{nodarray}[$k][1])){
								if ($debug{'rdoverlap'}){ print "done is:$done{$nodv}\n"}
								if ((abs($$eachrd[$i]->{nodarray}[$k][0]-$n)==1) && (abs($$eachrd[$j]->{nodarray}[$l][0]-$m)==1)){
								$done{$$eachrd[$i]->{nodarray}[$k][1]}=$nodv;
								print "eachrd $$eachrd[$i][2][0] and $$eachrd[$j][2][0] have two common nodes:\n";
								if ($debug{'rdoverlap'}){ print "m: $m n: $n k0: $$eachrd[$i]->{nodarray}[$k][0] l0: $$eachrd[$j]->{nodarray}[$l][0]\n" }
								print "$$eachrd[$i]->{nodarray}[$k][1] at $$eachrd[$i]->{nodarray}[$k][3],$$eachrd[$i]->{nodarray}[$k][4] and \n";
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
	my $missf = shift;
	my @numbers;
	my @nods; 
	my $i2;
	my $isnum;
	my $uncnt = 0;

	#	numbering is actually from a numbered node to the next routing node, not next numbered node. 
	#	so we need to check for nodes which are routing nodes after a numbering node starts numbering.
	
	print "Check for routing nodes without numbering in the middle of a numbered segment\n";
	for my $roadhp (@roadsh) {

		my @used; #scoped in loop to clear each iteration
		if ($debug{'unnumbered'}){print "in unnumbered_node_check. Road is $roadhp->{label}[0]\n";}
		@numbers = @{$roadhp->{numarray}};
		@nods = @{$roadhp->{nodarray}};
		
		if ($debug{'unnumbered'}){print "Numbers\n";}
		for (my $i=0;$i<=$#numbers;$i++){
			if ($debug{'unnumbered'}){print "\t$i: @{$numbers[$i]}\n";}
			addnode(\@used,$numbers[$i][0],$i,-1);
		}
		if ($debug{'unnumbered'}){print "Nods:\n";}
		for (my $i=0;$i<=$#nods;$i++){
			if ($debug{'unnumbered'}){print "\t$i : $nods[$i][0] $nods[$i][1]\n";}
			addnode(\@used,$nods[$i][0],-1,$i);
		}
		if ($debug{'unnumbered'}){
			print "\tused array:\n";
			for (@used) {
				print "\t\t@{$_} $roadhp->{x}[$$_[0]]\,$roadhp->{y}[$$_[0]]\n";
			}
		}
		
		$i2=0;
		$isnum=0;
		while ($i2 < $#used){
			if ($used[$i2][1]!=-1){
				if ($numbers[$used[$i2][1]][1] eq "N" and $numbers[$used[$i2][1]][4] eq "N"){
					if ($debug{'unnumbered'}){print "Node $used[$i2][1] is not numbered :\n";}
					$isnum = 0;
				} else {
					if ($debug{'unnumbered'}){print "Node $used[$i2][1] is numbered :\n";}
					$isnum = 1;
				}
			} else {		#used[i2][1]=-1
				if ($isnum){
					local $, = ',';
					print "Error: unnumbered node. Road is $roadhp->{label}[0]\t node $used[$i2][0] at \t$roadhp->{x}[$used[$i2][0]],$roadhp->{y}[$used[$i2][0]]\n";
					print $missf $roadhp->{y}[$used[$i2][0]],$roadhp->{x}[$used[$i2][0]],"Missing Numbering","$roadhp->{label}[0]\n";
					$uncnt++;
				}
			}
			$i2++;
		}
	}
	print sprintf "%s incorrectly numbered node%s",$uncnt ? $uncnt : "No",$uncnt==1?"\n":"s\n";
}	


sub rbout_level_check {
	my $missf = shift;
	my @nods;
	my @routeprm;
	my $rbclass;
	my @nodid;
	my $hiclass;
	my $hiroad;
	my @hinode;

	print "Check roundabouts are high enough level...\n";
	for my $roadhp (@roadsh) {	# go through all roads - put node ids into %bynodid
		@nods = @{$roadhp->{nodarray}};
		for (@nods) {
			@nodid = @{$_};
			if($debug{'rblvlchk'}>3){
				print "@{$_}\n"
			}
			if ( defined ${$_}[1] ) {
				if ( $bynodid{${$_}[1]}){
					if($debug{'rblvlchk'}>2){
						print "Adding road id $roadhp->{roadid} - ($roadhp->{label}[0]) to node ${$_}[1]\n";
					}
					push @{$bynodid{${$_}[1]}},$roadhp;
				} else {
					$bynodid{${$_}[1]} = [$roadhp];
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

	for my $roadhp (@roadsh) {	# go back through roads
		if(oct($roadhp->{type})==0xc){	# this time only look at roundabouts
			@routeprm = split /,/,$roadhp->{routeparam};
			$rbclass = $routeprm[1];
			$hiclass = $rbclass;
			undef $hiroad;
			undef @hinode;
			if($debug{'rblvlchk'}>1){
				print "checking road id $roadhp->{roadid} - class $rbclass\n"
			}
			@nods = @{$roadhp->{nodarray}};
			for (@nods) {			# for each node
				@nodid = @{$_};
				if ( defined ${$_}[1]){
					for (@{$bynodid{${$_}[1]}}){
						my $road2 = $_;
						if ( defined $road2->{routeparam} ) {
							@routeprm = split /,/,$road2->{routeparam};
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
				print "roundabout id $roadhp->{roadid} class $rbclass is too low at $nodid[3],$nodid[4]\n";
				print $missf "$nodid[4],$nodid[3],Low class RBout-$rbclass,Road Id $roadhp->{roadid}\n";
			} else {
				if (@hinode){
					print "road id $hiroad->{roadid} - class $hiclass is higher class than roundabout id $roadhp->{roadid} class $rbclass at $hinode[3],$hinode[4]\n";
					print $missf "$hinode[4],$hinode[3],Low class RBout-$hiclass,Road Id $roadhp->{roadid}\n";
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
					dump_id3($roadsh[$bylinznumbid{$linzid}{$lnid}[0][0]],0,-1);
					print "Linzid $usedrnids{$lnid}->[0] : ";
					dump_id3($roadsh[$usedrnids{$lnid}->[1]],0,-1);
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
					dump_id3($roadsh[$rdptr->[0]],0,-1);
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
				dump_id3($roadsh[$key],0,-1);
			}
			undef %rdids;
		}
	}
	if($debug{'lnidcheck'}>0){
		print "Used rnids:\n";
		for my $rnid(sort keys %usedrnids){
			print "linznumbid: $rnid, linzid: ${usedrnids{$rnid}->[0]}, road[${usedrnids{$rnid}->[1]}]\n";
		}
	}
}


sub read_roads_not_2_index {
	my $infile;
	my $fn;
	
	if (defined ($cmdopts{l})){
		$fn = "$basedir\\$linzpaper\\IgnoreIndexing.txt";
	} else {
		$fn = "$basedir\\$paperdir\\IgnoreIndexing.txt";
	}
	if ( !open $infile, '<', $fn ){
		print "File $fn not found\n";
		return;
	}

	while (<$infile>){
		chomp;
#		print "$_\n";
		next if $_ eq "";
		next if substr($_,1,1) eq "#";
		push @namesnot2index,$_;
	}
	close $infile;
}


sub no_city_index {
	my $missf = shift;

	print "check for unindexed roads...\n";
	ROAD: for my $roadhp (@roadsh) {
		next ROAD if oct($roadhp->{type}) > 12; # 0xc - don't check railways, rivers, etc...
		my $idx = $roadhp->{cityidx};
		my $label = $roadhp->{label}[0];
		my $dontfind = $roadhp->{dontfind};
		my $linzid = $roadhp->{linzid}[0];
		if (defined($label)){
			if (!defined($idx)) {
				for (@namesnot2index) {
					if ( uc($label) eq uc ) {
						if ($linzid == 0 && !$dontfind) {
							print "Indexed don't find name: \t";
							dump_id3($roadhp,0,-1);
							print $missf "$roadhp->{y}[0],$roadhp->{x}[0],\"Indexed Do not find\",\"$roadhp->{label}[0]\"\n";
						}
						next ROAD 
					}
				} 
				next ROAD if ( $linzid == 0 && $dontfind ); # OK to not index if linzid=0 and DontFind=Y
				print "Unindexed road:\t";
					dump_id3($roadhp,0,-1);
					print $missf "$roadhp->{y}[0],$roadhp->{x}[0],\"UnIndexed road\",\"$roadhp->{label}[0]\"\n";
			} else {
				for (@namesnot2index) {
					if ( uc($label) eq uc ) {
						if ($linzid == 0 && !$dontfind) {
							print "Indexed don't find name: \t";
							dump_id3($roadhp,0,-1);
							print $missf "$roadhp->{y}[0],$roadhp->{x}[0],\"Indexed Do not find\",\"$roadhp->{label}[0]\"\n";

						}
					}
				}
				
			}
		}
	}
	
}


sub numbered_id0 {
#	my $i;
	my $thisrd;
	my $type;
	my $dec;
	my $numptr;
	my $isnum;
	
	print "Check for numbering on Linzid=0 roads...\n";
	if ( exists(${$byid}{0})){ #of course it does, but...
		my @id0 = @{${$byid}{0}};
		for my $i (@id0){
			$isnum = -1;
			$thisrd = $roadsh[$i->[0]];
			$type = $thisrd->{type};
			$dec = oct($type);
			if ($debug{'numberedid0'}){print "numbered_id0 - type is $dec\n";}
			if ( $dec <= oct("0xC") or $dec == oct("0x16")) {	#<+roundabout
				$numptr = $thisrd->{numptr};
				if ( $numptr ) {
					for (@{$numptr}) {
					if ($debug{'numberedid0'}){print "numbered_id0 - ${$_}[1],${$_}[4] \n";}
						if (${$_}[1] ne "N" or ${$_}[4] ne "N"){ $isnum = ${$_}[0] }
						if ($isnum >= 0){
							print "Type is $type/$roadtype{$dec}, ";
							dump_id3($thisrd,$isnum,-1);
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
	my $missf = shift;

	my %roads_for_level_3 = (
		0x01 => 1, #major highway
		0x02 => 1, #principal highway
		0x1e => 1, #international border
	);

	my %polys_for_level_3 = (
		0x28 => 1, #sea/Ocean
		0x3c => 1, #large lake
		0x3d => 1, #large lake
		0x42 => 1, #major lake
		0x43 => 1, #major lake
		0x44 => 1, #large lake
		0x46 => 1, #major lake
	);

	print "check for roads of type=0 or too low a level...\n";
	for my $roadhp (@roadsh) {
		my $rdn = defined $roadhp->{label}[0] ? $roadhp->{label}[0] : "(blank)";
		my $level = $roadhp->{endlevel};
		my $type = $roadhp->{type};
		if (oct($type) == 0 ) {
			my $errmsg = "Road has type = 0";
			print $errmsg,":\t";
			dump_id3($roadhp,0,-1);
			print $missf "$roadhp->{y}[0],$roadhp->{x}[0],$errmsg,$rdn\n";

		}
		if ($level < 1) {
			my $errmsg =  "Road on level 0 only";
			print $errmsg,":\t";
			dump_id3($roadhp,0,-1);
			print $missf "$roadhp->{y}[0],$roadhp->{x}[0],$errmsg,$rdn\n";
		} else {
			if ( $roads_for_level_3{$type} && $level < 3 ){
				my $errmsg = "Road on level$level only";
				print $errmsg,":\t";
				dump_id3($roadhp,0,-1);
				print $missf "$roadhp->{y}[0],$roadhp->{x}[0],$errmsg,$rdn\n";
			}
		}
	}

	print "check for polygons on too low a level...\n";
	for my $polyhp (@polygons) {
		my $level = $polyhp->{endlevel};
		my $ptype = hex($polyhp->{type});
		my $ptypename = $polytype{$ptype} || $polytype{0};
		my $pname = $polyhp->{label}[0] || "unnamed";
		if ($level < 1) {
			print "Polygon on level 0 only:\t";
			dump_poly2($polyhp,0,-1);
			print $missf "$polyhp->{x}[0],$polyhp->{y}[0],$ptypename on level0 only,$pname\n";
		} else {
			if ( $polys_for_level_3{$ptype} && $level < 3 ){
				print "Polygon on level$level only:\t";
				dump_poly2($polyhp,0,-1);
				print $missf "$polyhp->{x}[0],$polyhp->{y}[0],Large $ptypename on level$level only,$pname\n";
			}
		}
	}	
}
	
	
sub read_number_csv {
	my $csvfile;
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
	my $numids;
	my $number;
	my $road;
	my $idnm;

	$idnm = "Linzid";
	$idformat = "(\"?)(\\d+)\\1";
	if (defined ($cmdopts{P})){
		$fn = "${d1}scripts\\outputs\\$f1-numbers.csv";
	} else {
		$fn = "${d1}numbers\\$f1-numbers.csv";
	}

	open ($csvfile, '<', $fn) or die "Can't open file $fn\n";
	print "Reading csv numbers from $fn\n";
	$hline = <$csvfile>;
	chomp $hline;
	if (uc($hline) ne uc($header)){
		print "expected header not found in CSV file. Expected:\n$header\nfound:\n$hline\n\n";
		die;
	}
	while (<$csvfile>){
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
			if (defined($csvroadname{$idval})){
				if ($csvroadname{$idval} ne $road){
					print "error: different road names for $idnm $idval: $road and $csvroadname{$idval}\n";
				}
			} else {
				$csvroadname{$idval}=$road;
				if ($debug{'readcsvnums'}){print "read_number_csv: setting csvroadname($idval) to $road\n";} 
			}
			if ($lnid == 0) {
				if (grep /\d{5,}/,keys %{$csv_x{$idval}} ) {
					print "Error in CSV file: Line $.: Section with no Num ID on Road ID $idval - $csvroadname{$idval} which has sections with a Num ID\n";
				}
			} else {
				if (exists $csv_x{$idval}{0}) {
					print "Error in CSV file: Line $.: Num ID $lnid on Road ID $idval - $csvroadname{$idval} which has sections with no Num ID\n";
				}
			}
	
			if (defined($csv_x{$idval}{$lnid}{$number})){
				print "warning: multiple definitions for $number $csvroadname{$idval} ($idval)\n";
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

	close $csvfile;
	$numids = keys %csvroadname;
	print "$count lines, $numids ${idnm}s\n";
}

sub read_paper_roads {
	my $prfile;
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

	if ( !open $prfile, '<', $fn ){
		print STDERR "Paper roads file $fn not found\n";
		return;
	}

	print "reading paper roads from $fn\n";
	while (<$prfile>){
		chomp;

		next if /^#.*/; #comment line
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
	close $prfile;
	if ($debug{'read_paper_roads'}) {print Dumper %paperroads}
}

sub paper_rd_check{
	my $rdid;
	my $rdsegp0;
#	my $idval;

	print "check if paper roads in paper road file are in map\n";
	foreach my $idval ( sort ({$paperroads{$a}{lnum} <=> $paperroads{$b}{lnum}} keys %paperroads )){
		if ($debug{'paper_rd_check'}) { print "check paper roads for linzid $idval - line $paperroads{$idval}{lnum} - $paperroads{$idval}{line}\n"}
		if (defined($byid->{$idval})){
			print "ID $idval in paper roads file found in map\n";
			print "Paper road line $paperroads{$idval}{lnum} is: $paperroads{$idval}{line}\n";
		#	print Dumper $byid->{$idval};
			$rdid = ${$byid->{$idval}}[0];
			dump_id3($roadsh[$rdid->[0]],0,-1);
			print "\n";
		}
	}
}

sub read_paper_road_numbers {
	my $pnfile;
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

	$fn = "$d1$linzpaper\\${f1}PaperNumbers.txt";

	if ( !open $pnfile, '<', $fn ){
		print STDERR "Paper numbers file $fn not found\n";
		return;
	}

	print "reading paper numbers from $fn\n";

	while (<$pnfile>){
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
	close $pnfile;

	if ($debug{'readpapernums'}){
		foreach my $idval ( keys %papernumbers ){
			print "paper numbers for linzid ",$idval," are:\n";
			for ( @{$papernumbers{$idval}} ){
				print " $_";
			}
			print "\n";
		}
		foreach my $idval ( keys %papernumberends ){
			print "paper number ends for linzid ",$idval," are:\n";
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
#	my $idval;
#	my $roads;
#	my $num;
#	my $rdsegptr;
#	my $numseg;

	# check that paper numbers are still valid, i.e. that the range ends are not numbered in the map
	{ print "check if paper numbers in paper number file are in map\n" }
	foreach my $idval ( keys %papernumberends ){
		if ($debug{'paper_number_check'}) { print "check paper number ends for linzid ",$idval,"\n" }
		for my $num ( @{$papernumberends{$idval}{nums}} ){
			if ($debug{'paper_number_check'}) { print "checking: $num\n"}
			# the hard bit
			if (defined($byid->{$idval})){
				if ($debug{'paper_number_check'}) { print "ID $idval found in map\n" }
				for my $rdsegptr (@{$byid->{$idval}}){
					for my $numseg( @{$roadsh[$rdsegptr->[0]][11]} ){
						if ( findnumberinseg($num,@{$numseg}[1..3])) {
							print "Number $num found in paper number file for ID $idval on line $papernumberends{$idval}{lnum}\n";
							print "Line is: $papernumberends{$idval}{line}\n";
							dump_id3($roadsh[$rdsegptr->[0]],${$numseg}[0],-1);
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
	my $missf = shift;
	my $rdsegptr;
	my $numseg;
	my @numa;
	my $missnum = 0;
	my $missid;
	my $missthis;
	my $manual;
	my $idnm = "Linzid";

	print "check for house numbers with no corresponding $idnm on the map...\n";
	foreach my $onerdid ( keys %csvroadname ){
		if (!defined($byid->{$onerdid})){
			foreach my $onelnid ( keys %{$csv_x{$onerdid}}){
				for my $number  ( keys %{$csv_x{$onerdid}{onelnid}}){
				if ( numberisinpaperfile($number,$onerdid)){
						delete $csv_x{$onerdid}{onelnid}{$number};
						delete $csv_y{$onerdid}{onelnid}{$number};
					}
				}
			}
			my @nums = sort{ $a <=> $b } keys %{$csv_x{$onerdid}{onelnid}};
			if ($#nums >= 0 ){
				print "$csvroadname{$onerdid}\t$onerdid\tnot found in map.\t$nums[0]\t$csv_y{$onerdid}{onelnid}{$nums[0]},$csv_x{$onerdid}{onelnid}{$nums[0]}";
				if ($#nums > 0 ){
					print "\t$nums[$#nums]\t$csv_y{$onerdid}{onelnid}{$nums[$#nums]},$csv_x{$onerdid}{onelnid}{$nums[$#nums]}\n";
				} else {
					print "\n";
				}
# comment out next 4 lines to temporarily stop saving missing numbers on missing roads to CSV (if there are heaps of them)
				local $, = ',';
				for my $i(0..$#nums) {
					print $missf $csv_x{$onerdid}{onelnid}{$nums[$i]},$csv_y{$onerdid}{onelnid}{$nums[$i]},"$nums[$i] $csvroadname{$onerdid}","$onerdid\n";
				}
			}
		}
	}

	print "check for house numbers missing from the map...\n";
	
	foreach my $onerdid ( keys %csvroadname ){
		if (defined($byid->{$onerdid})){
			$missthis = 0;
			$manual = 0;
			foreach my $onelnid ( keys %{$csv_x{$onerdid}}){
				NUM: for my $number ( sort {$a <=> $b} keys %{$csv_x{$onerdid}{$onelnid}}){
				if ($debug{'numpresent'}==$onerdid){ print "numpres: $number\n"; }
				for my $rdsegptr (@{$byid->{$onerdid}}){
					if ($roadsh[$rdsegptr->[0]]->{autonum}==-1) {$manual = 1}; #$roadhp->{autonum}
					for my $numseg( @{$roadsh[$rdsegptr->[0]]->{numarray}} ){
						next NUM if findnumberinseg($number,@{$numseg}[1..3]);
						next NUM if findnumberinseg($number,@{$numseg}[4..6]);
					}
				}
				
					next NUM if numberisinpaperfile($number,$onerdid,$onelnid);
				local $, = ',';
				print "$number $csvroadname{$onerdid} not found. ";
				print "$idnm is $onerdid. ";
					print "LINZ Num ID is $onelnid. " if $onelnid != 0;
					print "Should be ~ $csv_y{$onerdid}{$onelnid}{$number},$csv_x{$onerdid}{$onelnid}{$number}";
				print $manual ? " *Manual*\n" : "\n";
					print $missf $csv_x{$onerdid}{$onelnid}{$number},$csv_y{$onerdid}{$onelnid}{$number},"$number $csvroadname{$onerdid}","$onerdid\n";
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
	die "Usage: $0 -p \\path\\mapfile.mp\n\t-p checks paper number files\n\t-P uses pilot data\n";
}

##### Main program starts...

getopts("lsxpPd", \%cmdopts);
if (!($cmdopts{s} or $cmdopts{l})){
	$cmdopts{l}=1;
}

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

open(my $missfile, '>', "${basefile}_missing.csv") or die "can't create missing csv file\n";

id_check();
routing_check();
odd_even_zero_check($missfile);
sort_by_id();

#dump_by_roadid(); # does all
#dump_by_roadid("aihop");
#dump_by_roadid(1775424);
#dump_by_roadid(15441); #parkinson - canterbury

nolinzidset();
levels_check($missfile);
$byid = \%bylinzid;

if ($cmdopts{d}){
	dump_by_id();
}

if (!$cmdopts{p}){
	numbered_id0();

	road_overlap();
	overlap_check($missfile);

	unnumbered_node_check($missfile);

	rbout_level_check($missfile);
	lnid_check();

	read_roads_not_2_index();
	no_city_index($missfile);
}

read_number_csv($basefile,$basedir);
read_paper_road_numbers($basefile,$basedir);

if ($cmdopts{p}){
	read_paper_roads($basefile,$basedir);
	paper_number_check();
	paper_rd_check();
} else {
	check_for_number_present($missfile);
}