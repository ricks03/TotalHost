# StarsBlock.pm
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
# 191123 Added subs for other block data
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

# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

# StarsPWD and StarsRace are both integrated into TotalHost
# StarsClean implemented in TotalHost (clean .m files)
# StarsMsg not implemented in TotalHost
# StarsFix implemented (fox .x files)

# Here is a list of blocks and their types I found so far. I’ve never met several of them in any game file, which I can access to, but you can try to find them in your own game files using this small command line tool (there is no decryption code, since block headers are never encrypted), and please if you find them let me know:
# https://wiki.starsautohost.org/wiki/Technical_Information
# 0	FileFooterBlock (Year: .M, .HST   Checksum XOR .R, null .X, .H) 
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
# 36	ChangePasswordBlock (.x), Password (.HST)
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
#use TotalHost;
do 'config.pl';

require Exporter;
our @ISA = qw(Exporter);
# Don't stick comments in the Export array.
# Don't use commas
our @EXPORT = qw( 
  StarsPWD
  nextRandom StarsRandom
  initDecryption getFileHeaderBlock getFileFooterBlock   getFileFooter
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
  showHab showLeftoverPoints
  showResearchCost showExpensiveTechStartsAt3
  showPlayerRelations
  showResearchPriority
  showPRT showLRT
  showFactoriesCost1LessGerm
  showMTItems
  decodeBytesForStarsString decodeBytesForStarsMessage
  getPlayers resetPlayers
  resetRace showRace
  StarsClean decryptClean
  StarsFix decryptFix
  StarsAI decryptAI
  zerofy splitWarnId attackWho
  showCategory
  getMask
  PLogOut
  shiftBytes unshiftBytes
);  

my $debug = 1;

#############################################
sub StarsPWD {
#  my ($GameFile, $Player) = @_;
  my ($File) = @_;   # .m File is full file path
  use File::Copy;
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
  
#  my $MFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.m' . $Player;
  &PLogOut(300, "Password Reset Started for : $File", $LogFile);
#   # Backup the current .m file
# 	my $Backup_Destination_File   = $MFile . '.bak';
# 	copy($MFile, $Backup_Destination_File);
# 	&PLogOut(100,"Copy $MFile to $Backup_Destination_File",$LogFile);
   
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
  open (OutFile, '>:raw', "$File");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
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
  my (@fileBytes) = @_; # Expecting to get an entire .M file
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

# sub parseBlock {
#   # This returns the 3 relevant parts of a block: typeId, size, raw block data
#   my ($fileBytes, $offset) = @_;
#   my @fileBytes = @{ $fileBytes };
#   my @blockdata;
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
#   for (my $i = $offset+2; $i < $offset+$blocksize+2; $i++) {   #skipping over the typeId
#     push @blockdata, $fileBytes[$i];
#   }
#   return ($blocktype, $blocksize, \@blockdata);
# } 

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
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $pwdreset = 0;
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    &PLogOut(400, "BLOCK typeId: $typeId, Offset: $offset, Size: $size", $LogFile);
    my $BlockRaw = "BLOCK RAW: Size " . @block . ":\n" . join ("", @block);
    &PLogOut(400, $BlockRaw, $LogFile);
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } elsif ($typeId == 7) {
      # Note that planet's data requires something extra to decrypt. 
      # Fortunately block 7 isn't in my test files
      &PLogOut(0, "BLOCK 7 found. ERROR!", $ErrorLog); die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      &PLogOut(400, "DATA DECRYPTED:" . join (" ", @decryptedData), $LogFile);
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
# So apparently there are player blocks from other players in the .M file, and
# If you reset the password in those you corrupt at the very least the player race name 
#        if (($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) {
        # BUG: Fixing for only PlayerID = Player blocks will break for .HST
        my $playerId = $decryptedData[0] & 0xFF; 
        if ((($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) && ($playerId == $Player)){
          &PLogOut(200,"Block $offset password blanked for M File", $LogFile);
          print "Block $offset password blanked for M File\n";
          # Replace the password with blank
          $decryptedData[12] = 0;
          $decryptedData[13] = 0;
          $decryptedData[14] = 0;
          $decryptedData[15] = 0;  
          $pwdreset = 1;
        } else { 
#           if ($playerId != $Player) { print "Block $offset is for another player!\n"; }
#           # BUG: In .HST some Player blocks could be password protected, and some not
#           else { print "Block $offset isn't password-protected!\n"; }
# BUG: This prevents this from working when there's more than one Type 6 block, and
# the first one doesn't have a password.
#          return 0;
        }
      }
      if ($typeId == 36) { # .x file Change Password Block
        if (($decryptedData[0]  != 0) | ($decryptedData[1] != 0) | ($decryptedData[2] != 0) | ($decryptedData[3] != 0)) {
          &PLogOut(200,"Block $offset password blanked for X File", $LogFile);
          # Replace the password with blank
          $decryptedData[0] = 0;
          $decryptedData[1] = 0;
          $decryptedData[2] = 0;
          $decryptedData[3] = 0; 
          $pwdreset = 1;
        } 
      }
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      &PLogOut(400, "BLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), $LogFile); 
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  # If the password was not reset, no need to write the file back out
  # Faster, less risk of corruption
  if ( $pwdreset ) { return \@outBytes; }
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
  # unpredictably. But I can't ge the math to work out. 
   
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

sub displayBlockRace {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
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

    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
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
        if ($debug > 3) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        if ($debug > 3) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        my $playerId = $decryptedData[0] & 0xFF; # Always 255 in a race file
        my $shipDesigns = $decryptedData[1] & 0xFF;  # Always 0
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); # Always 0
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  # Always 0
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); # always 0
        my $logo = (($decryptedData[6] & 0xFF) >> 3); 
        my $fullDataFlag = ($decryptedData[6] & 0x04); # Always true
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
        my $singularRaceName = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        my $pluralRaceName = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        
        if ($fullDataFlag) { 
          my $homeWorld = &read16(\@decryptedData, 8); # no homeworld in race file
#          print "Homeworld: $homeWorld\n";
          # BUG: the references say this is two bytes, but I don't think it is.
          # That means I don't know what byte 11 is tho. 
          #my $rank = &read16(\@decryptedData, 10);
          my $rank = $decryptedData[10]; # Always 0;
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
          my $energyLevel           = $decryptedData[26]; #Always 0 in race file
          my $weaponsLevel          = $decryptedData[27]; #Always 0 in race file
          my $propulsionLevel       = $decryptedData[28]; #Always 0 in race file
          my $constructionLevel     = $decryptedData[29]; #Always 0 in race file
          my $electronicsLevel      = $decryptedData[30]; #Always 0 in race file
          my $biotechLevel          = $decryptedData[31]; #Always 0 in race file
          # print "Tech Level: $energyLevel, $weaponsLevel, $propulsionLevel, $constructionLevel, $electronicsLevel, $biotechLevel\n";    
          my $energyLevelPointsSincePrevLevel         = $decryptedData[32]; # (4 bytes) #Always 0 in race file
          my $weaponsLevelPointsSincePrevLevel        = $decryptedData[36]; # (4 bytes) #Always 0 in race file
          my $propulsionLevelPointsSincePrevLevel     = $decryptedData[42]; # (4 bytes) #Always 0 in race file
          my $constructionLevelPointsSincePrevLevel   = $decryptedData[46]; # (4 bytes) #Always 0 in race file
          my $electronicsLevelPointsSincePrevLevel     = $decryptedData[50]; # (4 bytes) #Always 0 in race file
          my $biologyLevelPointsSincePrevLevel         = $decryptedData[54]; # (4 bytes) #Always 0 in race file
#          print "Tech Points: $energyLevelPointsSincePrevLevel, $weaponsLevelPointsSincePrevLevel, $propulsionLevelPointsSincePrevLevel, $constructionLevelPointsSincePrevLevel, $electronicsLevelPointsSincePrevLevel, $biologyLevelPointsSincePrevLevel \n";
          my $researchPercentage    = $decryptedData[56]; # defaults to 15
#          print "Research Percentage: $researchPercentage\n"; 
          my $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]  #Always 0 in race file
#          print "Research Priority: " . &showResearchPriority($currentResourcePriority) . "\n";
          my $nextResourcePriority  = $decryptedData[57] & 0x04; # (left 4 bits) #Always 0 in race file
#          print "Next Priority: " . &showResearchPriority($nextResourcePriority) . "\n";
          my $researchPointsPreviousYear = $decryptedData[58]; # (4 bytes) #Always 0 in race file
#          print "researchPointsPreviousYear: $researchPointsPreviousYear\n";
          my $resourcePerColonist = $decryptedData[62]; # ? 55? 
          my $producePerFactory = $decryptedData[63];
          my $toBuildFactory = $decryptedData[64];
          my $operateFactory = $decryptedData[65];
          my $producePerMine = $decryptedData[66];
          my $toBuildMine = $decryptedData[67];
          my $operateMine = $decryptedData[68];
          my $spendLeftoverPoints = $decryptedData[69]; # ?  (3:factories)  
          my $researchEnergy        = $decryptedData[70]; # (0:+75%, 1: 0%, 2:-50%) 
          my $researchWeapons       = $decryptedData[71]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchProp          = $decryptedData[72]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchConstruction  = $decryptedData[73]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchElectronics   = $decryptedData[74]; # (0:+75%, 1: 0%, 2:-50%)
          my $researchBiotech       = $decryptedData[75]; # (0:+75%, 1: 0%, 2:-50%)
          my $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
          #$decryptedData[77]; unknown , always 0
          my $LRT =  $decryptedData[78]  + ($decryptedData[79] * 0x100); 
          my @LRTs = &showLRT($LRT);
          my $checkBoxes = $decryptedData[81]; 
            #<Unknown bits="5"/> 
            my $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
            # Unknown bit 6
            my $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
          my $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100); #Always 0 in race file
