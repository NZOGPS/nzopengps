use strict;
use File::Basename;
	
my $lds = "..\\LinzDataService\\";
my $pdn = "${lds}PaperRoads\\";
# my $mappingfilename = "${lds}rna_mappings.csv";
my $mappingfilename = "${lds}new_street_address_ids.csv";
my %idmap;
my $cnt;
my $oldfn;
my $newfn;
my $basefile;
my $basedir;
my $basesuff;
my $oldid;
my $mode;
my $dienomatch = 0;

$idmap{0}=0;

sub do_paper_file{
	if (-r $oldfn){
		$cnt = 0;
		$newfn = $oldfn;
		$newfn =~ s!\.(?=[^.]*$)!\.remapped\.!;
		print "Creating new file $newfn\n";
		open INF, $oldfn or die "Cannot open Paper road file $oldfn\n";
		open MAPPEDF,">",$newfn or die "Cannot create new map file $newfn\n";
		while (<INF>){
			if (/(\d+)\t/){
				$cnt++;
				$oldid = $1;
				if (defined($idmap{$oldid})) {
					s/^$oldid/$idmap{$oldid}/;
					$cnt++;
				} else {
					if ($dienomatch){
						print "ERROR! linzid map for $1 not found! File $oldfn line $.\n";
						s/^$oldid/###$oldid### - no new mapping for linzid found/;
					}
				}
			}
			print MAPPEDF $_;
		}
		close INF;
		close MAPPEDF;
		print "$cnt linzids remapped\n";
	} else {
		print "$oldfn not found. Skipped\n";
	}
}

open IDF, $mappingfilename or die "Cannot find id mapping file $mappingfilename\n";
while (<IDF>){
	if (/(\d+),(\d+)/){
		if ($idmap{$1}){
			die "map for $1 already set to $idmap{$1} Duplicate on line $.\n";
		}
		$idmap{$1}=$2;
		$cnt++;
	}
}
print "$cnt mappings set\n";
close IDF;
$cnt = 0;

die "No filename specified" if ($ARGV[0] eq "");
$oldfn = $ARGV[0];
($basefile, $basedir, $basesuff) = fileparse($oldfn,qr/\.[^.]*/);

if (1){
	open INF, $oldfn or die "Cannot find map $oldfn\n";
	$newfn = $oldfn;
	$newfn =~ s!\.(?=[^.]*$)!\.remapped\.!;
	print "Creating new file $newfn\n";
	open MAPPEDF,">",$newfn or die "Cannot create new map file $newfn\n";
	while (<INF>){
		if (/linzid\d?=(\d+)/){
			$oldid = $1;
			if (defined($idmap{$oldid})) {
				s/$oldid/$idmap{$oldid}/;
				$cnt++;
			} else {
				if ($dienomatch){
					print "ERROR! linzid map for $1 not found! File $oldfn line $.\n";
					s/$oldid/###$oldid### - no new mapping for linzid found/;
				}
			}  
		}
		print MAPPEDF $_;
	}
	close INF;
	close MAPPEDF;
	print "$cnt linzids remapped\n";
	
	#Paper roads
	
	$oldfn = "${pdn}${basefile}.txt";
	$mode = "Paper road";
	do_paper_file;
	
	$oldfn = "${pdn}${basefile}PaperNumbers.txt";
	$mode = "Paper Numbers";
	do_paper_file;
}

$oldfn = "${pdn}${basefile}-LINZWrongSide.txt";
$mode = "LINZ Wrongside";
do_paper_file;

$oldfn = "${pdn}${basefile}-WrongSide.txt";
$mode = "Wrongside";
do_paper_file;
