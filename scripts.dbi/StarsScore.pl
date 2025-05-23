#!/usr/bin/perl
# StarsScore.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 200526  Version 1.0
# Not presently working
#
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

#
# Gets Player Scores
# Example Usage: StarsScore.pl c:\stars\game.m1
#
# Gets the values from a  .m file  (not in .hst files)
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsScore.pl <input file>\n\n";
  print "Please enter the input file (.m). Example: \n";
  print "  StarsScore.pl c:\\games\\test.m1\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1
if (lc($ext) =~ /[x]/ || lc($ext) =~ /[hst]/) { print "X & HST files do not include score information\n"; exit; }

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
my ($outBytes) = &decryptBlockScore(@fileBytes);
#my ($outBytes) = &decryptBlockScore();
#my @outBytes = @{$outBytes};


################################################################
sub decryptBlockScore {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  #my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    if ($typeId == 8) { # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      #push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      #push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 45) { # PlayerScoresBlock
        #if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        #if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        my $playerId     = ($decryptedData[0] >> 0) & 0x0F; 
        my $unk4                = ($decryptedData[0] >> 4) & 0x01; 
        my $unk5                = ($decryptedData[0] >> 5) & 0x01;  # something here
        my $victoryPlanets      = ($decryptedData[0] >> 6) & 0x01; #Correct
        my $victoryTech         = ($decryptedData[0] >> 7) & 0x01; #Correct
        my $victoryScore        = ($decryptedData[1] >> 0) & 0x01; #Correct
        my $victorySecondPlace  = ($decryptedData[1] >> 1) & 0x01; #Correct
        my $victoryProduction   = ($decryptedData[1] >> 2) & 0x01; #Correct
        my $victoryCapital      = ($decryptedData[1] >> 3) & 0x01; #Correct
        my $victoryHighestScore = ($decryptedData[1] >> 4) & 0x01; #Correct
        my $unk1                = ($decryptedData[1] >> 5) & 0x01; 
        my $unk2                = ($decryptedData[1] >> 6) & 0x01;   # something here
        my $unk3                = ($decryptedData[1] >> 7) & 0x01; 
        my $rank         = &read16(\@decryptedData, 2);
        my $score        = &read32(\@decryptedData, 4);  # Not exactly the same
        my $resources    = &read32(\@decryptedData, 8); # Not EXACTLY the same
        my $planets      = &read16(\@decryptedData, 12);
        my $starbases    = &read16(\@decryptedData, 14);   
        my $unarmedShips = &read16(\@decryptedData, 16);
        my $escortShips  = &read16(\@decryptedData, 18);    
        my $capitalShips = &read16(\@decryptedData, 20);
        my $techLevels   = &read16(\@decryptedData, 22);
        print "Turn:" . ($turn+2400) . ", Player:$playerId, planets:$planets, Starbases:$starbases, unarm:$unarmedShips, escort:$escortShips, Cap:$capitalShips, Tech:$techLevels, Res: $resources, score:$score,rank:$rank\n";
        print "\tVICTORY: planet:$victoryPlanets,tech:$victoryTech,score:$victoryScore,2nd:$victorySecondPlace,prod:$victoryProduction,cap:$victoryCapital,highest:$victoryHighestScore,UNK:$unk1,$unk2,$unk3,$unk4,$unk5\n";
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  #return \@outBytes;
}

