use strict;
use warnings;
use open IO => ":crlf";
use Cwd;
use Data::Dumper;
use Win32::OLE;

my $tile = $ARGV[0];
my %lids;
my %lnids;
my $filename;
my $line;
my $lid;
my $lrsid;
my $lreg;
my $lloc;
my $lnid;
my $type;
my $label;
my $data0;

sub assign_colours_to_lnids(){
	my %roadnames;

	for (keys %lnids){
		my $aref = ${$lnids{$_}};
		my $rdname = $aref->[0];
		if ( defined $roadnames{$rdname}) {
			$roadnames{$rdname}++;
			$roadnames{$rdname}++ if $roadnames{$rdname} == 2; #avoid 2 which is 'ordinary'.
			$roadnames{$rdname} = 0 if $roadnames{$rdname} >= 7;	#wrap around if 7 which is 'no linzid' or greater.
			$aref->[1]=$roadnames{$rdname};
		} else {
			$roadnames{$rdname} = $aref->[1]
		}
	}
}

sub process_road(){
	my $endlevel = 1;
	my $route = "2,0,0,0,0,0,0,0,0,0,0,0";
	
	if ($lids{$lid}){
		if (not $label =~ /STATE HIGHWAY/){
			$endlevel = 1;
			$route = "7,0,0,0,0,0,0,0,0,0,0,0";
		}
	}

	if (defined $lnid && $lnids{$lnid}){
		$endlevel = 1;
		$route =  ${$lnids{$lnid}}->[1] . ",0,0,0,0,0,0,0,0,0,0,0";
	}

	if ($label eq "ACCESSWAY"){
		$type = "0x16";
		$label = "WALKWAY";
		$route = "0,0,0,0,1,1,1,1,1,0,0,1";
	}
	
	if ($label eq "SERVICE LANE"){
		$type = "0x07";
		$route = "1,0,0,0,0,0,0,1,0,0,0,0";
	}
			
	print OUT "\n";
	print OUT ";linzid=$lid\n";
	if ( defined $lnid ){
		print OUT ";linznumbid=$lnid\n";
	}
	print OUT ";linz_road_sub_id=$lrsid\n";
	print OUT ";linz_region=$lreg\n";
	print OUT ";linz_locality=$lloc\n";
	
	print OUT "[POLYLINE]\n";
	print OUT "Type=$type\n";
	print OUT "Label=$label\n";
	print OUT "EndLevel=$endlevel\n";
	print OUT "Data0=$data0\n";
	print OUT "RouteParam=$route\n";
	print OUT "[END]\n";
}

die "usage: $0 tilename\n" if $tile eq ""; 

$filename = "outputs/$tile-report-2.txt";
open (REPORT, $filename) or die "$filename not found\n";

HEADER: while (<REPORT>) {
	last HEADER if /[\d]+ LINZ ids are missing/;
}
GETLIDS: while (<REPORT>) {
	last GETLIDS if /#{29}/; #29 #'s?
	if (/^;linzid=(\d+)\t\D+/){
		$lids{$1}=1;
	}
}
INTERIM: while (<REPORT>) {
	last INTERIM if /[\d]+ Number range ids are missing/;
}
GETLNMIDS: while (<REPORT>) {
	last GETLNMIDS if /#{29}/; #29 #'s?
	if (/^;linznumbid=(\d+)\t(\D.*)\t/){
		$lnids{$1}=\[$2,0];
	}
}
close REPORT;

assign_colours_to_lnids();

$filename = "../LinzDataService/outputslinz/$tile-LINZ.mp";
open (MP, $filename) or die "$filename not found\n";

$filename = "../LinzDataService/outputslinz/$tile-LINZ-V2.mp";
open (OUT, ">", $filename) or die "$filename not found\n";

HEADER: while (<MP>) {
	print OUT $_;
	last HEADER if /\[END-Regions\]/;
}

LINE: while (<MP>) {
	chomp;
	next LINE if $_ eq "";
	$line = $_;
	if ($line =~ /;linzid=(\d+)/) {$lid = $1} else {die "linzid not found line $. - $line\n"};
	$line = <MP>;
	if ($line =~ /;linznumbid=(\d+)/) { #skip the polyline;
		$lnid = $1;
		$line = <MP>;
	} else { undef $lnid }
	if ($line =~ /;linz_road_sub_id=(\d+)/) {$lrsid = $1} else {die "linz_road_sub_id not found line $. - $line\n"};
	$line = <MP>;
	if ($line =~ /;linz_region=(.*)/) {$lreg = $1} else {die "linz_region not found line $. - $line\n"};
	$line = <MP>;
	if ($line =~ /;linz_locality=(.*)/) {$lloc = $1} else {die "linz_locality not found line $. - $line\n"};
	$line = <MP>;
	$line = <MP>; #skip over polyline
	if ($line =~ /Type=(.+)/) {$type = $1} else {die "type not found line $. - $line\n"};
	$line = <MP>;
	if ($line =~ /Label=(.+)/) {$label = $1} else {die "label not found line $. - $line\n"};
	$line = <MP>; #skip the endlevel;
	$line = <MP>;
	if ($line =~ /Data0=(.+)/) {$data0 = $1} else {die "data0 not found line $. - $line\n"};
	$line = <MP>; #skip routeparam
	$line = <MP>; #skip end
	process_road();
}
close OUT;

my $cwd = cwd();
$filename = Cwd::abs_path("$cwd/../LinzDataService/outputslinz/$tile-LINZ-V2.mp");
my $gme = Win32::OLE->new('GPSMapEdit.Application.1');
die "GPSMapEdit not available/installed" if not defined $gme;
sleep 1; # funky crap happens if you don't wait.
my $gv = $gme->version;
die "Obsolete GPSMapedit version $gv" if $gv lt '1.1.60.0';
$gme->Open($filename,0);
$gme->Edit->GenerateRoutingNodes();
$gme->Edit->GeneralizeNodesOfPolylinesAndPolygons();
$filename =~ s/LINZ-V2/LINZ-V3/;
$filename =~ s|/|\\|g;
$gme->SaveAs($filename,'polish');
$gme->Close();
$gme->Close(); #funky crap also seems to happen if you don't close twice. Not sure about this, but safer to do it anyway.



	
