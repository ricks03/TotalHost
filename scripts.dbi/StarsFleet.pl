#!/usr/bin/perl
# StarsFleet.pl
# Reads fleet, ship design, and waypoint data from Stars! files.
# Reads Blocks: 6 (Player), 7 (Universe/XY), 16 (Fleet Full/rtFleetA),
#               17 (Fleet Partial+Cargo/rtFleetB), 18 (Fleet Minimal/rtFleetC),
#               19/20 (Waypoints/rtOrderA/rtOrderB), 21 (Fleet Name/rtString),
#               26/27 (Ship Design / Ship Design Change)
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 260408  Version 1.0
#
#     Copyright (C) 2026 Rick Steeves
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

# Gets Fleet, Ship Design, and Waypoint attributes.
# Example Usage: StarsFleet.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;

use File::Basename;
use StarsBlock;

my $debug    = 0;
my $display  = 1;
my $fixFiles = 0;  # 0: display only.  2: write output file.

# Planet name and coordinate tables, populated from the .xy file pass.
my @planet_names  = &planetNames;
my %planet_ID2Name;
my %planet_coords;

my %hullType = &readHullType;

my $filename    = $ARGV[0];
my $outFileName = $ARGV[1];

if (!($filename)) {
  print "\n\nUsage: StarsFleet.pl <input file> [output file]\n\n";
  print "Please enter the input file (.m|.hst|.x|.h). Example:\n";
  print "  StarsFleet.pl c:\\games\\test.m1\n\n";
  print "Reports on:\n";
  print "  Ship designs (block 26/27): hull, name, slots, armor, cargo/fuel capacity\n";
  print "  Fleets (block 16): composition, cargo, damage, battle plan, waypoints\n";
  print "  Enemy fleets (block 17/18): composition, direction, mass, cargo if visible\n";
  print "  Waypoints (block 19/20): destination, warp, task, transport orders\n";
  print "  Fleet names (block 21)\n";
  print "  Planet names and coordinates are read from the .xy file if present.\n";
  print "\nIf an output file is specified and \$fixFiles > 1, the re-encrypted file\n";
  print "will be written to that path.\n";
  print "\nAs always when using any tool, back up your file(s) first.\n";
  exit;
}
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
$basefile = basename($filename);
$dir      = dirname($filename);
$dir =~ s/\\/\//g;
($ext) = $basefile =~ /(\.[^.]+)$/;

if ($ext =~ /[rR]/) { print "Race files do not include fleet information\n"; exit; }

my $FileValues;
my @fileBytes;

# Read the .xy file first to populate planet names and coordinates.
# Only attempt this when processing a non-.xy file.
if ($ext !~ /\.xy$/i) {
  my ($prefix) = fileparse($basefile, qr/\.[^.]*/);
  my $xyfile   = $dir . '/' . $prefix . '.xy';
  print "Looking for $xyfile for planet names and coordinates...\n";
  if (-e $xyfile) {
    print "Found: $xyfile\n";
    my $display_tmp = $display;
    $display = 0;
    open my $XYFile, '<', $xyfile or die "Cannot open $xyfile: $!";
    binmode($XYFile);
    while (read($XYFile, $FileValues, 1)) { push @fileBytes, $FileValues; }
    close($XYFile);
    &decryptBlockFleet(\@fileBytes);
    @fileBytes = ();
    $display = $display_tmp;
    print "\n";
  } else {
    print "Not found. Planet names and coordinates will not be shown.\n\n";
  }
}

# Read the main Stars! file.
open my $StarFile, '<', $filename or die "Cannot open $filename: $!";
binmode($StarFile);
while (read($StarFile, $FileValues, 1)) { push @fileBytes, $FileValues; }
close($StarFile);

# Decrypt the data block by block and display results.
my ($outBytes) = &decryptBlockFleet(\@fileBytes);
my @outBytes = @{$outBytes};

