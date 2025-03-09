#!/usr/bin/perl
# StarsPlanet.pl
# Reads Blocks $typeID == 7, $typeId == 13, $typeId == 14, $typeId == 15, $typeId == 35 
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
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;
my $display = 1;
 
my $ownerId;
        
my $filename = $ARGV[0]; # input file
my $inBin = $ARGV[1]; # Desired block Type
#my $inBin = 1;

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
if ($ext =~ /[rR]/ ) { print "Race files do not include planet information\n"; exit; }

# Read in the binary Stars! file, byte by byte
my $FileValues;
my @fileBytes;
open my $StarFile,  '<', "$filename" or die $!;
binmode($StarFile);
while (read($StarFile, $FileValues, 1)) { push @fileBytes, $FileValues; }
close($StarFile);

# Read in all the planet data
open my $PlanetFile, '<', "/home/beta/strings_planets.txt" or die $!;
my @planet_names = <$PlanetFile>;
close($PlanetFile);
chomp(@planet_names); # Remove the newlines

# Decrypt the data, block by block
my ($outBytes) = &decryptBlockPlanet(@fileBytes);

################################################################
sub decryptBlockPlanet { 
  my (@fileBytes) = @_;
  my @block;
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
      shift @block; # remove the first two elements of the array (formerly @data)
      shift @block; 
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@block, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($typeId == 7 || $typeId == 13 || $typeId == 14 || $typeId == 35|| $typeId == 15) { 
        if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), ""; print "\n";}
        
        unless (!defined($inBin)) { 
          my $counter = 0;
          foreach my $key ( @decryptedData ) { 
            print "$counter:$key\t" . substr(&dec2bin($key),8,8); print "\n"; 
            $counter++;
          }
          print "\n";
        }  
      } 
      # WHERE THE MAGIC HAPPENS
      if ( $typeId == 35 ) { # Planet Change Block  (.x)
        my ($planetID);
        my ($fNoResearch, $idFling, $iWarpFling, $warpSpeed, $idRoute);

        #define rtChgPlanetLong 35  // Log    Changes to vars like fNoResearch and mdIdleBuild       
#         typedef struct _rtChgPlanetLong
#         {
#         int id; // Planet ID
#         union
#         {
#         unsigned long ul;
#         struct
#         {
#         unsigned long fNoResearch : 1,
#         idFling     : 10,
#         iWarpFling  : 4,
#         idRoute     : 10,
#         unused      : 7;
#         };
#         };
#         };
  
        # Remember to update in StarsBlock.pm
        $planetId = &read16(\@decryptedData, 0); # from 0-whatever, meaning add 1 for UI
        my $ul = read32(\@decryptedData, 2);
        $fNoResearch = ($ul >> 0) & 0x1;              # Extract the 1st bit
        $idFling     = ($ul >> 1) & 0x3FF;            # Extract the next 10 bits
        $iWarpFling  = ($ul >> 11) & 0xF;             # Extract the next 4 bits
        $warpSpeed = $iWarpFling + 4;
        $idRoute     = ($ul >> 15) & 0x3FF;           # Extract the next 10 bits, not 0.. but 1.. so no need to change
        my $unused      = ($ul >> 25) & 0x7F;            # Extract the final 7 bits
         
        if ($display) {        
          print "Planet Change: Planet: " . ($planetId+1);
          print " , fNoResearch: $fNoResearch";  
          if ($iWarpFling) { print ", idFling: $idFling, Warp speed: $warpSpeed"; }   else { print ", no Warp"; }
          print ", Route to Planet: $idRoute";
          print "\n";
        }
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
        if ($display) {       
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
        }
        
        # The planet info is now unencrypted, and the rest of the file sans the footer. 
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
          if ($display) { print "Planet ID:  $planetId, x: $x_coord, y: $y_coord, NameID: $name_id, Planet Name: $planet_names[$name_id]\n"; }
          $planetId++;
        }
       
        push @outBytes, @block;
        # need to deal with the "extra" planetBytes since we dealt with them out of band, so we use offset, not index
        $offset = $offset + ($GameValues{'NumPlanets'} * 4) + 4; 
        push @outBytes, @planetBytes; 
        
      } elsif ( $typeId == 13 || $typeId == 14 || $typeId == 15 ) { # Planet Block  .hst, .m, .h (only 14)
        #define rtPlanetA       13  // Turn   Planet with full info    .m
        #define rtPlanetB       14  // Turn   Planet with partial info .h
        #define rtPlanetC       15  // Turn   Planet with minimal info
        # char *rgszDetails[4] = { "None", "Minimal", "Partial", "Full" };  rtdump.c
 
        # This always precedes the Production Queue in the .m and .hst file
        #https://github.com/stars-4x/starsapi/blob/master/src/main/java/org/starsautohost/starsapi/block/PartialPlanetBlock.java#L93
        my ($planetId, $ownerId);
        my ($ironiumLevelConc, $boraniumLevelConc, $germaniumLevelConc) = ();
        my ($ironiumConc, $boraniumConc, $germaniumConc) = ();
        my $index = 4; # Where to start digging through the file when size varies
        my ($ironium, $boranium, $germanium, $population) = ();
        my ($gravity, $temperature, $radiation) = ();
        my ($origGravity, $origTemperature, $origRadiation) = ();
        my ($defGuess, $popGuess) = ();
        my @DEFENSES_ESTIMATES =  (0, 5, 8, 11, 15, 19, 23, 28, 34, 40, 48, 57, 69, 85, 100, 100); 
        my ($iDeltaPop, $cMines, $cFactories, $cDefenses, $iScanner, $fArtifact, $fNoResearch);
        my ($isb, $pctDp, $idFling, $iWarpFling, $fNoHeal);
        my ($idRoute);
        my ($turn_number);
        my ($fHomeworld, $fInclude, $fStarbase, $fIncEVO, $fIncImp, $fIsArtifact, $fincSurfMin, $fRouting, $fFirstYear);
        
        # Struct.h for _rtplanet
        my $field1 = read16(\@decryptedData, 0);
        $planetId = extract_bitfield($field1, 0, 11);  # 11 bits for `id`
        $ownerId = extract_bitfield($field1, 11, 5);  # 5 bits for `iPlayer`
        if ($ownerId == 31) { $ownerId = -1; }
        elsif ($ownerId >= 16) { die "Unexpected owner: $ownerId"; }

        my $flags = &read16(\@decryptedData, 2);         # 0x01  - 0x40 are $det
        my $det = $flags & 0x7F; # Mask the lowest 7 bits (0x7F = 01111111 in binary) #Detail: detNone=0, detMinimal 1, detObscure 2, detSome 3, detMore 4, detAll 7
        my @det = qw (detNone detMinimal detObscure detSome detMore error error detAll);
        # det only comes in 0,1,3,7
        # Planets with detection level det >= detSome are classified as rtPlanetB.
        # Planets with detection level det < detSome are classified as rtPlanetC.

        #00000000 detNone
        #00000001 detMinimal   0x01  // Bit 0
        #00000010 detObscure ? 
        #00000011 detSome      0x02  // Bit 1
        #00000100 detMore ?
        #00000111 detAll       0x04  // Bit 2  
        
        # struct.h            
        # if (fRobberBaronActive && prtPlanet->fMinedRemotely) {      prtPlanet->fInclude = 1;
        # if (!prtPlanet->fOwned && !prtPlanet->fPopulated) {  prtPlanet->fInclude = 0;
        # if (prtPlanet->fMinedRemotely) {  CalculateMining(prtPlanet);
        # if (fRobberBaronActive && prtPlanet->resources > 0) { prtPlanet->fMinedRemotely = 1;
        # if (lppl->iPlayer == -1 && lppl->det >= detSome)  // Mark value as a mining destination.
        # if (lppl->det >= detSome) {     IncludeInReport(lppl);
        # Owned or inhabitable planets vs unowned planets. Processed/saved  or skipped. population growth, resource generation, or starbase activity. Included or not in reports. Uninhabited planets being remote-mined by a Robber Baron are often marked for inclusion
        #                                                                     # Bits 4-6 not used
	      $fHomeworld  = ($flags >> 7  & 0x01) != 0; # Extract 'fInclude' (1 bit at bit position 7)      isHomeworld                
        $fInclude    = ($flags >> 8) & 0x01 != 0;  # Extract 'fInclude' (1 bit at bit position 8)      fInclude
        $fStarbase   = ($flags >> 9) & 0x01 != 0;  # Extract 'fStarbase' (1 bit at bit position 9)     fStarbase  
        $fIncEVO     = ($flags >> 10) & 0x01 != 0; # Extract 'fIncEVO' (1 bit at bit position 10).     isTerraformed       
        $fIncImp     = ($flags >> 11) & 0x01 != 0; # Extract 'fIncImp' (1 bit at bit position 11)      hasInstallations             
        $fIsArtifact = ($flags >> 12) & 0x01 != 0; # Extract 'fIsArtifact' (1 bit at bit position 12)  hasArtifact              
        $fincSurfMin = ($flags >> 13) & 0x01 != 0; # Extract 'fIncSurfMin' (1 bit at bit position 13)  hasSurfaceMinerals              
        $fRouting    = ($flags >> 14) & 0x01 != 0; # Extract 'fRouting' (1 bit at bit position 14)     hasSurfaceMinerals   
        # We need to know if a planet has been in the history file past a turn generation.
				# That way we can send "discovery" messages even if you Save and Load.  Otherwise
				# we would only send you the messages the first time you load the turn file.       
        $fFirstYear  = ($flags >> 15) & 0x01 != 0; # Extract 'fFirstYear' (1 bit at bit position 15)   fFirstYear

	      if (($flags & 0x0100) != 0x0100) { die "Unexpected planet flags 100: $flags"; } # bit 8, 9th bit
        if (($flags & 0x0078) != 0) {  die "Unexpected planet flags 78: $flags";  }  # bits 3, 4, 5, and 6 (0 indexed)

          $planetId++;
          if ($ownerId >=0) {$ownerId++;}
          if ($display) {
            print "\nPlanet ID: $planetId, \
            Owner ID: $ownerId, \
            Det: $det[$det] $det, \
            Homeworld: $fHomeworld, \
            fInclude: $fInclude, \
            Starbase: $fStarbase, \
            Terraformed: $fIncEVO, \
            Installation: $fIncImp, \
            Artifact: $fIsArtifact, \
            Surface: $fincSurfMin, \
            Route: $fRouting, \
            FirstYear: $fFirstYear,\
            \n";
        }
        if ($typeId == 15) { next;}  # if rtPlanetC, minimal info
        if ($det == 7 || $det == 3) {  # detAll or detSome
        #my $canSeeEnvironment = ($hasEnvironmentInfo || ( ($fincSurfMin || $isInUseOrRobberBaron) && !$bitWhichIsOffForRemoteMiningAndRobberBaron) );  #if ($det == 7 || $det == 3) {  # detAll or detSome
        #if ($canSeeEnvironment) {  
          my $isGermLevelConc = ( $decryptedData[4] & 0b00110000 ) >> 4;  # first 2 bits
          my $isBorLevelConc = ( $decryptedData[4] & 0b00001100 ) >> 2;  # 2nd 2 bits
          my $isIronLevelConc = ( $decryptedData[4] & 0b00000011 ); # 3rd 2 bits
          if ($display) { print "Concentration available:  iron: $isIronLevelConc, bor: $isBorLevelConc, germ: $isGermLevelConc\n"; }
          
          my $preEnvironmentLengthByte = $decryptedData[4];
          if (($preEnvironmentLengthByte & 0xC0) != 0) { die "Unexpected bits at data[4]: "; }
          my $preEnvironmentLength = 1;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x30) >> 4;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x0C) >> 2;
          $preEnvironmentLength += ($preEnvironmentLengthByte & 0x03);
          my @fractionalMinConcBytes = @decryptedData[4 .. 4 + $preEnvironmentLength - 1];          
          $index += $preEnvironmentLength;