#          my @MTItems = &showMTItems($MTItems);
#          print "MT Items: " . join(',',@MTItems) . "\n";
          #$decryptedData[82-109]; unknown, but in pairs
          # Interestingly, if the player relations have never been set, the
          # player relations length will be 0, with no bytes after it
          # For the player relations values
          # So the result here CAN be 0.
          my $playerRelationsLength = $decryptedData[112]; #Always 0 in race file
#           if ( $playerRelationsLength ) { 
#             for (my $i = 1; $i <= $playerRelationsLength; $i++) {
#               my $id = $i-1;
#               if ($id == $playerId) { next; } # Skip for self
#               print "Player " . $id . ": " . &showPlayerRelations($decryptedData[$i+112]) . "\n";
#             } 
#           } else { print "Player Relations never set\n"; }
          print "<img src=\"$WWW_Image" . "logo" . $logo . ".png\">\n";
          print "<P>$singularRaceName:$pluralRaceName\n"; 
          print "<P><u>Spend Leftover Points</u>: " . &showLeftoverPoints($spendLeftoverPoints) . "\n";
          print "<P><u>PRT</u>: " . &showPRT($PRT) . "\n";
          print "<P><u>LRTs:</u> " . join(', ',@LRTs) . "\n";
          print "<P>Grav: " . &showHab($lowGravity,$centreGravity,$highGravity, 0) . ", Temp: " . &showHab($lowTemperature,$centreTemperature,$highTemperature,1) . ", Rad: " . &showHab($lowRadiation,$centreRadiation,$highRadiation,2) . ", Growth: $growthRate\%\n"; 
          print "<P><u>Productivity</u>: Colonist " . $resourcePerColonist*100 .", Factory: Produce $producePerFactory, Cost To Build $toBuildFactory, May Operate $operateFactory, Mine: Produce $producePerMine, Resources to Build $toBuildMine, May Operate $operateMine\n";
          print "<P>FactoriesCost1LessGerm: " . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          print "<P><u>Research Cost</u>:  Energy " . &showResearchCost($researchEnergy) . ", Weapons " . &showResearchCost($researchWeapons) . ", Propulsion " . &showResearchCost($researchProp). ", Construction " . &showResearchCost($researchConstruction) . ", Electronics " . &showResearchCost($researchElectronics) . ", Biotech " . &showResearchCost($researchBiotech) . "\n";
          print "<P>Expensive Tech Starts at 3: " . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
        }
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
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

sub showHab {
  my ($low,$center,$high, $type) = @_;
  my @habBase = qw ( .12 -200 0) ; #The starting value for each hab range
  my @habIncrement = qw (.24 4 1 ) ; # The size of the hab increment
  my ($lowFixed, $centerFixed, $highFixed); 
  if ($center == 255) {return "Immune"; }
  else { 
    $lowFixed = ($low * @habIncrement[$type]) + $habBase[$type];
    $centerFixed = ($center * @habIncrement[$type]) + $habBase[$type];
    $highFixed = ($high * @habIncrement[$type]) + $habBase[$type]; # Radiation is simple
  }
 return "$low/$center/$high  (in clicks)"; 
}

sub showLeftoverPoints {
   my ($points) = @_;
   my @Leftover = qw ( SurfaceMinerals MineralConcentrations Mines Factories Defenses );
   return $Leftover[$points];
}

