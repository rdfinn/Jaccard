#!/usr/bin/perl -W

=head1

SCRIPT 
JaccardHierarchy2.pl

PURPOSE 
Writes a tab-delimited file that shows the hierarchy derived from a Jaccard analysis

AUTHOR
Neil Rawlings 

MODIFICATIONS
8 August 2017 - program created

HOW THIS PROGRAM WORKS
The Jaccard analysis performed by RunJaccard6.pl is a tab-delimited file showing the predicted relationship between any two member database entries.  Using this a new file is generated to show the relationships as a hierarchy
with a tab indicated parent/child relationship and an equals sign indicating equivalence.

This is a re-think to deal with identifying children from grandchildren, which was a problem with the first version.  Rob has suggested that the greater the JI score, the closer the relationship, and a parent/child relationship
should have the greatest JI score.  
=cut
use Data::Dumper;
use strict;

my @data;
my %methods;
my %equivalent;
my %parent;
my %child;
my %bestJaccard;
my $threshold = 0.75;
my @newname;

my $infile = $ARGV[0] || die "Please supply a filename on the command line.\n";
my $DB2keep = $ARGV[1] || die "Please supply member database name to keep in results on command line (eg SLFD).\n";
open(IN,"$infile") || die "Unable to read $infile.\n";

# throw away header
my $line = <IN>;

# read in data WITHOUT interpreting it, except to convert child-parent pairs to parent-child (to make further programming easier)
my $count = 0;
while ($line = <IN>) {
      chomp($line);
      my ($test_method,$hit_method,$relationship,$ji,$jc1,$jc2,$temp) = split(/\t/,$line);
      $count++;
      if ($jc1 > $jc2) {
           $data[$count][1] = $hit_method;
           $data[$count][2] = $test_method;
           $data[$count][4] = $ji;
           $data[$count][5] = $jc2;
           $data[$count][6] = $jc1;
           $data[$count][7] = $temp;
      }
      else {
           $data[$count][1] = $test_method;
           $data[$count][2] = $hit_method;
           $data[$count][4] = $ji;
           $data[$count][5] = $jc1;
           $data[$count][6] = $jc2;
           $data[$count][7] = $temp;
      }
      $data[$count][3] = $relationship;
      if (($ji >= $threshold) && ($ji >= $data[$count][6])) {$data[$count][3] = 'E'}
      elsif ($data[$count][6] >= $threshold) {$data[$count][3] = 'P'}
      #if (($ji >= $threshold) || ($jc1 >= $threshold) || ($jc2 >= $threshold)) {print "$count: $data[$count][1]\t$data[$count][2]\t$data[$count][3]\t$data[$count][4]\t$data[$count][5]\t$data[$count][6]\t$data[$count][7]\n"}
}
close(IN);

# moved following routine from last to first
# delete any lines where match is not significant
print "Removing lines where match is not significant.\n";
for (my $i = 1; $i <= $count; $i++) {
    if ($data[$i][4] == 0) {next}
    
    # What should the cut-offs be?  0.75 appears to be too stringent; 0.65 is too lax.
    if (($data[$i][4] < $threshold) && ($data[$i][5] < $threshold) && ($data[$i][6] < $threshold)) {
       delete_row($i);
    }
}

print "\nResolving equivalences\n";
# Now resolve equivalences
my @newnames;
for (my $i = 1; $i <= $count; $i++) {
    if ($data[$i][4] == 0) {next}
    $newname[$i] = $data[$i][1];
    for (my $j =1; $j <= $count; $j++) {
        if (($data[$j][3] eq 'E') && ($newname[$i] =~ /$data[$j][1]/)) {  # is this working correctly for Panther?
           if ($newname[$i] =~ /$data[$j][2]/) {}
           else {
                $newname[$i] .= "=".$data[$j][2];
                $newname[$i] = namesort($newname[$i]);
           }
        }
    }
}
for (my $i = 1; $i <= $count; $i++) {

    if ($data[$i][4] == 0) {next}
    
    # A subroutine is required to check if the new name includes the old name so that equivalence can be checked, not just contianment, becuase of Panther subfamiles.
    if (namecheck($newname[$i],$data[$i][1]) == 1) {
#    if ($newname[$i] =~ /$data[$i][1]/) {
        if ($i == 1794) {print "i = $i; old name: $data[$i][1]\t"}
        $data[$i][1] = $newname[$i];
        if ($i == 1794) {print "i = $i; new name: $data[$i][1]\n"}
    }
    for (my $j = 1; $j <= $count; $j++) {
        if (namecheck($newname[$i],$data[$j][2]) == 1) {
#        if ($newname[$i] =~ /$data[$j][2]/) {  # doesn't work for Panther!
           if ($j == 1794) {print "j = $j; old name: $data[$j][2]\t"}
           $data[$j][2] = $newname[$i];
           if ($j == 1794) {print "j = $j; new name: $data[$j][2]\n"}
        }
    }
    $data[$i][1] = namesort($data[$i][1]);
    $data[$i][2] = namesort($data[$i][2]);
}

