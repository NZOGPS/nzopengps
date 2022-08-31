use strict;
use warnings;
use feature qw "switch say";
use File::Basename;
use Cwd;

my $basefile;
my $basedir;
my $basesuff;
my $label;
my $pclabel;

die "No filename specified" if (!defined $ARGV[0]);
($basefile, $basedir, $basesuff) = fileparse($ARGV[0],qr/\.[^.]*/);
$basedir = Cwd::realpath($basedir);

my $ofn = "${basedir}/${basefile}-pc${basesuff}";
say "creating $ofn";
open(OUTFILE, '>', $ofn ) or die "can't create output file\n";


while (<>){
	if (/^Label=(.*)/) {
		$label = $1;
		if ($label eq uc $label){
			$pclabel = $label;
			$pclabel =~ s/([\w']+)/\u\L$1/g;
			s/$label/$pclabel/;
		}
	}
	print OUTFILE;
}