sub showResearchCost {
#(0:+75%, 1: 0%, 2:-50%) 
   my ($value) = @_;
   if    ($value eq '2') {     return '-50%';
   } elsif  ($value eq '1') {  return 'Standard'; 
   } else {                  return '+75%'; }
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

#Duplicate of decodeBytesforStarsMsg ??
sub decodeBytesForStarsString {
  my (@res) = @_;
  my $hexChars='';
  my ($b, $b1,$b2, $firstChar, $secondChar);
  my ($ch1, $ch2, $index, $result);
  #$hexDigits      = "0123456789ABCDEF";
  my $encodesOneByte = " aehilnorst";
  my $encodesB       = "ABCDEFGHIJKLMNOP";
  my $encodesC       = "QRSTUVWXYZ012345";
  my $encodesD       = "6789bcdfgjkmpquv";
  my $encodesE       = "wxyz+-,!.?:;\'*%\$";

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

# Duplicate of forStarsString?
sub decodeBytesForStarsMessage {
  my (@res) = @_;
  my $hexChars='';
  my ($b, $b1,$b2, $firstChar, $secondChar);
  my ($ch1, $ch2, $index, $result);
  #$hexDigits      = "0123456789ABCDEF";
  my $encodesOneByte = " aehilnorst";
  my $encodesB       = "ABCDEFGHIJKLMNOP";
  my $encodesC       = "QRSTUVWXYZ012345";
  my $encodesD       = "6789bcdfgjkmpquv";
  my $encodesE       = "wxyz+-,!.?:;\'*%\$";

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
 	for (my $loop = 0; $loop < 16; $loop++){
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
 	for (my $loop = 0; $loop < 16; $loop++){
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
    if ($debug ) {print "Player Relations Length $playerRelationsLength\n"; }
    if ($playerRelationsLength) {
      for (my $i = 1; $i <= $playerRelationsLength; $i++) {
        $decryptedBytes[112+$i] = 0;
      }
    }
  }
  return @decryptedBytes;
}

sub showRace {
  my ($decryptedData, $size) = @_;
  my @decryptedData = @{$decryptedData};
  my $raceData = '';
  my $playerId = $decryptedData[0] & 0xFF;
  my $shipDesigns = $decryptedData[1] & 0xFF;
  my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8);
  my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);
  my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4);
  my $logo = (($decryptedData[6] & 0xFF) >> 3);
  my $fullDataFlag = ($decryptedData[6] & 0x04);
  # Byte 7 unknown
  #   The 2s bit is 0 for Player, 1 for Human(inactive)
  #   bits 6,7,8 also flip changed to human(inactive)  but don't flip back
  # We figure out names here, because they're here at 8 when not fullDataFlag 
  my $index = 8; 
  my $playerRelations;
  if ($fullDataFlag) { 
    # The player names are at the end and are not a fixed length,
    # The number of player relations bytes change where the names start   
    # That also changes whether it's a fullData set or not. 
    # PlayerRelationsLength is also number of players
    #   except when it's not. If PR has never been changed, PRL will be 0.
    $index = 112;
    my $playerRelationsLength = $decryptedData[112]; 
    $index = $index + $playerRelationsLength + 1;
  }  
  my $singularNameLength = $decryptedData[$index] & 0xFF;
  my $singularMessageEnd = $index + $singularNameLength;
  my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
  $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
  $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
  $raceData = "playerID: $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
  
  if ($fullDataFlag) { 
    my $homeWorld = &read16(\@decryptedData, 8);
#    my $rank = &read16(\@decryptedData, 10);
# BUG: the references say this is two bytes, but I don't think it is.
# That means I don't know what byte 11 is tho. 
    my $rank = $decryptedData[10];
    # Bytes 12..15 are the password;
    # They change to 255 255 255 255 when in Human(inactive) mode.
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
      # Worth noting all of these are +18 when in the fullDataFlag
    my $energyLevel           = $decryptedData[26];
    my $weaponsLevel          = $decryptedData[27];
    my $propulsionLevel       = $decryptedData[28];
    my $constructionLevel     = $decryptedData[29];
    my $electronicsLevel      = $decryptedData[30];
    my $biotechLevel          = $decryptedData[31];
    my $energyLevelPointsSincePrevLevel         = $decryptedData[32]; # (4 bytes) 
    my $weaponsLevelPointsSincePrevLevel        = $decryptedData[36]; # (4 bytes) 
    my $propulsionLevelPointsSincePrevLevel     = $decryptedData[42]; # (4 bytes) 
    my $constructionLevelPointsSincePrevLevel   = $decryptedData[46]; # (4 bytes) 
    my $electronicsLevelPointsSincePrevLevel     = $decryptedData[50]; # (4 bytes)
    my $biologyLevelPointsSincePrevLevel         = $decryptedData[54]; # (4 bytes)
    my $researchPercentage    = $decryptedData[56];
    my $currentResourcePriority = $decryptedData[57] >> 4; # (right 4 bits) [same, energy ..., lowest]
    my $nextResourcePriority  = $decryptedData[57] & 0x04; # (left 4 bits)
    my $researchPointsPreviousYear = $decryptedData[58]; # (4 bytes)
    my $resourcePerColonist = $decryptedData[62]; # ? 55? 
    my $producePerFactory = $decryptedData[63];
    my $toBuildFactory = $decryptedData[64];
    my $operateFactory = $decryptedData[65];
    my $producePerMine = $decryptedData[66];
    my $toBuildMine = $decryptedData[67];
    my $operateMine = $decryptedData[68];
    $raceData .=  "Productivity: Colonist: $resourcePerColonist, Factory: $producePerFactory, $toBuildFactory, $operateFactory, Mine: $producePerMine, $toBuildMine, $operateMine\n";
    my $spendLeftoverPoints = $decryptedData[69]; # ?  (3:factories)  
    $raceData .= "Spend Leftover Points On: " . &showLeftoverPoints($spendLeftoverPoints) . "\n"; 
    my $researchEnergy        = $decryptedData[70]; # (0:+75%, 1: 0%, 2:-50%) 
    my $researchWeapons       = $decryptedData[71]; # (0:+75%, 1: 0%, 2:-50%)
    my $researchProp          = $decryptedData[72]; # (0:+75%, 1: 0%, 2:-50%)
    my $researchConstruction  = $decryptedData[73]; # (0:+75%, 1: 0%, 2:-50%)
    my $researchElectronics   = $decryptedData[74]; # (0:+75%, 1: 0%, 2:-50%)
    my $researchBiotech       = $decryptedData[75]; # (0:+75%, 1: 0%, 2:-50%)
    $raceData .= "Research Cost:  " . &showResearchCost($researchEnergy) . ", " . &showResearchCost($researchWeapons) . ", " . &showResearchCost($researchProp). ", " . &showResearchCost($researchConstruction) . ", " . &showResearchCost($researchElectronics) . ", " . &showResearchCost($researchBiotech) . "\n";
    my $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
    $raceData .= "PRT: " . &showPRT($PRT) . "\n";
    #$decryptedData[77]; unknown , always 0?
    my $LRT =  $decryptedData[78]  + ($decryptedData[79] * 0x100); 
    my @LRTs = &showLRT($LRT);
    $raceData .= "LRTs: " . join(',',@LRTs) . "\n";
    my $checkBoxes = $decryptedData[81]; 
      #Unknown bits="5" 
      my $expensiveTechStartsAt3 = &bitTest($checkBoxes, 5);
      # Unknown bit 6
      my $factoriesCost1LessGerm = &bitTest($checkBoxes, 7);
    $raceData .= "Expensive Tech Starts at 3: " . &showExpensiveTechStartsAt3($expensiveTechStartsAt3) . "\n";
    $raceData .= "FactoriesCost1LessGerm: " . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
    my $MTItems =  $decryptedData[82] + ($decryptedData[83] * 0x100);
    my @MTItems = &showMTItems($MTItems);
    $raceData .= "MT Items: " . join(',',@MTItems) . "\n";
    #$decryptedData[82-109]; unknown, but in pairs  
    # Interestingly, if the player relations have never been set, the
    #  player relations length will be 0, with no bytes after it
    #  for the player relations values
    #  so the result here CAN be 0.
    my $playerRelationsLength = $decryptedData[112];
    if ( $playerRelationsLength ) { 
      for (my $i = 1; $i <= $playerRelationsLength; $i++) {
        my $id = $i -1;
        if ($id == $playerId) { next; } # Skip for self
        $raceData .= "Player " . $id . ": " . &showPlayerRelations($decryptedData[$i+112]) . "\n";
      } 
    } else { $raceData .= "Player Relations never set\n"; }
  }
  $raceData .= "\n";
  return $raceData;
}

