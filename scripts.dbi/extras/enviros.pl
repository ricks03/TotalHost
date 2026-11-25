#!/usr/bin/perl
# prints out an alphabetical list of all environmental variables
use CGI;
use CGI qw(:standard);

my $cgi = CGI->new;   
print $cgi->header();

print "<html><body>";
foreach (sort(keys %ENV)) { print "$_: $ENV{$_}<br>\n"; } 

# if ($ENV{'CONTENT_LENGTH'}) 
# { print "&lt;STDIN&gt;: ", <STDIN>, "<br>\n"; }
print "****************************\n\n";

print "<center><h3>here's a list of your environmental variables</h3></center>\n";
print "<code><ul>";
@keys = sort(keys(%ENV));  
foreach $key (@keys){ print "<li> ", $key, " = ", $ENV{$key},"\n";}
print "</ul></code>";

print "</body></html>\n";


