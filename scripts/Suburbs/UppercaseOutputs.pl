use strict;
my @fs = glob "Outputs/*.csv"; 
my $cnt = 0;
for my $f(@fs){
	my $f2=$f;
	if( $f2 =~ s/Outputs\/([a-z])/Outputs\/\U$1/ ){
		print "ren $f $f2\n";
		$cnt++;
	}
}
if ($cnt){print $cnt}else{print "none"}
print " changed\n";