# Write the re-encrypted output file if requested.
if ($fixFiles > 1) {
  my $newFile;
  if ($outFileName) { $newFile = $outFileName; }
  else              { $newFile = $dir . '/' . $basefile . '.fixed'; }
  open my $OutFile, '>:raw', $newFile or die "Cannot open $newFile: $!";
  for (my $i = 0; $i < @outBytes; $i++) {
    print $OutFile $outBytes[$i];
  }
  close($OutFile);
  print "\nFile output: $newFile\n";
  unless ($outFileName) { print "Don't forget to rename $newFile\n\n"; }
}

################################################################
sub decryptBlockFleet {
  my ($fileBytes_ref) = @_;
  my @fileBytes = @{$fileBytes_ref};
  my @block;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt);
  my ($seedA, $seedB, $seedX, $seedY);
  my ($FileValues, $typeId, $size);
  my $offset = 0;

  # State persists across blocks: waypoints and names follow their fleet block.
  my ($fleetId, $ownerId) = (0, 0);
  my $waypointId = 0;

  # Design owner tracking: replicates the counting logic in StarsBlock.pm.
  # block 6 supplies counts per player; block 26 designs appear in that same order.
  my %player;
  my %designList;
  my ($designShipTotal,        $designBaseTotal)        = (0, 0);
  my ($designShipPlayerId,     $designBasePlayerId)      = (0, 0);
  my ($designShipCounter,      $designBaseCounter)       = (0, 0);
  my ($designShipTotalCounter, $designBaseTotalCounter)  = (0, 0);
  my ($designOwner,            $lastPlayer)              = (0, 0);

  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    @block = @fileBytes[$offset .. $offset+(2+$size)-1];
    my @data = @block[2..$#block];

    # ---- Block 8: File Header (never encrypted) ----
    if ($typeId == 8) {
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt)
        = &getFileHeaderBlock(\@block);
      ($seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA;
      $seedY = $seedB;
      if ($display) {
        print "File: $basefile, Player:" . ($Player+1) . ", Year:" . ($turn+2400) . ", dt:$dt\n\n";
      }
      push @outBytes, @block;

    # ---- Block 0: File Footer (not encrypted) ----
    } elsif ($typeId == 0) {
      push @outBytes, @block;

    } else {
      # All other blocks are encrypted.
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB);
      @decryptedData = @{$decryptedData};

      if ($debug) {
        if ($typeId == 6 || ($typeId >= 16 && $typeId <= 21)
            || $typeId == 26 || $typeId == 27) {
          print "BLOCK:$typeId, Offset:$offset, Bytes:$size\n";
          print "DATA: " . join(' ', @decryptedData) . "\n";
        }
      }

      my $extraOffset = 0; # extra advance past raw planet data after block 7

      # ---- Block 7: Universe/XY  ----
      # Block 7 data (62 encrypted bytes) is followed immediately by unencrypted
      # planet coordinate records (4 bytes each), which are not their own block.
      # index 84 = block 8 total (20 bytes) + block 7 total (64 bytes).
      if ($typeId == 7) {
        my $numPlanets = &read16(\@decryptedData, 10);
        my $index      = 84;
        my $end_index  = $index + $numPlanets * 4;
        my $read_x     = 1000;
        my $planetId   = 1;
        for (my $i = $index; $i < $end_index; $i += 4) {
          my $b0     = ord($fileBytes[$i]);
          my $b1     = ord($fileBytes[$i+1]);
          my $b2     = ord($fileBytes[$i+2]);
          my $b3     = ord($fileBytes[$i+3]);
          my $record  = $b0 | ($b1 << 8) | ($b2 << 16) | ($b3 << 24);
          my $name_id = ($record >> 22) & 0x3FF;
          my $x_coord = ($record & 0x3FF) + $read_x;
          $read_x     = $x_coord;
          my $y_coord = ($record >> 10) & 0xFFF;
          # Always store; $display controls printing only.
          $planet_ID2Name{$planetId} = $planet_names[$name_id];
          $planet_coords{$planetId}  = { x => $x_coord, y => $y_coord };
          if ($display) {
            print "Planet:$planetId, Name:$planet_names[$name_id], X:$x_coord, Y:$y_coord\n";
          }
          $planetId++;
        }
        # Planet records are not a separate block; advance offset past them.
        $extraOffset = $numPlanets * 4;

      # ---- Block 6: Player Data ----
      } elsif ($typeId == 6) {
        my $playerId        = $decryptedData[0] & 0xFF;
        my $shipDesigns     = $decryptedData[1] & 0xFF;
        my $planets         = &read16(\@decryptedData, 2);
        my $fleets          = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x0F) << 8);
        my $starbaseDesigns = ($decryptedData[5] & 0xF0) >> 4;
        $player{$playerId}{shipDesigns}     = $shipDesigns;
        $player{$playerId}{planets}         = $planets;
        $player{$playerId}{fleets}          = $fleets;
        $player{$playerId}{starbaseDesigns} = $starbaseDesigns;
        $designShipTotal += $shipDesigns;
        $designBaseTotal += $starbaseDesigns;
        $lastPlayer = $playerId;
        if ($display) {
          print "Player:" . ($playerId+1) . ", ShipDesigns:$shipDesigns"
            . ", StarbaseDesigns:$starbaseDesigns"
            . ", Planets:$planets, Fleets:$fleets\n";
        }

      # ---- Blocks 26/27: Ship Design and Ship Design Change ----
      # Block 26 is in .m/.hst files; block 27 is the .x file design-change block.
      # RTSHDEF layout (struct.h): wFlags[0-1], ihuldef[2], ibmp[3],
      #   dp/wtEmpty[4-5], chs[6], turn[7-8], cBuilt[9-12], cExist[13-16],
      #   rghs[] (4 bytes per slot: grhst[2] + iItem[1] + cItem[1]), then name.
      # Block 27 prefixes 2 bytes of RTCHGSHDEF header, so $index = 2 for that case.
      } elsif ($typeId == 26 || $typeId == 27) {
        my $index;
        my ($isFullDesign, $isTransferred, $isStarbase, $designNumber, $designId);
        my ($hullId, $pic);
        my ($armor, $slotCount, $turnDesigned, $totalBuilt, $totalRemaining) = (0) x 5;
        my ($shipNameLength, $shipName, $slotEnd) = (0, '', 0);
        my ($cargoCapacity, $fuelCapacity, $mass) = (0) x 3;
        my $items = '';

        # Determine design owner.
        # For block 26 (.m/.hst), ownership is inferred from sequential counters
        # that were populated by block 6 (player) data.  Ship designs appear first;
        # starbase designs appear after all fleet blocks.
        # For block 27 (.x), the owner is always the file's player.
        if ($typeId == 26) {
          $designOwner = 0;
          if ($designShipTotalCounter >= $designShipTotal) {
            # Now assigning starbase designs.
            while ($designOwner <= 0
                   && $designBaseTotalCounter < $designBaseTotal
                   && $designBasePlayerId <= $lastPlayer) {
              if (exists($player{$designBasePlayerId}{starbaseDesigns})
                  && $designBaseCounter < $player{$designBasePlayerId}{starbaseDesigns}) {
                $designBaseCounter++;
                $designBaseTotalCounter++;
                $designOwner = $designBasePlayerId;
                last;
              } else {
                $designBasePlayerId++;
                $designBaseCounter = 0;
              }
            }
          } else {
            # Still assigning ship designs.
            while ($designOwner <= 0
                   && $designShipTotalCounter < $designShipTotal
                   && $designShipPlayerId <= $lastPlayer) {
              if (exists($player{$designShipPlayerId}{shipDesigns})
                  && $designShipCounter < $player{$designShipPlayerId}{shipDesigns}) {
                $designShipCounter++;
                $designShipTotalCounter++;
                $designOwner = $designShipPlayerId;
                last;
              } else {
                $designShipPlayerId++;
                $designShipCounter = 0;
              }
            }
          }
          $ownerId = $designOwner;
        } elsif ($typeId == 27) {
          $ownerId = $Player;
        }

        # Block 27 has a 2-byte RTCHGSHDEF prefix before the RTSHDEF data.
        $index = ($typeId == 27) ? 2 : 0;

        # keepDesign == 0 means this is a delete-design record.
        my $keepDesign = $decryptedData[$index] % 16;

        if ($keepDesign == 0) {
          # Delete record: only design slot and starbase flag are present.
          $designNumber = $decryptedData[$index+1] % 16;
          $isStarbase   = ($decryptedData[$index+1] >> 4) & 0x01;
          $designId     = $isStarbase ? $designNumber + 16 : $designNumber;
          if (exists $designList{$ownerId}{$designId}) {
            delete $designList{$ownerId}{$designId};
          }
          if ($display) {
            print "Design DELETE: Player:" . ($ownerId+1)
              . ", Slot:" . ($designNumber+1)
              . ", Starbase:$isStarbase\n\n";
          }

        } else {
          # Active or updated design.
          # isFullDesign: wFlags.det == detAll (7), meaning bits 0-2 are all set.
          $isFullDesign  = (($decryptedData[$index]   & 0x07) == 7) ? 1 : 0;
          $isTransferred = ($decryptedData[$index+1]  & 0x80) ? 1 : 0;  # fGift
          $isStarbase    = ($decryptedData[$index+1]  & 0x40) ? 1 : 0;  # ishdef bit 4
          $designNumber  = ($decryptedData[$index+1]  & 0x3C) >> 2;     # ishdef bits 0-3
          $designId      = $isStarbase ? $designNumber + 16 : $designNumber;
          $hullId        = $decryptedData[$index+2] & 0xFF;              # ihuldef
          $pic           = $decryptedData[$index+3] & 0xFF;              # ibmp
          my $hullName   = (defined $hullType{$hullId} && defined $hullType{$hullId}[2])
                           ? $hullType{$hullId}[2] : "Hull:$hullId";

          if ($isFullDesign) {
            # Full RTSHDEF: dp[4-5], chs[6], turn[7-8], cBuilt[9-12], cExist[13-16], slots, name.
            $armor          = &read16(\@decryptedData, $index+4);
            $slotCount      = $decryptedData[$index+6] & 0xFF;
            $turnDesigned   = &read16(\@decryptedData, $index+7);
            $totalBuilt     = &read32(\@decryptedData, $index+9);
            $totalRemaining = &read32(\@decryptedData, $index+13);
            $slotEnd        = $index + 17 + ($slotCount * 4);
            $shipNameLength = $decryptedData[$slotEnd];
            $shipName       = &decodeBytesForStarsString(
                                @decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            unless ($isStarbase) {
              $cargoCapacity = $hullType{$hullId}[16] // 0;
              $fuelCapacity  = $hullType{$hullId}[17] // 0;
              $mass          = $hullType{$hullId}[10] // 0;
            }

            if ($display) {
              print "Design: Player:" . ($ownerId+1)
                . ", Slot:" . ($designNumber+1) . ($isStarbase ? "(SB)" : "")
                . ", Hull:$hullName($hullId), Name:$shipName"
                . ($isTransferred ? ", Transferred:1" : "") . "\n";
              print "  Armor:$armor, Slots:$slotCount"
                . ", Year:" . ($turnDesigned+2400)
                . ", Built:$totalBuilt, Remaining:$totalRemaining"
                . ", Mass:$mass";
              print ", Cargo:$cargoCapacity, Fuel:$fuelCapacity" unless $isStarbase;
              print "\n";
            }

            # Each slot: grhst (2 bytes) + iItem (1 byte) + cItem (1 byte).
            my $slotIndex = $index + 17;
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              my $itemCategory = &read16(\@decryptedData, $slotIndex);
              $slotIndex += 2;
              my $itemId    = &read8($decryptedData[$slotIndex]);
              $slotIndex++;
              my $itemCount = $decryptedData[$slotIndex];
              $slotIndex++;
              if ($itemCount > 0) {
                $items .= "$itemSlot|$itemCategory|$itemId|$itemCount" . chr(31);
                if ($display) {
                  my ($catName, $itemName) = &showCategory($itemCategory, $itemId);
                  $catName  //= "Cat:$itemCategory";
                  $itemName //= "Item:$itemId";
                  print "  Slot " . ($itemSlot+1) . ": $catName/$itemName x$itemCount\n";
                }
              }
            }
            chop $items if $items; # remove trailing chr(31)

          } else {
            # Partial design (det == detSome = 3): enemy design seen but not owned.
            # cbrtshdefB layout: wFlags[0-1], ihuldef[2], ibmp[3], wtEmpty[4-5], name[6+].
            $mass           = &read16(\@decryptedData, 4);
            $slotEnd        = 6;
            $shipNameLength = $decryptedData[$slotEnd];
            $shipName       = &decodeBytesForStarsString(
                                @decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            if ($display) {
              print "Design: Player:" . ($ownerId+1)
                . ", Slot:" . ($designNumber+1) . ($isStarbase ? "(SB)" : "")
                . ", Hull:$hullName($hullId), Name:$shipName (partial)\n";
              print "  Mass:$mass\n";
            }
          }

          if ($display) { print "\n"; }

          # Store design info for fleet composition display.
          $designList{$ownerId}{$designId} = {
            shipName       => $shipName,
            hullId         => $hullId,
            hullName       => $hullName,
            isFullDesign   => $isFullDesign,
            isStarbase     => $isStarbase,
            designNumber   => $designNumber,
            mass           => $mass,
            armor          => $armor,
            cargoCapacity  => $cargoCapacity,
            fuelCapacity   => $fuelCapacity,
            items          => $items,
            turnDesigned   => $turnDesigned,
            totalBuilt     => $totalBuilt,
            totalRemaining => $totalRemaining,
          };
        }

      # ---- Blocks 16/17/18: Fleet Data ----
      # 16 rtFleetA: det==detAll(7).  Own full fleet, followed by waypoints then optional name.
      # 17 rtFleetB: det>=detMore(4). Partial fleet with cargo + dirLong/mass.
      # 18 rtFleetC: det<detMore.     Partial fleet, no cargo + dirLong/mass.
      # FLEETSOME header (12 bytes): id[0-1], iPlayer[2-3], flags[4-5]
      #   (det:8, fInclude:1, fRepOrders:1, fDead:1, fByteCsh:1, unused:4),
      #   idPlanet[6-7], x[8-9], y[10-11].
      # Then: shipDesignsBitmask[12-13], ship counts (1 or 2 bytes each per fByteCsh).
      # fleetId = ifl (bits 0-8 of id word).  ownerId = iplr (bits 9-12 of id word).
      } elsif ($typeId == 16 || $typeId == 17 || $typeId == 18) {
        my ($kindByte, $byte5);
        my ($fByteCsh, $fDead, $fRepOrders, $fInclude);
        my $positionObjectId;
        my ($x, $y);
        my $shipDesignsBitmask;
        my @shipCount;
        my $index;
        my ($ironium, $boranium, $germanium, $population, $fuel) = (0) x 5;
        my $damagedShipDesigns = 0;
        my @damagedShipInfo = (0) x 16;
        my ($battlePlan, $waypointCount) = (0, 0);
        my ($deltaX, $deltaY, $warp) = (0) x 3;
        my $mass = 0;

        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $ownerId = ($decryptedData[1] >> 1) & 0x0F;
        $kindByte = $decryptedData[4];         # det level: detSome(3), detMore(4), detAll(7)
        $byte5    = $decryptedData[5];         # high byte of flags WORD
        $fByteCsh   = ($byte5 >> 3) & 0x01;   # 1=1-byte ship counts, 0=2-byte ship counts
        $fDead      = ($byte5 >> 2) & 0x01;
        $fRepOrders = ($byte5 >> 1) & 0x01;
        $fInclude   = $byte5 & 0x01;
        $positionObjectId = &read16(\@decryptedData, 6); # idPlanet; 65535 = deep space
        $x = &read16(\@decryptedData, 8);
        $y = &read16(\@decryptedData, 10);
        $shipDesignsBitmask = &read16(\@decryptedData, 12);
        $index = 14;

        # Reset waypoint counter; waypoints (block 19/20) follow block 16 only.
        $waypointId = 0;

        # fByteCsh=1 means all ship counts fit in 1 byte; 0 means some need 2 bytes.
        my $shipCountTwoBytes = ($fByteCsh == 0) ? 1 : 0;
        for (my $bit = 0; $bit <= 15; $bit++) {
          if ($shipDesignsBitmask & (1 << $bit)) {
            if ($shipCountTwoBytes) {
              $shipCount[$bit] = &read16(\@decryptedData, $index);
              $index += 2;
            } else {
              $shipCount[$bit] = &read8($decryptedData[$index]);
              $index += 1;
            }
          } else {
            $shipCount[$bit] = 0;
          }
        }

        # Cargo section: present when det >= detMore (4 or 7).
        # Variable-length encoding: 2-byte bitmask then 1/2/4 bytes per mineral/fuel.
        if ($kindByte >= 4) {
          my $contentsLengths = &read16(\@decryptedData, $index);
          my $iLength    = $contentsLengths & 0x03;
          $iLength       = 4 >> (3 - $iLength);
          my $bLength    = ($contentsLengths & 0x0C) >> 2;
          $bLength       = 4 >> (3 - $bLength);
          my $gLength    = ($contentsLengths & 0x30) >> 4;
          $gLength       = 4 >> (3 - $gLength);
          my $popLength  = ($contentsLengths & 0xC0) >> 6;
          $popLength     = 4 >> (3 - $popLength);
          my $fuelLength = $contentsLengths >> 8;
          $fuelLength    = 4 >> (3 - $fuelLength);
          $index += 2;
          $ironium    = &readN(\@decryptedData, $index, $iLength);    $index += $iLength;
          $boranium   = &readN(\@decryptedData, $index, $bLength);    $index += $bLength;
          $germanium  = &readN(\@decryptedData, $index, $gLength);    $index += $gLength;
          $population = &readN(\@decryptedData, $index, $popLength);  $index += $popLength;
          $fuel       = &readN(\@decryptedData, $index, $fuelLength); $index += $fuelLength;
        }

        if ($kindByte == 7) {
          # Full fleet (rtFleetA): damage bitmask + damage values + iplan + cord.
          $damagedShipDesigns = &read16(\@decryptedData, $index);
          $index += 2;
          for (my $bit = 0; $bit <= 15; $bit++) {
            if ($damagedShipDesigns & (1 << $bit)) {
              $damagedShipInfo[$bit] = &read16(\@decryptedData, $index);
              $index += 2;
            }
          }
          $battlePlan    = &read8($decryptedData[$index++]); # iplan (0-based)
          $waypointCount = &read8($decryptedData[$index++]); # cord
        } else {
          # Partial fleet (rtFleetB/C): dirLong (4 bytes) + mass (4 bytes).
          # dirLong: dirFltX[0], dirFltY[1], iwarpFlt+flags[2], unused[3].
          $deltaX = &read8($decryptedData[$index++]);
          $deltaY = &read8($decryptedData[$index++]);
          $warp   = $decryptedData[$index] & 0x0F;   # iwarpFlt (low 4 bits)
          $index++;
          $index++;                                   # skip flags/unused byte
          $mass = &read32(\@decryptedData, $index);
          $index += 4;
        }

        if ($display) {
          my @detNames = ('None', 'Minimal', 'Obscure', 'Some', 'More', '', '', 'All');
          my $detName  = $detNames[$kindByte] // $kindByte;

          # Build orbit display: planet ID, name, and coordinates if known.
          my $orbitDisplay;
          if ($positionObjectId == 65535) {
            $orbitDisplay = 'None';
          } else {
            my $pid    = $positionObjectId + 1;
            my $pname  = defined($planet_ID2Name{$pid})
                         ? "($planet_ID2Name{$pid})" : '';
            my $pcoord = defined($planet_coords{$pid})
                         ? " at $planet_coords{$pid}{x},$planet_coords{$pid}{y}" : '';
            $orbitDisplay = "$pid$pname$pcoord";
          }

          print "Fleet:" . ($fleetId+1)
            . ", Player:" . ($ownerId+1)
            . ", Block:$typeId, Det:$kindByte($detName)"
            . ", X:$x, Y:$y, InOrbit:$orbitDisplay";
          if ($kindByte == 7) {
            print ", BattlePlan:" . ($battlePlan+1) . ", Waypoints:$waypointCount";
          }
          print ", Dead:1" if $fDead;
          print "\n";

          # Ship composition: slot number (1-based), count, design name if known.
          my $hasShips = 0;
          for (my $bit = 0; $bit <= 15; $bit++) {
            if ($shipCount[$bit] > 0) {
              if (!$hasShips) { print "  Ships:"; $hasShips = 1; }
              my $dname = exists($designList{$ownerId}{$bit})
                          ? "($designList{$ownerId}{$bit}{shipName})" : '';
              print " Slot" . ($bit+1) . ":$shipCount[$bit]$dname,";
            }
          }
          print "\n" if $hasShips;

          # Cargo (det >= detMore).  Population is stored as units of 100.
          if ($kindByte >= 4) {
            print "  Cargo: Iron:$ironium, Bor:$boranium, Germ:$germanium"
              . ", Pop:" . ($population * 100) . ", Fuel:$fuel\n";
          }

          if ($kindByte == 7) {
            # Damage: pctSh (bits 0-6) and pctDp (bits 7-15) per DV struct.
            my $hasDamage = 0;
            for (my $bit = 0; $bit <= 15; $bit++) {
              if ($damagedShipInfo[$bit] > 0) {
                if (!$hasDamage) { print "  Damage:"; $hasDamage = 1; }
                my $pctSh = $damagedShipInfo[$bit] & 0x7F;
                my $pctDp = ($damagedShipInfo[$bit] >> 7) & 0x01FF;
                print " Slot" . ($bit+1) . ":Ships${pctSh}pct/Armor${pctDp}pct,";
              }
            }
            print "\n" if $hasDamage;
          } else {
            # Direction and mass for partial fleets.
            # dirFltX/Y are 8-bit two's complement direction components.
            if ($deltaX > 127) { $deltaX -= 256; }
            if ($deltaY > 127) { $deltaY -= 256; }
            print "  Dir: dX:$deltaX, dY:$deltaY, Warp:$warp, Mass:$mass\n";
          }
        }

      # ---- Blocks 19/20: Waypoint Orders ----
      # rtOrderA (19): full waypoint with task structure.
      # rtOrderB (20): waypoint without task structure (no transport/patrol data).
      # These always follow block 16 (full fleet).  $fleetId and $ownerId are from
      # the most recently processed fleet block.
      } elsif ($typeId == 19 || $typeId == 20) {
        my ($waypoint_x, $waypoint_y, $targetId, $warp, $taskId);
        my ($targetType, $validTask, $noAutoTrack);
        $waypoint_x  = &read16(\@decryptedData, 0);
        $waypoint_y  = &read16(\@decryptedData, 2);
        $targetId    = &read16(\@decryptedData, 4);
        $warp        = ($decryptedData[6] >> 4) & 0x0F;
        $taskId      = $decryptedData[6] & 0x0F;
        $targetType  = $decryptedData[7] & 0x0F;
        $validTask   = ($decryptedData[7] >> 4) & 0x01;
        $noAutoTrack = ($decryptedData[7] >> 5) & 0x01;

        if ($display) {
          my @taskNames = ('None', 'Transport', 'Colonize', 'RemoteMine',
                           'MergeFleet', 'ScrapFleet', 'LayMines', 'Patrol',
                           'Route', 'TransferFleet');
          my @targetTypeNames = ('Unknown', 'Planet', 'Fleet', 'DeepSpace', 'Object');
          my $taskName       = $taskNames[$taskId]        // "Task:$taskId";
          my $targetTypeName = $targetTypeNames[$targetType] // "Type:$targetType";

          # Build target display with planet name and coords when available.
          my $targetDisplay;
          if ($targetType == 1) {
            my $tid    = $targetId + 1;
            my $tname  = defined($planet_ID2Name{$tid})
                         ? "($planet_ID2Name{$tid})" : '';
            my $tcoord = defined($planet_coords{$tid})
                         ? " at $planet_coords{$tid}{x},$planet_coords{$tid}{y}" : '';
            $targetDisplay = "$tid$tname$tcoord";
          } elsif ($targetType == 2) {
            $targetDisplay = "Fleet:" . ($targetId+1);
          } elsif ($targetId == 511) {
            $targetDisplay = "CurrentLocation";
          } else {
            $targetDisplay = "ID:$targetId";
          }

          print "  WP" . ($waypointId+1)
            . ": X:$waypoint_x, Y:$waypoint_y, Warp:$warp"
            . ", Task:$taskName, Target:$targetTypeName($targetDisplay)"
            . ", RepeatOrders:" . ($noAutoTrack ? 'No' : 'Yes');

          # Task-specific data, only in rtOrderA (19) when the task is valid.
          if ($typeId == 19 && $validTask) {
            if ($taskId == 1) { # Transport
              my @minerals = ('Iron', 'Bor', 'Germ', 'Pop', 'Fuel');
              my @actions  = ('NoTask', 'Transport', 'Load>=', 'Load<=', 'SetTo',
                              'FillPercent', 'WaitForPercent', 'LoadAll', 'UnloadAll',
                              'LoadNone', 'FuelOnly');
              my $hasOrder = 0;
              for (my $i = 0; $i < 5; $i++) {
                my $itemaction = &read16(\@decryptedData, 8 + ($i * 2));
                my $quantity   = $itemaction & 0x0FFF;
                my $action     = ($itemaction >> 12) & 0x0F;
                if ($action != 0) {
                  if (!$hasOrder) { print "\n    Transport:"; $hasOrder = 1; }
                  my $actionName = $actions[$action] // "Act:$action";
                  print " $minerals[$i]:$actionName:${quantity}kT";
                }
              }
            } elsif ($taskId == 6) { # LayMines
              my $mineTime    = &read16(\@decryptedData, 8);
              my $mineTimeOld = &read16(\@decryptedData, 10);
              print ", MineTime:$mineTime, MineTimeOld:$mineTimeOld";
            } elsif ($taskId == 7) { # Patrol
              my $patrolWarp = &read16(\@decryptedData, 8);
              my $patrolDist = &read16(\@decryptedData, 10);
              print ", PatrolWarp:$patrolWarp, PatrolDist:$patrolDist";
            } elsif ($taskId == 9) { # TransferFleet
              my $sellToPlayer = &read16(\@decryptedData, 8);
              print ", ToPlayer:" . ($sellToPlayer+1);
            }
          }
          print "\n";
        }
        $waypointId++;

      # ---- Block 21: rtString (fleet name) ----
      # Follows block 16 and its waypoints when the player has named the fleet.
      # Also follows other named objects; in practice here it always means a fleet name.
      } elsif ($typeId == 21) {
        my $name = &decodeBytesForStarsString(@decryptedData[0..$#decryptedData]);
        if ($display && $name) {
          print "  Name: $name\n";
        }

      } # end block-type dispatch

      # Re-encrypt and push to output for all blocks in the encrypted branch.
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock(
        \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @{$encryptedBlock};
      push @outBytes, @encryptedBlock;

      # For block 7: also push the raw (unencrypted) planet records that
      # immediately follow the block in the file, so @outBytes represents
      # a complete, valid .xy file if we were to write it back out.
      if ($extraOffset > 0) {
        my $planetStart = $offset + 2 + $size;
        push @outBytes, @fileBytes[$planetStart..$planetStart+$extraOffset-1];
      }

      # CRITICAL: sync decryption seeds for the next block.
      $seedA = $seedX;
      $seedB = $seedY;

      $offset += $extraOffset; # extra advance past planet records for block 7

    } # end encrypted-block branch

    if ($display && ($typeId == 16 || $typeId == 17 || $typeId == 18)) {
      print "\n";
    }

    $offset += (2 + $size);
  }
  return \@outBytes;
}

################################################################
sub extract_bitfield {
  my ($value, $start_bit, $num_bits) = @_;
  return ($value >> $start_bit) & ((1 << $num_bits) - 1);
}
