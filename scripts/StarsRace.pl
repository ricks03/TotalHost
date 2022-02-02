# StarsRace.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
# 191123 Version 1.1 mostly working to display all race info
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
  print "Please enter the input file (.R|.M|.HST). Example: \n";
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
  $newFile = "$dir\\$basefile.fixed"; 
  
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
sub decryptBlockRace {
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

    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    if ($typeId == 8) { # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug) { print "DECRYPTED:" . join (" ", @unshiftedData), "\n"; } 

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
        my $aiRace;
        my $homeWorld; 
        my $rank;
        my $centreGravity; 
        my $centreTemperature; #(base 35), 255 if immune  
        my $centreRadiation; # , 255 if immune 
        my $lowGravity;
        my $lowTemperature;
        my $lowRadiation;
        my $highGravity;
        my $highTemperature;
        my $highRadiation;
        my $growthRate;
        my $energyLevel;
        my $weaponsLevel;
        my $propulsionLevel;
        my $constructionLevel;
        my $electronicsLevel;
        my $biotechLevel;
        my $energyLevelPointsSincePrevLevel; # (4 bytes) 
        my $weaponsLevelPointsSincePrevLevel; # (4 bytes) 
        my $propulsionLevelPointsSincePrevLevel; # (4 bytes) 
        my $constructionLevelPointsSincePrevLevel; # (4 bytes) 
        my $electronicsLevelPointsSincePrevLevel; # (4 bytes)
        my $biologyLevelPointsSincePrevLevel; # (4 bytes)
        my $researchPercentage;
        my $currentResourcePriority; # (right 4 bits) [same, energy ..., lowest]
        my $nextResourcePriority; # (left 4 bits)
        my $researchPointsPreviousYear; # (4 bytes)
        my $resourcePerColonist; # ? 55? 
        my $producePerFactory;
        my $toBuildFactory;
        my $operateFactory;
        my $producePerMine;
        my $toBuildMine;
        my $operateMine;
        my $spendLeftoverPoints; # ?  (3:factories) 
        my $researchEnergy; # (0:+75%, 1: 0%, 2:-50%) 
        my $researchWeapons; # (0:+75%, 1: 0%, 2:-50%)
        my $researchProp; # (0:+75%, 1: 0%, 2:-50%)
        my $researchConstruction; # (0:+75%, 1: 0%, 2:-50%)
        my $researchElectronics; # (0:+75%, 1: 0%, 2:-50%)
        my $researchBiotech; # (0:+75%, 1: 0%, 2:-50%)
        my $PRT; # HE SS WM CA IS SD PP IT AR JOAT  
        my @PRT=();
        my $LRT;
        my @LRT=(); 
        my $checkBoxes; 
        my $expensiveTechStartsAt3;
        my $factoriesCost1LessGerm;
        my $MTItems;
        my @MTItems=();
        my $playerRelationsLength;

        my $points = 1650; 
        my @scienceCost = ( 150, 330, 540, 780, 1050, 1380 );
        my @prtCost     = (40,95,45,10,-100,-150,120,180,90,66); # HE,SS,WM,CA,IS,SD,PP,IT,AR,JOAT
        my @lrtCost     = (-235,-25,-159,-201,40,-240,-155,160,240,255,325,180,70,30); #IFE,TT,ARM,ISB,GR,UR,MA,NRSE,CE,OBRM,NAS,LSP,BET,RS
        my $tmpPoints=0;
        
        if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        $playerId = $decryptedData[0] & 0xFF; print "Player ID:$playerId"; if ($playerId == 255) { print "(race file)"; } print "\n";
        my $shipDesigns = $decryptedData[1] & 0xFF;  print " Ship Designs:$shipDesigns\n";
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); print " Planets:$planets\n";
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  print " Fleets:$fleets\n";
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); print " Starbase Designs:$starbaseDesigns\n";
        my $logo = (($decryptedData[6] & 0xFF) >> 3); print " Logo:$logo\n";
        my $fullDataFlag = ($decryptedData[6] & 0x04); print "fullDataFlag:$fullDataFlag\n";
        # Byte 7 as 76543210
        #   Bit 0 is always 1
        #   Bit 1 defines whether an AI is enabled :  0:off ,  1:on
        my $aiEnabled = ($decryptedData[7] >> 1) & 0x01; print "AI Enabled:$aiEnabled\n"; 
                      
        if ($aiEnabled) {
          # bits 23 defines how good the AI will be:
          #00 - Easy
          #01 - Standard
          #10 - Harder
          #11 - Expert
          my $aiSkill = ($decryptedData[7] >> 2) & 0x03;  print "AI Skill:$aiSkill[$aiSkill]\n"; # 2 bits starting at bit 2
          
          # Bit 4 is always 0
          
          # bits 765 define which PRT AI to use: 
          # 000 - HE - Robotoids
          # 001 - SS - Turindromes
          # 010 - IS - Automitrons
          # 011 - CA - Rototills
          # 100 - PP - Cybertrons
          # 101 - AR - Macinti
          # 111 - Human inactive / Expansion player
          # When human is set back to active from Inactive, bit 1 flips but bits 765 aren't reset to 0
          # So the values for Byte 7 for human are 1 (active) or 225 (active again) and 227 (inactive/expansion player)
          $aiRace =  ($decryptedData[7] >> 5) & 0x07;  print "AI:$aiRace[$aiRace]\n"; # 3 bits starting at position 5
        } 
        # We figure out names here, because they're here at 8 when not fullDataFlag 
        my $index = 8; 
        if ($fullDataFlag) { 
          # The player names are at the end and are not a fixed length,
          # The number of player relations bytes change where the names start   
          # That also changes whether it's a fullData set or not. 
          $index = 112;
          my $playerRelationsLength = $decryptedData[112]; 
          $index = $index + $playerRelationsLength + 1;
        }  
        my $singularNameLength = $decryptedData[$index] & 0xFF;
        my $singularMessageEnd = $index + $singularNameLength;
        # changed this 210516
        #my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
        my $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
        if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        print "playerId:$playerId Name:$singularRaceName[$playerId]:$pluralRaceName[$playerId]"; 
        if ($playerId == 255) { print "(race file)"; } print "\n"; 
        
        if ($fullDataFlag) { 
          $homeWorld = &read16(\@decryptedData, 8);
          print "Homeworld:$homeWorld\n";
          $rank = $decryptedData[10];
          # BUG: the references say this is two bytes, but I don't think it is.
          # That means I don't know what byte 11 is tho. 
          # Maybe in universes with more planets?
          print "Player Rank:$rank\n";
          # Bytes 12..15 are the password;
          # The password inverts when the player is set to Human(inactive) mode (the bits are flipped).
          # The ai password "viewai" is 238 171 77 9
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
          print "RAW: GRAV: $lowGravity,$centreGravity,$highGravity  Temp: $lowTemperature,$centreTemperature,$highTemperature RAD: $lowRadiation,$centreRadiation,$highRadiation\n";
          print 'Grav:' . &showHab($lowGravity,$centreGravity,$highGravity,0) . ', Temp: ' . &showHab($lowTemperature,$centreTemperature,$highTemperature,1) . ', Rad: ' . &showHab($lowRadiation,$centreRadiation,$highRadiation,2) . ", Growth: $growthRate\%\n"; 
                    # Worth noting all of these are +18 when in the fullDataFlag
          $energyLevel           = $decryptedData[26];
          $weaponsLevel          = $decryptedData[27];
          $propulsionLevel       = $decryptedData[28];
          $constructionLevel     = $decryptedData[29];
          $electronicsLevel      = $decryptedData[30];
          $biotechLevel          = $decryptedData[31];
          print "Tech Level :$energyLevel, $weaponsLevel, $propulsionLevel, $constructionLevel, $electronicsLevel, $biotechLevel\n";    
          $energyLevelPointsSincePrevLevel         = $decryptedData[32]; # (4 bytes) 
          $weaponsLevelPointsSincePrevLevel        = $decryptedData[36]; # (4 bytes) 
          $propulsionLevelPointsSincePrevLevel     = $decryptedData[42]; # (4 bytes) 
          $constructionLevelPointsSincePrevLevel   = $decryptedData[46]; # (4 bytes) 
          $electronicsLevelPointsSincePrevLevel     = $decryptedData[50]; # (4 bytes)
          $biologyLevelPointsSincePrevLevel         = $decryptedData[54]; # (4 bytes)
          print "Tech Points:$energyLevelPointsSincePrevLevel, $weaponsLevelPointsSincePrevLevel, $propulsionLevelPointsSincePrevLevel, $constructionLevelPointsSincePrevLevel, $electronicsLevelPointsSincePrevLevel, $biologyLevelPointsSincePrevLevel \n";
          $researchPercentage    = $decryptedData[56];
          print "Research Percentage:$researchPercentage\n";
          $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]
          print "Research Priority:" . &showResearchPriority($currentResourcePriority) . "\n";
          $nextResourcePriority  = $decryptedData[57] & 0x04; # (left 4 bits)
          print "Next Priority:" . &showResearchPriority($nextResourcePriority) . "\n";
          $researchPointsPreviousYear = $decryptedData[58]; # (4 bytes)
          print "ResearchPointsPreviousYear:$researchPointsPreviousYear\n";
          $resourcePerColonist = $decryptedData[62]; # ? 55? 
          $producePerFactory = $decryptedData[63];
          $toBuildFactory = $decryptedData[64];
          $operateFactory = $decryptedData[65];
          $producePerMine = $decryptedData[66];
          $toBuildMine = $decryptedData[67];
          $operateMine = $decryptedData[68];
          print "Productivity: Colonist: $resourcePerColonist, Factory: $producePerFactory, $toBuildFactory, $operateFactory, Mine: $producePerMine, $toBuildMine, $operateMine\n";
          $spendLeftoverPoints = $decryptedData[69]; # ?  (3:factories) 
          print 'Leftover Points:' . &showLeftoverPoints($spendLeftoverPoints) . "\n";
          $researchEnergy        = $decryptedData[70]; # (0:+75%, 1: 0%, 2:-50%) 
          $researchWeapons       = $decryptedData[71]; # (0:+75%, 1: 0%, 2:-50%)
          $researchProp          = $decryptedData[72]; # (0:+75%, 1: 0%, 2:-50%)
          $researchConstruction  = $decryptedData[73]; # (0:+75%, 1: 0%, 2:-50%)
          $researchElectronics   = $decryptedData[74]; # (0:+75%, 1: 0%, 2:-50%)
          $researchBiotech       = $decryptedData[75]; # (0:+75%, 1: 0%, 2:-50%)
          print 'Research Cost:' . &showResearchCost($researchEnergy) . ", " . &showResearchCost($researchWeapons) . ", " . &showResearchCost($researchProp). ", " . &showResearchCost($researchConstruction) . ", " . &showResearchCost($researchElectronics) . ", " . &showResearchCost($researchBiotech) . "\n";
          $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
          # 'HyperExpansion', 'Super Stealth', 'War Monger', 'Claim Adjustor', 'Inner Strength', 'Space Demolition', 'Packet Physics', 'Interstellar Traveller', 'Alternate Reality', 'Jack of all Trades' );
          print 'PRT:' . &showPRT($PRT) . "\n";
          @PRT = &PRT($PRT);
          #$decryptedData[77]; unknown , always 0
          $LRT =  $decryptedData[78]  + ($decryptedData[79] * 0x100); 
          @LRT = &LRT($LRT);
          print "LRT: $LRT  @LRT\n";
          print 'LRTs:' . join(',',&showLRT($LRT)) . "\n";
          $checkBoxes = $decryptedData[81]; 
          #<Unknown bits="5"/> 
          $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
          # Unknown bit 6
          $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
          print 'Expensive Tech Starts at 3:' . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
          print 'FactoriesCost1LessGerm:' . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100);
          @MTItems = &showMTItems($MTItems);
          print 'MT Items:' . join(',',@MTItems) . "\n";
          #$decryptedData[84-109]; unknown, but in pairs
          # Interestingly, if the player relations have never been set, the
          # player relations length will be 0, with no bytes after it
          # For the player relations values
          # So the result here CAN be 0.
          my $playerRelationsLength = $decryptedData[112];
          if ( $playerRelationsLength ) { 
            for (my $i = 1; $i <= $playerRelationsLength; $i++) {
              my $id = $i-1;
              if ($id == $playerId) { next; } # Skip for self
              print "PlayerID:$id :" . &showPlayerRelations($decryptedData[$i+112]) . "\n";
            } 
          } else { print "Player Relations never set\n"; }
        }
        
        # Calculate the race checksums
        ($checkSum1, $checkSum2) = &raceCheckSum(\@decryptedData, $singularRaceName[$playerId], $pluralRaceName[$playerId], $singularNameLength, $pluralNameLength);
        print "Calculated Race Checksum: $checkSum1  \t$checkSum2\n";
        
        
        # https://sourceforge.net/p/stars-nova/svn/HEAD/tree/trunk/Common/RaceDefinition/RaceAdvantagePointCalculator.cs#l22
        # https://sourceforge.net/p/freestars/code/HEAD/tree/trunk/Server/Race.cpp#l141
        # BUG: Not done integrating yet.
        
        # Hab
        my $hab;
        $hab = 0;
        $tmpPoints=0;    
        my $desireFactor;
        my $v13E;
        my $v136;
        my $v12E;
        my $v100 = 0;
        my @v108 = (0) x3; 
        my $planetDesir;
        my @testPlanetHab;
        my $advantagePoints = 0;
        my $isTotalTerraforming;
        if (&LRT($LRT) eq 'TT') {  $isTotalTerraforming = 1;} else { $isTotalTerraforming = 0; } 

        my @habCenter = ($centreGravity, $centreTemperature, $centreRadiation);
        my @habWidth = ($highGravity-$lowGravity, $highTemperature-$lowTemperature, $highRadiation-$lowRadiation);
        my @habLow = ($lowGravity, $lowTemperature, $lowRadiation);
        my @habHigh = ($highGravity, $highTemperature, $highRadiation);
        my @testHabStart = ();
        my @testHabWidth = ();
        my $ttCorrFactor; 
        my @terraformFactor = ( -1, -1, -1 ); 
        my @iterNum;
        my $tmpHab=0;
        for (my $h=0; $h<3; $h++) { # Where $h is Grav/Temp/Rad
          if ($h == 0 )    { $ttCorrFactor = 0; }
          elsif ($h == 1 ) { if (&LRT($LRT) eq 'TT') { $ttCorrFactor = 8; } else { $ttCorrFactor = 5; } }
          elsif ($h == 2 ) { if (&LRT($LRT) eq 'TT') { $ttCorrFactor = 17; } else { $ttCorrFactor = 15; } }
          for (my $i=0; $i<3; $i++) { 
            if ($habCenter[$i] == 255) { # immune
            	$testHabStart[$i] = 50;
      				$testHabWidth[$i] = 11;
      				$iterNum[$i] = 1;
            } else {
      				$testHabStart[$i] = $habLow[$i] - $ttCorrFactor;
      				if ($testHabStart[$i] < 0) { $testHabStart[$i] = 0; }
      				$tmpHab = $habHigh[$i] + $ttCorrFactor;
      				if ($tmpHab > 100) { $tmpHab = 100; }
      				$testHabWidth[$i] = $tmpHab - $testHabStart[$i];
      				$iterNum[$i] = 11;
            }
          }
          # /* loc_92AAC */
          $v13E = 0.0;
          for (my $i=0; $i<$iterNum[0]; $i++) {
            if ( $i==0 || $iterNum[0]<=1 ) { $tmpHab = $testHabStart[0]; }
            else { $tmpHab = ($testHabWidth[0]*$i) / ($iterNum[0]-1) + $testHabStart[0]; }
            if ( $h!=0 && $habCenter[0] != 255) { # Grav immune
               $v100 = $habCenter[0] - $tmpHab;
               if (abs($v100)<= $ttCorrFactor) { $v100 = 0; }
               elsif ($v100 < 0) { $v100 += $ttCorrFactor; }
               else { $v100 -= $ttCorrFactor; }
               $v108[0] = $v100;
               $tmpHab = $habCenter[0] - $v100;
            }
            $testPlanetHab[0] = $tmpHab;
            $v136 = 0.0;
            for (my $j=0; $j<$iterNum[1]; $j++) {
              if ($j==0 || $iterNum[1]<=1) { $tmpHab = $testHabStart[1]; }
              else { $tmpHab = ($testHabWidth[1]*$j) / ($iterNum[1]-1) + $testHabStart[1]; }
              if ($h != 0 && $habCenter[1] != 255) { # Temp imune
                $v100 = $habCenter[1] - $tmpHab;
                if (abs($v100) <= $ttCorrFactor) { $v100=0; }
                elsif ($v100<0) { $v100+= $ttCorrFactor; }
                else { $v100 -= $ttCorrFactor; }
                $v108[1] = $v100;
                $tmpHab = $habCenter[1] - $v100;
              }
              $testPlanetHab[1] = $tmpHab;
              $v12E = 0;

              for (my $k=0;$k<$iterNum[2];$k++) {
                if ( $k==0 || $iterNum[2] <= 1) { $tmpHab = $testHabStart[2]; }
                else { $tmpHab = ($testHabWidth[2]*$k) / ($iterNum[2]-1) + $testHabStart[2]; }
                if ($h != 0 && $habCenter[2] != 255) { 
                  $v100 = $habCenter[2] - $tmpHab; 
                  if ( abs( $v100 ) <= $ttCorrFactor ) { $v100 = 0; }
                  elsif ($v100 < 0) { $v100+=$ttCorrFactor; }
                  else { $v100 -= $ttCorrFactor; }
                  $v108[2] = $v100;
                  $tmpHab = $habCenter[2] - $v100;
                }
                $testPlanetHab[2] = $tmpHab;
                #$planetDesir = &planetValueCalc($race, $testPlanetHab);
                $planetDesir = 100;

                $v100 = $v108[0]+$v108[1]+$v108[2];
                if ($v100 > $ttCorrFactor) { 
                  $planetDesir -= $v100-$ttCorrFactor; 
                  if ($planetDesir < 0) { $planetDesir=0; }
                }
                $planetDesir *= $planetDesir;
                if ($h == 0) { $planetDesir *=7; }
                elsif ($h == 1) { $planetDesir *=5 } 
                elsif ($h == 2) { $planetDesir *= 6; }
                $v12E += $planetDesir;
              }   
              #/* loc_92D34 */
              if ($habCenter[2] != 255) { $v12E = ($v12E*$testHabWidth[2])/100; }
              else { $v12E *= 11; }
              $v136 += $v12E;
            }
            if ($habCenter[1] != 255) { $v136 = ($v136 * $testHabWidth[1]) / 100; }
            else { $v136 *= 11; }
            $v13E += $v136;
          }
          if ($habCenter[0] != 255) { $v13E = ($v13E * $testHabWidth[0]) / 100; }
          else { $v13E *= 11; }
          $advantagePoints += $v13E;
        }
        $points = 1650;
        $advantagePoints = $advantagePoints / 2000;
        $points += int($advantagePoints/10.0+.5);
        print "POINTS Hab: $points\n";
         
        # Growth
        my $grRateFactor = ($growthRate * 100 + .5); #use raw growth rate, otherwise HEs pay for GR at 2x
        my $grRate = $grRateFactor;
        if ($grRateFactor <= 5) { $points += (6 - $grRateFactor) * 4200; }
        elsif ($grRateFactor <= 13) {
          if ($grRateFactor == 6 )  { $points += 3600 }
          elsif ($grRateFactor == 7) { $points += 2250 }
          elsif ($grRateFactor == 8) { $points +=  600; }
          elsif ($grRateFactor == 9) { $points +=  225; }
          $grRateFactor = $grRateFactor * 2 - 5;
        } elsif ( $grRateFactor < 20) { $grRateFactor = ($grRateFactor - 6) * 3; }
        else { $grRateFactor = 45; }
        $points -= ($hab * $grRateFactor) / 24;         
        print "POINTS Growth: $points\n";
       
        # Immunities
        my $immunities = 0;
        if ( $centreGravity == 255)     { $immunities++; } #(base 65), 255 if immune 
        else { $points += abs($centreGravity - 50) * 4; } # bonus points for off center habs
        if ( $centreTemperature == 255) { $immunities++; } #(base 35), 255 if immune  
        else { $points += abs($centreTemperature - 50) * 4; } # bonus points for off center habs
        if ( $centreRadiation == 255)   { $immunities++; } # , 255 if immune 
        else { $points += abs($centreRadiation - 50) * 4; } # bonus points for off center habs
        if ($immunities > 1) { $points -= 150; } # if more then one immunity
        print "POINTS Immunities: $points \n";
   
        # Production
        my $j = $resourcePerColonist; # popEfficiency
        if ($j > 25)      { $j = 25; }
        if ($j <= 7)      { $points -= 2400; }
        elsif ($j == 8)   { $points -=1260; }
        elsif ($j == 9)   { $points -= 600; }
        elsif ($j > 10)   { $points += ($j - 10) * 120; }
  
        print "POINTS Production: $points \n";

        # factories
        $tmpPoints=0;    
      	if (&PRT($PRT) eq 'AR') {
       	  $points += 210; #AR
        } else {
        	my $prodPoints = $producePerFactory - 10; #FactoryRate() - 10;
        	my $costPoints = $toBuildFactory - 10; #FactoryCost().GetResources() - 10;
        	my $operPoints = $operateFactory - 10; #FactoriesRun() - 10;
        	if ($prodPoints < 0) { $tmpPoints -= $prodPoints * 100; }
          else { $tmpPoints -= $prodPoints * 121; }
        
        	if ($costPoints < 0) { $tmpPoints += $costPoints * $costPoints * -60; }
        	else { $tmpPoints += $costPoints * 55; }
        
        	if ($operPoints < 0) { $tmpPoints -= $operPoints * 40; }
        	else { $tmpPoints -= $operPoints * 35; }
      
        	my $llfp = 700; #Rules::GetConstant("LimitLowFactoryPoints", 700);
            
        	if ($tmpPoints > $llfp) { $tmpPoints = ($tmpPoints - $llfp) / 3 + $llfp; }
        
        	if ($operPoints > 14) { $tmpPoints -= 360; }
        	elsif ($operPoints > 11) { $tmpPoints -= ($operPoints - 7) * 45; }
        	elsif ($operPoints >= 7) { $tmpPoints -= ($operPoints - 6) * 30; }
        
        	if ($prodPoints >= 3) { $tmpPoints -= ($prodPoints - 2) * 60; }
        }
        $points += $tmpPoints;
        if ($toBuildFactory == 3) { $points -= 175; } # factory cost
        print "POINTS Factory: $points\n";
    
      	# mines
      	$tmpPoints = 0;
      	my $prodPoints = 10 - $producePerMine; # mineRate
      	my $costPoints = 3 - $producePerMine; # MineCost().GetResources();
      	my $operPoints = 10 - $operateMine; # MinesRun();
      	if ($prodPoints > 0) { $tmpPoints = $prodPoints * 100; }
      	else{ $tmpPoints = $prodPoints * 169; }
      	if ($costPoints > 0) { $tmpPoints -= 360; }
      	else { $tmpPoints += 80 - $costPoints * 65; }
      	if ($operPoints > 0) { $tmpPoints += $operPoints * 40; }
      	else { $tmpPoints += $operPoints * 35; }
      	$points += $tmpPoints;
        print "POINTS Mine: $points\n";
        
        # Traits
        # PRTs
        my %prtCost;
        my %lrtCost;
        $prtCost{HE} =40;
        $prtCost{SS} =95;
        $prtCost{WM} =45;
        $prtCost{CA} =10;
        $prtCost{IS} =-100;
        $prtCost{SD} =-150;
        $prtCost{PP} =120;
        $prtCost{IT} =180;
        $prtCost{AR} =90;
        $prtCost{JOAT} =-66;
  
        # BUG: Shouldnot this be positive?   
        $points += $prtCost{&PRT($PRT)};  # Modify points for PRTs
        print "POINTS PRT: $points\n";
        
        # LRTs
        $lrtCost{IFE} =-235;
        $lrtCost{TT}  =-25;
        $lrtCost{ARM} =-159;
        $lrtCost{ISB} =-201;
        $lrtCost{GR}  =40;
        $lrtCost{UR}  =-240;
        $lrtCost{MA}  =-155;
        $lrtCost{NRSE} =160; # NRSE
        $lrtCost{CE}  =240;
        $lrtCost{OBRM} =255;
        $lrtCost{NAS} =325;
        $lrtCost{LSP} =180;
        $lrtCost{BET} =70;
        $lrtCost{RS}  =30;
        my $i = 0;
        my $k = 0;
      	foreach my $j (@LRT) {
  	      if    ($lrtCost{$j} < 0) { $i++; }
  	      elsif ($lrtCost{$j} > 0) { $k++; }
        }
        if (($i + $k) > 4) { $points -= ($i + $k) * ($i + $k - 4) * 10; }
        if (($i - $k) > 3) { $points -= ($i - $k - 3) * 60; }
        if (($k - $i) > 3) { $points -= ($k - $i - $3) * 40; }
        
        foreach my $j (@LRT) { # Point changes for NAS
          $points += $lrtCost{$j};
          if ($j eq 'NAS') {
            if (&PRT($PRT) eq 'PP') { $points -=280; }
            elsif (&PRT($PRT) eq 'SS') { $points -=200; }
            elsif (&PRT($PRT) eq 'JOAT') { $points -= 40; }
          }
        }
  
        print "POINTS LRT: $points\n";
         
        # Research
        my @researchCost =  ($researchEnergy,$researchWeapons,$researchProp,$researchConstruction,$researchElectronics,$researchBiotech); # (0:+75%, 1: 0%, 2:-50%)
        my $techCost = 0;
        foreach my $i ( @researchCost ) {
          if    ($i == 2) { $techCost++; } # -50%
          elsif ($i == 0) {$techCost--; } # +75%
          # $i == 1 is 0
          else { print 'error'; die; }
        }
        if ($techCost > 0) {
          $points -= $techCost * $techCost * 130;
          if ($techCost >= 6) { $points += 1430; }
          elsif ($techCost == 5) { $points +=520; } 
        } elsif ($techCost < 0 ) {
          $techCost =- $techCost;
          $points += $techCost * ($techCost + 9) * 15;
          if ($techCost >= 6) { $points += 30 };
          if ($techCost < 4 && $resourcePerColonist < 10) { $points -= 190; }#  Pop efficiency \ 100
        }
        if ($expensiveTechStartsAt3) { $points -= 180; }
        if (&showPRT($PRT) eq 'AR' && $researchCost[0] == 2) { $points -= 100; }  #Energy @ 50%
        
        print "POINTS research: $points\n";

      } # typeId = 6
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
    } # typeid = 8 else
    $offset = $offset + (2 + $size); 
  } # main while
  if ( $action ) { return \@outBytes; }
  else { return 0; }
} # Main sub

