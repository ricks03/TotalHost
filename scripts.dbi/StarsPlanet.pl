# StarsPlanet.pl
# BUG: NOT FULLY WORKING, but close
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
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
use warnings;   
#use warnings::unused;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 1;
my $display = 1;
 
my $ownerId;
        
my $filename = $ARGV[0]; # input file
my $inBin = $ARGV[1]; # Desired block Type
my $inBin = 1;

if (!($filename)) { 
  print "\n\nUsage: StarsPlanet.pl <input file>\n\n";
  print "Please enter the input file (.xy|.m|.hst|.h|.x). Example: \n";
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
#if ($ext =~ /[xX]/ || uc($ext) =~ /\.h\d/ ) { print "This file does not include race information\n"; exit; }
if ($ext =~ /[rR]/ ) { print "Race files do not include planet information\n"; exit; }

# Read in the binary Stars! file, byte by byte
my $FileValues;
my @fileBytes;
open(StarFile, "<$filename");
binmode(StarFile);
while (read(StarFile, $FileValues, 1)) {
  push @fileBytes, $FileValues; 
}
close(StarFile);

# Read in all the planet data
open(PlanetFile, "</home/beta/strings_planets.txt");
my @planet_names = <PlanetFile>;
close(PlanetFile);
chomp(@planet_names); # Remove the newlines

# Decrypt the data, block by block
my ($outBytes) = &decryptBlockPlanet(@fileBytes);

################################################################
sub decryptBlockPlanet { 
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
  my $block7Found = 0;
  my %GameValues;
  my ($planetId, $ownerId);    

  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    #@data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    print "typeId = $typeId\n";
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
      shift @block; # remove the first two elements of the array (formerly @data)
      shift @block; 
#      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@block, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($typeId == 7 || $typeId == 13 || $typeId == 14 || $typeId == 35|| $typeId == 15) { 
        if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), ""; print "\n";}
        
        unless (!defined($inBin)) { 
          my $counter = 0;
          foreach my $key ( @decryptedData ) { 
            #print "byte  $counter:\t$key\t" . &dec2bin($key); if ($inBin ==1 || $inBin ==2 ) { print "\n"; }
            print "$counter:$key\t" . substr(&dec2bin($key),8,8); print "\n"; 
            $counter++;
          }
          print "\n";
        }  
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
      } elsif ($typeId == 7) { # Planets block (.xy file)  , create.c
        my ($mdSize, $mdDensity, $mdStartDest, $wCrap); 
        my @Params; 
        my @rgvc;
        my @GameSize       = ('Tiny','Small','Medium','Large','Huge');
        my @GameDensity    = ('Sparse','Normal','Dense','Packed');
        my @GamePositions  = ('Close','Moderate','Farther','Distant');
        my @GameParameters = ('Beginner: Max Minerals', 'Slower Tech Advances','Single Player', 'Tutorial', 'Computer Players Form Alliances', 'Accelerated BBS Play','Public Player Scores','No Random Events','Galaxy Clumping','wGen','unused');
        my @GameVictory    = ('Owns x of all planets','Attains Tech x','in x Tech Fields', 'Exceeds score of x','Exceeds second place score by x','Has production capacity of x thousand','Owns x capital ships','Has the highest score after x years','Must meet x criteria', 'At least x years');
        $block7Found = 1; 
        
        $GameValues{'UniverseId'} = &read32(\@decryptedData, 0); #lid
        $mdSize = &read16(\@decryptedData,4); #mdSize
        $GameValues{'UniverseSize'} =  $GameSize[$mdSize];
        $GameValues{'GalaxyXY'}= ($mdSize *400) + 400; #dGal    
        $mdDensity = &read16(\@decryptedData,6);
        $GameValues{'Density'} = $GameDensity[$mdDensity]; #$mdDensity
  	    $GameValues{'NumPlayers'} = $decryptedData[8] & 0b00011111;  # Correct, first 5 bits at least, as it uses an actual "16". $cPlayer
        $GameValues{'NumPlanets'} = &read16(\@decryptedData, 10);  # planetsSize cPlanet = cPlanMax; 
        $mdStartDest = &read16(\@decryptedData, 12);  #mdStartDest
        $GameValues{'StartingPositions'} = $GamePositions[$mdStartDest];
        $GameValues{'fDirty'} = &read16(\@decryptedData,14); # Typically 4 bytes, but 2 in this case
        $wCrap = &read16(\@decryptedData, 16); 
        # Extract 1-bit field
        $Params[0]  = ($wCrap >> 0) & 0x1;  # $fExtraFuel
        $Params[1]  = ($wCrap >> 1) & 0x1;  # $fSlowTech
        $Params[2]  = ($wCrap >> 2) & 0x1;  # $fSinglePlr
        $Params[3]  = ($wCrap >> 3) & 0x1;  # $fTutorial
        $Params[4]  = ($wCrap >> 4) & 0x1;  # $fAisBand
        $Params[5]  = ($wCrap >> 5) & 0x1;  # $fBBSPlay
        $Params[6]  = ($wCrap >> 6) & 0x1;  # $fVisScores
        $Params[7]  = ($wCrap >> 7) & 0x1;  # $fNoRandom
        $Params[8]  = ($wCrap >> 8) & 0x1;  # $fClumping
        $Params[9]  = ($wCrap >> 9) & 0x7;  # $wGen , number from 0-7 determined randomly, 	else if (prtBOF->wGen != game.wGen) {  FileError(idsNotCurrentGame); }
        $Params[10] = ($wCrap >> 12) & 0xF; # $unused
        
        $GameValues{'turn'} = &read16(\@decryptedData, 18);  #turn, 2 bytes
        @rgvc         = @decryptedData[20..31]; # 12 bytes  
#         my $vcPlanetControl = $rgvc[0];  #   $vcPlanetControl decryptedData[20] 
#         my $vcTechLevel     = $rgvc[1];  #   $vcTechLevel     decryptedData[21]
#         my $vcTechFields    = $rgvc[2];  #   $vcTechFields    decryptedData[22]
#         my $vcScore         = $rgvc[3];  #   $vcScore         decryptedData[23]
#         my $vcScoreExcess   = $rgvc[4];  #   $vcScoreExcess   decryptedData[24]
#         my $vcProduction    = $rgvc[5];  #   $vcProduction    decryptedData[25]
#         my $vcLargeShips    = $rgvc[6];  #   $vcLargeShips    decryptedData[26]
#         my $vcTurns         = $rgvc[7];  #   $vcTurns         decryptedData[27]
#         my $vcMustMeet      = $rgvc[8];  #   $vcMustMeet      decryptedData[28]
#         my $vcLeastYears    = $rgvc[9];  #                    decryptedData[29]

        $GameValues{'GameName'} = join('', map { chr($_) } @decryptedData[32..63]);  

        # Print out the values        
        foreach my $key (sort keys %GameValues) { print "Univ: $key, $GameValues{$key}\n";  }
        for my $i (0..10) { print  "Game: $Params[$i]: $GameParameters[$i]\n"; }
        my $vcMustMeet; 
        for my $i (0..9)  { 
          my $active = ($rgvc[$i] & 0x80) ? 1 : 0;
          if ($active) { $vcMustMeet++; }
          my $rawValue = $rgvc[$i] & 0x7F;
          my $value = &decode_victory_conditions($i,$rawValue); 
          print  "Victory: Active: $active, Value: $rawValue, $GameVictory[$i]: $value\n"; 
        }
        
        # The planet info is now unencrypted, and the test of the file sans the footer. 
        #my @planets =  @fileBytes[$index .. scalar(@fileBytes)-4]; # The rest of the .xy file  sans footer
        my $index = 84; # the first 20 bytes is the header, and then 64 bytes in block 7        
        my $x = 1000;
        my $planetId = 1;
        my $end_index = $index + $GameValues{'NumPlanets'} * 4;
        my @planetBytes = @fileBytes[$index .. $end_index];
        @fileBytes = map { ord($_) } @fileBytes;  # see also unshiftBytes   
        if ($end_index > scalar(@fileBytes)) { die "Not enough bytes in file to read all planet data!"; }
        for (my $i = $index; $i < $end_index; $i+=4) {
          my $record = &read32(\@fileBytes, $i);  # These values are not encrypted.
          my $name_id = ($record >> 22) & 0x3FF;          
          my $x_coord = ($record & 0x3FF) + $x; # Decode X coordinate (bits 0-9)
          $x = $x_coord;  # Update the delta X          
          my $y_coord = ($record >> 10) & 0xFFF; # Decode Y coordinate (bits 10-21)
          print "Planet ID:  $planetId, x: $x_coord, y: $y_coord, NameID: $name_id, Planet Name: $planet_names[$name_id]\n";
          $planetId++;
        }
       
        push @outBytes, @block;
        # need to deal with the "extra" planetBytes since we dealt with them out of band.
        $offset = $offset + ($GameValues{'NumPlanets'} * 4) + 4; 
        push @outBytes, @planetBytes; 
        
      } elsif ( $typeId == 13 || $typeId == 14 || $typeId == 15 ) { # Planet Block  .hst, .m, .h (only 14)
        #define rtPlanetA       13  // Turn   Planet with full info    .m
        #define rtPlanetB       14  // Turn   Planet with partial info .H
        #define rtPlanetC       15  // Turn   Planet with minimal info

        # This always precedes the Production Queue in the .m and .hst file
        #https://github.com/stars-4x/starsapi/blob/master/src/main/java/org/starsautohost/starsapi/block/PartialPlanetBlock.java#L93
        my ($ironiumLevelConc, $boraniumLevelConc, $germaniumLevelConc) = ();
        my ($ironiumConc, $boraniumConc, $germaniumConc) = ();
        my $index = 4; # Where to start digging through the file when size varies
        my ($ironium, $boranium, $germanium, $population) = ();
        my ($gravity, $temperature, $radiation) = ();
        my ($origGravity, $origTemperature, $origRadiation) = ();
        my ($defGuess, $popGuess) = ();
        my @DEFENSES_ESTIMATES =  (0, 5, 8, 11, 15, 19, 23, 28, 34, 40, 48, 57, 69, 85, 100, 100); 
        my ($excessPop, $cMines, $cFactories, $cDefenses, $iScanner, $fArtifact, $hasScanner, $fNoResearch);
        my ($StarbaseDesign, $StarbaseDamage, $idFling, $iWarpFling, $fNoHeal);
        my ($idRoute);
        my ($isb, $turnDiscovered);
        
        # Struct.h for _rtplanet
        #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        #$ownerId = ($decryptedData[1] & 0xF8) >> 3;  # left 5 bits
        my $tmp = &read16 (\@decryptedData, 0); 
        $planetId = ($tmp >> 5) & 0x7FF;
        $ownerId = $tmp & 0x1F;
        #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        #$ownerId = ($decryptedData[1] & 0xF8) >> 3;  # left 5 bits
        if ($ownerId == 31) { $ownerId = -1; }
        elsif ($ownerId >= 16) { die "Unexpected owner: $ownerId"; }

        my $flags = &read16(\@decryptedData, 2);         # 0x01  - 0x40 are $det
        my $det = ($flags >> 9) & 0x7F;  # 0x7F is 01111111 (7 bits)
        #my $det = ($decryptedData[2] & 0x7F);   #Detail: detNone=0, detMinimal 1, detObscure 2, detSome 3, detMore 4, detAll 7
        my @det = qw (detNone detMinimal detObscure detSome detMore error error detAll);
# struct.h        
# # Extract fHomeworld (1 bit), this is the next bit (bit 8)
# my $fHomeworld = ($flags >> 8) & 0x1;  # 0x1 is 00000001 (1 bit)
# # Extract fInclude (1 bit), bit 7
# my $fInclude = ($flags >> 7) & 0x1;
# # Extract fStarbase (1 bit), bit 6
# my $fStarbase = ($flags >> 6) & 0x1;
# # Extract fIncEVO (1 bit), bit 5
# my $fIncEVO = ($flags >> 5) & 0x1;
# # Extract fIncImp (1 bit), bit 4
# my $fIncImp = ($flags >> 4) & 0x1;
# # Extract fIsArtifact (1 bit), bit 3
# my $fIsArtifact = ($flags >> 3) & 0x1;
# # Extract fIncSurfMin (1 bit), bit 2
# my $fIncSurfMin = ($flags >> 2) & 0x1;
# # Extract fRouting (1 bit), bit 1
# my $fRouting = ($flags >> 1) & 0x1;
# # Extract fFirstYear (1 bit), bit 0
# my $fFirstYear = $flags & 0x1;        
#         
	      if (($flags & 0x0100) != 0x0100) { die "Unexpected planet flags 100: $flags"; }
        if (($flags & 0x0078) != 0) {  die "Unexpected planet flags 78: $flags";  }

  	    my $bitWhichIsOffForRemoteMiningAndRobberBaron = ($flags & 0x01) != 0;
   	    my $hasEnvironmentInfo = ($flags & 0x02) != 0;
        my $isInUseOrRobberBaron = ($flags & 0x04) != 0;
	      my $isHomeworld = ($flags & 0x80) != 0;      #fHomeworld
        my $fInclude = ($flags & 0x100) != 0;
	      my $hasStarbase = ($flags & 0x0200) != 0;    #fStarbase
	      my $isTerraformed = ($flags & 0x0400) != 0;  #fIncEVO
 	      my $hasInstallations = ($flags & 0x0800) != 0;  #fIncImp
	      my $hasArtifact = ($flags & 0x1000) != 0;       #fisArtifact  // Does planet have an artifact bonus, 0 after occupancy
 	      my $hasSurfaceMinerals = ($flags & 0x2000) != 0;  #fincSurfMin
	      my $fRouting = ($flags & 0x4000) != 0;            #fRouting aka hasRoute
        # We need to know if a planet has been in the history file past a turn generation.
				# That way we can send "discovery" messages even if you Save and Load.  Otherwise
				# we would only send you the messages the first time you load the turn file.
        
        my $firstYear = ($flags & 0x8000) != 0;           #fFirstYear      #weirdBit  in .h file
        if ($display) { 
          print "Index $index: \
          Planet ID: $planetId, \
          Owner ID: $ownerId, \
          Det: $det[$det] $det, \
          Bit: $bitWhichIsOffForRemoteMiningAndRobberBaron,\
          Environment: $hasEnvironmentInfo, \
          InUseRobber: $isInUseOrRobberBaron, \
          Homeworld: $isHomeworld, \
          fInclude: $fInclude, \
          Starbase: $hasStarbase, \
          Terraformed: $isTerraformed, \
          Installation: $hasInstallations, \
          Artifact: $hasArtifact, \
          Surface: $hasSurfaceMinerals, \
          Route: $fRouting, \
          FirstYear: $firstYear,\
          \n";
        }
 
        if (!$bitWhichIsOffForRemoteMiningAndRobberBaron && !$hasSurfaceMinerals && !$isInUseOrRobberBaron) {  die "Unexpected planet flags for not $decryptedData[2] & 1: "; }
	      if ($isInUseOrRobberBaron && $typeId == 14 && $bitWhichIsOffForRemoteMiningAndRobberBaron) { die "Did not expect data[2] & 5 in partial planet: "; }
        if (!$isInUseOrRobberBaron && $typeId == 13) { die "Expected data[2] & 4 in planet: "; }
        
        if ($typeId == 15) { next;}  # if rtPlanetC, minimal info
#         if ($det == 7 || $det == 3) {  # detAll or detSome
        my $canSeeEnvironment = ($hasEnvironmentInfo || (($hasSurfaceMinerals || $isInUseOrRobberBaron) && !$bitWhichIsOffForRemoteMiningAndRobberBaron));  #if ($det == 7 || $det == 3) {  # detAll or detSome
        if ($canSeeEnvironment) {  
          # Is concentration blank on the first year? 
          
          my $isGermLevelConc = ( $decryptedData[4] & 0b00110000 ) >> 4;  # first 2 bits
          my $isBorLevelConc = ( $decryptedData[4] & 0b00001100 ) >> 2;  # 2nd 2 bits
          my $isIronLevelConc = ( $decryptedData[4] & 0b00000011 ); # 3rd 2 bits
          print "Is CONC LEVEL:  iron: $isIronLevelConc, bor: $isBorLevelConc, germ: $isGermLevelConc\n";
          
          my $preEnvironmentLengthByte = $decryptedData[4];
          if (($preEnvironmentLengthByte & 0xC0) != 0) { die "Unexpected bits at data[4]: "; }
          my $preEnvironmentLength = 1;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x30) >> 4;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x0C) >> 2;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x03);
          my @fractionalMinConcBytes = @decryptedData[4 .. 4 + $preEnvironmentLength - 1];          
          $index += $preEnvironmentLength;
          print "Index: $index ";
