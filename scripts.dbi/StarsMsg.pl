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
# Displays player messages
# .hst files don't have message blocks.

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost

my (@singularRaceName, @pluralRaceName);
$singularRaceName[0] = 'Everyone'; # When there's no result
$pluralRaceName[0] = 'Everyone'; # When there's no result

##########  
my @mFiles; # .m files in the directory
my @mDirs; # subdirs with turns in them     
my $inName = $ARGV[0]; # input file
my $filename = $inName;

if (!($inName)) { 
  print "\n\nDisplays the Player Messages in a Stars! file.\n";
  print "\nUsage: StarsMsg.pl <input> \n";
  print "  StarsMsg.pl c:\\games\\test.m6\n\n";
  print "  StarsMsg.pl c:\\games\\test.x6\n\n";
  print "  StarsMsg.pl c:\\games will list all messages in the folder\n";
  print "    If there are 2xxx subfolders, it will scan through those too!\n";
  exit;
}

#Validate directory or file 
unless (-e $inName || -d $inName) { 
  print "Requested object: $inName does not exist!\n"; exit; 
}

# Get all the file names in the directory, or just the one name
# Note that directories test for files, but files don't test
# for directories
if (-e $inName && -f _) { # if it exists, and it's just a file (not a directory)
  # If a single .m or .x file name was specified
  if ($inName =~ /^.*\.[MmXx]\d*$/ ) {   $mFiles[0] = $inName; }
} elsif (-d $inName) {  
  # If a directory name was specified
  my $file;
  opendir(BIN, $inName) or die "Cannot open directory $inName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    # Add any subdirs in the right format
    if ( $file =~ /^2[0-9][0-9][0-9]/ ) { # won't work if into the turn 3xxx but whatever
      push @mDirs, "$inName\\$file";
      next;
    }
    next unless ($file =~  /^.*\.[MmXx]\d*$/ ); #prefiltering for .m and .x files
    push @mFiles, "$inName\\$file";
  }
}

# OK, now lets get all the files from any potential backup subdirectories
foreach my $dirName (@mDirs) {
  my $file;
  opendir(BIN, $dirName) or die "Cannot open directory $dirName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /^.*\.[MmXx]\d*$/ ); #prefiltering for .m / .x files
    push @mFiles, "$dirName\\$file";
  }
}

if (@mFiles == 0) { 
  die "Something went wrong. There\'s no information\nDid you specify a .m or .x file?\n"; 
}

# foreach my $fileName (@mFiles) {
#  print "Filename: $fileName\n";
# }
# die;

