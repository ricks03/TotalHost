# StarsClean.pl
# Clean shared information out of .m files
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191114 - Started dev
# 191122 - Added player read
# 191123 - Added CA clean
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

# Removes "privileged" information from a .m file
#
# .m files include other player information about:
#    Mystery Trader (tech offered and who has met with him)
#    wormholes (who can and can't see, who has jumped in and who hasn't)
#    minefields (who can see it)
#    CA (more player information on other races than appropriate)

# Example Usage: StarsClean.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# And takes inspiration from Xyligun's StarsKnowledgeCleaner.exe

#Some of the bytes in minefields differ from player to player inexplicably

#Currently:
# Cleans MT cargo (sets to "research")
# Cleans who has visited mystery trader (only player)
# Cleans who has seen minefields (only player)
# Cleans who has seen wormholes (only player)
# Cleans who has been through a wormhole (only player)
# Cleans CA known player information

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0; # Enable better debugging output. Bigger the better
my $clean = 1; # 0, 1, 2: display, clean but don't write, write 

# For Object Block 43 
my $objectId;    
my $count = -1;
my $number;
my $owner;
my $type; # 0 = minefield, 1 = packet/salvage, 2 = wormhole, 3 = MT
my ($x, $y);
# For MT
my ($xDest, $yDest);
my $warp;
my $metBits;
my $itemBits;
my $turnNo;
my $turnNoDisplay;
#For minefields
my $mineCount;
my $mineDetonate;
my $mineType;
#For wormholes
my $wormholeId;
my $targetId;
my $beenThrough;    
my $canSee;
my $stability;
# For packets
my $targetAndSpeed;
my ($destPlanetId, $WarpSpeedMinus4, $WarpOverMDLimit);
my ($ironium, $boranium, $germanium);
#holding values for unknown variables
my ($unk1, $unk2, $unk3, $unk4, $unk5) = '';  

# For Player Block 6
my $playerId;  # int , 1 byte
my $ShipSlotsUsed;   # intm 1 byte
my $PlanetCount;       # int, 2 bytes
my $FleetAndStarBaseDesignCount;        # int , 2 bytes
my $FleetCount; # 12 bits
my $StarBaseDesignCount; # 4 bits
my $logo;          # int
my $fullDataFlag;  # boolean
my $fullDataBytes; # byte
my $playerRelations; # byte, 0 neutral, 1 friend, 2 enemy
my $nameBytes;     #byte
my $byte7 = 1;
my @singularRaceName;
my @pluralRaceName;

#my @resetRace =  ( 0,6,2,0,6,16,15,1,81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,2,2,6,183,222,219,22,116,214,7,183,222,219,22,116,214 );
# The values used when cleaning race values. Defaults to Humanoids
my @resetRace =  ( 81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 );

#Stars random number generator class used for encryption
my @primes = ( 
                3, 5, 7, 11, 13, 17, 19, 23, 
                29, 31, 37, 41, 43, 47, 53, 59,
                61, 67, 71, 73, 79, 83, 89, 97,
                101, 103, 107, 109, 113, 127, 131, 137,
                139, 149, 151, 157, 163, 167, 173, 179,
                181, 191, 193, 197, 199, 211, 223, 227,
                229, 233, 239, 241, 251, 257, 263, 279,
                271, 277, 281, 283, 293, 307, 311, 313 
        );

##########  
my @fileBytes;
my @mFiles;      
my $inName = $ARGV[0]; # input file
my $outName = $ARGV[1];
my $filename;

