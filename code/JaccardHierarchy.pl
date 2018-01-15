#!/usr/bin/env perl

=head1

SCRIPT 
JaccardHierarchy.pl

PURPOSE 
Writes a tab-delimited file that shows the hierarchy derived from a Jaccard analysis

AUTHOR
Neil Rawlings 

MODIFICATIONS
8 August 2017 - program created

HOW THIS PROGRAM WORKS
The Jaccard analysis performed by RunJaccard.pl is a tab-delimited file showing the predicted relationship between any two member database entries.  Using this a new file is generated to show the relationships as a hierarchy
with a tab indicated parent/child relationship and an equals sign indicating equivalence.

This is a re-think to deal with identifying children from grandchildren, which was a problem with the first version.  Rob has suggested that the greater the JI score, the closer the relationship, and a parent/child relationship
should have the greatest JI score.  
=cut


use strict;
use warnings;
use Getopt::Long;

my @data;
my %methods;
my %equivalent;
my %parent;
my %child;
my $ithreshold = 0.75;
my $cthreshold = 0.75;
my $DB2keep;
my $infile;
my @newname;

GetOptions(
  "ithreshold=s" => \$ithreshold,
  "cthreshold=s" => \$cthreshold,
  "db=s"         => \$DB2keep,
  "infile=s"     => \$infile,
) or die "Invalid option passed in\n";



if(!$infile){
  die "Please supply a filename on the command line.\n";
}
if(! -s $infile){
  die "Input file, $infile, does not exist or has no size\n";
}

if(!$DB2keep){
 die "Please supply member database name to keep in results on command line (eg SLFD).\n";
}






open(IN,"$infile") || die "Unable to read $infile.\n";

# throw away header
my $line = <IN>;

# read in data WITHOUT interpreting it, except to convert child-parent pairs to parent-child (to make further programming easier)
my $count = 0;
while ($line = <IN>) {
      chomp($line);
        
      #my ($test_method,$hit_method,$relationship,$ji,$jc1,$jc2,$temp) = split(/\t/,$line);
      #Break the line down and make sure that the large jaccard containment is always last.
      my @ldata = split(/\t/, $line);
      if($ldata[4] > $ldata[5]){
        my $jci = $ldata[5];
        my $name1 = $ldata[0];
        $ldata[0] = $ldata[1];
        $ldata[1] = $name1;
        $ldata[5] = $ldata[4];
        $ldata[4] = $jci;
      }
      
      #Now check that one of the thresholds of the match are okay!
      if (($ldata[3] < $ithreshold) && ($ldata[4] < $cthreshold) && ($ldata[5] < $cthreshold)) {
        next;
      }

      #Now define the relationship.  
      if (($ldata[3] >= $ithreshold)){ 
        $ldata[2] = 'E'
      }elsif ($ldata[5] >= $cthreshold) {
        $ldata[2] = 'P'
      }else{
        #We should not get here, as it should have already been removed.
        #One of the above conditions should have been matched.
        next;
      }

      $data[$count] = \@ldata;
      $count++;
}
close(IN);
# moved following routine from last to first
# delete any lines where match is not significant
print "\nResolving equivalences\n";
my $e; 
foreach my $pair (@data){
  if($pair->[2] eq "E"){
    $e->{$pair->[0]}->{$pair->[1]}++;
    $e->{$pair->[1]}->{$pair->[0]}++;
  }
}

foreach my $name1 (keys %$e){
  foreach my $name2 (keys %{$e->{$name1}}){
    foreach my $other (keys %{$e->{$name2}}){
      $e->{$name1}->{$other}++;
    }
    $e->{$name2}->{$name1}++;
  }
}

foreach my $pair (@data){
  if(defined($e->{$pair->[0]})){
    my $newname = join("=", sort{ $a cmp $b }keys( %{$e->{$pair->[0]}}));
    $pair->[0] = $newname;
  }
  if(defined($e->{$pair->[1]})){
    my $newname = join("=", sort{ $a cmp $b }keys( %{$e->{$pair->[1]}}));
    $pair->[1] = $newname;
  }
  
  #If the two names have the same name, then these are duplicates.
  #Need to delete the row! But first, look which has the highest containment.
}

