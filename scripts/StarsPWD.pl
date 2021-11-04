# StarsPWD.pl
# Strips the passwords off of Stars! files
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 180815  Version 1.0
# 210515  Version 2.0
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
# Example Usage: StarsPWD.pl c:\stars\game.m1
#
# Removes the password from a .M file
# Removes the password from a .HST file
# Removes the password from a .X file
# Removes the password from a .R file
# Removes the passwords for all players from a .HST file
#   Player passwords in a HST file will be reset, but multi-turn .M files will
#   still require a password because the password is still set in the 
#   .M file. On their next save the password will be removed even without
#   a submission of a PWD change. 
#   In this case reset the password(s) on the .M file as well. 
#
# TBD: add ability to create .x file with password reset
# 210515: Remove password from .r file
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

# Block 0 (File footer Block) normally includes a checksum of two bytes
# 
# .r file
# The first XOR of the even bytes of Block 6, 
#   the second the XOR of the odd bytes of Block 6: 
# for (my $i = 0; $i < scalar @decryptedData; $i=$i+2) {
#   $checkSum1 = $checkSum1^$decryptedData[$i];
# }
# for (my $i = 1; $i < scalar @decryptedData; $i=$i+2) {
#   $checkSum2 = $checkSum2^$decryptedData[$i];
# }
# 
# .X file
# The checksum is blank (no values) even though the block exists
# 
# .M file
# The checksum is the turn # (Turn - 2400), not starting a count at 0.
# 
# .HST file
# The checksum is the same as the .M file (the turn # - 2400).

use strict;
use warnings;   
use warnings::unused;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;
        
