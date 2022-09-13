#!/usr/bin/env perl

use Data::Dumper;

print "Content-Type: text/html\n\n";
print "<p>healthy</p>\n";

print "<p>checking local package import</p>\n";
use StarsConfig;

my $config = new StarsConfig();
print "<p>Database enabled: "+$config->isFeatureLive("database")+"</p>\n";

print "<p>Platform: $^O</p>\n";

print <<eop;
<p>Config values:</p>
<table>
  <tr><th>Key</th><th>Value</th></tr>
  <tr><td>Is Windows</td><td>${\($config->isWindows())}</td></tr>
  <tr><td>HTML Root</td><td>${\($config->htmlRoot())}</td></tr>
</table>
eop

print "<p>Environment variables:</p>\n";
print "<table>\n";
print "<tr><th>Key</th><th>Value</th></tr>\n";
foreach $key (sort keys(%ENV)) {
  print "<tr><td><pre>$key</pre></td><td><pre>$ENV{$key}</td></pre></tr>\n";
}
print "</table>\n";