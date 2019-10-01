use strict;
use warnings;
use open IO => ":crlf";
use Cwd;
use Data::Dumper;
use Win32::OLE;

my $tile = $ARGV[0];
my $filename;

die "usage: $0 tilename\n" if $tile eq ""; 

my $cwd = cwd();
$filename = Cwd::abs_path("$cwd/../LinzDataService/outputslinz/$tile-LINZ-V2.mp");
my $gme = Win32::OLE->new('GPSMapEdit.Application.1');
my $gv = $gme->version;
die "Obsolete GPSMapedit version $gv" if $gv lt '1.1.60.0';
$gme->Open($filename,0);
$gme->Edit->GenerateRoutingNodes();
$gme->Edit->GeneralizeNodesOfPolylinesAndPolygons();
$filename =~ s/LINZ-V2/LINZ-V3/;
$filename =~ s|/|\\|g;
$gme->SaveAs($filename,'polish');
$gme->Close();



	