my $filename = $ARGV[0]; # input file
my $outFileName = $ARGV[1];
if (!($filename)) { 
  print "\n\nUsage: StarsPWD.pl <input file> <output file (optional)>\n\n";
  print "Please enter the input file (.M, .R, .X, .HST). Example: \n";
  print "  StarsPWD.pl c:\\games\\test.m6\n\n";
  print "If the password is removed from a .M file, the password must be\n";
  print "  set when the turn is next submitted or the password will revert.\n\n";
  print "Removes all player passwords from a .HST file. For multi-turn .M files\n";
  print "  you must also reset the password on the .M file.\n\n"; 
  print "Removes any administrative password on the .HST file.\n\n";
  print "Removes the race password on the .R file.\n\n";
  print "Sets a password in a .X file that would change the password to blank.\n\n";
  print "By default, a new file will be created: <filename>.blank\n\n";
  print "You can create a different file with StarsPWD.pl <filename> <newfilename>\n";
  print "  StarsPWD.pl <filename> <filename> will overwrite the original file.\n\n";
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

# There are no passwords in these files
if (uc($ext) eq '.XY') { print "There are no passwords in .XY files!\n"; exit; }
if (uc($ext) =~ /\.H\d/ ) { print "There are no passwords in .H files!\n"; exit; }

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
my ($outBytes) = &decryptPWD2(@fileBytes);
if ($outBytes) {
  my @outBytes = @{$outBytes};
  
  # Create the output file name
  my $newFile; 
  if ($outFileName) {   $newFile = $outFileName;  } 
  else { $newFile = $dir . '\\' . $basefile . '.blank'; }
  if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me
  
  # Output the Stars! File with blank password(s)
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "File output: $newFile\n";
  unless ($ARGV[1] && $ARGV[1] eq $ARGV[0]) { print "\nDon't forget to rename\n$newFile\n to\n$filename\n"; }
  if (uc($ext) eq '.HST' ) { print "\n*****Reset password(s) on the .M file(s) as well before generating the turn\n"; }
} else { print "No passwords found\n"; }

################################################################
sub decryptPWD2 {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti );
  my ( $seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $pwdreset = 0;  # has the password been reset
  my $playerId;
  my @singularRaceName;
  my @pluralRaceName;
  my ($checkSum1, $checkSum2); # The checksums for .r file Block 0
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }

    if ($typeId == 8) {  # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      if ($debug) { print "DECRYPTED:" . join (" ", @unshiftedData), "\n"; } 

      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      # shift the data from binary
      my ($unshiftedData) = &unshiftBytes(\@data); 
      my @unshiftedData = @{ $unshiftedData };
      if ($debug) { print "DECRYPTED:" . join (" ", @unshiftedData), "\n"; } 
      #if (uc($ext) =~ /R/) { print "Race CheckSum (original):" . join (" ", @unshiftedData), "\n"; } 
      if ( $pwdreset                                             # If the password has been reset, fix the checksum
           && $size                                              # .x files don't have any data in block 0
           && $unshiftedData[0] > 0 && $unshiftedData[1] > 0     # race files have values set for the checksum
           && uc($ext) =~ /R/                                    # And it's an R file
          ) 
      {
        # change the checksum values
        $unshiftedData[0] = $checkSum1;
        $unshiftedData[1] = $checkSum2;
        #print "Race Checksum (Calculated): $checkSum1 $checkSum2\n";
        #shift the data back to binary
        my $shiftedData = &shiftBytes(\@unshiftedData);
        my @shiftedData = @{ $shiftedData };
        my @header = ($block[0], $block[1]); # Get the original header for the block
        unshift (@shiftedData, @header); # Prefix the shifted data with the header
        push @outBytes, @shiftedData;
      } else {
        push @outBytes, @block;
      }
    } elsif ($typeId == 7) { # Planet block (.xy file)
      # Note that planet's data requires something extra to decrypt. 
      print "BLOCK 7 found. ERROR! .XY file!\n"; die;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        # We need the race name info for calculating the race checksum if we reset a race password
        $playerId = $decryptedData[0] & 0xFF; 
        my $fullDataFlag = ($decryptedData[6] & 0x04); 
        my $index = 8; 
        if ($fullDataFlag) { 
          $index = 112;
          my $playerRelationsLength = $decryptedData[112]; 
          $index = $index + $playerRelationsLength + 1;
        }  
        my $singularNameLength = $decryptedData[$index] & 0xFF;
        my $singularMessageEnd = $index + $singularNameLength;
        my $pluralNameLength = $decryptedData[$index+$singularNameLength+1] & 0xFF;
        if ($pluralNameLength == 0) { $pluralNameLength = 1; } # Because there's a 0 byte after it
        $singularRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
        $pluralRaceName[$playerId] = &decodeBytesForStarsString(@decryptedData[$singularMessageEnd+1..$size-1]);

        # There are player blocks from other players in the .M file. 
        #   If you reset the password in those you can corrupt at the very least the player race name 
        # The playerId of race (.R) files is 255
        if ((($decryptedData[12]  != 0) | ($decryptedData[13] != 0) | ($decryptedData[14] != 0) | ($decryptedData[15] != 0)) && (($playerId == $Player) | (uc($ext) eq '.HST') | ($playerId == 255))) {
          # Replace the password with blank
          $decryptedData[12] = 0;
          $decryptedData[13] = 0;
          $decryptedData[14] = 0;
          $decryptedData[15] = 0;  
          $pwdreset = 1;
          print "Block $typeId password reset!\n";
                                              
          if (uc($ext) =~ /R/ && $pwdreset) { # recalculate the checksum for race files   
            ($checkSum1, $checkSum2) = &raceCheckSum(\@decryptedData, $singularRaceName[$playerId], $pluralRaceName[$playerId], $singularNameLength, $pluralNameLength);
          }
        } else { 
          # In .HST some Player blocks could be password protected, and some not 
          unless (uc($ext) eq '.HST' ) { print "Block $typeId isn't password-protected!\n"; }
        }
      }
      if ($typeId == 36) { # .x file Change Password Block
        if (($decryptedData[0]  != 0) | ($decryptedData[1] != 0) | ($decryptedData[2] != 0) | ($decryptedData[3] != 0)) {
          # Replace the password with blank
          $decryptedData[0] = 0;
          $decryptedData[1] = 0;
          $decryptedData[2] = 0;
          $decryptedData[3] = 0; 
          $pwdreset = 1;
          print "Block $typeId password reset!\n";
        }
      } 
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      if ($debug) { print "\nBLOCK ENCRYPTED: \n" . join ("", @encryptedBlock), "\n\n"; }
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  # If the password was not reset, no need to write the file back out
  # Faster, less risk of corruption   
  if ( $pwdreset ) { return \@outBytes; }
  else { return 0; }
}