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
# Note that the race file has a checksum value, so writing out changes will 
# fail.
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
my $debug = 1;

#$hexDigits      = "0123456789ABCDEF";
my $encodesOneByte = " aehilnorst";
my $encodesB       = "ABCDEFGHIJKLMNOP";
my $encodesC       = "QRSTUVWXYZ012345";
my $encodesD       = "6789bcdfgjkmpquv";
my $encodesE       = "wxyz+-,!.?:;\'*%\$";

my @singularRaceName;
my @pluralRaceName;

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
my ($outBytes) = &decryptBlock(@fileBytes);
my @outBytes = @{$outBytes};


################################################################
sub StarsRandom {
  my ($seedA, $seedB, $initRounds) = @_;  
  my $randomNumber;
  # Now initialize a few rounds
  for (my $i = 0; $i < $initRounds; $i++) { 
    ($randomNumber, $seedA, $seedB) = &nextRandom($seedA, $seedB);
  }
  return $seedA, $seedB;
}
        
sub nextRandom {
  my ($seedA, $seedB) = @_; 
  my ($seedApartA, $seedApartB);
  my ($seedBpartA, $seedBpartB);
  my ($newSeedA, $newSeedB);
  my $randomNumber;
  # First, calculate new seeds using some constants
  $seedApartA = ($seedA % 53668) * 40014;
  $seedApartB = int(($seedA / 53668)) * 12211; # integer division OK
  $newSeedA = $seedApartA - $seedApartB;
  $seedBpartA = ($seedB % 52774) * 40692;
  $seedBpartB = int(($seedB / 52774)) * 3791;
  $newSeedB = $seedBpartA - $seedBpartB;
  # If negative add a whole bunch (there's probably some weird bit math
  # going on here that the disassembler didn't make obvious)
  if ($newSeedA < 0) { $newSeedA += 0x7fffffab; }
  if ($newSeedB < 0) { $newSeedB += 0x7fffff07; }
  # Generate "random" number.  This will fit into an unsigned 32-bit integer
  $randomNumber = $newSeedA - $newSeedB;
#  if ($seedA < $seedB) { $randomNumber += 0x100000000l; }  # 2^32
  if ($newSeedA < $newSeedB) { $randomNumber += 4294967296; }  # 2^32
  # Now return our random number
  return $randomNumber, $newSeedA, $newSeedB;
}

