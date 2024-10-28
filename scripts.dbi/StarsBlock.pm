#!/usr/bin/perl
# StarsBlock.pm
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
# 191123 Added subs for other block data
# 220202 Rewritten for stateful .x processing

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

# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

# StarsPWD and StarsRace are both integrated into TotalHost
# StarsClean implemented in TotalHost (clean .m files)
# StarsMsg not implemented in TotalHost
# StarsFix implemented (fox .x files exploits)

# Here is a list of blocks and their types I found so far. I've never met several of them in any game file, which I can access to, but you can try to find them in your own game files using this small command line tool (there is no decryption code, since block headers are never encrypted), and please if you find them let me know:
# https://wiki.starsautohost.org/wiki/Technical_Information
# 0	FileFooterBlock (Year: .m, .hst   Checksum XOR .r, null .x, .h) 
# 1	ManualSmallLoadUnloadTaskBlock
# 2	ManualMediumLoadUnloadTaskBlock
# 3	WaypointDeleteBlock
# 4	WaypointAddBlock
# 5	WaypointChangeTaskBlock
# 6	PlayerBlock
# 7	PlanetsBlock
# 8	FileHeaderBlock (unencrypted)
# 9	FileHashBlock
# 10	WaypointRepeatOrdersBlock
# 11	Never met it
# 12	EventsBlock
# 13	PlanetBlock
# 14	PartialPlanetBlock
# 15	Never met it
# 16	FleetBlock
# 17	PartialFleetBlock
# 18	Never met it
# 19	WaypointTaskBlock
# 20	WaypointBlock
# 21	FleetNameBlock
# 22	Never met it
# 23	MoveShipsBlock
# 24	FleetSplitBlock
# 25	ManualLargeLoadUnloadTaskBlock
# 26	DesignBlock
# 27	DesignChangeBlock
# 28	ProductionQueueBlock
# 29	ProductionQueueChangeBlock
# 30	BattlePlanBlock
# 31	BattleBlock (content isn't decoded yet)
# 32	CountersBlock
# 33	MessagesFilterBlock
# 34	ResearchChangeBlock
# 35	PlanetChangeBlock
# 36	ChangePasswordBlock (.x), Password (.hst)
# 37	FleetsMergeBlock
# 38	PlayersRelationChangeBlock
# 39	BattleContinuationBlock (content isn't decoded yet)
# 40	MessageBlock
# 41	Record made by AI in H file (content isn't decoded yet)
# 42	SetFleetBattlePlanBlock
# 43	ObjectBlock
# 44	RenameFleetBlock
# 45	PlayerScoresBlock
# 46	SaveAndSubmitBlock

package StarsBlock;
# 220824 Don't think this is ever called from StarsBlock. Fix for required SSL from SMTP library for block applications
#use TotalHost; # eval'd at compile time
do 'config.pl';
use StarStat;  # eval'd at compile time

require Exporter;
our @ISA = qw(Exporter);
# Don't stick comments in the Export array.
# Don't use commas
our @EXPORT = qw( 
  StarsPWD
  nextRandom StarsRandom
  initDecryption getFileHeaderBlock getFileFooterBlock getFileFooter
  encryptBytes decryptBytes
  read8 read16 read32 readN write16 parseBlock
  dec2bin bin2dec
  encryptBlock decryptPWD
  stripPadding addPadding
  isMinefield getMineType getMineDetonate
  isPacketOrSalvage getPacketType
  isWormhole getWormholeType
  isMT getMTPartName
  displayBlockRace
  parseInt bitTest
  nibbleToChar charToNibble
  showHabRange showHab showLeftoverPoints
  showResearchCost showExpensiveTechStartsAt3
  showPlayerRelations
  showResearchPriority
  PRT LRT 
  showFactoriesCost1LessGerm
  showMTItems
  decodeBytesForStarsString
  getPlayers resetPlayers
  resetRace 
  StarsClean decryptClean  
  StarsFix StarsList decryptFix
  StarsAI decryptAI
  zerofy splitWarnId attackWho
  showCategory readHullType readItemDetail
  getMask
  BlockLogOut
  shiftBytes unshiftBytes
  raceCheckSum checkRaceCorrupt
  checkSerials decryptSerials
  readList writeList printList updateList
  cleanFiles
  adjustFleetCargo tallyFleet 
  publicMessages decryptMessages
);  

my $debug = 1;

#############################################
sub StarsPWD {
#  my ($GameFile, $Player) = @_;
  my ($File) = @_;   # .m File is full file path
  use File::Copy;
  #Stars random number generator class used for encryption
  
#  my $MFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.m' . $Player;
  &BlockLogOut(300, "Password Reset Started for : $File", $LogFile);
#   # Backup the current .m file
# 	my $Backup_Destination_File   = $MFile . '.PWD';
# 	copy($MFile, $Backup_Destination_File);
# 	&BlockLogOut(100,"Copy $MFile to $Backup_Destination_File",$LogFile);
   
  # Read in the binary Stars! file, byte by byte
  my $FileValues = '';
  my @fileBytes=();
  open(StarFile, "<$File");
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block, removing the password
  my ($outBytes) = &decryptPWD(@fileBytes);
  # If the decrypt Bytes returned 0, there's no password
  unless ($outBytes) { return 0; }
  my @outBytes = @{$outBytes};
  # Output the Stars! File with blank password(s)
  open (OUTFILE, '>:raw', "$File");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OUTFILE $outBytes[$i];
  }
  close (OUTFILE);
  return 1;
}

#################################
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
  return $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti;
}

sub getFileFooterBlock {
  my ($fileBytes, $size) = @_; # Expecting to get just the data of the block
  my @fileBytes = @{ $fileBytes };
  my $fileFooter;
  if ($size > 0) { # .x files have a 0 byte FileFooterBlock 
    $fileValues = $fileBytes[0] . $fileBytes[1];
    $fileFooter = unpack ('S', $fileValues);
 } else { $fileFooter = 0; }
  return $fileFooter;
}

sub getFileFooter {
  my (@fileBytes) = @_; # Expecting to get an entire .m file
  #my @fileBytes = @{ $fileBytes };
  my ($fileFooter, $fileValues);
  $fileValues = $fileBytes[-2] . $fileBytes[-1];
  $fileFooter = unpack ('S', $fileValues);
  return $fileFooter;
}

sub initDecryption {
  # Need the values from the FileHeaderBlock to seed the encryption
  my ($binSeed, $fShareware, $Player, $turn, $lidGame) = @_;
  my ($salt, $index1, $index2);
  my ($part1, $part2, $part3, $part4); 
  my ($rounds, $random, $seedA, $seedB);
  #Stars random number generator class used for encryption
	# * IMPORTANT:  One number here is not prime (279 instead of 269).  
  # * An analysis of the stars EXE with a hex editor
	# * also shows a primes table with 279.  Fun!  
  my @primes = ( 
                  3, 5, 7, 11, 13, 17, 19, 23, 
                  29, 31, 37, 41, 43, 47, 53, 59,
                  61, 67, 71, 73, 79, 83, 89, 97,
                  101, 103, 107, 109, 113, 127, 131, 137,
                  139, 149, 151, 157, 163, 167, 173, 179,
                  181, 191, 193, 197, 199, 211, 223, 227,
                  229, 233, 239, 241, 251, 257, 263, 279,
#                  271, 277, 281, 283, 293, 307, 311, 313
                  271, 277, 281, 283, 293, 307, 311, 313,
                  317,331,337,347,349,353,359,367,373,379,383,389,397,401,409,419,
                  421,431,433,439,443,449,457,461,463,467,479,487,491,499,503,509,
                  521,523,541,547,557,563,569,571,577,587,593,599,601,607,613,617,
                  619,631,641,643,647,653,659,661,673,677,683,691,701,709,719,727
          );

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
  my @decryptedBytes = ();
  my ($decryptedChunk, $decryptedBytes, $newRandom, $chunk);
  my $padding;
  # Add padding to 4 bytes
  ($byteArray, $padding) = &addPadding (\@byteArray);
  @byteArray = @ {$byteArray };
  my $paddedSize = $size + $padding;
  # Now decrypt, processing 4 bytes at a time
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
    # BUG: This line was different than the 211006 version, which broke re-encryption
    $encryptedBytes = chr ($encryptedChunk        & 0xFF);
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

# Restructured to not pass the entire file each time
sub parseBlock {
  ## This returns the 3 relevant parts of a block: typeId, size, raw block data
  # This returns the typeId, size
  my ($FileValues,$offset) = @_;
  my (@FileValues, $Header);
  my ($binHeader, $blocktype, $blocksize);
  @FileValues = unpack("S",$FileValues);
  ($Header) =  @FileValues;
  $binHeader = dec2bin($Header);
  $blocktype = (substr($binHeader, 8,6));
  $blocktype = bin2dec($blocktype);
  $blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
  $blocksize = bin2dec($blocksize);
  return ($blocktype, $blocksize);
}   

sub read8 {
# Convert unsigned byte to integer.
  my ($b) = @_;
	return $b & 0xFF;
}

#BUG: this was here when I merged all the new functions, which means likely commenting this
# out breaks any other functions calling it, as they're different. In particular, StarsPWD.
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

sub read16 {
#	 Read a 16 bit little endian integer from a byte array
  my ($data, $offset) = @_;
  my @data = @{ $data };
	return &read8($data[$offset+1]) << 8 | &read8($data[$offset]);
}

sub read32 {
#	 Read a 32 bit little endian integer from a byte array
  my ($data, $offset) = @_;
  my @data = @{ $data };
	return &read8($data[$offset+3]) << 24 | 
				&read8($data[$offset+2]) << 16 | 
				&read8($data[$offset+1]) << 8 | 
				&read8($data[$offset]);
}

sub readN {
my ($data, $offset, $byteLen) = @_;
  my @data = @{ $data };
	if ($byteLen == 0) {return  0; }
	elsif ($byteLen == 1) {return &read8($data[$offset]);  }
  elsif ($byteLen == 2) {return &read16($data, $offset);  }
  elsif ($byteLen == 4) {return &read32($data, $offset);  }
}

#Write a 16 bit little endian integer into a byte array
sub write16 {
  my ($value) = @_;
  my @data;
  $data[1] = ($value >>8) & 0xFF;
  $data[0] = $value & 0xFF;
  return  $data[0], $data[1];
}
 
sub dec2bin {
	# This doesn't match stuff online because I changed from 32- to 16-bit
	return unpack("B16", pack("n", shift));
}

sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub decryptPWD {
  my (@fileBytes) = @_;
  my @block=();
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ( $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $action = 0; # has the password been reset
  my $playerId;
  my @singularRaceName;
  my @pluralRaceName;
  my ($checkSum1, $checkSum2); # The checksums for .r file Block 0
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 8) {  # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } elsif ($typeId == 7) { # Planet block (.xy file)
      # Note that planet's data requires something extra to decrypt. 
       &BlockLogOut(0, "BLOCK 7 found. ERROR!", $ErrorLog); die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        # We need the race name info for calculating the race checksum if we reset a race password
        $playerId = $decryptedData[0] & 0xFF; 
# So apparently there are player blocks from other players in the .m file, and
# ff you reset the password in those you corrupt at the very least the player race name 
#        if (($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) {
        # BUG: Fixing for only PlayerID = Player blocks will break for .hst
        if ((($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) && ($playerId == $Player)){
          &BlockLogOut(200,"Block $offset password blanked for M File", $LogFile);
          print "Block $offset password blanked for M File\n";
          # Replace the password with blank
          $decryptedData[12] = 0;
          $decryptedData[13] = 0;
          $decryptedData[14] = 0;
          $decryptedData[15] = 0;  
          $action = 1;
        } else { 
#           if ($playerId != $Player) { print "Block $offset is for another player!\n"; }
#           # BUG: In .hst some Player blocks could be password protected, and some not
#           else { print "Block $offset isn't password-protected!\n"; }
# BUG: This prevents this from working when there's more than one Type 6 block, and
# the first one doesn't have a password.
#          return 0;
        }
      }
      if ($typeId == 36) { # .x file Change Password Block
        if (($decryptedData[0]  != 0) | ($decryptedData[1] != 0) | ($decryptedData[2] != 0) | ($decryptedData[3] != 0)) {
          &BlockLogOut(200,"Block $offset password blanked for X File", $LogFile);
          # Replace the password with blank
          $decryptedData[0] = 0;
          $decryptedData[1] = 0;
          $decryptedData[2] = 0;
          $decryptedData[3] = 0; 
          $action = 1;
        } 
      }
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      &BlockLogOut(400, "BLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), $LogFile); 
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  # If the password was not reset, no need to write the file back out
  # Faster, less risk of corruption
  if ( $action ) { return \@outBytes; }
  else { return 0; }
}

sub encryptBlock {
  my ($block, $decryptedData, $padding, $seedX, $seedY) = @_; 
  my @block = @{$block};
  my @header = ($block[0], $block[1]); # Get the original header from the block
  my @decryptedData = @{$decryptedData};
  my @encryptedData;
  my $encryptedData;
  # reencrypt the data
  ($encryptedData, $seedX, $seedY) = &encryptBytes(\@decryptedData, $seedX, $seedY, $padding); 
  @encryptedData = @{ $encryptedData };
  unshift (@encryptedData, @header); # Prefix the encrypted data with the header
  return \@encryptedData, $seedX, $seedY;
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

sub isMinefield() {
  my ($type) = (@_);
  if ($type == 0) { return 1;} else {return 0;} 
}

sub getMineType {
  my ($bitArray) = (@_);
  my @bitArray = @ { $bitArray };
  $mineType = $bitArray[14] . $bitArray[15];
  $mineType = bin2dec($mineType);
  if ($mineType == 0) { return "Standard"};
  if ($mineType == 1) { return "Heavy"};
  if ($mineType == 2) { return "Speed Trap"};
}

sub getMineDetonate {
  my ($bitArray) = @_;
  my @bitArray = @ { $bitArray };
  if ($bitArray == 1) { return "Detonating"; }
  else { return "Not Detonating"; }
}

sub isPacketOrSalvage {
  my ($type) = @_;
  if ($type == 1) { return 1;} else {return 0;} 
}    

sub getPacketType  {
  my ($planetId) = @_;
  if ($planetId == 1023) { 
    return "Salvage";
  } else { return "Packet";
  }
}

sub isWormhole {
  my ($type) = @_;
  if ($type == 2) { return 1;} else {return 0;} 
}
	
sub getWormholeType {
  # I can figure out that the values here are a range, much like
  # something adds (or subtracts) a random number to it to make it change
  # unpredictably. But I can't get the math to work out. 
   
  # 0 = Rock Solid
  # 1 = Mostly Stable 
  # Mostly Stable
  # Average
  # Slightly Volatile
  # Volatile
  # Extremely Volatile
}

sub isMT {
  my ($type) = @_;
  if ($type == 3) { return 1; } else { return 0; } 
}

sub getMTPartName {
  my ($itemBits) = @_;
  if ($itemBits == 0) { return 'Research'; }
  if (&bitTest($itemBits, 0)) { return 'Multi Cargo Pod';    }
  if (&bitTest($itemBits, 1)) { return 'Multi Function Pod'; }
  if (&bitTest($itemBits, 2)) { return 'Langston Shield';    }
  if (&bitTest($itemBits, 3)) { return 'Mega Poly Shell';    }
  if (&bitTest($itemBits, 4)) { return 'Alien Miner';        }
  if (&bitTest($itemBits, 5)) { return 'Hush-a-Boom';        }
  if (&bitTest($itemBits, 6)) { return 'Anti Matter Torpedo'; }
  if (&bitTest($itemBits, 7)) { return 'Multi Contained Munition'; }
  if (&bitTest($itemBits, 8)) { return 'Mini Morph';         }
  if (&bitTest($itemBits, 9)) { return 'Enigma Pulsar';      }
  if (&bitTest($itemBits, 10)) { return 'Genesis Device';    }
  if (&bitTest($itemBits, 11)) { return 'Jump Gate';         }
  if (&bitTest($itemBits, 12)) { return 'Ship/MT Lifeboat';  }
 	return '';
}

sub displayBlockRace { # mostly a duplicate of decryptBlockRace
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
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        my $playerId; 
        my ($shipDesigns, $planets, $fleets, $starbaseDesigns, $logo);
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
        my $spendLeftoverPoints;
        my ($researchEnergy, $researchWeapons, $researchProp, $researchConstruction, $researchElectronics, $researchBiotech);
        my ($PRT,$LRT);
        my $checkBoxes; 
        my ($expensiveTechStartsAt3, $factoriesCost1LessGerm);
        my $MTItems;

        $playerId = $decryptedData[0] & 0xFF; # Always 255 in a race file
        $shipDesigns = $decryptedData[1] & 0xFF;  # Always 0 in race file
        $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); # Always 0 in race file
        $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  # Always 0 in race file
        $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); # Always 0 in race file
        $logo = (($decryptedData[6] & 0xFF) >> 3); 
        $fullDataFlag = ($decryptedData[6] & 0x04); # Always true in race file
        # Byte 7 as 76543210
        #   Bit 0 is always 1, Bit 1 defines whether an AI is enabled :  0:off ,  1:on
        #   The 2s bit is 0 for Player, 1 for Human(inactive)
        #   bits 6,7,8 also flip changed to human(inactive)  but don't flip back
        $aiEnabled = ($decryptedData[7] >> 1) & 0x01;
        if ($aiEnabled) {
          # bits 23 defines how good the AI will be:
           $aiSkill = ($decryptedData[7] >> 2) & 0x03; #00 - Easy, 01 - Standard, 10 - Harder, 11 - Expert 
          
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
          $rank = &read16(\@decryptedData, 10); # Always 0 in race file. Not in game file. BUG: This is likely 2 bytes for 16 player games
          # Bytes 12..15 are the password;
          # The password inverts when the player is set to Human(inactive) mode (the bits are flipped).
          # The ai password "viewai" is 238 171 77 9
          # They change to 255 255 255 255 when in Human(inactive) mode.
          $centreGravity = $decryptedData[16]; # (base 65), 255 if immune 
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
          $energyLevelPointsSincePrevLevel         = $decryptedData[32]; # (4 bytes) #Always 0 in race file
          $weaponsLevelPointsSincePrevLevel        = $decryptedData[36]; # (4 bytes) #Always 0 in race file
          $propulsionLevelPointsSincePrevLevel     = $decryptedData[42]; # (4 bytes) #Always 0 in race file
          $constructionLevelPointsSincePrevLevel   = $decryptedData[46]; # (4 bytes) #Always 0 in race file
          $electronicsLevelPointsSincePrevLevel     = $decryptedData[50]; # (4 bytes) #Always 0 in race file
          $biologyLevelPointsSincePrevLevel         = $decryptedData[54]; # (4 bytes) #Always 0 in race file
          $researchPercentage    = $decryptedData[56]; # defaults to 15
          $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]  #Always 0 in race file
          $nextResourcePriority  = $decryptedData[57] & 0x04; # (left 4 bits) #Always 0 in race file
          $researchPointsPreviousYear = $decryptedData[58]; # (4 bytes) #Always 0 in race file
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
          #Unknown bit 5
          $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
          # Unknown bit 6
          $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
          $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100); #Always 0 in race file
          #$decryptedData[82-109]; unknown, but in pairs
          # Interestingly, if the player relations have never been set, the
          # player relations length will be 0, with no bytes after it
          # for the player relations values
          # so the result here CAN be 0.

          print "<img src=\"$WWW_Image" . 'logo' . $logo . ".png\">\n";
          print "<P><u>Race Name</u>: $singularRaceName : $pluralRaceName\n"; 
          print '<P><u>Spend Leftover Points</u>: ' . &showLeftoverPoints($spendLeftoverPoints) . "\n";
          print '<P><u>PRT</u>: ' . &PRT($PRT,1) . "\n";
          print '<P><u>LRTs</u>: ' . join(', ',&LRT($LRT,1)) . "\n";
          print '<P><u>Hab</u>: Grav: ' . &showHabRange($lowGravity,$centreGravity,$highGravity, 0) . ", Temp: " . &showHabRange($lowTemperature,$centreTemperature,$highTemperature,1) . ", Rad: " . &showHabRange($lowRadiation,$centreRadiation,$highRadiation,2) . ", Growth: $growthRate\%\n"; 
          print '<P><u>Productivity</u>: Colonist ' . ($resourcePerColonist*100) . ", Factory: Produce $producePerFactory, Cost To Build $toBuildFactory, May Operate $operateFactory, Mine: Produce $producePerMine, Resources to Build $toBuildMine, May Operate $operateMine\n";
          print '<P><u>Factories Cost 1 Less Germ</u>: ' . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          print '<P><u>Research Cost</u>:  Energy ' . &showResearchCost($researchEnergy) . ", Weapons " . &showResearchCost($researchWeapons) . ", Propulsion " . &showResearchCost($researchProp). ", Construction " . &showResearchCost($researchConstruction) . ", Electronics " . &showResearchCost($researchElectronics) . ", Biotech " . &showResearchCost($researchBiotech) . "\n";
          print '<P><u>Expensive Tech Starts at 3</u>: ' . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
        }
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

sub nibbleToChar {
  my ($b) = @_; # this is sent as a 4-bit nibble, 0 to 15
	my $i1 = ($b & 0xff) + ord('0'); 
	my $i2 = ($b & 0xff) + ord('A') - 10;  
	my $i3 = ($b & 0xff) + ord('a') - 10;
	if ($i1 >= ord('0') && $i1 <= ord('9')) { return chr($i1);  }
	if ($i2 >= ord('A') && $i2 <= ord('F')) { return chr($i2);  }
	if ($i3 >= ord('a') && $i3 <= ord('f')) { return chr($i3); }
	die "Could not find correct char\n";
}

sub charToNibble {
  # BUG: Untested
  my ($ch) = @_; # this is sent as a 4-bit nibble, 0 to 15
	if (ord($ch) >= ord('0') && ord($ch) <= ord('9')) { return (ord($ch) - ord('0')); }
  if (ord($ch) >= ord('A') && ord($ch) <= ord('F')) { return (ord($ch) - ord('A') + 10); }
  if (ord($ch) >= ord('a') && ord($ch) <= ord('f'))  { return (ord($ch) - ord('a') + 10); }
}

sub showHabRange {
  my ($low,$center,$high,$type) = @_; # Type is 0,1,2 for grav, temp, rad
  my ($lowFixed, $centerFixed, $highFixed); 
  my @habBase = qw ( .12 -200 0) ; #The starting value for each hab range, max 8.0, 200, 100
  my @habIncrement = qw (.24 4 1 ) ; # The size of the hab increment
  # I don't know the GRAV formula, but I can brute force it: https://wiki.starsautohost.org/wikinew/craebild/habcalc.htm
  my @gravity_table = ( 0.12, 0.12, 0.13, 0.13, 0.14, 0.14, 0.15, 0.15, 0.16, 0.17, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.24, 0.25, 0.27, 0.29, 0.31, 0.33, 0.36, 0.40, 0.44, 0.50, 0.51, 0.52, 0.53, 0.54, 0.55, 0.56, 0.58, 0.59, 0.60, 0.62, 0.64, 0.65, 0.67, 0.69, 0.71, 0.73, 0.75, 0.78, 0.80, 0.83, 0.86, 0.89, 0.92, 0.96, 1.00, 1.04, 1.08, 1.12, 1.16, 1.20, 1.24, 1.28, 1.32, 1.36, 1.40, 1.44, 1.48, 1.52, 1.56, 1.60, 1.64, 1.68, 1.72, 1.76, 1.80, 1.84, 1.88, 1.92, 1.96, 2.00, 2.24, 2.48, 2.72, 2.96, 3.20, 3.44, 3.68, 3.92, 4.16, 4.40, 4.64, 4.88, 5.12, 5.36, 5.60, 5.84, 6.08, 6.32, 6.56, 6.80, 7.04, 7.28, 7.52, 7.76, 8.00 );
  if ($center == 255) {return 'Immune'; } 
  elsif ($type != 0 ) { # Grav is different
    $lowFixed = ($low * $habIncrement[$type]) + $habBase[$type];
    $centerFixed = ($center * $habIncrement[$type]) + $habBase[$type];
    $highFixed = ($high * $habIncrement[$type]) + $habBase[$type]; # Radiation is simple
    return "$lowFixed/$centerFixed/$highFixed"; 
  } else {return "$gravity_table[$low]/$gravity_table[$center]/$gravity_table[$high]"; }  # Because gravity is weird. 
}

sub showHab {
  # Display a planet's actual hab range
  my ($value,$type) = @_; # Type is 0,1,2 for grav, temp, rad
  my @habBase = qw ( .12 -200 0) ; #The starting value for each hab range, max 8.0, 200, 100
  my @habIncrement = qw (.24 4 1 ) ; # The size of the hab increment
  # I don't know the GRAV formula, but I can brute force it: https://wiki.starsautohost.org/wikinew/craebild/habcalc.htm
  my @gravity_table = ( 0.12, 0.12, 0.13, 0.13, 0.14, 0.14, 0.15, 0.15, 0.16, 0.17, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.24, 0.25, 0.27, 0.29, 0.31, 0.33, 0.36, 0.40, 0.44, 0.50, 0.51, 0.52, 0.53, 0.54, 0.55, 0.56, 0.58, 0.59, 0.60, 0.62, 0.64, 0.65, 0.67, 0.69, 0.71, 0.73, 0.75, 0.78, 0.80, 0.83, 0.86, 0.89, 0.92, 0.96, 1.00, 1.04, 1.08, 1.12, 1.16, 1.20, 1.24, 1.28, 1.32, 1.36, 1.40, 1.44, 1.48, 1.52, 1.56, 1.60, 1.64, 1.68, 1.72, 1.76, 1.80, 1.84, 1.88, 1.92, 1.96, 2.00, 2.24, 2.48, 2.72, 2.96, 3.20, 3.44, 3.68, 3.92, 4.16, 4.40, 4.64, 4.88, 5.12, 5.36, 5.60, 5.84, 6.08, 6.32, 6.56, 6.80, 7.04, 7.28, 7.52, 7.76, 8.00 );
  if ($value == 255) {return 'Immune'; } 
  elsif ($type != 0 ) { # Grav is different
    $centerFixed = ($value * $habIncrement[$type]) + $habBase[$type];
    return "$centerFixed"; 
  } else {return "$gravity_table[$value]"; }  # Because gravity is weird. 
}

sub showLeftoverPoints {
   my ($points) = @_;
   my @Leftover = ( "Surface Minerals", "Mineral Concentrations", "Mines", "Factories", "Defenses" );
   return $Leftover[$points];
}

sub showResearchCost {
#(0:+75%, 1: 0%, 2:-50%) 
   my ($value) = @_;
   if ($value eq '2')       {  return '-50%';
   } elsif  ($value eq '1') {  return 'Standard'; 
   } else                   {  return '+75%'; }
}

sub showExpensiveTechStartsAt3 {
 my ($value) = @_;
 if ($value == 32) {return "Checked"; }
 else {return "Not Checked"; }
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

sub PRT {
  # return a string of the PRT, abbrev or full
  my ($prt, $type) = @_;
  my @prts;
  if ($type) { @prts = ('HyperExpansion', 'Super Stealth', 'War Monger', 'Claim Adjustor', 'Inner Strength', 'Space Demolition', 'Packet Physics', 'Interstellar Traveller', 'Alternate Reality', 'Jack of all Trades' ); }
  else { @prts = qw (HE SS WM CA IS SD PP IT AR JOAT ); } 
  return $prts[$prt]; 
}

sub LRT {
  # return a string of all LRTs, abbrev or full
  my ($lrts, $type) = @_;
  my @lrts;
  if ($type) {
    @lrts = ("Improved Fuel Efficiency", "Total Terraforming",  "Advanced Remote Mining", "Improved Starbases", "Generalised Research", "Ultimate Recycling", "Mineral Alchemy", "No RamScoop Engines", "Cheap Engines", "Only Basic Remote Mining", "No Advanced Scanners", "Low Starting Population", "Bleeding Edge Technology", "Regenerating Shields", "Unused", "Unused");
  } else { @lrts = qw( IFE TT ARM ISB GR UR MA NRSE CE OBRM NAS LSP BET RS Unused Unused); }
  my @string = ();
  if (&bitTest($lrts, 0)) { push @string, $lrts[0];  }
  if (&bitTest($lrts, 1)) { push @string, $lrts[1]; }
  if (&bitTest($lrts, 2)) { push @string, $lrts[2]; }
  if (&bitTest($lrts, 3)) { push @string, $lrts[3];  }
  if (&bitTest($lrts, 4)) { push @string, $lrts[4];    }
  if (&bitTest($lrts, 5)) { push @string, $lrts[5];    }
  if (&bitTest($lrts, 6)) { push @string, $lrts[6]; }
  if (&bitTest($lrts, 7)) { push @string, $lrts[7]; }
  if (&bitTest($lrts, 8)) { push @string, $lrts[8];     }
  if (&bitTest($lrts, 9)) { push @string, $lrts[9];   }
  if (&bitTest($lrts, 10)) { push @string, $lrts[10];  }
  if (&bitTest($lrts, 11)) { push @string, $lrts[11];     }
  if (&bitTest($lrts, 12)) { push @string, $lrts[12];     }
  if (&bitTest($lrts, 13)) { push @string, $lrts[13];     }
  if (&bitTest($lrts, 14)) { push @string, $lrts[14];     }
  if (&bitTest($lrts, 15)) { push @string, $lrts[15];     }
  
  if (@string) { return join (', ', @string);  }
  else { $string[0] = 'None'; return @string; }
}

sub showFactoriesCost1LessGerm {
 my ($value) = @_;
 if ($value == 128) {return 'Checked'; }
 else {return 'Not Checked'; }
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
  else { $string[0] = 'None'; return @string }
}

sub decodeBytesForStarsString {
  my (@res) = @_;
  my $hexChars='';
  my ($b, $b1,$b2, $firstChar, $secondChar);
  my ($ch1, $ch2, $index, $result);
  #$hexDigits        = "0123456789ABCDEF";
  my $encodesOneByte = " aehilnorst";
  my $encodesB       = "ABCDEFGHIJKLMNOP";
  my $encodesC       = "QRSTUVWXYZ012345";
  my $encodesD       = "6789bcdfgjkmpquv";
  my $encodesE       = "wxyz+-,!.?:;\'*%\$";  # the \ character here is escaping the ' and $

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
      # Use 3 nibbles
      # BUG: Should likely be using charToNibble here
      # In some cases this is the last character
      unless ($t+2 > length($hexChars)) {
        my $ch3 = substr($hexChars,$t+2,1);  # Get hex character
        $ch3 = hex ($ch3); # convert to decimal
        $ch3 = &dec2bin($ch3);  # convert to binary
        $ch3 = substr($ch3,-4);  # convert to nibble
        my $ch4 = substr($hexChars,$t+1,1);
        $ch4 = hex ($ch4); # convert to decimal
        $ch4 = &dec2bin($ch4); # convert to binary
        $ch4 = substr($ch4,-4); # convert to nibble
        $ch2 = $ch3 . $ch4;
        $ch2 = chr(&bin2dec($ch2));
        $result .= $ch2;
      }
      $t++;  # need to advance twice (format to make more readable)
  		$t++;  # need to advance twice
  	}
  	elsif ($ch1 eq 'E'){
      # use next nibble
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesE, $index, 1);
  		$t++;
  	}
  	elsif ($ch1 eq 'D'){
      # use next nibble
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesD, $index, 1);
  		$t++;
  	}
  	elsif ($ch1 eq 'C'){
      # use next nibble
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesC, $index, 1);
		  $t++;
  	}
  	elsif ($ch1 eq 'B'){
      # use next nibble
  		$ch2 = substr($hexChars,$t+1,1);
  		$index = &parseInt($ch2,16);
  		$result .= substr($encodesB, $index, 1);
  		$t++;
  	}
  	else {
      # use this nibble
  		$index = &parseInt($ch1,16);
  		$result .= substr($encodesOneByte, $index, 1);
  	}
  }
	return $result;
}


