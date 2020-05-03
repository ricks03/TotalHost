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
# StarsFix not integrated (fox .x files)

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
  initDecryption getFileHeaderBlock
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
  StarsMsg decryptMsg
  PLogOut
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
  &PLogOut(400,"binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame", $LogFile);
  return $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic;
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
	if ($byteLen == 0) {return  0; }
	elsif ($byteLen == 1) {return &read8($data);  }
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
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  my $pwdreset = 0;
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    &PLogOut(400, "BLOCK typeId: $typeId, Offset: $offset, Size: $size", $LogFile);
    my $BlockRaw = "BLOCK RAW: Size " . @block . ":\n" . join ("", @block);
    &PLogOut(400, $BlockRaw, $LogFile);
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
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
          &PLogOut(200,"Block $offset password blanked for M", $LogFile);
          print "Block $offset password blanked for M\n";
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
          &PLogOut(200,"Block $offset password blanked for X", $LogFile);
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
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
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
          print "<P>Spend Leftover Points: " . &showLeftoverPoints($spendLeftoverPoints) . "\n";
          print "<P>PRT: " . &showPRT($PRT) . "\n";
          print "<P>LRTs: " . join(',',@LRTs) . "\n";
          print "<P>Grav: " . &showHab($lowGravity,$centreGravity,$highGravity, 0) . ", Temp: " . &showHab($lowTemperature,$centreTemperature,$highTemperature,1) . ", Rad: " . &showHab($lowRadiation,$centreRadiation,$highRadiation,2) . ", Growth: $growthRate\%\n"; 
          print "<P>Productivity: Colonist " . $resourcePerColonist*100 .", Factory: Produce $producePerFactory, Cost To Build $toBuildFactory, May Operate $operateFactory, Mine: Produce $producePerMine, Resources to Build $toBuildMine, May Operate $operateMine\n";
          print "<P>FactoriesCost1LessGerm: " . &showFactoriesCost1LessGerm($factoriesCost1LessGerm) . "\n";
          print "<P>Research Cost:  Energy " . &showResearchCost($researchEnergy) . ", Weapons " . &showResearchCost($researchWeapons) . ", Propulsion " . &showResearchCost($researchProp). ", Construction " . &showResearchCost($researchConstruction) . ", Electronics " . &showResearchCost($researchElectronics) . ", Biotech " . &showResearchCost($researchBiotech) . "\n";
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
  $raceData = "playerName $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
  
  if ($fullDataFlag) { 
    my $homeWorld = &read16(\@decryptedData, 8);
#    my $rank = &read16(\@decryptedData, 10);
# BUG: the references say this is two bytes, but I don't think it is.
# That means I don't know what byte 11 is tho. 
    my $rank = $decryptedData[10];
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

sub StarsMsg {
  my ($GameFile, $Player) = @_;

    # Displays Stars! Messages
    # Displays Block 40 - Message Block
    # Derived from decryptor.py and decryptor.java from
    # https://github.com/stars-4x/starsapi  
    
    use File::Basename;  # Used to get filename components
    my $debug = 0; # Enable better debugging output. Bigger the better
    
    my $filename = $GameFile;
    
    #Validate directory or file 
    unless (-e $inName ) { 
      print "Requested object $inName does not exist!\n"; exit; 
    }
        
    # Read in the binary Stars! file, byte by byte
    my $FileValues;
    my @fileBytes;
    open(StarFile, "<$filename" );
    binmode(StarFile);
    while ( read(StarFile, $FileValues, 1)) {
      push @fileBytes, $FileValues; 
    }
    close(StarFile);
    
    # Decrypt the data, block by block
    my ($outBytes) = &decryptMsg(@fileBytes);
}

sub decryptMsg {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY );
  my ($blockId, $size, $data );
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($blockId, $size, $data ) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($blockId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      # Display the messages in the file
      my ($decryptedData,$blockId,$offset,$size)  = @_;
      my @decryptedData = @{ $decryptedData };
      # We need the names to display
      # although there are no names in .x files
      if ($blockId == 6) { #Check the Player Block so we can get the race names
        my $playerId = $decryptedData[0];
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
        my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
        print "playerName $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
      } elsif ($blockId == 40) { # check the Message block 
        my $byte0 =  &read16(\@decryptedData, 0);  # unknown
        my $byte2 =  &read16(\@decryptedData, 2);  # unknown
        my $senderId = &read16(\@decryptedData, 4);
        my $recipientId = &read16(\@decryptedData, 6);
        my $byte8 =  &read16(\@decryptedData, 8); # unknown
        my $messageBytes = &read16(\@decryptedData, 10);
        my $messageLength = $size -1;
        my $message = &decodeBytesForStarsMessage(@decryptedData[11..$messageLength]);
        if ($debug) { print "blockId: $blockId\n"; }
        if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
        print "From: $senderId, To: $recipientId, \"$message\"\n"; 
        if ($debug) { print "b0: $byte0, b2: $byte2, b8: $byte8\n"; }
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
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

