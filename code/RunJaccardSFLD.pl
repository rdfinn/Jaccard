#!/usr/bin/perl -W

=head1

SCRIPT 
RunJaccardSFLD.pl

PURPOSE 
Runs Jaccard analysis.  This is a version for the FuncFams comparison paper designed to read in all data from a flat file supplied by SiewYit.  This file was /homes/siewyit/syy/ibu/7427/func_fam_match.tsv and has been copied to 
/nfs/nobackup/interpro/ndr/Jaccard/func_fam_match.tsv.  Columns in this file are Uniprot accession, member database accession, source database, start of match (residue no.), end of match  (residue no.) and E-value.  I presume that
the UniProt entries are restricted to organisms in the set supplied by Paul Thomas from Panther.  

Overlaps have not been precalculated, so this has to be done once data have been read in.

Pfam entries include domains as well as families, either filter these out or calculate overlaps using residue ranges.

AUTHOR
Neil Rawlings 

MODIFICATIONS
13 Dec 2017 - program created

HOW THIS PROGRAM WORKS

=cut

#use strict;
use DBI;

# global variables
my @testmethods;
my %methods;
my %swacc;
my @setcount = (0);
my @swisscount = (0);
my @tremblcount = (0);
my @union = (0);

# Read in data from supplied filename
unless ($ARGV[0]) {
       die "Please supply a source filename on the command line.\n";
}
my $infile = $ARGV[0];
open(IN,"$infile") || die "Unable to open $infile.\n";
my %method_proteins;  # this is a string of UniProt accessions separated by underscores for each member database entry
my %method_counter;   # this is the number of proteins in each member database entry
my $count_of_methods; # total number of different methods
my $line = <IN>;  # discard header
while ($line = <IN>) {
      chomp($line);
      my ($pacc,$method_ac,$db,$start,$end,$eval) = split(/\t/,$line);
      if ($methods{$method_ac}) {}
      else {
           $methods{$method_ac}++;
           $count_of_methods++;
      }
      $method_counter{$method_ac}++;
      $method_proteins{$method_ac} .= $pacc."-".$start."-".$end."_";
      #if ($method_ac eq 'SFLDG01020') {print "$method_ac; $method_proteins{$method_ac}\n"}
      #die "method_proteins = $method_proteins{$method_ac}\n";
}
print "All proteins read in for all $count_of_methods methods.\n";
close(IN);

# open outfile
my $outfile = "SFLD_hits.txt";
open(OUT,">$outfile") || die "Unable to write to $outfile.\n";
print OUT "Test method\tHit method\tComment\tJaccard index\tJaccard containment AB\tJaccard containment BA\tcurated\n";

# Calculate union and intersect for all methods.  It is essential that relationship is calculated.
my $curated = '';
foreach my $method1 (%methods) {
        print "Comparing $method1\n";
        foreach my $method2 (%methods) {
                if ($method1 eq $method2) {next}   # don't do statistics if methods are the same
                
                # skip Pfam
                if ($method1 =~ /^PF/) {next}
                if ($method2 =~ /^PF/) {next}
                if (($method_counter{$method1}) && ($method_counter{$method1} == 0)) {next}
                if (($method_counter{$method2}) && ($method_counter{$method2} == 0)) {next}
                
                # calculate intersect
                #print "\t$method_counter{$method1}\n";
                #print "\t$method_counter{$method2}\n";
                my $acc1 = $method_proteins{$method1};
                my $acc2 = $method_proteins{$method2};
                unless ($acc2) {next}
                #print "Comparing $method1 with $method2\n";
                my (@proteins) = split(/\_/,$acc1);
                my $intersect = 0;
                foreach my $pdata1 (@proteins) {
                        #print "$pdata1\n";
                        my ($pacc1,$start1,$end1) = $pdata1 =~ /^(.*)\-(\d*)\-(\d*)$/;
                        $midpoint = int(($end1-$start1)/2+$start1);
                        if ($acc2 =~ /$pacc1/) {
                           my $pos = index($acc2,$pacc1);
                           my $pdata2 = substr($acc2,$pos);
                           $pdata2 =~ s/\_.*$//;
                           #die "$pacc1 at pos = $pos, pdata2 = $pdata2\n";
                           my ($pacc2,$start2,$end2) = $pdata2 =~ /^(.*)\-(\d*)\-(\d*)$/;
                           if (($midpoint > $start2) && ($midpoint < $end2)) {
                              $intersect++;
                           }
                           #print "pacc1 = $pacc1, start1 = $start1, end1 = $end1, midpoint = $midpoint\n";
                           #print "pacc2 = $pacc2, start2 = $start2, end2 = $end2, intersect = $intersect\n";
                           #die;
                        }
                }
                if ($intersect == 0) {next}
                my $union = $method_counter{$method1}+$method_counter{$method2}-$intersect;
                my $JI = $intersect/$union;
                my $JC1 = $intersect/$method_counter{$method1};
                my $JC2 = $intersect/$method_counter{$method2};
                my $relationship;

                # calculate relationship
                if ($JI > 0.9) {$relationship = 'E'}
                elsif ($JC1 > 0.9) {$relationship = 'C'}
                elsif ($JC2 > 0.9) {$relationship = 'P'}

                print OUT "$method1\t$method2\t$relationship\t$JI\t$JC1\t$JC2\t$curated\n";
        }
}
close(OUT);                   
    
    