sub getFileHeaderBlock {
#$Header-S, $Magic=A4, $lidGame-h8, $ver-S, $turn-S $iPlayer-S, $dts-S)
# S/s - Unsigned/signed Short     (exactly 16-bits, 2 bytes) 
# h/H -  hex string, low/high nybble first. 1 byte?
# A - ASCII string, blank padded. 1 byte
# L - unsigned long, 32 bits, 4 bytes
  my ($fileBytes) = @_;
  my @fileBytes = @{ $fileBytes };
  my ($bytes, $Header, $Magic, $lidGame, $ver, $turn, $iPlayer); 
  my ($dts, $binHeader, $blocktype, $blocksize, $verInc);
  my ($verMinor, $verMajor, $verClean, $Player, $binSeed, $Seed, $dt); 
  my ($fDone, $fInUse, $fMulti, $fGameOver, $fShareware);
  # Unpack the FileHeaderBlock data
  # 2 bytes
  $bytes = $fileBytes[0] . $fileBytes[1];
  $Header = unpack ("S", $bytes);
  # 4 bytes
  $bytes = $fileBytes[2] . $fileBytes[3] . $fileBytes[4] . $fileBytes[5];
  $Magic = unpack ("A4", $bytes);
  # 4 bytes
  $bytes =  $fileBytes[6] . $fileBytes[7] . $fileBytes[8] . $fileBytes[9];
  $lidGame = unpack ("L",  $bytes);
  # 2 bytes
  $bytes = $fileBytes[10] . $fileBytes[11];
  $ver = unpack ("S", $bytes);
  # 2 bytes
  $bytes = $fileBytes[12] . $fileBytes[13];
  $turn = unpack ("S", $bytes); # $turn + 2400 = turn
  # 2 bytes
  $bytes = $fileBytes[14] . $fileBytes[15];
  $iPlayer = unpack ("s", $bytes);
  # 2 bytes
  $bytes = $fileBytes[16] . $fileBytes[17];
  $dts = unpack ("S", $bytes);
  # Convert the data to its usable form
  $binHeader = dec2bin($Header);
  $blocktype = (substr($binHeader, 0,6));
  $blocktype = bin2dec($blocktype);
  $blocksize = (substr($binHeader, 7,2)) . (substr($binHeader, 8,8));
  $blocksize = bin2dec($blocksize);
  # Game Version
  $ver = dec2bin($ver);
  $verInc = substr($ver,11,5);
  $verMinor = substr($ver,4,7);
  $verMajor = substr($ver,0,4);
  $verMajor = bin2dec($verMajor);
  $verMinor = bin2dec($verMinor);
  $verInc = bin2dec($verInc);
  $ver = $verMajor . "." . $verMinor . "." . $verInc;
  $verClean = $verMajor . "." . $verMinor;
  # Player Number
  $iPlayer = &dec2bin($iPlayer);
  $Player = substr($iPlayer,11,5);
  $Player = bin2dec($Player); # note from 0-15
  # Encryption Seed
  $binSeed =  substr($iPlayer,0,11);
  $Seed = bin2dec($binSeed);
  # dts - Convert DTS to binary so we can pull the values back out
  $dts = dec2bin($dts);
  #Break DTS into its binary components
  $dt = substr($dts, 8,15);
  $dt = bin2dec($dt);
  # File Type
  # These are 1 character, so there's no need to convert them back to decimal
  # Turn state (.x file only)
  $fDone = substr($dts, 7,1);
  # Host instance is using this file (dtHost, dtTurn).
  $fInUse = substr($dts, 6, 1);
  # Are multiple turns included (.m only)
  $fMulti = substr($dts, 5,1);
  # Is the Game Over
  $fGameOver = substr($dts, 4,1);  # Probably 4
  # Shareware
  $fShareware = substr($dts, 3, 1);
  if ($debug>2) { print "binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame\n"; }
  return $binSeed, $fShareware, $Player, $turn, $lidGame;
}
    
sub initDecryption {
  # Need the values from the FileHeaderBlock to seed the encryption
  my ($binSeed, $fShareware, $Player, $turn, $lidGame) = @_;
  my ($salt, $index1, $index2);
  my ($part1, $part2, $part3, $part4); 
  my ($rounds, $random, $seedA, $seedB);
  # Convert fileBytes back to an array. Use two prime numbers as random seeds.
	# First one comes from the lower 5 bits of the salt
  $salt = bin2dec($binSeed);
 	$index1 = $salt & 0x1F;
	# Second index comes from the next higher 5 bits
	$index2 = ($salt >> 5) & 0x1F;
  #Adjust our indexes if the highest bit (bit 11) is set
	#If set, change index1 to use the upper half of our primes table
	if(($salt >> 10) == 1) { $index1 += 32; 
	#else index2 uses the upper half of the primes table
	} else { $index2 += 32; }
  #Determine the number of initialization rounds from 4 other data points
	#0 or 1 if shareware (I think this is correct, but may not be - so far
	#I have not encountered a shareware flag
	$part1 = $fShareware;
  #Lower 2 bits of player number, plus 1
	$part2 = ($Player & 0x3) + 1;
	#Lower 2 bits of turn number, plus 1
	$part3 = ($turn & 0x3) + 1;
	#Lower 2 bits of gameId, plus 1
	$part4 = ($lidGame & 0x3) + 1;
  #Now put them all together, this could conceivably generate up to 65 
	# rounds  (4 * 4 * 4) + 1
	$rounds = ($part4 * $part3 * $part2) + $part1;
  #Now initialize our random number generator
	($seedA, $seedB) = &StarsRandom($primes[$index1], $primes[$index2], $rounds);
  return  $seedA, $seedB;
}
    
