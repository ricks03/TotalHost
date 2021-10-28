# StarsHash.pl
# Deals with Block 9 File Hash Block
# NOT WORKING
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
# Copy Protection Activates When Editing an Allies Turn File
# https://wiki.starsautohost.org/wiki/Known_Bugs

# Factors in 
#// Fills in the vrgbEnvCur buffer with the following:
#// szWork[0] - szWork[3] : Label C:
#// szWork[4] - szWork[5] : C: date/time of volume
#// szWork[6] - szWork[8] : Label D:
#// szWork[9]             : D: date/time of volume
#// szWork[10]            : C: and D: drive size in 100's of MB
#// Returns the length of vrgbEnvCur data (usually 11)

# GlobalSettings=IUK30dFAN9eY1pKABAL3tVcWUpnp
# is for SAH62J1E

# GlobalSettings=DVK31UFA29lCFpKAAwZb1VcW1onp
# is for E2WAENCB

# Example Usage: StarsHash.pl c:\stars\game.x1
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
  print "\n\nDisplays the hash information in Stars! blocks.\n";
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

    #if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {  # File Header Block
      # Convert the nonencrypted Block 8 data
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug) { print "DATA UNSHIFTED:" . join (" ", @unshiftedData), "\n"; }

      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      my $gameId = &read32(\@unshiftedData, 4); 
      print "gameId: $gameId  lidGame: $lidGame\n";
    } elsif ($typeId == 0) {
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      $debug = 1;
      if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }

    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      $debug = 1;
      if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 9) {
        &processData(\@decryptedData,$typeId,$offset,$size);
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub processData {
  # Display the byte information
  my ($decryptedData,$typeId,$offset,$size)  = @_;
  my @decryptedData = @{ $decryptedData };
  my $ordersSum = &read16(\@decryptedData, 0); print "OrdersSum: $ordersSum\n";

#The remaining 15 bytes are Machine and Serial no hashes according to PaulCr.
  
  die;
}

