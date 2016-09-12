#!C:/Perl/bin/perl -w
use strict;

use Win32::OLE qw(in with);
use Win32::OLE::Const 'Microsoft Excel';
use IO::File;
use utf8;
use Cwd;


my $image_id=1;

#Run Win32
$Win32::OLE::Warn = 3; # Die on Errors.
# ::Warn = 2; throws the errors, but #
# expects that the programmer deals  #

#First, we need an excel object to work with, so if there isn't an open one, we create a new one, and we define how the object is going to exit

my $excelfile = shift @ARGV;
my $dir= getcwd;
	$dir=~s/\//\\/g;
	$excelfile=$dir."\\".$excelfile;

my $Excel = Win32::OLE->GetActiveObject('Excel.Application')
        || Win32::OLE->new('Excel.Application', 'Quit');

#For the sake of this program, we'll turn off all those pesky alert boxes, such as the SaveAs response "This file already exists", etc. using the DisplayAlerts property.

$Excel->{DisplayAlerts}=0;   

#opened an existing file to work with 
                                              
my $Book = $Excel->Workbooks->Open($excelfile);   

#Create a reference to a worksheet object and activate the sheet to give it focus so that actions taken on the workbook or application objects occur on this sheet unless otherwise specified.

my $Sheet = $Book->Worksheets("Sheet1");
$Sheet->Activate();  

print "Hi! \n";

main();

#########
sub main {
#########

#Find used range

	my $last_row = $Sheet -> UsedRange -> Find({What => "*", SearchDirection => xlPrevious, SearchOrder => xlByRows})    -> {Row};
	print "last row is $last_row\n";

	my $last_col = $Sheet -> UsedRange -> Find({What => "*", SearchDirection => xlPrevious, SearchOrder => xlByColumns}) -> {Column};
	print "last column is $last_col\n";

#Skip header row, and find row range for each "Hanvey item" in finding aid
	my $item_number;
	my $item_start_row=2;
	my $item_end_row=3;

	for my $row_count (2..$last_row){
		if ($item_end_row > $last_row || $Sheet->Range("I" . $item_start_row)->{Value} ne $Sheet->Range("I" . $item_end_row)->{Value}) {
			$item_end_row--;
			$item_number = $Sheet->Range("I" . $item_start_row)->{Value};
			#print "\n\nstart is $item_start_row to $item_end_row; item $item_number and row_count is $row_count\n";
			print "got em all\n";
			metadata($item_start_row, $item_end_row);
			$row_count++;
			$item_start_row=$row_count;
		}
		else {
			$row_count=$item_end_row;
		}
	$item_end_row=$row_count+1;

	}

};