sub decryptBytes {
  my ($byteArray, $seedA, $seedB) = @_;
  my @byteArray = @{ $byteArray }; 
  my $size = @byteArray;
  my @decryptedBytes;
  my ($decryptedChunk, $decryptedBytes, $newRandom, $chunk);
  my $padding;
  # Add padding to 4 bytes
  ($byteArray, $padding) = &addPadding (\@byteArray);
  @byteArray = @ {$byteArray };
  my $paddedSize = $size + $padding;
 # Now decrypt, processing 4 bytes at a time
  @decryptedBytes = ();
  for (my $i = 0; $i <  $paddedSize; $i+=4) {
    # Swap bytes using indexes in this order:  4 3 2 1
    $chunk =  (
        (ord($byteArray[$i+3]) << 24) | 
        (ord($byteArray[$i+2]) << 16) | 
        (ord($byteArray[$i+1]) << 8)  | 
         ord($byteArray[$i])
    );
    # XOR with a (semi) random number
    ($newRandom, $seedA, $seedB) = &nextRandom($seedA, $seedB);
    # Store the random value being used to start the decryption, as I'll 
    # need it to reencrypt the player information
    $decryptedChunk = $chunk ^ $newRandom;
    # Write out the decrypted data, swapped back
    my $decryptedBytes = $decryptedChunk & 0xFF;
    push @decryptedBytes, $decryptedBytes;
    $decryptedBytes = ($decryptedChunk >> 8) & 0xFF;
    push @decryptedBytes, $decryptedBytes;
    $decryptedBytes = ($decryptedChunk >> 16) & 0xFF;
    push @decryptedBytes, $decryptedBytes;
    $decryptedBytes = ($decryptedChunk >> 24) & 0xFF;
    push @decryptedBytes, $decryptedBytes;
  }    
  # Strip off any padding
  @decryptedBytes = &stripPadding(\@decryptedBytes, $padding);
  return \@decryptedBytes, $seedA, $seedB, $padding;
}      

sub encryptBytes {
  my ($byteArray, $seedX, $seedY, $padding) = @_; 
  my @byteArray = @{ $byteArray };
  my @encryptedBytes;
  my ($chunk, $newRandom, $encryptedBytes, $encryptedChunk);
  my $size = @byteArray;
  # Add padding to 4 bytes
  ($byteArray, $padding) = &addPadding(\@byteArray);
  @byteArray = @ {$byteArray };
  my $paddedSize = $size + $padding;
  # Now encrypt, processing 4 bytes at a time
  for(my $i = 0; $i <$paddedSize; $i+=4) {
  # Swap bytes:  4 3 2 1
    $chunk = (
        ($byteArray[$i+3] << 24) | 
        ($byteArray[$i+2] << 16) | 
        ($byteArray[$i+1] << 8)  | 
         $byteArray[$i]
    );
    # XOR with a (semi) random number
    ($newRandom, $seedX, $seedY) = &nextRandom($seedX, $seedY);
    $encryptedChunk = $chunk ^ $newRandom;
    # Write out the decrypted data, swapped back
    $encryptedBytes = chr($encryptedChunk         & 0xFF);
    push @encryptedBytes, $encryptedBytes;
    $encryptedBytes = chr(($encryptedChunk >> 8)  & 0xFF);
    push @encryptedBytes, $encryptedBytes;
    $encryptedBytes = chr(($encryptedChunk >> 16) & 0xFF);
    push @encryptedBytes, $encryptedBytes;
    $encryptedBytes = chr(($encryptedChunk >> 24) & 0xFF);
    push @encryptedBytes, $encryptedBytes;
  }
  # Strip off any padding
  @encryptedBytes = &stripPadding(\@encryptedBytes, $padding);
  return \@encryptedBytes, $seedX, $seedY;
}   
      
# sub parseBlock {
#   # This returns the 3 relevant parts of a block: typeId, size, raw block data
#   my ($fileBytes, $offset) = @_;
#   my @fileBytes = @{ $fileBytes };
#   my @blockdata;
#   my ($blocktype, $blocksize) = &read16(\@fileBytes, $offset);
#   for (my $i = $offset+2; $i < $offset+$blocksize+2; $i++) {   #skipping over the TypeID
#     push @blockdata, $fileBytes[$i];
#   }
#   return ($blocktype, $blocksize, \@blockdata);
# } 

