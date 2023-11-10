use strict;
use warnings;
my $tilen;
my $infn;
my $csvfn;
my $done;
my %vars;
my $tbuf;
my $cmmt;

sub dochunk {
	undef $tbuf;
	undef %vars;

	while (<MPF>){
		$tbuf .= $_;
		if (/;/){
			$cmmt .= $_;
		}
		if (/(.*)=(.*)/){
			$vars{$1}=$2;
		}
		if (/^\[END/){
			if (defined $vars{'Data0'} and $vars{'Data0'} eq '(-38.70442,176.03196)'){
				print "Found it\n";
				print $tbuf;
			}
			return 0;
		}
	}
	print $tbuf;
	return 1;
}

die "No filename specified" if (!defined $ARGV[0]);
$tilen = $ARGV[0];
$infn = "..\\$ARGV[0].mp";
$csvfn = "$ARGV[0]-correct.csv";

open(MPF,"<",$infn) or die "Can't open $infn\n";
#open(CCSV,$csvfn) or die "Can't open $csvfn\n";
do {
	$done = dochunk();
}
until $done;