# sub StarsMsg {
#   my ($GameFile, $Player) = @_;
# 
#     # Displays Stars! Messages
#     # Displays Block 40 - Message Block
#     # Derived from decryptor.py and decryptor.java from
#     # https://github.com/stars-4x/starsapi  
#     
#     use File::Basename;  # Used to get filename components
#     my $debug = 0; # Enable better debugging output. Bigger the better
#     
#     my $filename = $GameFile;
#     
#     #Validate directory or file 
#     unless (-e $inName ) { 
#       print "Requested object $inName does not exist!\n"; exit; 
#     }
#         
#     # Read in the binary Stars! file, byte by byte
#     my $FileValues;
#     my @fileBytes;
#     open(StarFile, "<$filename" );
#     binmode(StarFile);
#     while ( read(StarFile, $FileValues, 1)) {
#       push @fileBytes, $FileValues; 
#     }
#     close(StarFile);
#     
#     # Decrypt the data, block by block
#     my ($outBytes) = &decryptMsg(@fileBytes);
# }
# 
# sub decryptMsg {
#   my (@fileBytes) = @_;
#   my @block;
#   my @data;
#   my ($decryptedData, $encryptedBlock, $padding);
#   my @decryptedData;
#   my @encryptedBlock;
#   my @outBytes;
#   my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
#   my ($random, $seedA, $seedB, $seedX, $seedY );
#   my ( $FileValues, $typeId, $size );
#   my $offset = 0; #Start at the beginning of the file
#   while ($offset < @fileBytes) {
#     # Get block info and data
#     $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
#     ( $typeId, $size ) = &parseBlock($FileValues, $offset);
#     @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
#     @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
# 
#     if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
#     # FileHeaderBlock, never encrypted
#     if ($typeId == 8 ) {
#       # We always have this data before getting to block 6, because block 8 is first
#       # If there are two (or more) block 8s, the seeds reset for each block 8
#       ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
#       ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
#    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
#     } else {
#       # Everything else needs to be decrypted
#       ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
#       @decryptedData = @{ $decryptedData };  
#       # WHERE THE MAGIC HAPPENS
#       # Display the messages in the file
#       my ($decryptedData,$typeId,$offset,$size)  = @_;
#       my @decryptedData = @{ $decryptedData };
#       # We need the names to display
#       # although there are no names in .x files
#       if ($typeId == 6) { #Check the Player Block so we can get the race names
#         my $playerId = $decryptedData[0];
#         my $fullDataFlag = ($decryptedData[6] & 0x04);
#         my $index = 8;
#         if ($fullDataFlag) { 
#           # The player names are at the end which is not a fixed length
#           $index = 112;
#           my $playerRelationsLength = $decryptedData[112]; 
#           $index = $index + $playerRelationsLength + 1;
#         } 
#         my $singularNameLength = $decryptedData[$index] & 0xFF;
#         my $singularMessageEnd = $index + $singularNameLength;
#         my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
#         $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
#         $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
#         print "playerName $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
#       } elsif ($typeId == 40) { # check the Message block 
#         my $byte0 =  &read16(\@decryptedData, 0);  # unknown
#         my $byte2 =  &read16(\@decryptedData, 2);  # unknown
#         my $senderId = &read16(\@decryptedData, 4);
#         my $recipientId = &read16(\@decryptedData, 6);
#         my $byte8 =  &read16(\@decryptedData, 8); # unknown
#         my $messageBytes = &read16(\@decryptedData, 10);
#         my $messageLength = $size -1;
#         my $message = &decodeBytesForStarsMessage(@decryptedData[11..$messageLength]);
#         if ($debug) { print "typeId: $typeId\n"; }
#         if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
#         print "From: $senderId, To: $recipientId, \"$message\"\n"; 
#         if ($debug) { print "b0: $byte0, b2: $byte2, b8: $byte8\n"; }
#       }
#       # END OF MAGIC
#     }
#     $offset = $offset + (2 + $size); 
#   }
# }