sub parseBlock {
  # This returns the 3 relevant parts of a block: blockId, size, raw block data
  my ($fileBytes, $offset) = @_;
  my @fileBytes = @{ $fileBytes };
  my @blockdata;
  my ($FileValues, @FileValues, $Header);
  my ($binHeader, $blocktype, $blocksize);
  $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
  @FileValues = unpack("S",$FileValues);
  ($Header) =  @FileValues;
  $binHeader = dec2bin($Header);
  $blocktype = (substr($binHeader, 8,6));
  $blocktype = bin2dec($blocktype);
  $blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
  $blocksize = bin2dec($blocksize);
  for (my $i = $offset+2; $i < $offset+$blocksize+2; $i++) {   #skipping over the blockId
    push @blockdata, $fileBytes[$i];
  }
  return ($blocktype, $blocksize, \@blockdata);
}     

# sub read16 {
#   # For a given offset, determine the block size and blocktype
#   my ($fileBytes, $offset) = @_; 
#   my @fileBytes = @{ $fileBytes };
#   my ($FileValues, @FileValues, $Header);
#   my ($binHeader, $blocktype, $blocksize);
#   $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
#   @FileValues = unpack("S",$FileValues);
#   ($Header) =  @FileValues;
#   $binHeader = dec2bin($Header);
#   $blocktype = (substr($binHeader, 8,6));
#   $blocktype = bin2dec($blocktype);
#   $blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
#   $blocksize = bin2dec($blocksize);
#   return ($blocktype, $blocksize);
# }

sub read8 {
# Convert unsigned byte to integer.
  my ($b) = @_;
	return $b & 0xFF;
}

sub read16 {
#	 Read a 16 bit little endian integer from a byte array
  my ($data, $offset) = @_;
  my @data = @{ $data };
	return &read8($data[$offset+1]) << 8 | &read8($data[$offset]);
}

sub dec2bin {
	# This doesn't match stuff online because I changed from 32- to 16-bit
	return unpack("B16", pack("n", shift));
}

sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub decryptBlock {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
     } elsif ($typeId == 7) {
      # Note that planet's data requires something extra to decrypt. 
      # Fortunately block 7 isn't in my test files
      die "BLOCK 7 found. ERROR!\n";
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        my $playerId = $decryptedData[0] & 0xFF; print "Player Id: $playerId\n";
        my $shipDesigns = $decryptedData[1] & 0xFF;  print " Ship Designs: $shipDesigns\n";
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); print " Planets: $planets\n";
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  print " Fleets: $fleets\n";
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); print " Starbase Designs: $starbaseDesigns\n";
        my $logo = (($decryptedData[6] & 0xFF) >> 3); print " Logo: $logo\n";
        my $fullDataFlag = ($decryptedData[6] & 0x04); print "fullDataFlag: $fullDataFlag\n";
        # We figure out names here, because they're here at 8 when not fullDataFlag 
        my $index = 8; 
        my $playerRelations;
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
        my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        print "playerName $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
        
        if ($fullDataFlag) { 
          my $homeWorld = &read16(\@decryptedData, 8);
          print "Homeworld: $homeWorld\n";
          # BUG: the references say this is two bytes, but I don't think it is.
          # That means I don't know what byte 11 is tho. 
          #my $rank = &read16(\@decryptedData, 10);
          my $rank = $decryptedData[10];
          print "Player Rank: $rank\n";
          # Bytes 12..15 are the password;
          my $centreGravity = $decryptedData[16]; # (base 65), 255 if immune 
          my $centreTemperature = $decryptedData[17]; #(base 35), 255 if immune  
          my $centreRadiation = $decryptedData[18]; # , 255 if immune 
          my $lowGravity      = $decryptedData[19];
          my $lowTemperature  = $decryptedData[20];
          my $lowRadiation    = $decryptedData[21];
          my $highGravity     = $decryptedData[22];
          my $highTemperature = $decryptedData[23];
          my $highRadiation   = $decryptedData[24];
          my $growthRate      = $decryptedData[25];
          print "Grav: " . &showHab($lowGravity,$centreGravity,$highGravity) . ", Temp: " . &showHab($lowTemperature,$centreTemperature,$highTemperature) . ", Rad: " . &showHab($lowRadiation,$centreRadiation,$highRadiation) . ", Growth: $growthRate\%\n"; 
                    # Worth noting all of these are +18 when in the fullDataFlag
          my $energyLevel           = $decryptedData[26];
          my $weaponsLevel          = $decryptedData[27];
          my $propulsionLevel       = $decryptedData[28];
          my $constructionLevel     = $decryptedData[29];
          my $electronicsLevel      = $decryptedData[30];
          my $biotechLevel          = $decryptedData[31];
          print "Tech Level: $energyLevel, $weaponsLevel, $propulsionLevel, $constructionLevel, $electronicsLevel, $biotechLevel\n";    
          my $energyLevelPointsSincePrevLevel         = $decryptedData[32]; # (4 bytes) 
          my $weaponsLevelPointsSincePrevLevel        = $decryptedData[36]; # (4 bytes) 
          my $propulsionLevelPointsSincePrevLevel     = $decryptedData[42]; # (4 bytes) 
          my $constructionLevelPointsSincePrevLevel   = $decryptedData[46]; # (4 bytes) 
          my $electronicsLevelPointsSincePrevLevel     = $decryptedData[50]; # (4 bytes)
          my $biologyLevelPointsSincePrevLevel         = $decryptedData[54]; # (4 bytes)
          print "Tech Points: $energyLevelPointsSincePrevLevel, $weaponsLevelPointsSincePrevLevel, $propulsionLevelPointsSincePrevLevel, $constructionLevelPointsSincePrevLevel, $electronicsLevelPointsSincePrevLevel, $biologyLevelPointsSincePrevLevel \n";
          my $researchPercentage    = $decryptedData[56];
          print "Research Percentage: $researchPercentage\n";
          my $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]
          print "Research Priority: " . &showResearchPriority($currentResourcePriority) . "\n";
          my $nextResourcePriority  = $decryptedData[57] & 0x04; # (left 4 bits)
          print "Next Priority: " . &showResearchPriority($nextResourcePriority) . "\n";
          my $researchPointsPreviousYear = $decryptedData[58]; # (4 bytes)
          print "researchPointsPreviousYear: $researchPointsPreviousYear\n";
          my $resourcePerColonist = $decryptedData[62]; # ? 55? 
          my $producePerFactory = $decryptedData[63];
          my $toBuildFactory = $decryptedData[64];
          my $operateFactory = $decryptedData[65];
          my $producePerMine = $decryptedData[66];
          my $toBuildMine = $decryptedData[67];
          my $operateMine = $decryptedData[68];
          print "Productivity: Colonist: $resourcePerColonist, Factory: $producePerFactory, $toBuildFactory, $operateFactory, Mine: $producePerMine, $toBuildMine, $operateMine\n";
          my $spendLeftoverPoints = $decryptedData[69]; # ?  (3:factories)  
          my $researchEnergy        = $decryptedData[70]; # (0:+75%, 1: 0%, 2:-50%) 
          my $researchWeapons       = $decryptedData[71]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchProp          = $decryptedData[72]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchConstruction  = $decryptedData[73]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchElectronics   = $decryptedData[74]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchBiotech       = $decryptedData[75]; # (0:+75%, 1: 0%, 2:-50%)
          print "Research Cost:  " . &showResearchCost($researchEnergy) . ", " . &showResearchCost($researchWeapons) . ", " . &showResearchCost($researchProp). ", " . &showResearchCost($researchConstruction) . ", " . &showResearchCost($researchElectronics) . ", " . &showResearchCost($researchBiotech) . "\n";
          my $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
          print "PRT: " . &showPRT($PRT) . "\n";
          #$decryptedData[77]; unknown , always 0
          my $LRT =  $decryptedData[78]  + ($decryptedData[79] * 0x100); 
          my @LRTs = &showLRT($LRT);
          print "LRTs: " . join(',',@LRTs) . "\n";
          my $checkBoxes = $decryptedData[81]; 
            #<Unknown bits="5"/> 
            my $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
            # Unknown bit 6
            my $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
          print "Expensive Tech Starts at 3: " . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
          print "FactoriesCost1LessGerm: " . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          my $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100);
          my @MTItems = &showMTItems($MTItems);
          print "MT Items: " . join(',',@MTItems) . "\n";
          #$decryptedData[82-109]; unknown, but in pairs
          # Interestingly, if the player relations have never been set, the
          # player relations length will be 0, with no bytes after it
          # For the player relations values
          # So the result here CAN be 0.
          my $playerRelationsLength = $decryptedData[112];
          if ( $playerRelationsLength ) { 
            for (my $i = 1; $i <= $playerRelationsLength; $i++) {
              my $id = $i-1;
              if ($id == $playerId) { next; } # Skip for self
              print "Player " . $id . ": " . &showPlayerRelations($decryptedData[$i+112]) . "\n";
            } 
          } else { print "Player Relations never set\n"; }
        }
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub addPadding {
  # Add padding to 4 bytes
  my ($byteArray) = @_;
  my @byteArray = @ { $byteArray }; 
  my $size = @byteArray;
  my $padding;
  $padding = ((($size / 4) - (int ($size / 4))) * 4);
  if ($padding) { $padding = 4 - $padding; }
  for (my $i = 0; $i < $padding; $i++) { 
    push  @byteArray, 0;
  }
  return \@byteArray, $padding;
}