if (!($inName)) { 
  print "\n\nRemoves other player minefield, MT, wormhole, and race information from .M files.\n";
  print "\n\nUsage: StarsClean.pl <input> <output (optional)>\n\n";
  print "Please enter the .M input. Example: \n";
  print "  StarsClean.pl c:\\games\\test.m6\n\n";
  print "For files, by default, a new file will be created: <filename>.clean\n\n";
  print "You can create a different file with: StarsClean.pl <filename> <newfilename>\n";
  print "  StarsClean.pl <filename> <filename> will overwrite the original file.\n\n";
  print "Also works for all .M files in a directory. Example: \n";
  print "  StarsClean.pl c:\\games\n";
  print "  or\n"; 
  print "  StarsClean.pl c:\\games1 c:\\games2  <directory2 must exist>\n\n";
  print "  StarsClean c:\\games c:\\games will overwrite the local files.\n\n";
  print "The script will try to save you if you choose file and directories poorly,\n";
  print "  but as always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

#Validate directory or file 
unless (-d $inName || -e $inName ) { 
  print "Requested object: $inName does not exist!\n"; exit; 
}

# Get all the file names in the directory, or just the one name
# Note that directories test for files, but files don't test
# for directories
if (-d $inName) {  
  # If a directory name was specified
  my $file;
  my $fullName;
  opendir(BIN, $inName) or die "Cannot open directory $inName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
    $fullName = $inName . '\\' . $file;
    push @mFiles, $fullName;
  }
} elsif (-e $inName) { 
  # If a .m file name was specified
  if ($inName =~ /^.*\.[mM]\d*$/) {   $mFiles[0] = $inName; }
}

if (@mFiles == 0) { 
  die "Something went wrong. There\'s no information\nDid you specify a .M file?\n"; 
}

