#!/usr/bin/perl
# StarsByteChange.pl
# Change Bytes in a StarsFile
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191122  Version 1.0
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
# Example Usage: StarsByteChange.pl c:\stars\game.m1
#
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;  
use FindBin;
use lib $FindBin::Bin;
 
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my $inBlock = '';
my $inBin = 0; 
my $inName = $ARGV[0]; # input file
my $outFileName = $ARGV[1];
# $inBlock = $ARGV[1]; # Desired block Type
# $inBin = $ARGV[2]; # Desired block Type
# unless ($inBlock) { $inBlock = -1;}
$inBlock = -1;   # show every block (the 2nd argument is the output file)
my $filename = $inName;

if (!($filename)) { 
  print "\n\nUsage: StarsByteChange.pl <input file> <output file (optional)>\n\n";
  print "Please enter the input file (.m or .hst). Example: \n";
  print "  StarsByteChange.pl c:\\games\\test.m6\n\n";
  print "By default, a new file will be created: <filename>.clean\n\n";
  print "You can create a different file with StarsByteChange.pl <filename> <newfilename>\n";
  print "  StarsByteChange.pl <filename> <filename> will overwrite the original file.\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
$dir =~ s/\\/\//g;  # normalize to forward slashes
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

my @fileBytes = &readFile($filename);

# Decrypt the data, block by block
my ($outBytes) = &decryptBlock(@fileBytes);
#my ($outBytes) = &decryptBlock();
my @outBytes = @{$outBytes};

# Create the output file name
my $newFile; 
if ($outFileName) {   $newFile = $outFileName;  } 
else { $newFile = $dir . '/' . $basefile . '.clean'; }
if ($debug) { $newFile = "f:/clean_" . $basefile;  } # Just for me

open (OUTFILE, '>:raw', "$newFile");
for (my $i = 0; $i < @outBytes; $i++) {
  print OUTFILE $outBytes[$i];
}
close (OUTFILE);

print "File output: $newFile\n";
unless ($ARGV[1]) { print "Don't forget to rename $newFile\n"; }

################################################################
sub decryptBlock {
  my (@fileBytes) = @_;
  my @block;
  #my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    #@data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    my @data = @block[2..$#block];
    
    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\t"; }
    if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
      my ($unshiftedData, $padding) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      &processData(\@unshiftedData,$typeId,$offset,$size, $inBlock);

      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
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
#      }
      # END OF MAGIC
      
      unless ($typeId == 30) { 
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
        push @outBytes, @encryptedBlock; 
      }
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}
      