package re::engine::PCRE2;
our $VERSION = '0.09';
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

use 5.010;
use strict;
use XSLoader ();

# All engines should subclass the core Regexp package
our @ISA = 'Regexp';

XSLoader::load(__PACKAGE__, $XS_VERSION);

# set'able via import
our @CONTEXT_OPTIONS = qw(
  bsr max_pattern_length newline parens_nest_limit
  match_limit offset_limit recursion_limit
);

# TODO: set context options, and save prev. ones for unimport.
# compile-ctx and match-ctx (see above: @CONTEXT_OPTIONS)
sub import {
  $^H{regcomp} = re::engine::PCRE2::ENGINE();
}

sub unimport {
  delete $^H{regcomp} if $^H{regcomp} == re::engine::PCRE2::ENGINE();
}

1;

__END__
=encoding UTF-8

=head1 NAME 

re::engine::PCRE2 - PCRE2 regular expression engine with jit

=head1 SYNOPSIS

    use re::engine::PCRE2;

    if ("Hello, world" =~ /(?<=Hello|Hi), (world)/) {
        print "Greetings, $1!";
    }

=head1 DESCRIPTION

Replaces perl's regex engine in a given lexical scope with PCRE2
regular expressions provided by libpcre2-8.

This provides jit support and faster matching, but may fail in corner
cases. See
L<pcre2compat|http://www.pcre.org/current/doc/html/pcre2compat.html>.
It is typically 40% faster than the core regex engine. See L</BENCHMARKS>.

The goal is to pass the full core re testsuite, identify all
problematic patterns and fall-back to the core re engine.  From the
1330 core tests, 46 currently fail. 90% of the most popular cpan
modules do work fine already. Note that older perl version do fail
more regression tests. See L</FAILING TESTS>.

Note that some packaged libpcre2-8 libraries do not enable the jit
compiler. C<CFLAGS=-fPIC cmake -DPCRE2_SUPPORT_JIT=ON; make>
PCRE2 then silently falls back to the normal PCRE2 compiler and matcher.

Check with:

  perl -Mre::engine::PCRE2 -e'print re::engine::PCRE2::JIT'

=head1 METHODS

Since re::engine::PCRE2 derives from the C<Regexp> package, you can call
compiled C<qr//> objects with these methods.
See L<PCRE2 NATIVE API MATCH CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC5>
and L<INFORMATION ABOUT A COMPILED PATTERN|http://www.pcre.org/current/doc/html/pcre2api.html#SEC22>.

With older library versions which do not support a particular info method, undef is returned.
E.g. hasbackslashc and framesize.

=over

=item match_limit (RX, [INT])

Get or set the match_limit match context. NYI

=item offset_limit (RX, [INT])

NYI

=item recursion_limit (RX, [INT])

NYI

=item _alloptions (RX)

The result of pcre2_pattern_info(PCRE2_INFO_ALLOPTIONS) as unsigned integer.

   my $q=qr/(a)/; print $q->_alloptions
   => 64

64 stands for PCRE2_DUPNAMES which is always set. See F<pcre2.h>

=item _argoptions (RX)

The result of pcre2_pattern_info(PCRE2_INFO_ARGOPTIONS) as unsigned integer.

   my $q=qr/(a)/i; print $q->_argoptions
   => 72

72 = 64+8
64 stands for PCRE2_DUPNAMES which is always set.
8 for PCRE2_CASELESS.
See F<pcre2.h>

=item backrefmax (RX)

Return the number of the highest back reference in the pattern.

  my $q=qr/(a)\1/; print $q->backrefmax
  => 1
  my $q=qr/(a)(?(1)a|b)/; print $q->backrefmax
  => 1

=item bsr (RX)

What character sequences the C<\R> escape sequence matches.
1 means that C<\R> matches any Unicode line ending sequence;
2 means that C<\R> matches only CR, LF, or CRLF.

=item capturecount (RX)

