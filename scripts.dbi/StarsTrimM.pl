#!/usr/bin/perl
# StarsTrimM.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 200526  Version 1.0
#     Copyright (C) 2019 Rick Steeves
# 
#     This file is part of TotalHost, a Stars! hosting utility.
#     TotalHost is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Strips all but the last turn from a Stars! .m file with fMulti set.
#   Useful for storage and cleanup. 
# Example Usage: StarsTrimM.pl c:\stars\game.m1
#
# Usage: StarsTrimM.pl <input.m#> [output.m#]
# If no output file given, creates <input.m#>.stripped
# Usage: StarsTrimM.pl <input.m#|game.hst>
# If a .hst file is given, strips all .m files in the folder and year subfolders.

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use File::Basename;
use StarsBlock;
use StarStat;

my $filename    = $ARGV[0];
my $outFileName = $ARGV[1];

unless ($filename) {
  print "\nUsage: StarsTrimM.pl <input .m file | game.hst> [output file]\n\n";
  print "Strips all but the last turn from a multi-turn .m file,\n";
  print "clears the fMulti flag, and writes the result.\n";
  print "If a .hst file is given, processes all .m files in the folder\n";
  print "and year subfolders (2400, 2401, etc), overwriting in place.\n\n";
  print "If a single .m file and no output given, creates <input>.stripped\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

unless (-e $filename) { print "File $filename does not exist!\n"; exit; }

my $basefile = basename($filename);
my ($gameName, $file_player, $file_type, $file_ext) = &FileData($basefile);

# Single .m file mode
if ($file_type =~ /^m$/i && $file_player >= 1 && $file_player <= 16) {
  &trimM($filename, $outFileName, 1);
  exit;
}

# .hst batch mode - process all matching .m files in root and year subfolders
if ($file_type =~ /hst/i) {
  my $gameDir = dirname($filename);
  $gameDir =~ s|\\|/|g;  # normalize to forward slashes
  my @mFiles;
  
  opendir(my $dh, $gameDir) or die "Cannot open $gameDir: $!\n";
  my @entries = readdir($dh);
  closedir($dh);

  # Get .m files in root directory
  push @mFiles, map { "$gameDir/$_" } grep { /^$gameName\.m([1-9]|1[0-6])$/i } @entries;

  # Get .m files in year subdirectories
  my @yearDirs = grep { /^\d{4}$/ && -d "$gameDir/$_" } @entries;
  for my $yearDir (@yearDirs) {
    opendir(my $ydh, "$gameDir/$yearDir") or next;
    push @mFiles, map { "$gameDir/$yearDir/$_" } grep { /^$gameName\.m([1-9]|1[0-6])$/i } readdir($ydh);
    closedir($ydh);
  }
  for my $yearDir (@yearDirs) {
    opendir(my $ydh, "$gameDir/$yearDir") or next;
    push @mFiles, map { "$gameDir/$yearDir/$_" } grep { /\.m\d+$/i } readdir($ydh);
    closedir($ydh);
  }  
  my $total = scalar(@mFiles);
  print "Found $total .m file(s) under $gameDir\n\n";
  for my $mFile (sort @mFiles) {
    &trimM($mFile, $mFile, 1);  # overwrite in place
  }
  exit;
}

print "Error: $filename does not appear to be a .m1 to .m16 or .hst file.\n"; 
exit;