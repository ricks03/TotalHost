# StarsPWD.pl
# Strips the passwords off of Stars! files
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
# Example Usage: StarsPWD.pl c:\stars\game.m1
#
# Removes the password from a .M file
# Removes the password from a .HST file
# Removes the password from a .X file
# Removes the passwords for all players from a .HST file
#
# TBD: add ability to create .x file with password reset
# TBD: Remove password from .r file (should work, doesn't).
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  


use strict;
use warnings;   
use File::Basename;  # Used to get filename components
my $debug = 0;

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
my $outFileName = $ARGV[1];
if (!($filename)) { 
  print "\n\nUsage: StarsPWD.pl <input file> <output file (optional)>\n\n";
  print "Please enter the input file (.M or .HST). Example: \n";
  print "  StarsPWD.pl c:\\games\\test.m6\n\n";
  print "Removes the password from a .M file. The password must be\n";
  print "  set when the turn is submitted or the password will revert.\n\n";
  print "Removes all player passwords from a .HST file. On the next\n";
  print "  turn generation all .M files will have no password.\n\n"; 
  print "Removes any administrative password on the .HST file.\n\n";
  print "Sets a password in a .X file to blank.\n\n";
  print "By default, a new file will be created: <filename>.blank\n\n";
  print "You can create a different file with StarsPWD.pl <filename> <newfilename>\n";
  print "  StarsPWD.pl <filename> <filename> will overwrite the original file.\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

# Passwords in .R files are also stored in Block 6. The script correctly
# IDs and blanks the password, but they're corrupt nonetheless. 
if (uc($ext) eq '.R1') { print "Doesn't work for Race Files -- Sorry!\n"; exit; }

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
my ($outBytes) = &decryptPWD(@fileBytes);
#my ($outBytes) = &decryptPWD();
if ($outBytes) {
  my @outBytes = @{$outBytes};
  
  # Create the output file name
  my $newFile; 
  if ($outFileName) {   $newFile = $outFileName;  } 
  else { $newFile = $dir . '\\' . $basefile . '.blank'; }
  if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me
  
  # Output the Stars! File with blank password(s)
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "File output: $newFile\n";
  unless ($ARGV[1] && $ARGV[1] eq $ARGV[0]) { print "Don't forget to rename $newFile to $filename\n"; }
} else { print "No passwords found\n"; }

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
  #my ($fileBytes) = @_;
  #my @fileBytes = @{ $fileBytes };
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
  if ($debug) { print "binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame,fMulti:$fMulti\n"; }
  return $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti;
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

sub dec2bin {
	# This doesn't match stuff online because I changed from 32- to 16-bit
	return unpack("B16", pack("n", shift));
}

sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub decryptPWD {
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
  my $pwdreset = 0;
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
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
      print "BLOCK 7 found. ERROR!\n"; die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($debug) { print "\nDATA DECRYPTED:\n" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        # BUG: Fixing for only PlayerID = Player blocks will break for .HST
        my $playerId = $decryptedData[0] & 0xFF; 
        if ((($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) && ($playerId == $Player)){
        print "Block $offset password replaced!\n";
          # Replace the password with blank
          $decryptedData[12] = 0;
          $decryptedData[13] = 0;
          $decryptedData[14] = 0;
          $decryptedData[15] = 0;  
          $pwdreset = 1;
        } else { 
          # In .HST some Player blocks could be password protected, and some not 
          # Or in files with block 6 from multiple players
          unless (uc($ext) eq '.HST' ) { print "Block $offset isn't password-protected!\n"; }
        }
      }
      if ($typeId == 36) { # .x file Change Password Block
        if (($decryptedData[0]  != 0) | ($decryptedData[1] != 0) | ($decryptedData[2] != 0) | ($decryptedData[3] != 0)) {
          print "Block $offset password replaced!\n";
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
      if ($debug) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
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
