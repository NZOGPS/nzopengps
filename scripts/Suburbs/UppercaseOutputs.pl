use strict;
use File::Copy;

my @ofs = glob "Outputs/*.csv"; 
my $cnt = 0;
my $arg = $ARGV[0];
my $checkit = 1;
if ( defined $arg && $arg eq '-x'){
	$checkit = 0;
}

for my $of(@ofs){
	my $of2=$of;
	if( $of2 =~ s/Outputs\/([a-z])/Outputs\/\U$1/ ){
		if ($checkit) {
			print "ren $of $of2\n";
		} else {
			move($of, $of2);
			print "renamed $of to $of2\n";
		}
		$cnt++;
	}
}

if ($cnt){
	if ($checkit){
		print "$cnt files to rename\n";
		print "Use $0 -x to actually change\n";
	} else {
		print "$cnt files renamed\n";
	}
} else {
	print "no lowercase csv files in Outputs to change\n";
}

