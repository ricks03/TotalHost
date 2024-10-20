# StarsPlanet.pl
# BUG: NOT YET FULLY WORKING

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
# Gets Planet attributes
# Example Usage: StarsPlanet.pl c:\stars\game.m1
#
# Gets planet values
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#

use strict;
#use warnings;   
#use warnings::unused;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 1;
my $display = 1;

my $ownerId;
        
my $filename = $ARGV[0]; # input file
my $inBin = $ARGV[1]; # Desired block Type

if (!($filename)) { 
  print "\n\nUsage: StarsPlanet.pl <input file>\n\n";
  print "Please enter the input file (.xy|.m|.hst|.H). Example: \n";
  print "  StarsPlanet.pl c:\\games\\test.m1\n\n";
  print "Add a 2nd command-line parameter of 1 for binary output.\n";
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

# There is not planet information in these files
#if ($ext =~ /[xX]/ || uc($ext) =~ /\.H\d/ ) { print "This file does not include race information\n"; exit; }
if ($ext =~ /[rR]/ ) { print "This file does not include planet information\n"; exit; }

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
my ($outBytes) = &decryptBlockPlanet(@fileBytes);


################################################################
sub decryptBlockPlanet { #
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
  
  my ($planetId, $ownerId);    

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
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($typeId == 7 || $typeId == 13 || $typeId == 14 || $typeId == 35|| $typeId == 15) { 
        if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), ""; print "\n";}
        
        if ($inBin == 1 ){ 
          my $counter =0;
          foreach my $key ( @decryptedData ) { 
            #print "byte  $counter:\t$key\t" . &dec2bin($key); if ($inBin ==1 || $inBin ==2 ) { print "\n"; }
            print "$counter:$key\t" . substr(&dec2bin($key),8,8); print "\n"; 
            $counter++;
          }
          print "\n";
        }  
        #print "\n";    
      } 
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
      } elsif ( $typeId == 35 ) { # Planet Change Block  (.x)
        #define rtChgPlanetLong 35  // Log    Changes to vars like fNoResearch and mdIdleBuild

  
        # Remember to update in StarsBlock.pm
        #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        #$ownerId = ($decryptedData[1] & 0xF8) >> 3;
        $planetId = &read16(\@decryptedData, 0); # from 0-whatever, meaning add 1 for UI
        my $fNoResearch =   $decryptedData[2] & 0x01;  # 0000000x
        my $iWarpFling =   (($decryptedData[3] & 0x7f ) >> 3);  # 0xxxx000
        my $warpSpeed = $iWarpFling + 4;
        my $idFling =  (&read16(\@decryptedData, 2) >> 1) & 0b1111111111; # bytes 2 & 3, 10 bits shifted 1 to the right. UI Actual
        # I need one bit from byte 3, all of byte 4, and 1 bit from byte 5  (10 bits)              
        my $byte1 = $decryptedData[3] >> 7; # Extracting the first bit of $byte1      
        my $idRoute = ($decryptedData[5] & 0x01) << 9 | ($decryptedData[4] << 1) | $byte1 & 0x01; #move 4 one to the left, and then get the first bit of byte 5
                 
        my $output =  "Planet ID: $planetId, ";
        if ($fNoResearch) { $output .= "No Research"; 
        } elsif ($iWarpFling) { $output .="idFling: $idFling, Warp speed: $warpSpeed, idRoute: $idRoute"; 
        } else { $output .= "ERROR"; }
        $output .= "\n";
        if ($display) { print $output; }
##
      } elsif ( $typeId == 7 ) { # Planets Block  (.xy)
      #define rtGame           7  // xy     Game identification
#         case rtGame:
# 				printf("\n%04lx:     lid:  %08lx\n", lOff, prtGame->lid);
# 				printf("     Uni Size: %d        Density: %d\n", prtGame->mdSize*400+800, prtGame->mdDensity);
# 				printf(" # of Players: %d   # of Planets: %d\n", prtGame->cPlayer, prtGame->cPlanMax);
# 				printf("Starting Dist: %d      Dirty Bit: %d\n", prtGame->mdStartDist, prtGame->fDirty);
# 				printf("   Extra Fuel: %s      Slow Tech: %s\n", YesNo(prtGame->fExtraFuel), YesNo(prtGame->fSlowTech));
# 				printf("   Single Plr: %s       Tutorial: %s\n", YesNo(prtGame->fSinglePlr), YesNo(prtGame->fTutorial));
# 				printf("     Ais Band: %s       BBS Play: %s\n", YesNo(prtGame->fAisBand), YesNo(prtGame->fBBSPlay));
# 				printf("No Random Evt: %s  Public Scores: %s\n", YesNo(prtGame->fNoRandom), YesNo(prtGame->fVisScores));
# 				printf("       Turn #: %d      Game Name: %s\n", prtGame->turn, prtGame->szName);
# 				printf("         wGen: %u\n", prtGame->wGen);
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
        if ($display) { print "Planet ID: $planetId, Owner ID: $ownerId\n"; }
##        
      } elsif ( $typeId == 13 || $typeId == 14 || $typeId == 15 ) { # Planet Block  (.hst)
        #define rtPlanetA       13  // Turn   Planet with full info    .m
        #define rtPlanetB       14  // Turn   Planet with partial info .H
        #define rtPlanetC       15  // Turn   Planet with minimal info

        # This always precedes the Production Queue in the .m and .hst file
        #https://github.com/stars-4x/starsapi/blob/master/src/main/java/org/starsautohost/starsapi/block/PartialPlanetBlock.java#L93
        my ($ironiumLevelConc, $boraniumLevelConc, $germaniumLevelConc) = ();
        my ($ironiumConc, $boraniumConc, $germaniumConc) = ();
        my $index = 5; # Where to start digging through the file when size varies
        my ($ironium, $boranium, $germanium, $population) = ();
        my ($gravity, $temperature, $radiation) = ();
        my ($origGravity, $origTemperature, $origRadiation) = ();
        my ($defGuess, $popGuess) = ();
        my @DEFENSES_ESTIMATES =  (0, 5, 8, 11, 15, 19, 23, 28, 34, 40, 48, 57, 69, 85, 100, 100); 
        my ($iDeltaPop, $excessPop, $cMines, $cFactories, $cDefenses, $iScanner, $fArtifact, $hasScanner, $fNoResearch);
        my ($StarbaseDesign, $StarbaseDamage, $idFling, $iWarpFling, $fNoHeal);
        my ($idRoute);
        my ($isb, $turnDiscovered);
        
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
        my $det = ($decryptedData[2] & 0x7F);   #Detail: detNone=0, detMinimal 1, detObscure 2, detSome 3, detMore 4, detAll 7
        my @det = qw (detNone detMinimal detObscure detSome detMore error error detAll);
 
        my $flags = &read16(\@decryptedData, 2);
        # 0x01  - 0x40 are $det
	      my $isHomeworld = ($flags & 0x80) != 0;      #fHomeworld
        my $fInclude = ($flags & 0x100) != 0;
	      my $hasStarbase = ($flags & 0x0200) != 0;    #fStarbase
	      my $isTerraformed = ($flags & 0x0400) != 0;  #fIncEVO
 	      my $hasInstallations = ($flags & 0x0800) != 0;  #fIncImp
	      my $hasArtifact = ($flags & 0x1000) != 0;       #fisArtifact  // Does planet have an artifact bonus, 0 after occupancy
 	      my $incSurfMin = ($flags & 0x2000) != 0;  #fincSurfMin
	      my $fRouting = ($flags & 0x4000) != 0;            #fRouting
        # We need to know if a planet has been in the history file past a turn generation.
				# That way we can send "discovery" messages even if you Save and Load.  Otherwise
				# we would only send you the messages the first time you load the turn file.
        my $firstYear = ($flags & 0x8000) != 0;           #fFirstYear
        if ($display) { print "Planet ID: $planetId, Owner ID: $ownerId, Det: $det[$det] $det, Homeworld: $isHomeworld, fInclude: $fInclude, Starbase: $hasStarbase, Terraformed: $isTerraformed, Installation: $hasInstallations, Artifact: $hasArtifact, Surface: $incSurfMin, Route: $fRouting\n"; }

        if ($typeId == 15) { next;}  # if rtPlanetC, minimal info
        if ($det == 7 || $det == 3) {  # detAll or detSome
          my $isGermLevelConc = ( $decryptedData[4] & 0b00110000 ) >> 4;  # first 2 bits
          my $isBorLevelConc = ( $decryptedData[4] & 0b00001100 ) >> 2;  # 2nd 2 bits
          my $isIronLevelConc = ( $decryptedData[4] & 0b00000011 ); # 3rd 2 bits
          print "CONC LEVEL:  $isIronLevelConc, $isBorLevelConc , $isGermLevelConc\n";
          print "Index: $index ";
          if ( $isIronLevelConc == 1) { $ironiumLevelConc = $decryptedData[$index++]; }
          if ( $isBorLevelConc == 1)  { $boraniumLevelConc = $decryptedData[$index++]; }
          if ( $isGermLevelConc == 1) { $germaniumLevelConc = $decryptedData[$index++]; }   
          if ($display) { print "Mineral Level Concentrations: $ironiumLevelConc, $boraniumLevelConc, $germaniumLevelConc\n"; }

        
          print "Index: $index ";
          $ironiumConc = $decryptedData[$index++]; 
          $boraniumConc = $decryptedData[$index++]; 
          $germaniumConc = $decryptedData[$index++];    
          if ($display) { print "Mineral Conc: $ironiumConc, $boraniumConc, $germaniumConc\n"; }

          print "Index: $index ";
          $gravity = $decryptedData[$index++]; 
          $temperature = $decryptedData[$index++];
          $radiation = $decryptedData[$index++];
          if ($display) { print "Hab: $gravity " . &showHab($gravity, 0) . ", $temperature " . &showHab($temperature, 1) . ", $radiation " . &showHab($radiation, 2) . "\n"; }
          
          if ($isTerraformed) { 
            print "Index: $index ";
            $origGravity = $decryptedData[$index++]; 
            $origTemperature = $decryptedData[$index++];
            $origRadiation = $decryptedData[$index++];
            if ($display) { print "Orig Hab: $origGravity, $origTemperature, $origRadiation\n"; }

          }
          # No idea why we guess at a home world. #if ($ownerId != -1 && $ownerId != $Player) {
          if ($ownerId != -1) {
            print "Index: $index ";
            my $guess = &read16(\@decryptedData, $index); $index+=2;
            $popGuess = $guess & 0x3FF;     # first 12 bits
            $defGuess = $guess >> 12;        #last 4 bits
            if ($display) { print "Guess: " . $popGuess . "," . ($defGuess*6 + 3) . "\n"; }
          }
          
          if ($det < 3) {
            if ($incSurfMin) {
              print "Index: $index ";
              my $contentsLengths = &read8($decryptedData[$index]);
              my $iLength = $contentsLengths & 0x03;
              $iLength = 4 >> (3 - $iLength);
              my $bLength = ($contentsLengths & 0x0C) >> 2;
              $bLength = 4 >> (3 - $bLength);
              my $gLength = ($contentsLengths & 0x30) >> 4;
              $gLength = 4 >> (3 - $gLength);
              my $popLength = ($contentsLengths & 0xC0) >> 6;
              $popLength = 4 >> (3 - $popLength);
              $index += 1;
              $ironium = &readN(\@decryptedData, $index, $iLength);
              $index += $iLength;
              $boranium = &readN(\@decryptedData, $index, $bLength);
              $index += $bLength;
              $germanium = &readN(\@decryptedData, $index, $gLength);
              $index += $gLength;
              $population = &readN(\@decryptedData, $index, $popLength);  # is pop / 100
              $index += $popLength;
              if ($display) { print "Surface: $ironium, $boranium, $germanium, " . ($population*100). "\n"; }
            }
          }
          if ($typeId == 13) {  # if rtPlanetA / Block type 13
            if ($hasInstallations) {   # If there are installations
              print "Index: $index ";
              my @installationsBytes = @decryptedData[$index..$index+7]; # cut this down to 8 bytes for simplicity
              $iDeltaPop = $installationsBytes[0] & 0xFF; # 8 bits
              $cMines = ($installationsBytes[1] & 0xFF) | ($installationsBytes[2] & 0x0F) << 8;  # 12 bits
              $cFactories = ($installationsBytes[2] & 0xF0) >> 4 | ($installationsBytes[3] & 0xFF) << 4;  # 12 bits
              $cDefenses = ($installationsBytes[4] & 0xFF) | ($installationsBytes[5] & 0x0F) << 8; # 12 bits
              $iScanner = ($installationsBytes[6] & 0x1F);  # 5 bits
              $fArtifact = $installationsBytes[5];
              $fNoResearch = ($installationsBytes[6] & 0x80) != 0; # Don't contribute to research unless there's nothing to build here
              $hasScanner = ($installationsBytes[6] & 0x01) == 0;
              if (($installationsBytes[6] & 0x7E) != 0 || $installationsBytes[7] != 0) {
                  print("Unexpected installations data: ");
              }
              # 8 unused bits
              $index += 8;
              print "Installations: Delta: $iDeltaPop, Excess: $excessPop, M: $cMines, F: $cFactories, D: $cDefenses, iScan: $iScanner, art: $fArtifact, hasScan: $hasScanner, NoRes: $fNoResearch\n"; 
            }
          }
          
          if ($ownerId != -1) {
			      if ($hasStarbase) {
              print "Index: $index "; 
              my $tmp_index = $index;
				      $StarbaseDesign = ($decryptedData[$tmp_index] & 0b00001111);         # first 4 bits
				      $StarbaseDamage = ($decryptedData[$tmp_index++] & 0xF0) >> 4 | ($decryptedData[$tmp_index] & 0xFF) << 4; # 12 bits
              # I think this can also be gate mass and range? 
				      $idFling = ($decryptedData[$tmp_index++] & 0xFF) | (($decryptedData[$tmp_index] & 0xC0) >> 6) ; # next 10 bits
				      $iWarpFling = ($decryptedData[$tmp_index] & 0b00111100) >> 2;      # next 4 bits
				      $fNoHeal = ($decryptedData[$tmp_index] & 0b0000010) >> 1; # second to last bit  // We got damaged this year (turn gen only).
              print "Starbase: $StarbaseDesign, $StarbaseDamage, $idFling, $iWarpFling, $fNoHeal\n";
              $index += 4;
              # Last bit unused
			      }
		      }
          if ($fRouting == 1) {
            $idRoute = &read16($decryptedData, $index) & 0b1111111111; # First 10 bits Route destination Id
            $index += 2;
            print "Index $index route: $idRoute\n";
            #  last 6 bits unused
          }
          
#   terra	VARCHAR(10),
# 	cap	VARCHAR(10),
# 	scan	INTEGER,
# 	pen	INTEGER,
# 	driver	VARCHAR(30),	/* This is a planet name */
# 	warp	INTEGER,
# 	route	VARCHAR(30),
# 	gate_range	INTEGER,
# 	gate_mass	INTEGER,
# 	pct_dmg	INTEGER
        }
        if (($typeId == 14) || ($det <= 3)) {
          print "Index: $index ";
           #$isb = ($decryptedData[$index++] & 0xF1) >> 4; # 4 bits, starbase design 
           # next 4 bits unused
           $turnDiscovered = &read16(\@decryptedData, $index); # last 2 bits
           #print "isb: $isb, discovered: $turnDiscovered\n";  
           print "discovered: $turnDiscovered (" . ($turnDiscovered + 2400) . ")\n";  
        }
      print "\n";
      }
      # END OF MAGIC
    } 
    $offset = $offset + (2 + $size); 
  } 
} # end sub

