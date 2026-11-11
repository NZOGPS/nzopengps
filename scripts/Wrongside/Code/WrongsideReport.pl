use strict;
use File::Spec;
my $paperdir;
my %Linz;
my %Ignore;
my $basename = shift;
my $nzo;
my $filename;
my $filename2;
my $tfilename;
my $csvrepfilename;
my $tbfilename;
my $csvcnt;
my $csvleft;
my $cnt;
my $wstempdir = File::Spec->catdir(File::Spec->updir(),"TempData");
my $wsrepdir = File::Spec->catdir(File::Spec->curdir(),"Reports");

sub printcsvline {
	my $key = shift;
	my $setp = shift;
	my $coords;
	my $lat;
	my $lon;
	my $add;
	my $date;
	my @rest;
	($add,$date,$coords,@rest) = split (/\t/,$setp->{$key});
	($lat,$lon) = split(/,/,$coords);
#	print stderr "$lon,$lat,\"$add\",$key\n";
	print OUTCSV "$lon,$lat,\"$add\",$key\n";
}

die "no Filename specified!\n" if $basename eq "";
$nzo = $ENV{nzogps_base};
$nzo =~ s/\"//g;

$paperdir .= File::Spec->catdir($nzo,'','LinzDataService','PaperRoads');

$filename = File::Spec->catfile($paperdir,"$basename-WrongSide.txt");
open (INF, "<",$filename)|| print STDERR "WS $filename not found\n";
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

$filename = File::Spec->catfile($paperdir,"$basename-LINZWrongSide.txt");
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
die "$filename not found" if not -f $filename;
rename $filename, $filename2 or die "Error renaming file $filename to $filename2 : $!";
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

$tfilename = "$wstempdir\\$filename2";
$tbfilename = "$tfilename.bak";
if (-f $tbfilename){
	unlink $tbfilename or warn "Could not delete $tbfilename: $!";
	print STDERR "deleted $tbfilename\n";
}
if (-f tfilename ){
	rename($tfilename,$tbfilename) or warn "Error renaming file: $!";
	print STDERR "renamed $tfilename $tbfilename\n";
}
rename($filename2,$tfilename)or warn "Error renaming file: $!";
print STDERR "renamed: $filename2 $tfilename\n";
	
print "$csvcnt wrongside numbers, $csvleft not in Exclusion files\n";

$cnt = keys %Ignore;
if ($cnt){
	$csvrepfilename = File::Spec->join($wsrepdir,"${basename}_NolongerWrong.csv");
	open OUTCSV,">",$csvrepfilename or die "Can't create $csvrepfilename\n";
	print "$cnt entries in Ignore list are no longer on the wrong side\n";
	foreach my $key (keys %Ignore){
		print "$key\t$Ignore{$key}\n";
		printcsvline($key,\%Ignore);
	}
	print "\n";
	close OUTCSV;
}

$cnt = keys %Linz;
if ($cnt){
	$csvrepfilename = File::Spec->join($wsrepdir,"${basename}_LINZNolongerWrong.csv");
	open OUTCSV,">",$csvrepfilename or die "Can't create $csvrepfilename\n";
	print "$cnt entries in Linz list are no longer on the wrong side\n";
	foreach my $key (keys %Linz){
		print "$key\t$Linz{$key}\n";
		printcsvline($key,\%Linz);
	}
	print "\n";
	close OUTCSV;
}

