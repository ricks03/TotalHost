# StarsRace.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
#
# Gets Race attributes
# Example Usage: decryptor.pl c:\stars\game.m1
#
# Gets the values from a Race File
# Note that the rece file has a checksum value, so writing out changes will 
# fail.
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# Not currently functional

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
my $debug = 1;

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
my $outfilename = $ARGV[1];
if (!($filename)) { 
  print "\n\nUsage: StarsRace.pl <input file> <output file (optional)>\n\n";
  print "Please enter the input file (.M or .HST). Example: \n";
  print "  StarsPWD.pl c:\\games\\test.m6\n\n";
  print "Removes the password from a .M file. The password must be\n";
  print "  set when the turn is submitted or the password will revert.\n\n";
  print "Removes all player passwords from a .HST file. On the next\n";
  print "  turn generation all .M files will have no password.\n\n"; 
  print "Removes any administrative password on the .HST file.\n\n";
  print "Sets a password in a .X file to blank.\n\n";
  print "By default, a new file will be created: <filename>.clean\n\n";
  print "You can create a different file with StarsRace.pl <filename> <newfilename>\n";
  print "  StarsRace.pl <filename> <filename> will overwrite the original file.\n\n";
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
#if (uc($ext) eq ".R1") { print "Doesn't work for Race Files -- Sorry!\n"; exit; }

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

# Create the output file name
# my $newFile; 
# if ($outfilename) {   $newFile = $outfilename;  } 
# else { $newFile = $dir . '\\' . $basefile . '.clean'; }
# if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me

# Output the Stars! File with blank password(s)
# open (OutFile, '>:raw', "$newFile");
# for (my $i = 0; $i < @outBytes; $i++) {
#   print OutFile $outBytes[$i];
# }
# close (OutFile);
# 
# print "File output: $newFile\n";
# unless ($ARGV[1]) { print "Don't forget to rename the file\n"; }

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
  if ($debug) { print "binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame\n"; }
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
      
sub parseBlock {
  # This returns the 3 relevant parts of a block: typeId, size, raw block data
  my ($fileBytes, $offset) = @_;
  my @fileBytes = @{ $fileBytes };
  my @blockdata;
  my ($blocktype, $blocksize) = &read16(\@fileBytes, $offset);
  for (my $i = $offset+2; $i < $offset+$blocksize+2; $i++) {   #skipping over the TypeID
    push @blockdata, $fileBytes[$i];
  }
  return ($blocktype, $blocksize, \@blockdata);
}   

sub read16 {
  # For a given offset, determine the block size and blocktype
  my ($fileBytes, $offset) = @_; 
  my @fileBytes = @{ $fileBytes };
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
  return ($blocktype, $blocksize);
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
#     if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
#     if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
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
      print "BLOCK 7 found. ERROR!\n"; die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
#      if ($debug) { print "\nDATA DECRYPTED:\n" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
        if ($debug) { print "\nPLAYER BLOCK:\n" . join (" ", @decryptedData), "\n"; }
        my @PRT = qw(HE SS WM CA IS SD PP IT AR JOAT );
        my $playerNumber = $decryptedData[0] & 0xFF; print "Player Number: $playerNumber\n";
        my $shipDesigns = $decryptedData[1] & 0xFF;  print " Ship Designs: $shipDesigns\n";
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); print " Planets: $planets\n";
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  print " Fleets: $fleets\n";
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); print " Starbase Designs: $starbaseDesigns\n";
	      my $logo = (($decryptedData[6] & 0xFF) >> 3); print " Logo: $logo\n";
        my $fullDataFlag = ($decryptedData[6] & 0x04); print " fullDataFlag: $fullDataFlag\n";
        my $index = 8;
        if ($fullDataFlag) {
        	# $fullDataBytes = new byte[0x68]; ASCII
          my $fullDataBytes = $decryptedData[8] + $decryptedData[9]; 
          my $index = 0x70;
          print "index: $index\n";
          my $playerRelationsLength = $decryptedData[$index] & 0xFF; print "Player Relations Length: $playerRelationsLength\n";
          my $playerRelations = $decryptedData[11]; print "PlayerRelations: $playerRelations\n";
          # arraycopy(Object source_arr, int sourcePos,  Object dest_arr, int destPos, int len)
          # System.arraycopy(decryptedData, index + 1, playerRelations, 0, playerRelationsLength);
          # Skip ahead that many places
          $index = $index + 1 + $playerRelationsLength;
        }
        print "index: $index\n";
        my $namesStart = $index;
        $index++; $index++;
        $index = 16;
        my $singularNameLength = $decryptedData[$index] & 0xFF;  print "singularNameLength: $singularNameLength\n";
  	    $index += $singularNameLength;
        $index++;
  	    my $pluralNameLength = $decryptedData[$index] & 0xFF;  print "pluralNameLength: $pluralNameLength\n";
  	    $index += $pluralNameLength;
        
        my $f1 = $decryptedData[55]; print "f1: $f1\n";
        my $f2 = $decryptedData[56]; print "f2: $f2\n";
        my $f3 = $decryptedData[57]; print "f3: $f3\n";
        my $m1 = $decryptedData[58]; print "m1: $m1\n";
        my $m2 = $decryptedData[59]; print "m2: $m2\n";
        my $m3 = $decryptedData[60]; print "m3: $m3\n";

        
        
        
