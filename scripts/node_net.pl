use strict;
use warnings;
# no warnings 'recursion';
use feature qw "switch say";
use Carp qw(shortmess);
use List::Util qw(max min);
no if $] >= 5.018, warnings => "experimental::smartmatch";
use File::Basename;
use File::Spec;
use Cwd;
use Getopt::Std;
use Data::Dumper;

my $basefile;
my $basedir;
my $basesuff;

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
my %nodenets;
my %papernumbers;
my %papernumberends;
my %bynodid;
my $nodsdone;
my $isborder;
my %nodsleft;
my @noddata;
my @restrictions;

my %csvroadname;
my %csv_x;
my %csv_y;

my %debug = (
	sbid			=> 0,
	dumpid3			=> 0,
	OEZCheck		=> 0,	# 1 or linzid or regex e.g '3063230|1830369'
	OEZCheck1s		=> 0,
	overlaperr		=> 0, #1801950,	# 1 or linzid or regex e.g '3063230|1830369'
	olcheck			=> 0, #1801950,	# 1 or linzid or regex e.g '3063230|1830369'
	ol1side			=> 0, #1801950,	# 1 or linzid or regex e.g '3063230|1830369'
	ol1numtype		=> 0, #1801950,	# 1 or linzid or regex e.g '3063230|1830369'
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

sub do_restrict {
	my $nod;
	my @trafpts;
	my @trafrds;
	my %thisrestrict;

	while (<>) {
		if (/^Nod=(\d*)$/) {
			$nod = $1;
			next;
		}
		if (/^TraffPoints=(.*)$/) {
			@trafpts = split(/,/,$1);
			next;
		};
		if (/^TraffRoads=(.*)$/) {
			@trafrds = split(/,/,$1);
			next;
		};

		if (/^\[END-Restrict\]$/)	{ #end of def - collect everything up and exit
			%thisrestrict = (
				nod		=> $nod,
				trafpts		=> \@trafpts,
				trafrds		=> \@trafrds,
			);
			push @restrictions, \%thisrestrict;
			last;
		}
		print "Strange line in Restriction:\n\tLine $. is $_\n";
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
						print " * Error: multiple linzid${1}s $2,$roadhp->{linzid}[$i]\n";
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
	my $nidx;
	my $xc;
	my $yc;

	print "Check roundabouts are high enough level...\n";
	for my $roadhp (@roadsh) {	# go through all roads - put node ids into %bynodid
		@nods = @{$roadhp->{nodarray}};
		for (@nods) {
			@nodid = @{$_};
			if($debug{'rblvlchk'}>3){
				print "@{$_}\n"
			}
			if ( defined ${$_}[1] ) {
				if ( defined ${$_}[0]) {
					$nidx = ${$_}[0];
					$xc = $roadhp->{x}[$nidx];
					$yc = $roadhp->{y}[$nidx];
				} else { 
					print "node id not defined!";
				}
				if ( $bynodid{${$_}[1]}{rds}){
					if($debug{'rblvlchk'}>2){
						print "Adding road id $roadhp->{roadid} - ($roadhp->{label}[0]) to node ${$_}[1]\n";
					}
					push @{$bynodid{${$_}[1]}{rds}},$roadhp;
				} else {
					$bynodid{${$_}[1]}{rds} = [$roadhp];
					$bynodid{${$_}[1]}{x} = $xc;
					$bynodid{${$_}[1]}{y} = $yc;
					$bynodid{${$_}[1]}{bdr} = ${$_}[2];
				}
			}
		}
	}

	if($debug{'rblvlchk'}>1){
		my $node = 1926;
		print "Roads connected to node ",$node,":\n";
		print "at ",$bynodid{$node}{y},",",$bynodid{$node}{x},"\n";
#		print Dumper $bynodid{1926};
		for (@{$bynodid{$node}{rds}}){
			print "${$_}{label}[0]\n";
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
					for (@{$bynodid{${$_}[1]}{rds}}){
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


sub read_node_net_names {
	my $nnfile;
	my $nndesc = 'node network name';
	my $f1 = shift;
	my $d1 = shift;
	my $fn;
	my $idval;
	my @chunks;

	$fn = File::Spec->join($d1,'LinzDataService','NodeNets',"${f1}_NetNames.txt");

	if ( !open $nnfile, '<', $fn ){
		print STDERR "$nndesc file $fn not found\n";
		return;
	}

	print "reading $nndesc from $fn\n";
	while (<$nnfile>){
		chomp;

		next if /^#.*/; #comment line
		@chunks = split/\t/;
		$idval = $chunks[0];
		next if not defined $idval; #blank line?
		if ($idval !~ /^\d+$/){
			print "Warning - in $nndesc file, line $. - node id is not numeric\n";
		}
		if (defined ($nodenets{$idval})) {
			print "Warning - in $nndesc file - Multiple definitions for id $idval on lines $nodenets{$idval}{lnum} and $.\n";
		}
		shift @chunks;
		$nodenets{$idval}{lnum}=$.;
		$nodenets{$idval}{line}=join ("\t",@chunks);
	}
	close $nnfile;
	if ($debug{'read_paper_roads'}) {print Dumper %nodenets}
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
							print "Indexed don't find name:\t";
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

sub node_tree {
	my $node0 = shift;
	my $netlbl = shift;

#	print "start at node $node0\n";
	$bynodid{$node0}{done}=1;
	$nodsdone++;
	if ($bynodid{$node0}{bdr}){
		$isborder = $node0;
	}
	if ($nodenets{$node0}{line}){
#		print "Node $node0 is $nodenets{$node0}{line} netlbl is *$netlbl*\n";
		if ($netlbl eq ''){
			$netlbl = $nodenets{$node0}{line};
#			print "set netlbl to $netlbl\n";
		}
	};
	for my $connroad (@{$bynodid{$node0}{rds}}) {
#		print Dumper $connroad;
#		print "road: $$connroad{roadid} $$connroad{label}[0]\n";
		my @nods = $$connroad{nodarray};
#		print Dumper @nods;
		for my $rdnode (@nods){
			for my $rdnode2 (@{$rdnode}){
#				print "node $$rdnode2[1]\n";
				if (!defined $bynodid{$$rdnode2[1]}{done}){
#					print "traverse $$rdnode2[1]\n";
					$netlbl = node_tree($$rdnode2[1],$netlbl);
				}
			}
		}
	}
	return $netlbl;
}

sub usage {
	die "Usage: $0 -p \\path\\mapfile.mp\n\t-p checks paper number files\n\t-P uses pilot data\n";
}

##### Main program starts...

getopts("lsxpPd", \%cmdopts);
if (!($cmdopts{s} or $cmdopts{l})){
	$cmdopts{l}=1;
}
$basedir = File::Spec->curdir();

usage() if (! defined $ARGV[0] || $ARGV[0] eq "");
($basefile, $basedir, $basesuff) = fileparse($ARGV[0],qr/\.[^.]*/);
$basedir = Cwd::realpath($basedir);
if ($basedir =~ m|/$nzogps(.*)$|) {
	if ($1 ne ""){
		$basedir =~ s/$1//;
	}
} else {
	print STDERR "$nzogps not found in path. Unlikely to find numbering files...\n";
}

while (<>){
	
	if (/\[IMG ID\]$/){
		do_header();
		$comment = "";
	} 

	if (/;(.*)/){	#comment
		$comment .= $1."\n";
	}

	if (/^\[Restrict\]$/){
		do_restrict();
		$comment = "";
	}

	if (/^\[POLYGON\]$/ || /^\[RGN80\]$/){
		do_polygon();
		$comment = "";
	}

	if (/^\[POLYLINE\]$/ || /^\[RGN40\]$/){
		do_polyline($comment);
		$comment = "";
	}

	if (/^\[POI\]$/ || /^\[RGN20\]$/){
		do_poi();
		$comment = "";
	}
}

id_check();
routing_check();
sort_by_id();

#dump_by_roadid(); # does all
#dump_by_roadid("aihop");
#dump_by_roadid(1775424);
#dump_by_roadid(15441); #parkinson - canterbury

nolinzidset();
#levels_check($missfile);
$byid = \%bylinzid;

if ($cmdopts{d}){
	dump_by_id();
}

if (!$cmdopts{p}){
	numbered_id0();

#	road_overlap();
#	overlap_check($missfile);

#	unnumbered_node_check($missfile);

	rbout_level_check(); #populates %bynodid
	my $nodcnt = keys %bynodid;
	my $maxnod = max(keys %bynodid);
	my $maxnodw = length($maxnod);
	my $minnod = min(keys %bynodid);
	print "$nodcnt nodes total from $minnod to $maxnod\n";

read_node_net_names($basefile,$basedir);
#print Dumper %nodenets;

	while ( my @keys_without_values = grep { !defined $bynodid{$_}{done} } keys %bynodid ){
		my $akey = $keys_without_values[0];
#		print "$akey $bynodid{$akey}{x},$bynodid{$akey}{y} is not linked\n";
		$nodsdone = 0;
		$isborder = 0;
		my $netlbl = node_tree($akey,'');
#		print "set w netlbl is $netlbl\n";

#		print "$akey connected to $nodsdone nodes\n";
#		if ($isborder){
#			print "border is $isborder\n";
#		}
		push (@noddata,[($akey,$nodsdone,$isborder,$netlbl)]);
	}
	my $firstrow = 1;
	my $rdnmlbl = "Road0 name";
	my $netclbl = "Net chunk name";
	my %fldlen = (netw => 0, rdname => length($rdnmlbl), chunkname => length($netclbl));

#calculate field widths
	for my $row ( @noddata ) {
		my $rd0 = @{$bynodid{$row->[0]}{rds}}[0];
		if ( defined %{$rd0}{label}->[0] ){
			my $label = %{$rd0}{label}->[0];
			if ( length( $label ) > $fldlen{rdname}) { $fldlen{rdname} = length($label)};
		}
		if ( length( $row->[1] ) > $fldlen{netw}) { $fldlen{netw} = length($row->[1]) };
		if ( length( $row->[3] ) > $fldlen{chunkname}) { $fldlen{chunkname} = length($row->[3]) };
	}

	for my $row ( sort {$b->[1]<=>$a->[1]} @noddata ) {
		my $rdlabel = "";
		
		my $rd0 = @{$bynodid{$row->[0]}{rds}}[0];
		if ( defined %{$rd0}{label}->[0] ){
			$rdlabel = %{$rd0}{label}->[0];
		}

		if ($firstrow) {
			$firstrow = 0;
			printf("%*s %*s %*s %*s %*s %*s %*s\n",$maxnodw, "StNode", $fldlen{netw}, "NetSz", $maxnodw, "Border",9,"StNdX",9,"StNdY",$fldlen{rdname},$rdnmlbl,$fldlen{chunkname},$netclbl);
		}
		printf("%*d %*d %*d %.5f %.5f %*s %*s\n",$maxnodw, $row->[0], $fldlen{netw}, $row->[1], $maxnodw, $row->[2],$bynodid{$row->[0]}{x},$bynodid{$row->[0]}{y},$fldlen{rdname},$rdlabel,$fldlen{chunkname}, $row->[3]);
	}
#	print Dumper @restrictions;
}


# print STDERR "basedir is $basedir\n";
