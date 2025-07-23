use strict;
use POSIX qw( strftime );
my @filenames = ("Northland","Auckland","Waikato","Central","Wellington","Tasman","Canterbury","Southland");
my $gofn = "gdb-compile-times.txt";
my $nofn = "numbering-times.txt";
my $nowts;

sub tdiff {
	my $t1 = shift;
	my $t2 = shift;
	my $hd; my $mid; my $sd;
	my $y1; my $mo1; my $d1; my $h1; my $mi1; my $s1; my $o1;
	my $y2; my $mo2; my $d2; my $h2; my $mi2; my $s2; my $o2;
	if ( $t1 =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) \+(\d{4})/){
		$y1 = $1; $mo1 = $2; $d1 = $3;
		$h1 = $4; $mi1 = $5; $s1 = $6; $o1 = $7;
	} else {
		print "date not matched: $t1\n";
	}
	if ( $t2 =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) \+(\d{4})/){
		$y2 = $1; $mo2 = $2; $d2 = $3;
		$h2 = $4; $mi2 = $5; $s2 = $6; $o2 = $7;
	} else {
		print "date not matched: $t2\n";
	}
	die "Bugger - timezone changed\n" if ($o1!=$o2 or $y1!=$y2);
	if ($s2>$s1){
		$sd = 60 + $s1 - $s2;
		$mid = -1;
	} else {
		$sd = $s1 - $s2;
	}
	if ($mi2>$mi1){
		$mid = 60 + $mid + $mi1 - $mi2;
		$hd = -1;
	} else {
		$mid = $mid + $mi1 - $mi2;
	}
	if ($h2>$h1){
		$hd = 24 + $hd + $h1 - $h2;
	} else {
		$hd = $hd + $h1 - $h2;
	}
	return sprintf("%02d:%02d:%02d",$hd,$mid,$sd);
}

sub doGPX {
	open(OFILE,">>",$gofn) or die "cannot open $gofn\n";
	for my $fn (@filenames){
	#	print "file is $fn\n";
		my $lfn = "outputs\\$fn-report-5.txt";
		my $start;
		my $endGPX;
		my $endGDB;
		my $gpxtime;
		my $gdbtime;

		open(LOGF,$lfn) or die "cannot open $lfn\n";
	#	print "opened $lfn\n";
		while (<LOGF>){
			if (/^Start = (.*)/){
				$start = $1;
			}
			if (/^Finish Database query =(.*)/){
				$endGPX = $1;
			}
			if (/^Finish convert to gdb =(.*)/){
				$endGDB = $1;
			}
		}
		close LOGF;
		if (!defined($start)){
			die "start time not found in $lfn\n";
		}
		if (!defined($endGPX)){
			die "End convert time not found in $lfn\n";
		}
		if (!defined($endGDB)){
			die "End gpx time not found in $lfn\n";
		}
		$gpxtime = tdiff($endGPX,$start);
		$gdbtime = tdiff($endGDB,$endGPX);
		
		print OFILE "$fn\t$start\t$endGPX\t$endGDB\t$gpxtime\t$gdbtime\n";
	}
	$nowts = strftime('%Y-%m-%d %H:%M:%S %z', localtime);
	print OFILE "(collated)\t$nowts\n"; 
	close OFILE;
}

sub doNumbering {
	open(OFILE,">>",$nofn) or die "cannot open $nofn\n";
	for my $fn (@filenames){
	#	print "file is $fn\n";
		my $lfn = "..\\linzdataservice\\outputslinz\\$fn-report-3b.txt";
		my $start;
		my $end;
		my $Sections; 
		my $SectionsCI;
		my $SectionsNN;
		my $SectionsNA;
		my $SectionsNAA;
		my $SectionsNA0A;
		my $time;
		
		open(LOGF,$lfn) or die "cannot open $lfn\n";
	#	print "opened $lfn\n";
		while (<LOGF>){
			if (/^Start = (.*)/){
				$start = $1;
			}
			if (/^Finish =(.*)/){
				$end = $1;
			}
			if (/^count_of_sections\t([0-9]+)/){
				$Sections = $1;
			}
			if (/^count_of_sections_city_indexed\t([0-9]+)/){
				$SectionsCI = $1;
			}
			if (/^count_of_sections_needing_numbering\t([0-9]+)/){
				$SectionsNN = $1;
			}
			if (/^count_of_sections_no_numbering_attempted\t([0-9]+)/){
				$SectionsNA = $1;
			}
			if (/^count_of_sections_numbering_attempted_and_added\t([0-9]+)/){
				$SectionsNAA = $1;
			}
			if (/^count_of_sections_numbering_attempted_but_zero_added\t([0-9]+)/){
				$SectionsNA0A = $1;
			}

		}
		close LOGF;
		if (!defined($start)){
			die "start time not found in $lfn\n";
		}
		if (!defined($end)){
			die "End time not found in $lfn\n";
		}
		if (!defined($Sections)){
			die "Sections count not found in $lfn\n";
		}
		$time = tdiff($end,$start);
		
		print OFILE "$fn\t$start\t$end\t$time\t$Sections\t$SectionsCI\t$SectionsNN\t$SectionsNA\t$SectionsNAA\t$SectionsNA0A\n";
	}
	$nowts = strftime('%Y-%m-%d %H:%M:%S %Z', localtime);
	print OFILE "(collated)\t$nowts\n"; 
	close OFILE;
}

if (! -f $gofn ){
	open(OFILE,">>",$gofn) or die "cannot create $gofn\n";
	print OFILE "File\tStart\tEnd gpx\tEnd gdb\tGPX time\tGDB time\n";
	close OFILE;
}
if (! -f $nofn ){
	open(OFILE,">>",$nofn) or die "cannot create $nofn\n";
	print OFILE "File\tStart\tEnd\tTime\tSections\tSections CI\tSections NN\tSections NA\tSections NAA\tSections NA0A\n";
	close OFILE;
}

doGPX();
doNumbering();