Return the highest capturing subpattern number in the pattern. In
patterns where C<(?|> is not used, this is also the total number of
capturing subpatterns.

  my $q=qr/(a(b))/; print $q->capturecount
  => 2

=item firstbitmap (RX)

In the absence of a single first code unit for a non-anchored pattern,
C<pcre2_compile()> may construct a 256-bit table that defines a fixed set
of values for the first code unit in any match. For example, a pattern
that starts with C<[abc]> results in a table with three bits set. When
code unit values greater than 255 are supported, the flag bit for 255
means "any code unit of value 255 or above". If such a table was
constructed, it is returned as string.

=item firstcodetype (RX)

Return information about the first code unit of any matched string,
for a non-anchored pattern. If there is a fixed first value, for
example, the letter "c" from a pattern such as C<(cat|cow|coyote)>, 1
is returned, and the character value can be retrieved using
L</firstcodeunit>. If there is no fixed first value, but it is known
that a match can occur only at the start of the subject or following a
newline in the subject, 2 is returned. Otherwise, and for anchored
patterns, 0 is returned.

=item firstcodeunit (RX)

Return the value of the first code unit of any matched string in the
situation where L</firstcodetype (RX)> returns 1; otherwise return
0. The value is always less than 256.

  my $q=qr/(cat|cow|coyote)/; print $q->firstcodetype, $q->firstcodeunit
  => 1 99

=item framesize (RX)

Undocumented. Only available since pcre-10.24.
Returns undef on older versions.
The pcre2_match() frame size.

=item hasbackslashc (RX)

Return 1 if the pattern contains any instances of \C, otherwise 0.
Note that \C is forbidden since perl 5.26 (?).
With an older pcre2 library undef might be returned.

=item hascrorlf (RX)

Return 1 if the pattern contains any explicit matches for CR or LF
characters, otherwise 0. An explicit match is either a literal CR or LF
character, or \r or \n.

=item jchanged (RX)

Return 1 if the (?J) or (?-J) option setting is used in the pattern,
otherwise 0. (?J) and (?-J) set and unset the local PCRE2_DUPNAMES
option, respectively.

=item jitsize (RX)

If the compiled pattern was successfully processed by
pcre2_jit_compile(), return the size of the JIT compiled code,
otherwise return zero.

=item lastcodetype (RX)

Returns 1 if there is a rightmost literal code unit that must exist in
any matched string, other than at its start. If there is no such value, 0 is
returned. When 1 is returned, the code unit value itself can be
retrieved using L</lastcodeunit (RX)>. For anchored patterns, a last
literal value is recorded only if it follows something of variable
length. For example, for the pattern C</^a\d+z\d+/> the returned value is
1 (with "z" returned from lastcodeunit), but for C</^a\dz\d/>
the returned value is 0.

=item lastcodeunit (RX)

Return the value of the rightmost literal data unit that must exist in
any matched string, other than at its start, if such a value has been
recorded. If there is no such value, 0 is returned.

=item matchempty (RX)

Return 1 if the pattern might match an empty string, otherwise 0. When
a pattern contains recursive subroutine calls it is not always
possible to determine whether or not it can match an empty
string. PCRE2 takes a cautious approach and returns 1 in such cases.

=item matchlimit (RX)

If the pattern set a match limit by including an item of the form
(*LIMIT_MATCH=nnnn) at the start, the value is returned.

=item maxlookbehind (RX)

Return the number of characters (not code units) in the longest
lookbehind assertion in the pattern. This information is useful when
doing multi-segment matching using the partial matching
facilities. Note that the simple assertions \b and \B require a
one-character lookbehind. \A also registers a one-character
lookbehind, though it does not actually inspect the previous
character. This is to ensure that at least one character from the old
segment is retained when a new segment is processed. Otherwise, if
there are no lookbehinds in the pattern, \A might match incorrectly at
the start of a new segment.

=item minlength (RX)

If a minimum length for matching subject strings was computed, its
value is returned. Otherwise the returned value is 0. The value is a
number of characters, which in UTF mode may be different from the
number of code units. The value is a lower bound to the length of any
matching string. There may not be any strings of that length that do
actually match, but every string that does match is at least that
long.

=item namecount (RX)

=item nameentrysize (RX)

PCRE2 supports the use of named as well as numbered capturing
parentheses. The names are just an additional way of identifying the
parentheses, which still acquire numbers. Several convenience
functions such as pcre2_substring_get_byname() are provided for
extracting captured substrings by name. It is also possible to extract
the data directly, by first converting the name to a number in order
to access the correct pointers in the output vector. To do the
conversion, you need to use the name-to-number map, which is described
by these three values.

The map consists of a number of fixed-size
entries. namecount gives the number of entries, and
nameentrysize gives the size of each entry in code units;
The entry size depends on the length of the longest name.

The nametable itself is not yet returned.

=item newline (RX)

Returns the newline regime, see below at L</config (OPTION)>.

=item recursionlimit (RX)

If the pattern set a recursion limit by including an item of the form
(*LIMIT_RECURSION=nnnn) at the start, the value is returned.

=item size (RX)

Return the size of the compiled pattern in bytes.  This value includes
the size of the general data block that precedes the code units of the
compiled pattern itself. The value that is used when
C<pcre2_compile()> is getting memory in which to place the compiled
pattern may be slightly larger than the value returned by this option,
because there are cases where the code that calculates the size has to
over-estimate. Processing a pattern with the JIT compiler does not
alter the value returned by this option.

=back

=head1 FUNCTIONS

=over

=item import

import lexically sets the PCRE2 engine to be active.

import will later accept compile context options.
See L<PCRE2 NATIVE API COMPILE CONTEXT FUNCTIONS|http://www.pcre.org/current/doc/html/pcre2api.html#SEC4>.

  bsr => INT
  max_pattern_length => INT
  newline => INT
  parens_nest_limit => INT

  match_limit => INT
  offset_limit => INT
  recursion_limit => INT

=item unimport

unimport sets the regex engine to the previous one.
If PCRE2 with the previous context options.

=item ENGINE

Returns a pointer to the internal PCRE2 engine, suitable for the
XS API C<<< (regexp*)re->engine >>> field.

=item JIT

Returns 1 or 0, if the JIT engine is available or not.

=item config (OPTION)

Returns build-time information about libpcre2.
Note that some of these options may later be set'able at run-time.

OPTIONS can be one of the following strings:

    JITTARGET
    UNICODE_VERSION
    VERSION

    BSR
    JIT
    LINKSIZE
    MATCHLIMIT
    NEWLINE
    PARENSLIMIT
    DEPTHLIMIT      (Not always defined)
    RECURSIONLIMIT  (Obsolete synonym for DEPTHLIMIT)
    STACKRECURSE    (Obsolete. Always 0 in newer libs)
    UNICODE

The first three options return a string, the rest an integer.
In case of internal errors, e.g. the new option is not yet supported by libpcre,
undef is returned.
See L<http://www.pcre.org/current/doc/html/pcre2api.html#SEC17>.

NEWLINE returns an integer, representing:

   PCRE2_NEWLINE_CR          1
   PCRE2_NEWLINE_LF          2
   PCRE2_NEWLINE_CRLF        3
   PCRE2_NEWLINE_ANY         4  Any Unicode line ending
   PCRE2_NEWLINE_ANYCRLF     5  Any of CR, LF, or CRLF

The default is OS specific.

BSR returns an integer, representing:

   PCRE2_BSR_UNICODE         1
   PCRE2_BSR_ANYCRLF         2

A value of PCRE2_BSR_UNICODE means that C<\R> matches any Unicode line
ending sequence; a value of PCRE2_BSR_ANYCRLF means that C<\R> matches
only CR, LF, or CRLF.

The default is 1 for UNICODE, as all libpcre2 libraries are now compiled
with unicode support builtin. (C<--enable-unicode>).

=back

=head1 BENCHMARKS

    time perl5.24.1 -Mblib t/perl/regexp.t 10000 >/dev/null

Without PCRE2:

    32.572s

With PCRE2:

    19.596s - 40% faster

=head1 FAILING TESTS

About 90% of all core tests and cpan modules do work with re::engine::PCRE2
already, but there are still some unresolved problems.
Esp. when the pattern is not detectable or marked as UTF-8 but the subject is,
the match will be performed without UTF-8.

Try the new faster matcher with C<export PERL5OPT=-Mre::engine::PCRE2>.

Known problematic popular modules are: Test-Harness-3.38,
Params-Util-1.07 I<t/12_main.t 552-553, 567-568>, HTML-Parser-3.72
I<(unicode)>, DBI-1.636 I<(EUMM problem)>, DBD-SQLite-1.54
I<(xsubpp)>, Sub-Name-0.21 I<t/exotic_names.t:105>, XML-LibXML-2.0129
I<(local charset)>, Module-Install-1.18 I<unrecognized character after
(?  or (?->, Text-CSV_XS-1.28 I<(unicode)>, YAML-Syck-1.29, MD5-2.03,
XML-Parser-2.44, Module-Build-0.4222, libwww-perl-6.25.

As of 0.05 the following core regression tests still fail:

    perl -C -Mblib t/perl/regexp.t | grep -a TODO

    # new patterns and pcre2 fails: need to fallback
    143..146, # \B{gcb} \B{lb} \B{sb} \B{wb}
    352,      # '^'i:ABC:y:$&:
    402,      # '(a+|b){0,1}?'i
    409,      # 'a*'i $&
    578,      # '(b.)c(?!\N)'s:a
    654,655,664, # unicode
    667,      # '[[:^cntrl:]]+'u:a\x80:y:$&:a

    # Pathological patterns that run into run-time PCRE_ERROR_MATCHLIMIT,
    # even with huge set_match_limit 512mill
    880 .. 897, # .X(.+)+[X][X]:bbbbXXXaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

    # aba =~ ^(a(b)?)+$ and aabbaa =~ ^(aa(bb)?)+$
    941, # ^(a(b)?)+$:aba:y:-$1-$2-:-a-- => `-a-b-', match=1
    942, # ^(aa(bb)?)+$:aabbaa:y:-$1-$2-:-aa-- => `-aa-bb-', match=1
    947, # ^(a\1?){4}$:aaaaaa:y:$1:aa => `', match=

    # empty codeblock
    1005, #TODO (??{}):x:y:-:- => error `Eval-group not allowed at runtime, use re 'eval' in regex m/(??{})/ at (eval 5663) line 1.'

    # XXX: <<<>>> pattern
    1096, # ^(<(?:[^<>]+|(?3)|(?1))*>)()(!>!>!>)$:<<!>!>!>><>>!>!>!>:y:$1:<<!>!>!>><>> => `', match=
    1126, # /^(?'main'<(?:[^<>]+|(?&crap)|(?&main))*>)(?'empty')(?'crap'!>!>!>)$/:<<!>!>!>><>>!>!>!>:yM:$+{main}:<<!>!>!>><>> => `', match=

    # XXX: \R doesn't match an utf8::upgraded \x{85}, we need to
    # always convert the subject and pattern to utf-8 for these cases
    # to work
    1378, # (utf8::upgrade($subject)) foo(\R+)bar:foo\r
    1380, # (utf8::upgrade($subject)) (\R+)(\V):foo\r
    1381, # (utf8::upgrade($subject)) foo(\R)bar:foo\x{85}bar:y:$1:\x{85} => `', match=
    1382, # (utf8::upgrade($subject)) (\V)(\R):foo\x{85}bar:y:$1-$2:o-\x{85} => `�-�', match=1
    1394, # (utf8::upgrade($subject)) foo(\v+)bar:foo\r
    1396..1398, # (utf8::upgrade($subject)) (\v+)(\V):foo\r
    1405,1407..1409, # (utf8::upgrade($subject)) foo(\h+)bar:foo\t\x{A0}bar:y:$1:\t\x{A0} => `', match=

    # regressions in 5.8.x (only) introduced by change 30638
    1433, # /^\s*i.*?o\s*$/s:io
    
    1446, #/\N{}\xe4/i:\xc4:y:$&:\xc4 => error `Unknown charname '' is deprecated. Its use will be fatal in Perl 5.28 at (eval 7892) line 2.'
    1484, # /abc\N {U+41}/x:-:c:-:Missing braces => `-', match=
    1485, # /abc\N {SPACE}/x:-:c:-:Missing braces => `-', match=
    1490, # /\N{U+BEEF.BEAD}/:-:c:-: => `-', match=
    
    1495, # \c`:-:ac:-:\"\\c`\" is more clearly written simply as \"\\ \" => `-', match=
    1496, # \c1:-:ac:-:\"\\c1\" is more clearly written simply as \"q\" => `-', match=
    
    1514, # \c?:\x9F:ey:$&:\x9F => `\', match=
    
    1575, # [\8\9]:\000:Sn:-:- => `-', match=
    1576, # [\8\9]:-:sc:$&:Unrecognized escape \\8 in character class => `[', match=
    
    1582, # [\0]:-:sc:-:Need exactly 3 octal digits => `-', match=
    1584, # [\07]:-:sc:-:Need exactly 3 octal digits => `-', match=
    1585, # [\07]:7\000:Sn:-:- => `-', match=
    1586, # [\07]:-:sc:-:Need exactly 3 octal digits => `-', match=
    
    1599, # /\xe0\pL/i:\xc0a:y:$&:\xc0a => `/', match=
    
    1618, # ^_?[^\W_0-9]\w\z:\xAA\x{100}:y:$&:\xAA\x{100} => `^', match=
    1621, # /s/ai:\x{17F}:y:$&:\x{17F} => `/', match=
    
    1630, # /[^\x{1E9E}]/i:\x{DF}:Sn:-:- => `-', match=
    1639, # /^\p{L}/:\x{3400}:y:$&:\x{3400} => `�', match=1
    1642, # /[s\xDF]a/ui:ssa:Sy:$&:ssa => `sa', match=1
    
    1648, # /ff/i:\x{FB00}\x{FB01}:y:$&:\x{FB00} => `/', match=
    1649, # /ff/i:\x{FB01}\x{FB00}:y:$&:\x{FB00} => `/', match=
    1650, # /fi/i:\x{FB01}\x{FB00}:y:$&:\x{FB01} => `/', match=
    1651, # /fi/i:\x{FB00}\x{FB01}:y:$&:\x{FB01} => `/', match=

    # These test that doesn't cut-off matching too soon in the string for
    # multi-char folds
    1669, # /ffiffl/i:abcdef\x{FB03}\x{FB04}:y:$&:\x{FB03}\x{FB04} => `/', match=
    1670, # /\xdf\xdf/ui:abcdefssss:y:$&:ssss => `/', match=
    1672, # /st/i:\x{DF}\x{FB05}:y:$&:\x{FB05} => `/', match=
    1673, # /ssst/i:\x{DF}\x{FB05}:y:$&:\x{DF}\x{FB05} => `/', match=
    # [perl #101970]
    1678, # /[[:lower:]]/i:\x{100}:y:$&:\x{100} => `/', match=
    1679, # /[[:upper:]]/i:\x{101}:y:$&:\x{101} => `/', match=
    # Was matching 'ss' only and failing the entire match, not seeing the
    # alternative that would succeed
    1683, # /s\xDF/ui:\xDFs:y:$&:\xDFs => `/', match=
    1684, # /sst/ui:s\N{LATIN SMALL LIGATURE ST}:y:$&:s\N{LATIN SMALL LIGATURE ST} => `/', match=
    1685, # /sst/ui:s\N{LATIN SMALL LIGATURE LONG S T}:y:$&:s\N{LATIN SMALL LIGATURE LONG S T} => `/', match=
    
    # [perl #111400].  Tests the first Y/N boundary above 255 for each of these.
    1699, # /[[:alnum:]]/:\x{2c1}:y:-:- => `-', match=
    1701, # /[[:alpha:]]/:\x{2c1}:y:-:- => `-', match=
    1703, # /[[:graph:]]/:\x{377}:y:-:- => `-', match=
    1706, # /[[:lower:]]/:\x{101}:y:-:- => `-', match=
    1708, # /[[:print:]]/:\x{377}:y:-:- => `-', match=
    1711, # /[[:punct:]]/:\x{37E}:y:-:- => `-', match=
    1713, # /[[:upper:]]/:\x{100}:y:-:- => `-', match=
    1715, # /[[:word:]]/:\x{2c1}:y:-:- => `-', match=

    # $^N, $+ on backtrackracking
    # BRANCH
    1739, # ^(.)(?:(..)|B)[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    # TRIE
    1741, # ^(.)(?:BC(.)|B)[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    # CURLYX
    1743, # ^(.)(?:(.)+)*[BX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    # CURLYM
    1746, # ^(.)(BC)*[BX]:ABCDE:y:$^N-$+:A-A => `-', match=1
    # CURLYN
    1749, # ^(.)(B)*.[CX]:ABCDE:y:$^N-$+:A-A => `-', match=1

    # [perl #114220]
    1793, # (utf8::upgrade($subject)) /[\H]/:\x{BF}:y:$&:\xBF => `�', match=1
    1794, # (utf8::upgrade($subject)) /[\H]/:\x{A0}:n:-:- => false positive
    1795, # (utf8::upgrade($subject)) /[\H]/:\x{A1}:y:$&:\xA1 => `�', match=1

    # \W in pattern -> !UTF8: add UTF if subject is UTF8 [#15]
    1804..1807, # \w:\x{200C}:y:$&:\x{200C} => `\', match=
    #1805, # \W:\x{200C}:n:-:- => false positive
    #1806, # \w:\x{200D}:y:$&:\x{200D} => `\', match=
    #1807, # \W:\x{200D}:n:-:- => false positive
    
    # again missing UTF [#15]
    1818..1820, # /^\D{11}/a:\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}\x{10FFFF}:n:-:- => false positive
    1823, # (utf8::upgrade($subject)) \Vn:\xFFn/:y:$&:\xFFn => `�n', match=1
    1830, # a?\X:a\x{100}:y:$&:a\x{100} => `a�', match=1
    1892, # /^\S+=/d:\x{3a3}=\x{3a0}:y:$&:\x{3a3}= => `Σ=', match=1
    1893, # /^\S+=/u:\x{3a3}=\x{3a0}:y:$&:\x{3a3}= => `Σ=', match=1
    1936, # /[a-z]/i:\N{KELVIN SIGN}:y:$&:\N{KELVIN SIGN} => `/', match=
    1937, # /[A-Z]/ia:\N{KELVIN SIGN}:y:$&:\N{KELVIN SIGN} => `/', match=
    1939, # /[A-Z]/i:\N{LATIN SMALL LETTER LONG S}:y:$&:\N{LATIN SMALL LETTER LONG S} => `/', match=
    
    1964, # \N(?#comment){SPACE}:A:c:-:Missing braces on \\N{} => `-', match=
    1983, # /(?xx:[a b])/x:\N{SPACE}:n:-:- => false positive
    1985, # /(?xx)[a b]/x:\N{SPACE}:n:-:- => false positive

    # [perl #125825]
    1945, # /(a+){1}+a/:aaa:n:-:- => false positive
    
    # [perl 128420] recursive matches
    1976, # aa$|a(?R)a|a:aaa:y:$&:aaa => `a', match=1

Note that core tests suite also reveals that about a similar number of
fails occur with older perls, without PCRE2. Many of them pass with PCRE2.

B<Failures in older perls>:

    -5.12:  629, 1367 (fatal)
    -5.10:  40..51, 90..91, 93..94, 96..97, 105, 356, 539,
            541, 543, 577, 1360, 1416, 1418, 1456..1457,
            1461..1462
    -5.12:  1448, 1521, 1524, 1577..1578, 1594..1596,
            1598, 1674..1675
    -5.14:  1633..1634
    -5.16:  871, 1745, 1789, 1816
    -5.18:  1674..1675, 1856..1857, 1885..1886, 1889
    -5.20:  138..142
    -5.22:  139, 1958, 1965
    -5.24:  1977

Invalid tests for older perls (fatal):

    -5.14: 1684..1996
    -5.20: 1896..1996
    -5.26: 1981..1996

=head1 AUTHORS

Reini Urban <rurban@cpan.org>

=head1 COPYRIGHT

Copyright 2007 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.
Copyright 2017 Reini Urban.

The original version was copyright 2006 Audrey Tang
E<lt>cpan@audreyt.orgE<gt> and Yves Orton.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