#######
sub metadata {
#######
	my $item_start_row=shift;
	my $item_end_row=shift;
	$item_start_row=~ s/\[\]//;
	$item_end_row=~ s/\[\]//;


#Open the output file; print xml declaration and root node
#

	my $item_code = $Sheet->Range("I" . $item_start_row)->{Value};
	$item_code =~/(^\d*)/;
	$item_code=sprintf("%03d",$1);
	(my $suffix = $') =~ s/\s//g;

	
	print "item code is $item_code\n";

	my $obj_id=sprintf("%02d", $Sheet->Range("H" . $item_start_row)->{Value}) . $Sheet->Range("Q" . $item_start_row)->{Value} . $item_code . $suffix;
	
	my $outputfile =  $obj_id . '.xml';
	print "out put file name $outputfile\n";
	my $fh = IO::File->new($outputfile, 'w')
		or die "unable to open output file for writing: $!";

	binmode($fh, ':utf8');
	
# Call mets opening subroutine	
	metsOpening($item_start_row, $fh, $obj_id);

# Call mods subroutine
	
	mods($fh, $obj_id, $item_start_row, $item_end_row);

#Generate file group section
	$fh->print("\t<mets:fileSec ID=\"FSD1\">\n");

#Call file group subroutine
	my @type= ( 'tiff', 'jp2', 'jpeg');
	foreach (@type) {
		#my $type=$_;
		fileGroup($fh, $_, $item_start_row, $item_end_row);
	};
	$fh->print("\t<\/mets:fileSec>\n");

####generate structMap
	my $label=$Sheet->Range("J" . $item_start_row)->{Value};
	$label =~ s/"/&#x22;/g;
	$fh->print("\t<mets:structMap TYPE=\"physical\" ID=\"SMD1\">\n");
	$fh->print("\t\t<mets:div TYPE=\"images\" LABEL=\"".$label."\" ORDER=\"1\">\n");
		structMap($fh, $item_start_row, $item_end_row);
	$fh->print("\t\t</mets:div>\n");
	$fh->print("\t</mets:structMap>\n");
	

#Call mets closing subroutine
	metsClosing($fh);

};


#########
sub mods {
########
	my $fh = shift;
	my $obj_id=shift;
	my $item_start_row=shift;
	my $item_end_row=shift;

	my %subj_topical=(
		authors => '<mods:subject authority="lcsh"><mods:occupation>Authors, Irish</mods:occupation><mods:temporal>20th century</mods:temporal><mods:genre>Portraits</mods:genre></mods:subject><mods:subject authority="lcsh"><mods:occupation>Authors, Irish</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		poets  =>   '<mods:subject authority="lcsh"><mods:occupation>Poets, Irish</mods:occupation><mods:temporal>20th century</mods:temporal><mods:genre>Portraits</mods:genre></mods:subject><mods:subject authority="lcsh"><mods:occupation>Poets, Irish</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		journalists => '<mods:subject authority="lcsh"><mods:occupation>Journalists</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		artists =>   '<mods:subject authority="lcsh"><mods:occupation>Artists</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		actors =>   '<mods:subject authority="lcsh"><mods:occupation>Actors</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		broadcasters =>   '<mods:subject authority="lcsh"><mods:occupation>Broadcasters</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		critics =>   '<mods:subject authority="lcsh"><mods:occupation>Critics</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		dramatists =>   '<mods:subject authority="lcsh"><mods:occupation>Dramatists</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		journalists =>   '<mods:subject authority="lcsh"><mods:occupation>Journalists</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		musicians =>   '<mods:subject authority="lcsh"><mods:occupation>Musicians</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		newspapereditors =>   '<mods:subject authority="lcsh"><mods:occupation>Newspaper editors</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		periodicaleditors =>   '<mods:subject authority="lcsh"><mods:occupation>Periodical editors</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		producersanddirectors =>   '<mods:subject authority="lcsh"><mods:occupation>Producers and directors</mods:occupation><mods:geographic>Northern Ireland</mods:geographic><mods:genre>Portraits</mods:genre></mods:subject>',
		bombings =>  '<mods:subject authority=\"lcsh\"><mods:topic>Bombings<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>',
		fs =>  '<mods:subject authority="lcsh"><mods:topic>Folk singers</mods:topic><mods:genre>Portraits</mods:genre></mods:subject>',
		fm =>  '<mods:subject authority="lcsh"><mods:topic>Folk musicians</mods:topic><mods:genre>Portraits</mods:genre></mods:subject>',
		clancybrothers => '<mods:subject authority="lcsh"><mods:name type="corporate" authority="naf"><mods:namePart>Clancy Brothers</mods:namePart><mods:displayForm>Clancy Brothers</mods:displayForm></mods:name><mods:genre>Photographs</mods:genre></mods:subject>',
		boysofthelough => '<mods:subject authority="lcsh"><mods:name type="corporate" authority="naf"><mods:namePart>Boys of the Lough</mods:namePart><mods:displayForm>Boys of the Lough</mods:displayForm></mods:name><mods:genre>Photographs</mods:genre></mods:subject>',
		downtownradio => '<mods:subject authority="lcsh"><mods:name type="corporate"><mods:namePart>Downtown Radio</mods:namePart><mods:displayForm>Downtwon Radio</mods:displayForm></mods:name><mods:genre>Photographs</mods:genre></mods:subject>',
		sandsfamily => '<mods:subject authority="lcsh"><mods:name type="corporate"><mods:namePart>Sands Family (Musical group)</mods:namePart><mods:displayForm>Sands Family (Musical group)</mods:displayForm></mods:name><mods:genre>Photographs</mods:genre></mods:subject>',
		chieftains => '<mods:subject authority="lcsh"><mods:name type="corporate"><mods:namePart>Chieftains</mods:namePart><mods:displayForm>Chieftains</mods:displayForm></mods:name><mods:genre>Photographs</mods:genre></mods:subject>',

		);
		
			
	my %subj_names=(
		duffy=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Duffy</mods:namePart><mods:namePart type="given">Rita</mods:namePart><mods:displayForm>Duffy, Rita</mods:displayForm></mods:name>',
		mcauley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McAuley</mods:namePart><mods:namePart type="given">Tony</mods:namePart><mods:displayForm>McAuley, Tony</mods:displayForm></mods:name>',
		mcgahern=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McGahern</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="date">1934-2006</mods:namePart><mods:displayForm>McGahern, John, 1934-2006</mods:displayForm></mods:name>',
		stewart=>	'<mods:name type="personal"><mods:namePart type="family">Stewart</mods:namePart><mods:namePart type="given">John D.</mods:namePart><mods:displayForm>Stewart, John D.</mods:displayForm></mods:name>',
		goldblatt=>	'<mods:name type="personal"><mods:namePart type="family">Goldblatt</mods:namePart><mods:namePart type="given">Harold</mods:namePart><mods:displayForm>Goldblatt, Harold</mods:displayForm></mods:name>',
		mccoubrey=>	'<mods:name type="personal"><mods:namePart type="family">McCoubrey</mods:namePart><mods:namePart type="given">Larry</mods:namePart><mods:displayForm>McCoubrey, Larry</mods:displayForm></mods:name>',
		mulhall=>	'<mods:name type="personal"><mods:namePart type="family">Mulhall</mods:namePart><mods:namePart type="given">Willie</mods:namePart><mods:displayForm>Mulhall, Willie</mods:displayForm></mods:name>',
		bell=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Bell</mods:namePart><mods:namePart type="given">Sam Hanna</mods:namePart><mods:displayForm>Bell, Sam Hanna</mods:displayForm></mods:name>',
		campbell=>	'<mods:name type="personal"><mods:namePart type="family">Campbell</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Campbell, Jim</mods:displayForm></mods:name>',
		deane=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Deane</mods:namePart><mods:namePart type="given">Seamus</mods:namePart><mods:namePart type="date">1940-</mods:namePart><mods:displayForm>Deane, Seamus, 1940-</mods:displayForm></mods:name>',
		clarke=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Clarke</mods:namePart><mods:namePart type="given">Liam</mods:namePart><mods:displayForm>Clarke, Liam</mods:displayForm></mods:name>',
		kelly=>	'<mods:name type="personal"><mods:namePart type="family">Kelly</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:displayForm>Kelly, James</mods:displayForm></mods:name>',
		mcaughtry=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McAughtry</mods:namePart><mods:namePart type="given">Sam</mods:namePart><mods:displayForm>McAughtry, Sam</mods:displayForm></mods:name>',
		andersond=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Anderson</mods:namePart><mods:namePart type="given">Don</mods:namePart><mods:namePart type="date">1942-</mods:namePart><mods:displayForm>Anderson, Don, 1942-</mods:displayForm></mods:name>',
		odoherty=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Doherty</mods:namePart><mods:namePart type="given">Malachi</mods:namePart><mods:namePart type="date">1951-</mods:namePart><mods:displayForm>O\'Doherty, Malachi, 1951-</mods:displayForm></mods:name>',
		shawcross=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Shawcross</mods:namePart><mods:namePart type="given">Neil</mods:namePart><mods:displayForm>Shawcross, Neil</mods:displayForm></mods:name>',
		turner=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Turner</mods:namePart><mods:namePart type="given">Colin</mods:namePart><mods:namePart type="date">1936-</mods:namePart><mods:displayForm>Turner, Colin, 1936-</mods:displayForm></mods:name>',
		edwards=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Edwards</mods:namePart><mods:namePart type="given">Ruth Dudley</mods:namePart><mods:displayForm>Edwards, Ruth Dudley</mods:displayForm></mods:name>',
		hammond=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hammond</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:namePart type="date">1928-2008</mods:namePart><mods:displayForm>Hammond, David, 1928-2008</mods:displayForm></mods:name>',
		leitch=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Leitch</mods:namePart><mods:namePart type="given">Maurice</mods:namePart><mods:displayForm>Leitch, Maurice</mods:displayForm></mods:name>',
		osearcaigh=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">� Searcaigh</mods:namePart><mods:namePart type="given">Cathal</mods:namePart><mods:displayForm>� Searcaigh, Cathal</mods:displayForm></mods:name>',
		andersong=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Anderson</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>Anderson, Gerry</mods:displayForm></mods:name>',
		lynch=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Lynch</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:displayForm>Lynch, Martin</mods:displayForm></mods:name>',
		longley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Longley</mods:namePart><mods:namePart type="given">Michael</mods:namePart><mods:namePart type="date">1939-</mods:namePart><mods:displayForm>Longley, Michael, 1939-</mods:displayForm></mods:name>',
		amanpour=>	'<mods:name type="personal"><mods:namePart type="family">Amanpour</mods:namePart><mods:namePart type="given">Christiane</mods:namePart><mods:displayForm>Amanpour, Christiane</mods:displayForm></mods:name>',
		obrien=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Brien</mods:namePart><mods:namePart type="given">Edna</mods:namePart><mods:displayForm>O\'Brien, Edna</mods:displayForm></mods:name>',
		hill=>	'<mods:name type="personal"><mods:namePart type="family">Hill</mods:namePart><mods:namePart type="given">Ian</mods:namePart><mods:displayForm>Hill, Ian</mods:displayForm></mods:name>',
		johnston=>	'<mods:name type="personal"><mods:namePart type="family">Johnston</mods:namePart><mods:namePart type="given">Neil</mods:namePart><mods:displayForm>Johnston, Neil</mods:displayForm></mods:name>',
		curran=>	'<mods:name type="personal"><mods:namePart type="family">Curran</mods:namePart><mods:namePart type="given">Ed</mods:namePart><mods:displayForm>Curran, Ed</mods:displayForm></mods:name>',
		ofarrel=>	'<mods:name type="personal"><mods:namePart type="family">OFarrell</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>OFarrell, John</mods:displayForm></mods:name>',
		collins=>	'<mods:name type="personal"><mods:namePart type="family">Collins</mods:namePart><mods:namePart type="given">Tom</mods:namePart><mods:displayForm>Collins, Tom</mods:displayForm></mods:name>',
		gorman=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Gorman</mods:namePart><mods:namePart type="given">Damian</mods:namePart><mods:displayForm>Gorman, Damian</mods:displayForm></mods:name>',
		grimes=>	'<mods:name type="personal"><mods:namePart type="family">Grimes</mods:namePart><mods:namePart type="given">Claire</mods:namePart><mods:displayForm>Grimes, Claire</mods:displayForm></mods:name>',
		mccafferty=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McCafferty</mods:namePart><mods:namePart type="given">Nell</mods:namePart><mods:displayForm>McCafferty, Nell</mods:displayForm></mods:name>',
		breen=>	'<mods:name type="personal"><mods:namePart type="family">Breen</mods:namePart><mods:namePart type="given">Suzanne</mods:namePart><mods:displayForm>Breen, Suzanne</mods:displayForm></mods:name>',
		macmathuna=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Mac Mathu´na</mods:namePart><mods:namePart type="given">Ciar&#xe1;n</mods:namePart><mods:displayForm>Mac Mathu´na, Ciar&#xe1;n</mods:displayForm></mods:name>',
		mahon=>	'<mods:name type="personal"><mods:namePart type="family">Mahon</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>Mahon, Joe</mods:displayForm></mods:name>',
		mcdevitt=>	'<mods:name type="personal"><mods:namePart type="family">McDevitt</mods:namePart><mods:namePart type="given">Tom</mods:namePart><mods:displayForm>McDevitt, Tom</mods:displayForm></mods:name>',
		malley=>	'<mods:name type="personal"><mods:namePart type="family">Malley</mods:namePart><mods:namePart type="given">Eamon</mods:namePart><mods:displayForm>Malley, Eamon</mods:displayForm></mods:name>',
		hawthorne=>	'<mods:name type="personal"><mods:namePart type="family">Hawthorne</mods:namePart><mods:namePart type="given">D. J.</mods:namePart><mods:displayForm>Hawthorne, D. J.</mods:displayForm></mods:name>',
		fitzgerald=>	'<mods:name type="personal"><mods:namePart type="family">Fitzgerald</mods:namePart><mods:namePart type="given">Charlie</mods:namePart><mods:displayForm>Fitzgerald, Charlie</mods:displayForm></mods:name>',
		piper=>	'<mods:name type="personal"><mods:namePart type="family">Piper</mods:namePart><mods:namePart type="given">Raymond</mods:namePart><mods:displayForm>Piper, Raymond</mods:displayForm></mods:name>',
		flanagan=>	'<mods:name type="personal"><mods:namePart type="family">Flanagan</mods:namePart><mods:namePart type="given">Terence</mods:namePart><mods:displayForm>Flanagan, Terence</mods:displayForm></mods:name>',
		doran=>	'<mods:name type="personal"><mods:namePart type="family">Doran</mods:namePart><mods:namePart type="given">Noel</mods:namePart><mods:displayForm>Doran, Noel</mods:displayForm></mods:name>',
		black=>	'<mods:name type="personal"><mods:namePart type="family">Black</mods:namePart><mods:namePart type="given">Brian</mods:namePart><mods:displayForm>Black, Brian</mods:displayForm></mods:name>',
		dunseath=>	'<mods:name type="personal"><mods:namePart type="family">Dunseath</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>Dunseath, David</mods:displayForm></mods:name>',
		toibin=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Toibin</mods:namePart><mods:namePart type="given">Niall</mods:namePart><mods:namePart type="date">1929-</mods:namePart><mods:displayForm>Toibin, Niall, 1929-</mods:displayForm></mods:name>',
		fitzpatrick=>	'<mods:name type="personal"><mods:namePart type="family">Fitzpatrick</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Fitzpatrick, Jim</mods:displayForm></mods:name>',
		manley=>	'<mods:name type="personal"><mods:namePart type="family">Manley</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Manley, Jim</mods:displayForm></mods:name>',
		pedlow=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Pedlow</mods:namePart><mods:namePart type="given">J. C.</mods:namePart><mods:displayForm>Pedlow, J. C.</mods:displayForm></mods:name>',
		mallie=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Mallie</mods:namePart><mods:namePart type="given">Eamonn</mods:namePart><mods:namePart type="date">1950-</mods:namePart><mods:displayForm>Mallie, Eamonn, 1950-</mods:displayForm></mods:name>',
		heaney=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Heaney</mods:namePart><mods:namePart type="given">Seamus</mods:namePart><mods:namePart type="date">1939-</mods:namePart><mods:displayForm>Heaney, Seamus, 1939-</mods:displayForm></mods:name>',
		montague=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Montague</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Montague, John</mods:displayForm></mods:name>',
		mcguckian=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McGuckian</mods:namePart><mods:namePart type="given">Medbh</mods:namePart><mods:namePart type="date">1950-</mods:namePart><mods:displayForm>McGuckian, Medbh, 1950-</mods:displayForm></mods:name>',
		simmons=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Simmons</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:namePart type="date">1933-</mods:namePart><mods:displayForm>Simmons, James, 1933-</mods:displayForm></mods:name>',
		colmer=>	'<mods:name type="personal"><mods:namePart type="family">Colmer</mods:namePart><mods:namePart type="given">Albert</mods:namePart><mods:displayForm>Colmer, Albert</mods:displayForm></mods:name>',
		pattonj=>	'<mods:name type="personal"><mods:namePart type="family">Patton</mods:namePart><mods:namePart type="given">Joel</mods:namePart><mods:displayForm>Patton, Joel</mods:displayForm></mods:name>',
		darcy=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">D\'Arcy</mods:namePart><mods:namePart type="given">Brian</mods:namePart><mods:namePart type="given">C.P.</mods:namePart><mods:displayForm>D\'Arcy, Brian (C.P.)</mods:displayForm></mods:name>',
		tutu=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Tutu</mods:namePart><mods:namePart type="given">Desmond</mods:namePart><mods:displayForm>Tutu, Desmond</mods:displayForm></mods:name>',
		hayes=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hayes</mods:namePart><mods:namePart type="given">Maurice</mods:namePart><mods:displayForm>Hayes, Maurice</mods:displayForm></mods:name>',
		skelly=>	'<mods:name type="personal"><mods:namePart type="family">Skelly</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Skelly, Jim</mods:displayForm></mods:name>',
		mckeown=>	'<mods:name type="personal"><mods:namePart type="family">McKeown</mods:namePart><mods:namePart type="given">Paul</mods:namePart><mods:displayForm>McKeown, Paul</mods:displayForm></mods:name>',
		blackj=>	'<mods:name type="personal"><mods:namePart type="family">Black</mods:namePart><mods:namePart type="given">Julian</mods:namePart><mods:displayForm>Black, Julian</mods:displayForm></mods:name>',
		mageeb=>	'<mods:name type="personal"><mods:namePart type="family">Magee</mods:namePart><mods:namePart type="given">Bernard</mods:namePart><mods:displayForm>Magee, Bernard</mods:displayForm></mods:name>',
		maguire=>	'<mods:name type="personal"><mods:namePart type="family">Maguire</mods:namePart><mods:namePart type="given">Joseph</mods:namePart><mods:displayForm>Maguire, Joseph</mods:displayForm></mods:name>',
		patton=>	'<mods:name type="personal"><mods:namePart type="family">Patton</mods:namePart><mods:namePart type="given">George</mods:namePart><mods:displayForm>Patton, George</mods:displayForm></mods:name>',
		jones=>	'<mods:name type="personal"><mods:namePart type="family">Jones</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>Jones, David</mods:displayForm></mods:name>',
		callaghan=>	'<mods:name type="personal"><mods:namePart type="family">Callaghan</mods:namePart><mods:namePart type="given">Sydney</mods:namePart><mods:displayForm>Callaghan, Sydney</mods:displayForm></mods:name>',
		eames=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Eames</mods:namePart><mods:namePart type="given">Robin</mods:namePart><mods:namePart type="date">1937-</mods:namePart><mods:displayForm>Eames, Robin, 1937-</mods:displayForm></mods:name>',
		mageer=>	'<mods:name type="personal"><mods:namePart type="family">Magee</mods:namePart><mods:namePart type="given">Roy</mods:namePart><mods:displayForm>Magee, Roy</mods:displayForm></mods:name>',
		law=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Law</mods:namePart><mods:namePart type="given">Bernard F.</mods:namePart><mods:namePart type="date">1931-</mods:namePart><mods:displayForm>Law, Bernard F., 1931-</mods:displayForm></mods:name>',
		wilson=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Wilson</mods:namePart><mods:namePart type="given">Desmond</mods:namePart><mods:displayForm>Wilson, Desmond</mods:displayForm></mods:name>',
		faul=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Faul</mods:namePart><mods:namePart type="given">Denis</mods:namePart><mods:displayForm>Faul, Denis</mods:displayForm></mods:name>',
		smyth=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Smyth</mods:namePart><mods:namePart type="given">W. Martin</mods:namePart><mods:namePart type="given">William Martin</mods:namePart><mods:namePart type="date">1931-</mods:namePart><mods:displayForm>Smyth, W. Martin (William Martin), 1931-</mods:displayForm></mods:name>',
		bryans=>	'<mods:name type="personal"><mods:namePart type="family">Bryans</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Bryans, John</mods:displayForm></mods:name>',
		buckley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Buckley</mods:namePart><mods:namePart type="given">Pat</mods:namePart><mods:namePart type="date">1951-</mods:namePart><mods:displayForm>Buckley, Pat, 1951-</mods:displayForm></mods:name>',
		ofiaich=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">� Fiaich</mods:namePart><mods:namePart type="given">Tom�s</mods:namePart><mods:displayForm>� Fiaich, Tom�s</mods:displayForm></mods:name>',
		adams=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Adams</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:namePart type="date">1948-</mods:namePart><mods:displayForm>Adams, Gerry, 1948-</mods:displayForm></mods:name>',
		mcguinness=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McGuinness</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:namePart type="date">1950-</mods:namePart><mods:displayForm>McGuinness, Martin, 1950-</mods:displayForm></mods:name>',
		hume=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hume</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="date">1937-</mods:namePart><mods:displayForm>Hume, John, 1937-</mods:displayForm></mods:name>',
		bain=>	'<mods:name type="personal"><mods:namePart type="family">Bain</mods:namePart><mods:namePart type="given">Bob</mods:namePart><mods:displayForm>Bain, Bob</mods:displayForm></mods:name>',
		sands=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Hugh</mods:namePart><mods:displayForm>Sands, Hugh</mods:displayForm></mods:name>',
		mcilwaine=>	'<mods:name type="personal"><mods:namePart type="family">McIlwaine</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>McIlwaine, Billy</mods:displayForm></mods:name>',
		mccarthy=>	'<mods:name type="personal"><mods:namePart type="family">McCarthy</mods:namePart><mods:namePart type="given">Victor</mods:namePart><mods:displayForm>McCarthy, Victor</mods:displayForm></mods:name>',
		ross=>	'<mods:name type="personal"><mods:namePart type="family">Ross</mods:namePart><mods:namePart type="given">Hugh</mods:namePart><mods:displayForm>Ross, Hugh</mods:displayForm></mods:name>',
		molyneaux=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Molyneaux</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:displayForm>Molyneaux, James</mods:displayForm></mods:name>',
		daly=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Daly</mods:namePart><mods:namePart type="given">Cahal B.</mods:namePart><mods:displayForm>Daly, Cahal B.</mods:displayForm></mods:name>',
		andrew=>    '<mods:name type="personal" authority="naf"><mods:namePart type="given">Andrew</mods:namePart><mods:namePart type="termsOfAddress">Prince, Duke of York</mods:namePart><mods:namePart type="date">1960-</mods:namePart><mods:displayForm>Andrew, Prince, Duke of York, 1960-</mods:displayForm></mods:name>',
		york=>	'    <mods:name type="personal" authority="naf"><mods:namePart type="family">York</mods:namePart><mods:namePart type="given">Sarah Mountbatten-Windsor</mods:namePart>       <mods:namePart type="termsOfAddress">Duchess of</mods:namePart><mods:namePart type="date">1959-</mods:namePart><mods:displayForm>York, Sarah Mountbatten-Windsor, Duchess of, 1959-</mods:displayForm></mods:name>',
		noonan=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Noonan</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>Noonan, Paddy</mods:displayForm></mods:name>',
	   	mccandless=> '<mods:name type="personal" authority="naf"><mods:namePart type="family">McCandless</mods:namePart><mods:namePart type="given">Rex</mods:namePart><mods:namePart type="date">1915-1992</mods:namePart><mods:displayForm>McCandless, Rex, 1915-1992</mods:displayForm></mods:name>',
		mckee=>	  '<mods:name type="personal"><mods:namePart type="family">McKee</mods:namePart><mods:namePart type="given">Silver</mods:namePart><mods:displayForm>McKee, Silver</mods:displayForm></mods:name>',
		mcguigan=>    '<mods:name type="personal" authority="naf"><mods:namePart type="family">McGuigan</mods:namePart><mods:namePart type="given">Barry</mods:namePart><mods:namePart type="date">1961-</mods:namePart><mods:displayForm>McGuigan, Barry, 1961-</mods:displayForm></mods:name>',
    		murphy=>       '<mods:name type="personal"><mods:namePart type="family">Murphy</mods:namePart><mods:namePart type="given">T. P.</mods:namePart><mods:displayForm>Murphy, T. P.</mods:displayForm></mods:name>',
    		beveridge=>	   '<mods:name type="personal" authority="naf"><mods:namePart type="family">Beveridge</mods:namePart>       <mods:namePart type="given">Gordon S. G.</mods:namePart><mods:displayForm>Beveridge, Gordon S. G.</mods:displayForm></mods:name>',
		abercorn=>     '<mods:name type="personal"><mods:namePart type="family">Abercorn</mods:namePart><mods:namePart type="given">James Hamilton</mods:namePart><mods:namePart type="termsOfAddress">Duke of</mods:namePart><mods:namePart type="date">1934-</mods:namePart><mods:displayForm>Abercorn, James Hamilton, Duke of, 1934-</mods:displayForm></mods:name>',
		lichfield=>    '<mods:name type="personal"><mods:namePart type="family">Lichfield</mods:namePart>       <mods:namePart type="given">Leonora Anson</mods:namePart><mods:namePart type="termsOfAddress">Countess of</mods:namePart><mods:displayForm>Lichfield, Leonora Anson, Countess of</mods:displayForm></mods:name>',
		wilsons=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Wilson</mods:namePart><mods:namePart type="given">Sammy</mods:namePart><mods:namePart type="date">1953-</mods:namePart><mods:displayForm>Wilson, Sammy, 1953-</mods:displayForm></mods:name>',
		white=>	'<mods:name type="personal"><mods:namePart type="family">White</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>White, John</mods:displayForm></mods:name>',
		west=>	'<mods:name type="personal"><mods:namePart type="family">West</mods:namePart><mods:namePart type="given">Harry</mods:namePart><mods:displayForm>West, Harry</mods:displayForm></mods:name>',
		tyrie=>	'<mods:name type="personal"><mods:namePart type="family">Tyrie</mods:namePart><mods:namePart type="given">Andy</mods:namePart><mods:displayForm>Tyrie, Andy</mods:displayForm></mods:name>',
		trimble=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Trimble</mods:namePart><mods:namePart type="given">W. D.</mods:namePart><mods:namePart type="given">W. David</mods:namePart><mods:displayForm>Trimble, W. D. (W. David)</mods:displayForm></mods:name>',
		taylor=>	'<mods:name type="personal"><mods:namePart type="family">Taylor</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Taylor, John</mods:displayForm></mods:name>',
		smythh=>	'<mods:name type="personal"><mods:namePart type="family">Smyth</mods:namePart><mods:namePart type="given">Hugh</mods:namePart><mods:displayForm>Smyth, Hugh</mods:displayForm></mods:name>',
		smythe=>	'<mods:name type="personal"><mods:namePart type="family">Smyth</mods:namePart><mods:namePart type="given">Ethel</mods:namePart><mods:displayForm>Smyth, Ethel</mods:displayForm></mods:name>',
		simpson=>	'<mods:name type="personal"><mods:namePart type="family">Simpson</mods:namePart><mods:namePart type="given">Alistair</mods:namePart><mods:displayForm>Simpson, Alistair</mods:displayForm></mods:name>',
		rodgers=>	'<mods:name type="personal"><mods:namePart type="family">Rodgers</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Rodgers, Jim</mods:displayForm></mods:name>',
		robinsonp=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Robinson</mods:namePart><mods:namePart type="given">Peter</mods:namePart><mods:namePart type="given">Peter D.</mods:namePart><mods:displayForm>Robinson, Peter (Peter D.)</mods:displayForm></mods:name>',
		robinsonh=>	'<mods:name type="personal"><mods:namePart type="family">Robinson</mods:namePart><mods:namePart type="given">Henry</mods:namePart><mods:displayForm>Robinson, Henry</mods:displayForm></mods:name>',
		reynolds=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Reynolds</mods:namePart><mods:namePart type="given">Albert</mods:namePart><mods:displayForm>Reynolds, Albert</mods:displayForm></mods:name>',
		purvis=>	'<mods:name type="personal"><mods:namePart type="family">Purvis</mods:namePart><mods:namePart type="given">Dawn</mods:namePart><mods:displayForm>Purvis, Dawn</mods:displayForm></mods:name>',
		paisley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Paisley</mods:namePart><mods:namePart type="given">Ian R. K.</mods:namePart><mods:displayForm>Paisley, Ian R. K.</mods:displayForm></mods:name>',
		oreilly=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Reilly</mods:namePart><mods:namePart type="given">Tony</mods:namePart><mods:namePart type="date">1936-</mods:namePart><mods:displayForm>O\'Reilly, Tony, 1936-</mods:displayForm></mods:name>',
		odwyer=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Dwyer</mods:namePart><mods:namePart type="given">Paul</mods:namePart><mods:namePart type="date">1907-</mods:namePart><mods:displayForm>O\'Dwyer, Paul, 1907-</mods:displayForm></mods:name>',
		obradaigh=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">&#xd3; Br&#xe1;daigh</mods:namePart><mods:namePart type="given">Ruair&#xed;</mods:namePart><mods:displayForm>&#xd3; Br&#xe1;daigh, Ruair&#xed;</mods:displayForm></mods:name>',
		nibreathneach=>	'<mods:name type="personal"><mods:namePart type="family">Ni Breathneach</mods:namePart><mods:namePart type="given">Lucelita</mods:namePart><mods:displayForm>Ni Breathneach, Lucelita</mods:displayForm></mods:name>',
		nellis=>	'<mods:name type="personal"><mods:namePart type="family">Nellis</mods:namePart><mods:namePart type="given">Mary</mods:namePart><mods:displayForm>Nellis, Mary</mods:displayForm></mods:name>',
		needham=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Needham</mods:namePart><mods:namePart type="given">Richard</mods:namePart><mods:displayForm>Needham, Richard</mods:displayForm></mods:name>',
		napier=>	'<mods:name type="personal"><mods:namePart type="family">Napier</mods:namePart><mods:namePart type="given">Oliver</mods:namePart><mods:displayForm>Napier, Oliver</mods:displayForm></mods:name>',
		murrayh=>	'<mods:name type="personal"><mods:namePart type="family">Murray</mods:namePart><mods:namePart type="given">Harry</mods:namePart><mods:displayForm>Murray, Harry</mods:displayForm></mods:name>',
		murrayd=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Murray</mods:namePart><mods:namePart type="given">Donald</mods:namePart><mods:namePart type="termsOfAddress">Sir</mods:namePart><mods:displayForm>Murray, Donald, Sir</mods:displayForm></mods:name>',
		morrison=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Morrison</mods:namePart><mods:namePart type="given">Danny</mods:namePart><mods:displayForm>Morrison, Danny</mods:displayForm></mods:name>',
		meehanm=>	'<mods:name type="personal"><mods:namePart type="family">Meehan</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:displayForm>Meehan, Martin</mods:displayForm></mods:name>',
		meehanb=>	'<mods:name type="personal"><mods:namePart type="family">Meehan</mods:namePart><mods:namePart type="given">Briege</mods:namePart><mods:displayForm>Meehan, Briege</mods:displayForm></mods:name>',
		mcmichael=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McMichael</mods:namePart><mods:namePart type="given">Gary</mods:namePart><mods:namePart type="date">1969-</mods:namePart><mods:displayForm>McMichael, Gary, 1969-</mods:displayForm></mods:name>',
		mclaughlin=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McLaughlin</mods:namePart><mods:namePart type="given">Mitchel</mods:namePart><mods:displayForm>McLaughlin, Mitchel</mods:displayForm></mods:name>',
		mcivor=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McIvor</mods:namePart><mods:namePart type="given">Basil</mods:namePart><mods:displayForm>McIvor, Basil</mods:displayForm></mods:name>',
		mcguinnessa=>	'<mods:name type="personal"><mods:namePart type="family">McGuinness</mods:namePart><mods:namePart type="given">Alban</mods:namePart><mods:displayForm>McGuinness, Alban</mods:displayForm></mods:name>',
		mcgrady=>	'<mods:name type="personal"><mods:namePart type="family">McGrady</mods:namePart><mods:namePart type="given">Eddie</mods:namePart><mods:displayForm>McGrady, Eddie</mods:displayForm></mods:name>',
		mcdonnell=>	'<mods:name type="personal"><mods:namePart type="family">McDonnell</mods:namePart><mods:namePart type="given">Alasdair</mods:namePart><mods:displayForm>McDonnell, Alasdair</mods:displayForm></mods:name>',
		mcdonald=>	'<mods:name type="personal"><mods:namePart type="family">McDonald</mods:namePart><mods:namePart type="given">Jackie</mods:namePart><mods:displayForm>McDonald, Jackie</mods:displayForm></mods:name>',
		mccormack=>	'<mods:name type="personal"><mods:namePart type="family">McCormack</mods:namePart><mods:namePart type="given">Inez</mods:namePart><mods:displayForm>McCormack, Inez</mods:displayForm></mods:name>',
		mccartneyr=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McCartney</mods:namePart><mods:namePart type="given">R. L.</mods:namePart><mods:namePart type="given">Robert L.</mods:namePart><mods:displayForm>McCartney, R. L. (Robert L.)</mods:displayForm></mods:name>',
		mccartneym=>	'<mods:name type="personal"><mods:namePart type="family">McCartney</mods:namePart><mods:namePart type="given">Maureen</mods:namePart><mods:displayForm>McCartney, Maureen</mods:displayForm></mods:name>',
		mccann=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McCann</mods:namePart><mods:namePart type="given">Eamonn</mods:namePart><mods:namePart type="date">1943-</mods:namePart><mods:displayForm>McCann, Eamonn, 1943-</mods:displayForm></mods:name>',
		mcburney=>	'<mods:name type="personal"><mods:namePart type="family">McBurney</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>McBurney, Billy</mods:displayForm></mods:name>',
		mcaleese=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McAleese</mods:namePart><mods:namePart type="given">Mary</mods:namePart><mods:displayForm>McAleese, Mary</mods:displayForm></mods:name>',
		maskey=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Maskey</mods:namePart><mods:namePart type="given">Alex</mods:namePart><mods:namePart type="date">1952-</mods:namePart><mods:displayForm>Maskey, Alex, 1952-</mods:displayForm></mods:name>',
		maguirem=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Maguire</mods:namePart><mods:namePart type="given">Mairead Corrigan</mods:namePart><mods:displayForm>Maguire, Mairead Corrigan</mods:displayForm></mods:name>',
		magennisf=>	'<mods:name type="personal"><mods:namePart type="family">Magennis</mods:namePart><mods:namePart type="given">Ken</mods:namePart><mods:displayForm>Magennis, Ken</mods:displayForm></mods:name>',
		magennisa=>	'<mods:name type="personal"><mods:namePart type="family">Magennis</mods:namePart><mods:namePart type="given">Alban</mods:namePart><mods:displayForm>Magennis, Alban</mods:displayForm></mods:name>',
		magees=>	'<mods:name type="personal"><mods:namePart type="family">Magee</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Magee, Sean</mods:displayForm></mods:name>',
		macgiolla=>	'<mods:name type="personal"><mods:namePart type="family">Mac Giolla</mods:namePart><mods:namePart type="given">Tomas</mods:namePart><mods:displayForm>Mac Giolla, Tomas</mods:displayForm></mods:name>',
		lucy=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Lucy</mods:namePart><mods:namePart type="given">Gordon</mods:namePart><mods:displayForm>Lucy, Gordon</mods:displayForm></mods:name>',
		little=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Little</mods:namePart><mods:namePart type="given">Ivan</mods:namePart><mods:displayForm>Little, Ivan</mods:displayForm></mods:name>',
		king=>	'<mods:name type="personal"><mods:namePart type="family">King</mods:namePart><mods:namePart type="given">Stephen</mods:namePart><mods:displayForm>King, Stephen</mods:displayForm></mods:name>',
		kennedy=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Kennedy</mods:namePart><mods:namePart type="given">Edward M.</mods:namePart><mods:namePart type="given">Edward Moore</mods:namePart><mods:namePart type="date">1932-2009</mods:namePart><mods:displayForm>Kennedy, Edward M. (Edward Moore), 1932-2009</mods:displayForm></mods:name>',
		kellyg=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Kelly</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>Kelly, Gerry</mods:displayForm></mods:name>',
		irvine=>	'<mods:name type="personal"><mods:namePart type="family">Irvine</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>Irvine, David</mods:displayForm></mods:name>',
		hutchinson=>	'<mods:name type="personal"><mods:namePart type="family">Hutchinson</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>Hutchinson, Billy</mods:displayForm></mods:name>',
		hurd=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hurd</mods:namePart><mods:namePart type="given">Douglas</mods:namePart><mods:namePart type="date">1930-</mods:namePart><mods:displayForm>Hurd, Douglas, 1930-</mods:displayForm></mods:name>',
		humep=>	'<mods:name type="personal"><mods:namePart type="family">Hume</mods:namePart><mods:namePart type="given">Pat</mods:namePart><mods:displayForm>Hume, Pat</mods:displayForm></mods:name>',
		holland=>	'<mods:name type="personal"><mods:namePart type="family">Holland</mods:namePart><mods:namePart type="given">Beryl</mods:namePart><mods:displayForm>Holland, Beryl</mods:displayForm></mods:name>',
		henderson=>	'<mods:name type="personal"><mods:namePart type="family">Henderson</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>Henderson, Joe</mods:displayForm></mods:name>',
		haughey=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Haughey</mods:namePart><mods:namePart type="given">Charles J.</mods:namePart><mods:displayForm>Haughey, Charles J.</mods:displayForm></mods:name>',
		harvey=>	'<mods:name type="personal"><mods:namePart type="family">Harvey</mods:namePart><mods:namePart type="given">Cecil</mods:namePart><mods:displayForm>Harvey, Cecil</mods:displayForm></mods:name>',
		hamiltonr=>	'<mods:name type="personal"><mods:namePart type="family">Hamilton</mods:namePart><mods:namePart type="given">Rowan</mods:namePart><mods:displayForm>Hamilton, Rowan</mods:displayForm></mods:name>',
		hall=>	'<mods:name type="personal"><mods:namePart type="family">Hall</mods:namePart><mods:namePart type="given">William</mods:namePart><mods:displayForm>Hall, William</mods:displayForm></mods:name>',
		graceyh=>	'<mods:name type="personal"><mods:namePart type="family">Gracey</mods:namePart><mods:namePart type="given">Harold</mods:namePart><mods:displayForm>Gracey, Harold</mods:displayForm></mods:name>',
		graceyn=>	'<mods:name type="personal"><mods:namePart type="family">Gracey</mods:namePart><mods:namePart type="given">Nancy</mods:namePart><mods:displayForm>Gracey, Nancy</mods:displayForm></mods:name>',
		gormanj=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Gorman</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="date">1923-</mods:namePart><mods:displayForm>Gorman, John, 1923-</mods:displayForm></mods:name>',
		gillen=>	'<mods:name type="personal"><mods:namePart type="family">Gillen</mods:namePart><mods:namePart type="given">Tom</mods:namePart><mods:displayForm>Gillen, Tom</mods:displayForm></mods:name>',
		garrett=>	'<mods:name type="personal"><mods:namePart type="family">Garrett</mods:namePart><mods:namePart type="given">Brian</mods:namePart><mods:displayForm>Garrett, Brian</mods:displayForm></mods:name>',
		garland=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Garland</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Garland, Sean</mods:displayForm></mods:name>',
		frazer=>	'<mods:name type="personal"><mods:namePart type="family">Frazer</mods:namePart><mods:namePart type="given">Willie</mods:namePart><mods:displayForm>Frazer, Willie</mods:displayForm></mods:name>',
		fittm=>	'<mods:name type="personal"><mods:namePart type="family">Fitt</mods:namePart><mods:namePart type="given">Mary Ann</mods:namePart><mods:displayForm>Fitt, Mary Ann</mods:displayForm></mods:name>',
		fittg=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Fitt</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:namePart type="date">1926-2005</mods:namePart><mods:displayForm>Fitt, Gerry, 1926-2005</mods:displayForm></mods:name>',
		faulkner=>	'<mods:name type="personal"><mods:namePart type="family">Faulkner</mods:namePart><mods:namePart type="given">Lucy</mods:namePart><mods:namePart type="termsOfAddress">Lady</mods:namePart><mods:displayForm>Faulkner, Lucy, Lady</mods:displayForm></mods:name>',
		duddy=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Duddy</mods:namePart><mods:namePart type="given">Sam</mods:namePart><mods:displayForm>Duddy, Sam</mods:displayForm></mods:name>',
		doherty=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Doherty</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:namePart type="date">1926-</mods:namePart><mods:displayForm>Doherty, Paddy, 1926-</mods:displayForm></mods:name>',
		devlin=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Devlin</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:namePart type="date">1925-</mods:namePart><mods:displayForm>Devlin, Paddy, 1925-</mods:displayForm></mods:name>',
		currand=>	'<mods:name type="personal"><mods:namePart type="family">Curran</mods:namePart><mods:namePart type="given">Dermot</mods:namePart><mods:displayForm>Curran, Dermot</mods:displayForm></mods:name>',
		cooke=>	'<mods:name type="personal"><mods:namePart type="family">Cooke</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:namePart type="termsOfAddress">Sir</mods:namePart><mods:displayForm>Cooke, David, Sir</mods:displayForm></mods:name>',
		chichesterclark=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Chichester-Clark</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:namePart type="date">1923-</mods:namePart><mods:displayForm>Chichester-Clark, James, 1923-</mods:displayForm></mods:name>',
		cave=>	'<mods:name type="personal"><mods:namePart type="family">Cave</mods:namePart><mods:namePart type="given">Cyril</mods:namePart><mods:displayForm>Cave, Cyril</mods:displayForm></mods:name>',
		carson=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Carson</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="date">1934-</mods:namePart><mods:displayForm>Carson, John, 1934-</mods:displayForm></mods:name>',
		carron=>	'<mods:name type="personal"><mods:namePart type="family">Carron</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Carron, John</mods:displayForm></mods:name>',
		carlin=>	'<mods:name type="personal"><mods:namePart type="family">Carlin</mods:namePart><mods:namePart type="given">Terry</mods:namePart><mods:displayForm>Carlin, Terry</mods:displayForm></mods:name>',
		campbellg=>	'<mods:name type="personal"><mods:namePart type="family">Campbell</mods:namePart><mods:namePart type="given">Gregory</mods:namePart><mods:displayForm>Campbell, Gregory</mods:displayForm></mods:name>',
		calvert=>	'<mods:name type="personal"><mods:namePart type="family">Calvert</mods:namePart><mods:namePart type="given">Sarah Eileen</mods:namePart><mods:displayForm>Calvert, Sarah Eileen</mods:displayForm></mods:name>',
		burnside=>	'<mods:name type="personal"><mods:namePart type="family">Burnside</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>Burnside, David</mods:displayForm></mods:name>',
		brookej=>	'<mods:name type="personal"><mods:namePart type="family">Brooke</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Brooke, John</mods:displayForm></mods:name>',
		brookeb=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Brooke</mods:namePart><mods:namePart type="given">Basil</mods:namePart><mods:namePart type="date">1888-1973</mods:namePart><mods:displayForm>Brooke, Basil, 1888-1973</mods:displayForm></mods:name>',
		biggsdavison=>	'<mods:name type="personal"><mods:namePart type="family">Biggs-Davison</mods:namePart><mods:namePart type="given">John Alec</mods:namePart><mods:namePart type="date">1918-</mods:namePart><mods:displayForm>Biggs-Davison, John Alec, 1918-</mods:displayForm></mods:name>',
		behan=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Behan</mods:namePart><mods:namePart type="given">Dominic</mods:namePart><mods:displayForm>Behan, Dominic</mods:displayForm></mods:name>',
		barr=>	'<mods:name type="personal"><mods:namePart type="family">Barr</mods:namePart><mods:namePart type="given">Glen</mods:namePart><mods:displayForm>Barr, Glen</mods:displayForm></mods:name>',
		anne=>	'<mods:name type="personal" authority="naf"><mods:namePart type="given">Anne</mods:namePart><mods:namePart type="termsOfAddress">Princess Royal, daughter of Elizabeth II, Queen of Great Britain</mods:namePart><mods:namePart type="date">1950-</mods:namePart><mods:displayForm>, Anne, Princess Royal, daughter of Elizabeth II, Queen of Great Britain,  1950-</mods:displayForm></mods:name>',
		adamson=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Adamson</mods:namePart><mods:namePart type="given">Ian</mods:namePart><mods:displayForm>Adamson, Ian</mods:displayForm></mods:name>',
		adamsd=>	'<mods:name type="personal"><mods:namePart type="family">Adams</mods:namePart ><mods:namePart type="given">David</mods:namePart><mods:displayForm>Adams, David</mods:displayForm></mods:name>',
		bradford=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Bradford</mods:namePart><mods:namePart type="given">Roy</mods:namePart><mods:displayForm>Bradford, Roy</mods:displayForm></mods:name>',
		brookeborough=>	'<mods:name type="personal"><mods:namePart type="family">Brookeborough</mods:namePart><mods:namePart type="given">Rosemary</mods:namePart><mods:namePart type="termsOfAddress">Lady</mods:namePart><mods:displayForm>Brookeborough, Rosemary, Lady</mods:displayForm></mods:name>',
		begley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Begley</mods:namePart><mods:namePart type="given">Philomena</mods:namePart><mods:displayForm>Begley, Philomena</mods:displayForm></mods:name>',
		odohertyd=>	'<mods:name type="personal"><mods:namePart type="family">O\'Doherty</mods:namePart><mods:namePart type="given">Don</mods:namePart><mods:displayForm>O\'Doherty, Don</mods:displayForm></mods:name>',
		martin=>	'<mods:name type="personal"><mods:namePart type="family">Martin</mods:namePart><mods:namePart type="given">Neil</mods:namePart><mods:displayForm>Martin, Neil</mods:displayForm></mods:name>',
		campbelljohn=>	'<mods:name type="personal"><mods:namePart type="family">Campbell</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Campbell, John</mods:displayForm></mods:name>',
		mckinlay=>	'<mods:name type="personal"><mods:namePart type="family">McKinlay</mods:namePart><mods:namePart type="given">Patrick</mods:namePart><mods:displayForm>McKinlay, Patrick</mods:displayForm></mods:name>',
		goss=>	'<mods:name type="personal"><mods:namePart type="family">Goss</mods:namePart><mods:namePart type="given">Ciaran</mods:namePart><mods:displayForm>Goss, Ciaran</mods:displayForm></mods:name>',
		mcintyre=>	'<mods:name type="personal"><mods:namePart type="family">McIntyre</mods:namePart><mods:namePart type="given">Gay</mods:namePart><mods:displayForm>McIntyre, Gay</mods:displayForm></mods:name>',
		mcanneonen=>	'<mods:name type="personal"><mods:namePart type="family">McCann</mods:namePart><mods:namePart type="given">Eamon</mods:namePart><mods:displayForm>McCann, Eamon</mods:displayForm></mods:name>',
		coulter=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Coulter</mods:namePart><mods:namePart type="given">Phil</mods:namePart><mods:displayForm>Coulter, Phil</mods:displayForm></mods:name>',
		cash=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Cash</mods:namePart><mods:namePart type="given">Johnny</mods:namePart><mods:displayForm>Cash, Johnny</mods:displayForm></mods:name>',
		cashjune=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Cash</mods:namePart><mods:namePart type="given">June Carter</mods:namePart><mods:displayForm>Cash, June Carter</mods:displayForm></mods:name>',
		lewis=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Lewis</mods:namePart><mods:namePart type="given">Jerry Lee</mods:namePart><mods:displayForm>Lewis, Jerry Lee</mods:displayForm></mods:name>',
		lee=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Lee</mods:namePart><mods:namePart type="given">Brenda</mods:namePart><mods:displayForm>Lee, Brenda</mods:displayForm></mods:name>',
		sandsm=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Mick</mods:namePart><mods:displayForm>Sands, Mick</mods:displayForm></mods:name>',
		sandsb=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Bridie</mods:namePart><mods:displayForm>Sands, Bridie</mods:displayForm></mods:name>',
		coughlan=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Coughlan</mods:namePart><mods:namePart type="given">Mary</mods:namePart><mods:displayForm>Coughlan, Mary</mods:displayForm></mods:name>',
		shannon=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Shannon</mods:namePart><mods:namePart type="given">Sharon</mods:namePart><mods:displayForm>Shannon, Sharon</mods:displayForm></mods:name>',
		keane=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Keane</mods:namePart><mods:namePart type="given">Dolores</mods:namePart><mods:displayForm>Keane, Dolores</mods:displayForm></mods:name>',
		woods=>	'<mods:name type="personal"><mods:namePart type="family">Woods</mods:namePart><mods:namePart type="given">Pat</mods:namePart><mods:displayForm>Woods, Pat</mods:displayForm></mods:name>',
		graham=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Graham</mods:namePart><mods:namePart type="given">Len</mods:namePart><mods:displayForm>Graham, Len</mods:displayForm></mods:name>',
		barry=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Barry</mods:namePart><mods:namePart type="given">Margaret</mods:namePart><mods:displayForm>Barry, Margaret</mods:displayForm></mods:name>',
		hanvey=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hanvey</mods:namePart><mods:namePart type="given">Bobbie</mods:namePart><mods:displayForm>Hanvey, Bobbie</mods:displayForm></mods:name>',
		morrissonv=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Morrison</mods:namePart><mods:namePart type="given">Van</mods:namePart><mods:displayForm>Morrison, Van</mods:displayForm></mods:name>',
		belld=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Bell</mods:namePart><mods:namePart type="given">Derek</mods:namePart><mods:displayForm>Bell, Derek</mods:displayForm></mods:name>',
		sandst=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Tommy</mods:namePart><mods:displayForm>Sands, Tommy</mods:displayForm></mods:name>',
		sandse=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Eugene</mods:namePart><mods:displayForm>Sands, Eugene</mods:displayForm></mods:name>',
		lloyd=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Lloyd</mods:namePart><mods:namePart type="given">A. L.</mods:namePart><mods:namePart type="given">Albert Lancaster</mods:namePart><mods:displayForm>Lloyd, A. L. (Albert Lancaster)</mods:displayForm></mods:name>',
		oflaherty=>	'<mods:name type="personal"><mods:namePart type="family">O\'Flaherty</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>O\'Flaherty, Paddy</mods:displayForm></mods:name>',
		campbellt=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Campbell</mods:namePart><mods:namePart type="given">Trevor</mods:namePart><mods:displayForm>Campbell, Trevor</mods:displayForm></mods:name>',
		mcconell=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McConnell</mods:namePart><mods:namePart type="given">Cathal</mods:namePart><mods:displayForm>McConnell, Cathal</mods:displayForm></mods:name>',
		watt=>	'<mods:name type="personal"><mods:namePart type="family">Watt</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Watt, John</mods:displayForm></mods:name>',
		butchere=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Butcher</mods:namePart><mods:namePart type="given">Eddie</mods:namePart><mods:displayForm>Butcher, Eddie</mods:displayForm></mods:name>',
		butcherg=>	'<mods:name type="personal"><mods:namePart type="family">Butcher</mods:namePart><mods:namePart type="given">Grace</mods:namePart><mods:displayForm>Butcher, Grace</mods:displayForm></mods:name>',
		makem=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Makem</mods:namePart><mods:namePart type="given">Tommy</mods:namePart><mods:displayForm>Makem, Tommy</mods:displayForm></mods:name>',
		clancyl=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Clancy</mods:namePart><mods:namePart type="given">Liam</mods:namePart><mods:displayForm>Clancy, Liam</mods:displayForm></mods:name>',
		oconnellr=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Connell</mods:namePart><mods:namePart type="given">Robbie</mods:namePart><mods:displayForm>O\'Connell, Robbie</mods:displayForm></mods:name>',
		clancyb=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Clancy</mods:namePart><mods:namePart type="given">Bobby</mods:namePart><mods:displayForm>Clancy, Bobby</mods:displayForm></mods:name>',
		clancyp=>	'<mods:name type="personal"><mods:namePart type="family">Clancy</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>Clancy, Paddy</mods:displayForm></mods:name>',
		clancy=>	'<mods:name type="personal"><mods:namePart type="family">Clancy</mods:namePart><mods:namePart type="given">Tom</mods:namePart><mods:displayForm>Clancy, Tom</mods:displayForm></mods:name>',
		greer=>	'<mods:name type="personal"><mods:namePart type="family">Greer</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Greer, John</mods:displayForm></mods:name>',
		quinnj=>	'<mods:name type="personal"><mods:namePart type="family">Quinn</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="given">Ned</mods:namePart><mods:displayForm>Quinn, John (Ned)</mods:displayForm></mods:name>',
		mckay=>	'<mods:name type="personal"><mods:namePart type="family">McKay</mods:namePart><mods:namePart type="given">Benny</mods:namePart><mods:displayForm>McKay, Benny</mods:displayForm></mods:name>',
		quinnm=>	'<mods:name type="personal"><mods:namePart type="family">Quinn</mods:namePart><mods:namePart type="given">Michael</mods:namePart><mods:displayForm>Quinn, Michael</mods:displayForm></mods:name>',
		irvinea=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Irvine</mods:namePart><mods:namePart type="given">Andy</mods:namePart><mods:displayForm>Irvine, Andy</mods:displayForm></mods:name>',
		moore=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Moore</mods:namePart><mods:namePart type="given">Christy</mods:namePart><mods:displayForm>Moore, Christy</mods:displayForm></mods:name>',
		brady=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Brady</mods:namePart><mods:namePart type="given">Paul</mods:namePart><mods:namePart type="termsOfAddress">vocalist</mods:namePart><mods:displayForm>Brady, Paul, vocalist</mods:displayForm></mods:name>',
		breena=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Breen</mods:namePart><mods:namePart type="given">Ann</mods:namePart><mods:namePart type="termsOfAddress">vocalist</mods:namePart><mods:displayForm>Breen, Ann, vocalist</mods:displayForm></mods:name>',
		mcfadden=>	'<mods:name type="personal"><mods:namePart type="family">McFadden</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>McFadden, Gerry</mods:displayForm></mods:name>',
		mccaffertyleo=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McCaffrey</mods:namePart><mods:namePart type="given">Leo</mods:namePart><mods:displayForm>McCaffrey, Leo</mods:displayForm></mods:name>',
		occonellm=>	'<mods:name type="personal"><mods:namePart type="family">O\'Connell</mods:namePart><mods:namePart type="given">Maire</mods:namePart><mods:displayForm>O\'Connell, Maire</mods:displayForm></mods:name>',
		knowles=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Knowles</mods:namePart><mods:namePart type="given">Sonny</mods:namePart><mods:displayForm>Knowles, Sonny</mods:displayForm></mods:name>',
		irvinej=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Irwin</mods:namePart><mods:namePart type="given">James B.</mods:namePart><mods:namePart type="given">James Benson</mods:namePart><mods:displayForm>Irwin, James B. (James Benson)</mods:displayForm></mods:name>',
		brollya=>	'<mods:name type="personal"><mods:namePart type="family">Brolly</mods:namePart><mods:namePart type="given">Anne</mods:namePart><mods:displayForm>Brolly, Anne</mods:displayForm></mods:name>',
		brollyf=>	'<mods:name type="personal"><mods:namePart type="family">Brolly</mods:namePart><mods:namePart type="given">Francie</mods:namePart><mods:displayForm>Brolly, Francie</mods:displayForm></mods:name>',
		salmon=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Salmon</mods:namePart><mods:namePart type="given">Colin</mods:namePart><mods:displayForm>Salmon, Colin</mods:displayForm></mods:name>',
		cassels=>	'<mods:name type="personal"><mods:namePart type="family">Cassels</mods:namePart><mods:namePart type="given">Harry</mods:namePart><mods:displayForm>Cassels, Harry</mods:displayForm></mods:name>',
		sloand=>	'<mods:name type="personal"><mods:namePart type="family">Sloan</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>Sloan, David</mods:displayForm></mods:name>',
		sloana=>	'<mods:name type="personal"><mods:namePart type="family">Sloan</mods:namePart><mods:namePart type="given">Anna</mods:namePart><mods:displayForm>Sloan, Anna</mods:displayForm></mods:name>',
		mcdermott=>	'<mods:name type="personal"><mods:namePart type="family">McDermott</mods:namePart><mods:namePart type="given">Tommy</mods:namePart><mods:displayForm>McDermott, Tommy</mods:displayForm></mods:name>',
		sandsc=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Colm</mods:namePart><mods:displayForm>Sands, Colm</mods:displayForm></mods:name>',
		sandsbar=>	'<mods:name type="personal"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Barbara</mods:namePart><mods:displayForm>Sands, Barbara</mods:displayForm></mods:name>',
		dunbar=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Dunbar</mods:namePart><mods:namePart type="given">Adrian</mods:namePart><mods:displayForm>Dunbar, Adrian</mods:displayForm></mods:name>',
		trotter=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Trotter</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:namePart type="termsOfAddress">bagpipe player</mods:namePart><mods:displayForm>Trotter, John, bagpipe player</mods:displayForm></mods:name>',
		rea=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Rea</mods:namePart><mods:namePart type="given">Stephen</mods:namePart><mods:displayForm>Rea, Stephen</mods:displayForm></mods:name>',
		hoey=>	'<mods:name type="personal"><mods:namePart type="family">Hoey</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>Hoey, Joe</mods:displayForm></mods:name>',
		brennan=>	'<mods:name type="personal"><mods:namePart type="family">Brennan</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>Brennan, Paddy</mods:displayForm></mods:name>',
		hughes=>	'<mods:name type="personal"><mods:namePart type="family">Hughes</mods:namePart><mods:namePart type="given">Bobby</mods:namePart><mods:displayForm>Hughes, Bobby</mods:displayForm></mods:name>',
		patterson=>	'<mods:name type="personal"><mods:namePart type="family">Patterson</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>Patterson, Billy</mods:displayForm></mods:name>',
		melville=>	'<mods:name type="personal"><mods:namePart type="family">Melville</mods:namePart><mods:namePart type="given">Pat</mods:namePart><mods:displayForm>Melville, Pat</mods:displayForm></mods:name>',
		mcglynn=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McGlynn</mods:namePart><mods:namePart type="given">Arty</mods:namePart><mods:displayForm>McGlynn, Arty</mods:displayForm></mods:name>',
		redmondw=>	'<mods:name type="personal"><mods:namePart type="family">Redmond</mods:namePart><mods:namePart type="given">Willie</mods:namePart><mods:displayForm>Redmond, Willie</mods:displayForm></mods:name>',
		redmonds=>	'<mods:name type="personal"><mods:namePart type="family">Redmond</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Redmond, Sean</mods:displayForm></mods:name>',
		mongaguel=>	'<mods:name type="personal"><mods:namePart type="family">Montague</mods:namePart><mods:namePart type="given">Lawrence</mods:namePart><mods:displayForm>Montague, Lawrence</mods:displayForm></mods:name>',
		maguires=>	'<mods:name type="personal"><mods:namePart type="family">Maguire</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Maguire, Sean</mods:displayForm></mods:name>',
		lennon=>	'<mods:name type="personal"><mods:namePart type="family">Lennon</mods:namePart><mods:namePart type="given">Frank</mods:namePart><mods:displayForm>Lennon, Frank</mods:displayForm></mods:name>',
		tomelty=>	'<mods:name type="personal"><mods:namePart type="family">Tomelty</mods:namePart><mods:namePart type="given">Roma</mods:namePart><mods:displayForm>Tomelty, Roma</mods:displayForm></mods:name>',
		davis=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Davis</mods:namePart><mods:namePart type="given">John T.</mods:namePart><mods:displayForm>Davis, John T.</mods:displayForm></mods:name>',
		crockart=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Crockart</mods:namePart><mods:namePart type="given">Andrew</mods:namePart><mods:displayForm>Crockart, Andrew</mods:displayForm></mods:name>',
		mooney=>	'<mods:name type="personal"><mods:namePart type="family">Mooney</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Mooney, Sean</mods:displayForm></mods:name>',
		hermonj=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hermon</mods:namePart><mods:namePart type="given">John C.</mods:namePart><mods:namePart type="given">(John Charles)</mods:namePart><mods:namePart type="termsOfAddress">Sir</mods:namePart><mods:displayForm>Hermon, John C. ((John Charles)), Sir</mods:displayForm></mods:name>',
		hermons=>	'<mods:name type="personal"><mods:namePart type="family">Hermon</mods:namePart><mods:namePart type="given">Sylvia</mods:namePart><mods:displayForm>Hermon, Sylvia</mods:displayForm></mods:name>',
		hermonr=>	'<mods:name type="personal"><mods:namePart type="family">Hermon</mods:namePart><mods:namePart type="given">Robert</mods:namePart><mods:displayForm>Hermon, Robert</mods:displayForm></mods:name>',
		vance=>	'<mods:name type="personal"><mods:namePart type="family">Vance</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:displayForm>Vance, Martin</mods:displayForm></mods:name>',
		hazlett=>	'<mods:name type="personal"><mods:namePart type="family">Hazlett</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Hazlett, Jim</mods:displayForm></mods:name>',
		finlay=>	'<mods:name type="personal"><mods:namePart type="family">Finlay</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>Finlay, Billy</mods:displayForm></mods:name>',
		curranm=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Curran</mods:namePart><mods:namePart type="given">Matthew Francis</mods:namePart><mods:displayForm>Curran, Matthew Francis</mods:displayForm></mods:name>',
		annesley=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Annesley</mods:namePart><mods:namePart type="given">H. N.</mods:namePart><mods:namePart type="given">Hugh N.</mods:namePart><mods:displayForm>Annesley, H. N. (Hugh N.)</mods:displayForm></mods:name>',
		wheeler=>	'<mods:name type="personal"><mods:namePart type="family">Wheeler</mods:namePart><mods:namePart type="given">Roger</mods:namePart><mods:namePart type="termsOfAddress">Sir</mods:namePart><mods:displayForm>Wheeler, Roger, Sir</mods:displayForm></mods:name>',
		stockdale=>	'<mods:name type="personal"><mods:namePart type="family">Stockdale</mods:namePart><mods:namePart type="given">Frank</mods:namePart><mods:displayForm>Stockdale, Frank</mods:displayForm></mods:name>',
		dalyjames=>	'<mods:name type="personal"><mods:namePart type="family">Daly</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:displayForm>Daly, James</mods:displayForm></mods:name>',
		baxter=>	'<mods:name type="personal"><mods:namePart type="family">Baxter</mods:namePart><mods:namePart type="given">Harry</mods:namePart><mods:namePart type="termsOfAddress">Brigadier</mods:namePart><mods:displayForm>Baxter, Harry, Brigadier</mods:displayForm></mods:name>',
		ocarroll=>	'<mods:name type="personal"><mods:namePart type="family">O\'Carroll</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>O\'Carroll, Gerry</mods:displayForm></mods:name>',
		torrens=>	'<mods:name type="personal"><mods:namePart type="family">Torrens-Spence</mods:namePart><mods:namePart type="given">Rachel</mods:namePart><mods:displayForm>Torrens-Spence, Rachel</mods:displayForm></mods:name>',
		spence=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Spence</mods:namePart><mods:namePart type="given">Gusty</mods:namePart><mods:namePart type="date">1933-</mods:namePart><mods:displayForm>Spence, Gusty, 1933-</mods:displayForm></mods:name>',
		robinson=>	'<mods:name type="personal"><mods:namePart type="family">Robinson</mods:namePart><mods:namePart type="given">Buck</mods:namePart><mods:namePart type="given">Alec</mods:namePart><mods:displayForm>Robinson, Buck (Alec)</mods:displayForm></mods:name>',
		mcmichaelj=>	'<mods:name type="personal"><mods:namePart type="family">McMichael</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>McMichael, John</mods:displayForm></mods:name>',
		deburca=>	'<mods:name type="personal"><mods:namePart type="family">De Burca</mods:namePart><mods:namePart type="given">Mairin</mods:namePart><mods:displayForm>De Burca, Mairin</mods:displayForm></mods:name>',
		fitzsimonsv=>	'<mods:name type="personal"><mods:namePart type="family">Fitzsimons</mods:namePart><mods:namePart type="given">Vivienne</mods:namePart><mods:displayForm>Fitzsimons, Vivienne</mods:displayForm></mods:name>',
		ohanlon=>	'<mods:name type="personal"><mods:namePart type="family">O\'Hanlon</mods:namePart><mods:namePart type="given">Leo</mods:namePart><mods:displayForm>O\'Hanlon, Leo</mods:displayForm></mods:name>',
		fitzsimonsf=>	'<mods:name type="personal"><mods:namePart type="family">Fitzsimons</mods:namePart><mods:namePart type="given">Frank</mods:namePart><mods:displayForm>Fitzsimons, Frank</mods:displayForm></mods:name>',
		payne=>	'<mods:name type="personal"><mods:namePart type="family">Payne</mods:namePart><mods:namePart type="given">Davey</mods:namePart><mods:displayForm>Payne, Davey</mods:displayForm></mods:name>',
		mclaughlins=>	'<mods:name type="personal"><mods:namePart type="family">McLaughlin</mods:namePart><mods:namePart type="given">Samuel</mods:namePart><mods:displayForm>McLaughlin, Samuel</mods:displayForm></mods:name>',
		loane=>	'<mods:name type="personal"><mods:namePart type="family">Loane</mods:namePart><mods:namePart type="given">Paul</mods:namePart><mods:displayForm>Loane, Paul</mods:displayForm></mods:name>',
		craig=>	'<mods:name type="personal"><mods:namePart type="family">Craig</mods:namePart><mods:namePart type="given">Jimmy</mods:namePart><mods:displayForm>Craig, Jimmy</mods:displayForm></mods:name>',
		mcglincheyd=>	'<mods:name type="personal"><mods:namePart type="family">McGlinchey</mods:namePart><mods:namePart type="given">Dominic</mods:namePart><mods:displayForm>McGlinchey, Dominic</mods:displayForm></mods:name>',
		mcglincheym=>	'<mods:name type="personal"><mods:namePart type="family">McGlinchey</mods:namePart><mods:namePart type="given">Mary</mods:namePart><mods:displayForm>McGlinchey, Mary</mods:displayForm></mods:name>',
		healy=>	'<mods:name type="personal"><mods:namePart type="family">Healy</mods:namePart><mods:namePart type="given">Maurice</mods:namePart><mods:displayForm>Healy, Maurice</mods:displayForm></mods:name>',
		sandsbob=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Sands</mods:namePart><mods:namePart type="given">Bobby</mods:namePart><mods:namePart type="date">d. 1981</mods:namePart><mods:displayForm>Sands, Bobby, d. 1981</mods:displayForm></mods:name>',
		mandela=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Mandela</mods:namePart><mods:namePart type="given">Nelson</mods:namePart><mods:namePart type="date">1918-</mods:namePart><mods:displayForm>Mandela, Nelson, 1918-</mods:displayForm></mods:name>',
		cahillj=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Cahill</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:namePart type="date">1920-2004</mods:namePart><mods:displayForm>Cahill, Joe, 1920-2004</mods:displayForm></mods:name>',
		cahilla=>	'<mods:name type="personal"><mods:namePart type="family">Cahill</mods:namePart><mods:namePart type="given">Annie</mods:namePart><mods:displayForm>Cahill, Annie</mods:displayForm></mods:name>',
		goulding=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Goulding</mods:namePart><mods:namePart type="given">Cathal</mods:namePart><mods:namePart type="date">1922-1998</mods:namePart><mods:displayForm>Goulding, Cathal, 1922-1998</mods:displayForm></mods:name>',
		ohagan=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Hagan</mods:namePart><mods:namePart type="given">Des</mods:namePart><mods:namePart type="date">1934-</mods:namePart><mods:displayForm>O\'Hagan, Des, 1934-</mods:displayForm></mods:name>',
		obradaighp=>	'<mods:name type="personal"><mods:namePart type="family">&#xd3; Br&#xe1;daigh</mods:namePart><mods:namePart type="given">Patsy</mods:namePart><mods:displayForm>&#xd3; Br&#xe1;daigh, Patsy</mods:displayForm></mods:name>',
		mccartney=>	'<mods:name type="personal"><mods:namePart type="family">McCartney</mods:namePart><mods:namePart type="given">Raymond</mods:namePart><mods:displayForm>McCartney, Raymond</mods:displayForm></mods:name>',
		drumm=>	'<mods:name type="personal"><mods:namePart type="family">Drumm</mods:namePart><mods:namePart type="given">Jimmy</mods:namePart><mods:displayForm>Drumm, Jimmy</mods:displayForm></mods:name>',
		english=>	'<mods:name type="personal"><mods:namePart type="family">English</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>English, Joe</mods:displayForm></mods:name>',
		macstiofain=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">MacStiof&#xe1;in</mods:namePart><mods:namePart type="given">Se&#xe1;n</mods:namePart><mods:namePart type="date">1928-</mods:namePart><mods:displayForm>MacStiof&#xe1;in, Se&#xe1;n, 1928-</mods:displayForm></mods:name>',
	        day=>	'<mods:name type="personal"><mods:namePart type="family">Day</mods:namePart><mods:namePart type="given">Heather</mods:namePart><mods:namePart type="given">Lissett</mods:namePart><mods:displayForm>Day, Heather (Lissett)</mods:displayForm></mods:name>',
		mcquillan=>	'<mods:name type="personal"><mods:namePart type="family">McQuillan</mods:namePart><mods:namePart type="given">Alan</mods:namePart><mods:displayForm>McQuillan, Alan</mods:displayForm></mods:name>',
		mcclurg=>	'<mods:name type="personal"><mods:namePart type="family">McClurg</mods:namePart><mods:namePart type="given">David</mods:namePart><mods:displayForm>McClurg, David</mods:displayForm></mods:name>',
		orde=>	'<mods:name type="personal"><mods:namePart type="family">Orde</mods:namePart><mods:namePart type="given">Hugh</mods:namePart><mods:displayForm>Orde, Hugh</mods:displayForm></mods:name>',
		gillespie=>	'<mods:name type="personal"><mods:namePart type="family">Gillespie</mods:namePart><mods:namePart type="given">Judith</mods:namePart><mods:displayForm>Gillespie, Judith</mods:displayForm></mods:name>',
		aiken=>	'<mods:name type="personal"><mods:namePart type="family">Aiken</mods:namePart><mods:namePart type="given">Philip</mods:namePart><mods:displayForm>Aiken, Philip</mods:displayForm></mods:name>',
		primrose=>	'<mods:name type="personal"><mods:namePart type="family">Primrose</mods:namePart><mods:namePart type="given">Carol</mods:namePart><mods:displayForm>Primrose, Carol</mods:displayForm></mods:name>',
		middlemas=>	'<mods:name type="personal"><mods:namePart type="family">Middlemas</mods:namePart><mods:namePart type="given">John</mods:namePart><mods:displayForm>Middlemas, John</mods:displayForm></mods:name>',
		breend=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Breen</mods:namePart><mods:namePart type="given">Dan</mods:namePart><mods:displayForm>Breen, Dan</mods:displayForm></mods:name>',
		forbes=>	'<mods:name type="personal"><mods:namePart type="family">Forbes</mods:namePart><mods:namePart type="given">Ian</mods:namePart><mods:namePart type="given">Foxy</mods:namePart><mods:displayForm>Forbes, Ian (Foxy)</mods:displayForm></mods:name>',
		lagan=>	'<mods:name type="personal"><mods:namePart type="family">Lagan</mods:namePart><mods:namePart type="given">Frank</mods:namePart><mods:displayForm>Lagan, Frank</mods:displayForm></mods:name>',
		mccargo=>	'<mods:name type="personal"><mods:namePart type="family">McCargo</mods:namePart><mods:namePart type="given">Brian</mods:namePart><mods:displayForm>McCargo, Brian</mods:displayForm></mods:name>',
		lusty=>	'<mods:name type="personal"><mods:namePart type="family">Lusty</mods:namePart><mods:namePart type="given">Arthur</mods:namePart><mods:displayForm>Lusty, Arthur</mods:displayForm></mods:name>',
		primroses=>	'<mods:name type="personal"><mods:namePart type="family">Primrose</mods:namePart><mods:namePart type="given">Sarah</mods:namePart><mods:displayForm>Primrose, Sarah</mods:displayForm></mods:name>',
		catterson=>	'<mods:name type="personal"><mods:namePart type="family">Catterson</mods:namePart><mods:namePart type="given">Bob</mods:namePart><mods:namePart type="given">The Cat</mods:namePart><mods:displayForm>Catterson, Bob (The Cat)</mods:displayForm></mods:name>',
		porter=>	'<mods:name type="personal"><mods:namePart type="family">Porter</mods:namePart><mods:namePart type="given">Sue</mods:namePart><mods:displayForm>Porter, Sue</mods:displayForm></mods:name>',
		fegan=>	'<mods:name type="personal"><mods:namePart type="family">Fegan</mods:namePart><mods:namePart type="given">Davy</mods:namePart><mods:displayForm>Fegan, Davy</mods:displayForm></mods:name>',
		flanaganr=>	'<mods:name type="personal"><mods:namePart type="family">Flanagan</mods:namePart><mods:namePart type="given">Ronnie</mods:namePart><mods:namePart type="termsOfAddress">Sir</mods:namePart><mods:displayForm>Flanagan, Ronnie, Sir</mods:displayForm></mods:name>',
		whites=>	'<mods:name type="personal"><mods:namePart type="family">White</mods:namePart><mods:namePart type="given">Stephen</mods:namePart><mods:displayForm>White, Stephen</mods:displayForm></mods:name>',
		nesbitt=>	'<mods:name type="personal"><mods:namePart type="family">Nesbitt</mods:namePart><mods:namePart type="given">Jimmy</mods:namePart><mods:displayForm>Nesbitt, Jimmy</mods:displayForm></mods:name>',
		lockhart=>	'<mods:name type="personal"><mods:namePart type="family">Lockhart</mods:namePart><mods:namePart type="given">Dave</mods:namePart><mods:displayForm>Lockhart, Dave</mods:displayForm></mods:name>',
		alexander=>	'<mods:name type="personal"><mods:namePart type="family">Alexander</mods:namePart><mods:namePart type="given">Monty</mods:namePart><mods:displayForm>Alexander, Monty</mods:displayForm></mods:name>',
		brown=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Brown</mods:namePart><mods:namePart type="given">Johnston</mods:namePart><mods:namePart type="date">1950-</mods:namePart><mods:displayForm>Brown, Johnston, 1950-</mods:displayForm></mods:name>',
		godson=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Godson</mods:namePart><mods:namePart type="given">Dean</mods:namePart><mods:displayForm>Godson, Dean</mods:displayForm></mods:name>',
		devalera=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">De Valera</mods:namePart><mods:namePart type="given">&#201;amon</mods:namePart><mods:namePart type="date">1882-1975</mods:namePart><mods:displayForm>De Valera, &#201;amon, 1882-1975</mods:displayForm></mods:name>',
		cunningham=>	'<mods:name type="personal"><mods:namePart type="family">Cunningham</mods:namePart><mods:namePart type="given">Dominic</mods:namePart><mods:displayForm>Cunningham, Dominic</mods:displayForm></mods:name>',
		obrienm=>	'<mods:name type="personal"><mods:namePart type="family">O\'Brien</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:displayForm>O\'Brien, Martin</mods:displayForm></mods:name>',
		mciiwaineb=>	'<mods:name type="personal"><mods:namePart type="family">McIlwaine</mods:namePart><mods:namePart type="given">Eddie</mods:namePart><mods:displayForm>McIlwaine, Eddie</mods:displayForm></mods:name>',
		mccoubreyj=>	'<mods:name type="personal"><mods:namePart type="family">McCoubrey</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>McCoubrey, Joe</mods:displayForm></mods:name>',
		conachty=>	'<mods:name type="personal"><mods:namePart type="family">Conachty</mods:namePart><mods:namePart type="given">Tom</mods:namePart><mods:displayForm>Conachty, Tom</mods:displayForm></mods:name>',
		hawthornej=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Hawthorne</mods:namePart><mods:namePart type="given">James</mods:namePart><mods:displayForm>Hawthorne, James</mods:displayForm></mods:name>',
		mccreery=>	'<mods:name type="personal"><mods:namePart type="family">McCreery</mods:namePart><mods:namePart type="given">Alf</mods:namePart><mods:displayForm>McCreery, Alf</mods:displayForm></mods:name>',
		blackshaw=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Blackshaw</mods:namePart><mods:namePart type="given">Basil</mods:namePart><mods:namePart type="date">1932-</mods:namePart><mods:displayForm>Blackshaw, Basil, 1932-</mods:displayForm></mods:name>',
		lifsett=>	'<mods:name type="personal"><mods:namePart type="family">Lifsett</mods:namePart><mods:namePart type="given">Solly</mods:namePart><mods:displayForm>Lifsett, Solly</mods:displayForm></mods:name>',
		wheelerm=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Wheeler</mods:namePart><mods:namePart type="given">Maureen</mods:namePart><mods:displayForm>Wheeler, Maureen</mods:displayForm></mods:name>',
		dawkins=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Dawkins</mods:namePart><mods:namePart type="given">Richard</mods:namePart><mods:namePart type="date">1941-</mods:namePart><mods:displayForm>Dawkins, Richard, 1941-</mods:displayForm></mods:name>',
		doyle=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Doyle</mods:namePart><mods:namePart type="given">Colman</mods:namePart><mods:namePart type="date">1932-</mods:namePart><mods:displayForm>Doyle, Colman, 1932-</mods:displayForm></mods:name>',
		pattersong=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Patterson</mods:namePart><mods:namePart type="given">Glenn</mods:namePart><mods:namePart type="date">1961-</mods:namePart><mods:displayForm>Patterson, Glenn, 1961-</mods:displayForm></mods:name>',
		ryder=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Ryder</mods:namePart><mods:namePart type="given">Chris</mods:namePart><mods:namePart type="date">1947-</mods:namePart><mods:displayForm>Ryder, Chris, 1947-</mods:displayForm></mods:name>',
		currie=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Currie</mods:namePart><mods:namePart type="given">Austin</mods:namePart><mods:namePart type="date">1939-</mods:namePart><mods:displayForm>Currie, Austin, 1939-</mods:displayForm></mods:name>',
		gatt=>	'<mods:name type="personal"><mods:namePart type="family">Gatt</mods:namePart><mods:namePart type="given">Bill</mods:namePart><mods:displayForm>Gatt, Bill</mods:displayForm></mods:name>',
		clarkson=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Clarkson</mods:namePart><mods:namePart type="given">Leslie A.</mods:namePart><mods:displayForm>Clarkson, Leslie A.</mods:displayForm></mods:name>',
		ormsby=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Ormsby</mods:namePart><mods:namePart type="given">Frank</mods:namePart><mods:namePart type="date">1947-</mods:namePart><mods:displayForm>Ormsby, Frank, 1947-</mods:displayForm></mods:name>',
		longleye=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Longley</mods:namePart><mods:namePart type="given">Edna</mods:namePart><mods:displayForm>Longley, Edna</mods:displayForm></mods:name>',
		oclery=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">O\'Clery</mods:namePart><mods:namePart type="given">Conor</mods:namePart><mods:displayForm>O\'Clery, Conor</mods:displayForm></mods:name>',
		feeney=>	'<mods:name type="personal"><mods:namePart type="family">Feeney</mods:namePart><mods:namePart type="given">Angela</mods:namePart><mods:displayForm>Feeney, Angela</mods:displayForm></mods:name>',
        ouellet	=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Ouellet</mods:namePart><mods:namePart type="given">Marc</mods:namePart><mods:namePart type="date">1944-</mods:namePart><mods:displayForm>Ouellet, Marc, 1944-</mods:displayForm></mods:name>',
	   magee	=>	'<mods:name type="personal"><mods:namePart type="family">Magee</mods:namePart><mods:namePart type="given">Eddie</mods:namePart><mods:displayForm>Magee, Eddie</mods:displayForm></mods:name>',
	   duffyj	=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Duffy</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:namePart type="date">1956-</mods:namePart><mods:displayForm>Duffy, Joe, 1956-</mods:displayForm></mods:name>',
	   dunne	=>	'<mods:name type="personal"><mods:namePart type="family">Dunne</mods:namePart><mods:namePart type="given">Eileen</mods:namePart><mods:displayForm>Dunne, Eileen</mods:displayForm></mods:name>',
	   martind	=>	'<mods:name type="personal"><mods:namePart type="family">Martin</mods:namePart><mods:namePart type="given">Diarmuid</mods:namePart><mods:displayForm>Martin, Diarmuid</mods:displayForm></mods:name>',
	   benedict	=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family"></mods:namePart><mods:namePart type="given">Benedict</mods:namePart><mods:namePart type="given">XVI</mods:namePart><mods:namePart type="termsOfAddress">Pope</mods:namePart><mods:namePart type="date">1927-</mods:namePart><mods:displayForm>, Benedict (XVI), Pope, 1927-</mods:displayForm></mods:name>',
	   rogan	=>	'<mods:name type="personal"><mods:namePart type="family">Rogan</mods:namePart><mods:namePart type="given">Sean</mods:namePart><mods:displayForm>Rogan, Sean</mods:displayForm></mods:name>',
	   mcgradyf	=>	'<mods:name type="personal"><mods:namePart type="family">McGrady</mods:namePart><mods:namePart type="given">Fergal</mods:namePart><mods:displayForm>McGrady, Fergal</mods:displayForm></mods:name>',
	   ritchie	=>	'<mods:name type="personal"><mods:namePart type="family">Ritchie</mods:namePart><mods:namePart type="given">Margaret</mods:namePart><mods:displayForm>Ritchie, Margaret</mods:displayForm></mods:name>',
	   vianney	=>	'<mods:name type="personal"><mods:namePart type="family"></mods:namePart><mods:namePart type="given">Vianney</mods:namePart><mods:namePart type="termsOfAddress">Sister</mods:namePart><mods:displayForm>, Vianney, Sister</mods:displayForm></mods:name>',
	   mcconvey	=>	'<mods:name type="personal"><mods:namePart type="family">McConvey</mods:namePart><mods:namePart type="given">Eamon</mods:namePart><mods:displayForm>McConvey, Eamon</mods:displayForm></mods:name>',
	   maguire	=>	'<mods:name type="personal"><mods:namePart type="family">Maguire</mods:namePart><mods:namePart type="given">Anne</mods:namePart><mods:displayForm>Maguire, Anne</mods:displayForm></mods:name>',
	   bradys	=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Brady</mods:namePart><mods:namePart type="given">Se&#xe1;n</mods:namePart><mods:namePart type="date">1939-</mods:namePart><mods:displayForm>Brady, Se&#xe1;n, 1939-</mods:displayForm></mods:name>',
	   obrienk	=>	'<mods:name type="personal"><mods:namePart type="family">O&apos;Brien</mods:namePart><mods:namePart type="given">Keith</mods:namePart><mods:displayForm>O&apos;Brien, Keith</mods:displayForm></mods:name>',
	   palma	=>	'<mods:name type="personal"><mods:namePart type="family">Palma</mods:namePart><mods:namePart type="given">Jose</mods:namePart><mods:namePart type="given">S.</mods:namePart><mods:displayForm>Palma, Jose (S.)</mods:displayForm></mods:name>',
	   marini	=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Marini</mods:namePart><mods:namePart type="given">Piero</mods:namePart><mods:namePart type="date">1942-</mods:namePart><mods:displayForm>Marini, Piero, 1942-</mods:displayForm></mods:name>',
	   monaghan	=>	'<mods:name type="personal"><mods:namePart type="family">Monaghan</mods:namePart><mods:namePart type="given">Siobhan</mods:namePart><mods:displayForm>Monaghan, Siobhan</mods:displayForm></mods:name>',
	   hamill=>	'<mods:name type="personal"><mods:namePart type="family">Hamill</mods:namePart><mods:namePart type="given">Michael</mods:namePart><mods:displayForm>Hamill, Michael</mods:displayForm></mods:name>',
	   winters=>	'<mods:name type="personal"><mods:namePart type="family">Winters</mods:namePart><mods:namePart type="given">Billy</mods:namePart><mods:displayForm>Winters, Billy</mods:displayForm></mods:name>',
	   smith=>	'<mods:name type="personal"><mods:namePart type="family">Smith</mods:namePart><mods:namePart type="given">Joe</mods:namePart><mods:displayForm>Smith, Joe</mods:displayForm></mods:name>',
	   glennon=>	'<mods:name type="personal"><mods:namePart type="family">Glennon</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>Glennon, Paddy</mods:displayForm></mods:name>',
	   cassidy=>	'<mods:name type="personal"><mods:namePart type="family">Cassidy</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Cassidy, Jim</mods:displayForm></mods:name>',
	   boyd=>	'<mods:name type="personal"><mods:namePart type="family">Boyd</mods:namePart><mods:namePart type="given">Johnny</mods:namePart><mods:displayForm>Boyd, Johnny</mods:displayForm></mods:name>',
	   bright=>	'<mods:name type="personal"><mods:namePart type="family">Bright</mods:namePart><mods:namePart type="given">Lily</mods:namePart><mods:displayForm>Bright, Lily</mods:displayForm></mods:name>',
	   brightp=>	'<mods:name type="personal"><mods:namePart type="family">Bright</mods:namePart><mods:namePart type="given">Paddy</mods:namePart><mods:displayForm>Bright, Paddy</mods:displayForm></mods:name>',
	   hanna=>	'<mods:name type="personal"><mods:namePart type="family">Hanna</mods:namePart><mods:namePart type="given">Colman</mods:namePart><mods:displayForm>Hanna, Colman</mods:displayForm></mods:name>',
	   kinsella=>	'<mods:name type="personal"><mods:namePart type="family">Kinsella</mods:namePart><mods:namePart type="given">Patrick</mods:namePart><mods:displayForm>Kinsella, Patrick</mods:displayForm></mods:name>',
	   quinn=>	'<mods:name type="personal"><mods:namePart type="family">Quinn</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>Quinn, Gerry</mods:displayForm></mods:name>',
	   mcburneyg=>	'<mods:name type="personal"><mods:namePart type="family">McBurney</mods:namePart><mods:namePart type="given">Gerry</mods:namePart><mods:displayForm>McBurney, Gerry</mods:displayForm></mods:name>',
	   hallr=>	'<mods:name type="personal"><mods:namePart type="family">Hall</mods:namePart><mods:namePart type="given">Roy</mods:namePart><mods:displayForm>Hall, Roy</mods:displayForm></mods:name>',
	   fay=>	'<mods:name type="personal"><mods:namePart type="family">Fay</mods:namePart><mods:namePart type="given">Cell</mods:namePart><mods:displayForm>Fay, Cell</mods:displayForm></mods:name>',
	   gough=>	'<mods:name type="personal"><mods:namePart type="family">Gough</mods:namePart><mods:namePart type="given">Jim</mods:namePart><mods:displayForm>Gough, Jim</mods:displayForm></mods:name>',
	   friel=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Friel</mods:namePart><mods:namePart type="given">Brian</mods:namePart><mods:displayForm>Friel, Brian</mods:displayForm></mods:name>',
	   friela=>	'<mods:name type="personal"><mods:namePart type="family">Friel</mods:namePart><mods:namePart type="given">Anne</mods:namePart><mods:displayForm>Friel, Anne</mods:displayForm></mods:name>',
	   roche=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Roche</mods:namePart><mods:namePart type="given">Anthony</mods:namePart><mods:displayForm>Roche, Anthony</mods:displayForm></mods:name>',
	   ferriter=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Ferriter</mods:namePart><mods:namePart type="given">Diarmaid</mods:namePart><mods:namePart type="date">1972-</mods:namePart><mods:displayForm>Ferriter, Diarmaid, 1972-</mods:displayForm></mods:name>',
	   fiach=>	'<mods:name type="personal"><mods:namePart type="family">Mac Conghail</mods:namePart><mods:namePart type="given">Fiach</mods:namePart><mods:displayForm>Mac Conghail, Fiach</mods:displayForm></mods:name>',
	   reganm=>	'<mods:name type="personal"><mods:namePart type="family">Regan</mods:namePart><mods:namePart type="given">Maurice</mods:namePart><mods:displayForm>Regan, Maurice</mods:displayForm></mods:name>',
	   priorp=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Prior</mods:namePart><mods:namePart type="given">Pauline</mods:namePart><mods:displayForm>Prior, Pauline</mods:displayForm></mods:name>',
	   mansergh=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Mansergh</mods:namePart><mods:namePart type="given">Martin</mods:namePart><mods:displayForm>Mansergh, Martin</mods:displayForm></mods:name>',
	   mcclean=>	'<mods:name type="personal"><mods:namePart type="family">Mc Clean</mods:namePart><mods:namePart type="given">Paddy Joe</mods:namePart><mods:displayForm>Mc Clean, Paddy Joe</mods:displayForm></mods:name>',
	   brysona=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Bryson</mods:namePart><mods:namePart type="given">Anna</mods:namePart><mods:namePart type="date">1976-</mods:namePart><mods:displayForm>Bryson, Anna, 1976-</mods:displayForm></mods:name>',
		kinahan=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Kinahan</mods:namePart><mods:namePart type="given">Coralie</mods:namePart><mods:namePart type="date">1924-</mods:namePart><mods:displayForm>Kinahan, Coralie, 1924-</mods:displayForm></mods:name>',
		harland=>	'<mods:name type="personal"><mods:namePart type="family">Harland</mods:namePart><mods:namePart type="given">Robin</mods:namePart><mods:displayForm>Harland, Robin</mods:displayForm></mods:name>',
		baing=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Bain</mods:namePart><mods:namePart type="given">George</mods:namePart><mods:namePart type="given">Sayers</mods:namePart><mods:displayForm>Bain, George (Sayers)</mods:displayForm></mods:name>',
		stacey=>	'<mods:name type="personal"><mods:namePart type="family">Stacey</mods:namePart><mods:namePart type="given">Lawrence</mods:namePart><mods:displayForm>Stacey, Lawrence</mods:displayForm></mods:name>',
		heaneym=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">Heaney</mods:namePart><mods:namePart type="given">Marie</mods:namePart><mods:displayForm>Heaney, Marie</mods:displayForm></mods:name>',
		mclaverty=>	'<mods:name type="personal" authority="naf"><mods:namePart type="family">McLaverty</mods:namePart><mods:namePart type="given">Michael</mods:namePart><mods:displayForm>McLaverty, Michael</mods:displayForm></mods:name>',
		marks=>	'<mods:name type="personal"><mods:namePart type="family">Marks</mods:namePart><mods:namePart type="given">Colm</mods:namePart><mods:displayForm>Marks, Colm</mods:displayForm></mods:name>',
		ruane=>	'<mods:name type="personal"><mods:namePart type="family">Ruane</mods:namePart><mods:namePart type="given">Catr&#237;ona</mods:namePart><mods:displayForm>Ruane, Catr&#237;ona</mods:displayForm></mods:name>',
		abercorna=>	'<mods:name type="personal"><mods:namePart type="family">Abercorn</mods:namePart><mods:namePart type="given">Alexandra Hamilton</mods:namePart><mods:namePart type="termsOfAddress">Duchess of</mods:namePart><mods:displayForm>Abercorn, Alexandra Hamilton, Duchess of</mods:displayForm></mods:name>',



	);




	my %part_names = (
		  1 => 'Politicians and Political Activities',
		  2 => 'Religious Leaders and Activities',
		  3 => 'Bombs and Violence',
		  4 => 'Writers, Poets, Journalists and Artists',
		  5 => 'Singers and Other Entertainers', 
		  6 => 'Ordinary Life During the Troubles', 	
		  7 => 'The Travelling People',  
		  8 => 'Paramilitary Organizations',
		  9 => 'The Security Forces',					 		  
		10 => 'Seamus Heaney',
		11 => '&#201;amon De Valera',
		12 => 'Gusty Spence',
                13 => 'RUC/PSNI',
		15 => 'Brian Friel',			  
	);
	my %subseries_names = (
				'1A' => 'Original Accession 2001, 1970s-2007',
				'1B' => 'Accretions 2003, 1970s-1980s',
				'1C' => 'Accretions 2008, 1980s-2007',
				'1E' => 'Accretions 2011, 1970s-2011', 	
				'2A' => 'Original Accession 2001, 1970s-1999',
				'2E' => 'Accretions 2011, 1980s-2011',
				'2F' => 'Accretions 2012, 50th International Eucharistic Congress (June 17, 2012)',
				'3A' => 'Original Accession 2001, 1970s-1990s', 
				'4A' => 'Original Accession 2001, 1970s-1990s',
				'4B' => 'Accretions 2003, 1970s-1990s',
				'4C' => 'Accretions 2008, 1998-2007',
				'5A' => 'Original Accession 2001, 1970s-1990s',
				'6A' => 'Original Accession 2001, early 1970s-1998',	
				'6B' => 'Accretions 2003, 1970s-1990s',
				'6C' => 'Accretions 2008, 1980s-2005',
				'7A' => 'Original Accession, 1970s-1990s',
				'8A' => 'Original Accession 2001, 1970s-2001',
				'9A' => 'Original Accession, 1970s-1990s',
				'10A' => 'Original Accession 2001, 1979-1999',
				'10B' => 'Accretions 2003, 1979',
				'11A' => 'Original Accession 2002, 1970s',
				'12A' => 'Original Accession 2002, 1985-1995',
				'13A' => 'Original Accession 2008, October 2001-March 2002',
				'15A' => 'Original Accession 2011, 1996-2011',
	);
	$fh->print("<mets:dmdSec ID=\"DMD1\">\n");
	$fh->print("\t\t<mets:mdWrap MDTYPE=\"MODS\">\n");
	$fh->print("\t\t\t<mets:xmlData>\n");
	$fh->print("\t\t\t\t<mods:mods>\n");

#Assign values in first row of item to meaningful variables
	## test stuff
	##print "item start row is $item_start_row\n";
	my $first_row_of_item=$Sheet->Range("A" . $item_start_row . ":S" . $item_start_row)->{Value};





	my $row_values = $first_row_of_item->[0];
	#print "row test is $row_values\n";



	my ($finding_aid_order , $box, $folder, $sheet, $frames, $size, $process, $part, $item, $title, $notes, $dates ,$verification_work, $formatting_notes, $start_file, $end_file, $subseries, $names, $topical) = @$row_values; 
if ($process ne "digital images"){
	print "mods box is $box\n\n";
};
### 1. MODS TitleInfo Element

	$fh->print("\t\t\t\t\t<mods:titleInfo>\n");

	$title =~ s/\.\s*$//;

	##Deal with initial articles
	my $nonsort;
	if ($title =~ m/^The (.*)/) 
		{$nonsort = "The"; 
		$title=$1} 
	elsif ($title =~ m/^A (.*)/) 
		{$nonsort = "A";
		$title=$1} 
	elsif ($title =~ m /^An (.*)/) 
		{$nonsort = "An";
		$title=$1}; 
	if ($nonsort) {$fh->print ("\t\t\t\t\t\t<mods:nonSort>$nonsort <\/mods:nonSort>\n")};

	##Print title
	$fh->print ("\t\t\t\t\t\t<mods:title>$title<\/mods:title>\n");
	$fh->print("\t\t\t\t\t<\/mods:titleInfo>\n\n");

####1.A  Alternative title
		
	if ($title =~ /MEP | MLA | MP/) {

		$title =~ s/MEP/Member of the European Parliament/;
		$title =~ s/MLA/Member of the Legislative Assembly/;
		$title =~ s/MP/Member of Parliament/;

		$fh->print("\t\t\t\t\t<mods:titleInfo type=\"alternative\">\n");

		##Deal with initial articles
		my $nonsort;
		if ($title =~ m/^The (.*)/) 
			{$nonsort = "The"; 
			$title=$1} 
		elsif ($title =~ m/^A (.*)/) 
			{$nonsort = "A";
			$title=$1} 
		elsif ($title =~ m /^An (.*)/) 
			{$nonsort = "An";
			$title=$1}; 
		if ($nonsort) {$fh->print ("\t\t\t\t\t\t<mods:nonSort>$nonsort <\/mods:nonSort>\n")};

		##Print title
		$fh->print ("\t\t\t\t\t\t<mods:title>$title<\/mods:title>\n");
		$fh->print("\t\t\t\t\t<\/mods:titleInfo>\n\n");

	};

### 2. MODS Name Elements 


	#Hanvey
	$fh->print ("\t\t\t\t\t<mods:name authority=\"naf\" type=\"personal\">\n\t\t\t\t\t\t<mods:namePart type=\"family\">Hanvey<\/mods:namePart>\n\t\t\t\t\t\t<mods:namePart type=\"given\">Bobbie<\/mods:namePart>\n\t\t\t\t\t\t<mods:namePart type=\"date\">1945-<\/mods:namePart>\n\t\t\t\t\t\t<mods:displayForm>Hanvey, Bobbie, 1945-<\/mods:displayForm>\n\t\t\t\t\t\t<mods:role>\n\t\t\t\t\t\t\t<mods:roleTerm type=\"code\" authority=\"marcrelator\">pht<\/mods:roleTerm>\n\t\t\t\t\t\t\t<mods:roleTerm type=\"text\" authority=\"marcrelator\">Photographer<\/mods:roleTerm>\n\t\t\t\t\t\t<\/mods:role>\n\t\t\t\t\t<\/mods:name>\n\n");

	#Burns Library
	$fh->print ("\t\t\t\t\t<mods:name authority=\"naf\" type=\"corporate\">\n\t\t\t\t\t\t<mods:namePart>Boston College<\/mods:namePart>\n\t\t\t\t\t\t<mods:namePart>John J. Burns Library<\/mods:namePart>\n\t\t\t\t\t\t<mods:displayForm>Boston College. John J. Burns Library<\/mods:displayForm>\n\t\t\t\t\t\t<mods:role>\n\t\t\t\t\t\t\t<mods:roleTerm type=\"code\" authority=\"marcrelator\">own<\/mods:roleTerm>\n\t\t\t\t\t\t\t<mods:roleTerm type=\"text\" authority=\"marcrelator\">Owner<\/mods:roleTerm>\n\t\t\t\t\t\t<\/mods:role>\n\t\t\t\t\t<\/mods:name>\n\n");

### 3. MODS TypeOfResource Element

	$fh->print("\t\t\t\t\t<mods:typeOfResource>still image<\/mods:typeOfResource>\n\n");

### 4. MODS Genre Element
	my $genre;
	my $aat_term;

	for my $i ($item_start_row..$item_end_row) {
		if ($i eq $item_start_row) {
			$genre=$process;
			$aat_term=aat($genre);
			$fh->print("\t\t\t\t\t<mods:genre authority=\"aat\" type=\"workType\">$aat_term<\/mods:genre>\n\n");
		}
		else {
			$genre = $Sheet->Range("G" . $i)->{Value};
			if ($genre ne $process) {
				$aat_term=aat($genre);
				$fh->print("\t\t\t\t\t<mods:genre authority=\"aat\" type=\"workType\">$aat_term<\/mods:genre>\n\n");
				$process=$genre;
			}
		};
		$i++;
	};

### 5. MODS OriginInfo Element

    my %month_conversions = (
        'January' => '01',
        'February' => '02',
        'March' => '03',
        'April' => '04',
        'May' => '05',
        'June' => '06',
        'July' => '07',
        'August' => '08',
        'September' => '09',
        'October' => '10',
        'November' => '11',
        'December' => '12',
        );
    
	$fh->print("\t\t\t\t\t<mods:originInfo>\n");
	$fh->print("\t\t\t\t\t\t<mods:dateCreated>$dates<\/mods:dateCreated>\n");
	
	#date is a specific day (two-digit day)
	if ($dates =~ m/^(\d{1,2})\s(January|February|March|April|May|June|July|August|September|October|November|December)\s(\d{4})/) {
	   my $firstdigit= $month_conversions{$2};
	   my $seconddigit= sprintf("%02d", $1);
	   my $thirddigit= $3;      
	   $fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\">$thirddigit-$firstdigit-$seconddigit<\/mods:dateCreated>\n");
	}
	
    #date is October 2001-March 2002
	elsif ($dates =~ m/^October 2001-March 2002$/) {
		my $start_point= "2001-10"; 
		my $end_point= "2002-03"; 
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" qualifier=\"approximate\" point=\"start\">$start_point<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" qualifier=\"approximate\" point=\"end\">$end_point<\/mods:dateCreated>\n");
	}
	
	#single date
	elsif ($dates =~ m/^\d{4}$/) {
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\">$dates<\/mods:dateCreated>\n");
	}

	#date with month
	elsif ($dates =~ m/(January|February|March|April|May|June|July|August|September|October|November|December) (\d{4})$/) {
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\">$2<\/mods:dateCreated>\n");
	}

	#date is a decade: 1980s
	elsif ($dates =~ m/^\d{3}0s$/) {
		$dates =~ m/^\d{3}/;
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" qualifier=\"approximate\" point=\"start\">$&0<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" qualifier=\"approximate\" point=\"end\">$&9<\/mods:dateCreated>\n");
	}
	#date is a list: 1996, 2000
	elsif ($dates =~ m/^(\d{4}),\s(\d{4})$/) {
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" point=\"start\">$1<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" point=\"end\">$2<\/mods:dateCreated>\n");
	}
	#date is a middle of a decade: mid-1980s
	elsif ($dates =~ m/^mid-(\d{3})\ds$/) {
		my $start_point=join "", $1, "3"; 
		my $end_point=join "", $1, "6"; 
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" qualifier=\"approximate\" point=\"start\">$start_point<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" qualifier=\"approximate\" point=\"end\">$end_point<\/mods:dateCreated>\n");
	}
	#date is the beginning of a decade:  early 1980s
	elsif ($dates =~ m/^early\s(\d{3})\ds$/) {
		my $start_point=join "", $1, "0"; 
		my $end_point=join "", $1, "4"; 
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" qualifier=\"approximate\" point=\"start\">$start_point<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" qualifier=\"approximate\" point=\"end\">$end_point<\/mods:dateCreated>\n");
	}

	#date is the end of a decade:  late 1980s
	elsif ($dates =~ m/^late\s(\d{3})\ds$/) {
		my $start_point=join "", $1, "6"; 
		my $end_point=join "", $1, "9"; 
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" keyDate=\"yes\" qualifier=\"approximate\" point=\"start\">$start_point<\/mods:dateCreated>\n");
		$fh->print("\t\t\t\t\t\t<mods:dateCreated encoding=\"w3cdtf\" qualifier=\"approximate\" point=\"end\">$end_point<\/mods:dateCreated>\n");
	}

	$fh->print("\t\t\t\t\t\t<mods:issuance>monographic<\/mods:issuance>\n");
	$fh->print("\t\t\t\t\t<\/mods:originInfo>\n\n");