# delete lines where equivalences occur
for (my $i = 1; $i <= $count; $i++) {

    if ($data[$i][4] == 0) {next}
    if ($data[$i][1] =~ /$data[$i][2]/) {
       #if (($data[$i][1] =~ /PTHR/) && ($data[$i][2] =~ /PTHR/)) {
       #   print "Deleting $i: $data[$i][1]\t$data[$i][2]\n";
       #}
       if ($i == 1794) {print "i = $i; deleting $data[$i][1], $data[$i][2]\t"}
       delete_row($i);
    }
    
    # Following line doesn't work for PANTHER because subfamily is substring of family!
    # are following three lines necessary?
    if ($data[$i][2] eq $data[$i][1]) {
       #if (($data[$i][1] =~ /PTHR/) && ($data[$i][2] =~ /PTHR/)) {
       #   print "Deleting $i: $data[$i][1]\t$data[$i][2]\n";
       #}
       delete_row($i);
    }
    #print "$i: $data[$i][1]\t$data[$i][2]\t$data[$i][3]\t$data[$i][4]\t$data[$i][5]\t$data[$i][6]\t$data[$i][7]\n";

    $bestJaccard{$data[$i][2]} = 0;
}
#die;

# Delete lines when child occurs more than once keeping only row with greatest JI
# Find best JI for each child first, then delete duplicates
print "\nDeleting poor children\n";
for (my $i = 1; $i <= $count; $i++) {
    if ($data[$i][4] == 0) {next}
    if ($data[$i][4] > $bestJaccard{$data[$i][2]}) {$bestJaccard{$data[$i][2]} = $data[$i][4]}
    if ($data[$i][5] > $bestJaccard{$data[$i][2]}) {$bestJaccard{$data[$i][2]} = $data[$i][5]}
    if ($data[$i][6] > $bestJaccard{$data[$i][2]}) {$bestJaccard{$data[$i][2]} = $data[$i][6]}
}

# delete duplicate lines
for (my $i = 1; $i <= $count; $i++) {
    for (my $j = 1; $j <= $count; $j++) {
        if ($i == $j) {next}
        if ($data[$j][4] == 0) {next}
        if ($data[$i][2] eq $data[$j][2]) {
           if (($bestJaccard{$data[$i][2]} > $data[$j][4]) && ($bestJaccard{$data[$i][2]} > $data[$j][5]) && ($bestJaccard{$data[$i][2]} > $data[$j][6])) {
              if ($j == 1794) {print "$i vs $j; $data[$i][2] vs $data[$j][2], $data[$i][1] vs $data[$j][1], JIs $bestJaccard{$data[$i][2]} vs $data[$j][4], $data[$j][5] or $data[$j][6]\n"}
              delete_row($j);
           }
           elsif (($bestJaccard{$data[$i][2]} == $data[$j][5]) || ($bestJaccard{$data[$i][2]} == $data[$j][6])) {
              if ($data[$i][4] > $data[$j][4]) {
                 if ($j == 1794) {print "$i vs $j; $data[$i][2] vs $data[$j][2], $data[$i][1] vs $data[$j][1]; best Jaccard = $bestJaccard{$data[$i][2]} vs $data[$j][5] or $data[$j][6]; JIs $data[$i][4] vs $data[$j][4]\n"}
                 delete_row($j);
              }
           }
        }
    }
}

# At this point, there are still duplicates in the file!
print "Removing duplicates lines.\n";
for (my $i = 1; $i <= $count; $i++) {
    if ($data[$i][4] == 0) {next}
    for (my $j = 1; $j <= $count; $j++) {
        if ($i == $j) {next}
        if (($data[$i][1] eq $data[$j][1]) && ($data[$i][2] eq $data[$j][2])) {
           if ($j == 1791) {print "$i vs $j: $data[$i][1]; $data[$j][1]; $data[$i][2]; $data[$j][2]\n"}
           delete_row($j);
        }
    }
}
#die;

my $outfile = 'newSFLD_hits.txt';
open(OUT,">$outfile");
for (my $i = 1; $i <= $count; $i++) {
    print OUT "$i: $data[$i][1]\t$data[$i][2]\t$data[$i][3]\t$data[$i][4]\t$data[$i][5]\t$data[$i][6]\t$data[$i][7]\n";
}
close(OUT);
#die;

# Find children
my %children;
for (my $i = 1; $i <= $count; $i++) {
    if ($data[$i][3] eq 'P') {$children{$data[$i][2]}++}
    
    # following line assumes any pairing not assigned to parent, child or equivalent is by default a child (not below significance threshold: is this correct?
    #unless ($data[$i][3]) {$children{$data[$i][2]}++}
}

