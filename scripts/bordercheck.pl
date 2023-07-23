use strict;
use Data::Dumper;
use Getopt::Std;

my %tiles;
my @direction = qw(North East South West);
my %restrictions;
my %options=();

sub setpt1{
	my $ph = shift;
	my $y = shift;
	my $x = shift;
	my @max;
	my @maxp;
	my $edge;
	
	$ph->{max} = \@max;
	$ph->{maxp} = \@maxp;
	
	for $edge(0..3){
		if ($edge % 2){
			$max[$edge] = $x;
			$maxp[$edge] = $y;
		} else {
			$max[$edge] = $y;
			$maxp[$edge] = $x;
		}
	}
#	print "Extrema:\n";
#	print "\tMax Lat = $ph->{max}[0]\n";
#	print "Lon = $ph->{max}[3] to $ph->{max}[1]\n";
#	print "\tMin Lat = $ph->{max}[2]\n";

}

sub setextremes{
	my $ph = shift;
	my $y = shift;
	my $x = shift;

	if ( $y > $ph->{max}[0] ){
		$ph->{max}[0] = $y;
		$ph->{maxp}[0] = $x;
	}
	if ( $x > $ph->{max}[1] ){
		$ph->{max}[1] = $x;
		$ph->{maxp}[1] = $y;
	}
	if ( $y < $ph->{max}[2] ){
		$ph->{max}[2] = $y;
		$ph->{maxp}[2] = $x;
	}
	if ( $x < $ph->{max}[3] ){
		$ph->{max}[3] = $x;
		$ph->{maxp}[3] = $y;
	}
}

sub printmaxpoint{
	my $tile = shift;
	my $edge = shift;
	print "First found point at the tile edge extreme is at ";
	if ($edge %2){
		print "$tiles{$tile}->{maxp}[$edge],$tiles{$tile}->{max}[$edge]\n";
	} else {
		print "$tiles{$tile}->{max}[$edge],$tiles{$tile}->{maxp}[$edge]\n";
	}
}

sub ReadRestrict{
	my $nodl = (<INF>); #Nod=
	unless ($nodl =~ /^Nod=(\d+)/) { die "Nod= not found in restrictions: $nodl\n"; }
	my $nod = $1;
	my $tpl = (<INF>); #TraffPoints
	unless ($tpl =~ /^TraffPoints=(\d+),(\d+),(\d+)/) { die "Invalid TraffPoints found in restrictions: $tpl\n"; }
	my @tpa = ($1,$2,$3);
	my $trl = (<INF>); #TraffRoads
	unless ($trl =~ /^TraffRoads=(\d+),(\d+)/) { die "Invalid TraffRoads found in restrictions: $trl\n"; }
	my @tra = ($1,$2);
	my $erl = (<INF>); #End
	unless ($erl =~ /^\[END-Restrict\]$/) { die "Invalid End restrictions: $erl\n"; }
	my @prms = (@tpa,@tra);
	$restrictions{$nod} = \@prms;
}