sub getPlayers {
  my ($getBits) = @_;
  my ($getString);
  $getString = '';
 	for (my $loop = 0; $loop <= 15; $loop++){
    if (&bitTest($getBits, $loop)) { 
      $getString = $getString . "" . $loop . " ";
    }
  }
 	return $getString;
}

sub resetPlayers {
  # If the player array includes more than one player, limit the array 
  # to only the specific player for the turn
  # And yes this is a stupid way to do it, but it's 3 in the morning
  my ($player, $getBits) = @_;
  my $isIdPresent = 0;
  my $bits1 = '0000000000000000';
  # Must check to see if the current player is in the list
  # If we just blank all values, we lose data we are supposed to have. 
 	for (my $loop = 0; $loop <= 15; $loop++){
    if (&bitTest($getBits, $loop)) { 
      if ($loop == $player) { 
        $isIdPresent = 1; 
      }
    }
  }
  # If the player is in the list, we need to rewrite the list
  #  with only the specific player
  if ($isIdPresent) {
    $bits1 = '';
   	for (my $loop = 15; $loop > -1; $loop--){
      if ($loop == $player) { $bits1 .= '1'; } else { $bits1 .= 0; } 
    }  
  }  
  my ($dd1, $dd2) = &write16(&bin2dec($bits1));
  return ($dd1, $dd2);
}
  
sub resetRace {
# reset the race values to the default
  my ($decryptedBytes, $Player) = @_;
  my @decryptedBytes = @{ $decryptedBytes };
  my $playerRelationsLength = $decryptedBytes[112];
  my $playerId = $decryptedBytes[0] & 0xFF;
  my $fullDataFlag = $decryptedBytes[6] & 0x04;
  # Reset all the player values but hab ranges to default Humanoid
  # Don't bother if no fullDataFlag
  #   or if it's the actual player's data!
  if ($fullDataFlag && $playerId ne $Player) {
    print "Cleaning ...\n";  
    for (my $i = 8; $i <112; $i++) {
     # CAs can see hab ranges so that shouldn't be cleaned.
     unless ($i =~ /^16|17|18|19|20|21|22|23|24/) {  $decryptedBytes[$i] = $resetRace[$i-8]; }
    }
    # Reset all of the player relations to Neutral
    # Variable length based on number of players
    # If player relations have never been set, length is 0
    if ($playerRelationsLength) {
      for (my $i = 1; $i <= $playerRelationsLength; $i++) {
        $decryptedBytes[112+$i] = 0;
      }
    }
  }
  return @decryptedBytes;
}


sub publicMessages {
  # Exports player messages
  my ($GameFile) = @_;
  my $inDir = $Dir_Games . "/" . $GameFile;
  my @messages;

  # Get all the .m file names in the directory
  my @mFiles; # .m files in the directory
  if (-d $inDir) {  
    # If a directory name was specified
    my $file;
    opendir(BIN, $inDir) or &BlockLogOut(20,"publicMessages: Cannot open directory $inDir", $LogFile);
    while (defined ($file = readdir BIN)) {
      next if $file =~ /^\.\.?$/; # skip . and ..
      next unless ($file =~  /^.*\.[Mm]\d*$/ ); #prefiltering for .m files
      push @mFiles, "$inDir/$file";
    }
  } else {&BlockLogOut(20,"publicMessages: $inDir does not exist", $LogFile); }

  if (@mFiles == 0) { 
    &BlockLogOut(20,"publicMessages: No .m files in $inDir", $LogFile);
  } else {
  
    my $messagefile = "$inDir/$GameFile" . '.messages';
    if (-f $messagefile) { unlink $messagefile; } # Get rid of the old one, since we append
    
    # BUG: You know, we could probably pull this from the .hst file
    foreach $filename (@mFiles) {
      # Loop through for each .m file in the directory
      my $FileValues;
      my @fileBytes;
      &BlockLogOut(20,"publicMessages: For File: $filename", $LogFile);
      open(StarFile, "<$filename" );
      # Read in the binary Stars! .m file, byte by byte
      binmode(StarFile);
      while ( read(StarFile, $FileValues, 1)) {
        push @fileBytes, $FileValues; 
      }
      close(StarFile);
      
      # Decrypt the data, block by block
      my ($outBytes) = &decryptMessages(@fileBytes);
      my @outBytes = @{ $outBytes };
      if (scalar (@outBytes)) {
        foreach my $message (@outBytes) {
          push @messages, $message;
        }
      } 
    }
    
    #Deduplicate the messages (as Everyone is in all files)
    my %hash   = map { $_, 1 } @messages;
    @messages = sort keys %hash;
    
    # Output the .messages file from the dedup'd, sorted messages
  	open (OUT_FILE, ">>$messagefile") || &BlockLogOut(100, "publicMessages: could not create $messagefile", $ErrorLog); 
    foreach my $message (@messages) {
      print OUT_FILE $message;
    }
    close(OUT_FILE);
    &BlockLogOut(50, "publicMessages: Created messages for $GameFile", $LogFile);
  }
}


sub StarsClean {
  my ($GameFile) = @_;
  # Removes shared "privileged" information from a .m file for TotalHost
  my @mFiles;      
  my $filename;
  my $inDir = $Dir_Games . "/" . $GameFile;
  
  #Validate directory 
  unless (-d $inDir  ) { 
    &BlockLogOut(0,"StarsClean: Failed to find $inDir for cleaning $GameFile", $ErrorLog);
  }
  
  # Get all the file names in the directory
  # Reading the dir is easier than figuring out the number of players in the game
  opendir(BIN, $inDir) or &BlockLogOut(0,"StarsClean: Failed to open $inDir for cleaning $GameFile", $ErrorLog);
  my $file;
  my $fullName;
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
    $fullName = $inDir . '/' . $file;
    push @mFiles, $fullName;
  }
  if (@mFiles == 0) { &BlockLogOut(0,"StarsClean: Failed to find any files in $inDir for cleaning $GameFile", $ErrorLog); }

  foreach my $mFile (@mFiles) {
    &BlockLogOut(100,"StarsClean: cleaning $mFile in $GameFile", $LogFile);
    # Read in the binary Stars! file(s), byte by byte
    my $fileValues;
    my @fileBytes;
    
    open(StarFile, "<$mFile" );
    binmode(StarFile);
    while ( read(StarFile, $fileValues, 1)) {
      push @fileBytes, $fileValues; 
    }
    close(StarFile);
    
    # Decrypt the data, block by block
    # and modify appropriately
    my ($outBytes, $needsCleaning) = &decryptClean(@fileBytes);
    &BlockLogOut(300,"StarsClean: $mFile Needs Cleaning : $needsCleaning", $LogFile);
    my @outBytes = @{$outBytes};
    
    # Output the Stars! file with modified data
    # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
    if ($cleanFiles == 2 && $needsCleaning) {
      # Backup the file before we clean it
      # Because otherwise we can't get back to where we were, as the actual
      # backup is pre-turn generation, so random event will change.
      my $mFilePreclean = $mFile . '.preclean';
	    &BlockLogOut(300,"StarsClean Backup: $mFile > $mFilePreclean", $LogFile);
 	    copy($mFile, $mFilePreclean);
      &BlockLogOut(200,"StarsClean: Pushing out $mFile post-cleaning for $GameFile", $LogFile);
      open ( CLEANFILE, '>:raw', "$mFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print CLEANFILE $outBytes[$i];
      }
      close ( CLEANFILE );
      &BlockLogOut(200,"StarsClean: Cleaned $mFile for $GameFile", $LogFile);
    } else {
      &BlockLogOut(200,"StarsClean: $mFile did not need cleaning for $GameFile", $LogFile);
    }
  } 
}

sub decryptClean {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
  my $needsCleaning = 0;
    # For Object Block 43 
  my $objectId;    
  my $count = -1;
  my $number;
  my $owner;
  my $type; # 0 = minefield, 1 = packet/salvage, 2 = wormhole, 3 = MT
  # For MT
  my ($warp, $metBits, $itemBits, $turnNo, $turnNoDisplay);
  #For minefields
  my ($mineCount, $mineDetonate, $mineType);
  #For wormholes
  my ($wormholeId, $targetId, $beenThrough, $canSee, $stability);
  # For packets
  my ($targetAndSpeed, $destPlanetId, $WarpSpeedMinus4, $WarpOverMDLimit);
  # For Player Block 6
  my ($playerId, $ShipSlotsUsed, $PlanetCount);
  my ($FleetAndStarBaseDesignCount, $FleetCount, $StarBaseDesignCount); 
  my ($fullDataFlag, $fullDataBytes);
  my $playerRelations; # byte, 0 neutral, 1 friend, 2 enemy
  # The values used when cleaning race values. Defaults to Humanoids
  my @resetRace =  ( 81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 );
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    # FileHeaderBlock, never encrypted
    if ($typeId == 8 ) { # File Header Block
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };    
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        my $PRT = $decryptedData[76];
        if ($PRT == 3) { # Reset the info the CA player can see
          $needsCleaning = 1;
          if ($cleanFiles) {   
            @decryptedData = &resetRace(\@decryptedData,$Player);
          }
        }
      }
      elsif ($typeId == 43) { # Check for special attributes in the Object Block
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
            $needsCleaning = 1;
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
            if ($cleanFiles) { 
              # Reset players who have traded with MT
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
          # Minefields
          } elsif (&isMinefield($type)) {
            $needsCleaning = 1;
            # BUG: decay rate? (might be calculated)
            $x = &read16(\@decryptedData, 2); # 2 bytes
            $y = &read16(\@decryptedData, 4); # 2 bytes
            $mineCount = &read32(\@decryptedData, 6); # 4 bytes
            $canSee = &read16(\@decryptedData, 10);
            my $mineStatus = &read16(\@decryptedData, 12);   # includes detonating
            $mineStatus = dec2bin($mineStatus);
            my @mineStatus;
            for (my $i=0; $i <= 15; $i++)  {
               $mineStatus[$i] = substr($mineStatus,$i,1); 
            }
            $mineDetonate = &getMineDetonate(\@mineStatus); # bit 7 is detonating  status
            $mineType = &getMineType(\@mineStatus); # bit 14+15 = mine type
            $unk4 = &read16(\@decryptedData, 14);  
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            if ($cleanFiles) {
              # Hard to find any data here as not much is known of the format
              # Reset players who can see the minefield
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $canSee = &read16(\@decryptedData, 10);
            }
          #Wormholes
          } elsif (isWormhole($type)) {
            $needsCleaning = 1;
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
            if ($cleanFiles) { 
              # Reset players who can see wormhole
              ($decryptedData[8], $decryptedData[9]) = &resetPlayers ($Player, &read16(\@decryptedData, 8));
              # reset values for display
    	        $canSee = &read16(\@decryptedData, 8);
              # Reset players who are known to have been through
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $beenThrough = &read16(\@decryptedData, 10);
            }
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
            my $warpSpeed = $WarpSpeedMinus4 + 4;
            if ($cleanFiles) {
              # BUG: Decay rate wouldn't be public.
              # BUG: Packet ownership must be included in here somewhere
            }
          }
        }
      }
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, $needsCleaning;
}