#           if ( $isIronLevelConc == 1) { $ironiumLevelConc = $decryptedData[$index++]; }
#           if ( $isBorLevelConc  == 1) { $boraniumLevelConc = $decryptedData[$index++]; }
#           if ( $isGermLevelConc == 1) { $germaniumLevelConc = $decryptedData[$index++]; }   
          $ironiumLevelConc = $decryptedData[$index++]; 
          $boraniumLevelConc = $decryptedData[$index++]; 
          $germaniumLevelConc = $decryptedData[$index++];    
          if ($display) { print "Mineral Level Concentrations: iron: $ironiumLevelConc, bor: $boraniumLevelConc, germ: $germaniumLevelConc\n"; }

          print "Index: $index ";
          $gravity = $decryptedData[$index++]; 
          $temperature = $decryptedData[$index++];
          $radiation = $decryptedData[$index++];
          if ($display) { print "Hab: Grav: $gravity (" . &showHab($gravity, 0) . "), temp: $temperature (" . &showHab($temperature, 1) . "), rad: $radiation (" . &showHab($radiation, 2) . ")\n"; }

          if ($isTerraformed) { 
            print "Index: $index ";
            $origGravity = $decryptedData[$index++]; 
            $origTemperature = $decryptedData[$index++];
            $origRadiation = $decryptedData[$index++];
            if ($display) { print "Orig Hab: $origGravity, $origTemperature, $origRadiation\n"; }
          }
          