sub StarsClean {
  my ($GameFile) = @_;
  # Removes shared "privileged" information from a .M file for TotalHost
#  my $cleanFiles = 1; # 0, 1, 2: display, clean but don't write, write. See config.pl
  my @mFiles;      
  my $filename;
  my $inDir = $FileHST . "\\" . $GameFile;
  
  #Validate directory 
  unless (-d $inDir  ) { 
    &PLogOut(0,"StarsClean: Failed to find $inDir for cleaning $GameFile", $ErrorLog);
  }
  
  # Get all the file names in the directory
  # Reading the dir is easier than figuring out the number of players in the game
  opendir(BIN, $inDir) or &PLogOut(0,"StarsClean: Failed to open $inDir for cleaning $GameFile", $ErrorLog);
  my $file;
  my $fullName;
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
    $fullName = $inDir . '\\' . $file;
    push @mFiles, $fullName;
  }
  if (@mFiles == 0) { &PLogOut(0,"StarsClean: Failed to find any files in $inDir for cleaning $GameFile", $ErrorLog); }

  foreach my $mFile (@mFiles) {
    &PLogOut(100,"StarsClean: cleaning $mFile in $GameFile", $LogFile);
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
    my @outBytes = @{$outBytes};
    
    # Output the Stars! file with modified data
    # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
    if ($needsCleaning) {
      # Backup the file before we clean it
      # Because otherwise we can't get back to where we were, as the actual
      # backup is pre-turn generation, so random event will change.
      # BUG: File name is important here, as backups work from the filename
      #   So do we want these to be .m files?

      my $mFilePreclean = "preclean." . $mFile;
	    &PLogOut(300,"StarsClean Backup: $mFile > $mFilePreclean", $LogFile);
 	    copy($mFile, $mFilePreclean);
      &PLogOut(200," StarsClean: Pushing out $mFile post-cleaning for $GameFile", $LogFile);
      open ( outFile, '>:raw', "$mFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print outFile $outBytes[$i];
      }
      close ( outFile);
      &PLogOut(200," StarsClean: Cleaned $mFile for $GameFile", $LogFile);
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
  my $needsCleaning = 0;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
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

  my $LogOutput;

  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 43 ) { $debug = 1;  } else { $debug = 0;}
    # FileHeaderBlock, never encrypted
    if ($typeId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      unless ($Magic eq 'J3J3') { &PLogOut(100,"decryptClean: One of the files is not a .M file. Stopped along the way.", $ErrorLog); }
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
      if ($typeId == 43) { # Check for special attributes in the Object Block
        if ($size == 2) {
          my $count = &read16(\@decryptedData, 0);
        } else {
          $objectId =  &read16(\@decryptedData, 0);
          $number = $objectId & 0x01FF;
          $owner = ($objectId & 0x1E00) >> 9;
          $type = $objectId >> 13;
          # Mystery Trader
          if (&isMT($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
      			$metBits = &read16(\@decryptedData, 12);
      			$itemBits = &read16(\@decryptedData, 14);
      			$turnNo = &read16(\@decryptedData, 16); # Which doesn't report turn like everything else
            $turnNoDisplay =  $turnNo + 2401;
            my $MTPart = &getMTPartName($itemBits);
            $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);

            if ($cleanFiles) { 
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
            $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);
          # Minefields
          } elsif (&isMinefield($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2); # 2 bytes
            $y = &read16(\@decryptedData, 4); # 2 bytes
            $canSee = &read16(\@decryptedData, 10);
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);
            if ($cleanFiles) {
              # Hard to find any data here as not much is known of the format
              # Reset players who can see the minefield
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $canSee = &read16(\@decryptedData, 10);
            }
            $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);
          #Wormholes
          } elsif (isWormhole($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
    	      $canSee = &read16(\@decryptedData, 8);
    	      $beenThrough = &read16(\@decryptedData, 10);
    	      $targetId = &read16(\@decryptedData, 12) % 4096;   
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);
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
            $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
            &PLogOut(100,"decryptClean: $LogOutput", $LogFile);
          } elsif (&isMinefield($type)) {
            # Packet
            # nothing decoded enough to clean
          } 
        }
      }
      if ($typeId == 6) { # Player Block
        my $PRT = $decryptedData[76];
        if ($PRT == 3) {
          # Reset the info the CA player can see
          $needsCleaning = 1;
          $LogOutput = &showRace(\@decryptedData,$size);
          &PLogOut(400,"decryptClean: $LogOutput", $LogFile);
          if ($cleanFiles) {   
            @decryptedData = &resetRace(\@decryptedData,$Player);
          }
          $LogOutput = &showRace(\@decryptedData,$size); 
          &PLogOut(400,"decryptClean: $LogOutput", $LogFile);
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

sub StarsFix {
  my ($xFile, $GameFile, $turn) = @_; # .x file location includes path   (Uploads)
  my $needsFixing = 0;
  my $queueCounter = 0;
  my %queueList;
  &PLogOut(100,"StarsFix: fixing .x: $xFile", $LogFile);
  
  #read in the .queue file for Cheap Starbase analysis  
  my $queueFile =  $FileHST . '\\' . $GameFile. '\\' . $GameFile . '.hst' . ".$turn" . '.queue';
  if (-e $queueFile ) { 
    my ($Player,$planetId,$itemId,$count,$completePercent,$itemType, $queueSize);
    my @queueFile;
    &PLogOut(200,"StarsFix: Reading in QUEUEFILE $queueFile", $LogFile);
    open (IN_FILE,$queueFile) || die("Cannot open $queueFile file");
    @queueFile = <IN_FILE>;
  	close IN_FILE;
    # Turn the file into a usable hash
    foreach my $line (@queueFile) {
    	chomp($line);
     	($Player,$planetId,$itemId,$count,$completePercent,$itemType, $queueSize)	= split (',', $line);
      # There is no unique combination of values for a queue
      # So using a faux-counter
      $queueList{$queueCounter}{Player} = $Player;
      $queueList{$queueCounter}{planetId} = $planetId;
      $queueList{$queueCounter}{itemId} = $itemId;
      $queueList{$queueCounter}{count} = $count;
      $queueList{$queueCounter}{completePercent} = $completePercent;
      $queueList{$queueCounter}{itemType} = $itemType;
      $queueList{$queueCounter}{queueSize} = $queueSize;
      $queueCounter++;
    }
  }
  
  # Read in the binary Stars! file(s), byte by byte
  my $fileValues;
  my @fileBytes;
  open(StarFile, "<$xFile" );
  binmode(StarFile);
  while ( read(StarFile, $fileValues, 1)) {
    push @fileBytes, $fileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my ($outBytes, $needsFixing, $warning) = &decryptFix(\@fileBytes,\%queueList);
  #my ($outBytes, $needsFixing, $warning) = &decryptFix(\%queueList);
  my @outBytes = @{$outBytes};
  my %warning = %$warning;
  
  # Need to return a string since passing an array through a URL is unlikely to work
  my $warning = '';
  foreach my $key (keys %warning) {
    $warning .= $warning{$key} . ',';
  }
  # Output the Stars! file with modified data
  # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
  if ($needsFixing) {
    # Backup the file before we clean it
    # Because otherwise we can't get back to where we were, as the
    # backup is pre-turn generation, so random event will change.
    # BUG: File name is important here, as backups work from the filename
    #   So do we want these to be .x files?
    if ($fixFiles > 1) {  # Don't do unless in write mode
      my $xFilePreFix = 'preFix.' . $xFile;
  	  &PLogOut(300,"StarsFix Backup: $xFile > $xFilePreFix", $LogFile);
   	  copy($xFile, $xFilePreclean);
      &PLogOut(200," StarsFix: Pushing out $xFile post-fixing", $LogFile);
      open ( outFile, '>:raw', "$xFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print outFile $outBytes[$i];
      }
      close ( outFile);
      &PLogOut(200," StarsFix: Fixed $xFile", $LogFile);
    } else { &PLogOut(300," StarsFix: Not in Fix mode for $xFile", $LogFile); }
    return $warning;
  } else { 
  	&PLogOut(300,"StarsFix: $xFile does not need fixing", $LogFile);
    return $warning; 
  }  
}

sub decryptFix {
  my ($fileBytes, $queueList) = @_;
  my @fileBytes = @{$fileBytes};
  my %queueList = %$queueList;

  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $needsFixing;
  my ($planetId, $ownerId); 
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    #if ( $debug  > 1) { print "BLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    #if ( $debug  > 1) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
    #if ($debug > 100) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
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
        my $playerId = $decryptedData[0] & 0xFF; 
        my $shipDesigns = $decryptedData[1] & 0xFF;  
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); 
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); 
        #print " Starbase Designs: $starbaseDesigns\n";
        $player{$playerId}{shipDesigns} = $shipDesigns;
        $player{$playerId}{planets} = $planets;
        $player{$playerId}{fleets} = $fleets;
        $player{$playerId}{starbaseDesigns} = $starbaseDesigns;
        $designShipTotal +=  $player{$playerId}{shipDesigns};
        $designBaseTotal +=  $player{$playerId}{starbaseDesigns};
        $lastPlayer = $playerId; # keep track of the largest known player Id
      } elsif ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .M and .HST file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
        ### Other stuff after I have the player ID
        my $flags = &read16(\@decryptedData, 2);
        my $isHomeworld = ($flags & 0x80) != 0;
        my $index = 4;
        # More in the block I don't care about right now.       
      } 
      # Detect the Cheap Starbase in the producton queue
      elsif ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
        # if not a .x file, we get the player Id from the most recent planet info
        # because the player info isn't in the ProductionQueueBlock 
        my $index = 0;
        my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
        if ($typeId == 28) { 
          $Player = $ownerId; 
          $index = 0;
       } elsif ($typeId == 29) { # Testing for ProductionQueueChangeBlock
          # planet ID is only in the ProductonQueueChangeBlock
          $planetId = &read16(\@decryptedData, 0);
          $index = 2;
        } 
        #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        if ($typeId == 29 ) {
          # Any change means erasing any old values for this planet
          foreach my $queueCounter (keys %queueList) {
            if (exists ($queueList{$queueCounter}{planetId}) ) { 
                  delete $queueList{$queueCounter}; 
            }
          }  
        }
        for (my $i=$index; $i <= scalar(@decryptedData) -4; $i=$i+4) {
          $chunk1 = &read16(\@decryptedData, $i);
          $chunk2 = &read16(\@decryptedData, $i+2);
          $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
          $count = $chunk1 & 0x3FF; # Bottom 10 bits
          $completePercent = $chunk2 >> 4; #Top 12 bits
          $itemType = $chunk2 & 0xF; # bottom 4 bits
          #print "Queue: Player: $Player, planetId: $planetId, itemId: $itemId, count: $count, %complete: $completePercent, itemType: $itemType, size: $size\n"; 
          $queueCounter++;
          $queueList{$queueCounter}{Player} = $Player;
          $queueList{$queueCounter}{planetId} = $planetId;
          $queueList{$queueCounter}{itemId} = $itemId;
          $queueList{$queueCounter}{count} = $count;
          $queueList{$queueCounter}{completePercent} = $completePercent;
          $queueList{$queueCounter}{itemType} = $itemType;
          $queueList{$queueCounter}{queueSize} = $size;
          # Store an copy that won't be modified
          $queueListHST{$queueCounter}= $queueList{$queueCounter};
        }
        if ($typeId == 29 && $size == 2) { # Clear Queue 
          # Need to clear the ProductionQueue array if this is a clear queue action
          # because we no longer care about what was in this production queue prior
          # If Cheap Starbase bug, clearing the planet queue fixes it.
          foreach my $queueCounter (keys %queueList) {
            if (exists ($queueList{$queueCounter}{planetId}) && $queueList{$queueCounter}{planetId} == $planetId) { 
              #print "CLEARING queue for planet: $queueList{$queueCounter}{planetId}\n";
              delete $queueList{$queueCounter}; 
            }
          }
        }
        # If we changed a queue, check the entire queue for any planets building on the warning
        # The warning list will be shorter, so start there. 
        foreach my $warnId (keys %warning) {
          my $stillBroken = 0;
          my ($player, $designType, $designNumber, $warningType) = &splitWarnId($warnId); 
          if ($warningType eq 'cheap') {
            my $designId = $designNumber + 16;
            foreach my $queueCounter (keys %queueList) {
              if ($queueList{$queueCounter}{Player} == $player &&  $queueList{$queueCounter}{itemId} == $designId) {
                $stillBroken = 1;
              }
            }
          }
          unless ($stillBroken) {
            if (exists ($warning{$warnId}) && $warningType eq 'cheap') { 
              delete $warning{$warnId}; 
            }
          }
        }
      } 
      elsif ($typeId == 26 || $typeId == 27) { # Design & Design Change block
        print "\n\n";
        my $spacedockOverflow = 0;  #Space Dock Overflow
        my $crobyLangston = 0; #Spack Dock overflow additional armor
        if ($typeId == 26 ) { # HST File. 
          # Find design block Player Id Because the player id isn't in Block 26
          # The Design blocks are in order, and the number of them for each player are defined in the player block(s). 
          # And if it seems like a lot of work to ge this info, it is.
          # Find design block player
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
          $Player = $designOwner;
        }  
        my $hullId;
        my $index = 0;
        if ( $typeId == 27 ) {# for the two extra bytes in a .x file 
          $index = 2; 
        }   
        my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
        $deleteDesign = $decryptedData[0] % 16;
        if ($deleteDesign == 0) { 
          $designNumber = $decryptedData[1] % 16; 
          $isStarbase = ($decryptedData[1] >> 4) % 2; 
          if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
          else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber); }  # adding a zero lets us sort on key
          
        }
        # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
        if ($deleteDesign) { 
          $isFullDesign =  ($decryptedData[$index] & 0x04); 
          $isTransferred = ($decryptedData[$index+1] & 0x80); 
          $isStarbase = ($decryptedData[$index+1] & 0x40);  
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; 
          $hullId = $decryptedData[$index+2] & 0xFF; 
          if ($isFullDesign) {
            # Since there can be a ship and base with the same designId, 
            # need to be able to keep them separate
            if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
            else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber) ; }  # adding a zero lets us sort on key
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
            my $spaceDockIndex = $index; # used for the Space Dock overflow
            # Loop through once for each slot
            my $itemSum = 0; # tracking if all the design slots are empty for the Cheap Starbase bug
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
              $index += 2;
              $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
              $index++;
              $itemCount = $decryptedData[$index];
              $itemSum = $itemSum + $itemCount;
              #my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
              #if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index\n"; }
              #else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index\n";}

              # Colonizer bug
              # Ships with a colonization module removed and the slot left empty can still colonise planets
              # If a colonizer hull is created, and then edited, it's going to put 2 (or more)  entries in the .x file.
              # so need to filter.
              if ($itemId == 0 &&  $itemCategory == 4096 && $itemCount == 0) {
                # Fixing display for those who don't count from 0.
                $err .= 'WARNING: Colonizer bug detected for player ' . ($Player+1) . ' in ship design slot ' . ($designNumber+1) . ": $shipName (in slot " . ($itemSlot+1) . '). ';
                $itemCategory = &read16(\@decryptedData, $index-3);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
                #print "category: $itemCategory  index: $index\n";
                ($decryptedData[$index-3], $decryptedData[$index-2]) = &write16(0); # Category
                $needsFixing = 1;
                if ($fixFiles > 1) {
                  $err .= '  Fixed!!! Slot now truly empty.';
                } else {$err .= '';}
                $warning{$warnId.'-colonizer'} = $err;
                #print "$index: $warnId: $err\n"; 
              }
              # Detect Space Dock Overflow
              # Don't fix it here because we don't know yet at a slot level what the rest of the slots are
              if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory == 8 && $itemCount > 21  && $armor  >= 49518) {  $spacedockOverflow = 1; } 
              # Check for other items that could be increasing armor
              if ( $spacedockOverflow ) { if ($itemCategory == 4 && ($itemId == 6 || $itemId == 3)) { $crobyLangston = $itemCount; } }
              # Step forward for the next slot
              $index++;
            }
            if ($spacedockOverflow) {
              # Fix Space Dock Armor slot Buffer Overflow with super latanium
              # If your race has ISB and RS, building a Space Dock with more than 21 SuperLat in the Armor slot 
              # will result in some sort of error (of massively increased armor)
              # Rick: I had hoped to fix this by simply rewriting the armor value,
              # but armor gets recalculated, so resetting the itemCount is the only choice. 
              $err = 'WARNING: Spacedock Overflow bug of > 21 SuperLatanium detected for player ' . ($Player+1) . ' in starbase design slot ' . ($designNumber+1) . ": $shipName. ";
              # reset the $itemCount 
              $decryptedData[$spaceDockIndex+11] = 21; # Armor slot on spacedock
              # Armor value should be 250 + (1500 * $itemCount) / 2
              $armor = 250 + (1500 * 21) / 2; # adjust for 21 Super Latanium
              if ($crobyLangston)  {  $armor += 65 * $crobyLangston; } # add on Croby or Langston armor
              #print "Updated armor value: $armor\n";
              # reset the final armor value for the spacedock overflow bug
              ($decryptedData[$armorIndex], $decryptedData[$armorIndex+1]) = &write16($armor);
              $needsFixing = 1;
              if ($fixFiles > 1) {
                $err .= '  Fixed!!! SuperLatanium set to 21. New armor value: ' . $armor;
              } else {$err .= '';}
              $warning{$warnId.'-dock'} = $err;
              #print "$warnId: $err\n";
            }
            # if we have a starbase with totally empty slots, we definitely don't have a Cheap Starbase
            if ($isStarbase && $itemSum == 0) { 
              $brokenStarbase[$designNumber] = -1; 
              if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
                delete ($warning{$warnId.'-cheap'}); 
              }
            }
          } else { # If it's not a full design
            $mass = &read16(\@decryptedData, 4); 
            $slotEnd = 6; 
            $shipNameLength = $decryptedData[$slotEnd]; 
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          }
          #print "shipName: $shipName\n";
          
          # Detect the 10th starbase design
          if ( $isStarbase && $designNumber == 9 && $deleteDesign && $Player > 0 ) {
            $err = 'WARNING: Player ' . ($Player+1) . ": Starbase ($shipName) in design slot 10 - Potential Crash if Player 1 Fleet 1 refuels when Last Player has a 10th starbase design.";
            # As I have no fix, no need to flag for fixing
            #print "$warnId: $err\n"; 
            $warning{$warnId.'-ten'} = $err;
          } 
          # Detect the Cheap Starbase exploit    
          # Editing a starbase under construction at planet(s) with no starbase
          # Only need to check starbase orders
          # If the design is deleted we also stop checking 
          if ($typeId == 27 && $isStarbase && $totalBuilt == 0 && !($brokenStarbase[$designNumber]  < 0) ){ # .x and Starbase
            my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
            my $queueCounter;
            foreach my $queueCounter (sort keys %queueList) {
              if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber) { # if the item in the queue is a ship design (4)
                $err = 'WARNING: Cheap Starbase Exploit for Player ' . ($Player+1) . '. Do not edit a starbase under construction (slot ' . ($designNumber+1) . ", $shipName).";
                $brokenStarbase[$designNumber] = 1; 
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
                  #my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
                  #if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index \n"; }
                  #else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index \n";}
                  $index++;
                }
                $needsFixing = 1;
                if ($fixFiles > 1) {
                  $err .= "  Fixed!!! Starbase design for $shipname reset to blank.";
                } else {$err .= ' '; }
                $warning{$warnId.'-cheap'} = $err;
                #print "$warnId: $err\n";
              }
            }
          }
        } 
        # For the Colonizer bug & Spacedock overflow, track whether the design was 
        # created, but remove the warning if the design was subsequently changed (inc. deleted)
        # (because a later .x file entry modified this designnumber)
        # Store the error in a hash so it's only one / ship / file
        # Will handle for multi-turn .m files.
        if (!$err && $warning{$warnId.'-dock'}) { 
          delete( $warning{$warnId.'-dock'} ); 
        }
        if (!$err && $warning{$warnId.'-colonizer'}) { 
          delete( $warning{$warnId.'-colonizer'} ); 
        }
        # If the 10th starbase has been deleted, clear the warning
        if ( $isStarbase && $designNumber == 9 && $deleteDesign == 0 && $Player > 0 ){
          if ($warning{$warnId.'-ten'}) { 
            delete ($warning{$warnId.'-ten'}); 
          }
        }
        # If the edited Cheap Starbase design is deleted, 
        # delete the queue entries as we no longer care for future checks on this design.
        my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
        if ( ($isStarbase && $deleteDesign == 0) ) {
          # Determine which starbase
          foreach my $queueCounter (sort keys %queueList) {
            if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber ) { # if the item in the queue is a ship design (4)
              if (exists ($queueList{$queueCounter})) { 
                delete $queueList{$queueCounter}; 
              }
            }
          }
          if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
            delete ($warning{$warnId.'-cheap'}); 
          }
        }
        # If the queue was cleared for planet, future queue no longer a problem
        foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
          if ( $queueList{$queueCounter}{queueSize} == 2 ) {
            if (exists ($queueList{$queueCounter})) { 
              delete $queueList{$queueCounter}; 
            }
          }
        }
        # Now that the queues are cleared up, see if we still have a Cheap Starbase problem
        my $stillBroken = 0;   
        foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
          if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber && $queueList{$queueCounter}{completePercent} > 0) { # if the item in the queue is a ship design (4)
             $stillBroken = 1;
          }
        }
        if ($stillBroken) {
          $brokenStarbase[$designNumber] = 1;
        } else {
          #if ($brokenStarbase[$designNumber] == 1) { 
          #  print "Cheap Starbase Player Fix Noted\n"; 
          #}
          $brokenStarbase[$designNumber] = -1;
          if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
            delete ($warning{$warnId.'-cheap'}); 
          }
        }
      } elsif ($typeId == 30) {  # BattlePlan block
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
        #print "planNameLength: $planNameLength  (using nibbles as characters, not bytes)\n";
        $planName = &decodeBytesForStarsString(@decryptedData[4..4+$planNameLength]);  
        #print "$planPlayerId,$primaryTarget,$secondaryTarget,$tactic,$attackWho,$dumpCargo\n";
        # Detect the BattlePlan Friendly Fire bug
        $warnId = &zerofy($planPlayerId) . '-plan-' . &zerofy($planNumber);
        if (($attackWho) > 3 && $planNumber == 0) { 
           # Fixing display for those who don't count from 0.
           $err .= 'WARNING: Friendly Fire bug detected for Player ' . ($planPlayerId+1) .  " in Default battle plan against " . &attackWho($attackWho) . '.';
           $decryptedData[3] = 2;
           $needsFixing = 1;
           if ($fixFiles > 1) {
             $err .= ' Fixed!!! Attack Who reset to Neutral/Enemy.';
           } else {$err .= '';}
           #print "$warnId: $err\n"; 
           $warning{$warnId.'-friendly'} = $err;
        }
        # If a subsequent Default battle plan fixes it, clear the warning
        if (!$err && $warning{$warnId.'-friendly'}) { 
          delete( $warning{$warnId.'-friendly'} ); 
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
  return \@outBytes, $needsFixing, \%warning;
}

#Deprecated ever since I leared about adding in parenthesis 
# sub plusone {
# # Increment the value of a number as one for display to end users
# # (who problably don't count from 0)
#   my ($val) = @_;
#   $val++;
#   return $val;
# } 

sub StarsAI {
  # Change player status in the HST file
  # Read in the binary Stars! file, byte by byte
  my ($GameFile, $PlayerAI, $NewStatus) = @_;
  use File::Copy;
  my $FileValues;
  my @fileBytes;
  my $filename = $FileHST . "\\" . $GameFile . "\\" . $GameFile . '.HST';
  my $backupfile = $filename . '.ai';
  
  #Validate the HST file exists 
  unless (-e $filename  ) { 
    &PLogOut(0,"StarsAI: Failed to find $filename for $GameFile", $ErrorLog);
    return 0;
  }

  # Read in the .HST file
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
    open (OutFile, '>:raw', "$filename");
    for (my $i = 0; $i < @outBytes; $i++) {
      print OutFile $outBytes[$i];
    }
    close (OutFile);
    &PLogOut(200," StarsAI: Updated $filename for playerId:$playerAI to $NewStatus ", $LogFile);
  } else { 
    &PLogOut(200," StarsAI: Did not update $filename for playerId:$playerAI to $NewStatus ", $LogFile); 
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
  my ( $random, $seedA, $seedB, $seedX, $seedY );
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
#    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
#      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
      my $playerId = $decryptedData[0] & 0xFF; 
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
            &PLogOut(200," StarsAI: Flipped playerId:$playerId to Active", $LogFile);
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
            &PLogOut(200," StarsAI: Flipped playerId:$playerId to Inactive", $LogFile);
          } else { &PLogOut(200," StarsAI: No Status Change for playerId:$playerId", $LogFile); }
        } 
      } # End of typeID 6
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
  } else { &PLogOut(200," StarsAI: Did not make changes to $filename for playerID:$PlayerAI to $NewStatus", $LogFile); return 0; }
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
	my ($player, $designType, $designNumber, $warningType) = split ('-',$warnId);
	$player = $player *1; # deZerofy
	$designNumber = $designNumber * 1; # deZerofy
	return ($player, $designType, $designNumber, $warningType);
}