my $bestJaccard;
foreach my $pair (@data){
  next if($pair->[0] eq $pair->[1]);
  if(!defined($bestJaccard->{$pair->[1]})){
    $bestJaccard->{$pair->[1]} = $pair->[3]; #store the JI
  }elsif( $bestJaccard->{ $pair->[1]} < $pair->[3] ){
    $bestJaccard->{$pair->[1]} = $pair->[3]; #store the JI
  }
}

#Now reduce to bare minimal nodes.
use DDP;
my %seen;
#p(@data);
#p($bestJaccard);
#exit;
my @redData;
foreach my $pair (@data){
  next if($pair->[0] eq $pair->[1]);
  if(defined($bestJaccard->{$pair->[1]})){
    unless($seen{ $pair->[1]}){
      if( $bestJaccard->{ $pair->[1]} == $pair->[3] ){
        push(@redData, $pair);
        $seen{ $pair->[1]}++;
      }
    }
  }else{
    p($pair);
    die;
  }
}

#p(@redData);
#exit;

# Find children
my %children;
for (my $i = 0; $i < scalar(@redData); $i++) {
    if ($redData[$i]->[2] eq 'P') {
      $children{$redData[$i]->[1]}++;
  }
}

# Find parents
my %all_parents;
my %parents;
for (my $i = 0; $i < scalar(@redData); $i++) {
    if ($redData[$i]->[2] eq 'P') {
       $all_parents{$redData[$i][0]} = $i;
       if ($children{$redData[$i][0]}) {}
       else {$parents{$redData[$i][0]} = $i}
    }
}

my $outfile = 'hierarchy2.txt';
open(OUT,">$outfile") || die "Unable to write to $outfile.\n";

# this almost worked when it was accessing an array
foreach my $parent (keys %parents) {
       my @row_to_check;
       my $level = 1;
       print OUT "$parent\n";
       my $nochildren = 0;
       $row_to_check[$level] = $parent;
       until ($nochildren == 1) {
             $nochildren = 1;
             for (my $j = 0; $j < scalar(@redData); $j++) {
                 if($redData[$j][2] eq "Done"){
                   next;
                 }elsif ($row_to_check[$level] eq $redData[$j][0]) {
                    my $tabs;
                    for (my $i = 1; $i <= $level; $i++) {
                        $tabs .= "\t";
                    }
                    
                    print OUT "$tabs$redData[$j][1]\n";
                    if ($all_parents{$redData[$j][1]}) {
                       $level++;
                       $row_to_check[$level] = $redData[$j][1];
                    }
                    $nochildren = 0;
                    $redData[$j][2] = "Done";
                    unless ($row_to_check[$level] eq $redData[$j][0]) {$j = 1}
                 }
             }
             $level--; 
             if ($level > 0) {$nochildren = 0} else {$nochildren = 1}
       }
       $level--;
       $nochildren = 0;
       my $tabs;
       $redData[$parents{$parent}]->[2] = "Done";
}
close(OUT);
# Now trim results of all elements of hierarchy that do not include selected member database
$infile = 'hierarchy2.txt';
print "\n\n\nRESULTS\n";
open(IN,"$infile") || die "Unable to open $infile.\n";
$outfile = 'hierarchy_trimmed.txt';
open(OUT,">$outfile-JI-$ithreshold-JC-$cthreshold") || die "Unable to write to $outfile.\n";

# Read in lines until line does not start with a tab
$line = <IN>;
my $text = $line."*";
while ($line = <IN>) {
      chomp($line);
      if ($line =~ /^\t/) {$text .= $line."*"}
      else {
           if ($text =~ /$DB2keep/) {
              $text =~ s/\*/\n/g;
              print OUT "$text";
           }
           $text = $line."*";
      }
}
close(IN);
if ($text =~ /$DB2keep/) {
   $text =~ s/\*/\n/g;
   print OUT "$text";
}
close(OUT);