### 6.  MODS Language Element

	$fh->print("\t\t\t\t\t<mods:language>\n\t\t\t\t\t\t<mods:languageTerm type=\"text\">Not applicable<\/mods:languageTerm>\n\t\t\t\t\t\t<mods:languageTerm type=\"code\" authority=\"iso639-2b\">zxx<\/mods:languageTerm>\n\t\t\t\t\t<\/mods:language>\n\n");


### 7. MODS Physical Description

	$fh->print("\t\t\t\t\t<mods:physicalDescription>\n");
	$fh->print("\t\t\t\t\t\t<mods:form authority=\"marcform\">electronic<\/mods:form>\n");
	$fh->print("\t\t\t\t\t\t<mods:internetMediaType>image/jp2<\/mods:internetMediaType>\n");
	$fh->print("\t\t\t\t\t\t<mods:internetMediaType>image/jpeg<\/mods:internetMediaType>\n");
	$fh->print("\t\t\t\t\t\t<mods:internetMediaType>image/tif<\/mods:internetMediaType>\n");

	my $count=0;
	my $previous=0;



	for my $i ($item_start_row..$item_end_row) {
		if ($i eq $item_start_row) {$previous = $item_start_row;$count=$frames} else {$previous = $i-1};
		#print "item start row: $item_start_row; previous: $previous; i:$i\n";


		if ($Sheet->Range("G" . $i)->{Value} eq $Sheet->Range("G" . $previous)->{Value} && $Sheet->Range("F" . $i)->{Value} eq $Sheet->Range("F" . $previous)->{Value}) {
			#Process and size match!!!!!!!!!

			if ($i ne $item_start_row){$count=$count+$Sheet->Range("E" . $i)->{Value}}

		}
		else {
			#Process and size don't match
			$genre=$Sheet->Range("G" . $previous)->{Value};
			$aat_term=aat($genre);
			
			$fh->print("\t\t\t\t\t\t<mods:extent>$count $aat_term (" . $Sheet->Range("F" . $previous)->{Value} .")<\/mods:extent>\n");
			$count=$Sheet->Range("E" . $i)->{Value};
		}
		if ($i eq $item_end_row) {
			print "i've reached the end of the item\n";
			$genre=$Sheet->Range("G" . $i)->{Value};
			$aat_term=aat($genre);
			if ($count == 1) {
			$aat_term =~ s/s$//;
			}
			if ($genre eq "digital images") 
				{
					$fh->print("\t\t\t\t\t\t<mods:extent>$count $aat_term<\/mods:extent>\n");
					$fh->print("\t\t\t\t\t\t<mods:digitalOrigin>born digital<\/mods:digitalOrigin>\n");
				}
			else 
				{
					$fh->print("\t\t\t\t\t\t<mods:extent>$count $aat_term (" . $Sheet->Range("F" . $i)->{Value} .")<\/mods:extent>\n");
					$fh->print("\t\t\t\t\t\t<mods:digitalOrigin>reformatted digital<\/mods:digitalOrigin>\n");
				}
			$count=0;
		}
		$i++;
	};
	
	

	$fh->print("\t\t\t\t\t<\/mods:physicalDescription>\n\n");
	
