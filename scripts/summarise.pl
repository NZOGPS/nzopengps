use strict;
use Data::Dumper;

my $base = $ENV{'nzogps_base'};
my $linzout = "$base/linzdataservice/outputs";
my $outputs = "$base/scripts/outputs";
my $checker = "$base/checker";
my @tiles = ("Northland","Auckland","Waikato","Central","Wellington","Tasman","Canterbury","Southland");
my @abbtiles = ("Northland"," Auckland","  Waikato","  Central","Wellngton","   Tasman","Canterbry","Southland");

my @tiled;
my %results;
my $debug = 0;

sub get_file_dates {
	my $tile = shift;
	my $resultsp = shift;
	my @stats;
	my $datet;
	my $fn = "$base/$tiles[$tile].mp";
	$fn =~ s/\"//g;
	print "gfd: file is $fn\n" if $debug;
	@stats = stat($fn);
	$tiled[$tile] =$stats[9];
	$datet=localtime($tiled[$tile]);
	print "gfd: date is $tiled[$tile] - $datet\n" if $debug;
}

sub do_report2 {

	my $tile = shift;
	my $resultsp = shift;
	my @stats;
	$resultsp->{'missrds'}[$tile]=0;
	$resultsp->{'extras'}[$tile]=0;

	my $fn = "$outputs/$tiles[$tile]-report-2.txt";
	$fn =~ s/\"//g;
	print "dr2: file is $fn\n" if $debug;
	@stats = stat($fn);
	$resultsp->{'rep2d'}[$tile] =$stats[9];
	open(REP2,$fn) or die "can't open $fn";
	while (<REP2>){
#		print "$_";
		if(/(\d+) LINZ ids are missing/) {
			$resultsp->{'missrds'}[$tile]=$1;
			print "missrds[$tile] is $resultsp->{'missrds'}[$tile]\n" if $debug;
		}
		if(/(\d+) LINZ ids are in NZOGPS/) {
			$resultsp->{'extras'}[$tile]=$1;
			print "extras[$tile] is $resultsp->{'extras'}[$tile]\n" if $debug;
		}
	}
	close(REP2);
}

sub do_report6 {

	my $tile = shift;
	my $resultsp = shift;
	my @stats;

	my $fn = "$outputs/$tiles[$tile]-report-6.txt";
	$fn =~ s/\"//g;
	@stats = stat($fn);
	$resultsp->{'rep6d'}[$tile] =$stats[9];
	$resultsp->{'wrongn'}[$tile]=0;
	print "dr6: file is $fn\n" if $debug;
	open(REP6,$fn) or die "can't open $fn";
	while (<REP6>){
#		print "$_";
		if(/(\d{5,})\t[A-Z]/) {
#			print "found id $1\n";
			$resultsp->{'wrongn'}[$tile]++;
		}
	}
	print "wrongn[$tile] is $resultsp->{'wrongn'}[$tile]\n" if $debug;
	close(REP6);
}

sub do_checker {

	my $tile = shift;
	my $resultsp = shift;
	my @stats;

	my $fn = "$checker/$tiles[$tile]_num_err.txt";
	$fn =~ s/\"//g;
	@stats = stat($fn);
	$resultsp->{'checkd'}[$tile] =$stats[9];
	$resultsp->{'chkmissno'}[$tile]=-1;
	$resultsp->{'chkmissrd'}[$tile]=-1;
	$resultsp->{'chkmissol'}[$tile]=0;
	
	print "dochk: file is $fn\n" if $debug;
	open(CHKF,$fn) or die "can't open $fn";
	while (<CHKF>){
#		print "$_";
		if(/(\d+) missing numbers* on (\d+) road/) {
			print "found missing $1 on $2\n" if $debug;
				$resultsp->{'chkmissno'}[$tile]=$1;
				$resultsp->{'chkmissrd'}[$tile]=$2;
		}
		if(/(\d+) already set in RoadID (\d+)/) {
			print "found overlap of $1 on $2\n" if $debug;
				$resultsp->{'chkmissol'}[$tile]++;
		}
		if(/Unindexed road:\tRoad is (.*),/) {
			print "found unindexed road $1\n" if $debug;
				$resultsp->{'chkmissui'}[$tile]++;
		}

	}
}

sub print_results{
	my @colw;
	my $col0w = 17;

	print("\n");
	printf("%*s |",$col0w,"");
	for my $tile(0..$#tiles){
		print(" $abbtiles[$tile] |");
		$colw[$tile]=length($abbtiles[$tile]);
	}

if ($debug){
		print("\n");
		printf("%*s |",$col0w,"File date");
		for my $tile(0..$#tiles){
		my ($sec, $min, $hour, $mday, $mon, $year_offset) = localtime($tiled[$tile]);
		my $month = $mon + 1; # Adjust month to be 1-based (1-12)
		printf(" %02d/%02d %02d%02d|",$colw[$tile],$mon,$mday,$hour,$min);
		}
	}

	print("\n");
	printf("%*s |",$col0w,"Missing roads");
	for my $tile(0..$#tiles){
		if ($results{'missrds'}[$tile]) {
			printf(" %*d |",$colw[$tile],$results{'missrds'}[$tile]);
		} else {printf(" %*s |",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Roads not in LINZ");
	for my $tile(0..$#tiles){
		if ($results{'extras'}[$tile]) {
			printf(" %*d |",$colw[$tile],$results{'extras'}[$tile]);
		} else {printf(" %*s |",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Report2 Old");
	for my $tile(0..$#tiles){
		printf(" %*s |",$colw[$tile],($results{'rep2d'}[$tile]<$tiled[$tile])?"==YES==":"");
	}

	print("\n");
	printf("%*s |",$col0w,"Different name");
	for my $tile(0..$#tiles){
		if ($results{'wrongn'}[$tile]) {
			printf(" %*d |",$colw[$tile],$results{'wrongn'}[$tile]);
		} else {printf(" %*s |",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Report6 Old");
	for my $tile(0..$#tiles){
		printf(" %*s |",$colw[$tile],($results{'rep6d'}[$tile]<$tiled[$tile])?"==YES==":"");
	}

	print("\n");
	printf("%*s |",$col0w,"Number overlaps");
	for my $tile(0..$#tiles){
		if ($results{'chkmissol'}[$tile]) {
			printf(" %*d |",$colw[$tile],$results{'chkmissol'}[$tile]);
		} else {printf(" %*s |",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Unindexed road");
	for my $tile(0..$#tiles){
		if ($results{'chkmissui'}[$tile]) {
			printf(" %*d |",$colw[$tile],$results{'chkmissui'}[$tile]);
		} else {printf(" %*s |",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Missing numbers");
	for my $tile(0..$#tiles){
		printf(" %*d |",$colw[$tile],$results{'chkmissno'}[$tile]);
	}

	print("\n");
	printf("%*s |",$col0w,"on different rds");
	for my $tile(0..$#tiles){
		printf(" %*d |",$colw[$tile],$results{'chkmissrd'}[$tile]);
	}

	print("\n");
	printf("%*s |",$col0w,"Checker Old");
	for my $tile(0..$#tiles){
		printf(" %*s |",$colw[$tile],($results{'checkd'}[$tile]<$tiled[$tile])?"==YES==":"");
	}
}

for my $tile(0..$#tiles){
	get_file_dates($tile,\@tiled);
	do_report2($tile,\%results);
	do_report6($tile,\%results);
	do_checker($tile,\%results);
}
print Dumper(%results) if $debug;
print Dumper(@tiled) if $debug;

print_results();
