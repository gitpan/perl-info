#!/usr/local/bin/perl
# changes pod to texinfo
# you still have to insert a few TeXinfo directives to make it look
# right ...

# parts stolen from pod2html (to get the perlpod listings, et al).
# unfortunately, texinfo 1.1 can't jump to a certain location in a 
# info page, so we can't do the kind of cool exactly-this-spot 
# xrefs that html can ...
# By Krishna Sethuraman (krishna@mit.edu)

# This was a real hack job -- I started this before I fully understood
# anonymous references (which continues to this day), so please feel free
# to hack this apart.

# The beginning of the url for the anchors to the other sections.
$nodeterm = "\c_";
chop($wd=`pwd`);
$type="<A HREF=\"file://localhost".$wd."/";
$debug=0;
$/ = "";
$p=\%p;
@exclusions=qw(perldebug perlform perlobj perlstyle perltrap perlmod);
$indent=0;
opendir(DIR,".");
@{$p->{"pods"}}=sort grep(/\.pod$/,readdir(DIR)); # sort so perl.pod is first
closedir(DIR);

# learn the important stuff.

foreach $tmpod (@{$p->{"pods"}}){
    ($pod=$tmpod)=~s/\.pod$//;
    $p->{"podnames"}->{$pod}=1;
    next if grep(/$pod/,@exclusions);
# for each podfile
    open(POD,"<$tmpod");
    while(<POD>){
# kill bold/italics
	s/B<([^<>]*)>/$1/g;         # bold
	s/I<([^<>]*)>/$1/g;         # bold
# if = cmd
        if (s/^=//) {
	    s/\n$//s;
	    s/\n/ /g;
	    ($cmd, $_) = split(' ', $_, 2);
# if =item cmd
 	    if ($cmd eq  "item") {
		($what,$rest)=split(' ', $_, 2);
# what is now only the (-.) part (dash plus one character)
		$what=~s#(-.).*#$1#;
		$what=~s/\s*$//;

		next if defined $p->{"items"}->{$what};
# put it in items subarray as podname_serialnumber(?)
		$p->{"items"}->{$what} = $pod."_".$i++;
	    }
	    elsif($cmd =~ /^head/){
# if =head cmd
		$_=~s/\s*$//;
		next if defined($p->{"headers"}->{$_});
# put it in headers subarray as podname_serialnumber(?)
# serial numbers, etc., look to be used as tags to indicate a position
# in an html file.  No such luck in texinfo (sigh).
		$p->{"headers"}->{$_} = $pod."_".$i++;
	    }
	}
    }
}

# we can do all the above, just ignore the _ tagging stuff.  Maybe in the next
# version of texinfo, we can ref a char. position in an info file.

