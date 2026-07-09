use strict;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

my $base = $ENV{'nzogps_base'};
my $linzout  = "$base/linzdataservice/outputs";
my $outputs  = "$base/scripts/outputs";
my $checker  = "$base/checker";
my $wrongout = "$base/scripts/Wrongside2table/Outputs";
my $burbout  = "$base/scripts/Suburbs/Outputs";
my @tiles = ("Northland","Auckland","Waikato","Central","Wellington","Tasman","Canterbury","Southland");
my @abbtiles = ("Northland"," Auckland","  Waikato","  Central","Wellngton","   Tasman","Canterbry","Southland");

my @BurbSuffixes = ("checkPOIs","dupliPOIs","mappois","nearpois","sizecodes","unindexed","UnmatchedCities","UnusedCities","WrongCities2","WrongRegions","WrongXLTCityID","WrongXLTSLID");
my @BurbSuffAbbs = ("chkpoi","duppoi","mappoi","nrpoi","szcode","unindx","unmatct","unusect","wrngcit","wrngreg","wrngxctid","wrongxlid");

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
	$resultsp->{'chkunnumb'}[$tile]=0;
	$resultsp->{'chkundefn'}[$tile]=0;
	$resultsp->{'chkdirind'}[$tile]=0;
	$resultsp->{'chklinzid'}[$tile]=0;

	print "docheck: file is $fn\n" if $debug;
	open(CHKF,$fn) or die "can't open $fn";
	while (<CHKF>){
#		print "$_";

		if(/No missing numbers YAY!!!/) {
			print "YAY!!\n" if $debug;
				$resultsp->{'chkmissno'}[$tile]=0;
				$resultsp->{'chkmissrd'}[$tile]=0;
		}

		if(/(\d+) missing numbers* on (\d+) road/) {
			print "found missing $1 on $2\n" if $debug;
				$resultsp->{'chkmissno'}[$tile]=$1;
				$resultsp->{'chkmissrd'}[$tile]=$2;
		}

		if(/(\d+) already set in RoadID (\d+)/) {
			print "found overlap of $1 on $2\n" if $debug;
				$resultsp->{'chkmissol'}[$tile]++;
		}

		if(/dirindicator.*set/) {
			print "found dirindicator\n" if $debug;
				$resultsp->{'chkdirind'}[$tile]++;
		}

		if(/multiple.*linzid/) {
			print "found multiple linzid\n" if $debug;
				$resultsp->{'chklinzid'}[$tile]++;
		}

		if(/Unindexed road:\tRoad is (.*),/) {
			print "found unindexed road $1\n" if $debug;
				$resultsp->{'chkmissui'}[$tile]++;
		}

		if(/Warning -.*\d+ is not (odd|even)/) {
			print "found incorrect odd/even number\n" if $debug;
				$resultsp->{'chkoen'}[$tile]++;
		}

		if(/Error: unnumbered node. Road is /) {
			print "found undefined end\n" if $debug;
				$resultsp->{'chkunnumb'}[$tile]++;
		}

		if(/Warning - Number\[\d+\] from -*\d+ to -*\d+/) {
			print "found undefined end\n" if $debug;
				$resultsp->{'chkundefn'}[$tile]++;
		}
	}
}

sub do__Sparse{

	my $tile = shift;
	my $resultsp = shift;
	my @stats;
	
	$resultsp->{'sparse'}[$tile]=0;

	my $fn = "$wrongout/$tiles[$tile]-sparsest.csv";
	$fn =~ s/\"//g;
	print "dosp: file is $fn\n" if $debug;
	@stats = stat($fn);
	$resultsp->{'sparsed'}[$tile] =$stats[9];
	open(REP2,$fn) or die "can't open $fn";
	while (<REP2>){
#		if (/,\"Sparse: \d+m, nums:\d+\"/){
			$resultsp->{'sparse'}[$tile]++;
#		}
	}
}

sub do_WrongSd{

	my $tile = shift;
	my $resultsp = shift;
	my @stats;
	
	$resultsp->{'wrongsd'}[$tile]=0;

	my $fn = "$wrongout/$tiles[$tile]-wrongside.csv";
	$fn =~ s/\"//g;
	print "dows: file is $fn\n" if $debug;
	@stats = stat($fn);
	$resultsp->{'wrngsdt'}[$tile] =$stats[9];
	open(REP2,$fn) or die "can't open $fn";
	while (<REP2>){
#		if (/\",Wrong Side: \d+$/){
			$resultsp->{'wrongsd'}[$tile]++;
#		}
	}	
}

