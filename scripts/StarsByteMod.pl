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

##########  
my $inBlock = '';
my $inBin = 0; 
my $inName;
my $filename; 
my $outFileName;
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

my $block9 = 0;
my $byteCalc = 0;
my @decryptedBlock;
# Decrypt the data, block by block
my ($outBytes, $decryptedBlock) = &decryptBlock(@fileBytes);
#my ($outBytes, $decryptedBlock) = &decryptBlock();
my @outBytes = @{$outBytes};
@decryptedBlock = @{$decryptedBlock};

# So we can mod Mod block 9
$debug = 1;
# Instead of doing complicated math along the way, just recalculate it
my $blockBytes = 0;
foreach my $blockCounter (@decryptedBlock) {
      my %blockCounter = %$blockCounter;
      my $typeId = $blockCounter{typeId};
      my $size = $blockCounter{size};
      if ( $typeId != 9  && $typeId != 0 ) {
        $blockBytes = $blockBytes + ($size + 2);
      }
}
print "BlockBytes: $blockBytes\n";

foreach my $blockCounter (@decryptedBlock) {
      my %blockCounter = %$blockCounter;
      my @encryptedBlock;
      my $encryptedBlock;
      my @block = @$blockCounter{block};
      my $typeId = $blockCounter{typeId};
      my $size = $blockCounter{size};
      my @decryptedData = @$blockCounter{decryptedData};
      my $padding = $blockCounter{padding};
      my $seedX = $blockCounter{seedX};
      my $seedY = $blockCounter{seedY};
#      if ($typeId == 9) {
#        # update the Block 9 checksum with the adjusted checksum
#         ($block[0], $block[1]) = write16($blockBytes);
#      }
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug > 1) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
}

my $newFile; 
if ($outFileName) { $newFile = $outFileName;  } 
else { $newFile = $dir . '\\' . $basefile . '.clean'; }
open (OutFile, '>:raw', "$newFile");
#  for (my $i = 0; $i < @outBytes; $i++) {
foreach my $value (@outBytes) {
  if ($value) { print OutFile $value; }
}
close (OutFile);

 
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
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $blockCounter = 0;
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {  # File Header Block
       # Convert the nonencrypted Block 8 data
       my ($unshiftedData, $padding) = &unshiftBytes(\@data); 
       my @unshiftedData = @{ $unshiftedData };
      &processData(\@unshiftedData,$typeId,$offset,$size);

      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      $decryptedBlock[$blockCounter]{block} = \@block;
      $decryptedBlock[$blockCounter]{typeId} = $typeId;
      $decryptedBlock[$blockCounter]{size} = $size;
      $decryptedBlock[$blockCounter]{decryptedData} = \@decryptedData;
      $decryptedBlock[$blockCounter]{padding} = $padding;
      $decryptedBlock[$blockCounter]{seedX} = $seedX;
      $decryptedBlock[$blockCounter]{seedY} = $seedY;
      $blockCounter++;

      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
       my ($unshiftedData, $padding) = &unshiftBytes(\@data); 
       my @unshiftedData = @{ $unshiftedData };
      &processData(\@unshiftedData,$typeId,$offset,$size);
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      &processData(\@decryptedData,$typeId,$offset,$size);
      # END OF MAGIC
 #     unless ($typeId == 30) {
      $decryptedBlock[$blockCounter]{block} = \@block;
      $decryptedBlock[$blockCounter]{typeId} = $typeId;
      $decryptedBlock[$blockCounter]{size} = $size;
      $decryptedBlock[$blockCounter]{decryptedData} = \@decryptedData;
      $decryptedBlock[$blockCounter]{padding} = $padding;
      $decryptedBlock[$blockCounter]{seedX} = $seedX;
      $decryptedBlock[$blockCounter]{seedY} = $seedY;
      $blockCounter++;
      #reencrypt the data for output
      print "SeedX: $seedX, $seedY \n";
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug > 1) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
  #    }
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, \@decryptedBlock;
}

sub processData {
  # Display the byte information
  my ($decryptedData,$typeId,$offset,$size)  = @_;
  my @decryptedData = @{ $decryptedData };
  if ($inBlock == $typeId || $inBlock == -1) {
    if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
    if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
    if ($inBin) {
      if ($inBin ==1 || $inBin ==2 ){ print "\n"; }
      my $counter =0;
      foreach my $key ( @decryptedData ) { 
        print "byte  $counter:\t$key\t" . &dec2bin($key); if ($inBin ==1 || $inBin ==2 ) { print "\n"; }
        $counter++;
      }  
      print "\n";    
    }
  }
}

