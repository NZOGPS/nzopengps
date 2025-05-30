use strict;
use feature "switch";
use File::Basename;
use Cwd;
use Getopt::Std;

my $basefile;
my $basedir;
my $basesuff;

my $paperdir = "PaperRoads";
my $linzpaper = "LinzDataService\\$paperdir";
my $nzogps = "nzopengps";
my $comment;
my @roads;
my @namesnot2index;
my %bysufi;
my %bylinzid;
my $byid;
my %papernumbers;

my %debug = (
	nothing => 1,
	overlaperr    => 0,
	olcheck       => 0,
	ol1numtype    => 0,
	readpapernums => 0,
	unnumbered    => 0,
	addnode       => 0,
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
	while (<>){
		if (/^LblCoding=9/) {
			print "\nError: LblCoding=9 found in header\n\n";
		}
		if (/^\[END-IMG ID\]$/)	{ #end of header
			last;
		}
	}
}

sub do_polygon {
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
	my $label;		#2
	my $endlevel = 0;	#3
	my $cityidx;	#4
	my $roadid;		#5
	my $routeparam;	#6
	my $lineno = $.;	#7
	my $sufi=-1;	#8
	my $linzid=-1;	#18
	my @data;
	my @numbers; #for now?
	my $coordstr;
	my @coords;
	my @x;	#9
	my @y;	#10
	my @nods;	#11
	my $label2;	#12
	my $numnum = 0;	#13
	my $dirindicator;  #16
	my $autonum = -1; #17
	my @numarray;
	my @nodarray;

	while (<>){
		if (/^Type=(.*)$/)         { $type = $1 };
		if (/^Label=(.*)$/)        { $label = $1 };
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
			$label=~s/~\[0x[[:xdigit:]]+\]/SH/;
			parsenums(\@numarray,@numbers);
			parsenods(\@nodarray,\@x,\@y,@nods);
			push @roads,[$comment,$type,$label,$endlevel,$cityidx,$roadid,$routeparam,$lineno,$sufi,\@x,\@y,\@numarray,\@nods,$label2,$numnum,\@nodarray,$dirindicator,$autonum,$linzid];
#			----------------0-------1-----2-------3----------4-------5--------6-----------7-----8-----9--10----11---------12-----13-----14-------15----------16------			
			last;
		}
	}
}
	
sub do_poi {
}

