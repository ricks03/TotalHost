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
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
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
        
my $inBlock = '';
my $inBin = 0; 
my $inName = $ARGV[0]; # input file
my $outFileName = $ARGV[1];
$inBlock = $ARGV[1]; # Desired block Type
$inBin = $ARGV[2]; # Desired block Type
unless ($inBlock) { $inBlock = -1;}
my $filename = $inName;

if (!($filename)) { 
  print "\n\nUsage: StarsByteChange.pl <input file> <output file (optional)>\n\n";
  print "Please enter the input file (.M or .HST). Example: \n";
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
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

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
#my ($outBytes) = &decryptBlock();
my @outBytes = @{$outBytes};

# Create the output file name
my $newFile; 
if ($outFileName) {   $newFile = $outFileName;  } 
else { $newFile = $dir . '\\' . $basefile . '.clean'; }
if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me

open (OutFile, '>:raw', "$newFile");
for (my $i = 0; $i < @outBytes; $i++) {
  print OutFile $outBytes[$i];
}
close (OutFile);

print "File output: $newFile\n";
unless ($ARGV[1]) { print "Don't forget to rename $newFile\n"; }

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
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\t"; }
    if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      my ($nocryptedData, $padding) = &displayBytes(\@data); 
      my @nocryptedData = @{ $nocryptedData };
      &processData(\@nocryptedData,$typeId,$offset,$size);
      #$fileFooter = &getFileFooterBlock(\@data, $size);
      #print "Footer $fileFooter\n";
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      if ($debug) { print "\nDATA DECRYPTED:\n" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
#      if ($typeId == 29) {
#        $skip = 1;
#        $skipcounter = $skipcounter + $size;
#      } else { 
      &processData(\@decryptedData,$typeId,$offset,$size);
#      }
      # END OF MAGIC
      #my $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
#       # 1. Concatenate Array values
#       print "Block0: $block[0] , Block1: $block[1]\n";
#       my $BlockValues = $block[1] . $block[0];
#       print "BlockValues: $BlockValues\n";
#       # 2. unpack array values
#       my ($Header) =  unpack("S",$BlockValues);
#       print "Header: $Header\n";
#       # 3. convert string array values to binary
#       my $binHeader = dec2bin($Header);
#       print "Binheader: $binHeader\n";
#       # 4. slice up Header to two values
#       my $blocktype = (substr($binHeader, 8,6));
#       my $blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
#       print "STUFF: $typeId, $size, $blocktype, $blocksize\n";
#       
#       # Right here we can change the block size in decimal
#       # and then the following code will convert it all back into the 
#       # correct structure, switching back and forth from decimal<> binary
#       # 5. change block size.
#       #my $blocksize2 = dec2bin(6);
#       my $blocksize2 = "$blocksize";  # Just convert back from whence we came
#       print "BS: $blocksize2\n";
#       # 4. unslice up the two values
#       $blocksize2 = substr($blocksize2,-10); # Make it the right length (10 bits)
#       print "BS2: $blocksize2\n";
#       my $bt = substr($blocksize2, 2,10) . $blocktype . substr($blocksize2,0,2);
#       # 3. convery the binary to decimal
#       my $binHeader2 = bin2dec($bt);
#       # 2. Pack values
#       my $Header2 = pack ("S", $binHeader2);
#       print "Header2: $Header2\n";
#       # 1. Assign array values
#       $block[0] = substr($Header2,1,1);
#       $block[1] = substr($Header2,0,1);
#       print "Block0: $block[0] , Block1: $block[1]\n\n";
      # reencrypt the data for output
      
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

#################################

sub processData {
  # Display the byte information
  my ($decryptedData,$typeId,$offset,$size)  = @_;
  my @decryptedData = @{ $decryptedData };

  if ($inBlock == $typeId || $inBlock eq -1) {
  print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t";
  if ($inBin) {
    if ($inBin ==1 || $inBin ==2 ){ print "\n"; }
    my $counter =0;
    foreach my $key ( @decryptedData ) { 
      print "byte  $counter:\t$key\t" . &dec2bin($key); if ($inBin ==1 || $inBin ==2 ) { print "\n"; }
      $counter++;
    }  
    print "\n";    
  } else {print "\t" . join ( " ", @decryptedData ), "\n";}
  }
}

