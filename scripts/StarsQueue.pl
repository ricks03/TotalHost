# StarsQueue.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191123 
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

#
# Gets information from Build Queue
# Example Usage: StarsQueue.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# Doesn't really work completely

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
do 'config.pl';

my $debug = 1;

#########################################        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsQueue.pl <input file>\n\n";
  print "Please enter the input file (.R|.M|.X|.HST). Example: \n";
  print "  StarsQueue.pl c:\\games\\test.m1\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

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
my ($outBytes) = &decryptQueue(@fileBytes);


################################################################
sub decryptQueue {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug  > 1 ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 7) {
      # Note that planet's data requires something extra to decrypt. 
      # Fortunately block 7 isn't in my test files
      die "BLOCK 7 found. ERROR!\n";
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ( $typeId == 9  ) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
      if ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
        my $index;
        my $planetId; 
        my $queueItem;
        
        if ($typeId == 29)  {$planetId = &read16(\@decryptedData, 2); $index = 2; }
        else { $index = 0; }
        my ($queueItem, $count, $item, $completion);
        $queueItem = &read32(\@decryptedData, $index); # 4 bytes
        print "Queue: $queueItem\n";
        $queueItem = &dec2bin($queueItem);
        $count = substr($queueItem,22,10);       # 10 bits
        $count = &bin2dec($count);
        print "count: $count\n";
        $item = substr($queueItem,12,10); #10 bits
        $item = &bin2dec($item);
        print "item: $item\n";
        $completion = substr($queueItem,0,12); #12 bits
        $completion = &bin2dec($competion);
        print "completion: $completion\n";

# <Structure28 Description="Production Queue">
#   <QueueItem bytes="4" repeat="{bytes}/4">
#     <Count bits="10"/>
#     <Item bits="10"/>
#     <Completion bits="12"/>
#   </QueueItem>
# </Structure28>      
# <Structure29 Description="Production Queue (x file)">
#   <PlanetID bytes="2"/>
#   <QueueItem bytes="4" repeat="({Bytes}-2)/4">
#     <Count bits="10"/>
#     <Item bits="10"/>
#     <Completion bits="12"/>
#   </QueueItem>
# </Structure29>
      
      }
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}



