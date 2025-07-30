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
my $akey;
my $pval;
my %changes;
my %diffcodes;
my $changed = 0;
my $debug = 0;

sub readCSV {

	my $which = shift;
	my $city;
	my %val;
	my $entries = 0;
	my @what = ('index','code');
	
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
		if ($which == 0){
			($val{'x'},$val{'y'},$city,$val{'city'},$val{'cid'}) = split /,/;
			$changes{$city}={%val};
		}

		if ($which == 1){
			my @splitvals = split/,/;
			if ($splitvals[2] =~ m/^\"(.*)/) { #"burb
				my $s2 = $1;
				if ($splitvals[3] =~ m/(.*)\"$/){ #city"
					splice(@splitvals,2,2,"$s2,$1");
				}
			}
			($val{'x'},$val{'y'},$city,$val{'newcode'},$val{'oldcode'},$val{'popn'}) = @splitvals;
			$diffcodes{$city}={%val};
		}
	}
#	print STDERR Dumper %changes;
#	print STDERR Dumper %diffcodes;
	print STDERR "$entries $what[$which] changes to do\n";
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
#					print STDERR ("Label match $vars{'Label'}\n");
					if (defined $changes{$vars{'Label'}}){
#						 print STDERR Dumper $changes{$vars{'Label'}},$changes{$vars{'Label'}}->{'x'};
						if (defined $vars{'x'} && $vars{'x'}->[0]==$changes{$vars{'Label'}}->{'x'}){
							if (defined $vars{'y'} && $vars{'y'}->[0]==$changes{$vars{'Label'}}->{'y'}){
								if ($changes{$vars{'Label'}}->{'city'} ne '""'){
									$tbuf =~ s/Label=$vars{'Label'}/Label=$vars{'Label'}, $changes{$vars{'Label'}}->{'city'}/;
								}
								$tbuf =~ s/\[END\]/CityIDX=$changes{$vars{'Label'}}->{'cid'}\n[END]/;
								$changed++;
								$changes{$vars{'Label'}}->{'done'}=1;
							}
						}
					}

					if (defined $diffcodes{$vars{'Label'}}){
						if ($debug & 4) {print STDERR "DC1: ", Dumper $diffcodes{$vars{'Label'}},$diffcodes{$vars{'Label'}}->{'x'}};
						if (defined $vars{'x'} && $vars{'x'}->[0]==$diffcodes{$vars{'Label'}}->{'x'}){
							if (defined $vars{'y'} && $vars{'y'}->[0]==$diffcodes{$vars{'Label'}}->{'y'}){
								if (defined $vars{'Type'} && $vars{'Type'} eq $diffcodes{$vars{'Label'}}->{'oldcode'}){
									if ($debug & 4) { print STDERR "Match: ", "$vars{'Label'},$diffcodes{$vars{'Label'}}->{'oldcode'},$diffcodes{$vars{'Label'}}->{'newcode'}\n"};
									$tbuf =~ s/Type=$diffcodes{$vars{'Label'}}->{'oldcode'}/Type=$diffcodes{$vars{'Label'}}->{'newcode'}/;
									$changed++;
									$diffcodes{$vars{'Label'}}->{'done'}=1;
								} else {
									if ($debug & 4) { print STDERR "Not type - $vars{'Label'} $diffcodes{$vars{'Label'}}->{'oldcode'}\n"};
								}
							} else {
								if ($debug & 4) { print STDERR "Not y - $vars{'y'}->[0] $diffcodes{$vars{'Label'}}->{'y'}\n"};
							}
						} else {
							if ($debug & 4) { print STDERR "Not x - $vars{'Label'}  $vars{'y'}->[0],$vars{'x'}->[0] $diffcodes{$vars{'Label'}}->{'y'},$diffcodes{$vars{'Label'}}->{'x'}\n"};
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

$csvfn = "outputs\\$ARGV[0]-mappois.csv";
open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
readCSV(0);
close(CCSV);

$csvfn = "outputs\\$ARGV[0]-sizecodes.csv";
open(CCSV,"<",$csvfn) or die "Can't open $csvfn\n";
readCSV(1);
close(CCSV);

do {
	$done = dochunk();
}
until $done;
print STDERR "$changed changes made\n";

my $cntt = 0;
foreach $akey (keys %changes){
#	print STDERR "$akey\n";
#	print STDERR Dumper $changes{$akey};
	if(!defined($changes{$akey}->{'done'})){
		print STDERR "Unmatched: $akey\n";
	} else {
		if($changes{$akey}->{'done'}==1){
			#print STDERR "Unmatched: $akey\n";
			$cntt++;
		}
	}
}
print STDERR "$cntt changes done\n";
# print STDERR Dumper %diffcodes;