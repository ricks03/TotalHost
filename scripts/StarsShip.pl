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
# Gets Ship attributes
# Example Usage: StarsShip.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# Doesn't really work completely, too much to do with design slots.
# But detects the colonizer, spacedock, and 10 starbase issues

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
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
my $itemCategory1;
my $itemCategory0;
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
  print "  StarsShip.pl c:\\games\\test.m1\n\n";
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

# Not actually do anything here to change the file

################################################################
sub decryptShip {
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
    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
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
      # Detect the Colonizer, Spack Dock SuperLatanuim, and 10 starbase design bugs
      if ($typeId == 26 || $typeId == 27) { # Design & Design Change block
        if ( $debug  ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        if ( $debug  ) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        my $index = 0;
        if ( $typeId == 27 ) { 
          $index = 2; # there are two extra bytes in a .x file
          $deleteDesign = $decryptedData[0] % 16;
          if ($deleteDesign == 0) { 
            print "Design to Delete: true " . $decryptedData[0] % 16 . "\n";
            $designToDelete = $decryptedData[1] % 16;  print "designToDelete: $designToDelete\n";
            $isStarbase = ($decryptedData[1] >> 4) % 2; print "isStarbase: $isStarbase\n";
          }
        }
        $isFullDesign =  ($decryptedData[$index] & 0x04); print "isFullDesign: $isFullDesign\n";
        my $byte1 = $decryptedData[$index+1];
        $isTransferred = ($decryptedData[$index+1] & 0x80); print "isTransferred: $isTransferred\n";
        $isStarbase = ($decryptedData[$index+1] & 0x40);  print "isStarbase: $isStarbase\n";
        $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; print "designNumber: $designNumber\n";
        $hullId = $decryptedData[$index+2] & 0xFF; print "HullId: $hullId " . &showHull($hullId) . "\n";
        $pic = $decryptedData[$index+3] & 0xFF; print "pic: $pic\n";
        if ($isFullDesign) {
          $armor = &read16(\@decryptedData, $index+4);  print "armor: $armor\n";
          $slotCount = $decryptedData[$index+6] & 0xFF; print "slotCount: $slotCount\n";  # Actual number of slots
          $slotEnd = $index+17+($slotCount*4); print "slotEnd: $slotEnd\n";
          $shipNameLength = $decryptedData[$slotEnd];          
          $turnDesigned = &read16(\@decryptedData, $index+7); print "turnDesigned: " . $turnDesigned . "\n";
          $totalBuilt = &read16(\@decryptedData, $index+9); print "totalBuilt: $totalBuilt\n";
          $totalRemaining = &read16(\@decryptedData, $index+13); print "totalRemaining: $totalRemaining\n";
          print "Ship slots: $slotCount\n";
          my $counter =0;
          print "Index: $index, slotEnd: $slotEnd\n";
          for (my $i = $index+19; $i < $slotEnd-1; $i+=4) {
            $itemId = $decryptedData[$i]; #print "$i: ItemId: $itemId \n";
            $itemCount =  $decryptedData[$i+1]; #print "$i: itemCount: $itemCount \n";
            # BUG: I really wish I'd figured out a better way to get this.
            $itemCategory0 = $decryptedData[$i+2]; #print "$i: slotId: $slotId \n";
            $itemCategory1 = $decryptedData[$i+3]; #print "$i: itemCategory: $itemCategory \n";  # Whether in the first or second set of 8
            if ($debug) { print "Slot $counter ($i): Cat0: $itemCategory0\tCat1: $itemCategory1\tItemId: $itemId\tCount: $itemCount\n"; }
            #############################################################3
            # Detect (and potentially fix) ship design issues
            # Fix the colonizer bug
            # If a ship is created, and then edited, it's going to put 2 entries in the .x file.
            # Both of which I think are correct. They only get screwed up from the .exe? 
            if ($itemCategory0 == 0 &&  $itemCategory1 == 16 &&  $itemId == 0 && $itemCount == 0) {
              print "***Colonizer bug\n";
              $decryptedData[$i+3] = 0; # fixing bug by setting the slot to empty
            }
            # Detect Space Dock Armor slot Buffer Overflow
            if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory0 == 8 && $itemCount >=22  && $armor  >= 49518) {
              #BUG: Should fix Spacedock. But How? 
              # Currently fixed by changing it back to 21. The Armor value will still be wrong. 
              print "***Spacedock Bug!\n";
              $decryptedData[$i+1] = 21;
            }
            # Detect the 10th starbase design
            if ($isStarbase &&  $designNumber == 9) {
              print "***10 Starbases - Potential Crash if Player #1 has fleet #1 in orbit of a starbase and refuels when the Last (?) Player has a 10th starbase design\n";
            }
            $counter++;
          }
        } else { $slotEnd = 6; $shipNameLength = $decryptedData[$slotEnd]; }
        print "shipNameLength: $shipNameLength  (this is in bytes, not necessarily characters, as we're using nibbles)\n";
        $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
        print "shipName: $shipName\n";
         
        print "\n";
      }
      # Part of the detection of the minefield 0-coordinate bug, but 
      # the fleet block isn't mapped well-enough for me to figure out the coordinates
      # easily
      if ($typeId == 4 || $typeId == 5) { # waypoint block (add/change) in .x files
        if ($debug ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        # Detect ships moving pure east/west or pure north/south
        # BUG: Doesn't work yet. Will need starting coordinates of fleet.
        my $fleetId = $decryptedData[0]; 
        my $ownerId = $decryptedData[1]; 
        my $positionObjectId = &read16(\@decryptedData, 2);
			  my $xDest = &read16(\@decryptedData, 4);  # CORRECT!!!
        my $yDest = &read16(\@decryptedData, 6);  # CORRECT!!!
        my $test = &read16(\@decryptedData, 8);  
        my $unknownBitsWithWarp = $decryptedData[6] & 0x0F;
        my $positionObjectType = $decryptedData[7] & 0xFF;
        my $fullWaypointData;
        my $warp =  $decryptedData[10] >> 4; # CORRECT!!!
        print "fleetId: $fleetId, ownerId: $ownerId, test: $test, xdest: $xDest, yDest: $yDest, positionId: $positionObjectId, unk = $unknownBitsWithWarp, PositionType: $positionObjectType, warp: $warp\n";
      }
      # BUG: I need the fleet IDs to be able to determine the Mine Bug, as the Fleet info includes
      # current coordinates. But the block isn't mapped well enough for me to determine it. 
#       if ($typeId == 26 || $typeId == 27) { # Design & Design Change block
#         if ($debug  ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
#         if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
#         
#         # BUG: Missing many of the variables
#         my $fleetId = $decryptedData[0]; # Correct
#         my $ownerId = $decryptedData[1]; # Correct
#         my $fleetIronium =  $decryptedData[2];
#         my $fleetBoranium =  $decryptedData[3];
#         my $fleetGermanium =  $decryptedData[4];
#         my $fleetPopulation =  $decryptedData[5];
#         my $fleetFuel =  $decryptedData[6];
#         my $fleetBattlePlan =  $decryptedData[7];
#       }  
#       if ($typeId == 16 || $typeId == 17) { # Fleet block and partial fleet block
#         $fleetNumber = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
#         $owner = $decryptedData[1] >> 1;
#         my $kindByte = $decryptedData[4];
#         $byte5 = $decryptedData[5];
#         my $shipCountTwoBytes;
#         if (($byte5 & 8) == 0) { $shipCountTwoBytes = 1; 
#         } else  {$shipCountTwoBytes = 0; }
#         $positionObjectId = &read16(\@decryptedData, 6);
#         $x = &read16(\@decryptedData, 8);
#         $y = &read16(\@decryptedData, 10);
#         $shipTypes = &read16(\@decryptedData, 12);
#         $index = 14;
#         $mask = 1;
#         for (my $bit = 0; $bit < 16; $bit++) {
#           if (($shipTypes & $mask) != 0) {
#             if ($shipCountTwoBytes) {
#               $shipCount[$bit] = &read16(\@decryptedData, $index);
#               $index += 2;
#             } else {
#               $shipCount[$bit] = &read8($decryptedData[$index]);
#               $index += 1;
#             }
#           }
#         }
#         $mask <<= 1;
#         # PARTIAL_KIND = 3, PICK_POCKET_KIND = 4, FULL_KIND = 7;
#         #if ($kindByte != 7 && $kindByte != 4 && $kindByte != 3) {
#         if ($kindByte == 7 || $kindByte == 4) {
#           $contentsLengths = &read16(\@decryptedData, $index);
#           $iLength = $contentsLengths & 0x03;
#           $iLength = 4 >> (3 - $iLength);
#           $bLength = ($contentsLengths & 0x0C) >> 2;
#           $bLength = 4 >> (3 - $bLength);
#           $gLength = ($contentsLengths & 0x30) >> 4;
#           $gLength = 4 >> (3 - $gLength);
#           $popLength = ($contentsLengths & 0xC0) >> 6;
#           $popLength = 4 >> (3 - $popLength);
#           $fuelLength = $contentsLengths >> 8;
#           $fuelLength = 4 >> (3 - $fuelLength);
#           $index += 2;
#           $ironium = &readN(\@decryptedData, $index, $iLength);
#           $index += $iLength;
#           $boranium = &readN(\@decryptedData, $index, $bLength);
#           $index += $bLength;
#           $germanium = &readN(\@decryptedData, $index, $gLength);
#           $index += $gLength;
#           $population = &readN(\@decryptedData, $index, $popLength);
#           $index += $popLength;
#           $fuel = &readN(\@decryptedData, $index, $fuelLength);
#           $index += $fuelLength;
#         } 
#         if ($kindByte == 7) {
#           $damagedShipTypes = &read16(\@decryptedData, $index);
#           $index += 2;
#           $mask = 1;
#           for (my $bit = 0; $bit < 16; $bit++) {
#             if (($damagedShipTypes & $mask) != 0) {
#               $damagedShipInfo[$bit] = \&read16(\@decryptedData, $index);
#               $index += 2;
#             }
#             $mask <<= 1;
#           }
#           $battlePlan = &read8($decryptedData[$index++]);
#           $waypointCount = &read8($decryptedData[$index++]);
#         } else {
#           $deltaX = &read8($decryptedData[$index++]);
#           $deltaY = &read8($decryptedData[$index++]);
#           $warp = $decryptedData[$index] & 15;
#           $unknownBitsWithWarp = $decryptedData[$index] & 0xF0;
#           $index++;
#           $index++;
#           $mass = &read32(\@decryptedData, $index);
#           $index += 4;
#         }
#       }   
#         
#         my $x = &read16(\@decryptedData, 8); # Correct  (likely only in full block?)
#         my $y = &read16(\@decryptedData, 10); # Correct (likely only in full block?)
#         print "fleetId: $fleetId, ownerId: $ownerId, x: $x, y: $y, \n";
#      }
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


sub showHull {
  my ($hull) = @_;
  if ($hull == 0) { return "Small Freighter"; }
  elsif ($hull == 1) { return "Medium Freighter"; }
  elsif ($hull == 2) { return "Large Freighter"; }
  elsif ($hull == 3) { return "Super Freighter"; }
  elsif ($hull == 4) { return "Scout"; }
  elsif ($hull == 5) { return "Frigate"; }
  elsif ($hull == 6) { return "Destroyer"; }
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

}

# Scout: slot 1: Engine, slot 2 Scanner
sub showPic {
 # scout = 0;
 
}

sub Category {
  my ($item) = @_;
  my @item;
#   my $type = qw ( empty engine scanner shield armor beam torp bomb mining layer orbital planetary elec mech ); 
#   $item[0] = qw ( empty ); 
#   $item[1] = qw (SettlerDelight Jump5 Mizer Hump6 Legs7 Alpha8 Trans9 Inter10 Trans10 NHRS Sub Trans TransSuper TransMizer Galaxy );
#   $item[2] = qw (Bat Rhino Mole DNA Possum PickPocket Chameleon Ferret Dolphin Gazelle RNA Cheetah Elephant Eagle Robber Peerless );
#   $item[4] = qw (Mole Cow Wolverine Croby Shadow Bear Gorilla Elephant Complete );
#   $item[8] = qw (Tritanium Crobmium CarbonicArmor Strobnium OrganicArmor Kelarium FieldedKelarium DepletedNeutronium Neutronium Valanium Superlatanium );
#   $item[16] = qw (Laser X-Ray MiniGun YakimoraPhaser Blackjack Phaser PulsedSapper ColloidalPhaser GatlingGun MiniBlaster Bludgeon MarkIVBlaster PhasedSapper HeavyBlaster GatlingNeutrino MyopicDisruptor Blunderbuss Disruptor SyncroSapper MegaDisruptor BigMuthaCannon StreamingPulverizer Anti-MatterPulverizer ); 
#   $item[32] = qw (Alpha Beta Delta Epsilon Rho Upsilon Omega Jihad Juggernaut Doomsday Armageddon );
#   $item[64] = qw (LadyFinger BlackCat M-70 M-80 Cherry LBU-17 LBU-32 LBU-74 Retro Smart Neutron EnrichedNeutron Peerless Annihilator );
#   $item[128] = qw (Midget Mini Miner Maxi Super Ultra Orbital ); 
#   $item[256] = qw (Mine40 Mine50 Mine80 Mine130 Heavy50 Heavy110 Heavy200 Speed20 Speed30 Speed50 );
#   $item[512] = qw (SG250 SG300 SG600 SG500 SGany SG800  SGanyany Mass5 Mass6 Mass7 Mass78 Mass9 Mass10 Mass11 Mass12 Mass13 );
#   $item[1024] = qw (Viewer50 Viewer90 Viewer150 Viewer220 Viewer280 Viewer320 Snooper400 Snooper500 Snooper620 );
#   $item[2048] = qw (TransportCloak StealthCloak Super-StealthCloak Ultra-StealthCloak BattleComputer BattleSuperComputer BattleNexus Jammer10 Jammer20 Jammer30 Jammer50 EnergyCapacitor FluxCapacitor EnergyDampener TachyonDetector Anti-matterGenerator);
#   $item[4096] = qw (Colonization OrbitalCon Cargo SuperCargo Fuel SuperFuel ManeuveringJet Overthruster BeamDeflector ); 
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