# Find parents
my %all_parents;
my %parents;
for (my $i = 1; $i <= $count; $i++) {
    # will this work if $data[$i][3] is null?
#    if ($data[$i][3] eq 'C') {
#       if ($children{$data[$i][2]}) {}
#       else {$parents{$data[$i][2]} = $i}
#    }
#    if ($data[$i][2] =~ /SFLD/) {
#       #print "checking $data[$i][2]\t";
#       if ($children{$data[$i][2]}) {print "child of $children{$data[$i][2]}"}
#       #print "\n";
#    }
    if ($data[$i][3] eq 'P') {
       $all_parents{$data[$i][1]} = $i;
       if ($children{$data[$i][1]}) {}
       else {$parents{$data[$i][1]} = $i}
    }
}

#print Dumper(%parents)."\n";
#die;

$outfile = 'hierarchy2.txt';
open(OUT,">$outfile") || die "Unable to write to $outfile.\n";

# this almost worked when it was accessing an array
foreach my $parent (keys %parents) {
       my @row_to_check;
       my $level = 1;
       print OUT "$parent\n";
       #if ($row_to_check[$level] =~ /^SFLD/) {print "$parent; level = $level\n"}
       my $nochildren = 0;
       $row_to_check[$level] = $parent;
       until ($nochildren == 1) {
             $nochildren = 1;
             #if ($row_to_check[$level] =~ /^SFLD/) {print "checking: $level, $row_to_check[$level]\t"}
             for (my $j = 1; $j <= $count; $j++) {
                 #print "$j\t";
                 #$row_to_check[$level] = $checking;
                 if ($data[$j][4] == 0) {}
                 elsif ($row_to_check[$level] eq $data[$j][1]) {
                    my $tabs;
                    for (my $i = 1; $i <= $level; $i++) {
                        $tabs .= "\t";
                    }
                    
                    print OUT "$tabs$data[$j][2]\n";
#                    print OUT "$tabs$data[$j][2] (JI = ".sprintf("%.2f",$data[$j][4]).", JC1 = ".sprintf("%.2f",$data[$j][5]).", JC2 = ".sprintf("%.2f",$data[$j][6]).")\n";
                    #print "$tabs$data[$j][2] (level = $level; $row_to_check[$level])\n";
                    if ($all_parents{$data[$j][2]}) {
                       #$checking = $data[$j][2];
                       $level++;
                       $row_to_check[$level] = $data[$j][2];
                    }
                    $nochildren = 0;
                    delete_row($j);
                    unless ($row_to_check[$level] eq $data[$j][1]) {$j = 1}
                 }
             }
             $level--; 
             if ($level > 0) {$nochildren = 0} else {$nochildren = 1}
       }
       $level--;
       #$row_to_check[$level] = $parents{$parent};
       $nochildren = 0;
       my $tabs;
       delete_row($parents{$parent});
}
close(OUT);

# Now trim results of all elements of hierarchy that do not include selected member database
$infile = 'hierarchy2.txt';
print "\n\n\nRESULTS\n";
open(IN,"$infile") || die "Unable to open $infile.\n";
$outfile = 'hierarchy_trimmed.txt';
open(OUT,">$outfile") || die "Unable to write to $outfile.\n";

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

sub delete_row {
    my ($row) = @_;
#    print "deleting row $row\n";
    if ($row == 1794) {print "Deleting row $row: Name 1 = $data[$row][1], Name 2 = $data[$row][2], JI = $data[$row][4], JC1 = $data[$row][5], JC2 = $data[$row][6]\n"}
    if ($row == 3556) {print "Deleting row $row: Name 1 = $data[$row][1], Name 2 = $data[$row][2], JI = $data[$row][4], JC1 = $data[$row][5], JC2 = $data[$row][6]\n"}
#    if ($data[$row][2] =~ /PTHR43287/) {print "Deleting row $row: Name 1 = $data[$row][1], Name 2 = $data[$row][2], JI = $data[$row][4], JC1 = $data[$row][5], JC2 = $data[$row][6]\n"}
    for (my $m = 1; $m <= 7; $m++) {
        if ($m < 4) {$data[$row][$m] = ''}
        else {$data[$row][$m] = 0};
    }
}

sub namesort {
    my ($unsortedname) = @_;
    my (@temp) = split(/\=/,$unsortedname);
    my $sortedname;
    foreach my $name (sort @temp) {
            $sortedname .= "=".$name;
    }
    $sortedname =~ s/^\=*//;
    return $sortedname;
}

sub namecheck {
    # returns a value of 1 if a match is found, else returns 0
    my ($newname,$oldname) = @_;
    my (@names) = split(/\=/,$newname);
    my $match = 0;
    foreach my $name (@names) {
            if ($name eq $oldname) {$match = 1}
    }
    return $match;
}