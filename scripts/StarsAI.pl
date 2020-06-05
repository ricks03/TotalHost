# StarsAI.pl
# Toggles a player from Human <> Human (Inactive) 
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 200604  Version 1.0
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
# Example Usage: StarsAI.pl c:\stars\game.m1
#
# Toggles a player from Human <> Human (Inactive) 
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
        
my $filename = $ARGV[0]; # input file
my $playerAI = $ARGV[1];
my $outFileName = $ARGV[2];
if (!($filename)) { 
  print "\n\nUsage: StarsAI.pl <input file> <PlayerID 1-16> <output file (optional)>\n\n";
  print "Please enter the input file (.HST). Example: \n";
  print "  StarsPWD.pl c:\\games\\test.HST <PlayerID 1-16>\n\n";
  print "Changes the player to Inactive\n";
  print "By default, a new file will be created: <filename>.clean\n\n";
  print "You can create a different file with StarsPWD.pl <filename> <newfilename>\n";
  print "  StarsPWD.pl <filename> <filename> will overwrite the original file.\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
if (-d $ARGV[0]) { print "$filename is a directory!\n"; exit; }
unless (-e $ARGV[0]) { print "File $filename does not exist!\n"; exit; }
if ( $ARGV[1] ) {
  if ($ARGV[1] > 16 || $ARGV[1] < 1) { die "Player ID must be between 1 and 16\n"; }
} else { die "Player ID must be between 1 and 16\n"; }
$playerAI--; #for simplicity, set it to the non-human value

my ($basefile, $dir, $ext);
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

unless (uc($ext) eq '.HST') { print "Needs to run on HST files\n"; exit; }

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
my ($outBytes) = &decryptAI(@fileBytes);
if ($outBytes) {
  my @outBytes = @{$outBytes};
  
  # Create the output file name
  my $newFile; 
  if ($outFileName) {   $newFile = $outFileName;  } 
  else { $newFile = $dir . '\\' . $basefile . '.clean'; }
  if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me
  
  # Output the Stars! File with blank password(s)
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "File output: $newFile\n";
  unless ($ARGV[2]) { print "Don't forget to rename $newFile\n"; }
} else { print "Nothing to do\n"; }

################################################################
sub decryptAI {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  my $flip = 0; # Was the player flipped
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
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
      if ($debug) { print "\nDATA DECRYPTED:\n" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        my $playerId = $decryptedData[0] & 0xFF; 
        if ($playerId == $playerAI) {
          $flip = 1;
          # Flip from  Human <> AI
          if ($decryptedData[7] == 1 || $decryptedData[7] == 225) { # currently Human
            $decryptedData[7] = 227;
            print "Flipping Player $ARGV[1] to AI...\n";
          } elsif ($decryptedData[7] == 227) { # currently AI
            $decryptedData[7] = 225;
            print "Flipping Player $ARGV[1] to Human...\n";
          } elsif ($decryptedData[7] == 39) { # changing an AI to human
            $decryptedData[7]  = 225;
            # Set the AI password to blank inverted, so that it flips correctly for human
            # BUG: I don't think this is working, they become human with a password
            $decryptedData[12] = 255;
            $decryptedData[13] = 255;
            $decryptedData[14] = 255;
            $decryptedData[15] = 255;  
            print "Flipping Player $ARGV[1] from AI to Human...\n";
          }
          # The bits for the password of an inactive player are the inverse of the 
          # bits of the password for an active player 
          # Flip the bits of the password
          $decryptedData[12] = &read8(~$decryptedData[12]);
          $decryptedData[13] = &read8(~$decryptedData[13]);
          $decryptedData[14] = &read8(~$decryptedData[14]);
          $decryptedData[15] = &read8(~$decryptedData[15]);
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
  if ( $flip ) { return \@outBytes; }
  else { return 0; }
}