sub StarsList {
# Generate List files used in exploit detection
# Generally a clone of the (old) StarsFix.pl functionality
  my ($gameDir, $filename) = @_;
  
  # Get the pieces of file names
  my $basefile = basename($filename);    # mygamename.m1
  my ($gameName, $file_player, $file_type, $file_ext) = &FileData ($basefile); 
  my $listPrefix = "$gameDir/$gameName";   
  &BlockLogOut(100,"StarsList: fixing game: $listPrefix", $LogFile);
  
  # Read in the .hst File
  open(STARFILE, "<$filename");
  binmode(STARFILE);
  while (read(STARFILE, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  # Decrypt the data, block by block, and process it
  # Include the directory to handle the difference between TH and standalone 
  my %fleetList;
  my %queueList;
  my %designList;
  my %waypointList;
  my $lastPlayer;
  my $warning;
  my $needsfixing;
  
  ($outBytes, $needsFixing, $warning, $fleetList, $queueList, $designList, $waypointList, $lastPlayer) = &decryptFix($gameDir, $filename, \@fileBytes, \%fleetList, \%queueList, \%designList, \%$waypointList, $lastPlayer);
  @outBytes = @{$outBytes};
  %warning    = %$warning; # Tracking warnings generated
  %fleetList  = %$fleetList;
  %queueList  = %$queueList;
  %designList = %$designList;
  %waypointList = %$waypointList;

  # Get rid of the old List Files in case they don't exist in the new turn
  if (-f "$listPrefix.hst.fleet")    { unlink "$listPrefix.hst.fleet" }
  if (-f "$listPrefix.hst.queue")    { unlink "$listPrefix.hst.queue" }
  if (-f "$listPrefix.hst.waypoint") { unlink "$listPrefix.hst.waypoint" }
  if (-f "$listPrefix.hst.design")   { unlink "$listPrefix.hst.design" }
  #if (-f "$listPrefix.hst.last")     { unlink "$listPrefix.hst.last" }  # Never changes

  if (-d $gameDir) { # Check to make sure we're putting the List files in the right place
    if (%designList)   { &writeList("$listPrefix.hst.design", \%designList); }
    if (%queueList)    { &writeList("$listPrefix.hst.queue", \%queueList); }
    if (%fleetList)    { &writeList("$listPrefix.hst.fleet", \%fleetList); }
    if (%waypointList) { &writeList("$listPrefix.hst.waypoint", \%waypointList); }
    if ($lastPlayer) {
      open (LISTFILE, ">$listPrefix.hst.last");
      print LISTFILE "$lastPlayer"; 
      close (LISTFILE);
      umask 0002; 
      chmod 0664,"$listPrefix.hst.last";
    }
    &BlockLogOut(100, "StarsList: Done writing out List files for $listPrefix", $LogFile)
  } else { &BlockLogOut (0,"TurnMake: Directory $Dir_Games Missing for $listPrefix", $ErrorLog); }
}

sub StarsFix {
  # Return results from Stars! file for exploits (based off StarsFix & StarsQueue/StarsFleet/decryptQueue/decryptFleet
  my ($gameDir, $filename, $turn) = @_; # .x file location includes path (Uploads). BUG: Uploaded files are moved prior to StarsFix
  my $needsFixing = 0;
  
  # Get the pieces of file names
  my $basefile = basename($filename);    # mygamename.m1
  my ($gameName, $file_player, $file_type, $file_ext) = &FileData ($basefile); # The filename as component parts  
  my $listPrefix =  "$gameDir/$gameName";
  &BlockLogOut(100,"StarsFix: fixing game: $listPrefix", $LogFile);

  # read Production queue data from export
  my %queueList;
  if (-f "$listPrefix.hst.queue" ) { 
    my $queueList = &readList("$listPrefix.hst.queue");
    %queueList = %$queueList;
  #  &printList(\%queueList);
  } #else { print "No production queue file detected. Cannot detect production queue exploits\n"; }

  # Read Ship Design data from export
  my %designList;
  if (-f "$listPrefix.hst.design") {
    my $designList = &readList("$listPrefix.hst.design");
    %designList = %$designList;
    #&printList(\%designList);
  } #else { print "No ship designs file detected.\n"; }
  
  # Read Fleet data from export for: 32k bug, Mineral Upload exploit
  my %fleetList;
  if (-f "$listPrefix.hst.fleet" ) {
    my $fleetList = &readList("$listPrefix.hst.fleet");
    %fleetList = %$fleetList;
  #  &printList(\%fleetList);
  } #else { print "No fleet file detected. Cannot detect SS Pop Steal and Mineral Upload exploits\n"; }
  
  # Read waypoint data
  my %waypointList;
  if (-f "$listPrefix.hst.waypoint" ) {
    my $waypointList = &readList("$listPrefix.hst.waypoint");
    %waypointList = %$waypointList;
  #  &printList(\%fleetList);
  } #else { print "No waypoint file detected.\n"; }
 
  # read lastPlayer
  my $lastPlayer = -1; # storing the last player # for 10th Starbase
  if ($file_type =~ /x/i && -f "$listPrefix.hst.last") {
    open (LISTFILE,"$listPrefix.hst.last");
    my @lastFile = <LISTFILE>;
    close LISTFILE;
    foreach my $line (@lastFile) {
        chomp($line); 
        $lastPlayer = $line;
    }
  }
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  open(STARFILE, "<$filename");
  binmode(STARFILE);
  while (read(STARFILE, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(STARFILE);
  
  # Decrypt the data, block by block, and process it
  my ($outBytes, $warning, $fleetList, $queueList, $designList, $waypointList);
  # Include the directory to handle the difference between TH and standalone 
  ($outBytes, $needsFixing, $warning, $fleetList, $queueList, $designList, $waypointList, $lastPlayer) = &decryptFix($gameDir, $filename, \@fileBytes, \%fleetList, \%queueList, \%designList, \%$waypointList, $lastPlayer);
  my @outBytes = @{$outBytes};
  %warning    = %$warning; # Tracking warnings generated
  %fleetList  = %$fleetList;
  %queueList  = %$queueList;
  %designList = %$designList;
  %waypointList = %$waypointList;  
  
  # Need to return a string since passing an array through a URL is unlikely to work
  $warning='';
  foreach my $key (keys %warning) {
    $warning .= $warning{$key} . ',';
  }
    
  # Output the Stars! file with modified data
  # Since we don't need to rewrite the file if nothing needs fixing, let's not (safer)
  if ($needsFixing) {
    if ($fixFiles == 2) {  # Don't do unless in write mode
  	  &BlockLogOut(300,"StarsFix Backup: $filename > $filename.preFix", $LogFile);
   	  copy($filename, "$filename.preFix");
      &BlockLogOut(200," StarsFix: Pushing out $filename post-fixing", $LogFile);
      open ( OUTFILE, '>:raw', "$xFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print OUTFILE $outBytes[$i];
      }
      close ( OUTFILE );
      &BlockLogOut(200," StarsFix: Fixed $filename", $LogFile);
    } else { &BlockLogOut(300," StarsFix: Not in Fix mode for $filename", $LogFile); }
    return $warning;
  } else { 
  	&BlockLogOut(300,"StarsFix: $filename does not need fixing", $LogFile);
    return $warning; 
  }  
}

sub StarsAI {
  # Change player status in the .hst file
  # Read in the binary Stars! file, byte by byte
  my ($GameFile, $PlayerAI, $NewStatus) = @_;
  use File::Copy;
  my $FileValues;
  my @fileBytes;
  my $filename = "$Dir_Games/$GameFile/$GameFile.hst";
  my $backupfile = $filename . '.ai';
  
  #Validate the .hst file exists 
  unless (-f $filename  ) { 
    &BlockLogOut(0,"StarsAI: Failed to find $filename for $GameFile", $ErrorLog);
    return 0;
  }

  # Read in the .hst file
  open(StarFile, "<$filename");
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my ($outBytes) = &decryptAI(\@fileBytes, $PlayerAI, $NewStatus);
  if ($outBytes) {
    my @outBytes = @{$outBytes};
    # Create the backup file
  	copy($filename, $backupfile);
    # Output the Stars! File with updated player status
    open (OUTFILE, '>:raw', "$filename");
    for (my $i = 0; $i < @outBytes; $i++) {
      print OUTFILE $outBytes[$i];
    }
    close (OUTFILE);
    &BlockLogOut(200," StarsAI: Updated $filename for playerId:$playerAI to $NewStatus ", $LogFile);
  } else { 
    &BlockLogOut(200," StarsAI: Did not update $filename for playerId:$playerAI to $NewStatus ", $LogFile); 
  }
}

sub decryptAI {
  my ($fileBytes, $PlayerAI, $NewStatus ) = @_;
  my @fileBytes = @{ $fileBytes };
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti );
  my ( $seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $action = 0; # Was any action taken
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
# BUG? Does the file footer / race hash have to be updated when we change this? 
#    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
#      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
      my $playerId = $decryptedData[0] & 0xFF; # Always 255 in a race file
        if ($PlayerAI == $playerId) {
          if (($NewStatus eq 'Active' || $NewStatus eq 'Idle')  && $decryptedData[7] == 227 ) {
            $action = 1;
            #Changing from Human(Inactive) to Human
            $decryptedData[7] = 225;
            # The bits for the password of an inactive player are the inverse of the 
            # bits of the password for an active player 
            # Flip the bits of the password
            $decryptedData[12] = &read8(~$decryptedData[12]);
            $decryptedData[13] = &read8(~$decryptedData[13]);
            $decryptedData[14] = &read8(~$decryptedData[14]);
            $decryptedData[15] = &read8(~$decryptedData[15]);
            &BlockLogOut(200," StarsAI: Flipped playerId:$playerId to Active", $LogFile);
          } elsif ($NewStatus eq 'Inactive'  && ($decryptedData[7] == 225  || $decryptedData[7] == 1)) {
            $action = 1;
            #Changing from Human to Human(Inactive) AI
            $decryptedData[7] = 227;
            # The bits for the password of an inactive player are the inverse of the 
            # bits of the password for an active player 
            # Flip the bits of the password
            $decryptedData[12] = &read8(~$decryptedData[12]);
            $decryptedData[13] = &read8(~$decryptedData[13]);
            $decryptedData[14] = &read8(~$decryptedData[14]);
            $decryptedData[15] = &read8(~$decryptedData[15]);
            &BlockLogOut(200," StarsAI: Flipped playerId:$playerId to Inactive/AI", $LogFile);
          } else { &BlockLogOut(200," StarsAI: No Status Change for playerId:$playerId", $LogFile); }
        } 
      } 
      # END OF MAGIC
      #reencrypt the data for output    
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  # If the password / AI was not reset, no need to write the file back out
  # Faster, less risk of corruption   
  if ($action) { return \@outBytes; 
  } else { &BlockLogOut(200," StarsAI: Did not make changes to $filename for playerID:$PlayerAI to $NewStatus", $LogFile); return 0; }
}

sub zerofy {
# make a 1 digit number 2 digits
  my ($val) = @_;
  if ($val < 10  && $val >=0 ) { return "0" . $val; }
  else { return $val; } 
}

sub splitWarnId {
  # I probably should make this another hash of hashes, but it would mean redesigning the warnId... again.
	my ($warnId)  = @_;
	my ($player, $warningType, $id) = split ('-',$warnId);
	$player = $player *1; # deZerofy
	return ($player, $warningType, $id);
}

sub attackWho {
   my ($value) = @_;
   #Nobody, Enemies, Neutral/Enemies, Everyone, [Players] 
   my @category = qw(Nobody Enemies Neutral/Enemies Everyone);
   if ($value > 3) { my $player = $value -4; return "Player " .($player+1); }
   else { return $category[$value]; }
}

sub showCategory {
  my ($category, $item) = @_;
  my @category;
  my %item;
  $category[0] = 'Empty';        #00000000  0
  $category[1] = 'Engine';       #0000000x  1
  $category[2] = 'Scanners';     #000000x0  2
  $category[4] = 'Shields';      #00000x00  4
  $category[8] = 'Armor';        #0000x000  8
  $category[16] = 'BeamWeapon';  #000x0000  0x10
  $category[32] = 'Torpedo';     #00x00000  0x20
  $category[64] = 'Bomb';        #0x000000  0x40
  $category[128] = 'MiningRobot';#x0000000  0x80
  $category[256] = 'MineLayer';  #          0x100
  $category[512] = 'Orbital';    #          0x200
  $category[1024] = 'Planetary'; #          0x400 Assumed since it appears to be the only missing one
  $category[2048] = 'Electrical';#          0x800
  $category[4096] = 'Mechanical';#          0x1000
  $category[6144] = 'Orbital Or Electrical';

  $item{'0'} =  [ qw ( empty ) ]; 
  $item{'1'} =  [ qw ( SettlerDelight Jump5 Mizer Hump6 Legs7 Alpha8 Trans9 Inter10 Enigma Trans10 NHRS Sub Trans TransSuper TransMizer Galaxy ) ];
  $item{'2'} =  [ qw ( Bat Rhino Mole DNA Possum PickPocket Chameleon Ferret Dolphin Gazelle RNA Cheetah Elephant Eagle Robber Peerless) ];
  $item{'4'} =  [ qw ( Mole Cow Wolverine Croby Shadow Bear Langston Gorilla Elephant Complete ) ];
  $item{'8'} =  [ qw ( Tritanium Crobmium CarbonicArmor Strobnium OrganicArmor Kelarium FieldedKelarium DepletedNeutronium Neutronium MegaPoly Valanium Superlatanium ) ];
  $item{'16'} = [ qw ( Laser X-Ray MiniGun YakimoraPhaser Blackjack Phaser PulsedSapper ColloidalPhaser GatlingGun MiniBlaster Bludgeon MarkIVBlaster PhasedSapper HeavyBlaster GatlingNeutrino MyopicDisruptor Blunderbuss Disruptor MultiContainedMunition SyncroSapper MegaDisruptor BigMuthaCannon StreamingPulverizer Anti-MatterPulverizer ) ]; 
  $item{'32'} = [ qw ( Alpha Beta Delta Epsilon Rho Upsilon Omega AntiMatter Jihad Juggernaut Doomsday Armageddon ) ];
  $item{'64'} = [ qw ( LadyFinger BlackCat M-70 M-80 Cherry LBU-17 LBU-32 LBU-74 HushaBoom Retro Smart Neutron EnrichedNeutron Peerless Annihilator ) ];
  $item{'128'} = [ qw ( Midget Mini Miner Maxi Super Ultra Orbital ) ]; 
  $item{'256'} = [ qw ( Mine40 Mine50 Mine80 Mine130 Heavy50 Heavy110 Heavy200 Speed20 Speed30 Speed50 ) ];
  $item{'512'} = [ qw ( SG250 SG300 SG600 SG500 SGany SG800  SGanyany Mass5 Mass6 Mass7 Mass8 Mass9 Mass10 Mass11 Mass12 Mass13 ) ];  #BUG: Where is SG100
  $item{'1024'} = [ qw ( Viewer50 Viewer90 Viewer150 Viewer220 Viewer280 Viewer320 Snooper400 Snooper500 Snooper620 ) ];
  $item{'2048'} = [ qw ( TransportCloak StealthCloak Super-StealthCloak Ultra-StealthCloak MultiFunction BattleComputer BattleSuperComputer BattleNexus Jammer10 Jammer20 Jammer30 Jammer50 EnergyCapacitor FluxCapacitor EnergyDampener TachyonDetector Anti-matterGenerator) ];
  $item{'4096'} = [ qw ( Colonization OrbitalCon Cargo SuperCargo MultiCargo Fuel SuperFuel ManeuveringJet Overthruster BeamDeflector ) ];
  $item{'6194'} = [ qw ( empty ) ];

  return ($category[$category],$item{$category}[$item]);
}

sub readHullType {
  my %hullType;
  $hullType{'0'} = [ 15,1,"Small Freighter",0,0,0,0,0,0,0,25,20,12,0,17,0,70,130,25,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,85,51,49,55,53,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'1'} = [ 15,2,"Medium Freighter",1,0,0,0,3,0,0,60,40,20,0,19,4,210,450,50,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,86,50,48,56,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'2'} = [ 15,3,"Large Freighter",2,0,0,0,8,0,0,125,100,35,0,21,8,1200,2600,150,1,2,6146,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,102,34,48,38,70,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'3'} = [ 15,4,"Super Freighter",3,0,0,0,13,0,0,175,125,45,0,21,12,3000,8000,400,1,3,6146,3,12,5,2048,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,136,34,64,40,72,104,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'4'} = [ 15,5,"Scout",4,0,0,0,0,0,0,8,10,4,2,4,16,0,50,20,1,1,2,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,65,8,255,255,50,54,52,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'5'} = [ 15,6,"Frigate",5,0,0,0,6,0,0,8,12,4,2,4,20,0,125,45,1,1,2,2,6462,3,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,68,8,255,255,49,55,53,51,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'6'} = [ 15,7,"Destroyer",6,0,0,0,3,0,0,30,35,15,3,5,24,0,280,200,1,1,48,1,48,1,6462,1,8,2,4096,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,67,8,255,255,66,21,117,70,68,35,99,0,0,0,0,0,0,0,0,0 ];
  $hullType{'7'} = [ 15,8,"Cruiser",7,0,0,0,9,0,0,90,85,40,5,8,28,0,600,700,1,2,6148,1,6148,1,48,2,48,2,6462,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
  $hullType{'8'} = [ 15,9,"Battle Cruiser",8,0,0,0,10,0,0,120,120,55,8,12,32,0,1400,1000,1,2,6148,2,6148,2,48,3,48,3,6462,3,12,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
  $hullType{'9'} = [ 15,10,"Battleship",9,0,0,0,13,0,0,222,225,120,25,20,36,0,2800,2000,1,4,6146,1,4,8,48,6,48,6,48,2,48,2,48,4,8,6,2048,3,2048,3,0,0,0,0,0,0,0,0,0,0,11,138,12,255,255,48,56,38,20,84,2,98,70,52,34,66,0,0,0,0,0 ];
  $hullType{'10'} = [ 15,11,"Dreadnought",10,0,0,0,16,0,0,250,275,140,30,25,40,0,4500,4500,1,5,12,4,12,4,48,6,48,6,2048,4,2048,4,48,8,48,8,8,8,52,5,52,5,6462,2,0,0,0,0,0,0,13,138,12,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
  $hullType{'11'} = [ 15,12,"Privateer",11,0,0,0,4,0,0,65,50,50,3,2,44,250,650,150,1,1,12,2,6146,1,6462,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,67,16,103,67,65,55,87,37,101,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'12'} = [ 15,13,"Rogue",12,0,0,0,8,0,0,75,60,80,5,5,48,500,2250,450,1,2,12,3,6400,2,2,1,6462,2,6462,2,6400,2,2048,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,132,16,118,51,65,70,102,72,20,116,38,18,114,0,0,0,0,0,0,0 ];
  $hullType{'13'} = [ 15,14,"Galleon",13,0,0,0,11,0,0,125,105,70,5,5,52,1000,2500,900,1,4,12,2,12,2,6462,3,6462,3,6400,2,6144,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,132,16,118,50,64,19,115,21,117,54,86,72,0,0,0,0,0,0,0,0 ];
  $hullType{'14'} = [ 15,15,"Mini-Colony Ship",14,0,0,0,0,0,0,8,3,2,0,2,56,10,150,10,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'15'} = [ 15,16,"Colony Ship",15,0,0,0,0,0,0,20,20,10,0,15,60,25,200,20,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'16'} = [ 15,17,"Mini Bomber",16,0,0,0,1,0,0,28,35,20,5,10,64,0,120,50,1,1,64,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,192,20,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'17'} = [ 15,18,"B-17 Bomber",17,0,0,0,6,0,0,69,150,55,10,10,68,0,400,175,1,2,64,4,64,4,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,192,20,255,255,49,51,53,55,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'18'} = [ 15,19,"Stealth Bomber",18,0,0,0,8,0,0,70,175,55,10,15,72,0,750,225,1,2,64,4,64,4,6146,1,2048,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,192,20,255,255,50,36,68,38,70,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'19'} = [ 15,20,"B-52 Bomber",19,0,0,0,15,0,0,110,280,90,15,10,76,0,750,450,1,3,64,4,64,4,64,4,64,4,6146,2,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,192,20,255,255,49,19,83,37,69,55,51,0,0,0,0,0,0,0,0,0 ];
  $hullType{'20'} = [ 15,21,"Midget Miner",20,0,0,0,0,0,0,10,20,10,0,3,80,0,210,100,1,1,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,24,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'21'} = [ 15,22,"Mini-Miner",21,0,0,0,2,0,0,80,50,25,0,6,84,0,210,130,1,1,6146,1,128,1,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,24,255,255,50,54,36,68,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'22'} = [ 15,23,"Miner",22,0,0,0,6,0,0,110,110,32,0,6,88,0,500,475,1,2,6154,2,128,2,128,1,128,2,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'23'} = [ 15,24,"Maxi-Miner",23,0,0,0,11,0,0,110,140,32,0,6,92,0,850,1400,1,3,6154,2,128,4,128,1,128,4,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'24'} = [ 15,25,"Ultra-Miner",24,0,0,0,14,0,0,100,130,30,0,6,96,0,1300,1500,1,2,6154,3,128,4,128,2,128,4,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'25'} = [ 15,26,"Fuel Transport",25,0,0,0,4,0,0,12,50,10,0,5,100,0,750,5,1,1,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,28,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'26'} = [ 15,27,"Super-Fuel Xport",26,0,0,0,7,0,0,111,70,20,0,8,104,0,2250,12,1,2,4,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,28,255,255,50,52,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'27'} = [ 15,28,"Mini Mine Layer",27,0,0,0,0,0,0,10,20,8,2,5,108,0,400,60,1,1,256,2,256,2,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,16,255,255,50,36,68,54,0,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'28'} = [ 15,29,"Super Mine Layer",28,0,0,0,15,0,0,30,30,20,3,9,112,0,2200,1200,1,3,256,8,256,8,12,3,6146,3,6400,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,16,255,255,49,35,67,53,39,71,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'29'} = [ 15,30,"Nubian",29,0,0,0,26,0,0,100,150,75,12,12,124,0,5000,5000,1,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,0,0,0,0,0,0,13,130,16,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
  $hullType{'30'} = [ 15,31,"Mini Morph",30,0,0,0,8,0,0,70,100,30,8,8,120,150,400,250,1,2,6462,3,6462,1,6462,1,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
  $hullType{'31'} = [ 15,32,"Meta Morph",31,0,0,0,10,0,0,85,120,50,12,12,116,300,700,500,1,3,6462,8,6462,2,6462,2,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
  $hullType{'32'} = [ 16,1,"Orbital Fort",32,0,0,0,0,0,0,0,80,24,0,34,128,0,0,100,2560,1,48,12,12,12,48,12,12,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,138,0,255,255,68,36,70,100,66,0,0,0,0,0,0,0,0,0,0,0 ];
  $hullType{'33'} = [ 16,2,"Space Dock",33,0,0,0,4,0,0,0,200,40,10,50,132,200,0,250,2560,1,48,16,12,24,48,16,4,24,2048,2,2048,2,48,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,140,0,102,68,34,20,65,71,116,38,102,98,0,0,0,0,0,0,0,0 ];
  $hullType{'34'} = [ 16,3,"Space Station",34,0,0,0,0,0,0,0,1200,240,160,500,136,-1,0,500,2560,1,48,16,4,16,48,16,12,16,4,16,2048,3,48,16,2048,3,48,16,2560,1,12,16,0,0,0,0,0,0,0,0,12,142,0,102,68,66,5,3,88,80,133,100,131,36,48,70,56,0,0,0,0 ];
  $hullType{'35'} = [ 16,4,"Ultra Station",35,0,0,0,12,0,0,0,1200,240,160,600,140,-1,0,1000,2560,1,48,16,2048,3,48,16,4,20,4,20,2048,3,48,16,2048,3,48,16,2560,1,12,20,48,16,12,20,2048,3,48,16,16,144,0,102,68,36,80,66,88,98,38,70,3,131,56,100,102,48,34,5,133 ];
  $hullType{'36'} = [ 16,5,"Death Star",36,0,0,0,17,0,0,0,1500,240,160,700,144,-1,0,1500,2560,1,48,32,2048,4,2048,4,4,30,4,30,2048,4,48,32,2048,4,48,32,2560,1,12,20,2048,4,12,20,2048,4,48,32,16,146,0,102,68,20,96,65,104,98,38,71,2,130,40,116,102,32,34,6,134 ];
  return %hullType;
}

sub readItemDetail {
  # Position 10 is mass
  # Position 18 is fuel
  my %itemDetail;
  $itemDetail{'1|1'}  = [  14,1,'Settler\'s Delight',1,0,0,0,0,0,0,2,2,1,0,1,8,1,0,0,0,0,0,0,0,140,275,480,576,0 ];
  $itemDetail{'1|2'}  = [  14,2,'Quick Jump 5',2,0,0,0,0,0,0,4,3,3,0,1,0,0,0,0,25,100,100,100,180,500,800,900,1080,0 ];
  $itemDetail{'1|3'}  = [  14,3,'Fuel Mizer',3,0,0,2,0,0,0,6,11,8,0,0,9,3,0,0,0,0,0,35,120,175,235,360,420,0 ];
  $itemDetail{'1|4'}  = [  14,4,'Long Hump 6',4,0,0,3,0,0,0,9,6,5,0,1,1,0,0,0,20,60,100,100,105,450,750,900,1080,0 ];
  $itemDetail{'1|5'}  = [  14,5,'Daddy Long Legs 7',5,0,0,5,0,0,0,13,12,11,0,3,2,0,0,0,20,60,70,100,100,110,600,750,900,0 ];
  $itemDetail{'1|6'}  = [  14,6,'Alpha Drive 8',6,0,0,7,0,0,0,17,28,16,0,3,3,0,0,0,15,50,60,70,100,100,115,700,840,0 ];
  $itemDetail{'1|7'}  = [  14,7,'Trans-Galactic Drive',7,0,0,9,0,0,0,25,50,20,20,9,4,0,0,0,15,35,45,55,70,80,90,100,120,0 ];
  $itemDetail{'1|8'}  = [  14,8,'Interspace-10',8,0,0,11,0,0,0,25,60,18,25,10,12,5,0,0,10,30,40,50,60,70,80,90,100,0 ];
  $itemDetail{'1|9'}  = [  14,9,'Enigma Pulsar',9,7,0,13,5,9,0,20,40,12,15,11,109,6,0,0,0,0,0,0,65,75,85,95,105,0 ];
  $itemDetail{'1|10'}  = [  14,10,'Trans-Star 10',10,0,0,23,0,0,0,5,10,3,0,3,117,0,0,0,5,15,20,25,30,35,40,45,50,0 ];
  $itemDetail{'1|11'}  = [  14,11,'Radiating Hydro-Ram Scoop',11,2,0,6,0,0,0,10,8,3,2,9,7,2,0,0,0,0,0,0,0,165,375,600,720,0 ];
  $itemDetail{'1|12'}  = [  14,12,'Sub-Galactic Fuel Scoop',12,2,0,8,0,0,0,20,12,4,4,7,5,0,0,0,0,0,0,0,85,105,210,380,456,0 ];
  $itemDetail{'1|13'}  = [  14,13,'Trans-Galactic Fuel Scoop',13,3,0,9,0,0,0,19,18,5,4,12,6,0,0,0,0,0,0,0,0,88,100,145,174,0 ];
  $itemDetail{'1|14'}  = [  14,14,'Trans-Galactic Super Scoop',14,4,0,12,0,0,0,18,24,6,4,16,10,0,0,0,0,0,0,0,0,0,65,90,108,0 ];
  $itemDetail{'1|15'}  = [  14,15,'Trans-Galactic Mizer Scoop',15,4,0,16,0,0,0,11,20,5,2,13,11,0,0,0,0,0,0,0,0,0,0,70,84,0 ];
  $itemDetail{'1|16'}  = [  14,16,'Galaxy Scoop',16,5,0,20,0,0,0,8,12,4,2,9,191,4,0,0,0,0,0,0,0,0,0,0,60,0 ];
  $itemDetail{'2|1'}  = [  12,1,'Bat Scanner',1,0,0,0,0,0,0,2,1,1,0,1,59,0,0,,,,,,,,,,, ];
  $itemDetail{'2|2'}  = [  12,2,'Rhino Scanner',2,0,0,0,0,1,0,5,3,3,0,2,48,50,0,,,,,,,,,,, ];
  $itemDetail{'2|3'}  = [  12,3,'Mole Scanner',3,0,0,0,0,4,0,2,9,2,0,2,49,100,0,,,,,,,,,,, ];
  $itemDetail{'2|4'}  = [  12,4,'DNA Scanner',4,0,0,3,0,0,6,2,5,1,1,1,52,125,0,,,,,,,,,,, ];
  $itemDetail{'2|5'}  = [  12,5,'Possum Scanner',5,0,0,0,0,5,0,3,18,3,0,3,61,150,0,,,,,,,,,,, ];
  $itemDetail{'2|6'}  = [  12,6,'Pick Pocket Scanner',6,4,0,0,0,4,4,15,35,8,10,6,56,80,4,,,,,,,,,,, ];
  $itemDetail{'2|7'}  = [  12,7,'Chameleon Scanner',7,3,0,0,0,6,0,6,25,4,6,4,63,160,4,,,,,,,,,,, ];
  $itemDetail{'2|8'}  = [  12,8,'Ferret Scanner',8,3,0,0,0,7,2,2,36,2,0,8,53,185,1,,,,,,,,,,, ];
  $itemDetail{'2|9'}  = [  12,9,'Dolphin Scanner',9,5,0,0,0,10,4,4,40,5,5,10,54,220,2,,,,,,,,,,, ];
  $itemDetail{'2|10'}  = [  12,10,'Gazelle Scanner',10,4,0,0,0,8,0,5,24,4,0,5,50,225,0,,,,,,,,,,, ];
  $itemDetail{'2|11'}  = [  12,11,'RNA Scanner',11,0,0,5,0,0,10,2,20,1,1,2,60,230,0,,,,,,,,,,, ];
  $itemDetail{'2|12'}  = [  12,12,'Cheetah Scanner',12,5,0,0,0,11,0,4,50,3,1,13,62,275,0,,,,,,,,,,, ];
  $itemDetail{'2|13'}  = [  12,13,'Elephant Scanner',13,6,0,0,0,16,7,6,70,8,5,14,55,300,3,,,,,,,,,,, ];
  $itemDetail{'2|14'}  = [  12,14,'Eagle Eye Scanner',14,6,0,0,0,14,0,3,64,3,2,21,51,335,0,,,,,,,,,,, ];
  $itemDetail{'2|15'}  = [  12,15,'Robber Baron Scanner',15,10,0,0,0,15,10,20,90,10,10,10,57,220,4,,,,,,,,,,, ];
  $itemDetail{'2|16'}  = [  12,16,'Peerless Scanner',16,7,0,0,0,24,0,4,90,3,2,30,58,500,0,,,,,,,,,,, ];
  $itemDetail{'4|1'}  = [  11,1,'Mole-skin Shield',1,0,0,0,0,0,0,1,4,1,0,1,42,25,,,,,,,,,,,, ];
  $itemDetail{'4|2'}  = [  11,2,'Cow-hide Shield',2,3,0,0,0,0,0,1,5,2,0,2,43,40,,,,,,,,,,,, ];
  $itemDetail{'4|3'}  = [  11,3,'Wolverine Diffuse Shield',3,6,0,0,0,0,0,1,6,3,0,3,44,60,,,,,,,,,,,, ];
  $itemDetail{'4|4'}  = [  11,4,'Croby Sharmor',4,7,0,0,4,0,0,10,15,7,0,4,40,60,,,,,,,,,,,, ];
  $itemDetail{'4|5'}  = [  11,5,'Shadow Shield',5,7,0,0,0,3,0,2,7,3,0,3,41,75,,,,,,,,,,,, ];
  $itemDetail{'4|6'}  = [  11,6,'Bear Neutrino Barrier',6,10,0,0,0,0,0,1,8,4,0,4,45,100,,,,,,,,,,,, ];
  $itemDetail{'4|7'}  = [  11,7,'Langston Shell',7,12,0,9,0,9,0,10,20,10,2,6,183,125,,,,,,,,,,,, ];
  $itemDetail{'4|8'}  = [  11,8,'Gorilla Delagator',8,14,0,0,0,0,0,1,11,5,0,6,46,175,,,,,,,,,,,, ];
  $itemDetail{'4|9'}  = [  11,9,'Elephant Hide Fortress',9,18,0,0,0,0,0,1,15,8,0,10,47,300,,,,,,,,,,,, ];
  $itemDetail{'4|10'}  = [  11,10,'Complete Phase Shield',10,22,0,0,0,0,0,1,20,12,0,15,119,500,,,,,,,,,,,, ];
  $itemDetail{'8|1'}  = [  13,1,'Tritanium',1,0,0,0,0,0,0,60,10,5,0,0,64,50,,,,,,,,,,,, ];
  $itemDetail{'8|2'}  = [  13,2,'Crobmnium',2,0,0,0,3,0,0,56,13,6,0,0,65,75,,,,,,,,,,,, ];
  $itemDetail{'8|3'}  = [  13,3,'Carbonic Armor',3,0,0,0,0,0,4,25,15,0,0,5,70,100,,,,,,,,,,,, ];
  $itemDetail{'8|4'}  = [  13,4,'Strobnium',4,0,0,0,6,0,0,54,18,8,0,0,68,120,,,,,,,,,,,, ];
  $itemDetail{'8|5'}  = [  13,5,'Organic Armor',5,0,0,0,0,0,7,15,20,0,0,6,71,175,,,,,,,,,,,, ];
  $itemDetail{'8|6'}  = [  13,6,'Kelarium',6,0,0,0,9,0,0,50,25,9,1,0,67,180,,,,,,,,,,,, ];
  $itemDetail{'8|7'}  = [  13,7,'Fielded Kelarium',7,4,0,0,10,0,0,50,28,10,0,2,78,175,,,,,,,,,,,, ];
  $itemDetail{'8|8'}  = [  13,8,'Depleted Neutronium',8,0,0,0,10,3,0,50,28,10,0,2,79,200,,,,,,,,,,,, ];
  $itemDetail{'8|9'}  = [  13,9,'Neutronium',9,0,0,0,12,0,0,45,30,11,2,1,69,275,,,,,,,,,,,, ];
  $itemDetail{'8|10'}  = [  13,10,'Mega Poly Shell',10,14,0,0,14,14,6,20,65,18,6,6,110,400,,,,,,,,,,,, ];
  $itemDetail{'8|11'}  = [  13,11,'Valanium',11,0,0,0,16,0,0,40,50,15,0,0,66,500,,,,,,,,,,,, ];
  $itemDetail{'8|12'}  = [  13,12,'Superlatanium',12,0,0,0,24,0,0,30,100,25,0,0,77,1500,,,,,,,,,,,, ];
  $itemDetail{'16|1'}  = [  2,1,'Laser',1,0,0,0,0,0,0,1,5,0,6,0,28,1,10,9,0,,,,,,,,, ];
  $itemDetail{'16|2'}  = [  2,2,'X-Ray Laser',2,0,3,0,0,0,0,1,6,0,6,0,29,1,16,9,0,,,,,,,,, ];
  $itemDetail{'16|3'}  = [  2,3,'Mini Gun',3,0,5,0,0,0,0,3,10,0,16,0,20,2,13,12,2,,,,,,,,, ];
  $itemDetail{'16|4'}  = [  2,4,'Yakimora Light Phaser',4,0,6,0,0,0,0,1,7,0,8,0,19,1,26,9,0,,,,,,,,, ];
  $itemDetail{'16|5'}  = [  2,5,'Blackjack',5,0,7,0,0,0,0,10,7,0,16,0,14,0,90,10,0,,,,,,,,, ];
  $itemDetail{'16|6'}  = [  2,6,'Phaser Bazooka',6,0,8,0,0,0,0,2,11,0,8,0,21,2,26,7,0,,,,,,,,, ];
  $itemDetail{'16|7'}  = [  2,7,'Pulsed Sapper',7,5,9,0,0,0,0,1,12,0,0,4,17,3,82,14,1,,,,,,,,, ];
  $itemDetail{'16|8'}  = [  2,8,'Colloidal Phaser',8,0,10,0,0,0,0,2,18,0,14,0,192,3,26,5,0,,,,,,,,, ];
  $itemDetail{'16|9'}  = [  2,9,'Gatling Gun',9,0,11,0,0,0,0,3,13,0,20,0,26,2,31,12,2,,,,,,,,, ];
  $itemDetail{'16|10'}  = [  2,10,'Mini Blaster',10,0,12,0,0,0,0,1,9,0,10,0,24,1,66,9,0,,,,,,,,, ];
  $itemDetail{'16|11'}  = [  2,11,'Bludgeon',11,0,13,0,0,0,0,10,9,0,22,0,15,0,231,10,0,,,,,,,,, ];
  $itemDetail{'16|12'}  = [  2,12,'Mark IV Blaster',12,0,14,0,0,0,0,2,15,0,12,0,25,2,66,7,0,,,,,,,,, ];
  $itemDetail{'16|13'}  = [  2,13,'Phased Sapper',13,8,15,0,0,0,0,1,16,0,0,6,18,3,211,14,1,,,,,,,,, ];
  $itemDetail{'16|14'}  = [  2,14,'Heavy Blaster',14,0,16,0,0,0,0,2,25,0,20,0,193,3,66,5,0,,,,,,,,, ];
  $itemDetail{'16|15'}  = [  2,15,'Gatling Neutrino Cannon',15,0,17,0,0,0,0,3,17,0,28,0,30,2,80,13,2,,,,,,,,, ];
  $itemDetail{'16|16'}  = [  2,16,'Myopic Disruptor',16,0,18,0,0,0,0,1,12,0,14,0,194,1,169,9,0,,,,,,,,, ];
  $itemDetail{'16|17'}  = [  2,17,'Blunderbuss',17,0,19,0,0,0,0,10,13,0,30,0,13,0,592,11,0,,,,,,,,, ];
  $itemDetail{'16|18'}  = [  2,18,'Disruptor',18,0,20,0,0,0,0,2,20,0,16,0,27,2,169,8,0,,,,,,,,, ];
  $itemDetail{'16|19'}  = [  2,19,'Multi Contained Munition',19,21,21,0,0,16,12,8,40,6,40,6,111,3,140,6,0,,,,,,,,, ];
  $itemDetail{'16|20'}  = [  2,20,'Syncro Sapper',20,11,21,0,0,0,0,1,21,0,0,8,16,3,541,14,1,,,,,,,,, ];
  $itemDetail{'16|21'}  = [  2,21,'Mega Disruptor',21,0,22,0,0,0,0,2,33,0,30,0,195,3,169,6,0,,,,,,,,, ];
  $itemDetail{'16|22'}  = [  2,22,'Big Mutha Cannon',22,0,23,0,0,0,0,3,23,0,36,0,31,2,204,13,2,,,,,,,,, ];
  $itemDetail{'16|23'}  = [  2,23,'Streaming Pulverizer',23,0,24,0,0,0,0,1,16,0,20,0,22,1,433,9,0,,,,,,,,, ];
  $itemDetail{'16|24'}  = [  2,24,'Anti-Matter Pulverizer',24,0,26,0,0,0,0,2,27,0,22,0,23,2,433,8,0,,,,,,,,, ];
  $itemDetail{'32|1'}  = [  3,1,'Alpha Torpedo',1,0,0,0,0,0,0,25,5,9,3,3,87,4,5,0,35,,,,,,,,, ];
  $itemDetail{'32|2'}  = [  3,2,'Beta Torpedo',2,0,5,1,0,0,0,25,6,18,6,4,88,4,12,1,45,,,,,,,,, ];
  $itemDetail{'32|3'}  = [  3,3,'Delta Torpedo',3,0,10,2,0,0,0,25,8,22,8,5,89,4,26,1,60,,,,,,,,, ];
  $itemDetail{'32|4'}  = [  3,4,'Epsilon Torpedo',4,0,14,3,0,0,0,25,10,30,10,6,92,5,48,2,65,,,,,,,,, ];
  $itemDetail{'32|5'}  = [  3,5,'Rho Torpedo',5,0,18,4,0,0,0,25,12,34,12,8,93,5,90,2,75,,,,,,,,, ];
  $itemDetail{'32|6'}  = [  3,6,'Upsilon Torpedo',6,0,22,5,0,0,0,25,15,40,14,9,94,5,169,3,75,,,,,,,,, ];
  $itemDetail{'32|7'}  = [  3,7,'Omega Torpedo',7,0,26,6,0,0,0,25,18,52,18,12,95,5,316,4,80,,,,,,,,, ];
  $itemDetail{'32|8'}  = [  3,8,'Anti Matter Torpedo',8,0,11,12,0,0,21,8,50,3,8,1,108,6,60,0,85,,,,,,,,, ];
  $itemDetail{'32|9'}  = [  3,9,'Jihad Missile',9,0,12,6,0,0,0,35,13,37,13,9,200,5,85,0,20,,,,,,,,, ];
  $itemDetail{'32|10'}  = [  3,10,'Juggernaut Missile',10,0,16,8,0,0,0,35,16,48,16,11,201,5,150,1,20,,,,,,,,, ];
  $itemDetail{'32|11'}  = [  3,11,'Doomsday Missile',11,0,20,10,0,0,0,35,20,60,20,13,202,6,280,2,25,,,,,,,,, ];
  $itemDetail{'32|12'}  = [  3,12,'Armageddon Missile',12,0,24,10,0,0,0,35,24,67,23,16,203,6,525,3,30,,,,,,,,, ];
  $itemDetail{'64|1'}  = [  4,1,'Lady Finger Bomb',1,0,2,0,0,0,0,40,5,1,20,0,35,1,6,2,,,,,,,,,, ];
  $itemDetail{'64|2'}  = [  4,2,'Black Cat Bomb',2,0,5,0,0,0,0,45,7,1,22,0,36,1,9,4,,,,,,,,,, ];
  $itemDetail{'64|3'}  = [  4,3,'M-70 Bomb',3,0,8,0,0,0,0,50,9,1,24,0,37,1,12,6,,,,,,,,,, ];
  $itemDetail{'64|4'}  = [  4,4,'M-80 Bomb',4,0,11,0,0,0,0,55,12,1,25,0,38,1,17,7,,,,,,,,,, ];
  $itemDetail{'64|5'}  = [  4,5,'Cherry Bomb',5,0,14,0,0,0,0,52,11,1,25,0,39,1,25,10,,,,,,,,,, ];
  $itemDetail{'64|6'}  = [  4,6,'LBU-17 Bomb',6,0,5,0,0,8,0,30,7,1,15,15,32,1,2,16,,,,,,,,,, ];
  $itemDetail{'64|7'}  = [  4,7,'LBU-32 Bomb',7,0,10,0,0,10,0,35,10,1,24,15,33,1,3,28,,,,,,,,,, ];
  $itemDetail{'64|8'}  = [  4,8,'LBU-74 Bomb',8,0,15,0,0,12,0,45,14,1,33,12,34,1,4,45,,,,,,,,,, ];
  $itemDetail{'64|9'}  = [  4,9,'Hush-a-Boom',9,0,12,0,0,12,12,5,5,1,5,0,182,1,30,2,,,,,,,,,, ];
  $itemDetail{'64|10'}  = [  4,10,'Retro Bomb',10,0,10,0,0,0,12,45,50,15,15,10,174,1,0,0,,,,,,,,,, ];
  $itemDetail{'64|11'}  = [  4,11,'Smart Bomb',11,0,5,0,0,0,7,50,27,1,22,0,112,1,13,0,,,,,,,,,, ];
  $itemDetail{'64|12'}  = [  4,12,'Neutron Bomb',12,0,10,0,0,0,10,57,30,1,30,0,113,1,22,0,,,,,,,,,, ];
  $itemDetail{'64|13'}  = [  4,13,'Enriched Neutron Bomb',13,0,15,0,0,0,12,64,25,1,36,0,114,1,35,0,,,,,,,,,, ];
  $itemDetail{'64|14'}  = [  4,14,'Peerless Bomb',14,0,22,0,0,0,15,55,32,1,33,0,115,1,50,0,,,,,,,,,, ];
  $itemDetail{'64|15'}  = [  4,15,'Annihilator Bomb',15,0,26,0,0,0,17,50,28,1,30,0,116,1,70,0,,,,,,,,,, ];
  $itemDetail{'128|1'}  = [  7,1,'Robo-Midget Miner',1,0,0,0,0,0,0,80,50,14,0,4,138,5,,,,,,,,,,,, ];
  $itemDetail{'128|2'}  = [  7,2,'Robo-Mini-Miner',2,0,0,0,2,1,0,240,100,30,0,7,139,4,,,,,,,,,,,, ];
  $itemDetail{'128|3'}  = [  7,3,'Robo-Miner',3,0,0,0,4,2,0,240,100,30,0,7,140,12,,,,,,,,,,,, ];
  $itemDetail{'128|4'}  = [  7,4,'Robo-Maxi-Miner',4,0,0,0,7,4,0,240,100,30,0,7,141,18,,,,,,,,,,,, ];
  $itemDetail{'128|5'}  = [  7,5,'Robo-Super-Miner',5,0,0,0,12,6,0,240,100,30,0,7,142,27,,,,,,,,,,,, ];
  $itemDetail{'128|6'}  = [  7,6,'Robo-Ultra-Miner',6,0,0,0,15,8,0,80,50,14,0,4,143,25,,,,,,,,,,,, ];
  $itemDetail{'128|7'}  = [  7,7,'Alien Miner',7,5,0,0,10,5,5,20,20,8,0,2,181,10,,,,,,,,,,,, ];
  $itemDetail{'128|8'}  = [  7,8,'Orbital Adjuster',8,0,0,0,0,0,6,80,50,25,25,25,173,0,,,,,,,,,,,, ];
  $itemDetail{'256|1'}  = [  8,1,'Mine Dispenser 40',1,0,0,0,0,0,0,25,45,2,10,8,128,4,,,,,,,,,,,, ];
  $itemDetail{'256|2'}  = [  8,2,'Mine Dispenser 50',2,2,0,0,0,0,4,30,55,2,12,10,129,5,,,,,,,,,,,, ];
  $itemDetail{'256|3'}  = [  8,3,'Mine Dispenser 80',3,3,0,0,0,0,7,30,65,2,14,10,130,8,,,,,,,,,,,, ];
  $itemDetail{'256|4'}  = [  8,4,'Mine Dispenser 130',4,6,0,0,0,0,12,30,80,2,18,10,131,13,,,,,,,,,,,, ];
  $itemDetail{'256|5'}  = [  8,5,'Heavy Dispenser 50',5,5,0,0,0,0,3,10,50,2,20,5,135,5,,,,,,,,,,,, ];
  $itemDetail{'256|6'}  = [  8,6,'Heavy Dispenser 110',6,9,0,0,0,0,5,15,70,2,30,5,136,11,,,,,,,,,,,, ];
  $itemDetail{'256|7'}  = [  8,7,'Heavy Dispenser 200',7,14,0,0,0,0,7,20,90,2,45,5,137,20,,,,,,,,,,,, ];
  $itemDetail{'256|8'}  = [  8,8,'Speed Trap 20',8,0,0,2,0,0,2,100,60,30,0,12,132,2,,,,,,,,,,,, ];
  $itemDetail{'256|9'}  = [  8,9,'Speed Trap 30',9,0,0,3,0,0,6,135,72,32,0,14,133,3,,,,,,,,,,,, ];
  $itemDetail{'256|10'}  = [  8,10,'Speed Trap 50',10,0,0,5,0,0,11,140,80,40,0,15,134,5,,,,,,,,,,,, ];
  $itemDetail{'512|1'}  = [  1,1,'Stargate 100/250',1,0,0,5,5,0,0,0,400,100,40,40,144,100,250,,,,,,,,,,, ];
  $itemDetail{'512|2'}  = [  1,2,'Stargate any/300',2,0,0,6,10,0,0,0,500,100,40,40,145,-1,300,,,,,,,,,,, ];
  $itemDetail{'512|3'}  = [  1,3,'Stargate 150/600',3,0,0,11,7,0,0,0,1000,100,40,40,146,150,600,,,,,,,,,,, ];
  $itemDetail{'512|4'}  = [  1,4,'Stargate 300/500',4,0,0,9,13,0,0,0,1200,100,40,40,147,300,500,,,,,,,,,,, ];
  $itemDetail{'512|5'}  = [  1,5,'Stargate 100/any',5,0,0,16,12,0,0,0,1400,100,40,40,148,100,-1,,,,,,,,,,, ];
  $itemDetail{'512|6'}  = [  1,6,'Stargate any/800',6,0,0,12,18,0,0,0,1400,100,40,40,149,-1,800,,,,,,,,,,, ];
  $itemDetail{'512|7'}  = [  1,7,'Stargate any/any',7,0,0,19,24,0,0,0,1600,100,40,40,150,-1,-1,,,,,,,,,,, ];
  $itemDetail{'512|8'}  = [  1,8,'Mass Driver 5',8,4,0,0,0,0,0,0,140,48,40,40,151,5,0,,,,,,,,,,, ];
  $itemDetail{'512|9'}  = [  1,9,'Mass Driver 6',9,7,0,0,0,0,0,0,288,48,40,40,152,6,0,,,,,,,,,,, ];
  $itemDetail{'512|10'}  = [  1,10,'Mass Driver 7',10,9,0,0,0,0,0,0,1024,200,200,200,153,7,0,,,,,,,,,,, ];
  $itemDetail{'512|11'}  = [  1,11,'Super Driver 8',11,11,0,0,0,0,0,0,512,48,40,40,154,8,0,,,,,,,,,,, ];
  $itemDetail{'512|12'}  = [  1,12,'Super Driver 9',12,13,0,0,0,0,0,0,648,48,40,40,155,9,0,,,,,,,,,,, ];
  $itemDetail{'512|13'}  = [  1,13,'Ultra Driver 10',13,15,0,0,0,0,0,0,1936,200,200,200,156,10,0,,,,,,,,,,, ];
  $itemDetail{'512|14'}  = [  1,14,'Ultra Driver 11',14,17,0,0,0,0,0,0,968,48,40,40,157,11,0,,,,,,,,,,, ];
  $itemDetail{'512|15'}  = [  1,15,'Ultra Driver 12',15,20,0,0,0,0,0,0,1152,48,40,40,158,12,0,,,,,,,,,,, ];
  $itemDetail{'512|16'}  = [  1,16,'Ultra Driver 13',16,24,0,0,0,0,0,0,1352,48,40,40,159,13,0,,,,,,,,,,, ];
#   $itemDetail{'5|1'}  = [  5,1,'Total Terraform 3',1,0,0,0,0,0,0,0,70,0,0,0,184,3,,,,,,,,,,,, ];
#   $itemDetail{'5|2'}  = [  5,2,'Total Terraform 5',2,0,0,0,0,0,3,0,70,0,0,0,185,5,,,,,,,,,,,, ];
#   $itemDetail{'5|3'}  = [  5,3,'Total Terraform 7',3,0,0,0,0,0,6,0,70,0,0,0,186,7,,,,,,,,,,,, ];
#   $itemDetail{'5|4'}  = [  5,4,'Total Terraform 10',4,0,0,0,0,0,9,0,70,0,0,0,187,10,,,,,,,,,,,, ];
#   $itemDetail{'5|5'}  = [  5,5,'Total Terraform 15',5,0,0,0,0,0,13,0,70,0,0,0,188,15,,,,,,,,,,,, ];
#   $itemDetail{'5|6'}  = [  5,6,'Total Terraform 20',6,0,0,0,0,0,17,0,70,0,0,0,180,20,,,,,,,,,,,, ];
#   $itemDetail{'5|7'}  = [  5,7,'Total Terraform 25',7,0,0,0,0,0,22,0,70,0,0,0,172,25,,,,,,,,,,,, ];
#   $itemDetail{'5|8'}  = [  5,8,'Total Terraform 30',8,0,0,0,0,0,25,0,70,0,0,0,164,30,,,,,,,,,,,, ];
#   $itemDetail{'5|9'}  = [  5,9,'Gravity Terraform 3',9,0,0,1,0,0,1,0,100,0,0,0,160,3,,,,,,,,,,,, ];
#   $itemDetail{'5|10'}  = [  5,10,'Gravity Terraform 7',10,0,0,5,0,0,2,0,100,0,0,0,161,7,,,,,,,,,,,, ];
#   $itemDetail{'5|11'}  = [  5,11,'Gravity Terraform 11',11,0,0,10,0,0,3,0,100,0,0,0,162,11,,,,,,,,,,,, ];
#   $itemDetail{'5|12'}  = [  5,12,'Gravity Terraform 15',12,0,0,16,0,0,4,0,100,0,0,0,163,15,,,,,,,,,,,, ];
#   $itemDetail{'5|13'}  = [  5,13,'Temp Terraform 3',13,1,0,0,0,0,1,0,100,0,0,0,168,3,,,,,,,,,,,, ];
#   $itemDetail{'5|14'}  = [  5,14,'Temp Terraform 7',14,5,0,0,0,0,2,0,100,0,0,0,169,7,,,,,,,,,,,, ];
#   $itemDetail{'5|15'}  = [  5,15,'Temp Terraform 11',15,10,0,0,0,0,3,0,100,0,0,0,170,11,,,,,,,,,,,, ];
#   $itemDetail{'5|16'}  = [  5,16,'Temp Terraform 15',16,16,0,0,0,0,4,0,100,0,0,0,171,15,,,,,,,,,,,, ];
#   $itemDetail{'5|17'}  = [  5,17,'Radiation Terraform 3',17,0,1,0,0,0,1,0,100,0,0,0,176,3,,,,,,,,,,,, ];
#   $itemDetail{'5|18'}  = [  5,18,'Radiation Terraform 7',18,0,5,0,0,0,2,0,100,0,0,0,177,7,,,,,,,,,,,, ];
#   $itemDetail{'5|19'}  = [  5,19,'Radiation Terraform 11',19,0,10,0,0,0,3,0,100,0,0,0,178,11,,,,,,,,,,,, ];
#   $itemDetail{'5|20'}  = [  5,20,'Radiation Terraform 15',20,0,16,0,0,0,4,0,100,0,0,0,179,15,,,,,,,,,,,, ];
  $itemDetail{'1024|1'}  = [  6,1,'Viewer 50',1,0,0,0,0,0,0,0,100,10,10,70,80,50,,,,,,,,,,,, ];
  $itemDetail{'1024|2'}  = [  6,2,'Viewer 90',2,0,0,0,0,1,0,0,100,10,10,70,81,90,,,,,,,,,,,, ];
  $itemDetail{'1024|3'}  = [  6,3,'Scoper 150',3,0,0,0,0,3,0,0,100,10,10,70,82,150,,,,,,,,,,,, ];
  $itemDetail{'1024|4'}  = [  6,4,'Scoper 220',4,0,0,0,0,6,0,0,100,10,10,70,83,220,,,,,,,,,,,, ];
  $itemDetail{'1024|5'}  = [  6,5,'Scoper 280',5,0,0,0,0,8,0,0,100,10,10,70,90,280,,,,,,,,,,,, ];
  $itemDetail{'1024|6'}  = [  6,6,'Snooper 320',6,3,0,0,0,10,3,0,100,10,10,70,84,-320,,,,,,,,,,,, ];
  $itemDetail{'1024|7'}  = [  6,7,'Snooper 400',7,4,0,0,0,13,6,0,100,10,10,70,85,-400,,,,,,,,,,,, ];
  $itemDetail{'1024|8'}  = [  6,8,'Snooper 500',8,5,0,0,0,16,7,0,100,10,10,70,86,-500,,,,,,,,,,,, ];
  $itemDetail{'1024|9'}  = [  6,9,'Snooper 620',9,7,0,0,0,23,9,0,100,10,10,70,91,-620,,,,,,,,,,,, ];
  $itemDetail{'1024|10'}  = [  6,10,'SDI',10,0,0,0,0,0,0,0,15,5,5,5,72,10,,,,,,,,,,,, ];
  $itemDetail{'1024|11'}  = [  6,11,'Missile Battery',11,5,0,0,0,0,0,0,15,5,5,5,73,20,,,,,,,,,,,, ];
  $itemDetail{'1024|12'}  = [  6,12,'Laser Battery',12,10,0,0,0,0,0,0,15,5,5,5,74,24,,,,,,,,,,,, ];
  $itemDetail{'1024|13'}  = [  6,13,'Planetary Shield',13,16,0,0,0,0,0,0,15,5,5,5,75,30,,,,,,,,,,,, ];
  $itemDetail{'1024|14'}  = [  6,14,'Neutron Shield',14,23,0,0,0,0,0,0,15,5,5,5,76,38,,,,,,,,,,,, ];
  $itemDetail{'1024|15'}  = [  6,15,'Genesis Device',15,20,10,10,20,10,20,0,5000,0,0,0,175,0,,,,,,,,,,,, ];
  $itemDetail{'2048|1'}  = [  10,1,'Transport Cloaking',1,0,0,0,0,0,0,1,3,2,0,2,98,300,,,,,,,,,,,, ];
  $itemDetail{'2048|2'}  = [  10,2,'Stealth Cloak',2,2,0,0,0,5,0,2,5,2,0,2,99,70,,,,,,,,,,,, ];
  $itemDetail{'2048|3'}  = [  10,3,'Super-Stealth Cloak',3,4,0,0,0,10,0,3,15,8,0,8,100,140,,,,,,,,,,,, ];
  $itemDetail{'2048|4'}  = [  10,4,'Ultra-Stealth Cloak',4,10,0,0,0,12,0,5,25,10,0,10,101,540,,,,,,,,,,,, ];
  $itemDetail{'2048|5'}  = [  10,5,'Multi Function Pod',5,11,0,11,0,11,0,2,15,5,0,5,189,60,,,,,,,,,,,, ];
  $itemDetail{'2048|6'}  = [  10,6,'Battle Computer',6,0,0,0,0,0,0,1,6,0,0,15,165,20,,,,,,,,,,,, ];
  $itemDetail{'2048|7'}  = [  10,7,'Battle Super Computer',7,5,0,0,0,11,0,1,14,0,0,25,166,30,,,,,,,,,,,, ];
  $itemDetail{'2048|8'}  = [  10,8,'Battle Nexus',8,10,0,0,0,19,0,1,15,0,0,30,167,50,,,,,,,,,,,, ];
  $itemDetail{'2048|9'}  = [  10,9,'Jammer 10',9,2,0,0,0,6,0,1,6,0,0,2,120,10,,,,,,,,,,,, ];
  $itemDetail{'2048|10'}  = [  10,10,'Jammer 20',10,4,0,0,0,10,0,1,20,1,0,5,121,20,,,,,,,,,,,, ];
  $itemDetail{'2048|11'}  = [  10,11,'Jammer 30',11,8,0,0,0,16,0,1,20,1,0,6,122,30,,,,,,,,,,,, ];
  $itemDetail{'2048|12'}  = [  10,12,'Jammer 50',12,16,0,0,0,22,0,1,20,2,0,7,123,50,,,,,,,,,,,, ];
  $itemDetail{'2048|13'}  = [  10,13,'Energy Capacitor',13,7,0,0,0,4,0,1,5,0,0,8,127,10,,,,,,,,,,,, ];
  $itemDetail{'2048|14'}  = [  10,14,'Flux Capacitor',14,14,0,0,0,8,0,1,5,0,0,8,190,20,,,,,,,,,,,, ];
  $itemDetail{'2048|15'}  = [  10,15,'Energy Dampener',15,14,0,8,0,0,0,2,50,5,10,0,124,1,,,,,,,,,,,, ];
  $itemDetail{'2048|16'}  = [  10,16,'Tachyon Detector',16,8,0,0,0,14,0,1,70,1,5,0,125,2,,,,,,,,,,,, ];
  $itemDetail{'2048|17'}  = [  10,17,'Anti-matter Generator',17,0,12,0,0,0,7,10,10,8,3,3,126,3,,,,,,,,,,,, ];
  $itemDetail{'4096|1'}  = [  9,1,'Colonization Module',1,0,0,0,0,0,0,32,10,12,10,10,106,1,,,,,,,,,,,, ];
  $itemDetail{'4096|2'}  = [  9,2,'Orbital Construction Module',2,0,0,0,0,0,0,50,20,20,15,15,107,1,,,,,,,,,,,, ];
  $itemDetail{'4096|3'}  = [  9,3,'Cargo Pod',3,0,0,0,3,0,0,5,10,5,0,2,96,2,,,,,,,,,,,, ];
  $itemDetail{'4096|4'}  = [  9,4,'Super Cargo Pod',4,3,0,0,9,0,0,7,15,8,0,2,97,2,,,,,,,,,,,, ];
  $itemDetail{'4096|5'}  = [  9,5,'Multi Cargo Pod',5,5,0,0,11,5,0,9,25,12,0,3,118,2,,,,,,,,,,,, ];
  $itemDetail{'4096|6'}  = [  9,6,'Fuel Tank',6,0,0,0,0,0,0,3,4,6,0,0,104,4,,,,,,,,,,,, ];
  $itemDetail{'4096|7'}  = [  9,7,'Super Fuel Tank',7,6,0,4,14,0,0,8,8,8,0,0,105,4,,,,,,,,,,,, ];
  $itemDetail{'4096|8'}  = [  9,8,'Maneuvering Jet',8,2,0,3,0,0,0,5,10,5,0,5,102,1,,,,,,,,,,,, ];
  $itemDetail{'4096|9'}  = [  9,9,'Overthruster',9,5,0,12,0,0,0,5,20,10,0,8,103,2,,,,,,,,,,,, ];
  $itemDetail{'4096|10'}  = [  9,10,'Jump Gate',10,16,0,20,20,16,0,10,40,0,0,50,208,0,,,,,,,,,,,, ];
  $itemDetail{'4096|11'}  = [  9,11,'Beam Deflector',11,6,6,0,6,6,0,1,8,0,0,10,209,10,,,,,,,,,,,, ];
  return %itemDetail;
}

sub getMask {
# Return true if the associated bit is set for the number
  my ($number, $position) = @_;
  my $new_num = $number >> ( $position ); 
    # if it results to '1' then bit is set, 
    # else it results to '0' bit is unset 
  my $check = $new_num &1;
  return ($check); 
} 

sub BlockLogOut {
	my($Logging, $PrintString, $LogFile) = (@_);
  # Get Date information to set up logs to roll over weekly
  my $CurrentEpoch = time();
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($CurrentEpoch); 
	my $Month = $WrongMonth + 1; 
	my $Year = $WrongYear + 1900;
  if ($DayofMonth <=7) { $WeekofMonth = 1;}
	elsif ($DayofMonth >7 && $DayofMonth <=14) { $WeekofMonth = 2;}
	elsif ($DayofMonth >14 && $DayofMonth <=21) { $WeekofMonth = 3;}
	elsif ($DayofMonth >21 && $DayofMonth <=28) { $WeekofMonth = 4;}
	elsif ($DayofMonth >28 && $DayofMonth <=31) { $WeekofMonth = 5;}

  my $LogFileDate = $LogFile . '.' . $Year . '.' . $Month . '.' . $WeekofMonth; 
	if ($Logging <= $logging) { 
    if ($LogFile) {
  		$PrintString = localtime(time()) . " : " . $Logging . " : " . $PrintString;
  		open (LOGFILE, ">>$LogFileDate");
  		print LOGFILE "$PrintString\n\n";
  		close LOGFILE;
    } else { print $PrintString . "\n"; }
	}
}

sub unshiftBytes {
  # Display the byte information without decrypting, a variation on &decryptBytes
  # Needed to display Block 8 & 0 in decimal so I can treat it like everything else.
  # Not decrypted, just unshifted from Binary
  my ($shiftedBytes) = @_;
  my @shiftedBytes = @{ $shiftedBytes }; 
  my $size = @shiftedBytes;
  my @unshiftedBytes; 
  my $padding;
  # Add padding to 4 bytes
  ($shiftedBytes, $padding) = &addPadding (\@shiftedBytes);
  @shiftedBytes = @ {$shiftedBytes };
  my $paddedSize = $size + $padding;
  # Now decrypt, processing 4 bytes at a time
  @unshiftedBytes = ();
  for (my $i = 0; $i <  $paddedSize; $i+=4) {
    # Swap bytes using indexes in this order:  4 3 2 1
    my $chunk =  (
        (ord($shiftedBytes[$i+3]) << 24) | 
        (ord($shiftedBytes[$i+2]) << 16) | 
        (ord($shiftedBytes[$i+1]) << 8)  | 
         ord($shiftedBytes[$i])
    );
    # Write out the decrypted data, swapped back
    my $unshiftedBytes = $chunk     & 0xFF;
    push @unshiftedBytes, $unshiftedBytes;
    $unshiftedBytes = ($chunk >> 8) & 0xFF;
    push @unshiftedBytes, $unshiftedBytes;
    $unshiftedBytes = ($chunk >> 16) & 0xFF;
    push @unshiftedBytes, $unshiftedBytes;
    $unshiftedBytes = ($chunk >> 24) & 0xFF;
    push @unshiftedBytes, $unshiftedBytes;
  }    
  # Strip off any padding
  @unshiftedBytes = &stripPadding(\@unshiftedBytes, $padding);
  return \@unshiftedBytes;
}   

sub shiftBytes {
  # Shift data unshifted from binary back to binary
  # The equivalent of encrypting on unencrypted data
  my ($unshiftedBytes) = @_; 
  my @unshiftedBytes = @{ $unshiftedBytes };
  my @shiftedBytes;
  my $size = @unshiftedBytes;
  my $padding;
  # Add padding to 4 bytes
  ($unshiftedBytes, $padding) = &addPadding(\@unshiftedBytes);
  @unshiftedBytes = @ {$unshiftedBytes };
  my $paddedSize = $size + $padding;
  # Now shift, processing 4 bytes at a time
  for(my $i = 0; $i <$paddedSize; $i+=4) {
    # Swap bytes:  4 3 2 1
    my $chunk = (
          ($unshiftedBytes[$i+3] << 24) | 
          ($unshiftedBytes[$i+2] << 16) | 
          ($unshiftedBytes[$i+1] << 8)  | 
           $unshiftedBytes[$i]
    );
    # Write out the shifted data, swapped back
    my $shiftedBytes = chr($chunk      & 0xFF);
    push @shiftedBytes, $shiftedBytes;
    $shiftedBytes = chr(($chunk >> 8)  & 0xFF);
    push @shiftedBytes, $shiftedBytes;
    $shiftedBytes = chr(($chunk >> 16) & 0xFF);
    push @shiftedBytes, $shiftedBytes;
    $shiftedBytes = chr(($chunk >> 24) & 0xFF);
    push @shiftedBytes, $shiftedBytes;
  }
  # Strip off any padding
  @shiftedBytes = &stripPadding(\@shiftedBytes, $padding);
  return \@shiftedBytes;
} 

sub raceCheckSum {  # calculate a race checksum
  # The race checksum is calculated from the array of decrypted data of Block 6
  #  without the singular/plural race name data
  # The singular and plural race names are recalculated as ord arrays, 
  #  and each padded to 15 characters
  # Then the data arrray has added to it:
  # + 0 0    (to replace the race name size fields I suspect) 
  # + the 1st two ord from the singular name, and the 1st two ord from the plural
  # + the 2nd two ord from singular, and 2nd two ord from plural
  # ...
  # the 1st checksum byte is the XOR of the even data bytes
  # the 2nd checksum byte is the XOR of the odd data bytes
  
  my ($decryptedData, $singularRaceName, $pluralRaceName, $singularNameLength, $pluralNameLength) = @_;
  my @decryptedData = @{ $decryptedData };
  my ($checkSum1, $checkSum2) = (0,0);
  my $datalength = scalar @decryptedData - (1 + $singularNameLength + 1 + $pluralNameLength + 1);
  my @dData = @decryptedData[0..$datalength];
  # get the ascii values of the Race names - singular
  my @singularRaceNameOrd = unpack("C*", $singularRaceName); #array of ascii values
  unshift (@singularRaceNameOrd, 0); # add a starting 0
  for (my $i = scalar @singularRaceNameOrd; $i <= 15; $i++) {
   push (@singularRaceNameOrd, 0); # Pad out the array
  }
  my @pluralRaceNameOrd = unpack("C*", $pluralRaceName); #array of ascii values
  unshift (@pluralRaceNameOrd, 0); # add a starting 0
  for (my $i = scalar @pluralRaceNameOrd; $i <= 15; $i++) {
    push (@pluralRaceNameOrd, 0); # Pad out the array
  }
  for (my $i=0; $i <= 15 ; $i=$i+2) { # add ords to the array in pairs (as we do odd/even)
    push (@dData, $singularRaceNameOrd[$i]);
    push (@dData, $singularRaceNameOrd[$i+1]);
    push (@dData, $pluralRaceNameOrd[$i]);
    push (@dData, $pluralRaceNameOrd[$i+1]);
  }
  for (my $i = 0; $i < scalar @dData; $i=$i+2) {
    $checkSum1 = $checkSum1^int($dData[$i]);  # Force numification
  }
  # Checksum 2: Odd bytes
  for (my $i = 1; $i < scalar @dData; $i=$i+2) {
    $checkSum2 = $checkSum2^int($dData[$i]); # Force numification
  }
  return $checkSum1, $checkSum2;
} 

sub checkRaceCorrupt {
  my ($filename) = @_;
  my $FileValues;
  my @fileBytes;
  open(StarFile, "<$filename");
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ( $seedA, $seedB );
  my ( $typeId, $size );
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
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      # If this is a race file, validate the checksum

      unless ($unshiftedData[0] == $checkSum1 && $unshiftedData[1] == $checkSum2 ) {
        return 1;   # This race file is corrupt
      } else {
        return 0; # This race file is not corrupt
      }
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        $playerId = $decryptedData[0] & 0xFF; # Always 255 in a race file
        my $fullDataFlag = ($decryptedData[6] & 0x04); 
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
        my $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
        if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
         # Calculate the race checksums
        ($checkSum1, $checkSum2) = &raceCheckSum(\@decryptedData, $singularRaceName[$playerId], $pluralRaceName[$playerId], $singularNameLength, $pluralNameLength);
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
}

sub checkSerials {
  # Check a Stars Block and return results of analysis. 
  # Currently only for the .x Block 9 serial/hardware hash 
  # Stand-alone code is in StarsSecure.pl
  
  my ($inFile) = @_;   # The uploaded file
  use File::Basename;  # Used to get filename components
  $inFile = basename($inFile);  # The uploaded file name sans path (IE6 fix). 
  ($file_prefix, $file_player, $file_type, $file_ext) = &FileData ($inFile); # The filename as component parts  
  my $uploadFile = $Dir_Upload . '/' . $inFile; # The uploaded .x file w/ path
  my $inDir = "$Dir_Games/$file_prefix"; # The game directory
  my %block9;
  my @block9data; # block 9 data from of a single .x file
  my $err;  
  my $FileValues='';
  my @fileBytes=();

  # get the block9 information for the uploaded file
  open(StarFile, "<$uploadFile" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  # Decrypt the data, block by block, to get the Block 9 serial and hardware hash
  @block9data = &decryptSerials(@fileBytes);
  $block9{$inFile} = [@block9data]; # store array in a hash
   
  # Read game uploaded .x files and  add block 9 data+
  opendir(DIR, $inDir); 
  while (defined(my $file = readdir(DIR))) {  
    my $filename =  $Dir_Games .'/' . $file_prefix . '/' . $file;
    next unless ($file =~ /^(\w+[\w.-]+\.[xX]\d{1,2})$/); # skip unless it's a .x[n] file
    # BUG: index might be better here than regexp?
    if ($inFile =~ /$file/i) { next; } # Skip if .x file present/uploaded previously 

    # Read in the file
    @fileBytes=();
    open(StarFile, "<$filename" );
    binmode(StarFile);
    while ( read(StarFile, $FileValues, 1)) {
      push @fileBytes, $FileValues; 
    }
    close(StarFile);
    # Decrypt the data, block by block, to get the serial and hardware hash
    @block9data = &decryptSerials(@fileBytes);
    $block9{$file} = [@block9data]; # store array in a hash
  }
  closedir(DIR);

  # Loop through the .x files for comparison
  $file1 = $inFile;
#    # Check it against all the files in the array
    foreach my $file2 ( sort keys %block9 ) {
      if ($file1 eq $file2) { next; } # if it's the same file then skip it
      # Check to see if the serial numbers are the same
      if (@{$block9{$file1}}[0] eq @{$block9{$file2}}[0]) {
        # If the serial numbers are the same, the hardware hashes must be the same
        if (@{$block9{$file1}}[1] eq @{$block9{$file2}}[1]) {
          # If the serial and hardware hash are the same, it's ok, but the two players 
          # are on the same PC. 
          #$err .= "<P>Info   : " . uc($file1) . " same serial/hardware hash as " . uc($file2). ",";
        } else {
          # Different computer, same serial. Problem. 
          $err .= uc($file1) . ' same serial as ' . uc($file2) . ' but different hardware hash,'; 
        }
      } 
    } 
  # If any results were reported, return them.
  return $err;
}

sub decryptSerials {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $padding);
  my @decryptedData;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($seedA, $seedB);
  my ($FileValues, $typeId, $size);
  my $offset = 0; #Start at the beginning of the file
  my ($hardware, $serial);
  
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    # BUG 211101: I could increase performance by not defining @data AND @block
    #    true across all the copies of this function
    # shift'ing it twice would do it I think. 
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 8) { # File Header Block, never encrypted
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 9) {
        $serial = &read32(\@decryptedData, 2);  # serial number, blocks 2-5
        $hardware = pack("C*", @decryptedData[6..16]); #get the hardware hash as a string
        return ($serial, $hardware); # might as well stop immediately
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
}

sub readList {
  my ($File) = @_;
  my %List;
  # Read in the file data
  my @File;
  open (LISTFILE,$File) || &BlockLogOut(0," readFleetList: cannot open $File", $ErrorLog);
  @File = <LISTFILE>;
  close LISTFILE;
  # Turn the file into a usable array
  my $counter = 0;
  my @keys;
  my %list;
  foreach my $line (@File) {
    chomp($line); # remove the CR
    my @values = split (',', $line);
    if ($counter == 0) { @keys = @values; $counter++; next; } # Read the header line and then move on
    # Auto assign keys from the header line
    foreach my $key ( @keys ) {
      my $value = shift @values;
      $list{$key} = $value;
    }
    $List{$list{playerId}}{$list{id}} =  { %list };
  }
  return { %List };
}

sub writeList {
  ($File, $List) = @_;
  my %List = %$List;
  open (LISTFILE, ">$File");

  # Content 
  my $count = 0;
  foreach my $i (sort keys %List) {
  	foreach my $j (sort keys %{$List{$i}}) {
      my $string = '';
      my $header = '';
    	foreach my $k (sort keys %{$List{$i}{$j}}) {
        $string .= $List{$i}{$j}{$k} . ',';
        $header .= $k . ',';
      }
      chop $string; # remove trailing comma
      chop $header; # remove trailing comma
      if ($count == 0 ) { print LISTFILE "$header\n"; $count = 1; } # Print the header on the first pass
      if ($string) { 
        print LISTFILE "$string\n"; 
      }  # because we end up with blank strings here in the output. 
    }
  }
  close LISTFILE;
  umask 0002; 
  chmod 0664, $File;
}

#print List hash
sub printList {  
  my ($List) = @_;
  my %List = %$List;
  foreach my $i (sort keys %List) {
    foreach my $j (sort keys %{$List{$i}}) {  
      foreach my $k (sort keys %{$List{$i}{$j}}) {
        if ($i == 15) {  
          printf("%-40s", "Player $i, id $j, $k: ");
          if ($List{$i}{$j}{$k} =~ /[\x1F]/) {  # chr(31)
            my @s = split (chr(31), $List{$i}{$j}{$k});
            my $string='';
            $string = join (',', @s); 
            print "$string";
          } 
          else {
            print "$List{$i}{$j}{$k}";
          }
          print "\n";
        }
      }
      print "\n";
    }
  }
}

sub updateList { # Update the list data for a game
  my ($GameFile, $enable) = @_;
  # Enable/disable List functionality for fix
  # Remove the old List files, as they may be out of date
  # unlink qq|$Dir_Games/$GameFile/$GameFile.warnings|; 
  my @extensions = qw ( design queue fleet waypoint last ); 
  if (!($enable)) { # Remove the fix file
    my $fixfile = qq|$Dir_Games/$GameFile/fix|; 
    if (-f $fixfile) {  unlink $fixfile; } 
  # StarsList cleans up the files otherwise
    foreach my $extension (@extensions) {
      my $extension = qq|$Dir_Games/$GameFile/$GameFile.hst.$extension|; 
      if (-f extension) { unlink $extension; } 
    }
  } 
  else { # We need to create both the fix file, and the List files
    if ($fixFiles && -f "$Dir+Games/$GameFile/fix") { 
      &StarsList("$Dir_Games/$GameFile", "$Dir_Games/$GameFile/$GameFile.hst"); 
    }
  }
}

sub cleanFiles {
  my ($GameFile) = @_;
  # Clean the .m files
  # Works on a folder-by-folder game-by-game basis. 
  # Requires a file named 'clean' in the game folder
  # $cleanFiles is set in config.pl
  if ($cleanFiles && -f "$Dir+Games/$GameFile/clean") {
    &StarsClean($GameFile); 
    &BlockLogOut(50, "Cleaned .m Files for $GameFile", $LogFile);
  }
}

sub tallyFleet {
  #recalculate the capacities of a fleet after composition changes
  my ($ownerId, $shipCount, $shipDesigns) = @_; # Expects $shipDesigns in decimal
  my $cargoCapacity = 0; 
  my $fuelCapacity = 0; 
  my $robberBaron = 0; 
  my $mass = 0;
  my @shipCount = split (chr(31), $shipCount);
  for (my $bit = 0; $bit <= 15; $bit++) {
    if ($shipDesigns & (1 << $bit) ) { # If there's a design in this slot, decimal value. 
        $cargoCapacity += $designList{$ownerId}{$bit}{cargoCapacity} * $shipCount[$bit];
        $fuelCapacity  += $designList{$ownerId}{$bit}{fuelCapacity} * $shipCount[$bit];
        if ($designList{$ownerId}{$bit}{robberBaron} == 1) { $robberBaron = 1; }
        $mass          += $designList{$ownerId}{$bit}{mass} * $shipCount[$bit];
    }
  }
  return $cargoCapacity, $fuelCapacity, $robberBaron, $mass;
}

sub adjustFleetCargo { # 
  #adjust fleet cargo when two fleets merge
  my ($ownerId, $id, $cargoLoad, $GameDirection) = @_;
  my @cargoLoad = split(chr(31), $cargoLoad);
  my @cargo = split(chr(31), $fleetList{$ownerId}{$id}{cargo});
  my $mass  = $fleetList{$ownerId}{$id}{mass};
  
  for (my $k=0; $k<=4; $k++) { # fuel isn't in mass or cargo
    $cargo[$k] = $cargo[$k] + ($cargoLoad[$k]*$GameDirection);
    if ($k != 4) { $mass += $cargoLoad[$k]*$GameDirection; } # Don't add fuel to mass
    if ($cargo[$k] < 0) { $cargo[$k] = 0; } # Fix for rounding error issues
  }
  $fleetList{$ownerId}{$id}{mass}  = $mass;
  $fleetList{$ownerId}{$id}{cargo} = join(chr(31), @cargo);
}

sub decryptFix {
  # Exploit check .hst and .x files
  # $filename needs to be the full file path and name of file checked
  #   so we know what file_type we're checking (.x, .m, or .hst)
  # BUG: NOT TRUE Directory and file name are split as TH .x files are in a different place than the .hst files
  #   when they are scanned
  my ($gameDir, $filename, $fileBytes, $fleetList, $queueList, $designList, $waypointList, $lastPlayer) = @_;
  @fileBytes = @$fileBytes;
  %fleetList  = %$fleetList;
  %queueList  = %$queueList;
  %designList = %$designList;
  %waypointList = %$waypointList;
  
  # Get the pieces of file names
  my $basefile = basename($filename);    # mygamename.m1
  my ($gameName, $file_player, $file_type, $file_ext) = &FileData ($basefile); # The filename as component parts  
  my $listPrefix = "$gameDir/$gameName";   #d:\th\games\gamename. Suffix added as appropriate
  
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $lastTurn;
  my $skipTurns = 0;
  my $offset = 0; #Start at the beginning of the file
  my $needsFixing = 0; # Exploit or bug detected
  my %totalUpload; # total uploaded to a fleet for Mineral upload exploit.
  my ($planetId, $ownerId, $playerId, $fleetId);    
  my $designShipTotal = 0;
  my $designBaseTotal = 0;
  my $designShipCounter = 0;
  my $designBaseCounter = 0;
  my $designShipTotalCounter = 0;
  my $designBaseTotalCounter = 0;
  my $designShipPlayerId = 0;
  my $designBasePlayerId = 0;
  my $designOwner = 0;
  my @designChanges; # used to track which starbase designs have been edited for cheap starbase
  # Tracking owner of the current design
  my %player;
  my $warnId='';
  my %hullType = &readHullType;
  my %itemDetail = &readItemDetail();
  #while ( my ($key, $value) = each(%itemDetail ) ) { print "$key => $value\n"; }

  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset]; # invert the pair of header bytes
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    # Skip over the duplicate information in a turn file which include multiple turns
#     if ( $skipTurns && $typeId != 8 ) {
#       $offset = $offset + (2 + $size); 
#       print "SKIP: TypeId: $typeId\n";
#       next;
#    } elsif ($typeId == 8 ) { # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block, never encrypted
#       if ( $skipTurns ) { $skipTurns--; }
#       if ( $skipTurns ) { next; }

      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      # This turn has multiple turns, so let's skip forward and decrypt only the last turn
#       if ( $fMulti ) {  # fMulti is set only on the first Block 8 
#          $lastTurn = &getFileFooter(@fileBytes);
#          $skipTurns = $lastTurn - $turn;
#          print "TURN: $turn, last: $lastTurn, SKIP: $skipTurns\n";
#          $offset = $offset + (2 + $size); 
#          next;
#       }
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } else {       # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
#       # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block. .m files can contain multiple players. Only enough info for Fix. More elsewhere.
        my $playerId = $decryptedData[0] & 0xFF; # typically >> 1
        my $shipDesigns = $decryptedData[1] & 0xFF;  
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); 
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); 
        $player{$playerId}{shipDesigns} = $shipDesigns;
        $player{$playerId}{planets} = $planets;
        $player{$playerId}{fleets} = $fleets;
        $player{$playerId}{starbaseDesigns} = $starbaseDesigns;
        $designShipTotal +=  $player{$playerId}{shipDesigns}; # Total across all players
        $designBaseTotal +=  $player{$playerId}{starbaseDesigns}; # Total across all players
        $lastPlayer = $playerId; # keep track of the largest known player Id (always in order). Not in .x files
      } elsif ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .m and .hst file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        #$planetId = &read16(@decryptedData, 0) & 0x7FF;  // 11 Bits to match other blocks
        $playerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($playerId == 31) { $playerId = -1; }
        my $flags = &read16(\@decryptedData, 2);
        my $isHomeworld = ($flags & 0x80) != 0;
	      my $isInUseOrRobberBaron = ($flags & 0x04) != 0;
	      my $hasEnvironmentInfo = ($flags & 0x02) != 0;
	      my $bitWhichIsOffForRemoteMiningAndRobberBaron = ($flags & 0x01) != 0;
	      my $weirdBit = ($flags & 0x8000) != 0;
	      my $hasRoute = ($flags & 0x4000) != 0;
	      my $hasSurfaceMinerals = ($flags & 0x2000) != 0;
	      my $hasArtifact = ($flags & 0x1000) != 0;
	      my $hasInstallations = ($flags & 0x0800) != 0;
	      my $isTerraformed = ($flags & 0x0400) != 0;
	      my $hasStarbase = ($flags & 0x0200) != 0;
        # More in the block I don't care about right now.       
      } 
      elsif ( $typeId == 3 ) { # waypoint delete block
        my $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        my $playerId = $decryptedData[1] >> 1;
        my $wayPointId = ($decryptedData[2]& 0xFF);   
        my $id = $fleetId . '+' . $wayPointId;
        
        # delete the waypoint
        if (exists ( $waypointList{$playerId}{$id}) ) { delete $waypointList{$playerId}{$id}; }
        
        ### SS Pop Steal ####################################################### 
        # Clear SS Pop Steal if it was an issue but waypoint now deleted.
        my $warnId = &zerofy($playerId) . '-popsteal-' . $fleetId . '+' . $wayPointId; # adding a zero lets us sort on key
        if (exists ($warning{$warnId})) { delete $warning{$warnId}; $needsFixing--; }
        ########################################################################
        
        ### 32k Merge ##########################################################
        # Clear 32k if it was an issue but waypoint now deleted.
        $warnId = &zerofy($playerId) . '-32k-' . $fleetId . '+' . $wayPointId; # adding a zero lets us sort on key
        if (exists ($warning{$warnId})) { delete $warning{$warnId}; $needsFixing--; }
        ########################################################################
      } 
      elsif ( $typeId == 4 || $typeId == 5 ) { # waypoint block (add/change) in .x files 
        # If there is a block 5, it will follow block 4
        # SS Pop Steal exploit, 32k merge bug
        # Part of the detection of the minefield 0-coordinate bug, but 
        # the fleet block isn't mapped well-enough for me to figure out coordinates easily
        #   for the minefield bugs.
        # Detect ships moving pure east/west or pure north/south
        # THIS WOULD HAVE BEEN LESS WORK IF I'D KNOWN minefield x/y WAS FIXED IN JRC4
        my $waypointId;
        my $xDest;
        my $yDest;
        my $targetId;
        my $targetIdType;
        my $warp;
        my $taskId;
        my $targetType;
        my $unknownBitsWithTargetType;
        my ($ironium, $boranium, $germanium, $population, $fuel) = (0) x 5;
        my ($taskIronium, $taskBoranium, $taskGermanium,$taskPopulation, $taskFuel) = (0) x 5;
        
        my @showTaskId = ('no task', 'Transport', 'Colonize', 'Remote Mining', 'Merge with Fleet', 'Scrap Fleet', 'Lay Minefield', 'Patrol', 'Route', 'Transfer Fleet');
        my @showTargetIdType = ( 'Unknown', 'Planet', 'Fleet', 'Deep Space', 'Salvage/Packet/MT'); 
        my @showTransportTask = ('no action','Load All Available','Unload All','Load Exactly','UnLoad Exactly','Fill Up to %','Wait For %','Load Optimal/Dunnage','Set Amount To','Set Waypoint To'); # Optimal is Fuel, Dunnage is other things
        my @showLayMinefield = ( '1 year', '2 years', '3 years', '4 years', '5 years', 'indefinitely');
        my @showPatrolWarp = qw( auto 1 2 3 4 5 6 7 8 9 10 ); 
        my @showPatrolIntercept = ( '50 ly','100 ly','150 ly','200 ly','250 ly','300 ly','350 ly','400 ly','450 ly','500 ly','550 ly','any enemy');
        my %waypoint; # to store waypoints in a hash
        my $transferId;
        my $err;
        # Setting destination task adds a change (so a Task 4 & Task 5)
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $playerId = $decryptedData[1] >> 1;
#         my $positionObjectId = &read16(\@decryptedData, 2);
        $waypointId = &read16(\@decryptedData, 2); # separate for each fleet.
			  $xDest = &read16(\@decryptedData, 4);  
        #$toIdType = $decryptedData[4] >> 4;  # left 4 bits    #unknown(0), planet(1), fleet(2), space(4), salvage/packet/MT(8)  
        #$fromIdType =  ($decryptedData[4] >> 0) & 0xF;  # right 4 bits 
#         my $unknownBitsWithWarp = $decryptedData[6] & 0x0F;
        $yDest = &read16(\@decryptedData, 6);  
#         my $positionObjectType = $decryptedData[7] & 0xFF;
        $targetId = ($decryptedData[8] & 0xFF) + (($decryptedData[9] & 1) << 8);  # ID for destination like Fleet Merge, 511 is current location
        $targetIdType = $decryptedData[9] >> 1; #BUG: Almost certainly incorrect bits
        $warp = $decryptedData[10] >> 4; # left 4 bits
        $taskId = $decryptedData[10] & 0x0F; # right 4 bits
        $targetType = ($decryptedData[11]& 0xFF) % 16; #0-Unknown, 1-planet, 2-fleet, 4-deep space, 8-wormhole/trader/minefield/salvage
		    $unknownBitsWithTargetType = ($decryptedData[11]& 0xFF) >> 4; # left 4 bits
        if ($targetId == 511) { $targetId = 'self'; }
        # Subtasks
        # Bytes 12+ are specific waypoint task data.
        if ($taskId == 1 && $size > 12) { # Transport   ( max value 4000 in GUI )
          # Cargo is: ironium, boranium, germanium, pop, fuel
          # "Additional" empty cargo types won't be present
          # If there's only fuel, for example, you'll have all cargo types as 0
          # If there's only boranium, there will be 0s for iron and then only boranium
          # $taskX follows @showTransportTask
          # There's a Stars "bug" here that the bit for the amount doesn't reset when the task changes, 
          my $index = 12;
            if (exists ($decryptedData[$index+1])) {
              $taskIronium = ($decryptedData[$index+1] >> 4 ); # left 4 bits  I think $decryptedData[$index+1] >> 4 & 0xF is the same
              $ironium    = (($decryptedData[$index+1] & 0x0F) << 8) + $decryptedData[$index]; 
            }
          # The right-most 4 bits of $decrypted[index+1] shifted to in front of $decrypted[$index]; 
          $index=$index+2; 
          if (exists($decryptedData[$index])) {
            if (exists ($decryptedData[$index+1])) {
              $taskBoranium = ($decryptedData[$index+1] >> 4); # left 4 bits 
              $boranium    = (($decryptedData[$index+1] & 0x0F) << 8) + $decryptedData[$index]; 
            }
            $index=$index+2; 
          }
          if (exists($decryptedData[$index])) {
            if (exists ($decryptedData[$index+1])) {
              $taskGermanium = ($decryptedData[$index+1] >> 4); # left 4 bits
              $germanium    = (($decryptedData[$index+1] & 0x0F) << 8) + $decryptedData[$index]; 
            }
            $index=$index+2; 
          }
          if (exists($decryptedData[$index])) {
            if (exists ($decryptedData[$index+1])) {
              $taskPopulation = ($decryptedData[$index+1] >> 4);  # left 4 bits
              $population    = (($decryptedData[$index+1] & 0x0F) << 8) + $decryptedData[$index]; 
            }
            $index=$index+2;
          } 
          if (exists($decryptedData[$index])) {
            if (exists ($decryptedData[$index+1])) {
              $taskFuel = ($decryptedData[$index+1] >> 4); # left 4 bits
              $fuel    = (($decryptedData[$index+1] & 0x0F) << 8) + $decryptedData[$index]; 
            }
          } 
        } 
        elsif ($taskId == 2) { # Colonize
          # There are no additional bytes for a Colonize order
        }
        elsif ($taskId == 3) { # Remote Mining
          # There are no additional bytes for a Mining order
        }
        elsif ($taskId == 4) { # Merge with Fleet
          # There are no additional bytes for a Merge order
        }
        elsif ($taskId == 5) { # Scrap Fleet
          # There are no additional bytes for a Scrap order
        }
        elsif ($taskId == 6) { #Lay Minefield 
          my @mineDuration = ( '1 Year', '2 Years', '3 Years', '4 Years', '5 Years', 'Infinite' );
          my $mineDuration = 0;
          my @mineTarget = ('Unknown','Planet','Fleet',3, 'Deep Space',5,6,7,'Object'); # Wormhole, Minefield, MT, Packet(?)
          my $mineTarget;
          #my $mineTarget = ($decryptedData[11]& 0xFF) % 16; #0-Unknown, 1-planet, 2-fleet, 4-deep space, 8-wormhole/trader/minefield/salvage
          $mineTarget = $decryptedData[11] & 0x0F; # right 4
          # If no values are set (the defaults) bytes 12-14 absent
          if (exists $decryptedData[12]) {
            $mineDuration = $decryptedData[12];
          } 
          #my $unk = $decryptedData[13]; # Always 0. Only exists if not "1 Year"
          #my $unk = $decryptedData[14]; # Always the same as byte 12. Only exists if not "1 Year"
        }
        elsif ($taskId == 7) { #Patrol
          # If no values are set (the defaults) there are no additional bytes added
          my ($patrolIntercept, $patrolWarp);
          if ($decryptedData[12]) { $patrolWarp = $decryptedData[12] } else { $patrolWarp = 0; }
          # bit 13 appears to always be 0
          if ($decryptedData[14]) { $patrolIntercept = $decryptedData[14] } else { $patrolIntercept = 0; }
        }
        elsif ($taskId == 8) { # Route Fleet
          # There are no additional bytes for a Route order
        }
        elsif ($taskId == 9) { # Transfer Fleet
          if ($decryptedData[12]) {
            # We skip over the actual player's ID, screwing up the value of the byte
            if ($decryptedData[12] > $playerId) { $transferId = $decryptedData[12] + 1 } 
            else { $transferId = $decryptedData[12]; }
          } else { 
           $transferId = 0; # To save space, Player 1 gets no byte
          }
        }
        
        ### 32K Merge & SS Pop Steal ###########################################
        if ($file_type =~ /x/i && -f "$listPrefix.hst.fleet") { # Requires fleet file
          ### 32k Merge #######################################################
          $warnId = &zerofy($playerId) . '-32k-' . $fleetId . '+' . $waypointId; # adding a zero lets us sort on key
         if ($typeId == 5 && $taskId == 4 && $targetType == 2) {
            # typeId = 5 Change Waypoint, taskId = 4 Merge Fleet, targetType = 2 Fleet
            # fleet 1 is: $fleetId  (this is the fleet that will go away)
            # fleet 2 is: $targetId
            # Check adding ship type together > 32767 and stop the merge
            my @playerShipCount = split (chr(31), $fleetList{$playerId}{$fleetId}{shipCount});
            my @targetShipCount = split (chr(31), $fleetList{$playerId}{$targetId}{shipCount});
            for (my $i=0; $i <=15; $i++) { # Check each ship type
              if ( ( $playerShipCount[$i] + $targetShipCount[$i] ) > 32767) {
                $err = '32k Merge: Player ' . ($playerId+1) . ' Fleet ' . ($fleetId+1) . ' to ' . ($targetId+1) . ' Merge order triggers 32k Fleet bug.';
                $needsFixing++; 
                if ($fixFiles == 2 ) {
                  $decryptedData[11] = $decryptedData[11] & 0xF0 ; # Set the right 4 bits to 0 (no action)
                  $err .= ' Fixed!! Reset to No Task.';
                }
                $warning{$warnId} = $err;
              } else { $err = ''; }
            }
          } else {  # Clear any 32K warning
             if (exists ($warning{$warnId})) { delete ($warning{$warnId}); $needsFixing--;}
          }
          ### SS Pop Steal #####################################################
          # typeId = 5 (waypoint change block), taskId = 1 (Transport)
          # targetType = 1 (Planet), taskPopulation = 1 (Load all Available)     
          # $fleetList{$ownerId}{$fleetId}{robberBaron} == 1 (Robber Baron in fleet)        
          # Load All Available doesn't flush any previous value for population, so don't check LoA value.
          # 'no action','Load All Available','Unload All','Load Exactly','UnLoad Exactly','Fill Up to %','Wait For %','Load Optimal/Dunnage','Set Amount To','Set Waypoint To'
          $warnId = &zerofy($playerId) . '-popsteal-' . $fleetId . '+' . $waypointId; # adding a zero lets us sort on key
          if ($typeId == 5 && $taskId == 1 && $targetType == 1 && $taskPopulation =~ /[135679]/ && $fleetList{$playerId}{$fleetId}{robberBaron} == 1 ) { # @showTransportTask
            $err = 'SS Pop Steal: Player ' . ($playerId+1) . ' fleet ' . ($fleetId+1) . " asssigned Transport> Population> $showTransportTask[$taskPopulation] orders at $xDest" . 'x' . "$yDest.";          
            $needsFixing++;
            if ($fixFiles == 2 ) { # Only fix if fixFiles is set
              $decryptedData[18] = 0; # Set the fleet task and cargo value for population to do nothing
              $decryptedData[19] = 0; 
              $err .= ' Fixed!! Reset to Do Nothing.';
            } else {$err .= '';}
            $warning{$warnId} = $err;
          } else { # Clear warnings if the task is now do nothing for pop
            if (exists ($warning{$warnId})) { delete($warning{$warnId}); $needsFixing--;}
          }
          ### freepop ############################################################
          # Check loading/unloading against fleet cargo
          # BUG: This code is completely untested!!!
  #         if ($typeId == 5 && $taskId == 1) {
  #           # Only check if we're in the ballpark of needing to check
  #           my ($errI, $errB, $errG, $errP, $errF) = (0) x 5;
  #           my @fleetCargo = split (chr(31), $fleetList{$playerId}{$fleetId}{cargo});
  #           my $cargoCapacity = $fleetList{$playerId}{$fleetId}{cargoCapacity};
  #           if ($fleetCargo[0] < $ironium)    { $errI =  $fleetCargo[0] - $ironium; }
  #           if ($fleetCargo[1] < $boranium)   { $errB =  $fleetCargo[1] - $boranium;}
  #           if ($fleetCargo[2] < $germanium)  { $errG =  $fleetCargo[2] - $germanium;}
  #           if ($fleetCargo[3] < $population) { $errP =  $fleetCargo[3] - $population;}
  #           if ($fleetCargo[4] < $fuel)       { $errF =  $fleetCargo[4] - $fuel;}
  #           if (  $errI || $errB || $errG || $errP || $errF) {
  #             $warnId = &zerofy($playerId) . '-freepop-' . &zerofy($fleetId); # adding a zero lets us sort on key
  #             $err = "Freepop Exploit: Player " . ($playerId+1) . " moved excess cargo over fleet " . ($fleetId+1) . " capacity: $errI, $errB, $errG, $errP, $errF,";
  #             #BUG: How to fix for this. 
  #             # needsFixing++;
  # #           if ($fixFiles == 2) {
  # #             $decryptedData[18] = 0; # Set the fleet task and cargo value for population to do nothing
  # #             $decryptedData[19] = 0; 
  # #             $err .= ' Fixed!! Reset to do nothing.';
  # #           } 
  #             $warning{$warnId} = $err;
  #           }
  #         }
          ########################################################################
        } else { print "Missing .fleet $listPrefix.hst.fleet. Cannot check SS Pop Steal or 32k Fleet for Player:" . ($playerId+1) . ", Fleet:" . ($fleetId+1) . ", Waypoint:" . ($waypointId+1); }
        
        # Store the waypoint data for later use.
        $waypoint{playerId} = $playerId;
        $waypoint{id} = $fleetId . '+' . $waypointId;  # Unique id.
        $waypoint{fleetId} = $fleetId;
        $waypoint{waypointId} = $waypointId; 
        $waypoint{warp} = $warp;
        $waypoint{taskId} = $taskId;
        $waypoint{typeId} = $typeId;
        $waypoint{xDest} = $xDest; 
        $waypoint{yDest} = $yDest;
        $waypoint{targetId} = $targetId;
        $waypoint{targetType} = $targetType;
        $waypointList{$playerId}{$waypoint{id}} = { %waypoint };   
      } 
      elsif ($typeId == 19 ) { # waypoint task block .m/.hst files. 
        # Fleet ID is not stored in this block. Always follows associated Fleet Block 16.
        # This is the fleet's next waypoints, in order. 
        my $xDest;      # tested
        my $yDest;      # tested
        my $objectId;   # like fleetId
        my $warp;       # tested
        my $taskId;     # tested
        my $targetType;
        my $playerId = $ownerId; # from last pass of fleet block
        
        $xDest =  &read16(\@decryptedData, 0);
        $yDest =  &read16(\@decryptedData, 2);
        $objectId = &read16(\@decryptedData,4);  # like fleetId
        $warp  = ($decryptedData[6] & 0xFF) >> 4; # Left bits
        # byte 6 = $decryptedData[6] & 0x0F; # right 4 bits, always 0??
        # byte 7
        $taskId = $decryptedData[8] & 0x0F; # right 4 bits
        $targetType = ($decryptedData[9]& 0xFF) % 16; #0-Unknown, 1-planet, 2-fleet, 4-deep space, 8-wormhole/trader/minefield/salvage
      }
      elsif ($typeId == 20 ) { # waypoint block 20 in .m/.hst files. 8 Bytes
        # We'll never have WP 20 (.m/.hst) && WP 28/29 (.x)
        # BUG: This block is not fully mapped.
        # Fleet ID is not stored in this block. Always follows associated Fleet Block 16. 
        # Block 8 is task ID.
        # This is the fleet's current location 
        # Additional waypoints are stored immediately thereafter as Block 19s or 20s
        my $x;     # tested
        my $y;     # tested
        my $objectId;         # like fleet Id?
        my $warp;  # tested
        my $taskId;# tested
        my $waypointId;
        my $targetType;
        my %waypoint; # to store waypoints in a hash
        #my $fleetId; # from last fleet block 
        my $playerId = $ownerId; # from last pass of fleet block
        
			  $x = &read16(\@decryptedData, 0);  
        $y = &read16(\@decryptedData, 2);
        $objectId = &read16(\@decryptedData,4); # like fleet Id
        $warp = $decryptedData[6] >> 4; # left 4 bits
        # $decryptedData[6] & 0x0F; # right 4 bits, always 0??
        if ($decryptedData[8]) { # Not present when no task assigned
          $taskId = $decryptedData[8] & 0x0F; # right 4 bits
        }
        
        $waypointId = &read16(\@decryptedData, 2);
        #$fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        #$playerId = $decryptedData[1] & 0xFF;
			  #$xDest = &read16(\@decryptedData, 4);  
        #$yDest = &read16(\@decryptedData, 6);
#        #my $positionObjectId = &read16(\@decryptedData, 2);
# #        my $unknownBitsWithWarp = $decryptedData[6] & 0x0F;
# #        my $positionObjectType = $decryptedData[7] & 0xFF;
# #        my $fullWaypointData;
# #        my $warp =  $decryptedData[10] >> 4; 
#         my $waypointTask = $decryptedData[6] & 0x0F;
        $waypoint{id} = $waypointId; # Duplicate data, but easier to manage.
        $waypoint{x} = $x; 
        $waypoint{y} = $y;
        $waypoint{warp} = $warp;
        $waypoint{taskId} = $taskId;
        $waypoint{typeId} = $typeId;
#        $waypoint{targetId} = $targetId;
        $waypoint{targetType} = $targetType;
        $waypoint{$playerId}{$waypointId} = { %waypoint };
      }
      elsif ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
        # Block 28 will always follow a Block 13 (Planet block), so the current planet ownerId will be the Player Id
        # in a non-.x file. 
        # if not a .x file, we derive player Id from the most recent planet info
        # because the player info isn't in the ProductionQueueBlock 
        my $index = 0;
        my ($itemId, $count, $completePercent, $itemType);
        my $item = ''; # array of items in the planet's queue
        my @item = ();
        # planetId is only in the ProductonQueueChangeBlock
        # because otherwise it's the planet Id that preceded this block
        # Player is the planet owner, unless we're in a .x file with no planet Id.
        if ($typeId == 28) { 
          $ownerId = $playerId; 
          $index = 0;
          # $planetId is the most recent planet ID.
        } elsif ($typeId == 29) { # Testing for Production Queue Change Block
          $ownerId = $Player;
          $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
          #$planetId = &read16(\@decryptedData, 0) & 0x7FF;  # 11 Bits to match other blocks
          $index = 2;
        } 
       
        if ($typeId == 29 && $size == 2) { # Clear Queue 
          # Need to clear the ProductionQueue array 
          if (exists $queueList{$ownerId}{$planetId}) { delete $queueList{$ownerId}{$planetId};}
        }
        
        ### Cheap Starbase #####################################################
        # Reset the cheap starbase warning before reprocessing queue
        my $warnId = &zerofy($ownerId) . '-starbase-' . $planetId;
        if (exists($warning{$warnId})) { $needsFixing --; delete ($warning{$warnId}); }
                
        my @queueValues = qw ( Mines(Auto) Factories(Auto) Defenses(Auto) Alchemy(Auto) MinTerra MaxTerra Packet Factory Mines Defenses Unknown Alchemy );
        for (my $i=$index; $i <= scalar(@decryptedData)-4; $i+=4) {
          $itemId = &read16(\@decryptedData, $i) >> 10;  # Top 6 bits - but only uses 4
          $count = &read16(\@decryptedData, $i) & 0x3FF; # Bottom 10 bits
          $completePercent = &read16(\@decryptedData, $i+2) >> 4; #Top 12 bits
          $itemType = &read16(\@decryptedData, $i+2) & 0x0F; # bottom 4 bits
          # itemType=2 is defaults, itemType=4 is ship (itemId 0-15) or base (itemId 16-25)
          # if itemType=4, $itemId is the designId
          $item = "$itemId|$count|$completePercent|$itemType";  
          ### Cheap Starbase ###################################################
          # I can't fix the design from here, but the design change should have fixed it
          #   if it needs fixing. 
          if ($itemType == 4 && $completePercent > 0 && grep( /^$itemId$/, @designChanges ) ) { # if a ship/base design, assumed designId
            $warnId = &zerofy($ownerId) . '-starbase-' . $planetId;
            my $err = 'Cheap Starbase: Player ' . ($ownerId+1) . '. Do not edit a starbase under construction (design slot ' . ($itemId+1) . '.';
            $warning{$warnId} = $err;
          } 
          push (@item, $item);
        } 
        unless ($size == 2) { # Don't store anything if it's a clear order
          $queueList{$ownerId}{$planetId}{playerId} = $ownerId;
          $queueList{$ownerId}{$planetId}{id}       = $planetId;
          $queueList{$ownerId}{$planetId}{offset}   = $offset; # So we can keep track of order for clear queue
          $queueList{$ownerId}{$planetId}{size}     = $size;  # $size=2 is a clear order
          $queueList{$ownerId}{$planetId}{item}     = join (chr(31), @item);
        }
      } 
      elsif ($typeId == 26 || $typeId == 27) { # Ship Design & Ship Design Change block
        # ship Designs are before fleet information. Starbase designs are after fleet information.
        my $hullId;
        my $isFullDesign;
        my $keepDesign;
        my $isTransferred;
        my $isStarbase;
        my $armor=0;
        my $armorIndex; # used to fix Space Dock Overflow
        my $designNumber;
        my $designId; # a single Id between $designNumber and $isStarbase of +16 for $isStarbase
        my $pic;
        my $slot;
        my $itemId;
        my $itemCategory;
        my $itemCount;
        my $slotCount; 
        my $slotEnd;
        my $cargoCapacity = 0; # calculated  
        my $fuelCapacity = 0; # calculated  
        my $robberBaron = 0;
        my $mass = 0;   # For full designs, this is calculated
        my $turnDesigned; 
        my $totalBuilt;
        my $totalRemaining;
        my $shipNameLength;
        my $shipName;
        my $index;
        my %design;
        my $items = '';
        
        my $itemHash = '';
        my $spacedockOverflow = 0;  #Space Dock Overflow
        my $spaceDockIndex; # used for the Space Dock overflow
        my $crobyLangston = 0; #Space Dock overflow additional armor (Croby or Langston)
        my $itemSum; #tracking if all the design slots are empty for the Cheap Starbase bug
        
        # Find design block Player Id Because the player id isn't in Block 26
        # The Design blocks are in order, and the number of them for each player are defined in the player block(s). 
        # And if it seems like a lot of work to get this info, it is.
        # Find design block player
        if ($typeId == 26 ) { # .m/.hst File. 
          $designOwner=0;
          if ($designShipTotalCounter >= $designShipTotal) { # Don't start starbases until the ships are done.
            while ($designOwner <= 0  && $designBaseTotalCounter < $designBaseTotal && $designBasePlayerId <= $lastPlayer) {
               if (exists($player{$designBasePlayerId}{starbaseDesigns}) && $designBaseCounter < $player{$designBasePlayerId}{starbaseDesigns}) {
                  $designBaseCounter++; 
                  $designBaseTotalCounter++; 
                  $designOwner = $designBasePlayerId; 
                  last;
               } else { 
                 $designBasePlayerId++; 
                 $designBaseCounter = 0; 
               }
             }
          } else {
            while ($designOwner <= 0  && $designShipTotalCounter < $designShipTotal && $designShipPlayerId <= $lastPlayer) {
               if (exists($player{$designShipPlayerId}{shipDesigns}) && $designShipCounter < $player{$designShipPlayerId}{shipDesigns}) {
                  $designShipCounter++;
                  $designShipTotalCounter++;
                  $designOwner = $designShipPlayerId; 
                  last;
               } else { $designShipPlayerId++; $designShipCounter = 0; }
            }
          }
          $ownerId = $designOwner;
        } elsif ($typeId == 27) { $ownerId = $Player; }  
 
        my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
        $keepDesign = $decryptedData[0] % 16; # right-most 4 bits
        # The Delete block type 27
        if ($keepDesign == 0) { # If this is a delete design command
          $designNumber = $decryptedData[1] % 16; 
          $isStarbase = ($decryptedData[1] >> 4) % 2; 
          if ($isStarbase) { $designId =  $designNumber + 16; } else { $designId = $designNumber; }
          
          # If the design is deleted, remove from the designList Array
          if (exists $designList{$ownerId}{$designId}) { delete ( $designList{$ownerId}{$designId}); } 
          
          # if the design is deleted, remove the starbase from the list of starbase design changes
          @designChanges = grep {$_ ne $designId } @designChanges; 
          
          # If the design is deleted, remove design (and whole fleets) from the fleetList array 
          foreach my $i (keys %fleetList) { # playerId
            foreach my $j (keys %{$fleetList{$i}}) { # fleetId
              unless ($ownerId == $fleetList{$i}{$j}{playerId}) { next; } # Skip other player fleets
              if (($fleetList{$i}{$j}{shipDesigns} & (1 << ($designNumber))) > 0) { # If the fleet includes ships of the deleted design
                # Reduce the count of ships of that design to 0 
                my @shipCount = split(chr(31), $fleetList{$i}{$j}{shipCount}); 
                $shipCount[$designNumber] = 0; # Now zero out the actual shipCount for the design
                $fleetList{$i}{$j}{shipCount} = join(chr(31), @shipCount); 
                               
                # If total ships in fleet is now 0, completely delete fleet
                my $fleetTotal; foreach (@shipCount) { $fleetTotal += $_; } # Total up the (remaining) ships in the fleet
                if ($fleetTotal == 0 ) { delete $fleetList{$i}{$j}; } 
                else { # Update fleet, cargo, robberBaron, fuel & cargo Capacity, mass
                  # clear the design by zeroing out the bit
                  $fleetList{$i}{$j}{shipDesigns} = &bin2dec($fleetList{$i}{$j}{shipDesigns});  # convert to decimal
                  $fleetList{$i}{$j}{shipDesigns} = $fleetList{$i}{$j}{shipDesigns} & ~(1 << $designNumber);
                   
                  # Reprocess capacity/RB/mass for each design in the fleet
                  my ($cargoCapacity, $fuelCapacity, $robberBaron, $mass) = &tallyFleet ($i, $fleetList{$i}{$j}{shipCount}, $fleetList{$i}{$j}{shipDesigns});
                  $fleetList{$i}{$j}{shipDesigns} = &dec2bin($fleetList{$i}{$j}{shipDesigns}); # convert to binary
                  
                  # Adjust the cargo after the deleted design
                  my $cargoRatio;
                  if ( $fleetList{$i}{$j}{cargoCapacity} > 0) {  $cargoRatio = $cargoCapacity / $fleetList{$i}{$j}{cargoCapacity}; }
                  else { $cargoRatio = 0; } 
                  my $fuelRatio;
                  if ( $fleetList{$i}{$j}{fuelCapacity} > 0) { $fuelRatio = $fuelCapacity / $fleetList{$i}{$j}{fuelCapacity}; }
                  else { $fuelRatio = 0; }
                  # Adjust the cargo for the deleted design
                  # BUG: The calculation for the cargo and fuel post design deletion will be +- 1 occasionally. 
                  # BUG: Should also be for split fleets, duplicate code.
                  my @cargo = split( chr(31), $fleetList{$i}{$j}{cargo});
                  for (my $k=0; $k <=3; $k++ ){
                    $cargo[$k] = int(.5 + ($cargo[$k] * $cargoRatio)); # adjust the cargo based on the deleted design
                    $mass += $cargo[$k]; 
                  }
                  $cargo[4] = int(.5 + ($cargo[4] * $fuelRatio));
                  
                  $fleetList{$i}{$j}{cargoCapacity} = $cargoCapacity;
                  $fleetList{$i}{$j}{fuelCapacity}  = $fuelCapacity;
                  $fleetList{$i}{$j}{robberBaron}   = $robberBaron;
                  $fleetList{$i}{$j}{cargo}         = join(chr(31), @cargo);
                  $fleetList{$i}{$j}{mass}          = $mass;
                  
                  # BUG: if the fleet is gone, need to delete associated waypointList entries
                  #         although fleet Id reordering could make this complicated?
                  # BUG:    which could clear the SS Pop Steal and 32k Fleet warnings. 
                }
              }
            }
          }
          
          ### Cheap Starbase ###################################################
          # If the design is deleted, remove from queueList array for every planet
          # and rebuild the queueList{}{}{item} value
          foreach my $i (keys %queueList) { # playerId
            foreach my $planetId (keys %{$queueList{$i}}) { 
              if (exists $queueList{$ownerId}{$planetId}) {  
                my @itemList = split (chr(31), $queueList{$ownerId}{$planetId}{item});
                my $itemNew;
                my @itemListNew;
                foreach my $k (@itemList) {
                  my ($itemId,$count,$completePercent,$itemType) = split ('\|', $k);
                  if ($itemType == 4 && $itemId == $designId) {  # if the item in the queue is a ship design (4)
                    # If there was a warning for the planet, remove it
                    $warnId = &zerofy($ownerId) . '-starbase-' . &zerofy($planetId);
                    if (exists ($warning{$warnId}) ) { delete ($warning{$warnId}); $needsFixing--;}
                  } else {
                    $itemNew = "$itemId|$count|$completePercent|$itemType";
                    push (@itemListNew, $itemNew); #easier to just flat replace them
                  }
                }
                $queueList{$ownerId}{$planetId}{item} = join(chr(31), @itemListNew);
              }
            }
          }
          ### 10th Starbase ####################################################
          # If the 10th starbase has been deleted, clear the warning  
          if ( $isStarbase && $designNumber == 9 && $keepDesign == 0 && $ownerId == $lastPlayer ) {
            $warnId = &zerofy($ownerId) . '-ten-' . &zerofy($designId);
            if ($warning{$warnId}) { delete ($warning{$warnId}); $needsFixing--; }
          }
          ### Space Dock Armor Overflow ########################################
          # If delted design was the Space Dock overflow, clear the warning 
          $warnId = &zerofy($ownerId) . '-dock-' . &zerofy($designId);
          if ($warning{$warnId}) { delete( $warning{$warnId} ); $needsFixing--; }
        }
        if ( $typeId == 27 ) { $index = 2; } else { $index = 0; }# for the two extra bytes in a .x file 
                 
        # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
        if ($keepDesign) { # $keepDesign = 1 is not deleted.
          $isFullDesign =  ($decryptedData[$index] & 0x04); 
          $isTransferred = ($decryptedData[$index+1] & 0x80); 
          $isStarbase = ($decryptedData[$index+1] & 0x40);  
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; 
          if ($isStarbase) { $designId =  $designNumber + 16; } else { $designId = $designNumber; } # id to quickly tell ship and starbase designs apart
          
          ### Cheap Starbase ###################################################
          if ($isStarbase) { push(@designChanges, $designId); } # Keep track of design changes for Cheap Starbase
          
          # Clear warning values before we potentially set them again
          ### Cheap Colonizer ##################################################
          # If we're deleting the design, clear Cheap Colonizer
          $warnId = &zerofy($ownerId) . '-colonizer-' . &zerofy($designId);
          if (exists($warning{$warnId})) { delete( $warning{$warnId} ); $needsFixing--; }
          
          ### Space Dock Armor Overflow  #######################################
          # If we're deleting the design, clear space dock overflow
          $warnId = &zerofy($ownerId) . '-dock-' . &zerofy($designId);
          if (exists($warning{$warnId})) { delete( $warning{$warnId} ); $needsFixing--;}
          
          $hullId = $decryptedData[$index+2] & 0xFF; 
          unless ($isStarbase) { $cargoCapacity = $hullType{$hullId}[16]; }
          unless ($isStarbase) { $fuelCapacity  = $hullType{$hullId}[17]; }
          unless ($isStarbase) { $mass          = $hullType{$hullId}[10]; }
          $pic = $decryptedData[$index+3] & 0xFF; 
          if ($hullId == 29) { $pic = 4*31; }  # No idea why these pics are swapped
          elsif ($hullId == 31) { $pic = 4*29; }
          if ($isFullDesign) {
            $armor = &read16(\@decryptedData, $index+4);  
            $armorIndex = $index +4; # used to fix the Space Dock overflow
            $slotCount = $decryptedData[$index+6] & 0xFF; 
            $turnDesigned = &read16(\@decryptedData, $index+7); 
            $totalBuilt = &read16(\@decryptedData, $index+9); 
            $totalRemaining = &read16(\@decryptedData, $index+13); 
            $slotEnd = $index+17+($slotCount*4); 
            $shipNameLength = $decryptedData[$slotEnd];          
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            $index = 17;  
            if ($typeId == 27) { $index += 2; } # x files have 2 more bytes
            $spaceDockIndex = $index; # used for the Space Dock overflow
            # Loop through once for each slot
            $itemSum = 0; # tracking if all the design slots are empty for the Cheap Starbase bug
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
              $index += 2;
              $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
              $index++;
              $itemCount = $decryptedData[$index];
              $itemSum = $itemSum + $itemCount;
              $items .= "$itemSlot|$itemCategory|$itemId|$itemCount";    
              $items .= chr(31); # delimit different slots with unit separator control code
              
              if ( $itemCount > 0 && !$isStarbase){ # Calculate fuel and cargo in hull
#                 my $key =  ($itemCategory << 8) | ( $itemId & 0xFF);
#                 mass += slot.count * Items.itemMasses.get(key); 
                $itemHash =  $itemCategory . '|' . ($itemId+1);
                $mass += $itemCount * $itemDetail{"$itemHash"}[10]; 
#                 if (itemCategory == Items.TechCategory.Mechanical.getMask()) 
                if ( &getMask($itemCategory, 12) ) { # or itemHash
                  if ($itemId == 2) { $cargoCapacity += $itemCount * 50;  } 
                  if ($itemId == 3) { $cargoCapacity += $itemCount * 100;  }
                  if ($itemId == 4) { $cargoCapacity += $itemCount * 250;  }
                  if ($itemId == 5) { $fuelCapacity += $itemCount * 250;  }
                  if ($itemId == 6) { $fuelCapacity += $itemCount * 500;  }
                }
#                if ($itemCategory == Items.TechCategory.Electrical.getMask()) {
                if ( &getMask($itemCategory, 11) ) {
                  if ($itemId == 16) { $fuelCapacity += $itemCount * 200; }
                }
                if ( &getMask($itemCategory, 1) ) { # detect a robber baron
                  if ($itemId == 14) { $robberBaron = 1;}
                }
              }
              ### Cheap Colonizer ##############################################
              # Ships with a colonization module removed and the slot left empty can still colonise planets
              # If a colonizer hull is created, and then edited, it's going to put 2 (or more)  entries in the .x file.
              if ($itemId == 0 &&  $itemCategory == 4096 && $itemCount == 0) {
                $err = 'Cheap Colonizer: Player ' . ($ownerId+1) . ': Ship design slot ' . ($designNumber+1) . ": $shipName (in slot " . ($itemSlot+1) . ').';
                $warnId = &zerofy($ownerId) . '-colonizer-' . &zerofy($designId);
                $itemCategory = &read16(\@decryptedData, $index-3);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
                $needsFixing++;
                if ($fixFiles == 2) {
                  ($decryptedData[$index-3], $decryptedData[$index-2]) = &write16(0); # Category
                  $err .= ' Fixed!! Slot now truly empty.';
                } 
                $warning{$warnId} = $err;
              } else { $err = ''; }
              
              ### Space Dock Armor Overflow ####################################
              # Don't fix it here because we don't know yet at a slot level what the rest of the slots are
              if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory == 8 && $itemCount > 21  && $armor  >= 49518) {  $spacedockOverflow = 1; } 
              if ( $spacedockOverflow ) { if ($itemCategory == 4 && ($itemId == 6 || $itemId == 3)) { $crobyLangston = $itemCount; } } #other potential armor

              $index++; # Step forward for the next slot
            }
            chop $items; # Remove the trailing chr(31)
            
            ### Space Dock Armor Overflow ######################################
            if ($spacedockOverflow) {
              # If your race has ISB and RS, building a Space Dock with more than 21 SuperLat in the Armor slot 
              # will result in massively increased armor
              # I had hoped to fix this by simply rewriting the armor value. But it gets recalculated,
              # so resetting the itemCount is the only choice. 
              $err = 'Spacedock Overflow: Player ' . ($ownerId+1) . ': > 21 SuperLatanium detected in starbase design slot ' . ($designNumber+1) . ": $shipName.";
              $warnId = &zerofy($ownerId) . '-dock-' . &zerofy($designId);
              $needsFixing++;
              if ($fixFiles == 2) {
                $decryptedData[$spaceDockIndex+11] = 21; # Armor slot on spacedock
                # Armor value should be 250 + (1500 * $itemCount) / 2
                $armor = 250 + (1500 * 21) / 2; # adjust for 21 Super Latanium
                if ($crobyLangston)  {  $armor += 65 * $crobyLangston; } # add on Croby or Langston armor
                # reset the final armor value
                ($decryptedData[$armorIndex], $decryptedData[$armorIndex+1]) = &write16($armor);
                $err .= ' Fixed!! SuperLatanium set to 21. New armor value: ' . $armor;
              } 
              $warning{$warnId} = $err;
            } else { $err = ''; }
          } else { # If it's not a full design
            $mass = &read16(\@decryptedData, 4); 
            $slotEnd = 6; 
            $shipNameLength = $decryptedData[$slotEnd]; 
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          }
          
          ### 10th Starbase ####################################################
          # Detect the 10th starbase design
          if ( $isStarbase && $designNumber == 9 && $keepDesign && $ownerId == $lastPlayer ) {
            $err = 'Starbase Slot 10: Player ' . ($ownerId+1) . ": Starbase ($shipName) in design slot 10 - Potential Crash if Player 1 Fleet 1 refuels at Last Player 10th starbase design.";
            $warnId = &zerofy($ownerId) . '-ten-' . &zerofy($designId);
            # As I have no fix, no need to flag for fixing
            $warning{$warnId} = $err;
          } 

          ### Cheap Starbase ###################################################
          # Editing a starbase under construction at planet(s) with no starbase
          if ($file_type =~ /x/i && -f "$listPrefix.hst.queue") {
            if ($typeId == 27 && $isStarbase && $totalBuilt == 0) { # .x and Starbase
              foreach my $planetId (sort keys %{$queueList{$ownerId}}) { 
                my @itemList = split (chr(31), $queueList{$ownerId}{$planetId}{item}); # $planetId = planetId
                foreach my $k (@itemList) {
                  my ($itemId,$count,$completePercent,$itemType) = split ('\|', $k);
                  if ($itemType == 4 && $itemId == $designId && $completePercent > 0 ) { # if the item is a ship design (4) partially complete
                    $err = 'Cheap Starbase: Player ' . ($ownerId+1) . '. Do not edit a starbase under construction (design slot ' . ($designNumber+1) . ": $shipName).";
                    $index = 19;  
                    # Loop through each slot, setting the slot to 0
                    for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
                      ($decryptedData[$index], $decryptedData[$index+1]) = &write16(0);
                      $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
                      $index += 2;
                      $decryptedData[$index] = 0;
                      $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
                      $index++;
                      $decryptedData[$index] = 0;
                      $itemCount = $decryptedData[$index];
  #                    my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
  #                    if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount\n"; }
  #                    else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount\n";}
                      $index++;
                    }
                    $needsFixing++;
                    $warnId = &zerofy($ownerId) . '-starbase-' . &zerofy($planetId); # warn on player and planet
                    if ($fixFiles == 2) {
                      $err .= " Fixed!! Starbase design for $shipName reset to blank.";
                    } 
                    $warning{$warnId} = $err;
                  } else { $err = ''; }
                }
              }
            } else { $err .= "Missing .fleet file $listPrefix.hst.fleet. Cannot detect Cheap Starbase.\n"; }
          }
        } 

        $design{playerId} = $ownerId;
        $design{id} = $designId;
        $design{isFullDesign} = $isFullDesign;
        $design{isTransferred} = $isTransferred;
        $design{isStarbase} = $isStarbase;
        $design{designNumber} = $designNumber;
        $design{designId} = $designId;  # designNumber +16 if Starbase
        $design{hullId} = $hullId;
        $design{armor} = $armor;
        $design{turnDesigned} = $turnDesigned;
        $design{totalBuilt} = $totalBuilt;
        $design{totalRemaining} = $totalRemaining;
        $design{shipName} = $shipName;
        $design{cargoCapacity} = $cargoCapacity;
        $design{fuelCapacity} = $fuelCapacity;
        $design{mass} = $mass;
        $design{robberBaron} = $robberBaron;
        $design{items} = $items;
        $designList{$ownerId}{$designId} = { %design }; 
      } 
      elsif ($typeId == 1 || $typeId == 2 || $typeId == 25) { #Manual Load Task block
        #typeID = 1 : ManualSmallLoadUnloadTaskBlock, 1 kt > 127 kt 
        #typeID = 2 : ManualMediumLoadUnloadTaskBlock, 128 kt > 32767 kt
        #typeID =25 : ManualLargeLoadUnloadTaskBlock, 32768kt >   
        my ($fromId, $fromIdType, $toId, $toIdType);
        my ($fromOwnerId, $toOwnerId);
        my $contents;
        my ($ironium, $boranium, $germanium, $population, $fuel) = (0) x 5; # Assign 0 to all of them.
        my ($index, $indexStep, $indexFlip, $indexHalf);
        my ($isIronium, $isBoranium, $isGermanium, $isPopulation, $isFuel);
        my $err = '';

        # OwnerId and Id are 0-15 (+1 for displayed value)
        # OwnerId of 127 is none (deep space), OwnerId of 0 is a planet if typeId = 1
        $fromOwnerId = $decryptedData[1] >> 1;
        $toOwnerId = $decryptedData[3] >> 1;
        # toId of 511 is deep space
        $fromId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $toId = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 1) << 8);
        # idType determines if From and To IDs are unknown(0), planet(1), fleet(2), space(4), salvage/packet/MT(8)
        $toIdType = $decryptedData[4] >> 4;  # left 4 bits
        $fromIdType =  ($decryptedData[4] >> 0) & 0xF;  # right 4 bits 
        $index = 5;
        $contents = $decryptedData[$index];
        $isIronium = &getMask($contents,0);
        $isBoranium = &getMask($contents,1);
        $isGermanium = &getMask($contents,2);
        $isPopulation = &getMask($contents,3);
        $isFuel = &getMask($contents,4);
        $index++;
        # The different load blocks use a different number of bytes to represent the data
        # typeId 1 is 1 byte, typeId 2 is 2 bytes, and typeId 25 is 3 bytes
        # If the value is negative (unload), bit 7 is 1, and the remaining 7 bits are flipped.
        if ($typeId == 1 ) {  # Small load
          $indexStep = 1; $indexHalf = 128; $indexFlip = 254; 
#          if ($isIronium)    { $ironium = $decryptedData[$index]; if ($ironium >= $indexHalf) { $ironium = $ironium -$indexFlip; } $index=$index+$indexStep; }
          if ($isIronium)    { $ironium = $decryptedData[$index]; if ($ironium >= $indexHalf) { $ironium = -(~$ironium & 0xFF)+ 1; } $index=$index+$indexStep; }
          if ($isBoranium)   { $boranium = $decryptedData[$index]; if ($boranium >= $indexHalf) { $boranium = -(~$boranium & 0xFF) + 1; } $index=$index+$indexStep; }
          if ($isGermanium)  { $germanium = $decryptedData[$index]; if ($germanium >= $indexHalf) { $germanium = -(~$germanium & 0xFF) + 1; } $index=$index+$indexStep; }
          if ($isPopulation) { $population = $decryptedData[$index]; if ($population >= $indexHalf) { $population = -(~$population & 0xFF) + 1 ; } $index=$index+$indexStep;}
          if ($isFuel)       { $fuel = $decryptedData[$index]; if ($fuel >= $indexHalf) { $fuel = -(~$fuel & 0xFF) + 1; } }
        } elsif ( $typeId == 2 ) { # Medium load
          $indexStep = 2; $indexFlip = 2**16; $indexHalf = $indexFlip/2; 
          if ($isIronium)    { $ironium = &read16(\@decryptedData, $index); if ($ironium >= $indexHalf) { $ironium = $ironium -$indexFlip; } $index=$index+$indexStep; }
          if ($isBoranium)   { $boranium = &read16(\@decryptedData, $index); if ($boranium >= $indexHalf) { $boranium = $boranium -$indexFlip; } $index=$index+$indexStep; }
          if ($isGermanium)  { $germanium = &read16(\@decryptedData, $index); if ($germanium >= $indexHalf) { $germanium = $germanium -$indexFlip; } $index=$index+$indexStep; }
          if ($isPopulation) { $population = &read16(\@decryptedData, $index); if ($population >= $indexHalf) { $population = $population -$indexFlip; } $index=$index+$indexStep;}
          if ($isFuel)       { $fuel = &read16(\@decryptedData, $index); if ($fuel >= $indexHalf) { $fuel = $fuel -$indexFlip; }}
        } elsif ($typeId == 25 ) { # Large load
          $indexStep = 4; $indexFlip = 2**32; $indexHalf = $indexFlip/2; 
          if ($isIronium)    { $ironium = &read32(\@decryptedData, $index); if ($ironium >= $indexHalf) { $ironium = $ironium -$indexFlip; }$index=$index+$indexStep; }
          if ($isBoranium)   { $boranium = &read32(\@decryptedData, $index); if ($boranium >= $indexHalf) { $boranium = $boranium -$indexFlip; } $index=$index+$indexStep; }
          if ($isGermanium)  { $germanium = &read32(\@decryptedData, $index); if ($germanium >= $indexHalf) { $germanium = $germanium -$indexFlip; } $index=$index+$indexStep; }
          if ($isPopulation) { $population = &read32(\@decryptedData, $index); if ($population >= $indexHalf) { $population = $population -$indexFlip; } $index=$index+$indexStep;}
          if ($isFuel)       { $fuel = &read32(\@decryptedData, $index); if ($fuel >= $indexHalf) { $fuel = $fuel -$indexFlip; }}
        }
        
        my @cargoLoad = ($ironium, $boranium, $germanium, $population, $fuel);
        my $cargoLoad = join(chr(31),@cargoLoad);
        if ($fromIdType == 2) { &adjustFleetCargo($fromOwnerId, $fromId, $cargoLoad, 1); } # update fleetList data
        if ($toIdType == 2) { &adjustFleetCargo($toOwnerId, $toId, $cargoLoad, -1); } # update fleetList data

        ### Mineral Upload #####################################################
        # If a transfer is from a planet to an enemy fleet, it could be Mineral Upload exploit
        # If the Owner is 0, type is 1, it's a planet
        # If the owner is 0-15, type is 2, it's a fleet
        # As the orders can accumulate, need to track the total uploaded over 
        # multiple tasks.
        if (-f "$listPrefix.hst.fleet" ) {
          unless (exists($totalUpload{$toId})) { $totalUpload{$toId} = 0; }
          if ((($fromOwnerId == 0 &&  $fromIdType == 1 ) && ($toOwnerId != $Player && $toIdType == 2) )) {
            $totalUpload{$toId} = $totalUpload{$toId} - $ironium; 
            $totalUpload{$toId} = $totalUpload{$toId} - $boranium; 
            $totalUpload{$toId} = $totalUpload{$toId} - $germanium; 
            #print "Player: $Player, fromOwnerId: $fromOwnerId fromId:$fromId(" . &showDestType($fromIdType) . "), toOwnerId: $toOwnerId toId:$toId(" . &showDestType($toIdType) . ") TotalUpload: $totalUpload{$toId}, Cargo space:" . $fleetList{$toOwnerId}{$toId}{cargoCapacity} . "\n";
            if ( $totalUpload{$toId}  >  $fleetList{$toOwnerId}{$toId}{cargoCapacity} ) {
              $warnId = &zerofy($Player) . '-mineral-' . &zerofy($toOwnerId) . '+' . &zerofy($toId); # adding a zero lets us sort on key
              $err = 'Mineral Upload: Overage of '. ( $totalUpload{$toId}-$fleetList{$toOwnerId}{$toId}{cargoCapacity}) . ' from player ' . ($Player+1) . ' to player ' . ($toOwnerId+1). ', fleet ' . ($toId+1) . '.';
              $needsFixing++; 
              $warning{$warnId} = $err;
              if ($fixFiles == 2) {
                # BUG: If we make an adjustment here remember to update fleetList data
                # Setting the contents to 0 seems to prevent the order from happening.
                $decryptedData[5] = 0;
                $err .= ' Fixed!! Canceled order.';
              }
            } else { $err = ''; }
          }
        } else { $err .= "Missing .fleet $listPrefix.hst.fleet. Cannot calculate Mineral Upload.\n"; }
         
        # clear the warning if it's been fixed and total is low enough again
        if ( $totalUpload{$toId} <  $fleetList{$toOwnerId}{$toId}{cargoCapacity} ) {
          $warnId = &zerofy($Player) . '-mineral-' . &zerofy($toOwnerId) . '+' . &zerofy($toId);
          if (exists($warning{$warnId})) { delete ($warning{$warnId}); $needsFixing--;}
        }
      } 
      elsif ( $typeId == 16 ) { # Fleet block and partial fleet block
        # Fleet info not duplicated in multi-turn file.
        # don't care about a partial fleet block (== 17), as that would be a different
        # player's fleet.
        my %fleet; # To store the values in a hash
        my $kindByte; # 3 for most partial, 4 for robber baron, 7 for full
        my $byte5;
        my $shipCountTwoBytes;
        my $positionObjectId;
        my $index;
        my $fileLength;
        my ($iLength, $bLength, $gLength, $popLength, $fuelLength);
        my $contentsLengths;
        my ($ironium, $boranium, $germanium, $population, $fuel);
        my ($x, $y);
        my $deltaX = 0;   # partial fleet data
        my $deltaY = 0;  # partial fleet data
        my $shipDesigns;
        my $damagedShipDesigns; # full fleet data
        my @damagedShipInfo = (0) x 16;    # full fleet data
        my @shipCount; # array of how many ships are in each fleet design slot
        my $warp = 0;
        my $waypointCount = 0;
        my $unknownBitsWithWarp; # partial fleet data
        my $battlePlan; # full fleet data
        my $fleetCargo = '0' . chr(31) . '0' . chr(31) .'0' . chr(31) . '0' . chr(31) . '0';
        my ($cargoCapacity, $fuelCapacity, $robberBaron, $mass) = (0) x 4;
                 
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $ownerId = $decryptedData[1] >> 1;
        #$byte2 = $decryptedData[2];
	      #$byte3 = $decryptedData[3];
        $kindByte = $decryptedData[4];
        $byte5 = $decryptedData[5];
        if (($byte5 & 8) == 0) { $shipCountTwoBytes = 1; 
        } else  {$shipCountTwoBytes = 0; }
        $positionObjectId = &read16(\@decryptedData, 6);
        $x = &read16(\@decryptedData, 8);
        $y = &read16(\@decryptedData, 10);
        $shipDesigns = &read16(\@decryptedData, 12); # counted from the right side
        $index = 14;
        # Loop through each ship design
        for (my $bit = 0; $bit <= 15; $bit++) { 
          if ($shipDesigns & (1 << $bit)) {
            if ($shipCountTwoBytes) {
              $shipCount[$bit] = &read16(\@decryptedData, $index);
              $index += 2;
            } else {
              $shipCount[$bit] = &read8($decryptedData[$index]);
              $index += 1;
            }
          } else {  
            $shipCount[$bit] = 0; 
          }
        }
        
        # Get the cargo totals for each ship in the fleet
        ($cargoCapacity, $fuelCapacity, $robberBaron, $mass) = &tallyFleet ($ownerId, $shipCount, $shipDesigns);
        
        # Fill out ship count for .fleet       
        #while (scalar(@shipCount) <= 15 ) { push(@shipCount,0 ) };
        
        # PARTIAL_KIND = 3, PICK_POCKET_KIND = 4, FULL_KIND = 7;
        #if ($kindByte != 7 && $kindByte != 4 && $kindByte != 3) {
        if ($kindByte == 7 || $kindByte == 4) {
          $contentsLengths = &read16(\@decryptedData, $index);
          $iLength = $contentsLengths & 0x03;
          $iLength = 4 >> (3 - $iLength);
          $bLength = ($contentsLengths & 0x0C) >> 2;
          $bLength = 4 >> (3 - $bLength);
          $gLength = ($contentsLengths & 0x30) >> 4;
          $gLength = 4 >> (3 - $gLength);
          $popLength = ($contentsLengths & 0xC0) >> 6;
          $popLength = 4 >> (3 - $popLength);
          $fuelLength = $contentsLengths >> 8;
          $fuelLength = 4 >> (3 - $fuelLength);
          $index += 2;
          $ironium = &readN(\@decryptedData, $index, $iLength);
          $index += $iLength;
          $boranium = &readN(\@decryptedData, $index, $bLength);
          $index += $bLength;
          $germanium = &readN(\@decryptedData, $index, $gLength);
          $index += $gLength;
          $population = &readN(\@decryptedData, $index, $popLength);
          $index += $popLength;
          $fuel = &readN(\@decryptedData, $index, $fuelLength);
          $index += $fuelLength;
          # delimit values for storage
          $fleetCargo = $ironium . chr(31) . $boranium . chr(31) . $germanium . chr(31) . $population . chr(31) . $fuel;
          $mass +=  $ironium + $boranium + $germanium + $population;
        } 
        if ($kindByte == 7) {
          $damagedShipDesigns = &read16(\@decryptedData, $index);
          $index += 2;
          for (my $bit = 0; $bit <= 15; $bit++) { # Loop through each ship design
            if (&bin2dec($damagedShipDesigns) & (1 << $bit)) {
              $damagedShipInfo[$bit] = \&read16(\@decryptedData, $index);
              $index += 2;
            }
          }
          $damagedShipInfo = join(chr(31), @damagedShipInfo);
          
          $battlePlan = &read8($decryptedData[$index++]);
          $waypointCount = &read8($decryptedData[$index++]);
        } else {
          $deltaX = &read8($decryptedData[$index++]);
          $deltaY = &read8($decryptedData[$index++]);
          $warp = $decryptedData[$index] & 15;
          $unknownBitsWithWarp = $decryptedData[$index] & 0xF0;
          $index++;
          $index++;
          $mass = &read32(\@decryptedData, $index);  # we only get the mass when the fleet is unknown?
          $index += 4;
        }
        $x = &read16(\@decryptedData, 8); # Correct (likely only in full block?)
        $y = &read16(\@decryptedData, 10); # Correct (likely only in full block?)
        
        #only store for active player (for a more accurate .m file result)
        if ($kindByte == 7) {
          $fleet{playerId} = $ownerId; # duplicate, but easier to read
          $fleet{id} = $fleetId; # duplicate, but easier to read
          $fleet{x} = $x;
          $fleet{y} = $y;
          $fleet{battlePlan} = $battlePlan;
          $fleet{cargoCapacity} = $cargoCapacity;
          $fleet{fuelCapacity} = $fuelCapacity;
          $fleet{robberBaron} = $robberBaron;
          $fleet{deltaX} = $deltaX;
          $fleet{deltaY} = $deltaY;
          $fleet{warp} = $warp;
          $fleet{mass} = $mass;
          $fleet{shipDesigns}  = &dec2bin($shipDesigns);
          $fleet{shipCount}  = join(chr(31), @shipCount); 
          $fleet{damagedShipInfo}  = join(chr(31), @damagedShipInfo); 
          $fleet{cargo} = $fleetCargo;
          $fleetList{$ownerId}{$fleetId} = { %fleet };
        }
      } 
      elsif ($typeId == 30) {  # BattlePlan block
        my ($planPlayerId, $planNumber, $primaryTarget,$secondaryTarget,$tactic,$attackWho, $dumpCargo, $planNameLength, $planName);
        my @target = qw(None Any Starbase Armed Bombers Unarmed Fuel Freighters);
        my @tactic = qw(Disengage ifChallenged minToSelf maxNet maxRatio Max);
        my @attackWho = qw(Nobody Enemies Neutral/Enemies Everyone 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16);
        my $err = '';
        # Player 0 Default: 0 4 19 2 5 179 45 113 222 90
        $planPlayerId = ($decryptedData[0] >> 0) & 0x0F; 
        $planNumber = ($decryptedData[0] >> 4) & 0x0F; 
        $tactic = ($decryptedData[1]) & 0x0F; 
        $dumpCargo = ($decryptedData[1] >> 7) & 0x01; 
        $primaryTarget = ($decryptedData[2] >> 0) & 0x0F; 
        $secondaryTarget = ($decryptedData[2] >> 4) & 0x0F; 
        $attackWho = $decryptedData[3]; 
        $planNameLength = $decryptedData[4]; 
        $planName = &decodeBytesForStarsString(@decryptedData[4..4+$planNameLength]);  

        ###  Detect the BattlePlan Friendly Fire bug  ##########################
        $warnId = &zerofy($planPlayerId) . '-friendly-' . &zerofy($planNumber);
        if (($attackWho) > 3 && $planNumber == 0) { 
           $err = 'Friendly Fire: Player ' . ($planPlayerId+1) . ': detected in Default battle plan against ' . &attackWho($attackWho) . '.';
           $needsFixing++;
           if ($fixFiles == 2) {
             $decryptedData[3] = 2;
             $err .= ' Fixed!! Attack Who reset to Neutral/Enemy.';
           }
           $warning{$warnId} = $err;
        } else { $err = ''; }
        # If a subsequent Default battle plan fixes it, clear the warning
        if (!$err && exists($warning{$warnId})) { delete( $warning{$warnId} ); $needsFixing--;}
        ########################################################################
      } 
      elsif ( $typeId == 34 ) { # Research Change block
      	my $researchBudget; 
      	my $researchField;
      	my $researchNext;
      	my @research = qw( Energy Weapons Propulsion Construction Electronics Biotech Same Lowest );
      
      	$researchBudget = $decryptedData[0];
      	$researchField = $decryptedData[1] & 0x0F; # right 4 bits
      	$researchNext = $decryptedData[1] >> 4;	   # left 4 bits
      }
      elsif ( $typeId == 35) { # Planet Change block
        # Planet Route orders, either NoResearch, iWarpfling, OR idRoute
        # Max planets = 945
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        my $fNoResearch =   $decryptedData[2] & 0x01;  # 0000000x
        my $iWarpFling =   (($decryptedData[3] & 0x7f ) >> 3);  # 0xxxx000
        my $warpSpeed = $iWarpFling + 4;
        my $idFling =  (&read16(\@decryptedData, 2) >> 1) & 0b1111111111; # bytes 2 & 3, 10 bits shifted 1 to the right.
        # I need one bit from byte 3, all of byte 4, and 1 bit from byte 5  (10 bits)              
        my $byte1 = $decryptedData[3] >> 7; # Extracting the first bit of $byte1      
        my $idRoute = ($decryptedData[5] & 0x01) << 9 | ($decryptedData[4] << 1) | $byte1 & 0x01; #move 4 one to the left, and then get the first bit of byte 5

      }
      elsif ($typeId == 37) {  # Fleet Merge block
        # Manual merge. Waypoint merges are handled under waypoints. 
        # The order of fleet merge is important
        # .hst files have owner info, .m and .x files have player information
        # Fleet 1 is the main ID, Fleet2+ is the rest of the fleets
        # IOW, Fleet 2+ ceases to exist.
        my @playerId;
        my @fleetId;
        my $fleetId; 
        my $playerId; 
        
        my @shipCount;
        my @fleetCargo;
        
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);  # Shift 8 to the left
        $playerId = $decryptedData[1] >> 1;  # The player Id will be the same in each fleet
        
        @fleetCargo = split (chr(31), $fleetList{$playerId}{$fleetId}{cargo}); 
        @shipCount   = split (chr(31), $fleetList{$playerId}{$fleetId}{shipCount}); # keeps updating
        # Merge the fleets in the fleetList array
        for (my $i = 2; $i < $size; $i=$i+2) {
          $fleetId[$i] = ($decryptedData[$i] & 0xFF) + (($decryptedData[$i+1] & 1) << 8);  # Shift 8 to the left
          $playerId[$i] =  $decryptedData[$i+1 ] >> 1; # Shift 1 to the right

          $fleetList{$playerId}{$fleetId}{cargoCapacity} += $fleetList{$playerId[$i]}{$fleetId[$i]}{cargoCapacity};
          $fleetList{$playerId}{$fleetId}{fuelCapacity} += $fleetList{$playerId[$i]}{$fleetId[$i]}{fuelCapacity};
          if ($fleetList{$playerId[$i]}{$fleetId[$i]}{robberBaron} == 1) { $fleetList{$playerId}{$fleetId}{robberBaron} = 1};
          $fleetList{$playerId}{$fleetId}{mass}          += $fleetList{$playerId[$i]}{$fleetId[$i]}{mass};
          
          my @fleetCargoMerge = split (chr(31), $fleetList{$playerId[$i]}{$fleetId[$i]}{cargo}); 
          for (my $j = 0; $j <= 4; $j++) {
            $fleetCargo[$j] +=  $fleetCargoMerge[$j]; # mass is already included in the other fleet's mass
          }
          
          my @shipCountMerge = split (chr(31), $fleetList{$playerId[$i]}{$fleetId[$i]}{shipCount}); 
          for (my $j = 0; $j <= 15; $j++) {
            $shipCount[$j] +=  $shipCountMerge[$j];
          }

          # Remove the merged entry from the fleet array
          delete $fleetList{$playerId[$i]}{$fleetId[$i]};
          # BUG: Clear any warnings for the fleet?
        }
        
        # Update new totals
        $fleetList{$playerId}{$fleetId}{cargo} = join (chr(31), @fleetCargo);
        $fleetList{$playerId}{$fleetId}{shipCount} = join (chr(31), @shipCount);
        my @shipDesigns = ();
        for (my $i=0;$i <=15; $i++) {
          if (($shipCount[$i] ) == 0) { unshift(@shipDesigns, '0'); #rebuilt the binary output for ship designs
          } else { unshift(@shipDesigns, '1'); };
        } 
        $fleetList{$playerId}{$fleetId}{shipDesigns} = join ('', @shipDesigns);
        
      }
      elsif ($typeId == 24) { # Fleet Split Block
        # The fleet that is being split. Followed by Block 23
        # In other words, create new fleet Id.
        my $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        my $playerId = $decryptedData[1] >> 1;
      }
      elsif ($typeId == 23) { # Move Ships block
        # Always follows each block 24 
        # A fleet being split from the block 24 fleet. 
        # One block 24/23 pair for each fleet split off for split all)
        # Merge Fleet can also be Block 23, without a 24
        my $fleetIdL;  # left side
        my $playerIdL;
        my $fleetIdR; # right side
        my $playerIdR;
        my $shipDesigns;
        
        my @shipCountL;
        my @shipCountR;
        my @shipDesignsL = ();
        my @shipDesignsR = ();
        
        $fleetIdL       = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $playerIdL      = $decryptedData[1] >> 1;
        $fleetIdR  = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 1) << 8); 
        $playerIdR =  $decryptedData[3] >> 1;        
        #$byte4 = $decryptedData[4]; # What is byte 4 (always 34)  00100010
        $shipDesigns = &read16(\@decryptedData, 5);        
        
        # if the fleet doesn't exist (yet) clone the original 
        unless (exists( $fleetList{$playerIdR}{$fleetIdR} )) { # the split creates a new fleet
          foreach my $k (keys %{$fleetList{$playerIdL}{$fleetIdL}}) {
            $fleetList{$playerIdR}{$fleetIdR}{$k} = $fleetList{$playerIdL}{$fleetIdL}{$k};
          }
          # the new fleet has (effectively) 0 cargo, 0 fuel, 0 designs, 0 ships
          # Capacities will all get recalculated, everything else is the same
          $fleetList{$playerIdR}{$fleetIdR}{cargo} = '0'.chr(31).'0'.chr(31).'0'.chr(31).'0'.chr(31).'0'; # blank cargo
          $fleetList{$playerIdR}{$fleetIdR}{shipCount}   = join(chr(31), (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)); # blank ship count
          # clone (any) waypoints to new fleet
          foreach my $k (sort keys %{$waypointList{$playerIdL}{$fleetIdL}}) {
            $waypointList{$playerIdR}{$fleetIdR}{$k} = $waypointList{$playerIdL}{$fleetIdL}{$k};  
          }
          # update the fleet Id to the new fleet
          $waypointList{$playerIdR}{$fleetIdR}{fleetId} = $fleetIdR;
        } 

        # Mostly Duplicate from Fleet Block 16 except shipCount in Block 23 is always 2 bits 
        # Moving to the right is a negative number. To the left is a positive number. 
        # Adjust the ship quantities and designs in fleet.
        @shipCountL = split(chr(31), $fleetList{$playerIdL}{$fleetIdL}{shipCount} );
        @shipCountR = split(chr(31), $fleetList{$playerIdR}{$fleetIdR}{shipCount} );
          
        my $indexFlip = 2**16; my $indexHalf = $indexFlip/2;  my $moveQuantity; # from typeId == 2 cargo movement
        my $index = 7;
        for (my $bit = 0; $bit <= 15; $bit++) {
          if ( &getMask($shipDesigns, $bit) ) {
            $moveQuantity = &read16(\@decryptedData, $index);
            if ($moveQuantity >= $indexHalf) { $moveQuantity = $moveQuantity -$indexFlip; } 
            $shipCountL[$bit] += $moveQuantity;
            $shipCountR[$bit] -= $moveQuantity;
            
            ### 32k Merge ######################################################
            # The UI can permit transferring more than 32k, but Stars! processing will fix.
            if ($shipCountL[$bit] > 32767 || $shipCountR[$bit] > 32767) {
              my $err = '32k Merge: Player ' . ($playerId+1) . ' merge order for fleet ' . ($fleetIdL+1) . ' to ' . ($fleetIdR+1) . ' for ship design ' . ($bit+1) . '.';
              if ($shipCountL[$bit] > 32767 ) { # fleet has more than 32k of a ship design
                $shipCountR[$bit] = $shipCountR[$bit] + ( $shipCountL[$bit] - 32767 );
                $shipCountL[$bit] = 32767 - $shipCountL[$bit]; # second so the value hasn't changed.
              }
              if ($shipCountR[$bit] > 32767 ) { # fleet has more than 32k of a ship design
                $shipCountL[$bit] = $shipCountL[$bit] + ( $shipCountR[$bit] - 32767 );
                $shipCountR[$bit] = 32767 - $shipCountR[$bit]; # second so the value hasn't changed.
              }
              $err .= '  Stars! will correct to 32,767.'; # This is handled by the EXE
              $warnId = &zerofy($playerId) . '-32k-' . $fleetIdL . '+' . $fleetIdR; # adding a zero lets us sort on key
              $warning{$warnId} = $err;
            } 
            # No need to clear this warning, as the UI will be screwed up until turn generation anyway.
            ##################################################################
            $index += 2;
          } 
          if ( $shipCountL[$bit] == 0) { unshift(@shipDesignsL, '0'); #rebuilt the binary output for ship designs
          } else { unshift(@shipDesignsL, '1'); };
          if ( $shipCountR[$bit] == 0) { unshift(@shipDesignsR, '0'); #rebuilt the binary output for ship designs
          } else { unshift(@shipDesignsR, '1'); };
        }
        $fleetList{$playerIdL}{$fleetIdL}{shipCount} = join(chr(31), @shipCountL );
        $fleetList{$playerIdR}{$fleetIdR}{shipCount} = join(chr(31), @shipCountR );
        
        # Cargo is not included in Block 23
        # To calculate current Cargo, you need to know the capacity of both fleets, and then 
        #   split the cargo proportionately
        # Get the capacities for the new split fleet
        my ($cargoCapacityR, $fuelCapacityR, $robberBaronR, $massR) = &tallyFleet ($playerIdR, $fleetList{$playerIdR}{$fleetIdR}{shipCount}, &bin2dec(join ('', @shipDesignsR)));
        # Get the capacities for the original (L)  fleet
        my ($cargoCapacityL, $fuelCapacityL, $robberBaronL, $massL) = &tallyFleet ($playerIdL, $fleetList{$playerIdL}{$fleetIdL}{shipCount}, &bin2dec(join ('', @shipDesignsL)));
        
        # Update the fleets into fleetList
        $fleetList{$playerIdR}{$fleetIdR}{playerId} = $playerIdR; # duplicate, but easier to read
        $fleetList{$playerIdR}{$fleetIdR}{id} = $fleetIdR; # duplicate, but easier to read
        #$fleetList{$playerIdR}{$fleetIdR}{x} = $fleetList{$playerIdL}{$fleetIdL}{x};
        #$fleetList{$playerIdR}{$fleetIdR}{y} = $fleetList{$playerIdL}{$fleetIdL}{y};
        #$fleetList{$playerIdR}{$fleetIdR}{battlePlan} = $fleetList{$playerIdL}{$fleetIdL}{battlePlan};
        #$fleetList{$playerIdR}{$fleetIdR}{deltaX} = $fleetList{$playerIdL}{$fleetIdL}{deltaX};
        #$fleetList{$playerIdR}{$fleetIdR}{deltaY} = $fleetList{$playerIdL}{$fleetIdL}{deltaY};
        #$fleetList{$playerIdR}{$fleetIdR}{warp}   = $fleetList{$playerIdL}{$fleetIdL}{warp};
        $fleetList{$playerIdR}{$fleetIdR}{shipCount}     = join(chr(31), @shipCountR); 
        $fleetList{$playerIdR}{$fleetIdR}{shipDesigns}  = join('',@shipDesignsR);
        $fleetList{$playerIdR}{$fleetIdR}{cargoCapacity} = $cargoCapacityR;
        $fleetList{$playerIdR}{$fleetIdR}{fuelCapacity } = $fuelCapacityR;
        $fleetList{$playerIdR}{$fleetIdR}{robberBaron}   = $robberBaronR;
        $fleetList{$playerIdR}{$fleetIdR}{mass}          = $massR;
        
        $fleetList{$playerIdL}{$fleetIdL}{shipCount}   = join(chr(31), @shipCountL);
        $fleetList{$playerIdL}{$fleetIdL}{shipDesigns} = join('',@shipDesignsL);
        $fleetList{$playerIdL}{$fleetIdL}{cargoCapacity} = $cargoCapacityL;
        $fleetList{$playerIdL}{$fleetIdL}{fuelCapacity}  = $fuelCapacityL;
        $fleetList{$playerIdL}{$fleetIdL}{robberBaron}   = $robberBaronL;
        $fleetList{$playerIdL}{$fleetIdL}{mass}          = $massL;
                
        # Calculate cargo & effect on mass
        my @cargoL = split(chr(31), $fleetList{$playerIdL}{$fleetIdL}{cargo}); # Before the split
        my @cargoR = split(chr(31), $fleetList{$playerIdR}{$fleetIdR}{cargo}); # Before the split
        my $fuelRatioR;
        if (($fleetList{$playerIdL}{$fleetIdL}{fuelCapacity} + $fleetList{$playerIdR}{$fleetIdR}{fuelCapacity}) > 0) { # capture div 0
           $fuelRatioR =  $fleetList{$playerIdR}{$fleetIdR}{fuelCapacity} / ($fleetList{$playerIdL}{$fleetIdL}{fuelCapacity} + $fleetList{$playerIdR}{$fleetIdR}{fuelCapacity});
        } else {        
          $fuelRatioR = 0;
        }
        my $totalCargoCapacity =  $fleetList{$playerIdL}{$fleetIdL}{cargoCapacity} + $fleetList{$playerIdR}{$fleetIdR}{cargoCapacity};
        my $totalCargo;
        my $totalFuel = $cargoR[4] + $cargoL[4];
        if ($totalCargoCapacity > 0) { # Can there even be cargo, solving div/0
          for (my $k=0; $k<=3; $k++) {
            $totalCargo = $cargoR[$k] + $cargoL[$k];
            $cargoR[$k] = int(.5 + ($totalCargo * $fleetList{$playerIdR}{$fleetIdR}{cargoCapacity}/$totalCargoCapacity));  
            $cargoL[$k] = $totalCargo - $cargoR[$k]; # So the totals aren't subject to rounding
            $massR += $cargoR[$k];
            $massL += $cargoL[$k];
          }
        } #Otherwise there's no cargo.
        $cargoR[4] = int(.5 + ($totalFuel *  $fuelRatioR));     # fuelCapacity is never 0. BUG: Had that happen.
        $cargoL[4] = $totalFuel - $cargoR[4];

        $fleetList{$playerIdL}{$fleetIdL}{cargo} = join (chr(31), @cargoL);
        $fleetList{$playerIdR}{$fleetIdR}{cargo} = join (chr(31), @cargoR);
        $fleetList{$playerIdL}{$fleetIdL}{mass} = $massL;
        $fleetList{$playerIdR}{$fleetIdR}{mass} = $massR;
        
        # delete fleets with no ships from fleetList, and associated waypoints
        my ($totalL, $totalR) = (0) x 2;
        foreach my $i (@shipCountL) {$totalL +=$i};
        foreach my $i (@shipCountR) {$totalR +=$i};
        if ($totalL == 0) { 
          if (exists( $fleetList{$playerIdL}{$fleetIdL})) { delete ($fleetList{$playerIdL}{$fleetIdL}); } 
          # dig through waypoints and clear
          foreach my $j (keys %{$waypointList{$playerIdL}}) {  
            my ($fltId, $wayId) = split ('\+', $j);
            if ($fltId == $fleetIdL) { delete  ($waypointList{$playerIdL}{$j}); } # clear "dead" waypoints
          }
        }
        if ($totalR == 0) { 
          if (exists( $fleetList{$playerIdR}{$fleetIdR})) { delete ($fleetList{$playerIdR}{$fleetIdR}); } 
          # dig through waypoints and clear
          foreach my $j (keys %{$waypointList{$playerIdR}}) {  
            my ($fltId, $wayId) = split ('\+', $j);
            if ($fltId == $fleetIdL) { delete  ($waypointList{$playerIdR}{$j}); } # clear "dead" waypoints
          }
        }
      }
      # END OF MAGIC
      # reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, $needsFixing, \%warning, \%fleetList, \%queueList, \%designList, \%waypointList, $lastPlayer;
}

