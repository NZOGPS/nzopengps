use strict;
use warnings;
use File::Basename;

my $lds = "..\\LinzDataService\\";
my $pdn = "${lds}PaperRoads\\";
# my $mappingfilename = "${lds}rna_mappings.csv";
my $mappingfilename = "${lds}new_street_address_ids.csv";
my %idmap;
my $cnt;
my $filfn;
my $bakfn;
my $basefile;
my $basedir;
my $basesuff;
my $oldid;
my $mode;
my $dienomatch = 0;

$idmap{0}=0;

sub do_paper_file{
	if (-r $filfn){
		$cnt = 0;
		$bakfn = $filfn;
		$bakfn =~ s!\.(?=[^.]*$)!\.old_ids\.!;
		print "Renaming $mode file as $bakfn\n";
		rename ($filfn, $bakfn) or die "Failed to rename $filfn as $bakfn\n";
		open INF, $bakfn or die "Cannot find paper $bakfn\n";
		open PAPERF,">",$filfn or die "Cannot create new $mode file $filfn\n";
		while (<INF>){
			if (/(\d+)\t/){
				$oldid = $1;
				if (defined($idmap{$oldid})) {
					s/^$oldid/$idmap{$oldid}/;
					$cnt++;
				} else {
					if ($dienomatch){
						print "ERROR! linzid map for $1 not found! File $bakfn line $.\n";
						s/^$oldid/###$oldid### - no new mapping for linzid found/;
					}
				}
			}
			print PAPERF $_;
		}
		close INF;
		close PAPERF;
		print "$cnt linzids remapped\n";
	} else {
		print "$filfn not found. Skipped\n";
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

die "No filename specified" if (!defined $ARGV[0]);
$filfn = $ARGV[0];
($basefile, $basedir, $basesuff) = fileparse($filfn,qr/\.[^.]*/);

$bakfn = $filfn;
$bakfn =~ s!\.(?=[^.]*$)!\.old_ids\.!;
print "Renaming map file as $bakfn\n";
rename ($filfn, $bakfn) or die "Failed to rename $filfn as $bakfn\n";
open INF, $bakfn or die "Cannot find map $bakfn\n";
open MAPPEDF,">",$filfn or die "Cannot create new map file $filfn\n";
while (<INF>){
	if (/linzid\d?=(\d+)/){
		$oldid = $1;
		if (defined($idmap{$oldid})) {
			s/$oldid/$idmap{$oldid}/;
			$cnt++;
		} else {
			if ($dienomatch){
				print "ERROR! linzid map for $1 not found! File $bakfn line $.\n";
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

$filfn = "${pdn}${basefile}.txt";
$mode = "Paper road";
do_paper_file;

$filfn = "${pdn}${basefile}PaperNumbers.txt";
$mode = "Paper Numbers";
do_paper_file;

$filfn = "${pdn}${basefile}-LINZWrongSide.txt";
$mode = "LINZ Wrongside";
do_paper_file;

$filfn = "${pdn}${basefile}-WrongSide.txt";
$mode = "Wrongside";
do_paper_file;
