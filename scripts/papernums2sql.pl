use strict;
use File::Basename;
use Cwd;

my $basefile;
my $basedir;
my $basesuff;
my $nzogps = "nzopengps";

my @vals;
my $linzid;
my @nums;
my $cmt;

my $first = 1;

die "No filename specified" if ($ARGV[0] eq "");
($basefile, $basedir, $basesuff) = fileparse($ARGV[0],qr/\.[^.]*/);
$basedir = Cwd::realpath($basedir);
if ($basedir =~ m|/$nzogps(.*)$|) {
	if ($1 ne ""){
		$basedir =~ s/$1//;
	}
	$basedir .= '/';
} else {
	print STDERR "$nzogps not found in path. Unlikely to find numbering files...\n";
}

open(SQLFILE, '>', "${basefile}.sql") or die "can't create sql file\n";
print SQLFILE "DROP TABLE \"${basefile}\";\n";
print SQLFILE "CREATE TABLE \"${basefile}\" (gid serial,\n";
print SQLFILE "\"linzid\" integer,\n";
print SQLFILE "\"type\" varchar(4),\n";
print SQLFILE "\"start\" integer,\n";
print SQLFILE "\"end\" integer,\n";
print SQLFILE "\"comment\" varchar(200));\n";
print SQLFILE "INSERT INTO \"${basefile}\" ";
print SQLFILE "(\"linzid\",\"type\",\"start\",\"end\",\"comment\")";
print SQLFILE " VALUES \n ";

while (<>){
	 chomp;
	@vals = split /\t/;
	$linzid = shift @vals;
	die 'invalid linzid $linzid\n' if not $linzid =~ /\d+/;
	while ( $vals[0] =~ /[OEB],\d+,\d+/){
		my $this = shift @vals;
		push @nums,$this;
	}
	die 'No numbers specified for linzid $linzid\n' if not @nums;
	$cmt = join ', ',@vals;
	$cmt =~ s/'//g;
	$cmt =~s/°/ /g;
	while (@nums) {
		my $num = shift @nums;
		my ($type,$start,$end)=split /,/,$num;
		if ($first) {
			$first = 0;
			print SQLFILE " ";
		} else {
			print SQLFILE ",";
		}
		print SQLFILE "($linzid,'$type',$start,$end,'$cmt')\n";
	}	
}
print SQLFILE ";\n";
