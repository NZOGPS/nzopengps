use strict;

need to do: 
	paper roads files
		3 x files! 
	linzid2s
	
my $mappingfilename = "..\\LinzDataService\\rna_mappings.csv";
my %idmap;
my $cnt;
my $newfn;
my $oldid;

$idmap{0}=0;

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

open MAPF, $ARGV[0] or die "Cannot find map $ARGV[0]\n";
$newfn = $ARGV[0];
$newfn =~ s!\.(?=[^.]*$)!\.remapped\.!;
print "Creating new file $newfn\n";
open MAPPEDF,">",$newfn or die "Cannot create new map file $newfn\n";
while (<MAPF>){
	if (/linzid=(\d+)/){
		$oldid = $1;
		if (defined($idmap{$oldid})) {
			s/$oldid/$idmap{$oldid}/;
			$cnt++;
		} else {
			print "ERROR! linzid map for $1 not found! File $ARGV[0] line $.\n";
			s/$oldid/###$oldid### - no new mapping for linzid found/;			
		}  
	}
	print MAPPEDF $_;
}
print "$cnt linzids remapped\n";