my ($basefile, $dir, $ext);   
foreach $filename (@mFiles) {
  # Loop through for each .m|x file in the directory
  # for c:\stars\mygamename.m1
  $basefile = basename($filename);    # mygamename.m1
  $dir  = dirname($filename);         # c:\stars
  ($ext) = $basefile =~ /(\.[^.]+)$/; # .m1  extension
  
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  print "\nFor File: $filename\n";
  open(StarFile, "<$filename" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my ($outBytes) = &decryptMessages(@fileBytes);
  my @outBytes = @{ $outBytes };
  unless (scalar (@outBytes)) { print "No message(s) found.\n" };  
  foreach my $message (@outBytes) {
    print $message;
  }
}
  
################################################################
# sub decryptMessages {
#   my (@fileBytes) = @_;
#   my @block;
#   my @data;
#   my ($decryptedData, $encryptedBlock, $padding);
#   my @decryptedData;
#   my @encryptedBlock;
#   my @outBytes;
#   my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
#   my ($random, $seedA, $seedB, $seedX, $seedY );
#   my ( $FileValues, $typeId, $size );
#   my $currentTurn;
#   my $offset = 0; #Start at the beginning of the file
#   my @messages;
#   while ($offset < @fileBytes) {
#     # Get block info and data
#     $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
#     ( $typeId, $size ) = &parseBlock($FileValues, $offset);
#     @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
#     @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
# 
#     if ($typeId == 8 ) { # File Header Block, never encrypted
#       # We always have this data before getting to block 6, because block 8 is first
#       # If there are two (or more) block 8s, the seeds reset for each block 8
#       ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
#       if ($fMulti) { 
#         my @footer =  ( $fileBytes[-2], $fileBytes[-1] );
#         $currentTurn = &getFileFooterBlock(\@footer, 2) + 2400; 
#         push @messages, "Current Year: $currentTurn\n";
#       } 
#       ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
#     } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
#     } else {
#       # Everything else needs to be decrypted
#       ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
#       @decryptedData = @{ $decryptedData };  
#       # WHERE THE MAGIC HAPPENS
#       # Display the messages in the file
#       my $message;
#       # We need the names to display
#       # Check the Player Block so we can get the race names
#       # although there are no names in .x files
#       if ($typeId == 6) { # Player Block
#         my $playerId = $decryptedData[0] & 0xFF;
#         my $fullDataFlag = ($decryptedData[6] & 0x04);
#         my $index = 8;
#         if ($fullDataFlag) { 
#           # The player names are at the end which is not a fixed length
#           $index = 112;
#           my $playerRelationsLength = $decryptedData[112]; 
#           $index = $index + $playerRelationsLength + 1;
#          } 
#         my $singularNameLength = $decryptedData[$index] & 0xFF;
#         my $singularMessageEnd = $index + $singularNameLength;
#         # changed this 210516
#         #my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
#         my $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
#         if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
#         $playerId++; # As 0 is "Everyone" need to use representative IDs
#         $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
#         $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
#       } elsif ($typeId == 40) { # check the Message block 
#         my $byte0 =  &read16(\@decryptedData, 0);  # unknown
#         my $byte2 =  &read16(\@decryptedData, 2);  # unknown
#         my $senderId = &read16(\@decryptedData, 4);
#         my $recipientId = &read16(\@decryptedData, 6);
#         my $byte8 =  &read16(\@decryptedData, 8); # unknown
#         my $messageBytes = &read16(\@decryptedData, 10);
#         my $messageLength = $size -1;
#         $message = &decodeBytesForStarsString(@decryptedData[11..$messageLength]);
#     #    print "From: $senderId, To: $recipientId, \"$message\"\n"; 
#         if ($message) {
#           if ($ext =~ /[xX]/) { 
#             # Different for x files, as we don't have player names in it.
#             # Player ID #s are a bit weird, as 0 in this case is "everyone", not Player 1 (ID:0)
#             if ( $recipientId == 0 ) { $recipientId = 'Everyone'; } else { $recipientId = 'Player ' . $recipientId; }
#             push @messages, "\tMessage Year:" . ($turn+2400) . ", From: Me, To: $recipientId, \"$message\"\n";
#           } else { 
#             push @messages, "\tMessage Year:" . ($turn+2400) . ", From: $singularRaceName[$senderId+1], To: $singularRaceName[$recipientId], \"$message\"\n";
#           }
#         } 
#       } 
#       #return @decryptedData;
#       # END OF MAGIC
#     }
#     $offset = $offset + (2 + $size); 
#   }
#   return \@messages;
# }

# sub processData {
#   # Display the messages in the file
#   my ($decryptedData,$typeId,$offset,$size,$turn)  = @_;
#   my @decryptedData = @{ $decryptedData };
#   my $message;
#   # We need the names to display
#   # Check the Player Block so we can get the race names
#   # although there are no names in .x files
#   if ($typeId == 6) { # Player Block
#     my $playerId = $decryptedData[0] & 0xFF;
#     my $fullDataFlag = ($decryptedData[6] & 0x04);
#     my $index = 8;
#     if ($fullDataFlag) { 
#       # The player names are at the end which is not a fixed length
#       $index = 112;
#       my $playerRelationsLength = $decryptedData[112]; 
#       $index = $index + $playerRelationsLength + 1;
#      } 
#     my $singularNameLength = $decryptedData[$index] & 0xFF;
#     my $singularMessageEnd = $index + $singularNameLength;
#     # changed this 210516
#     #my $pluralNameLength = $decryptedData[$index+2] & 0xFF;
#     my $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
#     if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
#     $playerId++; # As 0 is "Everyone" need to use representative IDs
#     $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
#     $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);
#   } elsif ($typeId == 40) { # check the Message block 
#     my $byte0 =  &read16(\@decryptedData, 0);  # unknown
#     my $byte2 =  &read16(\@decryptedData, 2);  # unknown
#     my $senderId = &read16(\@decryptedData, 4);
#     my $recipientId = &read16(\@decryptedData, 6);
#     my $byte8 =  &read16(\@decryptedData, 8); # unknown
#     my $messageBytes = &read16(\@decryptedData, 10);
#     my $messageLength = $size -1;
#     $message = &decodeBytesForStarsString(@decryptedData[11..$messageLength]);
# #    print "From: $senderId, To: $recipientId, \"$message\"\n"; 
#     if ($message) {
#       if ($ext =~ /[xX]/) { 
#         # Different for x files, as we don't have player names in it.
#         # Player ID #s are a bit weird, as 0 in this case is "everyone", not Player 1 (ID:0)
#         if ( $recipientId == 0 ) { $recipientId = 'Everyone'; } else { $recipientId = 'Player ' . $recipientId; }
#         print "\tMessage Year:" . ($turn+2400) . ", From: Me, To: $recipientId, \"$message\"\n";
#       } else { 
#         print "\tMessage Year:" . ($turn+2400) . ", From: $singularRaceName[$senderId+1], To: $singularRaceName[$recipientId], \"$message\"\n"; 
#       }
#       if ($debug) { print "b0: $byte0, b2: $byte2, b8: $byte8\n"; }
#     } 
#   } 
#   #return @decryptedData;
#   return $message;
# }


