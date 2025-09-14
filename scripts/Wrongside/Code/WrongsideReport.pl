use strict;
my $paperdir;
my %Linz;
my %Ignore;
my $basename = shift;
my $filename;
my $filename2;
my $csvcnt;
my $csvleft;
my $cnt;

die "no Filename specified!\n" if $basename eq "";
$paperdir = $ENV{nzogps_base};
$paperdir =~ s/\"//g;
$paperdir .= '\\LinzDataService\\PaperRoads';

$filename = "$paperdir\\$basename-WrongSide.txt";
open (INF, "<",$filename)|| print STDERR "$filename not found\n";
while (<INF>){
	if (/(\d+)\t(.*)/){
		if ($Ignore{$1}){
			print "Warning: duplicate entries for $1 on line $. in $filename\n";
		} else {
			$Ignore{$1}=$2;
		}
	}
}
close INF;

$cnt = keys %Ignore;
if ($cnt){
	print "$cnt entries in $filename\n";
}

$filename = "$paperdir\\$basename-LINZWrongSide.txt";
open INF,$filename;
while (<INF>){
	if (/(\d+)\t(.*)/){
		if ($Ignore{$1}){
			print "Warning: $1 on line $. in $filename - This ID is also set in the ignore file\n";
		}
		if ($Linz{$1}){
			print "Warning: duplicate entries for $1 on line $. in $filename\n";
		} else {
			$Linz{$1}=$2;
		}
	}
}
close INF;

$cnt = keys %Linz;
if ($cnt){
	print "$cnt entries in $filename\n";
}

$filename = "$basename-WrongSide.csv";
$filename2 = $filename;
$filename2 =~ s/\.csv/-all.csv/;
rename $filename, $filename2;
open INF,$filename2;
open OUTF,">",$filename or die "Can't create $filename\n";
while (<INF>){
	if (/,Wrong Side: (\d+)/){
		my $id;
		$csvcnt++;
		$id = $1;
		if (defined $Ignore{$id}){
			delete $Ignore{$id};
			next;
		}
		if (defined $Linz{$id}){
			delete $Linz{$id};
			next;
		}
		print OUTF;
		$csvleft++;
	}
}
close INF;
close OUTF;
print "$csvcnt wrongside numbers, $csvleft not in Exclusion files\n";
$cnt = keys %Ignore;
if ($cnt){
	print "$cnt entries in Ignore list are no longer on the wrong side\n";
	foreach my $key (keys %Ignore){
		print "$key\t$Ignore{$key}\n";
	}
	print "\n";
}

$cnt = keys %Linz;
if ($cnt){
	print "$cnt entries in Linz list are no longer on the wrong side\n";
	foreach my $key (keys %Linz){
		print "$key\t$Linz{$key}\n";
	}
	print "\n";
}

