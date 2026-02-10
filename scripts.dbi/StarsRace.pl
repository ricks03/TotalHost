#!/usr/bin/perl
# StarsRace.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
# 191123 Version 1.1 mostly working to display all race info
# 260209 Version 1.2 also calculates leftover points
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
# Gets Race attributes
# Example Usage: StarsRace.pl c:\stars\game.m1
#
# Gets the values from a Race File
# Note that the race file has a checksum value.
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#
# This is integrated into TotalHost StarsBlock. Don't get them out of sync.

use strict;
use warnings;   
#use warnings::unused; 
use FindBin;
use lib $FindBin::Bin;
  
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my @singularRaceName;
my @pluralRaceName;
my $playerId;
my @aiSkill = qw(Easy Standard Harder Expert);
my @aiRace = qw( HE SS IS CA PP AR Inactive/Expansion);
        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsRace.pl <input file>\n\n";
  print "Please enter the input file (.r|.m|.hst). Example: \n";
  print "  StarsRace.pl c:\\games\\test.r1\n\n";
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

# There is not race information in these files
#if ($ext =~ /[xX]/ || uc($ext) =~ /\.H\d/ ) { print "This file does not include race information\n"; exit; }
if ($ext =~ /[xX]/ ) { print "This file does not include race information\n"; exit; }

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
my ($outBytes) = &decryptBlockRace(@fileBytes);
if ($outBytes) {
  my @outBytes = @{$outBytes};
  print "*** Race File Corruption detected*******\n";
  # Create the output file name
  my $newFile; 
  $newFile = "$dir/$basefile.fixed"; 
  
  # Output the Stars! File with fixed checksum
  open (OUTFILE, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OUTFILE $outBytes[$i];
  }
  close (OUTFILE);
  
  print "Fixed file: $newFile\n";
  unless ($ARGV[1] && $ARGV[1] eq $ARGV[0]) { print "\nRename\n$newFile\n to\n$filename\n"; }
}

