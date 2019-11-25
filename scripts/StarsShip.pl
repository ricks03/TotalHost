# StarsShip.pl
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
# Gets Shipe attributes
# Example Usage: StarsShip.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# Doesn't really work completely, too much to do with design slots.

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock;
do 'config.pl';

my $debug = 1;

# Ship parts
my $deleteDesign;
my $designToDelete;
my $isFullDesign;
my $isTransferred;
my $isStarbase;
my $armor;
my $designNumber;
my $hullId;
my $pic;
my $slotCount;
my $slotEnd;
my $mass;
my $slot;
my $itemId;
my $slotId;
my $itemCategory;
my $itemCount;
my $items;
my $turnDesigned; 
my $totalBuilt;
my $totalRemaining;
my $shipNameLength;
my $shipName;

#########################################        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsShip.pl <input file>\n\n";
  print "Please enter the input file (.R|.M|.HST). Example: \n";
  print "  StarsShip.pl c:\\games\\test.r1\n\n";
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
my ($outBytes) = &decryptShip(@fileBytes);
my @outBytes = @{$outBytes};


################################################################
sub decryptShip {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame);
  my ( $random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame) = &getFileHeaderBlock(\@block);
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
      if ($typeId == 26 || $typeId == 27) { # Design & Design Change block
        if ($debug) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }

        if ($typeId == 27) {
          $deleteDesign = $decryptedData[0] % 16;
          if ($deleteDesign == 0) { 
			       print "Design to Delete: true " . $decryptedData[0] % 16 . "\n";
             $designToDelete = $decryptedData[1] % 16;  print "designToDelete: $designToDelete\n";
             $isStarbase = ($decryptedData[1] >> 4) % 2; print "isStarbase: $isStarbase\n";
		      }
        }
        $isFullDesign =  ($decryptedData[0] & 0x04); print "isFullDesign: $isFullDesign\n";
        my $byte1 = $decryptedData[1];
        print "byte1: $byte1 " . &dec2bin($byte1) . "\n";
#        my $canColonize = &bitTest($decryptedData[1],2); print "canColonize: $canColonize\n";
        $isTransferred = ($decryptedData[1] & 0x80); print "isTransferred: $isTransferred\n";
        $isStarbase = ($decryptedData[1] & 0x40);  print "isStarbase: $isStarbase\n";
        $designNumber = ($decryptedData[1] & 0x3C) >> 2; print "designNumber: $designNumber\n";
        $hullId = $decryptedData[2] & 0xFF; print "HullId: $hullId " . &showHull($hullId) . "\n";
        $pic = $decryptedData[3] & 0xFF; print "pic: $pic\n";
        $armor = &read16(\@decryptedData, 4);  print "armor: $armor\n";
        $slotCount = $decryptedData[6] & 0xFF; print "slotCount: $slotCount\n";  # Actual number of slots
        $slotEnd = 13+($slotCount*4); print "slotEnd: $slotEnd\n";
        my $canColonize = $decryptedData[$slotEnd+3]; print "!!!!!!!!!!Can colonize:  $canColonize\n";
        $shipNameLength = $decryptedData[$slotEnd+4]; print "shipNameLength: $shipNameLength\n";
        $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd+4..$slotEnd+4+$shipNameLength]);
        print "***************shipName: $shipName\n";
        
        my $index;
        if ($isFullDesign) {
          if ($isStarbase) { $mass = 0; }
          $turnDesigned = &read16(\@decryptedData, 7); print "turnDesigned: " . $turnDesigned . "\n";
          $totalBuilt = &read16(\@decryptedData, 9); print "totalBuilt: $totalBuilt\n";
          $totalRemaining = &read16(\@decryptedData, 13); print "totalRemaining: $totalRemaining\n";
          print "Ship slots: $slotCount\n";
          my $counter =0;
          for (my $i = 15; $i < $slotEnd-1; $i+=4) {
             # BUG: category (2 bytes), ItemId (1 byte), count (1 byte)? ? ?  Doesn't line up
            $itemId = $decryptedData[$i]; #print "$i: ItemId: $itemId \n";
            $itemCount =  $decryptedData[$i+1]; #print "$i: itemCount: $itemCount \n";
            $slotId = $decryptedData[$i+2]; #print "$i: slotId: $slotId \n";
            $itemCategory = $decryptedData[$i+3]; #print "$i: itemCategory: $itemCategory \n";  # Whether in the first or second set of 8
            my $colonize = &read16($decryptedData[$i]); #print "$i: itemCategory: $itemCategory \n";  # Whether in the first or second set of 8
            print "Slot $counter ($i): SlotId: $slotId\tCategory: $itemCategory\tItemId: $itemId\tCount: $itemCount, colonize: $colonize\n";
            $counter++;
          }
          if ($slotCount > 0) {
          }
          
        } else {
         $index = 6;
        }
        
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes;
}

