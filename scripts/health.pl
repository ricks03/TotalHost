#!/usr/bin/env perl

print "Content-Type: text/html\n\n";
print "<p>healthy</p>\n";

print "<p>checking local package import</p>\n";
use StarsConfig;

print "<p>Platform: $^O</p>\n";

print "<p>Environment variables:</p>\n";
print "<table>\n";
print "<tr><th>Key</th><th>Value</th></tr>\n";
foreach $key (sort keys(%ENV)) {
  print "<tr><td><pre>$key</pre></td><td><pre>$ENV{$key}</td></pre></tr>\n";
}
print "</table>\n";