sub stripPadding {
  # Strip off any padding
  my ($byteArray, $padding) = @_;
  my @byteArray = @ { $byteArray };
    for (my $i = 0; $i < $padding; $i++) {
      pop @byteArray;
    }
  return @byteArray;
}

sub decodeBytesForStarsString {
  my (@res) = @_;
  my $hexChars='';
  my ($b, $b1,$b2, $firstChar, $secondChar);
  my ($ch1, $ch2, $index, $result);

  for (my $i = 1; $i < scalar(@res); $i++) {
    $b = $res[$i];
    $b1 = ($b & 0xff) >> 4; # the left nibble of the byte
    $b2 = ($b & 0xff) % 16; # the right nibble of the byte
    $firstChar = &nibbleToChar($b1);
    $secondChar = &nibbleToChar($b2);
    $hexChars .= $firstChar;
    $hexChars .= $secondChar;
  }
  for (my $t = 0; $t < length($hexChars); $t++) {
  	$ch1 = substr($hexChars,$t,1);
  	if ($ch1 eq 'F'){
      # do nothing?
      # I think this happens when we skip past the end of the array.
  	}
  	elsif ($ch1 eq 'E'){
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesE, $index, 1);
  		$t++;
  	}
  	elsif ($ch1 eq 'D'){
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesD, $index, 1);
  		$t++;
  	}
  	elsif ($ch1 eq 'C'){
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesC, $index, 1);
		$t++;
  	}
  	elsif ($ch1 eq 'B'){
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesB, $index, 1);
  		$t++;
  	}
  	else {
  		$index = &parseInt($ch1,16);
  		$result .= substr($encodesOneByte, $index, 1);
  	}
  }
	return $result;
}

sub parseInt {
	my ($parse,$base) = @_;
  return hex($parse);		
}

sub bitTest {
  # Returns 0 if the associated bit in a decimal number is zero.
  # Useful given the number of times data is stored by bit.
  my ($value, $bit) = @_;
  return $value & (1 << $bit);
} 

sub nibbleToChar{
  my ($b) = @_; # this is sent as a 4-bit nibble, 0 to 15
	my $i1 = ($b & 0xff) + ord('0'); 
	my $i2 = ($b & 0xff) + ord('A') - 10;  
	my $i3 = ($b & 0xff) + ord('a') - 10;
	if ($i1 >= ord('0') && $i1 <= ord('9')) { return chr($i1);  }
	if ($i2 >= ord('A') && $i2 <= ord('F')) { return chr($i2);  }
	if ($i3 >= ord('a') && $i3 <= ord('f')) { return chr($i3); }
	die "Could not find correct char\n";
}

sub showHab {
 my ($low,$center,$high) = @_;
 if ($center == 255) {return "Immune"; }
 else { return "$low/$center/$high"; }
}

