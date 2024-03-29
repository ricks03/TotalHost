# StarsPlan.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 200505
#
#     Copyright (C) 2020 Rick Steeves
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
# Display Battle Plans
# Example Usage: StarsPlan.pl c:\stars\game.m1
#
# Gets the values for Battle Plans
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#
# This is integrated into TotalHost StarsBlock. Don't get them out of sync.

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0;

my $fixFiles = 1;
my $needsFixing =0;
my @singularRaceName;
my @pluralRaceName;
my %warning;

my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsPlan.pl <input file>\n\n";
  print "Please enter the input file (.R|.M|.HST). Example: \n";
  print "  StarsPlan.pl c:\\games\\test.r1\n\n";
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
my ($outBytes) = &decryptBlockPlan(@fileBytes);
#my ($outBytes) = &decryptBlockPlan();
#my @outBytes = @{$outBytes};


################################################################
sub decryptBlockPlan {
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
  my $warnId;
  my @target = qw(None Any Starbase Armed Bombers Unarmed Fuel Freighters);
  my @tactic = qw(Disengage ifChallenged minToSelf maxNet maxRatio Max);
  my @attackWho = qw(Nobody Enemies Neutral/Enemies Everyone 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16);
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    if ($typeId == 8) { # FileHeaderBlock, never encrypted
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      #push @outBytes, @block;
      print 'Turn: ',$turn+2400,"\n";
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      #push @outBytes, @block;
     } elsif ($typeId == 7) { # Planet block (.xy file)
      # Note that planet's data requires something extra to decrypt. 
      die "BLOCK 7 found. ERROR!\n";
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
       if ($typeId == 30) {  # BattlePlan block
        my $err = '';
        if ($debug) { print "BLOCK:$typeId,Offset:$offset,Bytes:$size\t"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }

        my ($planPlayerId, $planNumber, $primaryTarget,$secondaryTarget,$tactic,$attackWho, $dumpCargo, $planNameLength, $planName);

        # Player 0 Default: 0 4 19 2 5 179 45 113 222 90
        # Player 1 Default: 1 4 19 2 5 179 45 113 222 90
        $planPlayerId = ($decryptedData[0] >> 0) & 0x0F; 
        print "\tPlan Player ID:$planPlayerId\t";  # 4 bits starting at bit 0.
        $planNumber = ($decryptedData[0] >> 4) & 0x0F; 
        print "Plan:$planNumber\t";
        $tactic = ($decryptedData[1]) & 0x0F; 
        print "Tactic:" . $tactic[$tactic] . "($tactic)\t";
        $dumpCargo = ($decryptedData[1] >> 7) & 0x01; 
        print "Dump:$dumpCargo\t"; # 1 bit  starting at bit 7.
        $primaryTarget = ($decryptedData[2] >> 0) & 0x0F; 
        print "Pri:" . $target[$primaryTarget] . "($primaryTarget)\t"; 
        $secondaryTarget = ($decryptedData[2] >> 4) & 0x0F; 
        print "Sec:" . $target[$secondaryTarget] . "($secondaryTarget)\t"; 
        $attackWho = $decryptedData[3]; 
        print "Attack:". $attackWho[$attackWho] . "($attackWho)\t";
        $planNameLength = $decryptedData[4]; 
        #print "planNameLength: $planNameLength  (using nibbles as characters, not bytes)\n";
        $planName = &decodeBytesForStarsString(@decryptedData[4..4+$planNameLength]);  print "Name: $planName\t";
        print "\n";
        #print "$planPlayerId,$primaryTarget,$secondaryTarget,$tactic,$attackWho,$dumpCargo\n";
        # Detect the BattlePlan Friendly Fire bug
        $warnId = &zerofy($planPlayerId) . '-plan-' . &zerofy($planNumber);
        if (($attackWho) > 3 && $planNumber == 0) { 
           # Fixing display for those who don't count from 0.
           $err .= '***Friendly Fire bug detected for Player ' . $planPlayerId .  " in Default battle plan slot ($planNumber) against " . &attackWho($attackWho);
           $decryptedData[3] = 2;
           $needsFixing = 1;
           if ($fixFiles > 1) {
             $err .= '  Fixed!!! Attack Who reset to Neutral/Enemy.';
           } else {$err .= '';}
           print $err . "\n"; 
           $warning{$warnId.'-friendly'} = $err;
        }
        # If a subsequent Default battle plan fixes it, clear the warning
        if (!$err && $warning{$warnId.'-friendly'}) { 
          delete( $warning{$warnId.'-friendly'} ); 
          print "Friendly Fire Player Fix Noted for $warnId\n";
        }
      }
      # END OF MAGIC
      # reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      #push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  #return \@outBytes;
}

# sub getMask {
# # Return true if the associated bit is set for the number
#   my ($number, $position) = @_;
#   my $new_num = $number >> ($position ); 
#     # if it results to '1' then bit is set, 
#     # else it results to '0' bit is unset 
#   my $check = $new_num &1;
#   return ($check); 
# } 