### 11. MODS Note 
	$fh->print("\t\t\t\t\t<mods:note>Title based on entry in photographer's inventory.<\/mods:note>\n");
	for my $i ($item_start_row..$item_end_row) {
		if ($Sheet->Range("K" . $i)->{Value}) {
			my $note=$Sheet->Range("K" . $i)->{Value};
			$fh->print("\t\t\t\t\t<mods:note>".ucfirst($note)."<\/mods:note>\n");
		}
		$i++;
	};

###12. MODS Subject



	if (($part eq '1' || $part eq '4' || $part eq '10' || $part eq '2' || $part eq '6' || $part eq '1' || $part eq '5' || $part eq '8' || $part eq '9' || $part eq '13' || $part eq '12' || $part eq '11' || $part eq '15' ) && $names) {
###names
		
		my @names = split(/\s*,\s*/, $names);
		#print "@names\n";
		foreach my $names(@names){
			$fh->print("\t\t\t\t\t<mods:subject authority=\"lcsh\">\n");
			$fh->print("\t\t\t\t\t\t".$subj_names{lc($names)}."\n");
			$fh->print("\t\t\t\t\t\t<mods:genre>Photographs<\/mods:genre>\n");
			$fh->print("\t\t\t\t\t<\/mods:subject>\n");
		
		}
	}
	#print "i'm at subject\n";
	if (($part eq '4' || $part eq '10' || $part eq '5' || $part eq '15') && $topical) {
###topical	
		# "topical is $topical\n";
		my @topical = split(/\s*,\s*/, $topical);
		
	
		foreach my $topical(@topical){
			
		

			$fh->print("\t\t\t\t\t".$subj_topical{lc($topical)}."\n");
		}
	};
	#print "i'm at subject\n";