foreach $filename (@mFiles) {
# Loop through for each .m file in the directory
# and clean it
  my ($basefile, $dir, $ext);
  # for c:\stars\mygamename.m1
  $basefile = basename($filename);    # mygamename.m1
  $dir  = dirname($filename);         # c:\stars
  ($ext) = $basefile =~ /(\.[^.]+)$/; # .m  extension
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  @fileBytes = ();
  open(StarFile, "<$filename" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
#  my ($outBytes) = &decryptBlock(@fileBytes);
  my ($outBytes) = &decryptBlock();
  my @outBytes = @{$outBytes};
  
  # Create the output file name(s)
  # taking into account the paths provided. 
  my $newFile; 
  if (-e $inName) {
    # if the outName was defined
    if ($outName) {   $newFile = $outName;  } 
    # Otherwise, safety first
    else { $newFile = $dir . '\\' . $basefile . '.clean'; }
    # and because I dont like fiddling with it when debugging
    if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me
  } elsif (-d $inName && $inName eq $outName ) {
    # if inName was a directory, and outName is the same location
    # overwrite the existing files
    $newFile = $dir . '\\' . $basefile;
  } elsif (-d $outName) {
    # Otherwise create the files in the new location.   
    $newFile = $outName . '\\' . $basefile; 
  } else { die "What happened to the name?\n"; }
  
  # Output the Stars! File with modified data
  # Don't do unless in clean write mode
  if ($clean > 1) {
    open ( outFile, '>:raw', "$newFile" );
    for (my $i = 0; $i < @outBytes; $i++) {
      print outFile $outBytes[$i];
    }
    close ( outFile);
    
    print "File output: $newFile\n";
    unless ($ARGV[1] || -d $inName ) { print "Don't forget to rename $newFile\n"; }
  }
} 

################################################################
sub decryptBlock {
  #my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY );
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
    # FileHeaderBlock, never encrypted
    if ($typeId == 8 ) { # File Header Block
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      unless ($Magic eq 'J3J3') { die "One of the files is not a .M file. Stopped along the way."; }
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      print "Turn:" . ($turn+2400) . "\n";
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } elsif ($typeId == 7) {
      # BUG: Note that planet's data requires something extra to decrypt. 
      # Fortunately block 7 isn't in my test files
      die 'BLOCK 7 found. ERROR!\n'; 
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };    
      # WHERE THE MAGIC HAPPENS
      &processData(\@decryptedData,$typeId,$offset,$size,$Player);
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug > 1) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub processData {
  # Process the decrypted bytes
  my ($decryptedData,$typeId,$offset,$size,$Player)  = @_;
  my @decryptedData = @{ $decryptedData };
  if ($typeId == 43) { # Check for special attributes in the Object Block
    if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
    if ($size == 2) {
      my $count = &read16(\@decryptedData, 0);
    } else {
      $objectId =  &read16(\@decryptedData, 0);
      $number = $objectId & 0x01FF;
      $owner = ($objectId & 0x1E00) >> 9;
      $type = $objectId >> 13;
      # BUG: MTID 12 bits, Type 4 bits.
      # BUG: Wormhole ID 12 bits, Type ID 4 bits
      
      # Mystery Trader
      if (&isMT($type)) {
        $x = &read16(\@decryptedData, 2);
        $y = &read16(\@decryptedData, 4);
	      $xDest = &read16(\@decryptedData, 6);
  			$yDest = &read16(\@decryptedData, 8);
  			$warp = $decryptedData[10] % 16;
  			$metBits = &read16(\@decryptedData, 12);
  			$itemBits = &read16(\@decryptedData, 14);
  			$turnNo = &read16(\@decryptedData, 16); # Which doesn't report turn like everything else
        $turnNoDisplay =  $turnNo + 2401;
        my $MTPart = &getMTPartName($itemBits);
        if ($debug) { print "typeId: $typeId, objectId: $objectId, number: $number, owner = $owner, typeId = $type\n"; }
        print "turn:$turnNoDisplay, Mystery Trader: x: $x, y: $y, xDest: $xDest, yDest: $yDest, warp: $warp, met: " . &getPlayers($metBits) . ", $MTPart\n";
        if ($clean) { 
          # Reset players who has traded with MT
          ($decryptedData[12], $decryptedData[13]) = &resetPlayers($Player, &read16(\@decryptedData, 12));
          # reset values for display
          $metBits = &read16(\@decryptedData, 12);
          # Reset the MT Part
          $decryptedData[14] = 0;
          $decryptedData[15] = 0;
          # reset part values for display
  			  $itemBits = &read16(\@decryptedData, 14);
          $MTPart = &getMTPartName($itemBits);
        }
        print "turn:$turnNoDisplay, Mystery Trader: x: $x, y: $y, xDest: $xDest, yDest: $yDest, warp: $warp, met: " . &getPlayers($metBits) . ", $MTPart\n";
      # Minefields
      } elsif (&isMinefield($type)) {
        # BUG: decay rate? (might be calculated)
        $x = &read16(\@decryptedData, 2); # 2 bytes
        $y = &read16(\@decryptedData, 4); # 2 bytes
        $mineCount = &read32(\@decryptedData, 6); # 4 bytes
        $canSee = &read16(\@decryptedData, 10);
        my $mineStatus = &read16(\@decryptedData, 12);   # includes detonating
        $mineStatus = dec2bin($mineStatus);
        my @mineStatus;
        for (my $i=0; $i < 16; $i++)  {
           $mineStatus[$i] = substr($mineStatus,$i,1); 
        }
        $mineDetonate = &getMineDetonate(\@mineStatus); # bit 7 is detonating  status
        $mineType = &getMineType(\@mineStatus); # bit 14+15 = mine type
        $unk4 = &read16(\@decryptedData, 14);  # BUG: What is this, not player ID
        $turnNo = &read16(\@decryptedData, 16);
        $turnNoDisplay =  $turnNo + 2401;
        if ($debug) { print "typeId: $typeId, objectId: $objectId, minefieldId: $number, playerId: $owner, typeId: $type\n"; }
        print "turn:$turnNoDisplay, MineField: x: $x, y: $y, mineCount: $mineCount, canSee: " . &getPlayers($canSee) . ", $mineType, $mineDetonate, unk4: $unk4\n";
        if ($clean) {
          # Hard to find any data here as not much is known of the format
          # Reset players who can see the minefield
          ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
          # reset values for display
          $canSee = &read16(\@decryptedData, 10);
        }
        print "turn:$turnNoDisplay, MineField: x: $x, y: $y, mineCount: $mineCount, canSee: " . &getPlayers($canSee) . ", $mineType, $mineDetonate, unk4: $unk4\n";

      #Wormholes
      } elsif (isWormhole($type)) {
        $x = &read16(\@decryptedData, 2);
        $y = &read16(\@decryptedData, 4);
        $stability = &read16(\@decryptedData, 6);
        #$stability = &dec2bin($stability);
	      $canSee = &read16(\@decryptedData, 8);
	      $beenThrough = &read16(\@decryptedData, 10);
	      $targetId = &read16(\@decryptedData, 12) % 4096;   
        # BUG: One of these fields is likely wormhole AGE.
        $unk4 =  &read16(\@decryptedData, 12); #possibly random amount added to last stability value ?
        $unk4 = &dec2bin ($unk4);                        
        $unk5 =  &read16(\@decryptedData, 14);  # Always zeros? 
        $unk5 = &dec2bin ($unk5);                        
        $turnNo = &read16(\@decryptedData, 16);
        $turnNoDisplay =  $turnNo + 2401;
        if ($debug) { print "typeId: $typeId, objectId: $objectId, wormholeId: $number, typeId = $type\n"; }
        print "turn:$turnNoDisplay, Wormhole: x: $x, y: $y, TID: $targetId, stability: $stability, beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee) . ", unk5: $unk5, unk4: $unk4\n";
        if ($clean) { 
          # Reset players who can see wormhole
          ($decryptedData[8], $decryptedData[9]) = &resetPlayers ($Player, &read16(\@decryptedData, 8));
          # reset values for display
	        $canSee = &read16(\@decryptedData, 8);
          # Reset players who are known to have been through
          ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
          # reset values for display
          $beenThrough = &read16(\@decryptedData, 10);
        }
        print "turn:$turnNoDisplay, Wormhole: x: $x, y: $y, TID: $targetId, stability: $stability, beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee) . "\n";

      # Packet
      } elsif (&isPacketOrSalvage($type)) {
        $x = &read16(\@decryptedData, 2);
        $y = &read16(\@decryptedData, 4);
        $targetAndSpeed = &read16(\@decryptedData, 6);
        $targetAndSpeed = &dec2bin($targetAndSpeed);
        $destPlanetId = substr($targetAndSpeed,6,10);       # 10 bits
        $destPlanetId = &bin2dec($destPlanetId);
        $WarpSpeedMinus4 = substr($targetAndSpeed,2,4); #4 bits
        $WarpSpeedMinus4 = &bin2dec($WarpSpeedMinus4);
        $WarpOverMDLimit = substr($targetAndSpeed,2,2);# 2 bits 
        $WarpOverMDLimit = &bin2dec($WarpOverMDLimit);
        $ironium = &read16(\@decryptedData, 8);
        $boranium = &read16(\@decryptedData, 10);
        $germanium = &read16(\@decryptedData, 12);
        # BUG: there's data that changes in byte 14. 
        # fairly certain this isn't a player ID or CanSee??
        $unk5 = &dec2bin(&read16(\@decryptedData, 14)); 
        $turnNo = &read16(\@decryptedData, 16); # Doesn't appear to be turn info like the rest
        $turnNoDisplay = $turnNo + 2401;
        if ($debug) { print "typeID: $typeId, objectId: $objectId, salvageId: $number, ownerId: $owner, typeId: $type\n"; }
        my $warpSpeed = $WarpSpeedMinus4 + 4;
        print "turn:$turnNoDisplay, Packet: x: $x, y: $y, DestPlanetId: $destPlanetId, " . &getPacketType($destPlanetId) . ", Warp Speed: " . $warpSpeed . ", WarpOverMDLimit: $WarpOverMDLimit,  ironium: $ironium, boranium: $boranium, germanium: $germanium, unk5: $unk5\n";
        if ($clean) {
          # Decay rate wouldn't be public.
          # Packet ownership must be included in here somewhere
        }
        print "turn:$turnNoDisplay, Packet: x: $x, y: $y, DestPlanetId: $destPlanetId, " . &getPacketType($destPlanetId) . ", Warp Speed: $warpSpeed, WarpOverMDLimit: $WarpOverMDLimit,  ironium: $ironium, boranium: $boranium, germanium: $germanium, unk5: $unk5\n";
      }
    }
  }
  if ($typeId == 6) { # Player Block
    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
    print &showRace(\@decryptedData,$size);
    if ($clean) {   
      @decryptedData = &resetRace(\@decryptedData,$Player);
      if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; } 
      print "Cleaned Race:\n" . &showRace(\@decryptedData,$size);  
    }
  }
  return @decryptedData;
}