#           if ( $isIronLevelConc == 1) { $ironiumLevelConc = $decryptedData[$index++]; }
#           if ( $isBorLevelConc  == 1) { $boraniumLevelConc = $decryptedData[$index++]; }
#           if ( $isGermLevelConc == 1) { $germaniumLevelConc = $decryptedData[$index++]; }   
          $ironiumLevelConc = $decryptedData[$index++]; 
          $boraniumLevelConc = $decryptedData[$index++]; 
          $germaniumLevelConc = $decryptedData[$index++];    
          if ($display) { print "Mineral Level Concentrations: iron: $ironiumLevelConc, bor: $boraniumLevelConc, germ: $germaniumLevelConc\n"; }

          $gravity = $decryptedData[$index++]; 
          $temperature = $decryptedData[$index++];
          $radiation = $decryptedData[$index++];
          if ($display) { print "Hab: Grav: $gravity (" . &showHab($gravity, 0) . "), temp: $temperature (" . &showHab($temperature, 1) . "), rad: $radiation (" . &showHab($radiation, 2) . ")\n"; }

          if ($fIncEVO) { 
            $origGravity = $decryptedData[$index++]; 
            $origTemperature = $decryptedData[$index++];
            $origRadiation = $decryptedData[$index++];
            if ($display) { print "Orig Hab: $origGravity, $origTemperature, $origRadiation\n"; }
          }
          
          if ($ownerId > -1) { # If the planet is owned
            my $guess = &read16(\@decryptedData, $index); 
            $popGuess = $guess & 0x3FF;     # first 12 bits
            $defGuess = $guess >> 12;        #last 4 bits
            #$popGuess = $guess / 4096;     # first 12 bits
            #$defGuess = $guess % 4096;        #last 4 bits
            if ($display) { print "PopGuess: $popGuess, DefGuess:" . ($defGuess*6 + 3) . "\n"; }
            $index+=2;
          }
        }
        #if ($det < 3) {
        if ($fincSurfMin) {
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
        
#        if ($typeId == 13) {  # if rtPlanetA / Block type 13
          #my @installationsBytes;
          if ($fIncImp) {   # If there are installations
#             @installationsBytes = @decryptedData[$index..$index+7]; # cut this down to 8 bytes for simplicity
#             if (($installationsBytes[6] & 0x7E) != 0 || $installationsBytes[7] != 0) { die "Unexpected installations data: ";  }
#             $iDeltaPop = $installationsBytes[0] & 0xFF; # 8 bits  Excess Pop
#             $cMines = ($installationsBytes[1] & 0xFF) | ($installationsBytes[2] & 0x0F) << 8;  # 12 bits
#             $cFactories = ($installationsBytes[2] & 0xF0) >> 4 | ($installationsBytes[3] & 0xFF) << 4;  # 12 bits
#             $cDefenses = ($installationsBytes[4] & 0xFF) | ($installationsBytes[5] & 0x0F) << 8; # 12 bits
#             $fArtifact = $installationsBytes[5]; # unknownInstallationsByte
#             $iScanner = ($installationsBytes[6] & 0x1F);  # 5 bits
#             $fNoResearch = ($installationsBytes[6] & 0x80) != 0; # Don't contribute to research unless there's nothing to build here
#             $hasScanner = ($installationsBytes[6] & 0x01) == 0;
#             # 8 unused bits
#             print "Installations: iDeltaPop: $iDeltaPop, Mine: $cMines, Factory: $cFactories, Defense: $cDefenses, iScan: $iScanner, Artifact: $fArtifact, NoRes: $fNoResearch, hasScan: $hasScanner\n"; 
            
            my $installationsBytes = &read64(\@decryptedData, $index);
            $iDeltaPop   = ($installationsBytes >> 0)  & 0xFF;    # Extract the first 8 bits
            $cMines      = ($installationsBytes >> 8)  & 0xFFF;   # Extract the next 12 bits
            $cFactories  = ($installationsBytes >> 20) & 0xFFF;   # Extract the next 12 bits
            $cDefenses   = ($installationsBytes >> 32) & 0xFFF;   # Extract the next 12 bits
            $iScanner    = ($installationsBytes >> 44) & 0x1F;    # Extract the next 5 bits
            my $unused5  = ($installationsBytes >> 49) & 0x1F;    # Extract the next 5 bits
            $fArtifact   = ($installationsBytes >> 54) & 0x1;     # Extract the next 1 bit
            $fNoResearch = ($installationsBytes >> 55) & 0x1;     # Extract the next 1 bit   # Don't contribute to research unless there's nothing to build here
            my $unused2  = ($installationsBytes >> 56) & 0xFF;    # Extract the final 8 bits
            if ($display) { print "Installations: iDeltaPop: $iDeltaPop, Mine: $cMines, Factory: $cFactories, Defense: $cDefenses, iScan: $iScanner, Artifact: $fArtifact, NoRes: $fNoResearch\n"; } 
               
            $index += 8;
          }
#        }
    
        if ($fStarbase) {
          if ($typeId == 14) { # Partial Planet Block
          #if ($det <=3) { # Partial Planet Block
            my $starbaseByte = $decryptedData[$index++];
            $isb = $starbaseByte & 0x0F;
            if ($display) { print "Starbase: Design: $isb\n"; }
            #if (($starbaseByte & 0xF0) != 0) { die "Unexpected starbase byte: "; }
          } else {
            my $field = read32(\@decryptedData, $index);  # Read 32-bit value for full starbase info
            $isb        = &extract_bitfield($field, 0, 4);   # StarbaseDesign
            $pctDp      = &extract_bitfield($field, 4, 12);  # StarbaseDamage
            $idFling    = &extract_bitfield($field, 16, 10);
            $iWarpFling = &extract_bitfield($field, 26, 4);
            $fNoHeal    = &extract_bitfield($field, 30, 1);   # second to last bit  // We got damaged this year (turn gen only).
            my $unused     = &extract_bitfield($field, 31, 1);
            if ($display) { print "Starbase: Design: $isb, Damage: $pctDp, Fling: $idFling, Warp: $iWarpFling, NoHeal: $fNoHeal\n"; }
            $index += 4;
		      }
        
          if ($fRouting == 1) { 
            $idRoute = &read16(\@decryptedData, $index) & 0b1111111111; # First 10 bits Route destination Id
            #  last 6 bits unused
            $index += 2;
            if ($display) { print "route: $idRoute\n"; }        
          }

          if ($index + 1 < @$decryptedData) {
              $turn_number = &read16(\@decryptedData, $index);
              if ($display) { print "discovered: $turn_number (" . ($turn_number + 2400) . ")\n"; }  
          }
       }
 
      } else { # Block type not found
      }
      # END OF MAGIC
    } 
    $offset = $offset + (2 + $size); 
  } 
} # end sub

################################################################################
sub extract_bitfield {
    my ($value, $start_bit, $num_bits) = @_;
    return ($value >> $start_bit) & ((1 << $num_bits) - 1);
}


