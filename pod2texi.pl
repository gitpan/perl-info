#!/usr/bin/perl
# changes pod to texinfo
# you still have to insert a few TeXinfo directives to make it look
# right ...

# This is a modification of an original 'pod2texinfo' program by
# Krishna Sethuraman.  It does not try to be that smart but relies
# on results of an earlier run by mkmaster.pl to get "nodes" and
# their ordering.  On the other hand it tries to be a bit more
# careful when inserting various Texinfo constructs.  It also
# handles new pod directives.
# Michal Jaegermann (michal@ellpsapce.math.ualberta.ca)
# 1997/05/28
#
# (a part of an original header comment follows)
# parts stolen from pod2html (to get the perlpod listings, et al).
# unfortunately, texinfo 1.1 can't jump to a certain location in a 
# info page, so we can't do the kind of cool exactly-this-spot 
# xrefs that html can ...
# By Krishna Sethuraman (krishna@mit.edu)


@nodelist = ();
require "Nodelist.pl";          # this file created by 'mkmaster' run
@open_lists = ();

@podlist = @nodelist;
$#podlist -= 1;  		# drop 'indices' from @podlist
@delay = ();

$/ = "";
# learn the important stuff.

foreach $pod (@podlist) {
  $p->{"podnames"}->{$pod}=1;
  $tmpod = "$pod.pod";
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
	$what=~s#(-.).*#$1	#;
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
$podnum = 0;
foreach $pod (@podlist){
  while ($out = shift @delay) {
    print TEXINFO "\@end $out\n\n";
  }
  &close_all_lists;
  $tmpod = "$pod.pod";
  open(POD,"<$tmpod") || die "cant open $pod";
  open(TEXINFO,">$pod.texi");
  
  &putnodeline($podnum);
  $podnum += 1;

#### debug;
##  last if $podnum >= 2;
  
  $cutting = 1;
  while (<POD>) {
    if ($cutting) {
      next unless /^=/;
      $cutting = 0;
    }
    chop;
    length || (print TEXINFO "\n") && next;
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
      if($lines[0]=~/^\s+(\w*)\t(.*)/){	# maybe a menu
	($key,$rest)=($1,$2);
	if(defined($p->{"podnames"}->{$key})){ # yup, a menu
	  # process menu here. if not a menu, its an example
	  # or Its a menu.  Save it for end of node.
	  if (0 == @delay || 'menu' ne $delay[0]) {
	    print TEXINFO "\n\@menu\n";
	    $init_node = "\@node perl, $podlist[1], Top, Top\n";
	  }
	  else {
	    print TEXINFO "\n";
	  }
	  for (@lines) {
	    m/^\s+(\w*)\t(.*)/;
	    print TEXINFO "* $1:: $2\n";
	  }
	  #print TEXINFO "\@end menu\n\n";
	  if (0 == @delay || 'menu' ne $delay[0]) {
	    push @delay, 'menu';
	  }
	  # done with menu paragraph, next paragraph
	  next;
	}
	# not a menu, process it as example
      }
      s/^$space//mg;
      if (0 == @delay || 'example' ne $delay[0]) {
	print TEXINFO "\n\@example\n";
      }
      else {
	print TEXINFO "\n";
      }
      print TEXINFO  $_;
      if (0 == @delay || 'example' ne $delay[0]) {
	push @delay, 'example';
      }
      next;
    }
    while ($out = shift @delay) {
      print TEXINFO "\@end $out\n\n";
    }
    &pre_escapes;
    $_ = &Do_refs($_,$pod);
    
    s/Z<>//g;			#  what to do with this?
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
	&close_all_lists;
	print TEXINFO "\@unnumberedsec $_\n";
      }
      elsif ($cmd eq 'head2') {
	&close_all_lists;
	print TEXINFO "\@unnumberedsubsec $_\n";
      }
      elsif ($cmd eq 'item') {
	($what,$rest)=split(' ', $_, 2);
	$what=~s/\s*$//;
	
	if ($what =~ /[*]/) {	# if a single star, axe it
	  
	  # texinfo itemize can put in its own star.
	  $_ = $rest;
	  
	  # if a single star, its a bulleted list with paragraphs - 
	  # need a newline before paragraphs if theres anything
	  # left on that line.  Else, if no star,
	  # its probably going to be a table - no newlines before paragraph
	  $next_para=1 if $rest;
	  &maybe_open_itemize;
	}
	elsif ($what =~ /^\d+\.?/) { # if digits, get rid of them ...
	  
	  # texinfo enumerate can put in its own numbers
	  $_ = $rest;
	  
	  # if a single star, its a bulleted list with paragraphs - 
	  # need a newline before paragraphs.  Else, if digits
	  # its enumerated - no newlines before paragraph
	  $next_para=0;
	  &maybe_open_enum;
	}
	else {
	  &maybe_open_table;
	}
	
	# only if we have starred items do we want to really
	# have separate items - else, two items
	# in a row is likely an itemx
	# candidate.  We will see how this goes
	
	# previously we only wanted itemx if they had the first word
	# in common (write, write FILEHANDLE, etc.)
	#		if($justdid ne $what && $what =~ /[*]/){}
	if(! $justdid ||
	   $what =~ /([*])|(\d+[.])/ ||
	   'enumerate' eq $open_lists[0]){
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
	&close_list;
	#		print TEXINFO qq|back[$_]\n|;
      }
      elsif ($cmd eq 'for') {
	($cmd, $_) = split(' ', $_, 2);
	if ($cmd eq 'texi') { # make allowances for a literal 'texi' stuff
	  print TEXINFO $_;
	}
	next; # drop otherwise
      }
      elsif ($cmd eq 'begin') {
	($cmd, $_) = split(' ', $_, 2);
	$literal = ($cmd eq 'texi');
	while (<POD>) {
	  last if /^=end\s/;
	  print TEXINFO $_ if $literal;
	}
	next;
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
}

#########################################################################


sub pre_escapes {
  s/[\@{}`']/\@$&/g;
    s/C<E<lt>E<lt>>/\@code{<<}/g;
    s/C<-E<gt>>/\@code{->}/g;
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
#	  "\n<A NAME=\"".$p->{"headers"}->{$key}."\">\n$key</A>\n"
	  $key:$key
#	    "\n$type$pod2.html\#".$p->{"headers"}->{$key}."\">$key<\/A>\n";
	}
      else{
#	(warn "No \"=item\" or \"=head\" reference for $ar[$this] in $pod\n") if $debug;
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


sub putnodeline {
  my $pnum = shift;
  my $top;

  if (0 == $pnum) {  # this is 'perl' node
    print TEXINFO "\@node Top, perl, (dir), (dir)\n";
  }
  else {
    $top = $podlist[$podnum] =~ /perlfaq\d/ ? 'perlfaq' : 'Top';
    print TEXINFO "\@node $podlist[$podnum], $podlist[$podnum + 1], $podlist[$podnum - 1], $top\n";
  }
}

sub maybe_open_itemize {
  if (defined $open_lists[0] and 'itemize' eq $open_lists[0]) {
    return;
  }
  unshift @open_lists, 'itemize';
  print TEXINFO "\@itemize \@bullet\n";
}

sub maybe_open_enum {
  if (defined $open_lists[0] and 'enumerate' eq $open_lists[0]) {
    return;
  }
  unshift @open_lists, 'enumerate';
  print TEXINFO "\@enumerate\n";
}

sub maybe_open_table {
  if (defined $open_lists[0] and 'table' eq $open_lists[0]) {
    return;
  }
  unshift @open_lists, 'table';
  print TEXINFO "\@table \@asis\n";
}

sub close_list {
  my $lname;
  if (defined ($lname = shift @open_lists)) {
    print TEXINFO "\@end $lname\n";
    return 1;
  }
  return 0;
}

sub close_all_lists {
  while ( &close_list ) {
    ;
  }
  if (defined($init_node)) {  # print this only once
    print TEXINFO $init_node;
    undef $init_node;
  }
}
