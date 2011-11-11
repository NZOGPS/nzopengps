use strict;
my $tile = $ARGV[0];
my %lids;
my $filename;
my $line;
my $lid;
my $type;
my $label;
my $data0;

sub process_road(){
	my $endlevel = 1;
	my $route = "2,0,0,0,0,0,0,0,0,0,0,0";
	my $sufi = "";
	
	if ($lids{$lid}){
		if (not $label =~ /STATE HIGHWAY/){
			$endlevel = 1;
			$route = "7,0,0,0,0,0,0,0,0,0,0,0";
		}
	}
	if ($label eq "ACCESSWAY"){
		$type = "0x16";
		$label = "WALKWAY";
		$route = "0,0,0,0,1,1,1,1,1,0,0,1";
		$sufi = "sufi=0\n";
	}
	
	if ($label eq "SERVICE LANE"){
		$type = "0x15";
		$route = "1,0,0,0,0,0,0,1,0,0,0,0";
		$sufi = "sufi=0\n";
	}
			
	print OUT "\n";
	print OUT ";linzid=$lid\n";
	print OUT "[POLYLINE]\n";
	print OUT "Type=$type\n";
	print OUT "Label=$label\n";
	print OUT "EndLevel=$endlevel\n";
	print OUT "Data0=$data0\n";
	print OUT "RouteParam=$route\n";
	print OUT "[END]\n";
}	
	
die "usage: $0 tilename\n" if $tile eq ""; 

$filename = "outputs/$tile-report.txt";
open (REPORT, $filename) or die "$filename not found\n";
HEADER: while (<REPORT>) {
	last HEADER if /[\d]+ LINZ ids are missing/;
}
BODY: while (<REPORT>) {
	last BODY if /#{20}+/;
	if (/^;linzid=(\d+)\t\D+/){
		$lids{$1}=1;
	}
}
close REPORT;

$filename = "../LinzDataService/outputslinz/$tile-LINZ.mp";
open (MP, $filename) or die "$filename not found\n";

$filename = "../LinzDataService/outputslinz/$tile-LINZ-V2.mp";
open (OUT, ">", $filename) or die "$filename not found\n";

HEADER: while (<MP>) {
	print OUT $_;
	last HEADER if /\[END-Regions\]/;
}

LINE: while (<MP>) {
	chomp;
	next LINE if $_ eq "";
	$line = $_;
	if ($line =~ /;linzid=(\d+)/) {$lid = $1} else {die "linzid not found line $. - $line\n"};
	$line = <MP>; #skip the polyline;
	$line = <MP>;
	if ($line =~ /Type=(.+)/) {$type = $1} else {die "type not found line $. - $line\n"};
	$line = <MP>;
	if ($line =~ /Label=(.+)/) {$label = $1} else {die "label not found line $. - $line\n"};
	$line = <MP>; #skip the endlevel;
	$line = <MP>;
	if ($line =~ /Data0=(.+)/) {$data0 = $1} else {die "data0 not found line $. - $line\n"};
	$line = <MP>; #skip routeparam
	$line = <MP>; #skip end
	process_road();
}