###abbreviations

	if ($title =~ m/\sPSNI/ && $part eq '1') {
      	$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Police Service of Northern Ireland<\/mods:namePart><mods:displayForm>Police Service of Northern Ireland<\/mods:displayForm><\/mods:name>   <mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sFAIT/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Families Against Intimidation and Terror<\/mods:namePart><mods:displayForm>Families Against Intimidation and Terror<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sPUP\s/ || $title =~ m/\(PUP\)/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Progressive Unionist Party<\/mods:namePart><mods:displayForm>Progressive Unionist Party<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUDF\s/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Defence Association<\/mods:namePart><mods:displayForm>Ulster Defence Association<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUDP/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Democratic Party<\/mods:namePart><mods:displayForm>Ulster Democratic Party<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUFF/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Freedom Fighters<\/mods:namePart><mods:displayForm>Ulster Freedom Fighters<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUUP/ || $title =~ m/\(UUP/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Unionist Party<\/mods:namePart><mods:displayForm>Ulster Unionist Party<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUTV/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Television<\/mods:namePart><mods:displayForm>Ulster Television<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/\sUVF/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Volunteer Force<\/mods:namePart><mods:displayForm>Ulster Volunteer Force<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};
=cut
	if ($title =~ m/\sRTE/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Radio Telefi�s E�ireann<\/mods:namePart><mods:displayForm>Radio Telefi�s E�ireann<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};
=cut
	if ($title =~ m/\sWP/) {
		$fh->print("<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Workers' Party (Ireland)<\/mods:namePart><mods:displayForm>Workers' Party (Ireland)<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>");
		$fh->print("\n");};

	if ($title =~ m/DUP/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Democratic Unionist Party (Northern Ireland)<\/mods:namePart><mods:displayForm>Democratic Unionist Party (Northern Ireland)<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/GAA|G\.A\.A\./) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Gaelic Athletic Association<\/mods:namePart><mods:displayForm>Gaelic Athletic Association<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};