sub showResearchCost {
#(0:+75%, 1: 0%, 2:-50%) 
   my ($value) = @_;
   if    ($value eq '2') {     return '-50%';
   } elsif  ($value eq '1') {  return 'Standard'; 
   } else {                  return '+75%'; 
  }
}

sub showPlayerRelations {
  # If relations have never been changed, no value will be present.
  my ($relation) = @_;
  my @relations = qw ( neutral friend enemy ) ;
  return $relations[$relation];
}

sub showResearchPriority {
  my ($value) = @_;
  my @nextResearch = qw (Same Energy Weapons Propulsion Construction Electronics Biotech Lowest);
  if ($nextResearch[$value]) {return $nextResearch[$value]; }
  else {return "Error: $value\n"; }
}

sub showPRT {
  my ($prt) = @_;
  my @prts = qw (HE SS WM CA IS SD PP IT AR JOAT );
  return $prts[$prt]; 
}

sub showLRT {
  my ($lrts) = @_;
  my @string = ();
  if (&bitTest($lrts, 0)) { push @string, 'ImprovedFuelEfficiency';  }
  if (&bitTest($lrts, 1)) { push @string, 'TotalTerraforming'; }
  if (&bitTest($lrts, 2)) { push @string, 'AdvancedRemoteMining';  }
  if (&bitTest($lrts, 3)) { push @string, 'ImprovedStarbases';  }
  if (&bitTest($lrts, 4)) { push @string, 'GeneralisedResearch';    }
  if (&bitTest($lrts, 5)) { push @string, 'UltimateRecycling';    }
  if (&bitTest($lrts, 6)) { push @string, 'MineralAlchemy'; }
  if (&bitTest($lrts, 7)) { push @string, 'NoRamScoopEngines'; }
  if (&bitTest($lrts, 8)) { push @string, 'CheapEngines';     }
  if (&bitTest($lrts, 9)) { push @string, 'OnlyBasicRemoteMining';   }
  if (&bitTest($lrts, 10)) { push @string, 'NoAdvancedScanners';  }
  if (&bitTest($lrts, 11)) { push @string, 'LowStartingPopulation';     }
  if (&bitTest($lrts, 12)) { push @string, 'BleedingedgeTechnology';     }
  if (&bitTest($lrts, 13)) { push @string, 'RegeneratingShields';     }
  if (&bitTest($lrts, 14)) { push @string, 'Unused';     }
  if (&bitTest($lrts, 15)) { push @string, 'Unused';     }
  if (@string) { return join (',', @string);  }
  else { $string[0] = "None"; return @string; }
}

sub showExpensiveTechStartsAt3 {
 my ($value) = @_;
 if ($value == 32) {return "Checked"; }
 else {return "Not Checked"; }
}

sub showFactoriesCost1LessGerm {
 my ($value) = @_;
 if ($value == 128) {return "Checked"; }
 else {return "Not Checked"; }
}

sub showMTItems {
  my ($itemBits) = @_;
  my @string = ();
  if (&bitTest($itemBits, 0)) { push @string, 'Multi Cargo Pod';    }
  if (&bitTest($itemBits, 1)) { push @string, 'Multi Function Pod'; }
  if (&bitTest($itemBits, 2)) { push @string, 'Langston Shield';    }
  if (&bitTest($itemBits, 3)) { push @string, 'Mega Poly Shell';    }
  if (&bitTest($itemBits, 4)) { push @string, 'Alien Miner';        }
  if (&bitTest($itemBits, 5)) { push @string, 'Hush-a-Boom';        }
  if (&bitTest($itemBits, 6)) { push @string, 'Anti Matter Torpedo'; }
  if (&bitTest($itemBits, 7)) { push @string, 'Multi Contained Munition'; }
  if (&bitTest($itemBits, 0)) { push @string, 'Mini Morph';         }
  if (&bitTest($itemBits, 1)) { push @string, 'Enigma Pulsar';      }
  if (&bitTest($itemBits, 2)) { push @string, 'Genesis Device';    }
  if (&bitTest($itemBits, 3)) { push @string, 'Jump Gate';         }
  #     Unused bits="4"/>
  if (@string) { return @string; }
  else { $string[0] = "None"; return @string }
}
 