# parse the pods, produce texinfo
foreach $tmpod (@{$p->{"pods"}}){
    open(POD,"<$tmpod") || die "cant open $pod";
    ($pod=$tmpod)=~s/\.pod$//;
    open(TEXINFO,">$pod.texi");

# check if we have the lines array - if so, we can use it to
# generate pod nodes and prev, next, etc. refs

    ($curn,$prevn,$nextn,$upn) = ();
    $curn = $pod;
    if (@linesfornodes) {
	$i=0;
      podline: for (@linesfornodes) {
	  last podline if $pod eq $_;
	  $i++;
      }
# if we got to $#linesfornodes+1, we didnt find it.
	unless ($i == $#linesfornodes+1) {
	($prevn, $curn, $nextn) = @linesfornodes[($i?$i-1:0),$i,$i+1];
	$prevn = 'Top' if ($prevn eq $curn);
	}
    }


# specific to master node
    print TEXINFO "\\input texinfo.tex\n" if ($pod eq 'perl');
    $upn = ($pod eq 'perl')?'(dir)' :'Top';

    $pod eq 'perl' and ($curn,$nextn) = ('Top','perldata');
    $prevn eq 'perl' and $prevn = 'Top';
    $prevn ||= 'Top';
    $nextn ||= 'Top';

    print STDOUT "for pod $pod, \@node $curn, $nextn, $prevn, $upn\n";
    print STDOUT "@linesfornodes\n";

    print TEXINFO <<_EOF_ if $pod eq 'perl';
\@comment \%**start of header
\@setfilename $pod.info
\@settitle $pod
\@c footnotestyle separate
\@c paragraphindent 2
\@smallbook
\@comment \%**end of header
_EOF_

    print TEXINFO <<_EOF_;
\@node $curn, $nextn, $prevn, $upn
_EOF_


    $cutting = 1;
    while (<POD>) {
	if ($cutting) {
	    next unless /^=/;
	    $cutting = 0;
	}
	chop;
	length || (print "\n") && next;
	# Translate verbatim paragraph

# greedy matching here will set $1 to all space before first nonspace
# at beginning of string.  Since its unlikely anything after that in the
# same paragraph will be outdented farther left than the first line, 
# we can kill that much whitespace from the beginning of each line.  
# we kill whitespace from beginning of line for verbatim because
# example mode adds it back in.

	if (($space) = /^(\s+)/) { 
	    &pre_escapes;
	    @lines = split(/\n/);
	    if($lines[0]=~/^\s+(\w*)\t(.*)/){  # maybe a menu
		($key,$rest)=($1,$2);
		if(defined($p->{"podnames"}->{$key})){ # yup, a menu
		    # process menu here. if not a menu, its an example
		    # or Its a menu.  Save it for end of node.
		    print TEXINFO "\n\@menu\n";
		    for (@lines) {
			m/^\s+(\w*)\t(.*)/;
			print TEXINFO "* $1:: $2\n";
		    }
		    print TEXINFO "\@end menu\n\n";
# this next bit we will do by hand for now...
#		    for (@lines) {
#			m/^\s+(\w*)\t(.*)/;
#			print TEXINFO "\@include $1.texinfo\n";
#		    }
		    @linesfornodes = @lines;
		    map(s/^\s+(\w*)\t(.*)/$1/,@linesfornodes);
		    # done with menu paragraph, next paragraph
		    next;
		}
		# not a menu, process it as example
	    }
	    s/^$space//mg;
	    print TEXINFO "\@example\n", $_, "\@end example\n\n";
	    next;
	}
	&pre_escapes;
	$_ = &Do_refs($_,$pod);
	
	s/Z<>//g; #  what to do with this?
	s/E<lt>/</g;
	s/E<gt>/>/g;

	if (s/^=//) {
	    s/\n$//s;
	    s/\n/ /g;
	    ($cmd, $_) = split(' ', $_, 2);
	    if ($cmd eq 'cut') {
		$cutting = 1;
	    }
	    elsif ($cmd eq 'head1') {
		print TEXINFO qq|\@unnumberedsec $_\n|;
	    }
	    elsif ($cmd eq 'head2') {
		print TEXINFO qq|\@unnumberedsubsec $_\n|;
	    }
	    elsif ($cmd eq 'item') {
		($what,$rest)=split(' ', $_, 2);
		$what=~s/\s*$//;

		if ($what =~ /[*]/) { # if a single star, axe it

		# texinfo itemize can put in its own star.
		    $_ = $rest;

# if a single star, its a bulleted list with paragraphs - 
# need a newline before paragraphs if theres anything
# left on that line.  Else, if no star,
# its probably going to be a table - no newlines before paragraph
		    $next_para=1 if $rest;
		}

		if ($what =~ /^\d+[.]/) { # if digits, get rid of them ...

		# texinfo enumerate can put in its own numbers
		    $_ = $rest;

# if a single star, its a bulleted list with paragraphs - 
# need a newline before paragraphs.  Else, if digits
# its enumerated - no newlines before paragraph
		    $next_para=0;
		}

		# only if we have starred items do we want to really
		# have separate items - else, two items
		# in a row is likely an itemx
		# candidate.  We will see how this goes

# previously we only wanted itemx if they had the first word
# in common (write, write FILEHANDLE, etc.)
#		if($justdid ne $what && $what =~ /[*]/){}
		if(! $justdid || $what =~ /([*])|(\d+[.])/){
		    print TEXINFO "\@item $_\n";
		    $justdid=$what;
		} else {
		print TEXINFO qq{\@itemx $_\n};
	    }
	    }
	    elsif ($cmd eq 'over') {
#		print TEXINFO qq|over[$_]\n|;
	    }
	    elsif ($cmd eq 'back') {
#		print TEXINFO qq|back[$_]\n|;
	    }
	    else {
		warn "Unrecognized directive: $cmd\n";
	    }
	}
	else {
# not a perl command, so dont try to compare vs. the last item for itemxing
# upcoming paragraphs
	    $justdid = ''; 
	    
	    length || next;
# argh - in itemize, it sucks the whole thing up to the next line
# in table, it doesn't
# we don't know whether to do table or itemize

	    $next_para && print TEXINFO "\n";
#	    $next_para && (print TEXINFO  qq{<dd>\n});
	    print TEXINFO  "$_\n";
#	    $next_para && (print  TEXINFO qq{</dd>\n<p>\n}) && ($next_para=0);
	    $next_para = 0;
	}
    }
# argh! we have to do this in each file because texinfo 
# cant just read in a file with a whole bunch of include statements  ...
    print TEXINFO "\@include $nextn.texi\n" if ($nextn ne 'Top');
}