#comment out the above IF generating METS for Part 2F
	if ($title =~ m/INLA/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Irish National Liberation Army<\/mods:namePart><mods:displayForm>Irish National Liberation Army<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/\WIRA/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Irish Republican Army<\/mods:namePart><mods:displayForm>Irish Republican Army<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};


	if ($title =~ m/PIRA/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Provisional IRA<\/mods:namePart><mods:displayForm>Provisional IRA<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/RUC/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Royal Ulster Constabulary<\/mods:namePart><mods:displayForm>Royal Ulster Constabulary<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/Sinn Fein/ || $title =~ m/\(SF\)/ ) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Sinn Fein<\/mods:namePart><mods:displayForm>Sinn Fein<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/SAS/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Great Britain<\/mods:namePart><mods:namePart>Army<\/mods:namePart><mods:namePart>Special Air Service<\/mods:namePart><mods:displayForm>Great Britain. Army. Special Air Service<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};


	if ($title =~ m/SDLP/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Social Democratic and Labour Party (Northern Ireland)<\/mods:namePart><mods:displayForm>Social Democratic and Labour Party (Northern Ireland)<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};
	
	if ($title =~ m/UDR/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Great Britain<\/mods:namePart><mods:namePart>Army<\/mods:namePart><mods:namePart>Ulster Defence Regiment<\/mods:namePart><mods:displayForm>Great Britain. Army. Ulster Defence Regiment<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/Orange/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Orangemen<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n")};

	if ($title =~ m/Apprentice Boy/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Apprentice Boys of Derry<\/mods:namePart><mods:displayForm>Apprentice Boys of Derry<\/mods:displayForm><\/mods:name><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Orangemen<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n")};

	if ($title =~ m/UDA/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Ulster Defence Association<\/mods:namePart><mods:displayForm>Ulster Defence Association<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/RSF/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Republican Sinn F&#xe9;in<\/mods:namePart><mods:displayForm>Republican Sinn Fe&#xe9;in<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};

	if ($title =~ m/Cumann na mBan/) {$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Cumann na mBan<\/mods:namePart><mods:displayForm>Cumann na mBan<\/mods:displayForm><\/mods:name><\/mods:subject>\n")};


	if ($part eq '1' || $part eq '1 Additional 2003') {
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:geographic>Northern Ireland</mods:geographic><mods:topic>Politics and government</mods:topic><mods:genre>Photographs</mods:genre></mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Politicians<\/mods:topic>  <mods:geographic>Northern Ireland<\/mods:geographic><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");


		}

if ($part eq '11') {
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Death and burial</mods:topic></mods:subject>\n");
}

	if ($part eq '2') {
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:geographic>Northern Ireland</mods:geographic><mods:topic>Religious life and customs</mods:topic><mods:genre>Photographs</mods:genre></mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Photojournalism</mods:topic><mods:geographic>Northern Ireland</mods:geographic></mods:subject>\n");
    #Only one used for Subseries F  listed below -- comment out above subjects when generating METS for Part 2F###    
      #  $fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:name authority=\"naf\" type=\"conference\"><mods:namePart>International Eucharistic Congress (50th : 2012 : Dublin, Ireland)</mods:namePart></mods:name><mods:genre>Photographs</mods:genre></mods:subject>\n");
		}
	if ($part eq '8') {
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Paramilitary forces<\/mods:topic><mods:geographic>Northern Ireland</mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Social conflict<\/mods:topic><mods:geographic>Northern Ireland</mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Photojournalism<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><\/mods:subject>\n");

		}


    if ($part eq '12') {
        $fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Paramilitary forces<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n")
        }

	if ($part eq '3') {
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Social conflict<\/mods:topic><mods:geographic>Northern Ireland</mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Political violence<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:geographic>Northern Ireland<\/mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>1969-1994<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Photojournalism<\/mods:topic><mods:geographic>Northern Ireland<\/mods:geographic><\/mods:subject>\n");
		}

	if ($part eq '4' || $part eq '10'|| $part eq '5' || $part eq '12' || $part eq '15') {
###generic

		$fh->print("\t\t\t\t\t<mods:subject authority=\"lcsh\">\n");
		$fh->print("\t\t\t\t\t\t<mods:topic>Portrait photography<\/mods:topic>\n");
		$fh->print("\t\t\t\t\t\t<mods:geographic>Northern Ireland<\/mods:geographic>\n");
		$fh->print("\t\t\t\t\t<\/mods:subject>\n"); 
	};

	if ($part eq '6') {
		$fh->print("					<mods:subject authority=\"lcsh\">
     						<mods:geographic>Northern Ireland<\/mods:geographic>
					     <mods:topic>Social life and customs<\/mods:topic>
     						<mods:genre>Photographs<\/mods:genre>
					<\/mods:subject>\n");
				}



	if ($part eq '7') {
		

		$fh->print("					<mods:subject authority=\"lcsh\">
     						<mods:topic>Irish Travellers (Nomadic people)<\/mods:topic>
     						<mods:geographic>Northern Ireland<\/mods:geographic>
     						<mods:genre>Photographs<\/mods:genre>
					<\/mods:subject>

					<mods:subject authority=\"lcsh\">
					     <mods:topic>Children of nomads<\/mods:topic>
					     <mods:geographic>Northern Ireland<\/mods:geographic>
					     <mods:genre>Photographs<\/mods:genre>
					<\/mods:subject>

					<mods:subject authority=\"lcsh\">
					     <mods:topic>Irish Travellers (Nomadic people)<\/mods:topic>
					     <mods:topic>Social life and customs<\/mods:topic>
					     <mods:temporal>20th century<\/mods:temporal>
					     <mods:genre>Photographs<\/mods:genre>
					<\/mods:subject>

					<mods:subject authority=\"lcsh\">
					     <mods:topic>Photojournalism<\/mods:topic>
					     <mods:geographic>Northern Ireland<\/mods:geographic> 
					<\/mods:subject>\n");

	}
	if ($part eq '9') 
	{
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:geographic>Northern Ireland</mods:geographic><mods:topic>Politics and government</mods:topic><mods:genre>Photographs</mods:genre></mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Photojournalism</mods:topic><mods:geographic>Northern Ireland</mods:geographic></mods:subject>\n");
		$fh->print("\t\t\t\t\t\t<mods:subject authority=\"lcsh\"><mods:topic>Social conflict<\/mods:topic><mods:geographic>Northern Ireland</mods:geographic><mods:topic>History<\/mods:topic><mods:temporal>20th century<\/mods:temporal><mods:genre>Photographs<\/mods:genre><\/mods:subject>\n");

	}
	if ($part eq '13')
	{
	   $fh->print("
                   	<mods:subject authority=\"lcsh\">
                           <mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Royal Ulster Constabulary<\/mods:namePart><mods:displayForm>Royal Ulster Constabulary<\/mods:displayForm><\/mods:name>
                           <mods:genre>Photographs<\/mods:genre>
                       <\/mods:subject>
                   
                       <mods:subject authority=\"lcsh\">
                           <mods:name type=\"corporate\" authority=\"naf\"><mods:namePart>Police Service of Northern Ireland<\/mods:namePart><mods:displayForm>Police Service of Northern Ireland<\/mods:displayForm><\/mods:name>   
                           <mods:genre>Photographs<\/mods:genre>
                       <\/mods:subject>
                   
                       <mods:subject authority=\"lcsh\">
                             <mods:topic>Police stations<\/mods:topic>
                             <mods:geographic>Northern Ireland<\/mods:geographic>
                             <mods:genre>Photographs<\/mods:genre>
                       <\/mods:subject>
                       
                       <mods:subject authority=\"lcsh\">
                              <mods:topic>Photojournalism<\/mods:topic>
                              <mods:geographic>Northern Ireland<\/mods:geographic>
                       <\/mods:subject>
                  ");
                  }
    

### 14. MODS RelatedItem element

	$fh->print("\t\t\t\t\t<mods:relatedItem type=\"host\">\n");
	$fh->print("\t\t\t\t\t\t<mods:titleInfo>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:title>Bobbie Hanvey Photographic Archives<\/mods:title>\n");
	$fh->print("\t\t\t\t\t\t<\/mods:titleInfo>\n");
	$fh->print("\t\t\t\t\t<mods:part>\n");
	#detail level one
	$fh->print("\t\t\t\t\t\t<mods:detail type=\"series\" level=\"1\">\n");
	$fh->print("\t\t\t\t\t\t\t<mods:caption>Series</mods:caption>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:number>$part</mods:number>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:title>$part_names{$part}</mods:title>\n");
	$fh->print("\t\t\t\t\t\t<\/mods:detail>\n");
	#detail level two
	$fh->print("\t\t\t\t\t\t<mods:detail type=\"subseries\" level=\"2\">\n");
	$fh->print("\t\t\t\t\t\t\t<mods:caption>Subseries</mods:caption>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:number>$subseries</mods:number>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:title>$subseries_names{join('', $part,$subseries)}</mods:title>\n");
	$fh->print("\t\t\t\t\t\t<\/mods:detail>\n");
	#detail level three
	$fh->print("\t\t\t\t\t\t<mods:detail type=\"subseries\" level=\"3\">\n");
	$fh->print("\t\t\t\t\t\t\t<mods:caption>Item</mods:caption>\n");
	$fh->print("\t\t\t\t\t\t\t<mods:number>$item</mods:number>\n");
	$fh->print("\t\t\t\t\t\t<\/mods:detail>\n");
	$fh->print("\t\t\t\t\t\t<\/mods:part>\n");
	$fh->print("\t\t\t\t\t<\/mods:relatedItem>\n");


### 15. MODS Identifier
	$fh->print("\t\t\t\t\t<mods:identifier type=\"local\">(Hanvey)$obj_id<\/mods:identifier>\n");

### 16. MODS Location Element

	if ($genre ne "digital images") {
	my %boxes;
	for my $i ($item_start_row..$item_end_row) {
 		if ($i eq $item_start_row) {	
			push(@{$boxes{$Sheet->Range("B" . $i)->{Value}}}, $Sheet->Range("C" . $i)->{Value});}
		my $previous = $i-1;
		if ($i ne $item_start_row && $Sheet->Range("C" . $i)->{Value} ne $Sheet->Range("C" . $previous)->{Value}) {
			push(@{$boxes{$Sheet->Range("B" . $i)->{Value}}}, $Sheet->Range("C" . $i)->{Value});
		}
		$i++;
	};

	$fh->print("\t\t\t\t\t<mods:location>\n");	
	$fh->print("\t\t\t\t\t<mods:physicalLocation type=\"Location of original\">Boston College, John J. Burns Library, Bobbie Hanvey Photographic Archives: ");
	
	my $m=1;
	foreach my $k (sort(keys %boxes)) {
		my $length=@{$boxes{$k}};	
		if ($length eq 1 && $m eq 1){$fh->print("Box $k, Folder ");}
		if ($length eq 1 && $m ne 1){$fh->print("; Box $k, Folder ");}
		if ($length ne 1 && $m ne 1) {$fh->print("; Box $k, Folders ")}
		foreach (@{$boxes{$k}}) {
			if ($length eq 1) {$fh->print("$_");}
			else {$fh->print(shift(@{$boxes{$k}}).'-'. pop(@{$boxes{$k}}));}
	
   		}
	$m++;
	}
	$fh->print(".<\/mods:physicalLocation>");
	$fh->print("\t\t\t\t\t<\/mods:location>\n");
};
### 17. MODS Access Condition
	$fh->print("\t\t\t\t\t<mods:accessCondition type=\"useAndReproduction\">The Bobbie Hanvey Photographic Archives are licensed under a Creative Commons Attribution-Noncommercial-No Derivative Works 3.0 United States License. Citations should credit the Bobbie Hanvey Photographic Archives, John J. Burns Library, Boston College. Requests for high quality reproductions and permissions beyond the scope of this license should be submitted in writing to the Burns Librarian via e-mail (burnsref\@bc.edu) or via mail (John J. Burns Library, Boston College, 140 Commonwealth Avenue, Chestnut Hill, MA 02467-3801).<\/mods:accessCondition>\n");
	
### 20. MODS RecordInfo Element

	$fh->print("\t\t\t\t\t<mods:recordInfo>\n");	
	$fh->print("\t\t\t\t\t\t<mods:languageOfCataloging>\n\t\t\t\t\t\t\t<mods:languageTerm type=\"text\">English<\/mods:languageTerm>\n\t\t\t\t\t\t\t<mods:languageTerm type=\"code\" authority=\"iso639-2b\">eng<\/mods:languageTerm>\n\t\t\t\t\t\t<\/mods:languageOfCataloging>\n");
	$fh->print("\t\t\t\t\t\t<mods:recordContentSource>MChB<\/mods:recordContentSource>\n");
	$fh->print("\t\t\t\t\t<\/mods:recordInfo>\n");

### Close MODS Record
	$fh->print("\t\t\t\t<\/mods:mods>\n");
	$fh->print("\t\t\t<\/mets:xmlData>\n");
	$fh->print("\t\t<\/mets:mdWrap>\n");
	$fh->print("\t<\/mets:dmdSec>\n");
};

##########
sub aat {
##########
	my $genre=shift;
	my $aat_term;
	$genre =~ s/BW/black-and-white negatives/;
	$genre =~ s/CN/color negatives/;
	$genre =~ s/CP/color transparencies/;
	$aat_term=$genre;
	return $aat_term;
};



###########
sub metsOpening {
############
	my $item_start_row=shift;
	my $fh = shift;
	my $obj_id=shift;
	my $label=$Sheet->Range("J" . $item_start_row)->{Value};
	$label =~ s/"/&#x22;/g;


	$fh->print("<?xml version='1.0' encoding='UTF-8' ?>\n");
	$fh->print("<mets:mets OBJID=\"ar.hanvey.$obj_id\" LABEL=\"$label\" TYPE=\"photographs\" 
	xmlns:mets=\"http://www.loc.gov/METS/\"
    	xmlns:mods=\"http://www.loc.gov/mods/v3\" 	
    	xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"
    	xsi:schemaLocation=\"http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd\">
\n");
	my ($sec,$min,$hour,$mday,$mon,$yr,$wday,$yday,$isdst)=localtime();
	$fh->print("<mets:metsHdr CREATEDATE=\"".($yr+1900)."-".sprintf("%02d",$mon+1)."-".sprintf("%02d",$mday)."T".sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec)."\">\n");
	$fh->print("\t<mets:agent ROLE=\"CREATOR\" TYPE=\"ORGANIZATION\">\n");
	$fh->print("\t\t<mets:name>Boston College, University Libraries, Systems Office<\/mets:name>\n");
	$fh->print("\t<\/mets:agent>\n");
	$fh->print("<\/mets:metsHdr>\n");
};

#########
sub fileGroup {
#########
	my $fh=shift;
	my $type=shift;
	my $item_start_row=shift;
	my $item_end_row=shift;
	my $count=1;

	my %mime = (
			jpeg => [ 'reference image', 'jpg', 'image/jpeg', ],
    			jp2 => [ 'reference image dynamic', 'jp2', 'image/jp2', ],
    			tiff => [ 'archive', 'tif', 'image/tiff', ],
	);



	$fh->print("\t\t<mets:fileGrp USE=\"@{$mime{$type}}[0]\">\n");
	foreach my $i ($item_start_row..$item_end_row) {
		foreach my $j ($Sheet->Range("O" . $i)->{Value}..$Sheet->Range("P" . $i)->{Value}){
		$fh->print("\t\t\t<mets:file ID=\"@{$mime{$type}}[1]".sprintf("%05d", $count)."\" MIMETYPE=\"@{$mime{$type}}[2]\" GROUPID=\"GID".$count."\" SEQ=\"$count\">\n");
			$fh->print("\t\t\t\t<mets:FLocat xlink:href=\"file://streams/bh".sprintf("%06d",$j)."\.@{$mime{$type}}[1] \" LOCTYPE=\"URL\"\/>\n"); 
			$fh->print("\t\t\t<\/mets:file>\n");
			$j++;
			
			$count++;
		}
		$i++;
	}
		$fh->print("\t\t<\/mets:fileGrp>\n");			

};

#########
sub metsClosing{ 
	my $fh = shift;
	$fh->print("<\/mets:mets>\n");
};
########



sub structMap {
	my $fh = shift;
	my $item_start_row=shift;
	my $item_end_row=shift;
	my $div=1;
	my $fptr=1;
	my $div2=1;
	my $genre;
	my $aat_term;




	for my $i ($item_start_row..$item_end_row) {

		

###first row of item
		if ($i eq $item_start_row){
			#$fh->print("first loop i is $i\n");
			$genre=$Sheet->Range("G" . $i)->{Value};
			$aat_term=aat($genre);
	       if ($genre eq "digital images") {
	       $fh->print("\t\t\t<mets:div TYPE=\"process\" LABEL=\"".$aat_term."\" ORDER=\"".$div2."\">\n");
	       }
	       else {
			$fh->print("\t\t\t<mets:div TYPE=\"process\" LABEL=\"".$aat_term." (".$Sheet->Range("F" . $i)->{Value}.")\" ORDER=\"".$div2."\">\n"); }
			#$div++;
			$div2++;
			for my $j ($Sheet->Range("O" . $i)->{Value}..$Sheet->Range("P" . $i)->{Value}){
				#$fh->print("\t\t\t\t<mets:div TYPE=\"image\" LABEL=\"bh".sprintf("%02d",$Sheet->Range("H" . $i)->{Value}). $Sheet->Range("Q" . $item_start_row)->{Value} .sprintf("%03d",$image_id)."\" ORDER=\"".$div."\">\n");
				$fh->print("\t\t\t\t<mets:div TYPE=\"image\" LABEL=\"bh".sprintf("%06d",$j)."\" ORDER=\"".$div."\">\n");
				$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"tif".sprintf("%05d",$fptr)."\"\/>\n");
				$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"jp2".sprintf("%05d",$fptr)."\"\/>\n");
				$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"jpg".sprintf("%05d",$fptr)."\"\/>\n");
				$fptr++;

				$image_id++;
				$fh->print("\t\t\t\t<\/mets:div>\n");
				$j++;
				$div++;
				
			}
		}
		

#########end of first row of item
#########start of subsequent rows
		if ($i ne $item_start_row){
			if ($Sheet->Range("F" . $i)->{Value} ne $Sheet->Range("F" . ($i-1))->{Value} || $Sheet->Range("G" . $i)->{Value} ne $Sheet->Range("G" . ($i-1))->{Value}){
				$fh->print("\t\t\t<\/mets:div>\n");
				$genre=$Sheet->Range("G" . $i)->{Value};
				$aat_term=aat($genre);
				$fh->print("\t\t\t<mets:div TYPE=\"process\" LABEL=\"".$aat_term." (".$Sheet->Range("F" . $i)->{Value}.")\" ORDER=\"".$div2."\">\n");
				$div++;
				$div2++;
				$div=1;

 			}
			
			#$fh->print("i is $i\n");
			#$fh->print($Sheet->Range("G" . $i)->{Value});

			
				for my $j ($Sheet->Range("O" . $i)->{Value}..$Sheet->Range("P" . $i)->{Value}){
					#$fh->print("\t\t\t\t<mets:div TYPE=\"image\" LABEL=\"bh".sprintf("%02d",$Sheet->Range("H" . $i)->{Value}). $Sheet->Range("Q" . $item_start_row)->{Value} .sprintf("%03d",$image_id)."\" ORDER=\"".$div."\">\n");
					$fh->print("\t\t\t\t<mets:div TYPE=\"image\" LABEL=\"bh".sprintf("%06d",$j)."\" ORDER=\"".$div."\">\n");

					$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"tif".sprintf("%05d",$fptr)."\"\/>\n");
					$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"jp2".sprintf("%05d",$fptr)."\"\/>\n");
					$fh->print("\t\t\t\t\t<mets:fptr FILEID=\"jpg".sprintf("%05d",$fptr)."\"\/>\n");

					$fptr++;

					$image_id++;
					$fh->print("\t\t\t\t<\/mets:div>\n");
					$j++;
					$div++;
			}










		}
#########end of subsequent rows
		$i++;
	}

	$fh->print("\t\t\t<\/mets:div>\n");
};