sub attackWho {
   my ($value) = @_;
   #Nobody, Enemies, Neutral/Enemies, Everyone, [Players] 
   my @category = qw(Nobody Enemies Neutral/Enemies Everyone);
   if ($value > 3) { my $player = $value -4; return "Player $player"; }
   else { return $category[$value]; }
}

sub showCategory {
  my ($category, $item) = @_;
  my @category;
  my %item;
#             Empty = 0,
#             Engine = 1,
#             Scanners = 2,
#             Shields = 4,
#             Armor = 8,
#             BeamWeapon = 0x10,
#             Torpedo = 0x20
#             Bomb = 0x40,
#             MiningRobot = 0x80,
#             MineLayer = 0x100,
#             Orbital = 0x200,
#             Planetary = 0x400,
#             Electrical = 0x800,
#             Mechanical = 0x1000,

  $category[0] = 'Empty';
  $category[1] = 'Engine';
  $category[2] = 'Scanners';
  $category[4] = 'Shields';
  $category[8] = 'Armor';
  $category[16] = 'BeamWeapon';
  $category[32] = 'Torpedo';
  $category[64] = 'Bomb';
  $category[128] = 'MiningRobot';
  $category[256] = 'MineLayer';
  $category[512] = 'Orbital';
  $category[1024] = 'Planetary'; # Assumed since it appears to be the only missing one
  $category[2048] = 'Electrical';
  $category[4096] = 'Mechanical';
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
  $item{'512'} = [ qw ( SG250 SG300 SG600 SG500 SGany SG800  SGanyany Mass5 Mass6 Mass7 Mass8 Mass9 Mass10 Mass11 Mass12 Mass13 ) ];
  $item{'1024'} = [ qw ( Viewer50 Viewer90 Viewer150 Viewer220 Viewer280 Viewer320 Snooper400 Snooper500 Snooper620 ) ];
  $item{'2048'} = [ qw ( TransportCloak StealthCloak Super-StealthCloak Ultra-StealthCloak MultiFunction BattleComputer BattleSuperComputer BattleNexus Jammer10 Jammer20 Jammer30 Jammer50 EnergyCapacitor FluxCapacitor EnergyDampener TachyonDetector Anti-matterGenerator) ];
  $item{'4096'} = [ qw ( Colonization OrbitalCon Cargo SuperCargo MultiCargo Fuel SuperFuel ManeuveringJet Overthruster BeamDeflector ) ];
  $item{'6194'} = [ qw ( empty ) ];

  return ($category[$category],$item{$category}[$item]);
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

sub PLogOut {
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
#		print $PrintString . "\n";
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

