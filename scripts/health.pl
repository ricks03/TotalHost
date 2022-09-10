#!/usr/bin/env perl

print "Content-Type: text/html\n\n";
print '<p>healthy</p>';

print '<p>checking local package import</p>';
use StarsConfig;

print "<p>Environment variables:</p>";
print "<pre>\n";

foreach $key (sort keys(%ENV)) {
  print "$key = $ENV{$key}<p>";
}
print "</pre>\n";