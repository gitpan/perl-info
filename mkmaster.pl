#!/usr/bin/perl

# A program to prepare initial layout data for pod2texi.
# Michal Jaegermann (michal@ellpsapce.math.ualberta.ca)
# 1997/05/28

my @nodes = ('');
my $master = 'Pmaster.texi';
my $nlist  = 'Nodelist.pl';

sub addfaq {
  foreach(<perlfaq*.pod>) {
    chomp;
    s/\.pod//;
    push @nodes, $_;
  }
}

while (<>) {
  next unless /^\s+perl\S*\s+Perl/;
  @_ = split ' ', $_, 2;
  if ('perlfaq' eq $_[0]) {
    addfaq;
  }
  else {
    push @nodes, $_[0];
  }
}

$nodes[0] = $nodes[1];
$nodes[1] = 'perltoc';
push @nodes, 'indices';

open MT, ">$master" or die "cannot write to $master: $!\n";

print MT <<EOT;
\\input texinfo.tex
\@comment %**start of header
\@setfilename perl.info
\@settitle perl
\@c footnotestyle separate
\@paragraphindent 0
\@smallbook
\@comment %**end of header

EOT

foreach (@nodes) {
  print MT "\@include $_.texi\n"
}

close MT;

open NL, ">$nlist" or die "cannot write to $nlist: $!\n";

print NL "\@nodelist = (\n    ", (join ",\n    ", @nodes), "\n);\n1;";
close NL;

