#!/usr/bin/perl -w
   
use strict;
use Win32::OLE;
use FileHandle;
use Cwd;


main();

sub main {

	my $xlsFile = shift @ARGV;
	(my $xmlout = $xlsFile) =~ s/\.xlsx/\.txt/;
print "output file is $xmlout\n";
print "excel file is $xlsFile\n";
	my $dir= getcwd;
	$dir=~s/\//\\/g;
	print "dir is $dir\n";
	$xlsFile=$dir."//".$xlsFile;

	my $excel = Win32::OLE->GetActiveObject('Excel.Application') ||
	   Win32::OLE->new('Excel.Application');
 	my $workbook = $excel->Workbooks->Open($xlsFile);   
	my $sheet = $workbook->Worksheets("BHanveyNames");

	#ShowObjs($excel);

	my $outputFH = new FileHandle;
	$outputFH->open("> $xmlout"); 
		binmode($outputFH, ':utf8');

	

	my $everything = $sheet->UsedRange()->{Value};

	$outputFH->print("\tmy %subj_names=\(\n");

	foreach my $row (@$everything) {
   	my ($ID,$shortname,$naf,$family,$given,$given2,$title,$year) = @$row;
			

		unicode(\$family)
			if ($family =~ /\xb4|\xa8/);
		unicode(\$given)
			if ($given =~ /\xb4|\xa8/);
		if ($given2) {
			unicode(\$given2)
				if ($given2 =~ /\xb4|\xa8/);

		}

		###Betsy lowercases the shortname
		$shortname=lc($shortname);
		$shortname =~ s/[' \s -]//i;

		
		###Betsy done lowercasing
			
		unless ($ID eq 'ID') {
			$outputFH->print("\t\t" .$shortname . "=>	\'");
			

			if ($naf) {
				print $outputFH '<mods:name type="personal" authority="naf">';
				}
			else {print $outputFH '<mods:name type="personal">'}


			print $outputFH '<mods:namePart type="family">' . $family . '</mods:namePart>';
			print $outputFH '<mods:namePart type="given">'. $given . '</mods:namePart>';

			print $outputFH '<mods:namePart type="given">'. $given2 . '</mods:namePart>'
				if ($given2);

			print $outputFH '<mods:namePart type="termsOfAddress">'. $title . '</mods:namePart>'
				if ($title);

			if ( $year ) {
				print $outputFH '<mods:namePart type="date">' . $year . '</mods:namePart>';
			}

			print $outputFH '<mods:displayForm>' . $family . ', ' . $given;
			
			print $outputFH ' (' . $given2 . ')'
				if ($given2);

			print $outputFH ', ' .  $title 
				if ($title);

			print $outputFH ', ' .  $year 
				if ($year);

			print $outputFH '</mods:displayForm>';
			print $outputFH "</mods:name>\',\n";

		}
   }

	$excel->Quit;  	

	$outputFH->print("\t\n\)");
	$outputFH->close();

}

####################################################
sub unicode {

	my $string = shift;

	$$string =~ s/\x69\xb4/\&#xed\;/;
	$$string =~ s/\x61\xb4/\&#xe1\;/;
	$$string =~ s/\x6f\xa8/\&#xf6\;/;

}
##################################################
sub ShowObjs {

my $obj = shift;

foreach (sort keys %$obj) {
print "Keys: $_ - $obj->{$_}\n"; }

}