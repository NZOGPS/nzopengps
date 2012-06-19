use strict;
my $lid;
my $name;
my $latlon;
my $lat;
my $lon;

open (OUT,">","report2.csv") or die "can't open output file\n";
$, = ",";
$\ = "\n";
while (<>){
	if (/;linzid=(\d+)/){
		$lid = $1;
		(undef,$name,$latlon) = split /\t/;
		chomp $latlon;
		($lat,$lon) = split /,/,$latlon;
		print OUT $lon,$lat,$name,$lid;
	}
}