# # Unpack the FileHeaderBlock data
# # 2 bytes
# $bytes = $fileBytes[0] . $fileBytes[1];
# $Header = unpack ("S", $bytes);
# # 4 bytes
# $bytes = $fileBytes[2] . $fileBytes[3] . $fileBytes[4] . $fileBytes[5];
# $Magic = unpack ("A4", $bytes);
# # 4 bytes
# $bytes =  $fileBytes[6] . $fileBytes[7] . $fileBytes[8] . $fileBytes[9];
# $lidGame = unpack ("L",  $bytes);
# # 2 bytes
# $bytes = $fileBytes[10] . $fileBytes[11];
# $ver = unpack ("S", $bytes);
# # 2 bytes
# $bytes = $fileBytes[12] . $fileBytes[13];
# $turn = unpack ("S", $bytes); # $turn + 2400 = turn
# # 2 bytes
# $bytes = $fileBytes[14] . $fileBytes[15];
# $iPlayer = unpack ("s", $bytes);
# # 2 bytes
# $bytes = $fileBytes[16] . $fileBytes[17];
# $dts = unpack ("S", $bytes);
# # Convert the data to its usable form
# $binHeader = dec2bin($Header);
# $blocktype = (substr($binHeader, 0,6));
# $blocktype = bin2dec($blocktype);
# $blocksize = (substr($binHeader, 7,2)) . (substr($binHeader, 8,8));
# $blocksize = bin2dec($blocksize);
# # Game Version
# $ver = dec2bin($ver);
# $verInc = substr($ver,11,5);
# $verMinor = substr($ver,4,7);
# $verMajor = substr($ver,0,4);
# $verMajor = bin2dec($verMajor);
# $verMinor = bin2dec($verMinor);
# $verInc = bin2dec($verInc);
# $ver = $verMajor . "." . $verMinor . "." . $verInc;
# $verClean = $verMajor . "." . $verMinor;
# # Player Number
# $iPlayer = &dec2bin($iPlayer);
# $Player = substr($iPlayer,11,5);
# $Player = bin2dec($Player); # note from 0-15
# # Encryption Seed
# $binSeed =  substr($iPlayer,0,11);
# $Seed = bin2dec($binSeed);
# # dts - Convert DTS to binary so we can pull the values back out
# $dts = dec2bin($dts);
# #Break DTS into its binary components
# $dt = substr($dts, 8,15);
# $dt = bin2dec($dt);
# # File Type
# # These are 1 character, so there's no need to convert them back to decimal
# # Turn state (.x file only)
# $fDone = substr($dts, 7,1);
# # Host instance is using this file (dtHost, dtTurn).
# $fInUse = substr($dts, 6, 1);
# # Are multiple turns included (.m only)
# $fMulti = substr($dts, 5,1);
# # Is the Game Over
# $fGameOver = substr($dts, 4,1);  # Probably 4
# # Shareware
# $fShareware = substr($dts, 3, 1);



        
#         if (($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) {
#         print "Password replaced!\n";
#           # Replace the password with blank
#           $decryptedData[12] = 0;
#           $decryptedData[13] = 0;
#           $decryptedData[14] = 0;
#           $decryptedData[15] = 0;  
#         } else { 
#           # In .HST some Player blocks could be password protected, and some not 
#           unless (uc($ext) eq '.HST' ) { die "This file isn't password-protected!\n"; }
#         }
      }
      if ($typeId == 36) { # .x file Change Password Block
#         if (($decryptedData[0]  != 0) | ($decryptedData[1] != 0) | ($decryptedData[2] != 0) | ($decryptedData[3] != 0)) {
#           print "Password replaced!\n";
#           # Replace the password with blank
#           $decryptedData[0] = 0;
#           $decryptedData[1] = 0;
#           $decryptedData[2] = 0;
#           $decryptedData[3] = 0; 
#         } 
      }
      # END OF MAGIC
      #reencrypt the data for output
#       ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
#       @encryptedBlock = @ { $encryptedBlock };
#       if ($debug) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
#       push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
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
#################################

