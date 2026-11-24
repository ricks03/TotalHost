#!/usr/bin/perl
# StarsMax.pl
# Maximise a player: set all tech to 26, grant all MT parts,
# set homeworld to max surface minerals, mines, factories, defenses,
# and population.
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 260414  Version 1.0
#
#     Copyright (C) 2026 Rick Steeves
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
#
# Sets for a single player:
#   Tech levels: all six set to 26 (MAXTECHLEVEL)
#   Research points spent: all zeroed (tech registers as complete)
#   Mystery Trader parts: all 13 granted (grbitTraderAll = 0x1FFF)
#   Homeworld surface minerals: 10000 each (ironium, boranium, germanium)
#   Homeworld population: 1,000,000 (standard), 1,200,000 (JOAT),
#                         1,100,000 (Basic Remote Mining), 1,320,000 (both)
#   Homeworld mines and factories: 2048 each
#   Homeworld defenses: 100
#
# Always processes both the .hst and the matching .mN file.
# The .hst is authoritative for future turn generation.
# The .mN updates what the player sees in the current turn.
#
# Derived from StarsBlock.pm / TotalHost conventions.

use strict;
use warnings;
use File::Basename;
use FindBin;
use lib $FindBin::Bin;
use StarsBlock;

my $filename  = $ARGV[0];
my $playerArg = $ARGV[1]; # 1-based, required when input is .hst

unless ($filename) {
  print "\n\nUsage: StarsMax.pl <game.hst|game.mN> [playerN]\n\n";
  print "Given a .hst file: playerN is required (1-based).\n";
  print "Given a .m file:   player is derived from the file extension.\n\n";
  print "Sets for the specified player:\n";
  print "  All six tech levels to 26\n";
  print "  All 13 Mystery Trader parts\n";
  print "  Homeworld surface minerals to 10000 each\n";
  print "  Homeworld population to race maximum\n";
  print "  Homeworld mines and factories to 2048\n";
  print "  Homeworld defenses to 100\n\n";
  print "Both the .hst and the matching .mN file are updated.\n";
  print "Output files are named <filename>.max -- rename to replace the originals.\n\n";
  print "As always, back up your files before running any tool.\n";
  exit;
}

unless (-f $filename) { print "File $filename does not exist!\n"; exit; }

my ($prefix, $dir, $ext) = fileparse($filename, qr/\.[^.]*/);
$dir =~ s/\\/\//g;

my $targetPlayer; # 0-based

if ($ext =~ /^\.[mM](\d+)$/) {
  $targetPlayer = $1 - 1;
  print "Derived player " . ($targetPlayer+1) . " from file extension $ext\n\n";
} elsif ($ext =~ /^\.hst$/i) {
  unless (defined $playerArg && $playerArg =~ /^\d+$/ && $playerArg >= 1) {
    print "A player number (1-based) is required for .hst files.\n";
    print "Example: StarsMax.pl game.hst 3\n";
    exit;
  }
  $targetPlayer = $playerArg - 1;
} else {
  print "Input must be a .hst or .mN file, got '$ext'\n";
  exit;
}

my $hstFile = $dir . $prefix . '.hst';
my $mFile   = $dir . $prefix . '.m' . ($targetPlayer + 1);

print "Player : " . ($targetPlayer+1) . "\n";
print "HST    : $hstFile\n";
print "M file : $mFile\n\n";

&processFile($hstFile, $targetPlayer);
&processFile($mFile,   $targetPlayer);

print "\nDone.\n";

########################################
sub processFile {
  my ($filename, $targetPlayer) = @_;

  unless (-f $filename) {
    print "Skipping $filename -- file not found\n";
    return;
  }

  print "Processing: $filename\n";

  my @fileBytes = &readFile($filename);

  my ($outBytes, $changed) = &decryptMax(\@fileBytes, $targetPlayer);
  my @outBytes = @{$outBytes};

  if ($changed) {
    my $outFile = $filename . '.max';
    open(OUTFILE, '>:raw', $outFile) or die "Cannot write $outFile: $!\n";
    for my $b (@outBytes) { print OUTFILE $b; }
    close(OUTFILE);
    print "  Output : $outFile\n";
    print "  Rename to " . basename($filename) . " to replace the original.\n";
  } else {
    print "  No changes made -- player " . ($targetPlayer+1) .
          " block not found or not fully decoded in this file.\n";
  }
}