sub readtile{
	my $fn = shift;
	my $ffn = "..\\$fn.mp";
	my $pt1 = 1;
	my %vals;
	my @datax;
	my @datay;
	my $label;
	my $level;

	%restrictions = ();
	open (INF,$ffn) or die "Can't open $ffn\n";
	print "reading $ffn\n";
	$tiles{$fn}=\%vals;
	while (<INF>){
		if (/^Data(\d)=/) {
			my $level = $1;
			my @points = split /\)\,\(/;
			my $cnt = $#points;
			if (!($points[0]=~s/^Data\d=\(//)){
				print STDERR "Could not find dataN=( - line $.\n";
			}
			if (!($points[ $cnt ]=~s/\)$//)){
				print STDERR "Could not find closing ) - line $.\n";
			}
			for (@points){
				if (/(.*),(.*)/){
					push @datay,$1;
					push @datax,$2;
					if ($pt1){
						setpt1(\%vals,$1,$2);
						$pt1=0;
					} else {
						setextremes(\%vals,$1,$2);
					}		
				} else {
					print STDERR "did not find comma - line $.\n";
				}
			}
		}
		
		if (/^Label=(.*)/){
			$label = $1;
		}
		
		if (/^EndLevel=(.*)/){
			$level = $1;
		}
		
		if (/^\[END\]/){
			@datax=();
			@datay=();
			$label = "";
			$level = 0;
		}
		
		if (/^Nod\d+=(\d+),(\d+),1/){
			my $nodnum = $1;
			my $nodid = $2;
#			print "External node: $nodnum,$nodid : $label - $datay[$nodnum],$datax[$nodnum]\n";
			push @{$vals{bx}},$datax[$nodnum];
			push @{$vals{by}},$datay[$nodnum];
			push @{$vals{bl}},$label;
			push @{$vals{be}},$level;
			if ($restrictions{$nodid}){
				print "Warning! External node: $nodnum,$nodid : $label - $datay[$nodnum],$datax[$nodnum] appears in restriction list.\n";
			}
		}
		if (/^\[Restrict\]$/){
			ReadRestrict();
		}
	}
	close(INF);
#	print Dumper(\%restrictions);
}
	
sub AssignEdge{
	my $tile = shift;
	my $bx = $tiles{$tile}->{bx};
	my $by = $tiles{$tile}->{by};
	my $edge;
	my @max = @{$tiles{$tile}->{max}};
	my $val;
	my @err;
	my @ok;
	my $err;
	my $i;

	for $i (0..$#{$bx}) {
#		print "edge node $i at $tiles{$tile}->{by}[$i],$tiles{$tile}->{bx}[$i]\n";
		for $edge(0..3){
			$val = $edge % 2 ? ${$bx}[$i] : ${$by}[$i];
#			print "\tcompare: $max[$edge] to $val\n";
			if ( $val == $max[$edge]){
				#be (endlevel) at end since it was 'retrofitted'...
				push @{$tiles{$tile}->{bn}[$edge]},[$tiles{$tile}->{bl}[$i],${bx}->[$i],${by}->[$i],0,$tiles{$tile}->{be}[$i]];
				$tiles{$tile}->{en}[$i] += 1 << $edge;
				$ok[$edge]++;
#				print "node is on edge $edge\n";
			} else {
				if (abs($val - $max[$edge]) < 0.01){
					$tiles{$tile}->{en}[$i] += 1 << $edge + 4;
					$err[$edge]++;
					$err = 1;
					push @{$tiles{$tile}->{bn}[$edge]},[$tiles{$tile}->{bl}[$i],${bx}->[$i],${by}->[$i],1,$tiles{$tile}->{be}[$i]];
#					print "node is near edge $edge\n";
				}
			}
		}
	}
	if ($err){
		my @maxp = @{$tiles{$tile}->{maxp}};
		for $edge (0..3){
			if ($err[$edge]){
				print "Error! Some routing nodes along the $direction[$edge] edge";
				print " of the $tile tile aren't at the tile edge\n";
				printmaxpoint($tile,$edge);
				print "$err[$edge] routing node";
				print $err[$edge]>1 ? "s are" : " is";
				print " not at the edge, ";
				print $ok[$edge]? $ok[$edge] : "no";
				print " routing node";
				print $ok[$edge]!=1 ? "s are" : " is";
				print " at the edge\n";
				$i = 0;
				while ($tiles{$tile}->{bn}[$edge][$i][3]==0 and $i < $#{$bx} ) {
					$i++;
				}
				die "invalid logic! reached bx_max\n" if $i == $#{$bx};
				print "First off-edge node is on $tiles{$tile}->{bn}[$edge][$i][0] at $tiles{$tile}->{bn}[$edge][$i][2],$tiles{$tile}->{bn}[$edge][$i][1]\n";
			}
		}
	}
}

sub PrintNodes{
	my $tile = shift;
	my $bnp = shift;
	my $i;
	my @bxp = sort {$a->[1] <=> $b->[1]} @{$bnp};
	print "all nodes on tile $tile\n";
	for $i (0..$#bxp) {
		print "\t$bxp[$i][0] EndLevel $bxp[$i][4] at $bxp[$i][2],$bxp[$i][1]\n";
	}
}

sub CheckEdgeNodes{
	my($tile1,$bnp1,$tile2,$bnp2) = @_;
	my $i;
	my $j;
	
#	PrintNodes($tile1,$bnp1);
#	PrintNodes($tile2,$bnp2);

	T1: for $i (0..$#{$bnp1}){
		T2: for $j (0..$#{$bnp2}){
			if (uc($bnp1->[$i][0]) eq uc($bnp2->[$j][0]) and $bnp1->[$i][1]==$bnp2->[$j][1] and $bnp1->[$i][1]==$bnp2->[$j][1]){
#				print "nodes for $bnp1->[$i][0] at $bnp1->[$i][2],$bnp1->[$i][1] are the same\n";
				$bnp1->[$i][5]=1;
				$bnp2->[$j][5]=1;
				if (($bnp1->[$i][4]) !=($bnp2->[$j][4])){ #check end levels
					print "End Levels are different!\n";
					print "\t$bnp1->[$i][0] at $bnp1->[$i][2],$bnp1->[$i][1] - Levels are $bnp1->[$i][4],$bnp2->[$j][4]\n";
				}
				next T1;
			}
		}
	}
		
	$i=$#{$bnp1};
	while ($i>=0){
		if ($bnp1->[$i][5]){
			splice @{$bnp1},$i,1;
		}
		$i--;
	}
	
	if (@{$bnp1}){
		print "Unmatched nodes on the $tile1 tile:\n";
		for $i (0..$#{$bnp1}){
			print "\t$bnp1->[$i][0] at $bnp1->[$i][2],$bnp1->[$i][1]\n";
		}
	}
	
	
	$i=$#{$bnp2};
	while ($i>=0){
		if ($bnp2->[$i][5]){
			splice @{$bnp2},$i,1;
		}
		$i--;
	}

	if (@{$bnp2}){
		print "Unmatched nodes on the $tile2 tile:\n";
		for $i (0..$#{$bnp2}){
			print "\t$bnp2->[$i][0] at $bnp2->[$i][2],$bnp2->[$i][1]\n";
		}
	}
}

sub CheckEdge{
	my($tile1,$edge1,$tile2,$edge2) = @_;
	if ($tiles{$tile1}->{max}[$edge1]!=$tiles{$tile2}->{max}[$edge2]){
		print "Error - tile edges are not at the same coordinate!\n";
		print "$direction[$edge1] edge of $tile1 tile is at $tiles{$tile1}->{max}[$edge1]\n";
		printmaxpoint($tile1,$edge1);
		print "$direction[$edge2] edge of $tile2 tile is at $tiles{$tile2}->{max}[$edge2]\n";
		printmaxpoint($tile2,$edge2);
	} else {
		print "Tile border is at $tiles{$tile1}->{max}[$edge1]\n";
	}
	
	if ($#{$tiles{$tile1}->{bn}[$edge1]} == $#{$tiles{$tile2}->{bn}[$edge2]}){
		my $cnt = @{$tiles{$tile1}->{bn}[$edge1]};
		print "There".($cnt==1?" is ":" are ").$cnt." correct routing node".($cnt==1?"\n":"s\n");
		CheckEdgeNodes($tile1,$tiles{$tile1}->{bn}[$edge1],$tile2,$tiles{$tile2}->{bn}[$edge2]);
	} else {
		print "Error! - tiles have different numbers of routing nodes!\n";
		print "$direction[$edge1] edge of $tile1 tile has $#{$tiles{$tile1}->{bn}[$edge1]}\n";
		print "$direction[$edge2] edge of $tile2 tile has $#{$tiles{$tile2}->{bn}[$edge2]}\n";
		if ($#{$tiles{$tile1}->{bn}[$edge1]} > $#{$tiles{$tile2}->{bn}[$edge2]}){
		CheckEdgeNodes($tile1,$tiles{$tile1}->{bn}[$edge1],$tile2,$tiles{$tile2}->{bn}[$edge2]);
		} else {
		CheckEdgeNodes($tile2,$tiles{$tile2}->{bn}[$edge2],$tile1,$tiles{$tile1}->{bn}[$edge1]);
		}
	}
}
		
sub CheckTiles{
	my($tile1,$edge1,$tile2,$edge2) = @_;
	print "checking border between edge $edge1 of $tile1 tile and edge $edge2 of $tile2 tile\n";
	if (!defined($tiles{$tile1})){
		readtile($tile1);
		AssignEdge($tile1);
	}
	if (!defined($tiles{$tile2})){
		readtile($tile2);
		AssignEdge($tile2);
	}
	CheckEdge($tile1,$edge1,$tile2,$edge2);
}

getopts("1234567",\%options) || die "Invalid options\n";
if ( not %options ) {
	print "usage: $0 [-n][-m] for individual tile edges numbered from the S or no parameters for all tiles\n";
	%options = (1,1,2,1,3,1,4,1,5,1,6,1,7,1);
}

if ($options{1}) { CheckTiles ('Southland',0,'Canterbury',2)}
if ($options{2}) { CheckTiles ('Canterbury',0,'Tasman',2)}
if ($options{3}) { CheckTiles ('Tasman',1,'Wellington',3)}
if ($options{4}) { CheckTiles ('Wellington',0,'Central',2)}
if ($options{5}) { CheckTiles ('Central',0,'Waikato',2)}
if ($options{6}) { CheckTiles ('Waikato',0,'Auckland',2)}
if ($options{7}) { CheckTiles ('Auckland',0,'Northland',2)}

#for my $key (keys %tiles){
#	my $tk = $tiles{$key};
#	print "Extrema for $key:\n";
#	print "\tMax Lat = $tk->{max}[0]\n";
#	print "Lon = $tk->{max}[3] to $tk->{max}[1]\n";
#	print "\tMin Lat = $tk->{max}[2]\n";
#
#	for my $ni (0..$#{$tiles{$key}->{bx}}){
#		print "edge node $ni at $tk->{by}[$ni],$tk->{bx}[$ni] on $tk->{bl}[$ni] on edge $tk->{en}[$ni]\n";
#	}
#}