################################################################
sub decryptBlockRace { # mostly a duplicate of displayBlockRace
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ( $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $action;
  my ($checkSum1, $checkSum2);
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 8) { # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8

      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      # If this is a race file, validate the checksum
      if (uc($ext) =~ /R/) {
        print "Race Checksum: " . join (" ", @unshiftedData), "\n"; 
        unless ($unshiftedData[0] == $checkSum1 && $unshiftedData[1] == $checkSum2 ) {
        print "***Race checksum invalid\n";
        $unshiftedData[0] = $checkSum1;
        $unshiftedData[1] = $checkSum2;
        $action = 1; 
       } else {
          print "This race file is not corrupt\n";
        }
        #shift the data back to binary
        my $shiftedData = &shiftBytes(\@unshiftedData);
        my @shiftedData = @{ $shiftedData };
        my @header = ($block[0], $block[1]); # Get the original header for the block
        unshift (@shiftedData, @header); # Prefix the shifted data with the header
        push @outBytes, @shiftedData;
      } else { 
        push @outBytes, @block;
      }
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        my $playerId; 
        my ($shipDesigns, $planets , $fleets, $starbaseDesigns, $logo);
        my ($aiEnabled, $aiRace, $aiSkill);
        my $fullDataFlag;
        my ($playerRelations, $playerRelationsLength);
        my ($singularNameLength, $singularMessageEnd, $pluralNameLength, $singularRaceName, $pluralRaceName);
        my $homeWorld; 
        my $rank;
        my ($centreGravity, $centreTemperature, $centreRadiation); 
        my ($lowGravity, $lowTemperature, $lowRadiation);
        my ($highGravity, $highTemperature, $highRadiation);
        my $growthRate;
        my ($energyLevel, $weaponsLevel, $propulsionLevel, $constructionLevel, $electronicsLevel, $biotechLevel);
        my ($energyLevelPointsSincePrevLevel, $weaponsLevelPointsSincePrevLevel, $propulsionLevelPointsSincePrevLevel); 
        my ($constructionLevelPointsSincePrevLevel, $electronicsLevelPointsSincePrevLevel, $biologyLevelPointsSincePrevLevel);
        my ($researchPercentage, $currentResourcePriority, $nextResourcePriority, $researchPointsPreviousYear);
        my ($resourcePerColonist, $producePerFactory, $toBuildFactory, $operateFactory, $producePerMine, $toBuildMine, $operateMine);
        my ($leftoverPoints, $spendLeftoverPoints);
        my ($researchEnergy, $researchWeapons, $researchProp, $researchConstruction, $researchElectronics, $researchBiotech);
        my ($PRT, $LRT); 
        my $checkBoxes; 
        my ($expensiveTechStartsAt3, $factoriesCost1LessGerm);
        my $MTItems;
        my @MTItems=();
        
        $leftoverPoints =  &advantagePointsLeft(\@decryptedData);
        $playerId = $decryptedData[0] & 0xFF; # Always 255 in a race file
        $shipDesigns = $decryptedData[1] & 0xFF; # Always 0 in race file, // for players other than the current player this is based on the number
        #$planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); # Always 0 in race file
        #$fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8); # Always 0 in race file
        $planets = &read16(\@decryptedData, 2);
        $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x0F) << 8);
        $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); # Always 0 in race file
        $logo = (($decryptedData[6] & 0xFF) >> 3); # iPlrBmp  :5,     // What picture have they chosen?
        $fullDataFlag = ($decryptedData[6] & 0x04); # Always true in race file
        # Byte 7 as 76543210
        #   Bit 0 is always 1, Bit 1 defines whether an AI is enabled :  0:off ,  1:on
        #   The 2s bit is 0 for Player, 1 for Human(inactive)
        #   bits 6,7,8 also flip changed to human(inactive)  but don't flip back
        $aiEnabled = ($decryptedData[7] >> 1) & 0x01;
        if ($aiEnabled) {
          # bits 23 defines how good the AI will be:
          $aiSkill = ($decryptedData[7] >> 2) & 0x03;  #00 - Easy, 01 - Standard, 10 - Harder, 11 - Expert
          
          # Bit 4 is always 0
          # bits 765 define which PRT AI to use: 
          # 000 - HE - Robotoids, 001 - SS - Turindromes, 010 - IS - Automitrons
          # 011 - CA - Rototills, 100 - PP - Cybertrons, 101 - AR - Macinti, 111 - Human inactive / Expansion player
          # When human is set back to active from Inactive, bit 1 flips but bits 765 aren't reset to 0
          # So the values for Byte 7 for human are 1 (active) or 225 (active again) and 227 (inactive/expansion player)
          $aiRace =  ($decryptedData[7] >> 5) & 0x07;  
        } 
        # We figure out names here, because they're here at 8 when not fullDataFlag 
        my $index = 8; 
        if ($fullDataFlag) { 
          # The player names are at the end and are not a fixed length,
          # The number of player relations bytes change where the names start   
          # That also changes whether it's a fullData set or not. 
          # PlayerRelationsLength is also number of players
          #   except when it's not. If PR has never been changed, PRL will be 0.
          $index = 112;
          $playerRelationsLength = $decryptedData[112]; 
          $index = $index + $playerRelationsLength + 1;
        }  
        $singularNameLength = $decryptedData[$index] & 0xFF;
        $singularMessageEnd = $index + $singularNameLength;
        # updated 210516
        #my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
        $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
        if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
        $singularRaceName = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        
        if ($fullDataFlag) { 
          $homeWorld = &read16(\@decryptedData, 8); # no homeworld in race file
          # BUG: the references say this is two bytes, but I don't think it is.
          # That means I don't know what byte 11 is tho. 
          # Maybe in universes with more planets?
          $rank = &read16(\@decryptedData, 10); # Always 0 in race file. Not in game file.
          # Bytes 12..15 are the password;
          # The password inverts when the player is set to Human(inactive) mode (the bits are flipped).
          # The ai password "viewai" is 238 171 77 9
          # They change to 255 255 255 255 when in Human(inactive) mode.
          $centreGravity   = $decryptedData[16]; # (base 65), 255 if immune 
          $centreTemperature = $decryptedData[17]; #(base 35), 255 if immune  
          $centreRadiation = $decryptedData[18]; # , 255 if immune 
          $lowGravity      = $decryptedData[19];
          $lowTemperature  = $decryptedData[20];
          $lowRadiation    = $decryptedData[21];
          $highGravity     = $decryptedData[22];
          $highTemperature = $decryptedData[23];
          $highRadiation   = $decryptedData[24];
          $growthRate      = $decryptedData[25];
          # Worth noting all of these are +18 when in the fullDataFlag
          $energyLevel           = $decryptedData[26]; #Always 0 in race file
          $weaponsLevel          = $decryptedData[27]; #Always 0 in race file
          $propulsionLevel       = $decryptedData[28]; #Always 0 in race file
          $constructionLevel     = $decryptedData[29]; #Always 0 in race file
          $electronicsLevel      = $decryptedData[30]; #Always 0 in race file
          $biotechLevel          = $decryptedData[31]; #Always 0 in race file
          $energyLevelPointsSincePrevLevel          = &read32(\@decryptedData, 32); # (4 bytes) #Always 0 in race file 
          $weaponsLevelPointsSincePrevLevel         = &read32(\@decryptedData, 36); # (4 bytes) #Always 0 in race file 
          $propulsionLevelPointsSincePrevLevel      = &read32(\@decryptedData, 40); # (4 bytes) #Always 0 in race file
          $constructionLevelPointsSincePrevLevel    = &read32(\@decryptedData, 44); # (4 bytes) #Always 0 in race file
          $electronicsLevelPointsSincePrevLevel     = &read32(\@decryptedData, 48); # (4 bytes) #Always 0 in race file
          $biologyLevelPointsSincePrevLevel         = &read32(\@decryptedData, 52); # (4 bytes) #Always 0 in race file
          $researchPercentage    = $decryptedData[56]; # defaults to 15
          $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]  #Always 0 in race file
          $nextResourcePriority  = $decryptedData[57] & 0x0F; # (left 4 bits)  #Always 0 in race file
          $researchPointsPreviousYear = &read32(\@decryptedData, 58); # (4 bytes)  #Always 0 in race file
          $resourcePerColonist = $decryptedData[62]; # ? 55? 
          $producePerFactory = $decryptedData[63];
          $toBuildFactory = $decryptedData[64];
          $operateFactory = $decryptedData[65];
          $producePerMine = $decryptedData[66];
          $toBuildMine = $decryptedData[67];
          $operateMine = $decryptedData[68];
          $spendLeftoverPoints = $decryptedData[69]; # ?  (3:factories) 
          $researchEnergy        = $decryptedData[70]; # (0:+75%, 1: 0%, 2:-50%) 
          $researchWeapons       = $decryptedData[71]; # (0:+75%, 1: 0%, 2:-50%)
          $researchProp          = $decryptedData[72]; # (0:+75%, 1: 0%, 2:-50%)
          $researchConstruction  = $decryptedData[73]; # (0:+75%, 1: 0%, 2:-50%)
          $researchElectronics   = $decryptedData[74]; # (0:+75%, 1: 0%, 2:-50%)
          $researchBiotech       = $decryptedData[75]; # (0:+75%, 1: 0%, 2:-50%)
          $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
          #$decryptedData[77]; unknown , always 0?  #Bug: 2nd half of PRT?
          $LRT =  $decryptedData[78]  + ($decryptedData[79] * 0x100); 
          $checkBoxes = $decryptedData[81]; 
          # Unknown bit 5
          $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
          # Unknown bit 6
          $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
          $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100); #Always 0 in race file
          #$decryptedData[82-109]; unknown, but in pairs
          # Interestingly, if the player relations have never been set, the
          # player relations length will be 0, with no bytes after it
          # for the player relations values
          # so the result here CAN be 0.
          my $playerRelationsLength = $decryptedData[112]; #Always 0 in race file
          
          @MTItems = &showMTItems($MTItems);
          print "Player ID:$playerId"; if ($playerId == 255) { print "(race file)"; } print "\n";     
          if (uc($ext) !~ /R/) {  # Always 0 in a race file  
            print "Ship Designs:$shipDesigns\n";
            print "Planets:$planets\n";
            print "Fleets:$fleets\n";
            print "Starbase Designs:$starbaseDesigns\n";
            print "Homeworld:$homeWorld\n";
            print "Player Rank:$rank\n";
          }
          print "Logo:$logo\n";
          print "fullDataFlag:$fullDataFlag\n";
          print "Name:$singularRaceName:$pluralRaceName\n"; 
          print "AI Enabled:$aiEnabled\n"; 
          if ($aiEnabled) {
            print "AI Skill:$aiSkill[$aiSkill]\n"; # 2 bits starting at bit 2
            print "AI:$aiRace[$aiRace]\n"; # 3 bits starting at position 5
          }
          print "RAW: GRAV:$lowGravity,$centreGravity,$highGravity  TEMP:$lowTemperature,$centreTemperature,$highTemperature RAD:$lowRadiation,$centreRadiation,$highRadiation\n";
          print 'Grav:' . &showHabRange($lowGravity,$centreGravity,$highGravity,0) . ', Temp:' . &showHabRange($lowTemperature,$centreTemperature,$highTemperature,1) . ', Rad:' . &showHabRange($lowRadiation,$centreRadiation,$highRadiation,2) . ", Growth: $growthRate\%\n"; 
          print "Tech Level: $energyLevel, $weaponsLevel, $propulsionLevel, $constructionLevel, $electronicsLevel, $biotechLevel\n";    
          print "Tech Points:$energyLevelPointsSincePrevLevel, $weaponsLevelPointsSincePrevLevel, $propulsionLevelPointsSincePrevLevel, $constructionLevelPointsSincePrevLevel, $electronicsLevelPointsSincePrevLevel, $biologyLevelPointsSincePrevLevel \n";
          print "Research Percentage:$researchPercentage\n";
          print "Research Priority:" . &showResearchPriority($currentResourcePriority) . "\n";
          print "Next Priority:" . &showResearchPriority($nextResourcePriority) . "\n";
          print "ResearchPointsPreviousYear:$researchPointsPreviousYear\n";
          print "Productivity: Colonist: $resourcePerColonist, Factory: $producePerFactory, $toBuildFactory, $operateFactory, Mine: $producePerMine, $toBuildMine, $operateMine\n";
          print "Leftover Points:$leftoverPoints\n";
          print 'Spent Leftover Points:' . &showLeftoverPoints($spendLeftoverPoints) . "\n";
          print 'Research Cost:' . &showResearchCost($researchEnergy) . ', ' . &showResearchCost($researchWeapons) . ', ' . &showResearchCost($researchProp). ', ' . &showResearchCost($researchConstruction) . ', ' . &showResearchCost($researchElectronics) . ', ' . &showResearchCost($researchBiotech) . "\n";
          print 'PRT:' . &PRT($PRT,1) . "\n";
          print 'LRTs:' . join(',',&LRT($LRT,1)) . "\n";
          print 'Expensive Tech Starts at 3:' . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
          print 'Factories Cost 1 Less Germ:' . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          print 'MT Items:' . join(',',@MTItems) . "\n"; #Always 0 in race file
          if ( $playerRelationsLength ) { 
            for (my $i = 1; $i <= $playerRelationsLength; $i++) {
              my $id = $i-1;
              if ($id == $playerId) { next; } # Skip for self
              print "PlayerID:$id :" . &showPlayerRelations($decryptedData[$i+112]) . "\n";
            } 
          } else { print "Player Relations never set\n"; }
        }
        # Calculate the race checksums
        ($checkSum1, $checkSum2) = &raceCheckSum(\@decryptedData, $singularRaceName, $pluralRaceName, $singularNameLength, $pluralNameLength);
        print "Calculated Race Checksum: $checkSum1  \t$checkSum2\n";
        print "\n";
      } 
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    } 
    $offset = $offset + (2 + $size); 
  } 
  if ( $action ) { return \@outBytes; }
  else { return 0; }
} # end sub




