use strict;
use File::Basename;

my $fn = shift || $ENV{nzogps_dl_fn} || "lds-new-zealand-4layers-CSV.zip";
die "$fn not found\n" if not -f $fn;
my @stats = stat $fn;
my @lt = localtime $stats[9];
my $datebit = sprintf "-%04d-%02d-%02d",$lt[5]+1900,$lt[4]+1,$lt[3];
my $nfn = basename($fn);

$nfn =~ s/\.zip/$datebit\.zip/;
print "command is: ren $fn $nfn\n";
exec "ren $fn $nfn";