sub decryptMessages {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
  my $currentTurn;
  my $offset = 0; #Start at the beginning of the file
  my @messages;
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 8 ) { # File Header Block, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      if ($fMulti) { 
        my @footer =  ( $fileBytes[-2], $fileBytes[-1] );
        $currentTurn = &getFileFooterBlock(\@footer, 2) + 2400; 
        push @messages, "Current Year: $currentTurn\n";
      } 
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      # Display the messages in the file
      my $message;
      # We need the names to display
      # Check the Player Block so we can get the race names
      # although there are no names in .x files
      if ($typeId == 6) { # Player Block
        my $playerId = $decryptedData[0] & 0xFF;
        my $fullDataFlag = ($decryptedData[6] & 0x04);
        my $index = 8;
        if ($fullDataFlag) { 
          # The player names are at the end which is not a fixed length
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
        $playerId++; # As 0 is "Everyone" need to use representative IDs
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        $singularRaceName[0] = 'Everyone';
      } elsif ($typeId == 40) { # check the Message block 
        my $byte0 =  &read16(\@decryptedData, 0);  # unknown
        my $byte2 =  &read16(\@decryptedData, 2);  # unknown
        my $senderId = &read16(\@decryptedData, 4);
        my $recipientId = &read16(\@decryptedData, 6);
        my $byte8 =  &read16(\@decryptedData, 8); # unknown
        my $messageBytes = &read16(\@decryptedData, 10);
        my $messageLength = $size -1;
        $message = &decodeBytesForStarsString(@decryptedData[11..$messageLength]);
    #    print "From: $senderId, To: $recipientId, \"$message\"\n"; 
        if ($message) {
          my $recipient;
          if ($ext =~ /[xX]/) { 
            # Different for x files, as we don't have player names in it.
            # Player ID #s are a bit weird, as 0 in this case is "everyone", not Player 1 (ID:0)
            if ( $recipientId == 0 ) { $recipient = 'Everyone'; } else { $recipient = 'Player ' . $recipientId; }
            push @messages, "Year:" . ($turn+2400) . ", From: Me, To: $recipient (" . ($recipientId+1) . "), \"$message\"\n";
          } else { 
            # We don't have player names for races undiscovered either
#            push @messages, "\tMessage Year:" . ($turn+2400) . ", From: $singularRaceName[$senderId+1], To: $singularRaceName[$recipientId], \"$message\"\n";
            #push @messages, "Message Year:" . ($turn+2400) . ", From: $singularRaceName[$senderId+1] (" . ($senderId+1) . "), To: $singularRaceName[$recipientId] (" . ($recipientId) . "), \"$message\"\n";
            push @messages, "Year:" . ($turn+2400) . ", \tFrom: " . ($senderId+1) .":$singularRaceName[$senderId+1], \tTo: " . ($recipientId) . ": $singularRaceName[$recipientId], \t\"$message\"\n";
          }
        } 
      } 
      #return @decryptedData;
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@messages;
}