#########################################################################

sub pre_escapes {
    s/[\@{}`']/\@$&/g;
    s/C<E<lt>E<lt>>/\@code{<<}/g;
    s/C<-E<gt>>/\@code{->}/g;
}

sub post_escapes{
#    s/>>/\&gt\;\&gt\;/g;
#    s/([^"AIB])>/$1\&gt\;/g;
}

sub Do_refs{
local($para,$pod)=@_;
foreach $char (qw(L C I B S F Z)){
    next unless /($char<[^<>]*>)/;
# @ar = split paragraph, making array elements out of 
# the current char<foo> as well as regular text
    local(@ar) = split(/($char<[^<>]*>)/,$para);
    local($this,$key,$num,$sec,$also);
# for all @ar elements,
    for($this=0;$this<=$#ar;$this++){
# only handle the current chars char<foo> thingies
        next unless $ar[$this] =~ /$char<([^<>]*)>/;

# if just single foo, $key = foo.  Else if foo/bar, $key = foo, 
# $sec = bar.
	$key=$1;
    ($chkkey,$sec) = ($key =~ m|^([^/]+)(?:/([^/]+))?|);
# XXX if chkkey was '' but there was a slash, use the 'in this node' case
# if the key matches a podname, put in a ref to the pod
	if((defined($p->{"podnames"}->{$chkkey})) && ($char eq "L")){

	    $also = "\@samp{$sec}, " if $sec ;
#	    $ar[$this] = "${also}\@xref{$chkkey,\u$chkkey,,$chkkey.info},";
	    $ar[$this] = "${also}\@xref{$chkkey,\u$chkkey},";
	    # *note arg2: (arg3) arg1
# otherwise, if char is still "L", then key didnt match a podname
# and therefore is a section on the current manpage
	} 
    elsif ($char eq "L") {
	$ar[$this] = "\@samp{$chkkey} in this node";
	}

# if the key matches an item, put in a ref to the item def.
# ignore this for now
	elsif(defined($p->{"items"}->{$key})){
	    ($pod2,$num)=split(/_/,$p->{"items"}->{$key},2);
		$ar[$this] = (($pod2 eq $pod) && ($para=~/^\=item/)) ?
#		"\n<A NAME=\"".$p->{"items"}->{$key}."\">\n$key</A>\n"
		    $key:$key
#		"\n$type$pod2.html\#".$p->{"items"}->{$key}."\">$key<\/A>\n"
		    ;
        }
# if the key matches a header, put in a ref to the header def.
#ignore this to start with
	elsif(defined($p->{"headers"}->{$key})){
	    ($pod2,$num)=split(/_/,$p->{"headers"}->{$key},2);
		$ar[$this] = (($pod eq $pod2) && ($para=~/^\=head/)) ? 
#		"\n<A NAME=\"".$p->{"headers"}->{$key}."\">\n$key</A>\n"
		:
#		"\n$type$pod2.html\#".$p->{"headers"}->{$key}."\">$key<\/A>\n";
	}
	else{
	    (warn "No \"=item\" or \"=head\" reference for $ar[$this] in $pod\n") if $debug;
	    if ($char eq "L"){
		$ar[$this]=$key;
	    }
	    elsif($char eq "I"){
		$ar[$this]="\@emph{$key}";
	    }
	    elsif($char eq "B"){
		$ar[$this]="\@strong{$key}";
	    }
	    elsif($char eq "S"){
		$ar[$this]="\@w{$key}";
	    }
	    elsif($char eq "C"){
		$ar[$this]="\@code{$key}";
	    }
	    elsif($char eq "F"){
		$ar[$this]="\@file{$key}";
	    }
	}
    }
    $para=join('',@ar);
}
$para;
}
sub wait{1;}