sub id_check {
	my $road;
	my $cmt;
	my @lines;
	my $line;
	my $autonum;
	my $ancnt;
	my $noancnt;
	
	print "Check for valid sufis/linzids...\n";
	for $road (@roads) {
		$cmt = $$road[0];
		@lines = split/\n/,$cmt;
		$autonum = 0;
		for $line (@lines){
#			print "comment line is: $line\n";

			if ($line=~/sufi=(\d+)/) {
				if ($$road[8]==-1){
					$$road[8]=$1;
				} else {
					if ($1==$$road[8]){
						print "Warning: multiple copies of same sufi\n";
					} else {
						print " * Error: multiple sufis $1,$$road[8]\n";
					}
					dump_id2($road,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/sufi=(\d+)/i) {
					print "Warning: odd sufi capitalisation: $line\n";
					dump_id2($road,0,-1);
					print "\n";
				}
			}

			if ($line=~/linzid=(\d+)/) {
				if ($$road[18]==-1){
					$$road[18]=$1;
				} else {
					if ($1==$$road[18]){
						print "Warning: multiple copies of same linzid\n";
					} else {
						print " * Error: multiple linzids $1,$$road[18]\n";
					}
					dump_id2($road,0,-1);
					print "\n";
				}
			}
			else {
				if ($line=~/linzid=(\d+)/i) {
					print "Warning: odd linzid capitalisation: $line\n";
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
		$autonum ? $ancnt++ : $noancnt++;
	}
	print sprintf "%s roads autonumbered, %s roads manually numbered.\n", $ancnt ? $ancnt : "No", $noancnt ? $noancnt : "no";
}


sub dump_id2 {
	my $ridptr = shift;
	my $nodno = shift;
	my $nodn2 = shift;
	if ($debug{'dumpid2'}) { print "dump_id2: $ridptr, $nodno, $nodn2\n" }
	my @road = @$ridptr;
	my @x = @{$road[9]};
	my @y = @{$road[10]};
	my $roadname = $road[2];
	my $label2 = $road[13];
		
	if ( $roadname eq ""){
		$roadname = "unnamed";
	}
	if ($label2 ne ""){
		$label2 = " / " . $label2;
	} 
	
	if ( $nodn2 < 0 ){
		print "Road is $roadname$label2, Line $road[7], Coord is\t$x[$nodno],$y[$nodno]\n";
	} else {
		print "Road is $roadname$label2, Line $road[7], Coords are $x[$nodno],$y[$nodno] and\t$x[$nodn2],$y[$nodn2]\n";
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
	my $lastb;

	if ($debug{'overlaperr'}){print "overlap_err: beg:$beg lst:$lst isend:$isend nid:$nid nno:$nno red(1):$$red[1] red(2):$$red[2] red(3):$$red[3] red(0,14): $$red[0][14]\n"}
	if ($lst == $beg){
		if ( $isend and $$red[2]){ #both nodes are ends
			# have to convolve $nid and $isend to get right end...
			if ( $isend & 1 ){
				$x1 = $$road[9][$nid];
				$y1 = $$road[10][$nid];
				if ($debug{'overlaperr'}){print "overlap_err: isend=1 x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
					if ($debug{'overlaperr'}){print "overlap_err: red2=1 x2,y2= $$red[0][9][$$red[1]],$$red[0][10][$$red[1]]\n"}
					if (($x1 == $$red[0][9][$$red[1]])&&($y1 == $$red[0][10][$$red[1]])){
						if ($debug{'overlaperr'}){print "match 1,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0][14]-1){ #stored numberx < max numbers
						$lastb = $$red[0][11][$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0][9]}; #last node
					}
					if ($debug{'overlaperr'}){print "overlap_err: red2=2 lastb=$lastb x2,y2= $$red[0][9][$lastb],$$red[0][10][$lastb]\n"}
					if (($x1 == $$red[0][9][$lastb])&&($y1 == $$red[0][10][$lastb])){
						if ($debug{'overlaperr'}){print "match 1,2\n"}
						return 0;
					}
				}
			}
			if ( $isend & 2 ){
				if (($nno+1) < $$road[14]){ #this node numberx < max numbers
					$lasta = $$road[11][$nno+1][0];
					if ($debug{'overlaperr'}){print "overlap_err: red2=2,isend=2,set lasta=road[11][$nid+1][0]=$lasta\n"}
				} else {
					$lasta = $#{$$road[9]}; #last node
				}
				
				$x1 = $$road[9][$lasta];
				$y1 = $$road[10][$lasta];
				if ($debug{'overlaperr'}){print "overlap_err: isend=2 nid=$nid, road(14)=$$road[14],lasta=$lasta x1,y1= $x1,$y1\n"}

				if ( $$red[2] & 1){
#					print "overlap_err: red2=1 x2,y2= $$red[0][9][$$red[1]],$$red[0][10][$$red[1]]\n";
					if (($x1 == $$red[0][9][$$red[1]])&&($y1 == $$red[0][10][$$red[1]])){
						if ($debug{'overlaperr'}){print "match 2,1\n"}
						return 0;
					}
				}
				if ( $$red[2] & 2){
					if ($$red[3] < $$red[0][14]-1){ #stored numberx < max numbers
						$lastb = $$red[0][11][$$red[3]+1][0];
					} else {
						$lastb = $#{$$red[0][9]}; #last node
					}
					if($debug{'overlaperr'}){print "overlap_err: red2=2 lastb = $lastb x2,y2= $$red[0][9][$lastb],$$red[0][10][$lastb]\n"}
					if (($x1 == $$red[0][9][$lastb])&&($y1 == $$red[0][10][$lastb])){
#						print "match 2,2\n";
						return 0;
					}
				}
			}					
		}
		print "RoadID $$road[5]: number $beg already set in RoadID $$red[0][5]\n";
	} else {	
		print "RoadID $$road[5]: numbers $beg to $lst already set in RoadID $$red[0][5] (at least)\n";
		$lastb = $$red[3];
	}
	print "previous definition:\n";
	if($debug{'overlaperr'}){print sprintf "overlap_err: node: %s\n", defined($lastb) ? $lastb : "(undefined)" }
	dump_id2($$red[0],$lastb,-1);
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

	if ($debug{'ol1numtype'}){print "overlap_one_numtype: beg: $beg end: $end dif: $dif nid: $nid nno: $nno road: $$road[2]\n"}
	
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
				if ($debug{'ol1numtype'}){print "overlap_one_numtype: setting ste to $i\n";}
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

	if ($debug{'ol1numtype'}){print "overlap_one_numtype: isend is $isend\n"}	 
	$isend = 0;
	if ( $ste ){
		if ( $ste == $i){
			$isend |= 2;
		}
		if ($debug{'ol1numtype'}){print "overlap_one_numtype, end - ste: $ste i: $i isend: $isend\n"}
		($iserr,$errnod) = overlap_err($ste,$i,$road,$$srf{$ste},$isend,$nid,$nno);
		if (!$iserr){
			$err--;
		}
	}
	
	if ($debug{'ol1numtype'}){print "overlap_one_numtype returning $err, $errnod\n"}
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


sub overlap_check {
	my $road;
	my $rid;
	my @numprm;

	my @numa;
	my $nptr;

	my $i;
	my $l; my $r;
	my $errnod;
	
	print "Check for overlaps on number ranges...\n";
	if ($debug{'olcheck'}){print "*** Overlap_Check ***\n"};
	while( my( $idval, $roadlsta ) = each( %{$byid} ) ) { # for each id
		my %numset;	# scoped in loop to clear for each new road

		next if $idval == 0 || $idval == -1;	# ignore sufi=0 and no sufi roads
		for my $j (@$roadlsta){ #for each road of this id
			$road = $roads[$j];			
			if ($debug{'olcheck'}){print "overlap_check - Road: ${$road}[2], RoadID: ${$road}[5]\n"}
			$rid = $$road[5];
			@numa = @{$$road[11]};

			for ($i=0; $i<$$road[14];$i++) {	# for each numbered segment
				$nptr = $numa[$i];
				($l,$errnod) = overlap_one_side(@$nptr[1..3],$$nptr[0],$i,$road,\%numset);
				if ($l) { 
					if ($debug{'olcheck'}){print sprintf "overlap_check - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
					print "conflicting definition:\n";
					dump_id2($road,$errnod,-1); 
					print "\n";
				}
				($r,$errnod) = overlap_one_side(@$nptr[4..6],$$nptr[0],$i,$road,\%numset);
				if ($r) { 
					if ($debug{'olcheck'}){print sprintf "overlap_check - errnod is %s\n",defined($errnod) ? $errnod : "(undefined)"}
					print "conflicting definition:\n";
					dump_id2($road,$errnod,-1); 
					print "\n";
				}
			}
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
	
	print "Check numbers for incorrect odd/even values...\n";
	for my $road (@roads) {
		@numa = @{$$road[11]};
#		print "$$road[2]\n"; #label
		for ($i=0; $i<$$road[14];$i++) {	
			$nptr = $numa[$i];
#			print "@$nptr\n";
			$l = OEZ_check_one_side(@$nptr[1..3,8,7]);
			$r = OEZ_check_one_side(@$nptr[4..6,8,7]);
			$stend = $l | $r;
			$n2 = -1;
#			print "l,r,s: $l, $r, $stend\n";
			if ( $stend & 1 ){
				$n1 = $$nptr[0];
				if ( $stend & 2 ){
					if ( $i >= ($$road[14]-1)){
						$n2 = $#{$$road[9]}; #last node
					} else {
						$n2 = ${$numa[$i+1]}[7];
					}
				}
			} else {
				if ( $i >= ($$road[14]-1)){
						$n1 = $#{$$road[9]}; #last node
					} else {
						$n1 = ${$numa[$i+1]}[7];
					}
			}
			if ( $stend ){			
				dump_id2($road,$n1,$n2);
				print "\n";
			}
		}
	}
}


sub sort_by_id {
	#must call id_check first to populate sufi & linzid field
	my $sufi;
	my $linzid;
	my $i = 0;
	
	for my $road (@roads) {
		$sufi = $$road[8];
		$linzid = $$road[18];
		if (exists($bysufi{$sufi})){
#			print "in sbid - another road for sufi $sufi\n";
			push(@{$bysufi{$sufi}},$i);
		} else {
#			print "in sbid - new sufi $sufi\n";
			$bysufi{$sufi}=[$i];
		}
		if (exists($bylinzid{$linzid})){
#			print "in sbid - another road for linzid $linzid\n";
			push(@{$bylinzid{$linzid}},$i);
		} else {
#			print "in sbid - new linzid $linzid\n";
			$bylinzid{$linzid}=[$i];
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
			$dec = oct(${$roads[$j]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( ${$roads[$j]}[2] ne "") {
					print "Type is ${$roads[$j]}[1]/$roadtype{$dec}, ";
					dump_id2($roads[$j],0,-1);
				}
			}
		}
	} else {
		print "None found\n";
	}
}


sub nolinzidset {
	my $dec;
	
	print "Check for roads with no linzid set:\n";
	if ( exists($bylinzid{-1})){
		my @nolinzid = @{$bylinzid{-1}};
		for my $j (@nolinzid){
			$dec = oct(${$roads[$j]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				if ( ${$roads[$j]}[2] ne "") {
					print "Type is ${$roads[$j]}[1]/$roadtype{$dec}, ";
					dump_id2($roads[$j],0,-1);
				}
			}
		}
	} else {
		print "None found\n";
	}
}


sub dump_by_id{
	while( my( $key, $value ) = each( %{$byid} ) ) {
		for my $j (@$value){
			print "$key is - $j - ${$roads[$j]}[2] ${$roads[$j]}[5]\n";
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
	for my $road(@roads) {
		$motorway = (oct($$road[1])==0x1);
		$walkway = (oct($$road[1])==0x16);
		$roundabout = (oct($$road[1])==0xc);

		@routeprm = split /,/,$$road[6];
		$diri = $$road[16];
		$dirr = $routeprm[2];
		$speed7 =(oct($routeprm[0])==0x7);

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
	my $all = ($rid == undef);

	print sprintf "Dump by RoadID (%s)\n",$all ? "all" : $rid;
	
	for (@roads) {
		my @x; my @y;
		my @numbers;
		my @nods; 
		my $i;
		my $id;
		
		$id = $cmdopts{l} ? $$_[18] : $$_[8];
		
		if ($all or ($id == $rid)){
			print "\{\n";
				print "\tComment:\n";
				for ( split/\n/,$$_[0]){
					print "\t\t$_\n";
				}
				print "\tType:     $$_[1]\n";
				print "\tLabel:    $$_[2]\n";
				print "\tEndLevel: $$_[3]\n";
				print "\tCityIdx:  $$_[4]\n";
				print "\tRoadId:   $$_[5]\n";
				print "\tRoutePrm: $$_[6]\n";
				print "\tLine No:  $$_[7]\n";
				print "\tsufi:     $$_[8]\n";
				print "\tLabel2:   $$_[13]\n";
				print "\tNumnum:   $$_[14]\n";
				print "\tDirindic: $$_[16]\n";
				print "\tData:\n";
					@x = @{$$_[9]};
					@y = @{$$_[10]};
					for ($i=0;$i<$#x;$i++){
						print "\t\t$x[$i],$y[$i]\n";
					}
				print "\tNumbers\n";
					@numbers = @{$$_[11]};
					for ($i=0;$i<$#numbers/2;$i++){
						print "\t\t$numbers[$i*2]: $numbers[$i*2+1]\n";
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
	my $i; my $j; my $k; my $l;
	my $road;
	my $x; my $y; my $m; my $n;
	
	print "Check roads for multiple interconnect points\n";
	for $road (@roads) {
#		print "$$road[2]\n";
		@n1 = @{$$road[15]};
		for $n2 (@n1){
#			print "adding $$road[2] to node $$n2[1]\n";
			push @{$nodids{$$n2[1]}},$road;
		}
	}

	while( my( $nodv, $roads ) = each( %nodids ) ) {
#		print "node $nodv\n";
		for $i(0..$#$roads){
			for $k (0..$#{$$roads[$i][15]}){
				if ( $$roads[$i][15][$k][1]==$nodv ){
					$x = $$roads[$i][15][$k][3];
					$y = $$roads[$i][15][$k][4];
					$n = $$roads[$i][15][$k][0];
				}
			} 
#			print "connects to $$roads[$i][2] - $#{$$roads[$i][15]} nodes\n";
			for $j($i+1..$#$roads){
#				print "check against $$roads[$j][2] - $#{$$roads[$j][15]} nodes\n";
				for $l(0..$#{$$roads[$j][15]}){
					if ( $$roads[$j][15][$l][1]==$nodv ){
						$m = $$roads[$j][15][$l][0];
					}
				}
				for $k (0..$#{$$roads[$i][15]}){
					next if $$roads[$i][15][$k][1]==$nodv;
#					print "check node $$roads[$i][15][$k][0]\n";
					for $l(0..$#{$$roads[$j][15]}){
#						print "compare to node $$roads[$j][15][$l][0]\n";						
						if ( $$roads[$i][15][$k][1]==$$roads[$j][15][$l][1]){
							if (($$roads[$i][15][$k][1]!=$nodv) && 
								($done{$nodv}!=$$roads[$i][15][$k][1]) && 
								(abs($$roads[$i][15][$k][0]-$n)==1) &&
								(abs($$roads[$j][15][$l][0]-$m)==1)){
									
								$done{$$roads[$i][15][$k][1]}=$nodv;
								print "Roads $$roads[$i][2] and $$roads[$j][2] have two common nodes:\n";
#								print "m: $m n: $n k0: $$roads[$i][15][$k][0] l0: $$roads[$j][15][$l][0]\n";
								print "$$roads[$i][15][$k][1] at $$roads[$i][15][$k][3],$$roads[$i][15][$k][4] and \n";
								print "$nodv at $x,$y\n\n";
							}
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
		if ($debug{'unnumbered'}){print "in unnumbered_node_check. Road is $$road[2]\n";}
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
					print "Error: unnumbered node. Road is $$road[2]\t node $used[$i][0] at \t$$road[9][$used[$i][0]],$$road[10][$used[$i][0]]\n";
					print MISSFILE $$road[10][$used[$i][0]],$$road[9][$used[$i][0]],"Missing Numbering","$$road[2]\n";
					$uncnt++;
				}
			}
			$i++;
		}
	}
	print sprintf "%s incorrectly numbered node%s",$uncnt ? $uncnt : "No",$uncnt==1?"\n":"s\n";
}	


sub read_roads_not_2_index {
	my $d1 = shift;
	my $fn = "$d1$paperdir\\IgnoreIndexing.txt";
	if ( !open INF, $fn ){
		print "File $fn not found\n";
		return;
	}

	while (<INF>){
		chomp;
		next if $_ eq "";
		push @namesnot2index,$_;
	}
}


sub no_city_index {
	print "check for unindexed roads...\n";
	ROAD: for my $road (@roads) {
		next ROAD if oct($$road[1]) > 12; # 0xc - don't check railways, rivers, etc...
		my $idx = $$road[4];
		my $label = $$road[2];
		if (!defined($idx) and defined($label)){
			for (@namesnot2index) {
				next ROAD if uc($label) eq uc
			} 
			print "Unindexed road:\t";
			dump_id2($road,0,-1);
		}
	}
	
}


sub numbered_id0 {
	my $i;
	my $dec;
	my $numptr;
	my $isnum;
	
	print "Check for numbering on ".($cmdopts{l}?"Linzid":"Sufi")."=0 roads\n";
	if ( exists(${$byid}{0})){ #of course it does, but...
		my @id0 = @{${$byid}{0}};
		for $i (@id0){
			$isnum = -1;
			$dec = oct(${$roads[$i]}[1]);
			if ( $dec <= oct("0xC")) {	#<+roundabout
				$numptr = ${$roads[$i]}[11];
				if ( @{$numptr} ) {
					for (@{$numptr}) {
						if (${$_}[1] ne "N" or ${$_}[4] ne "N"){ $isnum = ${$_}[0] }
						if ($isnum >= 0){
							print "Type is ${$roads[$i]}[1]/$roadtype{$dec}, ";
							dump_id2($roads[$i],$isnum,-1);
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
	print "check for roads on level 0 only...\n";
	for my $road (@roads) {
		my $level = $$road[3];
		if ($level < 1) {
			print "Road on level 0 only:\t";
			dump_id2($road,0,-1);
		}
	}	
}
	
	
sub read_number_csv {
	my $header = "No,Latitude,Longitude,Name,Description,Symbol";
	my $hline;
	my @aline;
	my $f1 = shift;
	my $d1 = shift;
	my $fn;
	my $idformat;		
	my $idval;
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
		print "expected header not found. Expected:\n$header\nfound:\n$hline\n\n";
		die;
	}
	while (<INF>){
		chomp;
		@aline = split /,/;
		if ($#aline != 5){
			die "unexpected line length: $#aline, line $.\nLine is: $_\n";
		}
		$count++;
		if ($aline[3]=~/(\"?)(\d+) (.*)(\.\d+)?\1/){ #digits for the number, road name, optional .digits for multiples
			$number = $2;
			$road = $3;
#			print "read num csv: $number $road ($1) from $aline[3]\n";
		} else {
			die "odd address: $aline[3] line $.\nLine is: $_\n";
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
	
			if (defined($x{$idval}{$number})){
				print "error: multiple definitions for $number $sufiroadname{$idval} ($idval}\n";
				print "prev: $x{$idval}{$number},$y{$idval}{$number} - current $aline[2],$aline[1] line $_\n";
			} else {
				$x{$idval}{$number}=$aline[2];
				$y{$idval}{$number}=$aline[1];
				if ($debug{'readcsvnums'}){print "read_number_csv: x,y($idval,$number) = $aline[2],$aline[1]\n";} 
			}
		} else {
			die "odd $idnm: $aline[4] line $.\nLine is: $_\n";
		}
	}

	$numsufi = keys %sufiroadname;
	print "$count lines, $numsufi ${idnm}s\n";
}


sub read_paper_road_numbers {
	my $f1 = shift;
	my $d1 = shift;
	my $idval;
	my @nums;
	my @chunks;
	my $type;
	my $start;
	my $end;
	my $i;
	my $j;
	my $error;
	my $fn;
	
	
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
		$i  = 1;
		@chunks = split/\t/;
		$idval = $chunks[0];
		if (defined ($papernumbers{$idval})) {
			print "Warning - in paper numbers file - Multiple definitions for sufi $idval\n";
		}

		while ($chunks[$i]=~/([OBE])\,(\d+),(\d+)/){
			if ($debug{'readpapernums'}){print "valid number line: @chunks\n";}
			($type,$start,$end)=($1,$2,$3);
			if ($start<=0) {
				print "Warning - in paper numbers file - Start number $start is zero or negative\n";
				$error |= 1;
			}
			if ($end<=0) {
				print "Warning - in paper numbers file - End number $end is zero or negative\n";
				$error |= 1;
			}
			if ($type eq "E"){
				if ($start>0 && $start%2) { # >0 to avoid reiterating for -1
					print "Warning - in paper numbers file - $start is not even\n";
					$error |= 1;
				}
				if ($end>0 && $end%2) { # >0 to avoid reiterating for -1
					print "Warning - in paper numbers file - $end is not even\n";
					$error |= 1;
				}
			}
			if ($type eq "O"){
				if ($start>0 && !($start%2)) { 
					print "Warning - in paper numbers file - $start is not odd\n";
					$error |= 1;
				}
				if (($end+1)%2) {
					print "Warning - in paper numbers file - $end is not odd\n";
					$error |= 2;
				}
			}
			if ($start > $end) {
				print "Warning - in paper numbers file - $end is less than $start. Please put your numbers in ascending order\n";
				$error |= 2;
			}
			$i++;
			if (!$error){
				$j = $start;
				while ($j <= $end){
					push @nums,$j;
					$j++;
					if ($type =~/[OE]/){
						$j++;
					}
				}
				$papernumbers{$idval}=\@nums;
			}
		}
		if ($i==1 && /\S/){
			print "Warning! - No valid numbering found for $_ on line $.\n";
		} 
	}
	
	if ($debug{'readpapernums'}){
		foreach $idval ( keys %papernumbers ){
			print "paper numbers for sufi/linzid ",$idval," are:\n";
			for ( @{$papernumbers{$idval}} ){
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

sub check_for_number_present{
	my $onerdid;
	my $number;
	my $rdsegno;
	my $numseg;
	my @numa;
	my $missnum;
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
			for $number ( keys %{$x{$onerdid}}){
				if ( numberisinpaperfile($number,$onerdid)){
					delete $x{$onerdid}{$number};
					delete $y{$onerdid}{$number};
				}
			}
			my @nums = sort{ $a <=> $b } keys %{$x{$onerdid}};
			if ($#nums >= 0 ){
				print "$sufiroadname{$onerdid}\t$onerdid\tnot found in map.\t$nums[0]\t$y{$onerdid}{$nums[0]},$x{$onerdid}{$nums[0]}";
				if ($#nums > 0 ){
					print "\t$nums[$#nums]\t$y{$onerdid}{$nums[$#nums]},$x{$onerdid}{$nums[$#nums]}\n";
				} else {
					print "\n";
				}
				local $, = ',';
				for my $i(0..$#nums) {
					print MISSFILE $x{$onerdid}{$nums[$i]},$y{$onerdid}{$nums[$i]},"$nums[$i] $sufiroadname{$onerdid}","$onerdid\n";
				}
			}
		}
	}

	print "check for house numbers missing from the map...\n";
	
	foreach $onerdid ( keys %sufiroadname ){
		#$onerdid = 1030000054126; {
		if (defined($byid->{$onerdid})){
			$missthis = 0;
			$manual = 0;
			
			NUM: for $number ( sort {$a <=> $b} keys %{$x{$onerdid}}){
				for $rdsegno (@{$byid->{$onerdid}}){
					if ($roads[$rdsegno][17]==-1) {$manual = 1};
					for $numseg( @{$roads[$rdsegno][11]} ){
						next NUM if findnumberinseg($number,@{$numseg}[1..3]);
						next NUM if findnumberinseg($number,@{$numseg}[4..6]);
					}
				}
				
				next NUM if numberisinpaperfile($number,$onerdid);
				
				local $, = ',';
				print "$number $sufiroadname{$onerdid} not found. ";
				print "$idnm is $onerdid. ";
				print "Should be ~ $y{$onerdid}{$number},$x{$onerdid}{$number}";
				print $manual ? " *Manual*\n" : "\n";
				print MISSFILE $x{$onerdid}{$number},$y{$onerdid}{$number},"$number $sufiroadname{$onerdid}","$onerdid\n";
				$missnum++;
				if ($missthis == 0){
					$missid++;
					$missthis++;
				} 
				 
			}
		} 
	}
	print "$missnum missing numbers on $missid roads\n";
}

##### Main program starts...

getopts("ls", \%cmdopts);
if (!($cmdopts{s} or $cmdopts{l})){
	$cmdopts{l}=1;
}

die "No filename specified" if ($ARGV[0] eq "");
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

id_check;	
routing_check;
odd_even_zero_check;
sort_by_id;

#dump_by_roadid;
#dump_by_roadid(52131);

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
numbered_id0;

road_overlap;
overlap_check;

open(MISSFILE, '>', "${basefile}_missing.csv") or die "can't create missing csv file\n";

unnumbered_node_check;

read_roads_not_2_index($basedir);
no_city_index;

read_number_csv($basefile,$basedir);
read_paper_road_numbers($basefile,$basedir);
check_for_number_present;