# CSV position 18 is fuel
# 1,1,"Stargate 100/250",1,0,0,5,5,0,0,0,400,100,40,40,144,100,250,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,2,"Stargate any/300",2,0,0,6,10,0,0,0,500,100,40,40,145,-1,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,3,"Stargate 150/600",3,0,0,11,7,0,0,0,1000,100,40,40,146,150,600,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,4,"Stargate 300/500",4,0,0,9,13,0,0,0,1200,100,40,40,147,300,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,5,"Stargate 100/any",5,0,0,16,12,0,0,0,1400,100,40,40,148,100,-1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,6,"Stargate any/800",6,0,0,12,18,0,0,0,1400,100,40,40,149,-1,800,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,7,"Stargate any/any",7,0,0,19,24,0,0,0,1600,100,40,40,150,-1,-1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,8,"Mass Driver 5",8,4,0,0,0,0,0,0,140,48,40,40,151,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,9,"Mass Driver 6",9,7,0,0,0,0,0,0,288,48,40,40,152,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,10,"Mass Driver 7",10,9,0,0,0,0,0,0,1024,200,200,200,153,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,11,"Super Driver 8",11,11,0,0,0,0,0,0,512,48,40,40,154,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,12,"Super Driver 9",12,13,0,0,0,0,0,0,648,48,40,40,155,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,13,"Ultra Driver 10",13,15,0,0,0,0,0,0,1936,200,200,200,156,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,14,"Ultra Driver 11",14,17,0,0,0,0,0,0,968,48,40,40,157,11,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,15,"Ultra Driver 12",15,20,0,0,0,0,0,0,1152,48,40,40,158,12,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,16,"Ultra Driver 13",16,24,0,0,0,0,0,0,1352,48,40,40,159,13,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,1,"Laser",1,0,0,0,0,0,0,1,5,0,6,0,28,1,10,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,2,"X-Ray Laser",2,0,3,0,0,0,0,1,6,0,6,0,29,1,16,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,3,"Mini Gun",3,0,5,0,0,0,0,3,10,0,16,0,20,2,13,12,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,4,"Yakimora Light Phaser",4,0,6,0,0,0,0,1,7,0,8,0,19,1,26,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,5,"Blackjack",5,0,7,0,0,0,0,10,7,0,16,0,14,0,90,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,6,"Phaser Bazooka",6,0,8,0,0,0,0,2,11,0,8,0,21,2,26,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,7,"Pulsed Sapper",7,5,9,0,0,0,0,1,12,0,0,4,17,3,82,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,8,"Colloidal Phaser",8,0,10,0,0,0,0,2,18,0,14,0,192,3,26,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,9,"Gatling Gun",9,0,11,0,0,0,0,3,13,0,20,0,26,2,31,12,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,10,"Mini Blaster",10,0,12,0,0,0,0,1,9,0,10,0,24,1,66,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,11,"Bludgeon",11,0,13,0,0,0,0,10,9,0,22,0,15,0,231,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,12,"Mark IV Blaster",12,0,14,0,0,0,0,2,15,0,12,0,25,2,66,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,13,"Phased Sapper",13,8,15,0,0,0,0,1,16,0,0,6,18,3,211,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,14,"Heavy Blaster",14,0,16,0,0,0,0,2,25,0,20,0,193,3,66,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,15,"Gatling Neutrino Cannon",15,0,17,0,0,0,0,3,17,0,28,0,30,2,80,13,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,16,"Myopic Disruptor",16,0,18,0,0,0,0,1,12,0,14,0,194,1,169,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,17,"Blunderbuss",17,0,19,0,0,0,0,10,13,0,30,0,13,0,592,11,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,18,"Disruptor",18,0,20,0,0,0,0,2,20,0,16,0,27,2,169,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,19,"Multi Contained Munition",19,21,21,0,0,16,12,8,40,6,40,6,111,3,140,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,20,"Syncro Sapper",20,11,21,0,0,0,0,1,21,0,0,8,16,3,541,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,21,"Mega Disruptor",21,0,22,0,0,0,0,2,33,0,30,0,195,3,169,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,22,"Big Mutha Cannon",22,0,23,0,0,0,0,3,23,0,36,0,31,2,204,13,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,23,"Streaming Pulverizer",23,0,24,0,0,0,0,1,16,0,20,0,22,1,433,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,24,"Anti-Matter Pulverizer",24,0,26,0,0,0,0,2,27,0,22,0,23,2,433,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,1,"Alpha Torpedo",1,0,0,0,0,0,0,25,5,9,3,3,87,4,5,0,35,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,2,"Beta Torpedo",2,0,5,1,0,0,0,25,6,18,6,4,88,4,12,1,45,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,3,"Delta Torpedo",3,0,10,2,0,0,0,25,8,22,8,5,89,4,26,1,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,4,"Epsilon Torpedo",4,0,14,3,0,0,0,25,10,30,10,6,92,5,48,2,65,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,5,"Rho Torpedo",5,0,18,4,0,0,0,25,12,34,12,8,93,5,90,2,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,6,"Upsilon Torpedo",6,0,22,5,0,0,0,25,15,40,14,9,94,5,169,3,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,7,"Omega Torpedo",7,0,26,6,0,0,0,25,18,52,18,12,95,5,316,4,80,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,8,"Anti Matter Torpedo",8,0,11,12,0,0,21,8,50,3,8,1,108,6,60,0,85,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,9,"Jihad Missile",9,0,12,6,0,0,0,35,13,37,13,9,200,5,85,0,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,10,"Juggernaut Missile",10,0,16,8,0,0,0,35,16,48,16,11,201,5,150,1,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,11,"Doomsday Missile",11,0,20,10,0,0,0,35,20,60,20,13,202,6,280,2,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,12,"Armageddon Missile",12,0,24,10,0,0,0,35,24,67,23,16,203,6,525,3,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,1,"Lady Finger Bomb",1,0,2,0,0,0,0,40,5,1,20,0,35,1,6,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,2,"Black Cat Bomb",2,0,5,0,0,0,0,45,7,1,22,0,36,1,9,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,3,"M-70 Bomb",3,0,8,0,0,0,0,50,9,1,24,0,37,1,12,6,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,4,"M-80 Bomb",4,0,11,0,0,0,0,55,12,1,25,0,38,1,17,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,5,"Cherry Bomb",5,0,14,0,0,0,0,52,11,1,25,0,39,1,25,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,6,"LBU-17 Bomb",6,0,5,0,0,8,0,30,7,1,15,15,32,1,2,16,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,7,"LBU-32 Bomb",7,0,10,0,0,10,0,35,10,1,24,15,33,1,3,28,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,8,"LBU-74 Bomb",8,0,15,0,0,12,0,45,14,1,33,12,34,1,4,45,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,9,"Hush-a-Boom",9,0,12,0,0,12,12,5,5,1,5,0,182,1,30,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,10,"Retro Bomb",10,0,10,0,0,0,12,45,50,15,15,10,174,1,0,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,11,"Smart Bomb",11,0,5,0,0,0,7,50,27,1,22,0,112,1,13,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,12,"Neutron Bomb",12,0,10,0,0,0,10,57,30,1,30,0,113,1,22,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,13,"Enriched Neutron Bomb",13,0,15,0,0,0,12,64,25,1,36,0,114,1,35,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,14,"Peerless Bomb",14,0,22,0,0,0,15,55,32,1,33,0,115,1,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,15,"Annihilator Bomb",15,0,26,0,0,0,17,50,28,1,30,0,116,1,70,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,1,"Total Terraform +/-3",1,0,0,0,0,0,0,0,70,0,0,0,184,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,2,"Total Terraform +/-5",2,0,0,0,0,0,3,0,70,0,0,0,185,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,3,"Total Terraform +/-7",3,0,0,0,0,0,6,0,70,0,0,0,186,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,4,"Total Terraform +/-10",4,0,0,0,0,0,9,0,70,0,0,0,187,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,5,"Total Terraform +/-15",5,0,0,0,0,0,13,0,70,0,0,0,188,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,6,"Total Terraform +/-20",6,0,0,0,0,0,17,0,70,0,0,0,180,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,7,"Total Terraform +/-25",7,0,0,0,0,0,22,0,70,0,0,0,172,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,8,"Total Terraform +/-30",8,0,0,0,0,0,25,0,70,0,0,0,164,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,9,"Gravity Terraform +/-3",9,0,0,1,0,0,1,0,100,0,0,0,160,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,10,"Gravity Terraform +/-7",10,0,0,5,0,0,2,0,100,0,0,0,161,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,11,"Gravity Terraform +/-11",11,0,0,10,0,0,3,0,100,0,0,0,162,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,12,"Gravity Terraform +/-15",12,0,0,16,0,0,4,0,100,0,0,0,163,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,13,"Temp Terraform +/-3",13,1,0,0,0,0,1,0,100,0,0,0,168,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,14,"Temp Terraform +/-7",14,5,0,0,0,0,2,0,100,0,0,0,169,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,15,"Temp Terraform +/-11",15,10,0,0,0,0,3,0,100,0,0,0,170,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,16,"Temp Terraform +/-15",16,16,0,0,0,0,4,0,100,0,0,0,171,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,17,"Radiation Terraform +/-3",17,0,1,0,0,0,1,0,100,0,0,0,176,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,18,"Radiation Terraform +/-7",18,0,5,0,0,0,2,0,100,0,0,0,177,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,19,"Radiation Terraform +/-11",19,0,10,0,0,0,3,0,100,0,0,0,178,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,20,"Radiation Terraform +/-15",20,0,16,0,0,0,4,0,100,0,0,0,179,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,1,"Viewer 50",1,0,0,0,0,0,0,0,100,10,10,70,80,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,2,"Viewer 90",2,0,0,0,0,1,0,0,100,10,10,70,81,90,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,3,"Scoper 150",3,0,0,0,0,3,0,0,100,10,10,70,82,150,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,4,"Scoper 220",4,0,0,0,0,6,0,0,100,10,10,70,83,220,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,5,"Scoper 280",5,0,0,0,0,8,0,0,100,10,10,70,90,280,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,6,"Snooper 320X",6,3,0,0,0,10,3,0,100,10,10,70,84,-320,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,7,"Snooper 400X",7,4,0,0,0,13,6,0,100,10,10,70,85,-400,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,8,"Snooper 500X",8,5,0,0,0,16,7,0,100,10,10,70,86,-500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,9,"Snooper 620X",9,7,0,0,0,23,9,0,100,10,10,70,91,-620,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,10,"SDI",10,0,0,0,0,0,0,0,15,5,5,5,72,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,11,"Missile Battery",11,5,0,0,0,0,0,0,15,5,5,5,73,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,12,"Laser Battery",12,10,0,0,0,0,0,0,15,5,5,5,74,24,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,13,"Planetary Shield",13,16,0,0,0,0,0,0,15,5,5,5,75,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,14,"Neutron Shield",14,23,0,0,0,0,0,0,15,5,5,5,76,38,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,15,"Genesis Device",15,20,10,10,20,10,20,0,5000,0,0,0,175,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,1,"Robo-Midget Miner",1,0,0,0,0,0,0,80,50,14,0,4,138,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,2,"Robo-Mini-Miner",2,0,0,0,2,1,0,240,100,30,0,7,139,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,3,"Robo-Miner",3,0,0,0,4,2,0,240,100,30,0,7,140,12,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,4,"Robo-Maxi-Miner",4,0,0,0,7,4,0,240,100,30,0,7,141,18,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,5,"Robo-Super-Miner",5,0,0,0,12,6,0,240,100,30,0,7,142,27,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,6,"Robo-Ultra-Miner",6,0,0,0,15,8,0,80,50,14,0,4,143,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,7,"Alien Miner",7,5,0,0,10,5,5,20,20,8,0,2,181,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,8,"Orbital Adjuster",8,0,0,0,0,0,6,80,50,25,25,25,173,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,1,"Mine Dispenser 40",1,0,0,0,0,0,0,25,45,2,10,8,128,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,2,"Mine Dispenser 50",2,2,0,0,0,0,4,30,55,2,12,10,129,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,3,"Mine Dispenser 80",3,3,0,0,0,0,7,30,65,2,14,10,130,8,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,4,"Mine Dispenser 130",4,6,0,0,0,0,12,30,80,2,18,10,131,13,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,5,"Heavy Dispenser 50",5,5,0,0,0,0,3,10,50,2,20,5,135,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,6,"Heavy Dispenser 110",6,9,0,0,0,0,5,15,70,2,30,5,136,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,7,"Heavy Dispenser 200",7,14,0,0,0,0,7,20,90,2,45,5,137,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,8,"Speed Trap 20",8,0,0,2,0,0,2,100,60,30,0,12,132,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,9,"Speed Trap 30",9,0,0,3,0,0,6,135,72,32,0,14,133,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,10,"Speed Trap 50",10,0,0,5,0,0,11,140,80,40,0,15,134,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,1,"Colonization Module",1,0,0,0,0,0,0,32,10,12,10,10,106,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,2,"Orbital Construction Module",2,0,0,0,0,0,0,50,20,20,15,15,107,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,3,"Cargo Pod",3,0,0,0,3,0,0,5,10,5,0,2,96,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,4,"Super Cargo Pod",4,3,0,0,9,0,0,7,15,8,0,2,97,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,5,"Multi Cargo Pod",5,5,0,0,11,5,0,9,25,12,0,3,118,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,6,"Fuel Tank",6,0,0,0,0,0,0,3,4,6,0,0,104,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,7,"Super Fuel Tank",7,6,0,4,14,0,0,8,8,8,0,0,105,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,8,"Maneuvering Jet",8,2,0,3,0,0,0,5,10,5,0,5,102,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,9,"Overthruster",9,5,0,12,0,0,0,5,20,10,0,8,103,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,10,"Jump Gate",10,16,0,20,20,16,0,10,40,0,0,50,208,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,11,"Beam Deflector",11,6,6,0,6,6,0,1,8,0,0,10,209,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,1,"Transport Cloaking",1,0,0,0,0,0,0,1,3,2,0,2,98,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,2,"Stealth Cloak",2,2,0,0,0,5,0,2,5,2,0,2,99,70,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,3,"Super-Stealth Cloak",3,4,0,0,0,10,0,3,15,8,0,8,100,140,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,4,"Ultra-Stealth Cloak",4,10,0,0,0,12,0,5,25,10,0,10,101,540,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,5,"Multi Function Pod",5,11,0,11,0,11,0,2,15,5,0,5,189,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,6,"Battle Computer",6,0,0,0,0,0,0,1,6,0,0,15,165,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,7,"Battle Super Computer",7,5,0,0,0,11,0,1,14,0,0,25,166,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,8,"Battle Nexus",8,10,0,0,0,19,0,1,15,0,0,30,167,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,9,"Jammer 10",9,2,0,0,0,6,0,1,6,0,0,2,120,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,10,"Jammer 20",10,4,0,0,0,10,0,1,20,1,0,5,121,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,11,"Jammer 30",11,8,0,0,0,16,0,1,20,1,0,6,122,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,12,"Jammer 50",12,16,0,0,0,22,0,1,20,2,0,7,123,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,13,"Energy Capacitor",13,7,0,0,0,4,0,1,5,0,0,8,127,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,14,"Flux Capacitor",14,14,0,0,0,8,0,1,5,0,0,8,190,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,15,"Energy Dampener",15,14,0,8,0,0,0,2,50,5,10,0,124,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,16,"Tachyon Detector",16,8,0,0,0,14,0,1,70,1,5,0,125,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,17,"Anti-matter Generator",17,0,12,0,0,0,7,10,10,8,3,3,126,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,1,"Mole-skin Shield",1,0,0,0,0,0,0,1,4,1,0,1,42,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,2,"Cow-hide Shield",2,3,0,0,0,0,0,1,5,2,0,2,43,40,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,3,"Wolverine Diffuse Shield",3,6,0,0,0,0,0,1,6,3,0,3,44,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,4,"Croby Sharmor",4,7,0,0,4,0,0,10,15,7,0,4,40,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,5,"Shadow Shield",5,7,0,0,0,3,0,2,7,3,0,3,41,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,6,"Bear Neutrino Barrier",6,10,0,0,0,0,0,1,8,4,0,4,45,100,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,7,"Langston Shell",7,12,0,9,0,9,0,10,20,10,2,6,183,125,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,8,"Gorilla Delagator",8,14,0,0,0,0,0,1,11,5,0,6,46,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,9,"Elephant Hide Fortress",9,18,0,0,0,0,0,1,15,8,0,10,47,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,10,"Complete Phase Shield",10,22,0,0,0,0,0,1,20,12,0,15,119,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,1,"Bat Scanner",1,0,0,0,0,0,0,2,1,1,0,1,59,0,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,2,"Rhino Scanner",2,0,0,0,0,1,0,5,3,3,0,2,48,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,3,"Mole Scanner",3,0,0,0,0,4,0,2,9,2,0,2,49,100,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,4,"DNA Scanner",4,0,0,3,0,0,6,2,5,1,1,1,52,125,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,5,"Possum Scanner",5,0,0,0,0,5,0,3,18,3,0,3,61,150,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,6,"Pick Pocket Scanner",6,4,0,0,0,4,4,15,35,8,10,6,56,80,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,7,"Chameleon Scanner",7,3,0,0,0,6,0,6,25,4,6,4,63,160,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,8,"Ferret Scanner",8,3,0,0,0,7,2,2,36,2,0,8,53,185,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,9,"Dolphin Scanner",9,5,0,0,0,10,4,4,40,5,5,10,54,220,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,10,"Gazelle Scanner",10,4,0,0,0,8,0,5,24,4,0,5,50,225,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,11,"RNA Scanner",11,0,0,5,0,0,10,2,20,1,1,2,60,230,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,12,"Cheetah Scanner",12,5,0,0,0,11,0,4,50,3,1,13,62,275,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,13,"Elephant Scanner",13,6,0,0,0,16,7,6,70,8,5,14,55,300,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,14,"Eagle Eye Scanner",14,6,0,0,0,14,0,3,64,3,2,21,51,335,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,15,"Robber Baron Scanner",15,10,0,0,0,15,10,20,90,10,10,10,57,220,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,16,"Peerless Scanner",16,7,0,0,0,24,0,4,90,3,2,30,58,500,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,1,"Tritanium",1,0,0,0,0,0,0,60,10,5,0,0,64,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,2,"Crobmnium",2,0,0,0,3,0,0,56,13,6,0,0,65,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,3,"Carbonic Armor",3,0,0,0,0,0,4,25,15,0,0,5,70,100,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,4,"Strobnium",4,0,0,0,6,0,0,54,18,8,0,0,68,120,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,5,"Organic Armor",5,0,0,0,0,0,7,15,20,0,0,6,71,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,6,"Kelarium",6,0,0,0,9,0,0,50,25,9,1,0,67,180,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,7,"Fielded Kelarium",7,4,0,0,10,0,0,50,28,10,0,2,78,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,8,"Depleted Neutronium",8,0,0,0,10,3,0,50,28,10,0,2,79,200,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,9,"Neutronium",9,0,0,0,12,0,0,45,30,11,2,1,69,275,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,10,"Mega Poly Shell",10,14,0,0,14,14,6,20,65,18,6,6,110,400,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,11,"Valanium",11,0,0,0,16,0,0,40,50,15,0,0,66,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,12,"Superlatanium",12,0,0,0,24,0,0,30,100,25,0,0,77,1500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,1,"Settler's Delight",1,0,0,0,0,0,0,2,2,1,0,1,8,1,0,0,0,0,0,0,0,140,275,480,576,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,2,"Quick Jump 5",2,0,0,0,0,0,0,4,3,3,0,1,0,0,0,0,25,100,100,100,180,500,800,900,1080,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,3,"Fuel Mizer",3,0,0,2,0,0,0,6,11,8,0,0,9,3,0,0,0,0,0,35,120,175,235,360,420,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,4,"Long Hump 6",4,0,0,3,0,0,0,9,6,5,0,1,1,0,0,0,20,60,100,100,105,450,750,900,1080,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,5,"Daddy Long Legs 7",5,0,0,5,0,0,0,13,12,11,0,3,2,0,0,0,20,60,70,100,100,110,600,750,900,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,6,"Alpha Drive 8",6,0,0,7,0,0,0,17,28,16,0,3,3,0,0,0,15,50,60,70,100,100,115,700,840,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,7,"Trans-Galactic Drive",7,0,0,9,0,0,0,25,50,20,20,9,4,0,0,0,15,35,45,55,70,80,90,100,120,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,8,"Interspace-10",8,0,0,11,0,0,0,25,60,18,25,10,12,5,0,0,10,30,40,50,60,70,80,90,100,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,9,"Enigma Pulsar",9,7,0,13,5,9,0,20,40,12,15,11,109,6,0,0,0,0,0,0,65,75,85,95,105,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,10,"Trans-Star 10",10,0,0,23,0,0,0,5,10,3,0,3,117,0,0,0,5,15,20,25,30,35,40,45,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,11,"Radiating Hydro-Ram Scoop",11,2,0,6,0,0,0,10,8,3,2,9,7,2,0,0,0,0,0,0,0,165,375,600,720,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,12,"Sub-Galactic Fuel Scoop",12,2,0,8,0,0,0,20,12,4,4,7,5,0,0,0,0,0,0,0,85,105,210,380,456,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,13,"Trans-Galactic Fuel Scoop",13,3,0,9,0,0,0,19,18,5,4,12,6,0,0,0,0,0,0,0,0,88,100,145,174,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,14,"Trans-Galactic Super Scoop",14,4,0,12,0,0,0,18,24,6,4,16,10,0,0,0,0,0,0,0,0,0,65,90,108,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,15,"Trans-Galactic Mizer Scoop",15,4,0,16,0,0,0,11,20,5,2,13,11,0,0,0,0,0,0,0,0,0,0,70,84,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,16,"Galaxy Scoop",16,5,0,20,0,0,0,8,12,4,2,9,191,4,0,0,0,0,0,0,0,0,0,0,60,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
 


