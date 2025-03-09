#!/usr/bin/perl
# StarsHash.pl
# Deals with Block 9 File Hash Block
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191119, 211102
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

# Displays the contents of Block 9
# Copy Protection Activates When Editing an Allies Turn File
# https://wiki.starsautohost.org/wiki/Known_Bugs

#// szWork[0] - szWork[3] : Label C:
#// szWork[4] - szWork[5] : C: date/time of volume
#// szWork[6] - szWork[8] : Label D:
#// szWork[9]             : D: date/time of volume
#// szWork[10]            : C: and D: drive size in 100's of MB

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
my $filename; 
$inFile1 = $ARGV[0]; # input file 1
$inFile2 = $ARGV[1]; # input file 2
$filename = $inFile1;

if (!($inFile1)) { 
  print "\n\nDisplays the file hash block information in Stars! .x file.\n";
  exit;
}

#Validate directory or file 
unless (-e $inFile1 ) { 
  print "File: $inFile1 does not exist!\n"; exit; 
}
unless (-e $inFile2 && $inFile2) { 
  print "File: $inFile2 does not exist!\n"; exit; 
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
      if ($debug>1) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug>1) { print "DATA UNSHIFTED:" . join (" ", @unshiftedData), "\n"; }

      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($debug > 1) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
      if ($debug > 1) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 9) {
        if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        &processHash(\@decryptedData,$typeId,$offset,$size);
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub processHash {
  # Display the byte information
  my ($decryptedData,$typeId,$offset,$size)  = @_;
  my @decryptedData = @{ $decryptedData };
  my $byte0 =  &read16(\@decryptedData, 0);  # unknown
  my $serial = &read32(\@decryptedData, 2);  # serial number, blocks 2-5
  print "Serial (Hash): $serial\n";
  my $c_label = &read32(\@decryptedData, 6);  # C drive volume label, blocks 6-9
  print "C: Label (Hash): $c_label\n";
  my $c_date = &read16(\@decryptedData, 10); # blocks 10-11. Probably C volume date
  print "C: Date (Hash): $c_date\n";
  my $d_label = &read16(\@decryptedData, 12);  # D drive volume label, blocks 12-13
  print "D: Label (Hash): $d_label\n";
  my $d_date = &read16(\@decryptedData, 14);  # probably D volume date
  print "D: Date (Hash): $d_date\n";
  my $drive_size = &read8(\@decryptedData,16); # C: and D: drive size in 100's of MB
  print "Drive Size (Hash): $drive_size\n";
}

