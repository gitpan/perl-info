#
# Makefile for pod -> texi conversion (a sample)
# After initial conversion run 'make expand' and work on files
# in texi_w subdirectory
# Michal Jagermann (michal@ellpspace.math.ualberta.ca), 1997/05/28.
#
NFILES=Pmaster.texi Nodelist.pl

all: $NFILES indices.texi
	pod2texi.pl

$NFILES: perl.pod
	mkmaster.pl perl.pod

expand: texi_w
	for f in *.texi ; do expand $$f > texi_w/$$f ; done

texi_w:
	@if [ -d texi_w ] ; then : ; else mkdir texi_w ; fi
