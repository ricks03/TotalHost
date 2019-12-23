# StarsMsg.pl
# Displays Stars! Messages
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191119 , 191126, 191203
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

# Example Usage: StarsMsg.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#
# Displays player messages.
# This is intentionally standalone for a friend of mine.

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0; # Enable better debugging output. Bigger the better

my (@singularRaceName, @pluralRaceName);
$singularRaceName[0] = "Everyone"; # When there's no result

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
my $inName = $ARGV[0]; # input file
my $filename = $inName;

if (!($inName)) { 
  print "\n\nDisplays the Player Messages in a Stars! file.\n";
  print "\nUsage: StarsMsg.pl <input> \n";
  print "  StarsMsg.pl c:\\games\\test.m6\n\n";
  exit;
}

#Validate directory or file 
unless (-e $inName ) { 
  print "Requested file:> $inName <: does not exist!\n"; exit; 
}
print "\nFor File: $inName\n";

my ($basefile, $dir, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1  extension

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

  
################################################################
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
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($blockId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      &processData(\@decryptedData,$blockId,$offset,$size, $turn);
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
}

sub processData {
  # Display the messages in the file
  my ($decryptedData,$blockId,$offset,$size, $turn)  = @_;
  my @decryptedData = @{ $decryptedData };
  my $message;
  # We need the names to display
  # Check the Player Block so we can get the race names
  # although there are no names in .x files
  if ($blockId == 6) {
    my $playerId = $decryptedData[0];
    my $fullDataFlag = ($decryptedData[6] & 0x04);
    my $index = 8;
    if ($fullDataFlag) { 
      # The player names are at the end which is not a fixed length
      $index = 112;
      my $playerRelationsLength = $decryptedData[112]; 
      $index = $index + $playerRelationsLength + 1;
     } 
    my $singularNameLength = $decryptedData[$index] & 0xFF;
    my $singularMessageEnd = $index + $singularNameLength;
    my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
    $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
    $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
#    print "playerName $playerId: $singularRaceName[$playerId]:$pluralRaceName[$playerId]\n";  
  } elsif ($blockId == 40) { # check the Message block 
    my $byte0 =  &read16(\@decryptedData, 0);  # unknown
    my $byte2 =  &read16(\@decryptedData, 2);  # unknown
    my $senderId = &read16(\@decryptedData, 4);
    my $recipientId = &read16(\@decryptedData, 6);
    my $byte8 =  &read16(\@decryptedData, 8); # unknown
    my $messageBytes = &read16(\@decryptedData, 10);
    my $messageLength = $size -1;
    $message = &decodeBytesForStarsMessage(@decryptedData[11..$messageLength]);
    if ($debug) { print "blockId: $blockId\n"; }
    if ($debug) { print "\nDATA DECRYPTED:" . join ( " ", @decryptedData ), "\n"; }
#    print "From: $senderId, To: $recipientId, \"$message\"\n"; 
    my $turn_fix = $turn + 2400;
    if ($message) {
      if ($ext =~ /x/) { 
        # Different for x files, as we don't have player names in it.
        print "\nTurn:$turn_fix, From: Me, To: Player $recipientId, \"$message\"\n";
      } else { print "\nTurn:$turn_fix, From: $singularRaceName[$senderId], To: $singularRaceName[$recipientId-1], \"$message\"\n"; }
      if ($debug) { print "b0: $byte0, b2: $byte2, b8: $byte8\n"; }
    } else { print "No messages!\n"; }
  } 
  return @decryptedData;
}


