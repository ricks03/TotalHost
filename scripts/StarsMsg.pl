# StarsMsg.pl
# Displays Stars! Messages
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191119
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

# Displays Block 40 - Message Block
# Still problems displaying some of the special characters
# "   [254, 255] 34 0
# #   [254, 255] 35 0
# (   [254, 255] 40 0
# )   [254, 255] 41 0
# &   [254, 255] 42 0
# |   [254, 255] 43 0
# _   [254, 255] 45 0
# <   [254, 255] 60 0
# =   [254, 255] 61 0
# >   [254, 255] 62 0
# /   [254, 255] 63 0
# [   [254, 255] 91 0
# \   [254, 255] 92 0
# ]   [254, 255] 93 0
# ^   [254, 255] 94 0
# `   [254, 255] 96 0
# {   [254, 255] 123 0
# }   [254, 255] 125 0

# Example Usage: StarsMsg.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
my $debug = 0; # Enable better debugging output. Bigger the better

#$hexDigits      = "0123456789ABCDEF";
my $encodesOneByte = " aehilnorst";
my $encodesB       = "ABCDEFGHIJKLMNOP";
my $encodesC       = "QRSTUVWXYZ012345";
my $encodesD       = "6789bcdfgjkmpquv";
my $encodesE       = "wxyz+-,!.?:;\'*%\$";

my (@singularRaceName, @pluralRaceName);
$singularRaceName[0] = "Everyone";

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
my $inBlock = '';
my $inBin = 0; 
my $inName = $ARGV[0]; # input file
$inBlock = $ARGV[1]; # Desired block Type
$inBin = $ARGV[2]; # Desired block Type
unless ($inBlock) { $inBlock = -1;}
my $filename = $inName;

if (!($inName)) { 
  print "\n\nDisplays the Player Messages in a Stars! file.\n";
  print "\nUsage: StarsByte.pl <input> \n";
  print "  StarsMsg.pl c:\\games\\test.m6\n\n";
  exit;
}

#Validate directory or file 
unless (-e $inName ) { 
  print "Requested file:> $inName <: does not exist!\n"; exit; 
}

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m  extension

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
my ($outBytes) = &decryptBlock(@fileBytes);
my @outBytes = @{$outBytes};
  
################################################################
sub StarsRandom {
  my ($seedA, $seedB, $initRounds) = @_;  
  my $randomNumber;
  # Now initialize a few rounds
  for (my $i = 0; $i < $initRounds; $i++) { 
    ($randomNumber, $seedA, $seedB ) = &nextRandom($seedA, $seedB );
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
# This works differently than all the rest of the code, because of how
# I wrote it originally in my starstat.pl code
# $Header-S, $Magic=A4, $lidGame-h8, $ver-S, $turn-S $iPlayer-S, $dts-S)
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
  if ($debug) { print "binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame\n"; }
  return $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic;
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
        ( ord($byteArray[$i+3]) << 24) | 
        ( ord($byteArray[$i+2]) << 16) | 
        ( ord($byteArray[$i+1]) << 8)  | 
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

# Convert unsigned byte to integer.
sub read8 {
  my ($b) = @_;
	return $b & 0xFF;
}
	
#	 Read a 16 bit little endian integer from a byte array
sub read16 {
  my ($data, $offset) = @_;
  my @data = @{ $data };
	return &read8($data[$offset+1]) << 8 | &read8($data[$offset]);
}

#	 Read a 32 bit little endian integer from a byte array
sub read32 {
  my ($data, $offset) = @_;
  my @data = @{ $data };
	return &read8($data[$offset+3]) << 24 | 
				&read8($data[$offset+2]) << 16 | 
				&read8($data[$offset+1]) << 8 | 
				&read8($data[$offset]);
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
      # If there are two ( or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      &processData(\@decryptedData,$blockId,$offset,$size);
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
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

sub processData {
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
    my $message = &decodeBytesForStarsString(@decryptedData[11..$messageLength]);
    if ($debug) { print "blockId: $blockId\n"; }
    if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
#    print "From: $senderId, To: $recipientId, \"$message\"\n"; 
    print "From: $singularRaceName[$senderId], To: $singularRaceName[$recipientId-1], \"$message\"\n"; 
    if ($debug) { print "b0: $byte0, b2: $byte2, b8: $byte8\n"; }
  }
  return @decryptedData;
}
