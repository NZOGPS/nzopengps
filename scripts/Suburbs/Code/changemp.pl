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
my $changed = 0;

sub readCSV {
	my $city;
	my %val;
	my $entries = 0;
	
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
		$entries++;
		($val{'x'},$val{'y'},$city,$val{'city'},$val{'cid'}) = split /,/;
		$changes{$city}={%val};
	}
#	print STDERR Dumper %changes;
	print STDERR "$entries changes to do\n";
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
		if (/\[([A-Z]*)\]/){
			if (not /END/){
				$vars{kind}=$1;
				# print STDERR "Kind is $vars{kind}\n";
			}
		}
		if (/(.*)=(.*)/){
			$vars{$1}=$2;
			if ($1 eq 'Data0'){
#				print STDERR("is data0\n");
				$coordstr = $2;
				if (! ($coordstr =~ s/^\(// )){
					print STDERR "Error - leading ( not found in coords- line $.\n";
				}
				if (! ($coordstr =~ s/\)$// )){
					print STDERR "Error - trailing ( not found in coords- line $.\n";
				}
				$coordstr =~ s/\),\(/\#/g;
				@coords = split(/\#/,$coordstr);
				for (@coords){
					if (/^(-*\d+\.\d+),(-*\d+\.\d+)$/){
						push @y,$1;
						push @x,$2;
					} else {
						print STDERR "invalid coord: $_ line $.\n";
					}
				}
				$vars{'x'}=\@x;
				$vars{'y'}=\@y;
			}
		}
		if (/^\[END/){
#			print STDERR ("x: @x y: @y\n");
#			print STDERR ("x0: $x[0],$vars{'x'}->[0]\n");
			if (defined $vars{kind} && $vars{kind} eq 'POI'){
				if (defined $vars{'Label'}){ 
					if (defined $changes{$vars{'Label'}}){
	#					 print STDERR Dumper $changes{$vars{'Label'}},$changes{$vars{'Label'}}->{'x'};
						if (defined $vars{'x'} && $vars{'x'}->[0]==$changes{$vars{'Label'}}->{'x'}){
							if (defined $vars{'y'} && $vars{'y'}->[0]==$changes{$vars{'Label'}}->{'y'}){
								if ($changes{$vars{'Label'}}->{'city'} ne '""'){
									$tbuf =~ s/Label=$vars{'Label'}/Label=$vars{'Label'}, $changes{$vars{'Label'}}->{'city'}/;
								}
								$tbuf =~ s/\[END\]/CityIDX=$changes{$vars{'Label'}}->{'cid'}\n[END]/;
								$changed++;
							}
						}
					}
				}
			}
		print $tbuf;
		return 0;
		}
	}
	print $tbuf;
	return 1;
}

die "No filename specified" if (!defined $ARGV[0]);
$tilen = $ARGV[0];
$infn = "..\\..\\$ARGV[0].mp";

open(MPF,"<",$infn) or die "Can't open $infn\n";

# $csvfn = "$ARGV[0]-mappoiswc.csv";
# open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
# readCSV();
# close(CCSV);
$csvfn = "outputs\\$ARGV[0]-mappois.csv";
open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
readCSV();

do {
	$done = dochunk();
}
until $done;
print STDERR "$changed changes made\n";