my $fn = shift || "lds-new-zealand-2layers-SHP.zip";
die "$fn not found\n" if not -f $fn;
my @stats = stat $fn;
my @lt = localtime $stats[9];
my $datebit = sprintf "-%04d-%02d-%02d",$lt[5]+1900,$lt[4],$lt[3];
my $nfn = $fn;

$nfn =~ s/\.zip/$datebit\.zip/;

exec "ren $fn $nfn\n";
