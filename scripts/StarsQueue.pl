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
# Gets information from Production Queue
# Example Usage: StarsQueue.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# Doesn't really work completely

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
#use StarStat; # A Perl module from TotalHost
  # Have FileData subroutine local
do 'config.pl';

my $debug = 1;

#########################################        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsQueue.pl <input file>\n\n";
  print "Please enter the input file (.M|.X|.HST). Example: \n";
  print "  StarsQueue.pl c:\\games\\test.m1\n\n";
  print ".HST files will output the queue from all planets so\n";
  print " it can be used when checking .x files for queue issues.\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $basename, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1
$basename = $basefile;
$basename =~  s/$ext//;

my ($game_file, $file_player, $file_type, $file_ext) = &FileData ($basefile); 

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
my ($outBytes, $queueBlock) = &decryptQueue(@fileBytes);
my @outBytes = @{$outBytes};
my @queueBlock = @{$queueBlock};


# Write out the BuildQueue for .HST files
my $queueFile;
my @queueList;
$queueFile = $dir . '\\' . $basefile . '.queue';
if (@queueBlock && lc($ext) eq '.hst') {
  #$queueBlock = "$Player,$planetId,$itemId,$count,$completePercent,$itemType,$size";
  print "Writing out QUEUEFILE $queueFile...\n";
  open (QUEUEFILE, ">$queueFile");
  for my $value (@queueBlock) {
    print QUEUEFILE $value . "\n";
  }
  close QUEUEFILE;
  print "Done writing\n";
} elsif (-e $queueFile && $file_type eq 'x') {
  # Check the productionchangequeue for issues
  ############################################
  # Read in all the planetary queues not assuming they
  # have been written out to a .HST file previously
  
  # Read in the file data
  print "Reading in QUEUEFILE $queueFile\n";
  open (IN_FILE,$queueFile) || die("Cannot open $queueFile file");
  @queueList = <IN_FILE>;
	close IN_FILE;
  print "Done reading in $queueFile\n";
  # Turn the file into a usable array
  my($Player,$planetId,$itemId,$count,$completePercent,$itemType,$queueSize);
  my %queueList;
  my $queueId;
  foreach my $line (@queueList) {
  	chomp($line);
   	($Player,$planetId,$itemId,$count,$completePercent,$itemType,$queueSize)	= split (",", $line);
    $queueId = "$Player,$itemId";
    $queueList{$queueId} = [$itemId,$count,$completePercent,$itemType,$queueSize];  
  }
    
  # Compare the productionchangeblock orders to the existing production queues
  print "Running Compare\n";
  foreach my $value ( @queueBlock ) {
    print "Compare: $Player,$planetId,$itemId,$count,$completePercent,$itemType, $queueSize\n";
    ($Player,$planetId,$itemId,$count,$completePercent,$itemType,$queueSize)	= split (",", $value); 
    $queueId = "$Player,$itemId";
    if ($queueList{$queueId}[7] == 4 && $queueList{$queueId}[4] == $value) {
      print "You can't change that starbase\n";
    }
  }
}

################################################################
sub decryptQueue {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my @queueBlock;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  my ($planetId, $owner); 
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug > 1 ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    if ($typeId == 8) {     # FileHeaderBlock, never encrypted
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
      if ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .M and .HST file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $owner = ($decryptedData[1] & 0xF8) >> 3;
        if ($owner == 31) { $owner = -1; }
      } elsif ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
        if ($typeId == 28) { $Player = $owner; }

        if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; 
        my $index = 0;
        my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
        # Testing for ProductionQueueChangeBlock
        if ($typeId == 29) { 
          $index = $index + 2;
          $planetId = &read16(\@decryptedData, 0);
          print "Planet Id: $planetId\n"; 
        } 
        for (my $i=$index; $i <= scalar(@decryptedData) -4; $i=$i+4) {
          $chunk1 = &read16(\@decryptedData, $i);
          $chunk2 = &read16(\@decryptedData, $i+2);
          $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
          $count = $chunk1 & 0x3FF; # Bottom 10 bits
          $completePercent = $chunk2 >> 4; #Top 12 bits
          $itemType = $chunk2 & 0xF; # bottom 4 bits
          # if not a .x file, we have to get the player Id from the planet info
          if ($owner) { $Player = $owner } else { $Player = $Player; }
          print "Player: $Player, planetId: $planetId, Queue: itemId: $itemId, count: $count, %complete: $completePercent, itemType: $itemType, size: $size\n"; 
          if ($typeId == 28) {
            my $queueBlock = "$Player,$planetId,$itemId,$count,$completePercent,$itemType,$size";
            push  @queueBlock, $queueBlock;
          }
        }
      }  
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, \@queueBlock;
}

sub FileData {
	# break out the incoming file name to useful bits
	my ($File) = @_;
	$File = lc($File); 
	my $game_file = lc($File);
	$game_file=~ s/(.*)(\..+)/$1/;
	my $file_player = lc($File);
	$file_player =~ s/(.*)(\.)(.)(.*)/$4/;
	my $file_type = lc($File); 
	$file_type =~ s/(.*)(\.)(.)(.*)/$3/;
	my $file_ext = lc($File);
	$file_ext =~ s/(.*)(\.)(.*)/$3/;
	return $game_file, $file_player, $file_type, $file_ext; 	
}