sub do_Suburbs{

	my $tile = shift;
	my $resultsp = shift;
	my @stats;
	
	for my $suffabb(@BurbSuffAbbs){
		$resultsp->{$suffabb}[$tile]=0;
	}
	while (my ($i, $suffa) = each @BurbSuffAbbs) {
		my $fn = "$burbout/$tiles[$tile]-$BurbSuffixes[$i].csv";
		$fn =~ s/\"//g;
		print "dosub: file is $fn\n" if $debug;
		@stats = stat($fn);
		$resultsp->{$suffa.'d'}[$tile] =$stats[9];
		open(REP2,$fn) or die "can't open $fn";
		while (<REP2>){
			$resultsp->{$suffa}[$tile]++;
		}	
	}
}

sub getBGcolour{
	my $tile = shift;
	my $parm = shift;
	my $rold;
	
	$rold = $results{$parm}[$tile]<$tiled[$tile];
#	printf "GetBGCol: tile=%d parm =%s rd = %d td= %d rold = %d\n",$tile,$parm,$results{$parm}[$tile],$tiled[$tile],$rold;
	return $rold?ON_RED:ON_BLACK;
}
	
sub print_results{
	my @colw;
	my $col0w = 17;
	my $bgc;

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
		$bgc =getBGcolour($tile,'rep2d'); 
		if ($results{'missrds'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'missrds'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Roads not in LINZ");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'rep2d'); 
		if ($results{'extras'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'extras'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Report2 Old");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'rep2d'); 
		printf($bgc." %*s ".RESET."|",$colw[$tile],($results{'rep2d'}[$tile]<$tiled[$tile])?"==YES==":"");
	}

	print("\n");
	printf("%*s |",$col0w,"Different name");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'rep6d'); 
		if ($results{'wrongn'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'wrongn'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Report6 Old");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'rep6d'); 
		printf($bgc." %*s ".RESET."|",$colw[$tile],($results{'rep6d'}[$tile]<$tiled[$tile])?"==YES==":"");
	}

	print("\n");
	printf("%*s |",$col0w,"Number overlaps");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkmissol'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkmissol'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}
	
	print("\n");
	printf("%*s |",$col0w,"wrong odd/even");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkoen'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkoen'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"undefined end");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkundefn'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkundefn'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"unnumbered node");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkunnumb'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkunnumb'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Unindexed road");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkmissui'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkmissui'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Direction error");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkdirind'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkdirind'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"LINZID error");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chklinzid'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chklinzid'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Missing numbers");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd');
		if ($results{'chkmissrd'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkmissno'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"on different rds");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		if ($results{'chkmissrd'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'chkmissrd'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Checker Old");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'checkd'); 
		printf($bgc." %*s ".RESET."|",$colw[$tile],($results{'checkd'}[$tile]<$tiled[$tile])?"==YES==":"");
	}

	print("\n");
	printf("%*s |",$col0w,"Sparse roads");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'sparsed'); 
		if ($results{'sparse'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'sparse'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

	print("\n");
	printf("%*s |",$col0w,"Wrong side nums");
	for my $tile(0..$#tiles){
		$bgc =getBGcolour($tile,'wrngsdt'); 
		if ($results{'wrongsd'}[$tile]) {
			printf($bgc." %*d ".RESET."|",$colw[$tile],$results{'wrongsd'}[$tile]);
		} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
	}

#suburbs
	while (my ($i, $suffa) = each @BurbSuffAbbs) {
		print("\n");
	printf("%*s |",$col0w,$BurbSuffixes[$i]);
		for my $tile(0..$#tiles){
			$bgc =getBGcolour($tile,$suffa.'d'); 
			if ($results{$suffa}[$tile]) {
				printf($bgc." %*d ".RESET."|",$colw[$tile],$results{$suffa}[$tile]);
			} else {printf($bgc." %*s ".RESET."|",$colw[$tile],"") }
		}
	}
}
$debug =0;

for my $tile(0..$#tiles){
	get_file_dates($tile,\@tiled);
	do_report2($tile,\%results);
	do_report6($tile,\%results);
	do_checker($tile,\%results);
	do__Sparse($tile,\%results);
	do_WrongSd($tile,\%results);
	do_Suburbs($tile,\%results);
}
print Dumper(%results) if $debug;
print Dumper(@tiled) if $debug;

print_results();
