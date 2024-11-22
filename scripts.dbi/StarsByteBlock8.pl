# StarsByte.pl
# Displays Stars! Block Data
# Test file for debugging Block 8 decoding
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

# Displays the bytes of a Stars! Block

# Example Usage: StarsByte.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;  
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 1; # Enable better debugging output. Bigger the better

##########  
my $inBlock = '';
my $inBin = 0; 
my $inName;
my $filename; 
$inName = $ARGV[0]; # input file
$inBlock = $ARGV[1]; # Desired block Type
$inBin = $ARGV[2]; # Desired block Type
unless ($inBlock) { $inBlock = -1;}
$filename = $inName;

if (!($inName)) { 
  print "\n\nDisplays the (decrypted) byte information in Stars! blocks.\n";
  print "Will delimited-output Block Type, and bytes in decimal (or binary).\n";
  print "If you include the Block Type, will list only that block type.\n";
  print "For binary, add a third command line parameter.\n";
  print "\nUsage: StarsByte.pl <input> <Block Type (optional)>\n\n";
  print "Please enter the Stars! file as input. Example: \n";
  print "  StarsByte.pl c:\\games\\test.m6 43 1\n\n";
  print "Worth noting that if the specific data is \n";
  print "two bytes, the data is stored: \n";
  print "  A B C D E F\n";
  print "but actually read by Stars! as:\n";
  print "  (B A) (D C) (F E)\n\n";
  print "Data is also often tightly packed, so the binary result represents\n";
  print "the information using the bits (0 or 1).\n";
  exit;
}

#Validate directory or file 
unless (-e $inName ) { 
  print "File: $inName does not exist!\n"; exit; 
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

sub decryptBlock {
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
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {  # File Header Block
      # Convert the nonencrypted Block 8 data
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      &processData(\@unshiftedData,$typeId,$offset,$size, $inBlock);
      
# 2 bytes: Header    
# 4 bytes: (0/3): Magic
# 4 bytes: (4/7): GameID
# 2 bytes: (8/9): version
# 2 bytes: (10/11): turn number
# 2 bytes: (12/13): Player and encryption seed
# 1 byte: File type
#   Bit 0 (1) - Turn Submitted
#   Bit 1 (2) - Host is using file
#   Bit 2 (4) - Multiple turns in .m file
#   Bit 3 (8) - Game over
#   Bit 4 (16)- Shareware Version
        my $rickMagic            = &read32(\@unshiftedData, 0);  print "Magic: $rickMagic\n";
        #my $rickMagicStr        = &decodeBytesForStarsString(@unshiftedData[0..4]);  print "MagicStr: $rickMagicStr\n";  #Broken
        #my $rickMagicStr        = unpack ("A4", $rickMagic);  print "MagicStr: $rickMagicStr\n";  #Broken
        my $rickGameID           = &read32(\@unshiftedData, 4);  print "GameId: $rickGameID\n";
        my $rickVersion          = &read16(\@unshiftedData, 8);  print "Version: $rickVersion\n";
		      my $rickversionMajor = $rickVersion >> 12;         # First 4 bits
          print "\tMajor: $rickversionMajor\n";
		      my $rickversionMinor = ($rickVersion >> 5) & 0x7F; # Middle 7 bits
          print "\tMinor: $rickversionMinor\n";
		      my $rickversionIncrement = $rickVersion & 0x1F;    # Last 5 bits
          print "\tIncrement: $rickversionIncrement\n";
        my $rickTurnNumber       = &read16(\@unshiftedData, 10);  print "Turn Number: $rickTurnNumber\n";
        my $rickplayerData             = &read16(\@unshiftedData, 12); print "PlayerData: $rickplayerData\n";
          my $rickencryptionSalt = $rickplayerData >> 5;  # First 11 bits
          print "\tSalt: $rickencryptionSalt\n";
  		    my $rickplayerNumber = $rickplayerData & 0x1F;  # Last 5 bits
          print "\tPlayer Number: $rickplayerNumber\n";
        my $rickfiletype          = &read8($unshiftedData,14); print "FileType: $rickfiletype\n";
    		my $rickflags = &read8($unshiftedData,15);
      		my $rickunknownBits = (($rickflags >> 5) & 0x07);
          print "\tUnknown: $rickunknownBits\n";
      		my $rickturnSubmitted = ($rickflags & 1) > 0;
          print "\tSubmitted: $rickturnSubmitted\n";
      		my $rickhostUsing =     ($rickflags & (1 << 1)) > 0;
          print "\tUsing: $rickhostUsing\n";
      		my $rickmultipleTurns = ($rickflags & (1 << 2)) > 0;
          print "\tMultiple: $rickmultipleTurns\n";
      		my $rickgameOver =      ($rickflags & (1 << 3)) > 0;
          print "\tGame Over: $rickgameOver\n";
      		my $rickshareware =     ($rickflags & (1 << 4)) > 0;		
          print "\tShareware: $rickshareware\n";
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      &processData(\@unshiftedData,$typeId,$offset,$size, $inBlock);
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      &processData(\@decryptedData,$typeId,$offset,$size, $inBlock);
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug > 1) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}
