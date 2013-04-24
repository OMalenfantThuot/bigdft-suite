#!/usr/bin/perl

#print $file1;
$tol=0.001;

#Program to compare 2 .wout files
if( @ARGV <  1 ) {
    ARGVerror();
}

$file=$ARGV[0];



open TEMP, "<$file" or die "Opening '$file': $!\n";
$iline=0;

while ($line = <TEMP>){
 $iline=$iline+1;
 if($line=~/\s*module/){
   print "!$line";
 }
 elsif($line=~/\s*end\s*module/){
   print "!$line";
 }
 elsif($line=~/\s*public/){
   print "!$line";
 }
 elsif($line=~/\s*use\s*m_errors/){
   print "!$line";
 }
 elsif($line=~/\s*#include\s*\"config.h\"/){
   print "\#include \"config.inc\"\n";
 }
 elsif($line=~/\s*#include\s*\"abi_common.h\"/){
   print "use interfaces\_16\_hideleave\n";
 }
 elsif($line=~/\s*write\s*\(\s*6/){
   $tmp="write";
   $index=index($line, $tmp);
   $s1=substr($line,0,$index+5);
   $s2=substr($line,$index+5); 
   $tmp="(";
   $index=index($s2,$tmp);
   $s3=substr($s2,0,$index+1);
   $s4=substr($s2,$index+1);
   $tmp="6";
   $index=index($s4,$tmp);
   $s5=substr($s4,0,$index+1);
   $s6=substr($s4,$index+1);
   $line2=$s1."( std_out".$s6;
   print $line2;  
 }
 elsif(($line=~/MSG_ERROR\s*\(/)||($line=~/MSG_BUG\s*\(/)){
   if($line=~/MSG_ERROR\s*\(/){$tmp="MSG_ERROR";}
   if($line=~/MSG_BUG\s*\(/){$tmp="MSG_BUG";}
   $l=length($tmp);
   #print $line;
   $index=index($line, $tmp);
   $s0=substr($line,0,$index);
   $s1=substr($line,0,$index+$l);
   $s2=substr($line,$index+$l); 
   $tmp="(";
   $index=index($s2,$tmp);
   $s3=substr($s2,0,$index+1);
   $s4=substr($s2,$index+1);
   $tmp=')';
   $index=index($s4,$tmp);
   $s5=substr($s4,0,$index);
   $s6=substr($s4,$index+1);
   if($s6=~/^#/){ 
    $go=1;
   }
   elsif($s6=~/^\s*$/){ 
    $go=1;
   }
   else{ 
    $go=0;
   }
   $line2=$s0."call wrtout\(std_out,".$s5.",\'COLL\'\)\n";
   $line3=$s0."call leave_new\(\'COLL\'\)\n";
   if($go==1){
    print $line2;  
    print $line3; 
   }
   else{ #not in standard format
    print $line;
    print "!$line2";  
    print "!$line3"; 
   }
 }
 else{
  print $line;
 }#if
}

close TEMP;


###############
sub ARGVerror {
###############
    chop ( $case = qx /  echo \$PWD \| awk -F \/ '{print\$NF} '  /  );   #directory at which the user is working
    system("clear");
    print "\e[0;31m*******************************************************\e[00m \n";
    print "The scripts needs to be run as follows:\n";
    print "\n";
    print "format-bib.pl \e[0;34m file.bib \e[0;34m  \e[0m\n";
    print "\n";
    print "file.bib is a .bib file to be formated. \n";
    print "\e[0;31m******************************************************\e[00m \n";
    exit(1);
}

# Declare the subroutines


# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
# Left trim function to remove leading whitespace
sub ltrim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}