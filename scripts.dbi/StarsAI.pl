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
# The password to view AI turn files is "viewai"
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my $filename = $ARGV[0]; # input file
my $playerAI = $ARGV[1];
my $newAI = $ARGV[2];
my $outFileName = $ARGV[3];
my @aiStatus = qw(Human Inactive CA PP HE IS SS AR);
my @prts = qw (HE SS WM CA IS SD PP IT AR JOAT );

if (!($filename)) { 
  print "\n\nUsage: StarsAI.pl <Game HST file> <Player 1-16> <new AI status> <output file (optional)>\n\n";
  print "Please enter the input file (.hst). Example: \n";
  print "  StarsAI.pl c:\\games\\test.hst 1 Inactive\n";
  print "Changes the player to Inactive\n\n";
  print "Possible Player Status options: " . join(',',@aiStatus) . "\n\n";
  print "By default, a new file will be created: <filename>.ai\n";
  print "You can create a different file with StarsAI.pl <filename> <PlayerID 1-16> <new AI status> <newfilename>\n";
  print "  StarsAI.pl <filename> <PlayerID 1-16> <new AI status> <filename> will overwrite the original file.\n\n";
  print "\nThe password to view AI turn files is \"viewai\"\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
if (-d $ARGV[0]) { print "$filename is a directory!\n"; exit; }
unless (-e $ARGV[0]) { print "File $filename does not exist!\n"; exit; }
if ( $ARGV[1] ) {
  if ($ARGV[1] > 16 || $ARGV[1] < 1) { die "Player must be between 1 and 16\n"; }
} else { 
  die "Player # must be between 1 and 16\n"; 
}
# Simpler to use 1-16 above because a null is a 0;
$playerAI--;
unless ($ARGV[2] ~~ @aiStatus) { print "Player status must be:  " . join(",",@aiStatus) . "\n"; exit; }

my ($basefile, $dir, $ext);
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

unless (uc($ext) eq '.hst') { print "Needs to run on .hst files\n"; exit; }

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
#my ($outBytes) = &decryptAI();
if ($outBytes) {
  my @outBytes = @{$outBytes};
  
  # Create the output file name
  my $newFile; 
  if ($outFileName) {   $newFile = $outFileName;  } 
  else { $newFile = $dir . '\\' . $basefile . '.ai'; }
  
  # Output the Stars! File with blank password(s)
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "File output: $newFile\n";
  unless ($ARGV[3]) { print "Don't forget to rename $newFile\n"; }
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
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti );
  my ( $random, $seedA, $seedB, $seedX, $seedY );
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $action = 0; # Was any action taken
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
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
          my $fullDataFlag = ($decryptedData[6] & 0x04);
          if ($fullDataFlag) {
            my $PRT = $decryptedData[76]; # HE SS WM CA IS SD PP IT AR JOAT  
            # In here is also the AI difficulty (lvlEasy, lvlStandard, lvlHard, lvlExpert . . .)
            # $decryptedData[7] In here is also the AI ID for which AI
            print "Current PRT: $prts[$PRT]\n";
          }
          $action =1;
          # Have to handle the password change differently for human <> inactive
          if ($newAI eq 'Human' ) {
            if  ($decryptedData[7] == 225  || $decryptedData[7] == 1) { 
              print "Already Human\n";
            } elsif ($decryptedData[7] == 227 ) {
              print "Changing from Human(Inactive) AI to Human\n";
              $decryptedData[7] = 225;
              # The bits for the password of an inactive player are the inverse of the 
              # bits of the password for an active player 
              # Flip the bits of the password
              $decryptedData[12] = &read8(~$decryptedData[12]);
              $decryptedData[13] = &read8(~$decryptedData[13]);
              $decryptedData[14] = &read8(~$decryptedData[14]);
              $decryptedData[15] = &read8(~$decryptedData[15]);
            } else {
              print "Changing from AI to Human\n";
              $decryptedData[7] = 225;
              # Reset the AI password to blank for human use
              $decryptedData[12] = 0;
              $decryptedData[13] = 0;
              $decryptedData[14] = 0;
              $decryptedData[15] = 0;
            }
          } elsif ($newAI eq 'Inactive' ) {
            if ($decryptedData[7] == 227 ) {
              print "Already Inactive AI\n";
            } elsif ($decryptedData[7] == 225  || $decryptedData[7] == 1) { 
              print "Changing from Human to Human(Inactive) AI\n";
              $decryptedData[7] = 225;
              # The bits for the password of an inactive player are the inverse of the 
              # bits of the password for an active player 
              # Flip the bits of the password
              $decryptedData[12] = &read8(~$decryptedData[12]);
              $decryptedData[13] = &read8(~$decryptedData[13]);
              $decryptedData[14] = &read8(~$decryptedData[14]);
              $decryptedData[15] = &read8(~$decryptedData[15]);
            } else {
              print "Changing from Full AI to Human(Inactive) AI\n";
              $decryptedData[7] = 227;
              # The inverse of a blank password
              $decryptedData[12] = 255;
              $decryptedData[13] = 255;
              $decryptedData[14] = 255;
              $decryptedData[15] = 255;
            }
          } else { 
            # Setting to one of the AIs
            # Set the standard AI password              
            $decryptedData[12] = 238;
            $decryptedData[13] = 171;
            $decryptedData[14] = 77;
            $decryptedData[15] = 9;
            print "Changing to $newAI AI\n";
            # Use the Expert values for the AIs
            if ($newAI eq 'CA' )      {  $decryptedData[7] = 111;  print "Does not expect IFE. Expects TT/OBRM/NAS\n"; 
            } elsif ($newAI eq 'PP' ) {  $decryptedData[7] = 143;  print "Expects IFE/TT/OBRM/NAS. The PP AI appears brain dead for non-PP PRTs.\n";
            } elsif ($newAI eq 'HE' ) {  $decryptedData[7] = 15;   print "Expects IFE/OBRM. \n";
            } elsif ($newAI eq 'IS' ) {  $decryptedData[7] = 79;   print "Does not expect IFE. Expects OBRM/NAS\n";
            } elsif ($newAI eq 'SS' ) {  $decryptedData[7] = 47;   print "Expects IFE/ARM. \n";
            } elsif ($newAI eq 'AR' ) {  $decryptedData[7] = 175;  print "Expects IFE/TT/ARM/ISB. \n";
            } 
          } # End of $newAI
        } # End of PlayerId 
      } # End of typeID 6
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
  if ($action) { return \@outBytes; }
  else { print "File unchanged\n"; return 0; }
}

