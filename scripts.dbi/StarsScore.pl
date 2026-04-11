#!/usr/bin/perl
# StarsScore.pl
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
#

# Gets Player Scores
# Example Usage: StarsScore.pl c:\stars\game.m1
#
# Gets the values from a  .m file  (not in .hst files)
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;  
use FindBin;
use lib $FindBin::Bin;
 
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "Displays Turn and score information (for the most recent turn in multi-year files)\n";
  print "\nUsage: StarsScore.pl <input file>\n\n";
  print "Please enter the input file (.m). Example: \n";
  print "  StarsScore.pl c:\\games\\test.m1\n\n";
  print "Entering the .hst file will return all the scores from the .m files\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
$dir =~ s/\\/\//g;  # normalize to forward slashes
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1
if (lc($ext) =~ /[x]/ || lc($ext) =~ /r/) { print "R & X files do not include score information\n"; exit; }

if (lc($ext) =~ /hst/) {
  my $gameDir = dirname($filename);
  $gameDir =~ s|\\|/|g;
  my ($gameName) = $basefile =~ /^([^.]+)/;
  my @mFiles;
  opendir(my $dh, $gameDir) or die "Cannot open $gameDir: $!\n";
  push @mFiles, map { "$gameDir/$_" } grep { /^$gameName\.m([1-9]|1[0-6])$/i } readdir($dh);
  closedir($dh);
  my $total = scalar(@mFiles);
  print "Found $total .m file(s) for $gameName in $gameDir\n\n";
  for my $mFile (sort @mFiles) {
    my @fileBytes;
    my $FileValues;
    open(my $StarFile, "<", $mFile) or die "Cannot open $mFile: $!\n";
    binmode($StarFile);
    while (read($StarFile, $FileValues, 1)) { push @fileBytes, $FileValues; }
    close($StarFile);
    &decryptScores2(&lastTurnBytes(@fileBytes));  }
  exit;
}

# Read in the binary Stars! file, byte by byte
my $FileValues;
my @fileBytes;
open(StarFile, "<$filename");
binmode(StarFile);
while (read(StarFile, $FileValues, 1)) {
  push @fileBytes, $FileValues; 
}
close(StarFile);

# Decrypt the data, block by block
my ($outBytes) = &decryptScores2(&lastTurnBytes(@fileBytes));
my @outBytes = @{$outBytes};

################################################################
sub decryptScores2 {
  my (@fileBytes) = @_;
  my @block;
  #my @data;
  my ($decryptedData, $padding);
  my @decryptedData;
  #my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt);
  my ($seedA, $seedB);
  my ($FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    #@data   = @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    my @data = @block[2..$#block];
    
    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    if ($typeId == 8) { # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 45) { # PlayerScoresBlock
        my $scorex = &read16(\@decryptedData, 0);
        my $playerId            = ($scorex >> 0) & 0x1F;  # bits 0-4 (5 bits)
        my $fValid              = ($scorex >> 5) & 0x01;  # bit 5  #indicates whether the score data is valid for this player.
        my $grbitVC             = ($scorex >> 6) & 0xFF;  # bits 6-13 (8 bits) See Individual victory conditions
        my $fWinner             = ($scorex >> 14) & 0x01; # bit 14 
        my $fHistory            = ($scorex >> 15) & 0x01; # bit 15; 
        
        # Individual victory condition flags from grbitVC (based on defines.h)
        my $vcPlanetControl = ($grbitVC >> 0) & 0x01;  # vcPlanetControl = 0
        my $vcTechLevel     = ($grbitVC >> 1) & 0x01;  # vcTechLevel = 1
        my $vcTechFields    = ($grbitVC >> 2) & 0x01;  # vcTechFields = 2
        my $vcScore         = ($grbitVC >> 3) & 0x01;  # vcScore = 3
        my $vcScoreExcess   = ($grbitVC >> 4) & 0x01;  # vcScoreExcess = 4 
        my $vcProduction    = ($grbitVC >> 5) & 0x01;  # vcProduction = 5
        my $vcLargeShips    = ($grbitVC >> 6) & 0x01;  # vcLargeShips = 6 , capital ships
        my $vcTurns         = ($grbitVC >> 7) & 0x01;  # vcTurns = 7 Highest score
                
        my $rankOrTurn   = &read16(\@decryptedData, 2); # The same two bytes mean different things depending on $fHistory
        my $score        = &read32(\@decryptedData, 4);  # Not exactly the same
        my $resources    = &read32(\@decryptedData, 8); # Not EXACTLY the same
        my $planets      = &read16(\@decryptedData, 12);
        my $starbases    = &read16(\@decryptedData, 14);   
        my $unarmedShips = &unpackWord(&read16(\@decryptedData, 16));  # to properly unpack the ship counts, handling both small counts (< 8192, where exponent = 0) and large counts (= 8192, where the value is compressed).
        my $escortShips  = &unpackWord(&read16(\@decryptedData, 18));    
        my $capitalShips = &unpackWord(&read16(\@decryptedData, 20));
        my $techLevels   = &read16(\@decryptedData, 22);
        
        my $rankLabel = $fHistory ? "histTurn:$rankOrTurn" : "rank:$rankOrTurn";
        print "Turn:" . ($turn+2400) . ", Player:" . ($playerId+1) . ",planets:$planets,Starbases:$starbases,unarm:$unarmedShips,escort:$escortShips,Cap:$capitalShips,Tech:$techLevels,Resources:$resources,score:$score,$rankLabel\n";
        print "\tVICTORY: planet:$vcPlanetControl,techlevel:$vcTechLevel,techfields:$vcTechFields,score:$vcScore,2nd:$vcScoreExcess,prod:$vcProduction,cap:$vcLargeShips,turns:$vcTurns\n";
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub lastTurnBytes {
  my (@fileBytes) = @_;
  my $offset = 0;
  my $lastBlock8Offset = 0;
  my ($typeId, $size, $FileValues);
  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    if ($typeId == 8) { $lastBlock8Offset = $offset; }
    $offset = $offset + (2 + $size);
  }
  return @fileBytes[$lastBlock8Offset .. $#fileBytes];
}