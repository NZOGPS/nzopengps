use strict;
use warnings;
use Data::Dumper qw(Dumper);

my $tilen;
my $infn;
my $csvfn;
my $done;
my %vars;
my $tbuf;
my $cmmt;
my %changes;

sub readCSV {
	my $city;
	my %val;
	# %changes=('Acacia Bay, Taupo'=> {
		# 'x'=>176.03196,
		# 'y'=>-38.70442,
		# 'type'=>'0xb00',
		# 'cid'=>125,
	# });
	# print Dumper %changes;
	while (<CCSV>){
		undef %val;
		chomp;
		($val{'x'},$val{'y'},$city,$val{'city'},$val{'cid'}) = split /,/;
		$changes{$city}={%val};
	}
	 print Dumper %changes;

}

sub dochunk {
	my $coordstr;
	my @coords;
	my @x;
	my @y;
	undef $tbuf;
	undef %vars;

	while (<MPF>){
		$tbuf .= $_;
		if (/;/){
			$cmmt .= $_;
		}
		if (/(.*)=(.*)/){
			$vars{$1}=$2;
			if ($1 eq 'Data0'){
#				print("is data0\n");
				$coordstr = $2;
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
						push @y,$1;
						push @x,$2;
					} else {
						print "invalid coord: $_ line $.\n";
					}
				}
				$vars{'x'}=\@x;
				$vars{'y'}=\@y;
			}
		}
		if (/^\[END/){
#			print ("x: @x y: @y\n");
#			print ("x0: $x[0],$vars{'x'}->[0]\n");
			if (defined $vars{'Label'}){ 
				if (defined $changes{$vars{'Label'}}){
#					 print Dumper $changes{$vars{'Label'}},$changes{$vars{'Label'}}->{'x'};
					if (defined $vars{'x'} && $vars{'x'}->[0]==$changes{$vars{'Label'}}->{'x'}){
#						print "x OK\n";
						if (defined $vars{'y'} && $vars{'y'}->[0]==$changes{$vars{'Label'}}->{'y'}){
#							if (defined $vars{'Type'} && $vars{'Type'} eq $changes{$vars{'Label'}}->{'type'}){
								$tbuf =~ s/\[END\]/CityIDX=$changes{$vars{'Label'}}->{'cid'}\n[END]/;
								print "Found it\n";
								print $tbuf;
#							}
						}
					}
				}
			}
			return 0;
		}
	}
#	print $tbuf;
	return 1;
}

die "No filename specified" if (!defined $ARGV[0]);
$tilen = $ARGV[0];
$infn = "..\\$ARGV[0].mp";

open(MPF,"<",$infn) or die "Can't open $infn\n";

$csvfn = "$ARGV[0]-mappoiswc.csv";
open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
readCSV();
close(CCSV);
$csvfn = "$ARGV[0]-mappoisnc.csv";
open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
readCSV();

do {
	$done = dochunk();
}
until $done;