# StarsByte.pl
# Displays Stars! Block Data
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
  print "but actaully read by Stars! as:\n";
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
#print "FILENAME: $filename\n";
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
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($blockId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($blockId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    #if ($debug) { print "\nBLOCK blockId: $blockId, Offset: $offset, Size: $size\n"; }
    #if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($blockId == 8) {  # File Header Block
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
      &processData(\@decryptedData,$blockId,$offset,$size);
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

sub processData {
  # Display the byte information
  my ($decryptedData,$blockId,$offset,$size)  = @_;
  my @decryptedData = @{ $decryptedData };

  if ($inBlock == $blockId || $inBlock == -1) {
    if ($debug) { print "BLOCK:$blockId,Offset:$offset,Bytes:$size\t"; }
    if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
    if ($inBin) {
      if ($inBin ==1 || $inBin ==2 ){ print "\n"; }
      my $counter =0;
      foreach my $key ( @decryptedData ) { 
        print "byte  $counter:\t$key\t" . &dec2bin($key); if ($inBin ==1 || $inBin ==2 ) { print "\n"; }
        $counter++;
        
      }  
      print "\n";    
    } else {
#      print "\t" . join ( "\t", @decryptedData ), "\n";
    }
  }
}