sub showHull {
  my ($hull) = @_;
  if ($hull == 0) { return "Small Freighter"; }
  elsif ($hull == 1) { return "Medium Freighter"; }
  elsif ($hull == 2) { return "Large Freighter"; }
  elsif ($hull == 3) { return "Super Freighter"; }
  elsif ($hull == 4) { return "Scout"; }
  elsif ($hull == 7) { return "Colonizer"; }
  elsif ($hull == 8) { return "Battle Cruiser"; }
  elsif ($hull == 9) { return "Battleship"; }
  elsif ($hull == 10) { return "Dreadnaught"; }
  elsif ($hull == 11) { return "Privateer"; }
  elsif ($hull == 12) { return "Rogue"; }
  elsif ($hull == 13) { return "Galleon"; }
  elsif ($hull == 14) { return "Mini-Colony Ship"; }
  elsif ($hull == 15) { return "Colony Ship"; }
  elsif ($hull == 18) { return "Stealth Bomber"; }
  elsif ($hull == 25) { return "Fuel Transport"; }
  elsif ($hull == 27) { return "Mini Mine Layer"; }
  elsif ($hull == 28) { return "Super Mine Layer"; }
  elsif ($hull == 31) { return "Meta Morph"; }
  elsif ($hull == 32) { return "Orbital Fort"; }
  elsif ($hull == 33) { return "Space Dock"; }
  elsif ($hull == 34) { return "Space Station"; }
  elsif ($hull == 36) { return "Death Star"; }
  else { return $hull; }
}

sub showItemCategory {
  my ($item) = @_;

}

sub showItem {
  my ($itemId) = @_;
  # 4 long hump 6
  if ($itemId == 0) { return "?"; }
  elsif ($itemId == 1) { return "warp 5"; }
  elsif ($itemId == 3) { return "warp 6"; }
  elsif ($itemId == 4) { return "warp 7"; }
  elsif ($itemId == 5) { return "warp 8"; }
  elsif ($itemId == 6) { return "warp 9"; }
  elsif ($itemId == 7) { return "warp 10"; }
  elsif ($itemId == 9) { return "warp 11"; }
  elsif ($itemId == 1) { return "warp 5"; }

}

# Scout: slot 1: Engine, slot 2 Scanner
sub showPic {
 # scout = 0;
 
}


sub techCategory {
#              Armor = 8,
#             BeamWeapon = 0x10,
#             Bomb = 0x40,
#             Electrical = 0x800,
#             Empty = 0,
#             Engine = 1,
#             Mechanical = 0x1000,
#             MineLayer = 0x100,
#             MiningRobot = 0x80,
#             Orbital = 0x200,
#             Planetary = 0x400,
#             Scanners = 2,
#             Shields = 4,
#             Torpedo = 0x20
#   Empty=0
#   Engine=1
#   Scanners=2
#   Shields=4
#   Armor=8
#   BeamWeapon=16
#   Torpedo=32
#   Bomb=64
#   MiningRobot=128
#   MineLayer=256
#   Orbital=512
#   Planetary=1024 - Assumed since it appears to be the only missing one
#   Electrical=2048
#   Mechanical=4096



}