#           if (owner >= 0) {
#               int estimatesShort = Util.read16(decryptedData, index);
#               defensesEstimate = estimatesShort / 4096;
#               popEstimate = estimatesShort % 4096;
#               index += 2;
#           }
#         }
          if ($ownerId > -1) {
            print "Index: $index ";
            my $guess = &read16(\@decryptedData, $index); 
            $index+=2;
            $popGuess = $guess & 0x3FF;     # first 12 bits
            $defGuess = $guess >> 12;        #last 4 bits
            #$popGuess = $guess / 4096;     # first 12 bits
            #$defGuess = $guess % 4096;        #last 4 bits
            if ($display) { print "PopGuess: $popGuess, DefGuess:" . ($defGuess*6 + 3) . "\n"; }
          }
        }
        #if ($det < 3) {
        if ($hasSurfaceMinerals) {
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
          if ($display) { print "Surface: iron: $ironium, bor: $boranium, germ: $germanium, pop:" . ($population*100). "\n"; }
        }
        
        if ($typeId == 13) {  # if rtPlanetA / Block type 13
          my @installationsBytes;
          if ($hasInstallations) {   # If there are installations
            print "Index: $index ";
            @installationsBytes = @decryptedData[$index..$index+7]; # cut this down to 8 bytes for simplicity
            $excessPop = $installationsBytes[0] & 0xFF; # 8 bits  Excess Pop
            $cMines = ($installationsBytes[1] & 0xFF) | ($installationsBytes[2] & 0x0F) << 8;  # 12 bits
            $cFactories = ($installationsBytes[2] & 0xF0) >> 4 | ($installationsBytes[3] & 0xFF) << 4;  # 12 bits
            $cDefenses = ($installationsBytes[4] & 0xFF) | ($installationsBytes[5] & 0x0F) << 8; # 12 bits
            $fArtifact = $installationsBytes[5]; # unknownInstallationsByte
            #$iScanner = ($installationsBytes[6] & 0x1F);  # 5 bits
            $iScanner = ($installationsBytes[6] & 0x1);  # 5 bits
            $fNoResearch = ($installationsBytes[6] & 0x80) != 0; # Don't contribute to research unless there's nothing to build here
            $hasScanner = ($installationsBytes[6] & 0x01) == 0;
            # 8 unused bits
            $index += 8;
            print "Installations: ExcessPop: $excessPop, Mine: $cMines, Factory: $cFactories, Defense: $cDefenses, iScan: $iScanner, Artifact: $fArtifact, NoRes: $fNoResearch, hasScan: $hasScanner\n"; 
            if (($installationsBytes[6] & 0x7E) != 0 || $installationsBytes[7] != 0) { die "Unexpected installations data: ";  }
          }
        }
    
        if ($hasStarbase) {
          if ($typeId == 14) { # Partial Planet Block
            my $starbaseByte = $decryptedData[$index++];
            if (($starbaseByte & 0xF0) != 0) { die "Unexpected starbase byte: "; }
            $StarbaseDesign = $starbaseByte;
            print "Starbase: Design: $StarbaseDesign,\n";
          } else {
            print "Index: $index "; 
            my $tmp_index = $index;
			      $StarbaseDesign = ($decryptedData[$tmp_index] & 0b00001111);         # first 4 bits
			      $StarbaseDamage = ($decryptedData[$tmp_index++] & 0xF0) >> 4 | ($decryptedData[$tmp_index] & 0xFF) << 4; # 12 bits
            # I think this can also be gate mass and range? 
			      $idFling = ($decryptedData[$tmp_index++] & 0xFF) | (($decryptedData[$tmp_index] & 0xC0) >> 6) ; # next 10 bits
			      $iWarpFling = ($decryptedData[$tmp_index] & 0b00111100) >> 2;      # next 4 bits
			      $fNoHeal = ($decryptedData[$tmp_index] & 0b0000010) >> 1; # second to last bit  // We got damaged this year (turn gen only).
            print "Starbase: Design: $StarbaseDesign, Damage: $StarbaseDamage, Fling: $idFling, Warp: $iWarpFling, NoHeal: $fNoHeal\n";
            $index += 4;
            # Last bit unused
		      }
        
          if ($fRouting == 1 && $typeId == 13) { 
            $idRoute = &read16(\@decryptedData, $index) & 0b1111111111; # First 10 bits Route destination Id
            #  last 6 bits unused
            #$idRoute = &read16(\@decryptedData, $index);
              $index += 2;
              print "Index $index route: $idRoute\n";        
          }
          
          if ($index != $size && $index + 2 != $size) { die "Unexpected planet data: ";  }
        
  #        if (($typeId == 14) || ($det <= 3)) { # Partial Planet Block
          if ($index + 2 == $size) {
            $isb = ($decryptedData[$index++] & 0xF1) >> 4; # 4 bits, starbase design 
            # next 4 bits unused
            #print "isb: $isb, discovered: $turnDiscovered\n";  
            $turnDiscovered = &read16(\@decryptedData, $index);
            print "Index: $index isb: $isb, discovered: $turnDiscovered (" . ($turnDiscovered + 2400) . ")\n";  
          }
        }
          
      print "\n"; 
      } else { # Block type not found
      }
      # END OF MAGIC
    } 
    $offset = $offset + (2 + $size); 
  } 
} # end sub


 sub decode_victory_conditions {
    my ($id, $setting) = @_;
    my $active = ($setting & 0x80) ? 1 : 0;
    my $value = $setting & 0x7F;
    
    # Apply special logic based on the victory condition index (i)
    if ($id == 0) {  # vcPlanetControl
      $value = 20 + $value * 5;
    }
    elsif ($id == 1) {  # vcTechLevel
      $value = 8 + $value;
    }
    elsif ($id == 2) {  # vcTechFields
      $value = 2 + $value;
    }
    elsif ($id == 3) {  # vcScore
      $value = 1000 + $value * 1000;
    }
    elsif ($id == 4) {  # vcScoreExcess
      $value = 20 + $value * 10;
    }
    elsif ($id == 5) {  # vcProduction
      $value = 10 + $value * 10;
    }
    elsif ($id == 6) {  # vcLargeShips
      $value = 10 + $value * 10;
    }
    elsif ($id == 7) {  # vcTurns
      $value = 30 + $value * 10;
    }
    elsif ($id == 8) {  # vcTurns
    
    }
    elsif ($id == 9) {  # vcTurns
      $value = 30 + $value * 10;
    }
    #       elsif ($i == 8) {  # vcMustMeet
    #           my $count = grep { $_ & 0x80 } @rgvc;  # Count active VCs
    #           $decoded_value = $count < $value ? $count : $value;
    #       }
    return $value;
}