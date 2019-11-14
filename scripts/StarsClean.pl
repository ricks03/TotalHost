#!/usr/bin/perl
# StarsClean.pl
# Stars! Clean
# Clean shared information out of .m files
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191114
#
# Cleans .m files
# .m files include other player information about:
#    Mystery Trader (tech offered and who has met with him)
#    wormholes (who can and can't see, who has jumped in and who hasn't)
#    minefields (who can see it)
#    CA (player information on other races)

# Example Usage: StarsClean.pl c:\stars\game.m1
#
# Removes "priviledged" information from a .m file
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# And takes inspiration from Xyligun's StarsKnowledgeCleaner.exe

#Some of the bytes in minefields differ from player to player inexplicably

#Currently:
# Cleans MT Cargo (sets to "research")
# Cleans who has visited mystery trader (only player)
# Cleans who has seen minefields (only player)
# Cleans who has seen wormholes (only player)
# Cleans who has been through a wormhole (only player)

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
my $debug = 2; # Enable better debugging output. Bigger the better
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
# $CanSee;
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
my @mFiles;      
my $inName = $ARGV[0]; # input file
my $outName = $ARGV[1];
my $filename;

if (!($inName)) { 
  print "\n\nRemoves other player minefield, MT and wormhole information from .M files.\n";
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
  print "Requested object $inName does not exist!\n"; exit; 
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
  # If a file name was specified
  $mFiles[0] = $inName;
}
  
if (@mFiles == 0) { die "Someting went wrong. There\'s no information\n"; }

foreach $filename (@mFiles) {
# Loop through for each .m file in the directory
# and clean it
  my ($basefile, $dir, $ext);
  # for c:\stars\mygamename.m1
  $basefile = basename($filename);    # mygamename.m1
  $dir  = dirname($filename);         # c:\stars
  ($ext) = $basefile =~ /(\.[^.]+)$/; # .m  extension
  print "FILENAME: $filename\n";
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
  
  # Create the output file name(s)
  # taking account the paths provided. 
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
      print OutFile $outBytes[$i];
    }
    close ( outFile);
    
    print "File output: $newFile\n";
    unless ($ARGV[1] || -d $inName ) { print "Don't forget to rename the file\n"; }
  }
} 
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
    if ($blockId == 43 ) { $debug = 1;  } else { $debug = 0;}
    if ($debug > 1) { print "\nBLOCK blockId: $blockId, Offset: $offset, Size: $size\n"; }  
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($blockId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two ( or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      unless ($Magic eq "J3J3") { die "One of the files is not a .M file. Stopped along the way."; }
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
     } elsif ($blockId == 7) {
      # BUG: Note that planet's data requires something extra to decrypt. 
      # Fortunately block 7 isn't in my test files
      print "BLOCK 7 found. ERROR!\n"; die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };
      if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
      
#       if ($blockId == 6) { #Check the player block
#         $playerId = $decryptedData[0];
#         $ShipSlotsUsed = $decryptedData[1];
#         $PlanetCount = &read16(\@decryptedData, 2);
#         $FleetAndStarBaseDesignCount = read16(\@decryptedData, 4);
#         $FleetCount = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);
#         $StarBaseDesignCount = (($decryptedData[5] & 0xF0) >> 4);
#         $logo = (($decryptedData[6] & 0xFF) >> 3);
#         $fullDataFlag = ($decryptedData[6] & 0x04) != 0;
#         $byte7 = $decryptedData[7];
#         # Password is decryptedData[12-15]
#         if ($debug) { print "blockId: $blockId, objectId: $objectId, number: $number, owner = $owner, typeId = $type\n"; }
#         print "playerID: $playerId, ShipSlotsUsed: $ShipSlotsUsed,  PlanetCount: $PlanetCount, FleetAndStarBaseDesignCount: $FleetAndStarBaseDesignCount, fleets: $FleetCount, starbase designs: $StarBaseDesignCount, logo: $logo\n";
#       }
      if ($blockId == 43) { # Check for special attributes in the Object Block
        if ($size == 2) {
  	      my $count = &read16(\@decryptedData, 0);
          if ($debug) { print "Count: $count\n"; }
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
           if ($debug) { print "blockId: $blockId, objectId: $objectId, number: $number, owner = $owner, typeId = $type\n"; }
           print "Mystery Trader: x: $x, y: $y, xDest: $xDest, yDest: $yDest, warp: $warp, met: " . &getPlayers($metBits) . ", $MTPart, turnNoDisplay=$turnNoDisplay\n";
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
            print "Mystery Trader: x: $x, y: $y, xDest: $xDest, yDest: $yDest, warp: $warp, met: " . &getPlayers($metBits) . ", $MTPart, turnNoDisplay=$turnNoDisplay\n";
 
          # Minefields
          } elsif (&isMinefield($type)) {
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
            $mineCount = &read32(\@decryptedData, 6);
            # Missing owner, decay rate (might be calculated)
            $canSee = &read16(\@decryptedData, 10);
            $unk3 = &read16(\@decryptedData, 12);   # includes detonating
            $unk3 = dec2bin($unk3);
            my @unk3;
            for (my $i=0; $i < 16; $i++)  {
              $unk3[$i] = substr($unk3,$i,1); 
            }
            $mineDetonate = &getMineDetonate(\@unk3); # bit 7 is detonating  status
            $mineType = &getMineType(\@unk3); # bit 14+15 = mine type
            $unk4 = &read16(\@decryptedData, 14);  # Not player ID
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            if ($debug) { print "blockId: $blockId, objectId: $objectId, minefieldId: $number, playerId: $owner, typeId: $type\n"; }
            print "MineField: x: $x, y: $y, mineCount: $mineCount, canSee: " . &getPlayers($canSee) . ", $mineType, $mineDetonate, turnNo:$turnNoDisplay\n";
            if ($clean) {
              # Hard to find any data here as not much is known of the format
              # Reset players who can see the minefield
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $canSee = &read16(\@decryptedData, 10);
            }
            print "MineField: x: $x, y: $y, mineCount: $mineCount, canSee: " . &getPlayers($canSee) . ", $mineType, $mineDetonate, turnNo:$turnNoDisplay\n";

          #Wormholes
          } elsif (isWormhole($type)) {
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
            $stability = &read16(\@decryptedData, 6);
            $stability = &dec2bin($stability);
  		      $canSee = &read16(\@decryptedData, 8);
  		      $beenThrough = &read16(\@decryptedData, 10);
  		      $targetId = &read16(\@decryptedData, 12) % 4096;   
            $unk4 =  &read16(\@decryptedData, 12);
            $unk4 = &dec2bin ($unk4);                        
            $unk5 =  &read16(\@decryptedData, 14);  # Always zeros? 
            $unk5 = &dec2bin ($unk5);                        
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            if ($debug) { print "blockId: $blockId, objectId: $objectId, wormholeId: $number, typeId = $type\n"; }
            print "Wormhole: x: $x, y: $y, TID: $targetId, stability: $stability, beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee) . ", unk5: $unk5, unk4: $unk4, turnNoDisplay=$turnNoDisplay\n";
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
            print "Wormhole: x: $x, y: $y, TID: $targetId, beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee) . ", turnNoDisplay=$turnNoDisplay\n";

          # Packet
          } elsif (isPacketOrSalvage($type)) {
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
            $unk5 = &read16(\@decryptedData, 14); # fairly certain this isn't a player ID
            $turnNo = &read16(\@decryptedData, 16); # Doesn't appear to be turn info like the rest
            $turnNoDisplay = $turnNo + 2401;
            if ($debug) { print "blockID: $blockId, objectId: $objectId, salvageId: $number, ownerId: $owner, typeId: $type\n"; }
            my $warpSpeed = $WarpSpeedMinus4 + 4;
            print "Packet: x: $x, y: $y, DestPlanetId: $destPlanetId, " . &getPacketType($destPlanetId) . ", Warp Speed: " . $warpSpeed . ", WarpOverMDLimit: $WarpOverMDLimit,  ironium: $ironium, boranium: $boranium, germanium: $germanium, unk5: $unk5, turnNo:$turnNoDisplay\n";
            if ($clean) {
              # Decay rate wouldn't be public.
              # Packet ownership must be included in here somewhere
            }
            print "Packet: x: $x, y: $y, DestPlanetId: $destPlanetId, " . &getPacketType($destPlanetId) . ", Warp Speed: $warpSpeed, WarpOverMDLimit: $WarpOverMDLimit,  ironium: $ironium, boranium: $boranium, germanium: $germanium, unk5: $unk5, turnNo:$turnNoDisplay\n";
          }
        }
      }
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

sub isPacketOrSalvage() {
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
  # unpredictably. But I can't ge tteh math to work out. 
   
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
  my $binary;
  $binary = &dec2bin($itemBits);
  if ($debug > 1) { print "itemBits: $binary\n"; }
  if ($itemBits == 0) { return 'Research'; }
  if (&bit_test($itemBits, 0)) { return 'Multi Cargo Pod';    }
  if (&bit_test($itemBits, 1)) { return 'Multi Function Pod'; }
  if (&bit_test($itemBits, 2)) { return 'Langston Shield';    }
  if (&bit_test($itemBits, 3)) { return 'Mega Poly Shell';    }
  if (&bit_test($itemBits, 4)) { return 'Alien Miner';        }
  if (&bit_test($itemBits, 5)) { return 'Hush-a-Boom';        }
  if (&bit_test($itemBits, 6)) { return 'Anti Matter Torpedo'; }
  if (&bit_test($itemBits, 7)) { return 'Multi Contained Munition'; }
  if (&bit_test($itemBits, 8)) { return 'Mini Morph';         }
  if (&bit_test($itemBits, 9)) { return 'Enigma Pulsar';      }
  if (&bit_test($itemBits, 10)) { return 'Genesis Device';    }
  if (&bit_test($itemBits, 11)) { return 'Jump Gate';         }
  if (&bit_test($itemBits, 12)) { return 'Ship/MT Lifeboat';  }
 	return '';
}

# sub getPRTName{
# #      public static class PRT {
# #         public static int HE = 0;
# #         public static int SS = 1;
# #         public static int WM = 2;
# #         public static int CA = 3;
# #         public static int IS = 4;
# #         public static int SD = 5;
# #         public static int PP = 6;
# #         public static int IT = 7;
# #         public static int AR = 8;
# #         public static int JOAT = 9;
# #     }
# }

sub getPlayers {
  my ($getBits) = @_;
  my ($getString);
  $getString = '';
#  if ($debug) { print "getPlayers: " . &dec2bin($getBits) . "\n"; }
 	for (my $loop = 0; $loop < 16; $loop++){
    if (&bit_test($getBits, $loop)) { 
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
  # Check to see if the current player is in the list
  # If we just blank the value, we lose data. 
 	for (my $loop = 0; $loop < 16; $loop++){
    if (&bit_test($getBits, $loop)) { 
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

sub bit_test {
  # Returns 0 if the associated bit in a decimal number is zero.
  # Useful given the number of times data is stored by bit.
  my ($value, $bit) = @_;
  return $value & (1 << $bit);
}
