#!/usr/bin/perl
# StarsMerge.pl
# Merges two Stars! .m or .h files (different players, same turn)
# Will read only the most recent turn in a multi-turn .m file
#
# Version History
# 250206  Version 1.0
# 250215  Version 2.0 - Complete rewrite: two-pass merge using decryptA/decryptB
#
#     Copyright (C) 2025 Rick Steeves
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
# Architecture:
#   Step 1: decryptA  - Decrypt and categorize P1's blocks into buckets (save.c order)
#   Step 2: decryptB  - Decrypt P2's blocks, converting owned blocks to partial
#   Step 3: merge_and_write - Merge P1+P2 category by category, encrypt, output
#
# Block ordering follows save.c FWriteDataFile:
#   Block 8 (header) > 31/39 (battles) > 6 (players) > 12/40 (messages) >
#   13/14/28 (planets+queues) > 26 ship designs > 16/17+waypoints (fleets) >
#   26 starbase designs > 45 (scores) > 43 (objects) > 30 (battle plans) > 0 (footer)
#
# Design ownership (Block 26) is determined by counting down cShDef/cshdefSB
# from each player's Block 6, matching file.c lines 464-535 and 912-956.
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings; 
use FindBin;
use lib $FindBin::Bin;
use File::Basename;
use StarsBlock;

my $debug = 0;

# Command line arguments
my $file1 = $ARGV[0]; # Player 1 .M file (base/priority file)
my $file2 = $ARGV[1]; # Player 2 .M file (data to merge in)
my $outFile = $ARGV[2]; # Output merged file

if (!$ARGV[0]) {
  print "\n\nStarsMerge - Merge two Stars! player .M or .H files\n";
  print "Combines data from two different player files from the same turn.\n";
  print ".M files: Merges planets, fleets, designs, objects, scores.\n";
  print ".H files: Merges players, planets, designs, scores.\n";
  print "Player 1's data takes priority, EXCEPT when Player 2 has full blocks\n";
  print "vs partial blocks (e.g., FleetBlock vs PartialFleetBlock).\n\n";
  print "Usage: StarsMerge.pl <player1.m|h> <player2.m|h> [output.m|h]\n\n";
  print "Example:\n";
  print "  StarsMerge.pl game.m1 game.m2 game.m1.merged\n";
  print "  StarsMerge.pl game.h1 game.h2 game.h1.merged\n\n";
  print "Default output is game.m1.merged or game.h1.merged.\n";
  exit;
}

# Validate files exist
unless (-e $file1) { die "Error: File '$file1' does not exist!\n"; }
unless (-e $file2) { die "Error: File '$file2' does not exist!\n"; }

# Detect file type (.M or .H)
my $is_history = ($file1 =~ /\.h\d*$/i || $file1 =~ /\.hst$/i);
if ($file1 =~ /\.m\d*$/i) {
  $is_history = 0;
}
print "Detected file type: " . ($is_history ? "History (.H)" : "Turn (.M)") . "\n" if $debug;

# Read binary files byte by byte
my @fileBytes1 = readFile($file1);
my @fileBytes2 = readFile($file2);

# Step 1: Categorize P1's blocks
print "=== Step 1: Categorizing Player 1 blocks ===\n" if $debug;
my $p1 = decryptA(@fileBytes1, $is_history);

# Step 2: Convert P2's blocks
print "=== Step 2: Converting Player 2 blocks ===\n" if $debug;
my $p2 = decryptB(@fileBytes2, $is_history);
# my $p2 = {
#   planets          => [],
#   fleets           => [],
#   ship_designs     => [],
#   starbase_designs => [],
#   file_player      => 0,
#   players          => [],
#   objects          => [],
#   scores          => [],
# };

# Make sure both files are the same turn. 
if ($p1->{turn} != $p2->{turn}) { die "Error: Turn mismatch! P1 is turn " . ($p1->{turn}+2400) . ", P2 is turn " . ($p2->{turn}+2400) . "\n"; }

# Step 3: Merge and write
print "\n=== Step 3: Merging and writing output ===\n" if $debug;
my $outBytes = merge_and_write($p1, $p2, $is_history);

# Write output file
my $newFile = $outFile || $file1 . '.merged';
open(my $fh, '>:raw', $newFile) or die "Cannot open $newFile: $!\n";
for my $byte (@$outBytes) {
  print $fh $byte;
}
close($fh);
print "\nFile output: $newFile\n";

sub readFile {
  my ($filename) = @_;
  my @bytes;
  my $buf;
  open(my $fh, "<", $filename) or die "Cannot open $filename: $!\n";
  binmode($fh);
  while (read($fh, $buf, 1)) {
    push @bytes, $buf;
  }
  close($fh);
  return @bytes;
}

sub decryptA {
# decryptA - Decrypt and categorize ALL blocks from P1's .M or .H file
# Returns a hash ref with blocks sorted into buckets per save.c write order.
# No merging, no conversion -- just decrypt and categorize.
# Record format for encrypted blocks:
#   [ $typeId, $id1, $id2, \@blockHeader, \@decryptedData, $padding ]
# Design ownership is determined by counting down cShDef/cshdefSB from
# each player's Block 6, matching file.c lines 464-535 and 912-956.
  my (@fileBytes) = @_;
  my $is_history = pop(@fileBytes);  # Last parameter is file type flag
  my @block;
  my @data;
  my ($decryptedData, $padding);
  my @decryptedData;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt );
  my ( $seedA, $seedB );
  my ( $FileValues, $typeId, $size );
  my $offset = 0;

  # Categorized block arrays - per save.c FWriteDataFile order
  my @header;             # Block 8  (raw bytes, unencrypted)
  my @battles;            # Block 31, 39
  my @players;            # Block 6
  my @messages;           # Block 12, 40
  my @planets;            # Block 13, 14, 28 (file order preserves planet+queue grouping)
  my @ship_designs;       # Block 26 (bit 6 of byte[1] = 0)
  my @fleets;             # Block 16, 17, 19, 20, 21, 23, 24, 37 (file order)
  my @starbase_designs;   # Block 26 (bit 6 of byte[1] = 1)
  my @scores;             # Block 45
  my @objects;            # Block 43
  my @battle_plans;       # Block 30
  my @counters;           # Block 32 (.H files only) - P1 only, don't merge
  my @message_filters;    # Block 33 (.H files only) - P1 only, don't merge
  my @footer;             # Block 0  (raw bytes, unencrypted)
  
  # Design ownership tracking (mirrors file.c)
  # Populated from Block 6 records, consumed as Block 26s are encountered
  my @ship_design_counts;       # [ [playerId, remaining], ... ] in player order
  my @starbase_design_counts;   # [ [playerId, remaining], ... ] in player order
  my $ship_design_idx = 0;
  my $starbase_design_idx = 0;

  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data  = @fileBytes[$offset+2 .. $offset+(2+$size)-1];
    @block = @fileBytes[$offset .. $offset+(2+$size)-1];

    if ($typeId == 8) {  # FileHeaderBlock - not encrypted
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
      @header = @block;
      print "  decryptA: Block 8 header, Player=$Player, Turn=$turn\n" if $debug;

      # Reset arrays - only keep the most recent year
      @players = ();
      @planets = ();
      @fleets = ();
      @ship_designs = ();
      @starbase_designs = ();
      @objects = ();
      @scores = ();
      @ship_design_counts = ();
      @starbase_design_counts = ();
      $ship_design_idx = 0;
      $starbase_design_idx = 0;

    } elsif ($typeId == 0) {  # FileFooterBlock - not encrypted
      @footer = @block;

    } else {
      # Everything else needs decryption
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB);
      @decryptedData = @{$decryptedData};
      my @blockHeader = @block[0..1];  # 2-byte header preserved for re-encryption

      if ($typeId == 6) {  # PlayerBlock
        my $playerId = $decryptedData[0] & 0xFF;
        my $cShDef = $decryptedData[1] & 0xFF;
        my $word45 = ($decryptedData[4] & 0xFF) | (($decryptedData[5] & 0xFF) << 8);
        my $cFleet = $word45 & 0x0FFF;
        my $cshdefSB = ($word45 >> 12) & 0x0F;
        my $cPlanet = ($decryptedData[2] & 0xFF) | (($decryptedData[3] & 0xFF) << 8);

        # Track design counts for ownership assignment
        push @ship_design_counts, [ $playerId, $cShDef ] if $cShDef > 0;
        push @starbase_design_counts, [ $playerId, $cshdefSB ] if $cshdefSB > 0;

        print "  decryptA: Block 6 player=$playerId cShDef=$cShDef cPlanet=$cPlanet cFleet=$cFleet cshdefSB=$cshdefSB\n" if $debug;
        push @players, [ $typeId, $playerId, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 12 || $typeId == 40) {  # EventsBlock, MessageBlock
        push @messages, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 31 || $typeId == 39) {  # BattleBlock, ContinueBlock
        push @battles, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 13 || $typeId == 14) {  # PlanetBlock, PartialPlanetBlock
        my $field1 = read16(\@decryptedData, 0);
        my $planetId = $field1 & 0x7FF;
        my $ownerId = ($field1 >> 11) & 0x1F;
        if ($ownerId == 31) { $ownerId = -1; }
        push @planets, [ $typeId, $planetId, $ownerId, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 28) {  # ProductionQueueBlock - follows its planet
        push @planets, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 26) {  # DesignBlock
        my $is_starbase = ($decryptedData[1] >> 6) & 0x01;

        if ($is_starbase) {
          while ($starbase_design_idx < @starbase_design_counts
                 && $starbase_design_counts[$starbase_design_idx][1] <= 0) {
            $starbase_design_idx++;
          }
          my $designPlayer = -1;
          if ($starbase_design_idx < @starbase_design_counts) {
            $designPlayer = $starbase_design_counts[$starbase_design_idx][0];
            $starbase_design_counts[$starbase_design_idx][1]--;
          }
          print "  decryptA: Starbase design -> player $designPlayer\n" if $debug;
          push @starbase_designs, [ $typeId, 1, $designPlayer, [@blockHeader], [@decryptedData], $padding ];
        } else {
          while ($ship_design_idx < @ship_design_counts
                 && $ship_design_counts[$ship_design_idx][1] <= 0) {
            $ship_design_idx++;
          }
          my $designPlayer = -1;
          if ($ship_design_idx < @ship_design_counts) {
            $designPlayer = $ship_design_counts[$ship_design_idx][0];
            $ship_design_counts[$ship_design_idx][1]--;
          }
          print "  decryptA: Ship design -> player $designPlayer\n" if $debug;
          push @ship_designs, [ $typeId, 0, $designPlayer, [@blockHeader], [@decryptedData], $padding ];
        }

      } elsif ($typeId == 16 || $typeId == 17) {  # FleetBlock, PartialFleetBlock
        my $field1 = read16(\@decryptedData, 0);
        my $fleetId = $field1 & 0x1FF;
        my $ownerId = ($field1 >> 9) & 0x0F;
        push @fleets, [ $typeId, $fleetId, $ownerId, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 19 || $typeId == 20 || $typeId == 21) {  # Waypoints, FleetName
        push @fleets, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 23 || $typeId == 24 || $typeId == 37) {  # MoveShips, FleetSplit, FleetsMerge
        push @fleets, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];

      } elsif ($typeId == 45) {  # PlayerScoresBlock
        # Parse player ID from first 2 bytes
        my $wWord = ($decryptedData[0] & 0xFF) | (($decryptedData[1] & 0xFF) << 8);
        my $playerId = $wWord & 0x1F;  # 5 bits for iPlayer
        push @scores, [ $typeId, $playerId, 0, [@blockHeader], [@decryptedData], $padding ];
        
      } elsif ($typeId == 43) {  # ObjectBlock
        # Parse object ID
        my $idFull = ($decryptedData[0] & 0xFF) | (($decryptedData[1] & 0xFF) << 8);
        my $objectId = $idFull & 0x1FF;  # 9 bits
        my $ownerId = ($idFull >> 9) & 0x0F;  # 4 bits
        my $objectType = ($idFull >> 13) & 0x07;  # 3 bits
        my @newHeader = makeBlockHeader(43, scalar(@decryptedData));
        push @objects, [ $typeId, $objectId, $ownerId, [@newHeader], [@decryptedData] ];
      } elsif ($typeId == 30) {  # BattlePlanBlock
        push @battle_plans, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];
      } elsif ($typeId == 32) {  # CountersBlock (.H files) - P1 only
        push @counters, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];
        print "  decryptA: Block 32 (counters) size=" . scalar(@decryptedData) . "\n" if $debug;
      } elsif ($typeId == 33) {  # MessageFiltersBlock (.H files) - P1 only
        push @message_filters, [ $typeId, 0, 0, [@blockHeader], [@decryptedData], $padding ];
        print "  decryptA: Block 33 (message filters) size=" . scalar(@decryptedData) . "\n" if $debug;
      } else {
        print "  decryptA: Unhandled typeId=$typeId size=$size offset=$offset\n" if $debug;
      }
    }
    $offset = $offset + (2 + $size);
  }

  print "  decryptA summary: players=" . scalar(@players) .
    " planets=" . scalar(@planets) .
    " ship_designs=" . scalar(@ship_designs) .
    " fleets=" . scalar(@fleets) .
    " starbase_designs=" . scalar(@starbase_designs) . "\n" if $debug;

  return {
    header           => \@header,
    battles          => \@battles,
    players          => \@players,
    messages         => \@messages,
    planets          => \@planets,
    ship_designs     => \@ship_designs,
    fleets           => \@fleets,
    starbase_designs => \@starbase_designs,
    scores           => \@scores,
    objects          => \@objects,
    battle_plans     => \@battle_plans,
    counters         => \@counters,
    message_filters  => \@message_filters,
    footer           => \@footer,
    file_player      => $Player,
    turn             => $turn,
    is_history       => $is_history,
  };
}

sub decryptB {
# decryptB - Decrypt P2's blocks, converting owned blocks to partial.
# Record format: [ $typeId, $id1, $id2, \@blockHeader, \@decryptedData ]
# (no padding field - these get fresh headers)
# Waypoints (19/20), queues (28), fleet names (21) are STRIPPED from P2.
# For .H files: Blocks 32 and 33 are also STRIPPED (P1 only).
  my (@fileBytes) = @_;
  my $is_history = pop(@fileBytes);  # Last parameter is file type flag
  my @block;
  my @data;
  my ($decryptedData, $padding);
  my @decryptedData;
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt );
  my ( $seedA, $seedB );
  my ( $FileValues, $typeId, $size );
  my $offset = 0;

  my @players;
  my @planets;
  my @fleets;
  my @ship_designs;
  my @starbase_designs;
  my @objects;
  my @scores;

  # Design ownership tracking (same as decryptA)
  my @ship_design_counts;
  my @starbase_design_counts;
  my $ship_design_idx = 0;
  my $starbase_design_idx = 0;

  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data  = @fileBytes[$offset+2 .. $offset+(2+$size)-1];
    @block = @fileBytes[$offset .. $offset+(2+$size)-1];

    if ($typeId == 8) {  # FileHeaderBlock
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
      print "  decryptB: Block 8 header, Player=$Player, Turn=$turn\n" if $debug;
      # Reset arrays - only keep the most recent year
      @players = ();
      @planets = ();
      @fleets = ();
      @ship_designs = ();
      @starbase_designs = ();
      @objects = ();
      @scores = ();
      @ship_design_counts = ();
      @starbase_design_counts = ();
      $ship_design_idx = 0;
      $starbase_design_idx = 0;

    } elsif ($typeId == 0) {  # FileFooterBlock
    } else {
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB);
      @decryptedData = @{$decryptedData};

      if ($typeId == 6) {  # PlayerBlock - extract design counts
        my $playerId = $decryptedData[0] & 0xFF;
        my $cShDef = $decryptedData[1] & 0xFF;
        my $word45 = ($decryptedData[4] & 0xFF) | (($decryptedData[5] & 0xFF) << 8);
        my $cshdefSB = ($word45 >> 12) & 0x0F;

        push @ship_design_counts, [ $playerId, $cShDef ] if $cShDef > 0;
        push @starbase_design_counts, [ $playerId, $cshdefSB ] if $cshdefSB > 0;

        my @newHeader = makeBlockHeader(6, scalar(@decryptedData));
        push @players, [ 6, $playerId, 0, [@newHeader], [@decryptedData] ];

        print "  decryptB: Block 6 player=$playerId cShDef=$cShDef cshdefSB=$cshdefSB\n" if $debug;

      } elsif ($typeId == 13) {  # PlanetBlock (P2 owns) -> convert to Block 14
        my $field1 = read16(\@decryptedData, 0);
        my $planetId = $field1 & 0x7FF;
        my $ownerId = ($field1 >> 11) & 0x1F;
        if ($ownerId == 31) { $ownerId = -1; }

        my $converted = ConvertPlanetToPartial(\@decryptedData);
        my @convData = @{$converted};

        my @newHeader = makeBlockHeader(14, scalar(@convData));
        print "  decryptB: Planet $planetId (owner=$ownerId) Block 13 -> 14\n" if $debug;
        push @planets, [ 14, $planetId, $ownerId, [@newHeader], [@convData] ];

      } elsif ($typeId == 14) {  # PartialPlanetBlock - keep as-is
        my $field1 = read16(\@decryptedData, 0);
        my $planetId = $field1 & 0x7FF;
        my $ownerId = ($field1 >> 11) & 0x1F;
        if ($ownerId == 31) { $ownerId = -1; }

        my @newHeader = makeBlockHeader(14, scalar(@decryptedData));
        push @planets, [ 14, $planetId, $ownerId, [@newHeader], [@decryptedData] ];

      } elsif ($typeId == 16) {  # FleetBlock (P2 owns) -> convert to Block 17
        my $field1 = read16(\@decryptedData, 0);
        my $fleetId = $field1 & 0x1FF;
        my $ownerId = ($field1 >> 9) & 0x0F;

        my $converted = convertFleetToPartial(\@decryptedData);
        my @convData = @{$converted};

        my @newHeader = makeBlockHeader(17, scalar(@convData));
        print "  decryptB: Fleet $fleetId (owner=$ownerId) Block 16 -> 17\n" if $debug;
        push @fleets, [ 17, $fleetId, $ownerId, [@newHeader], [@convData] ];

      } elsif ($typeId == 17) {  # PartialFleetBlock - keep as-is
        my $field1 = read16(\@decryptedData, 0);
        my $fleetId = $field1 & 0x1FF;
        my $ownerId = ($field1 >> 9) & 0x0F;

        my @newHeader = makeBlockHeader(17, scalar(@decryptedData));
        push @fleets, [ 17, $fleetId, $ownerId, [@newHeader], [@decryptedData] ];

      } elsif ($typeId == 26) {  # DesignBlock - keep unconverted, determine ownership
        my $is_starbase = ($decryptedData[1] >> 6) & 0x01;
        my @newHeader = makeBlockHeader(26, scalar(@decryptedData));

        if ($is_starbase) {
          while ($starbase_design_idx < @starbase_design_counts
                 && $starbase_design_counts[$starbase_design_idx][1] <= 0) {
            $starbase_design_idx++;
          }
          my $designPlayer = -1;
          if ($starbase_design_idx < @starbase_design_counts) {
            $designPlayer = $starbase_design_counts[$starbase_design_idx][0];
            $starbase_design_counts[$starbase_design_idx][1]--;
          }
          print "  decryptB: Starbase design -> player $designPlayer\n" if $debug;
          push @starbase_designs, [ 26, 1, $designPlayer, [@newHeader], [@decryptedData] ];
        } else {
          while ($ship_design_idx < @ship_design_counts
                 && $ship_design_counts[$ship_design_idx][1] <= 0) {
            $ship_design_idx++;
          }
          my $designPlayer = -1;
          if ($ship_design_idx < @ship_design_counts) {
            $designPlayer = $ship_design_counts[$ship_design_idx][0];
            $ship_design_counts[$ship_design_idx][1]--;
          }
          print "  decryptB: Ship design -> player $designPlayer\n" if $debug;
          push @ship_designs, [ 26, 0, $designPlayer, [@newHeader], [@decryptedData] ];
        }
      } elsif ($typeId == 43) {  # ObjectBlock
        # Parse object ID from first 2 bytes
        my $idFull = ($decryptedData[0] & 0xFF) | (($decryptedData[1] & 0xFF) << 8);
        my $objectId = $idFull & 0x1FF;  # 9 bits
        my $ownerId = ($idFull >> 9) & 0x0F;  # 4 bits
        my $objectType = ($idFull >> 13) & 0x07;  # 3 bits
        
        my @newHeader = makeBlockHeader(43, scalar(@decryptedData));
        print "  decryptB: Object id=$objectId owner=$ownerId type=$objectType\n" if $debug;
        push @objects, [ $typeId, $objectId, $ownerId, [@newHeader], [@decryptedData] ];
        
       } elsif ($typeId == 45) {  # PlayerScoresBlock
        # Parse player ID from first 2 bytes
        my $wWord = ($decryptedData[0] & 0xFF) | (($decryptedData[1] & 0xFF) << 8);
        my $playerId = $wWord & 0x1F;  # 5 bits for iPlayer
        
        my @newHeader = makeBlockHeader(45, scalar(@decryptedData));
        print "  decryptB: Score for player $playerId\n" if $debug;
        push @scores, [ $typeId, $playerId, 0, [@newHeader], [@decryptedData] ];
      } # else: skip Block 28 (queues), 19/20 (waypoints), 21 (names), 32 (counters), 33 (filters), etc.      
    }
    $offset = $offset + (2 + $size);
  }

  print "  decryptB summary: players=" . scalar(@players) .
        " planets=" . scalar(@planets) .
        " fleets=" . scalar(@fleets) .
        " ship_designs=" . scalar(@ship_designs) .
        " starbase_designs=" . scalar(@starbase_designs) . "\n" if $debug;

  return {
    players          => \@players,
    planets          => \@planets,
    fleets           => \@fleets,
    ship_designs     => \@ship_designs,
    starbase_designs => \@starbase_designs,
    scores           => \@scores,
    objects          => \@objects,
    file_player      => $Player,
    turn             => $turn,
  };
}

# PLAYER struct layout constants (from struct.h, 16-bit MSVC pack(2))
# cbPlayerSome = offset of idPlanetHome = 8 bytes
#   Contains: iPlayer, cShDef, cPlanet, cFleet:12/cshdefSB:4, det/iPlrBmp/fInclude/mdPlayer
#
# cbPlayerAll = offset of rgmdRelation[0] = 112 bytes
#   Contains: everything up to but not including rgmdRelation
# Block 6 on-disk format (WriteRtPlr/ReadRtPlr):
#   detAll (owner):     cbPlayerAll bytes + 1 byte rel_count + rel_count bytes + names
#   non-owner:          cbPlayerSome bytes + names
#   Names:              1 byte compressed_len (0=uncompressed) + name_data, twice (singular+plural)
use constant CB_PLAYER_SOME => 8;
use constant CB_PLAYER_ALL  => 112;


sub convertPlayerToNonOwner {
# Convert a detAll Block 6 to non-owner format
# Takes the full detAll decrypted data, extracts the cbPlayerSome header
# and the name strings, sets det=3 (detSome), returns the shorter block.
 my ($data) = @_;
  my @data = @$data;

  # Take first cbPlayerSome bytes (iPlayer through det/flags word)
  my @output = @data[0 .. CB_PLAYER_SOME - 1];

  # Change det from 7 (detAll) to 3 (detSome) in bytes 6-7
  my $word67 = ($output[6] & 0xFF) | (($output[7] & 0xFF) << 8);
  $word67 = ($word67 & ~0x07) | 3;  # clear det bits, set to detSome
  $output[6] = $word67 & 0xFF;
  $output[7] = ($word67 >> 8) & 0xFF;

  # Extract name strings from the detAll block
  # detAll format: cbPlayerAll bytes of struct, then 1 byte relation count,
  # then relation_count bytes of relations, then name strings
  my $offset = CB_PLAYER_ALL;
  my $rel_count = $data[$offset] & 0xFF;
  $offset += 1 + $rel_count;  # skip count byte + relation bytes

  # Append name strings (everything from $offset to end of block)
  push @output, @data[$offset .. $#data];

  print "  convertPlayerToNonOwner: cbPlayerSome=" . CB_PLAYER_SOME .
        " rel_count=$rel_count names_start=$offset output_size=" . scalar(@output) . "\n" if $debug;
  return \@output;
}

sub merge_and_write {
  # Merge P1 and P2 categorized blocks, encrypt, output
  # For .M files, walks through block categories in save.c order:
  #   header > battles > players > messages > planets >
  #   ship_designs > fleets > starbase_designs >
  #   scores > objects > battle_plans > footer
  # For .H files, order is:
  #   header > counters > players > message_filters > planets >
  #   ship_designs > starbase_designs > scores > footer
  # Returns array ref of encrypted bytes ready to write to file.
  my ($p1, $p2, $is_history) = @_;
  my @outBytes;

  # Initialize encryption seeds from P1's header
  my @header = @{$p1->{header}};
  my ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt ) = &getFileHeaderBlock(\@header);
  my ( $seedA, $seedB ) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
  my $seedX = $seedA;  # encryption seeds track separately
  my $seedY = $seedB;

  my $p2_player = $p2->{file_player};

  print "  merge: P1 player=$Player, P2 player=$p2_player\n" if $debug;

  # ---- Merge all categories first, then count, then encrypt ----
  # We need final counts before encrypting Block 6, and Block 6 comes
  # early in the file.  So: merge everything, count, patch Block 6, 
  # then encrypt all in order.
  # Merge planets
  my @merged_planets = mergePlanets($p1->{planets}, $p2->{planets});
  my $merged_planet_count = 0;
  for my $rec (@merged_planets) {
    $merged_planet_count++ if ($rec->[0] == 13 || $rec->[0] == 14);
  }

  # Merge fleets
  my @merged_fleets = mergeFleets($p1->{fleets}, $p2->{fleets});
  my $merged_fleet_count = 0;
  for my $rec (@merged_fleets) {
    $merged_fleet_count++ if ($rec->[0] == 16 || $rec->[0] == 17);
  }

  # Merge designs
#  my @merged_ship_designs = mergeDesigns($p1->{ship_designs}, $p2->{ship_designs});
  my @merged_ship_designs = mergeDesigns($p1->{ship_designs}, $p2->{ship_designs}, $p1->{file_player}, $p2->{file_player});
#  my @merged_sb_designs   = mergeDesigns($p1->{starbase_designs}, $p2->{starbase_designs});
  my @merged_sb_designs   = mergeDesigns($p1->{starbase_designs}, $p2->{starbase_designs}, $p1->{file_player}, $p2->{file_player});

  # Count merged designs per player
  my %merged_ship_counts;
  for my $rec (@merged_ship_designs) {
    $merged_ship_counts{$rec->[2]}++ if $rec->[2] >= 0;
  }
  my %merged_sb_counts;
  for my $rec (@merged_sb_designs) {
    $merged_sb_counts{$rec->[2]}++ if $rec->[2] >= 0;
  }

  # ---- Now encrypt everything in save.c order ----
  # 1. Header (Block 8) - unencrypted
  push @outBytes, @header;
  
  # 2. For .H files: Counters (Block 32) - P1 only
  if ($is_history) {
    for my $rec (@{$p1->{counters}}) {
      encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);
    }
  }

  # 3. For .M files: Battles (Block 31, 39) - P1 only
  if (!$is_history) {
    for my $rec (@{$p1->{battles}}) {
      encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);
    }
  }

  # 4. Players (Block 6) - merge by playerId, P1 wins duplicates
  #    Need Block 6 for every player whose designs/fleets/planets are in the file.
  my %p1_players_by_id;
  for my $rec (@{$p1->{players}}) {
    $p1_players_by_id{$rec->[1]} = $rec;
  }
  my %p2_players_by_id;
  for my $rec (@{$p2->{players}}) {
    $p2_players_by_id{$rec->[1]} = $rec;
  }
  # Collect all player IDs, sorted
  my %all_player_ids;
  $all_player_ids{$_} = 1 for keys %p1_players_by_id;
  $all_player_ids{$_} = 1 for keys %p2_players_by_id;

  my @merged_player_records;
  for my $pid (sort { $a <=> $b } keys %all_player_ids) {
    if (exists $p1_players_by_id{$pid}) {
      push @merged_player_records, $p1_players_by_id{$pid};
    } else {
      my $rec = $p2_players_by_id{$pid};
      my @d = @{$rec->[4]};

      # Check if this Block 6 is detAll (P2's file owner)
      my $word67 = ($d[6] & 0xFF) | (($d[7] & 0xFF) << 8);
      my $det = $word67 & 0x07;

      if ($det == 7 && $pid != $Player) {
        # Convert detAll -> non-owner format
        my $converted = convertPlayerToNonOwner(\@d);
        my @convData = @$converted;
        my @newHeader = makeBlockHeader(6, scalar(@convData));
        push @merged_player_records, [ 6, $pid, 0, [@newHeader], [@convData] ];
        print "  merge: converted P2 Block 6 player $pid from detAll to non-owner (" . scalar(@convData) . " bytes)\n" if $debug;
      } else {
        push @merged_player_records, $rec;
        print "  merge: added P2 Block 6 for player $pid as-is\n" if $debug;
      }
    }
  }

  # The reader (file.c) only uses the file owner's cPlanet/cFleet
  # as the total count -- non-owner Block 6 counts are zeroed on read.
  # So owner's counts must equal the total merged counts.
  my $owner_cPlanet = $merged_planet_count;
  my $owner_cFleet  = $merged_fleet_count;
  print "  merge: owner cPlanet=$owner_cPlanet cFleet=$owner_cFleet\n" if $debug;

  for my $rec (@merged_player_records) {
    my $playerId = $rec->[1];
    my @d = @{$rec->[4]};  # copy decrypted data for patching

    # Set file owner's cPlanet and cFleet to correct absolute values
    if ($playerId == $Player) {
      # cPlanet (bytes 2-3)
      $d[2] = $owner_cPlanet & 0xFF;
      $d[3] = ($owner_cPlanet >> 8) & 0xFF;

      # cFleet (bytes 4-5, bottom 12 bits; preserve cshdefSB in top 4)
      my $word45 = ($d[4] & 0xFF) | (($d[5] & 0xFF) << 8);
      my $cshdefSB_bits = $word45 & 0xF000;
      my $newWord45 = ($owner_cFleet & 0x0FFF) | $cshdefSB_bits;
      $d[4] = $newWord45 & 0xFF;
      $d[5] = ($newWord45 >> 8) & 0xFF;

      print "  merge: Owner Block 6: cPlanet=$owner_cPlanet cFleet=$owner_cFleet\n" if $debug;
    } else {
      # Non-owner: zero cPlanet and cFleet (reader zeroes them anyway)
      $d[2] = 0;
      $d[3] = 0;
      my $word45 = ($d[4] & 0xFF) | (($d[5] & 0xFF) << 8);
      my $cshdefSB_bits = $word45 & 0xF000;
      $d[4] = $cshdefSB_bits & 0xFF;
      $d[5] = ($cshdefSB_bits >> 8) & 0xFF;

      print "  merge: Non-owner Block 6 player $playerId: zeroed cPlanet/cFleet\n" if $debug;
    }

    # Patch cShDef for any player with updated design counts
    if (exists $merged_ship_counts{$playerId}) {
      $d[1] = $merged_ship_counts{$playerId} & 0xFF;
      print "  merge: Player $playerId cShDef=$d[1]\n" if $debug;
    }

    # Patch cshdefSB for any player with updated starbase design counts
    if (exists $merged_sb_counts{$playerId}) {
      my $word45 = ($d[4] & 0xFF) | (($d[5] & 0xFF) << 8);
      my $newSB = $merged_sb_counts{$playerId} & 0x0F;
      $word45 = ($word45 & 0x0FFF) | ($newSB << 12);
      $d[4] = $word45 & 0xFF;
      $d[5] = ($word45 >> 8) & 0xFF;
      print "  merge: Player $playerId cshdefSB=$newSB\n" if $debug;
    }

    # Encrypt with patched data
    my @blockHeader = @{$rec->[3]};
    my $pad = defined($rec->[5]) ? $rec->[5] : 0;
    my ($encBlock, $newSX, $newSY) = &encryptBlock(\@blockHeader, \@d, $pad, $seedX, $seedY);
    push @outBytes, @$encBlock;
    $seedX = $newSX;
    $seedY = $newSY;
  }
  
  # 5. For .H files: Message Filters (Block 33) - P1 only
  if ($is_history) {
    for my $rec (@{$p1->{message_filters}}) {
      encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);
    }
  }

  # 6. For .M files: Messages (Block 12, 40) - P1 only
  if (!$is_history) {
    for my $rec (@{$p1->{messages}}) { 
      encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY); 
    }
  }
  
  # 7. Planets (Block 13/14/28) - merged
  for my $rec (@merged_planets) {  encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);  }

  # 8. Ship Designs (Block 26, bit6=0) - merged
  for my $rec (@merged_ship_designs) { encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);  }

  # 9. For .M files: Fleets (Block 16/17 + waypoints) - merged
  if (!$is_history) {
    for my $rec (@merged_fleets) { 
      encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY); 
    }
  }

  # 10. Starbase Designs (Block 26, bit6=1) - merged
  for my $rec (@merged_sb_designs) {  encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);  }

  # 11. Scores (Block 45) - merge by player
  my @merged_scores = mergeScores($p1->{scores}, $p2->{scores});
  for my $rec (@merged_scores) {    encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);   }

  # 12. For .M files: Objects (Block 43) - merge by ID
  if (!$is_history) {
    my @merged_objects = mergeObjects($p1->{objects}, $p2->{objects});
    for my $rec (@merged_objects) {  encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);    }
  }

  # 13. For .M files: Battle Plans (Block 30) - P1 only
  if (!$is_history) {
    for my $rec (@{$p1->{battle_plans}}) { encryptAndPush(\@outBytes, $rec, \$seedX, \$seedY);   }
  }
   
  push @outBytes, @{$p1->{footer}};  # 14. Footer (Block 0) - unencrypted    
  
  print "  merge: Output size=" . scalar(@outBytes) . " bytes\n" if $debug;
  return \@outBytes;
}

sub encryptAndPush {
# encryptAndPush - Encrypt a record and append to output array
# Handles both decryptA records (6-element with padding) and
# decryptB records (5-element without padding).
  my ($outBytes, $rec, $seedX_ref, $seedY_ref) = @_;
  my @blockHeader = @{$rec->[3]};
  my @data = @{$rec->[4]};
  my $pad = defined($rec->[5]) ? $rec->[5] : 0;

  my ($encBlock, $newSeedX, $newSeedY) = &encryptBlock(\@blockHeader, \@data, $pad, $$seedX_ref, $$seedY_ref);
  push @$outBytes, @$encBlock;
  $$seedX_ref = $newSeedX;
  $$seedY_ref = $newSeedY;
}

sub mergePlanets {
# mergePlanets - Merge P1 and P2 planet arrays by planetId
# P1's array may contain Block 28 (queues) following their planet.
# P2's array has no queues (stripped by decryptB).
# On duplicate planetId, P1 wins (may have Block 13 for owned planets).
  my ($p1_planets, $p2_planets) = @_;
  my @merged;
  my $p2idx = 0;

  for my $i (0 .. $#{$p1_planets}) {
    my $p1rec = $p1_planets->[$i];
    my $p1type = $p1rec->[0];
    
    if ($p1type == 28) { # Block 28 (queue) follows its planet - just pass through
      push @merged, $p1rec;
      next;
    }

    my $p1_planetId = $p1rec->[1];

    # Insert P2 planets with smaller IDs before this P1 planet
    while ($p2idx < @$p2_planets && $p2_planets->[$p2idx][1] < $p1_planetId) {
      push @merged, $p2_planets->[$p2idx];
      print "    mergePlanets: added P2 planet " . $p2_planets->[$p2idx][1] . " (before P1 planet $p1_planetId)\n" if $debug;
      $p2idx++;
    }

    # Duplicate planetId - compare det levels, highest wins
    if ($p2idx < @$p2_planets && $p2_planets->[$p2idx][1] == $p1_planetId) {
      my $p1_det = $p1rec->[4][2] & 0x7F;
      my $p2_det = $p2_planets->[$p2idx][4][2] & 0x7F;
      if ($p2_det > $p1_det || ($p2_det == $p1_det && $p2_planets->[$p2idx][0] < $p1type)) {
        $p1rec = $p2_planets->[$p2idx];
        print "    mergePlanets: P2 wins duplicate planetId=$p1_planetId (det $p2_det vs $p1_det)\n" if $debug;
      } else {
        print "    mergePlanets: P1 wins duplicate planetId=$p1_planetId (det $p1_det vs $p2_det)\n" if $debug;
      }
      $p2idx++;
    }
        
    push @merged, $p1rec; # Add P1's planet
  }

  # Add remaining P2 planets after all P1 planets
  while ($p2idx < @$p2_planets) {
    push @merged, $p2_planets->[$p2idx];
    print "    mergePlanets: added trailing P2 planet " . $p2_planets->[$p2idx][1] . "\n" if $debug;
    $p2idx++;
  }
  return @merged;
}

sub mergeFleets {
# mergeFleets - Merge P1 and P2 fleet arrays
# P1's array contains fleet blocks + associated waypoints/names in file order.
# P2's array contains only fleet blocks (17, converted from 16).
# P2 fleets are interleaved by (ownerId, fleetId) into the correct position.
# On duplicate (ownerId, fleetId), P1 wins.
# Fleet blocks in Stars! files are ordered by owner then by fleetId.
# Associated blocks (19, 20, 21, 23, 24, 37) immediately follow their fleet.
  my ($p1_fleets, $p2_fleets) = @_;
  my @merged;
  my $p2idx = 0;

  for my $i (0 .. $#{$p1_fleets}) {
    my $p1rec = $p1_fleets->[$i];
    my $p1type = $p1rec->[0];

    # Associated blocks (waypoints, names, etc.) follow their fleet - pass through
    if ($p1type != 16 && $p1type != 17) {
      push @merged, $p1rec;
      next;
    }

    my $p1_fleetId = $p1rec->[1];
    my $p1_ownerId = $p1rec->[2];

    # Insert P2 fleets that sort before this P1 fleet
    while ($p2idx < @$p2_fleets) {
      my $p2rec = $p2_fleets->[$p2idx];
      my $p2_ownerId = $p2rec->[2];
      my $p2_fleetId = $p2rec->[1];

      # Compare (ownerId, fleetId) tuples
      if ($p2_ownerId < $p1_ownerId ||
          ($p2_ownerId == $p1_ownerId && $p2_fleetId < $p1_fleetId)) {
        push @merged, $p2rec;
        print "    mergeFleets: added P2 fleet owner=$p2_ownerId id=$p2_fleetId\n" if $debug;
        $p2idx++;
      } elsif ($p2_ownerId == $p1_ownerId && $p2_fleetId == $p1_fleetId) {
        # Duplicate - compare det levels, highest wins
        my $p1_det = $p1rec->[4][4] & 0xFF;
        my $p2_det = $p2rec->[4][4] & 0xFF;
        if ($p2_det > $p1_det || ($p2_det == $p1_det && $p2rec->[0] < $p1type)) {
          $p1rec = $p2rec;
          print "    mergeFleets: P2 wins duplicate fleet owner=$p1_ownerId id=$p1_fleetId (det $p2_det vs $p1_det)\n" if $debug;
        } else {
          print "    mergeFleets: P1 wins duplicate fleet owner=$p1_ownerId id=$p1_fleetId (det $p1_det vs $p2_det)\n" if $debug;
        }
        $p2idx++;
        last;      
      } else {
        last;
      }
    }
    push @merged, $p1rec;
  }
 
  while ($p2idx < @$p2_fleets) { # Add remaining P2 fleets
    my $p2rec = $p2_fleets->[$p2idx];
    push @merged, $p2rec;
    print "    mergeFleets: added trailing P2 fleet owner=" . $p2rec->[2] . " id=" . $p2rec->[1] . "\n" if $debug;
    $p2idx++;
  }
  return @merged;
}

sub mergeDesigns {
# mergeDesigns - Merge P1 and P2 design arrays by player order
# Both arrays have records tagged with owning player (id2 field).
# Designs are grouped by player in player-number order.
# P1's designs for a given player take priority.
# P2's designs are added for players not represented in P1.
  my ($p1_designs, $p2_designs, $p1_owner, $p2_owner) = @_;
  # Index designs by player and slot
  my %designs;  # $designs{$player}{$slot} = $design_record
  
  # Add P1's designs
  for my $rec (@$p1_designs) {
    my $plr = $rec->[2];  # Player who owns the design
    my $slot = extractDesignSlot($rec->[4]);  # Extract ishdef from design data
    $designs{$plr}{$slot} = $rec;
    print "    mergeDesigns: P1 design - player=$plr, slot=$slot\n" if $debug;
  }
  
  # Add P2's designs (overwrite if P2 owns that player, otherwise only fill gaps)
  for my $rec (@$p2_designs) {
    my $plr = $rec->[2];
    my $slot = extractDesignSlot($rec->[4]);
    
    if ($plr == $p2_owner) {
      # P2 owns this player - their designs are authoritative
      $designs{$plr}{$slot} = $rec;
      print "    mergeDesigns: P2 design (OWNER) - player=$plr, slot=$slot\n" if $debug;
    } elsif (!exists $designs{$plr}{$slot}) {
      # P1 doesn't have this slot - add it
      $designs{$plr}{$slot} = $rec;
      print "    mergeDesigns: P2 design (new slot) - player=$plr, slot=$slot\n" if $debug;
    }
  }
  
  my @merged; # Output in order: by player, then by slot
  for my $plr (sort { $a <=> $b } keys %designs) {
    for my $slot (sort { $a <=> $b } keys %{$designs{$plr}}) {
      push @merged, $designs{$plr}{$slot};
      print "    mergeDesigns: OUTPUT design - player=$plr, slot=$slot\n" if $debug;
    }
  }  
  return @merged;
}

sub extractDesignSlot {
  my ($data_ref) = @_;
  # ishdef is in bits 10-14 of wFlags (bytes 0-1)
  my $wFlags = ($data_ref->[0] & 0xFF) | (($data_ref->[1] & 0xFF) << 8);
  my $ishdef = ($wFlags >> 10) & 0x1F;  # 5 bits (0-31)
  
  # For starbases (slots 16-31), normalize to 0-15
  if ($ishdef >= 16) {
    $ishdef = $ishdef - 16;
  }  
  return $ishdef;
}

sub makeBlockHeader {
# makeBlockHeader - Create a 2-byte block header (chr-encoded)
  my ($typeId, $dataSize) = @_;
  my $header = ($dataSize & 0x3FF) | (($typeId & 0x3F) << 10);
  return (chr($header & 0xFF), chr(($header >> 8) & 0xFF));
}

sub ConvertPlanetToPartial {
# ConvertPlanetToPartial - Convert Block 13 data to Block 14 format
# Sets fFirstYear flag.  Does NOT truncate data (the variable-length
# planet format is complex; setting fFirstYear tells the reader to
# ignore detAll-only fields even if trailing bytes are present).
  my ($data) = @_;  
  # === PARSE Block 13 ===  
  # Header (bytes 0-3)
  my $field1 = ($data->[0] & 0xFF) | (($data->[1] & 0xFF) << 8);
  my $planetId = $field1 & 0x7FF;
  my $ownerId = ($field1 >> 11) & 0x1F;
  
  my $flags = ($data->[2] & 0xFF) | (($data->[3] & 0xFF) << 8);
  my $det = $flags & 0x7F;
  my $fHomeworld = ($flags >> 7) & 0x01;
  my $fInclude = ($flags >> 8) & 0x01;
  my $fStarbase = ($flags >> 9) & 0x01;  my $fIncEVO = ($flags >> 10) & 0x01;
  my $fIncImp = ($flags >> 11) & 0x01;
  my $fIncSurfMin = ($flags >> 13) & 0x01;  
  my $isOccupied = ($ownerId != 31);
   
  my $offset = 4;  # Variable data starting at offset 4
  
  my $bitmask = $data->[$offset++]; # Bitmask for rgpctMinLevel
  
  my @rgpctMinLevel;  # rgpctMinLevel[3] - variable length
  for (my $i = 0; $i < 3; $i++) {
    my $bits = ($bitmask >> ($i * 2)) & 0x03;
    if ($bits & 0x01) {
      $rgpctMinLevel[$i] = $data->[$offset++];
    } else {
      $rgpctMinLevel[$i] = 0;
    }
  }
   
  my @rgMinConc; # rgMinConc[3] - 3 bytes
  for (my $i = 0; $i < 3; $i++) {
    $rgMinConc[$i] = $data->[$offset++];
  }
   
  my @rgEnvVar; # rgEnvVar[3] - 3 bytes
  for (my $i = 0; $i < 3; $i++) {
    $rgEnvVar[$i] = $data->[$offset++];
  }
    
  my @rgEnvVarOrig; # rgEnvVarOrig[3] - 3 bytes if fIncEVO
  if ($fIncEVO) {
    for (my $i = 0; $i < 3; $i++) {
      $rgEnvVarOrig[$i] = $data->[$offset++];
    }
  } else {
    @rgEnvVarOrig = @rgEnvVar;  # Use current values
  }
    
  my $uGuesses = 0; # uGuesses - 2 bytes if occupied
  if ($isOccupied) {
    $uGuesses = ($data->[$offset] & 0xFF) | (($data->[$offset+1] & 0xFF) << 8);
    $offset += 2;
  }
  
  # Surface minerals - only if det > detSome (i.e., det >= 4)
  my @rgwtMin = (0, 0, 0, 0);  # Initialize to 0
  if ($det > 3 && $fIncSurfMin) {
    # Read surface mineral bitmask
    my $minBitmask = $data->[$offset++];
    
    # Parse variable mineral data for 4 minerals (not 5 - no fuel for detMore)
    for (my $i = 0; $i < 4; $i++) {
      my $bits = ($minBitmask >> ($i * 2)) & 0x03;
      if ($bits == 1) {
        $rgwtMin[$i] = $data->[$offset++];
      } elsif ($bits == 2) {
        $rgwtMin[$i] = ($data->[$offset] & 0xFF) | (($data->[$offset+1] & 0xFF) << 8);
        $offset += 2;
      } elsif ($bits == 3) {
        $rgwtMin[$i] = ($data->[$offset] & 0xFF) | (($data->[$offset+1] & 0xFF) << 8) | 
                       (($data->[$offset+2] & 0xFF) << 16) | (($data->[$offset+3] & 0xFF) << 24);
        $offset += 4;
      }
    }
  }
  
  # Skip rgbImp improvements data (8 bytes) for detAll planets
  if ($fIncImp) {
    $offset += 8;  # sizeof(rgbImp)
  }
  # Starbase design slot (isb) - 1 byte if fStarbase and det <= detMore
  #                            - 4 bytes if fStarbase and det == detAll
  my $isb = 0;
  if ($fStarbase) {
    if ($det >= 7) {
      # detAll: 4 bytes lStarbase
      my $lStarbase = ($data->[$offset] & 0xFF) | (($data->[$offset+1] & 0xFF) << 8) |
                      (($data->[$offset+2] & 0xFF) << 16) | (($data->[$offset+3] & 0xFF) << 24);
      $offset += 4;
      # Extract isb from lStarbase (bits 0-3)
      $isb = $lStarbase & 0x0F;
    } else { 
      # detMore/detSome: 1 byte isb
      $isb = $data->[$offset++];
    }
  }
  
  # === BUILD Block 14 (detMore) ===
  my @output;
  $offset = 0;
  
  # Header (bytes 0-3)
  $output[$offset++] = $field1 & 0xFF;
  $output[$offset++] = ($field1 >> 8) & 0xFF;
  
  # Determine if we need fIncEVO in output
  my $need_fIncEVO = 0;
  for (my $i = 0; $i < 3; $i++) {
    if ($rgEnvVar[$i] != $rgEnvVarOrig[$i]) {
      $need_fIncEVO = 1;
      last;
    }
  }
  
  # Determine if we need fIncSurfMin (any minerals present)
  my $need_fIncSurfMin = 0;
  for (my $i = 0; $i < 4; $i++) {
    if ($rgwtMin[$i] > 0) {
      $need_fIncSurfMin = 1;
      last;
    }
  }
  
  # Build flags: det=4, fFirstYear=1, preserve fStarbase/fHomeworld
  my $outFlags = 4;  # det=4 (detMore)
  $outFlags |= 0x8000;  # fFirstYear=1
  $outFlags |= ($fHomeworld << 7);
  $outFlags |= (1 << 8);              # fInclude - always set for visible planets
  $outFlags |= ($fStarbase << 9);
  $outFlags |= ($need_fIncEVO << 10);
  $outFlags |= ($need_fIncSurfMin << 13);
  
  $output[$offset++] = $outFlags & 0xFF;
  $output[$offset++] = ($outFlags >> 8) & 0xFF;
  
  # Build bitmask for rgpctMinLevel (only if values > 0)
  my $outBitmask = 0;
  for (my $i = 0; $i < 3; $i++) {
    if ($rgpctMinLevel[$i] > 0) {
      $outBitmask |= (1 << ($i * 2));
    }
  }
  $output[$offset++] = $outBitmask;
  
  # Write rgpctMinLevel values (only non-zero)
  for (my $i = 0; $i < 3; $i++) {
    if ($rgpctMinLevel[$i] > 0) {
      $output[$offset++] = $rgpctMinLevel[$i];
    }
  }
  
  # Write rgMinConc[3]
  for (my $i = 0; $i < 3; $i++) {
    $output[$offset++] = $rgMinConc[$i];
  }
  
  # Write rgEnvVar[3]
  for (my $i = 0; $i < 3; $i++) {
    $output[$offset++] = $rgEnvVar[$i];
  }
  
  # Write rgEnvVarOrig[3] if needed
  if ($need_fIncEVO) {
    for (my $i = 0; $i < 3; $i++) {
      $output[$offset++] = $rgEnvVarOrig[$i];
    }
  }
  
  # Write uGuesses if occupied
  if ($isOccupied) {
    $output[$offset++] = $uGuesses & 0xFF;
    $output[$offset++] = ($uGuesses >> 8) & 0xFF;
  }
  
  # Write surface minerals if present (detMore addition)
  if ($need_fIncSurfMin) {
    # Build mineral bitmask
    my $minBitmask = 0;
    for (my $i = 0; $i < 4; $i++) { # BUG: AI sais this should be 3
      my $val = $rgwtMin[$i];
      my $bits = 0;
      if ($val > 0) {
        if ($val <= 255) {
          $bits = 1;  # byte
        } elsif ($val <= 65535) {
          $bits = 2;  # short
        } else {
          $bits = 3;  # long
        }
      }
      $minBitmask |= ($bits << ($i * 2));
    }
    
    $output[$offset++] = $minBitmask;
    
    # Write mineral values
    for (my $i = 0; $i < 4; $i++) {  # BUG: AI says this should be 3
      my $val = $rgwtMin[$i];
      if ($val > 0) {
        if ($val <= 255) {
          $output[$offset++] = $val & 0xFF;
        } elsif ($val <= 65535) {
          $output[$offset++] = $val & 0xFF;
          $output[$offset++] = ($val >> 8) & 0xFF;
        } else {
          $output[$offset++] = $val & 0xFF;
          $output[$offset++] = ($val >> 8) & 0xFF;
          $output[$offset++] = ($val >> 16) & 0xFF;
          $output[$offset++] = ($val >> 24) & 0xFF;
        }
      }
    }
  }
  # Write starbase design slot if present
  if ($fStarbase) {
    print "  ConvertPlanetToPartial: Writing starbase - planetId=$planetId, ownerId=$ownerId, isb=$isb\n" if $debug;
    $output[$offset++] = $isb;
  }
  return \@output;
}

sub convertFleetToPartial {
# convertFleetToPartial - Convert Block 16 data to Block 17 format
# FLEETSOME is the first 12 bytes of FLEET:
#   bytes 0-1: id union (ifl:9, iplr:4, junk:3)
#   bytes 2-3: iPlayer
#   bytes 4-5: flags (det:8, fInclude:1, fRepOrders:1, fDead:1, ...)
#   bytes 6-7: idPlanet
#   bytes 8-11: pt (POINT: x, y)
  my ($data) = @_;
  # === PARSE Block 16 ===
  # FLEETSOME header (12 bytes)
  my $id = ($data->[0] & 0xFF) | (($data->[1] & 0xFF) << 8);
  my $iPlayer = ($data->[2] & 0xFF) | (($data->[3] & 0xFF) << 8);
  my $flags = ($data->[4] & 0xFF) | (($data->[5] & 0xFF) << 8);
  my $idPlanet = ($data->[6] & 0xFF) | (($data->[7] & 0xFF) << 8);
  my $ptX = ($data->[8] & 0xFF) | (($data->[9] & 0xFF) << 8);
  my $ptY = ($data->[10] & 0xFF) | (($data->[11] & 0xFF) << 8);
  
  my $fByteCsh = ($flags >> 11) & 0x01;
  
  # Ship count bitmask (2 bytes after header)
  my $bitmask = ($data->[12] & 0xFF) | (($data->[13] & 0xFF) << 8);
  
  # Parse ship counts
  my @rgcsh;
  my $offset = 14;
  for (my $i = 0; $i < 16; $i++) {
    if ($bitmask & (1 << $i)) {
      if ($fByteCsh) {
        $rgcsh[$i] = $data->[$offset++];
      } else {
        $rgcsh[$i] = ($data->[$offset] & 0xFF) | (($data->[$offset+1] & 0xFF) << 8);
        $offset += 2;
      }
    } else {
      $rgcsh[$i] = 0;
    }
  }
  
  # For Block 16 (detAll), next would be cargo minerals
  # We need to skip those and find dirLong if it exists
  # For simplicity, calculate dirLong from fleet position
  # dirLong encodes direction as (dirX, dirY, warp, flags)
  
  my $dirLong = 0x1000;  # Default: some valid direction
  
  # Calculate total weight from ship counts
  # We don't have ship designs loaded, so approximate as 0
  my $wt = 0;
  
  # === BUILD Block 17 (detSome) ===
  my @output;
  $offset = 0;
  
  # FLEETSOME header (12 bytes) with det=3
  $output[$offset++] = $id & 0xFF;
  $output[$offset++] = ($id >> 8) & 0xFF;
  $output[$offset++] = $iPlayer & 0xFF;
  $output[$offset++] = ($iPlayer >> 8) & 0xFF;
  
  # Flags: det=3, keep fInclude, fRepOrders, fDead, set fByteCsh
  my $outFlags = 3;  # det=3
  $outFlags |= ($flags & 0x0700);  # Keep fInclude, fRepOrders, fDead
  $outFlags |= ($fByteCsh << 11);  # fByteCsh
  
  $output[$offset++] = $outFlags & 0xFF;
  $output[$offset++] = ($outFlags >> 8) & 0xFF;
  $output[$offset++] = $idPlanet & 0xFF;
  $output[$offset++] = ($idPlanet >> 8) & 0xFF;
  $output[$offset++] = $ptX & 0xFF;
  $output[$offset++] = ($ptX >> 8) & 0xFF;
  $output[$offset++] = $ptY & 0xFF;
  $output[$offset++] = ($ptY >> 8) & 0xFF;
  
  # Ship count bitmask
  $output[$offset++] = $bitmask & 0xFF;
  $output[$offset++] = ($bitmask >> 8) & 0xFF;
  
  # Write ship counts
  for (my $i = 0; $i < 16; $i++) {
    if ($rgcsh[$i] > 0) {
      if ($fByteCsh) {
        $output[$offset++] = $rgcsh[$i] & 0xFF;
      } else {
        $output[$offset++] = $rgcsh[$i] & 0xFF;
        $output[$offset++] = ($rgcsh[$i] >> 8) & 0xFF;
      }
    }
  }
  
  # Write dirLong (4 bytes)
  $output[$offset++] = $dirLong & 0xFF;
  $output[$offset++] = ($dirLong >> 8) & 0xFF;
  $output[$offset++] = ($dirLong >> 16) & 0xFF;
  $output[$offset++] = ($dirLong >> 24) & 0xFF;
  
  # Write wt (4 bytes)
  $output[$offset++] = $wt & 0xFF;
  $output[$offset++] = ($wt >> 8) & 0xFF;
  $output[$offset++] = ($wt >> 16) & 0xFF;
  $output[$offset++] = ($wt >> 24) & 0xFF;
  
  return \@output;
}

sub mergeObjects {
# mergeObjects - Merge P1 and P2 object arrays by ID
# Objects with same ID: P1 wins (more recent/detailed)
# Objects only in P2: add them
# Order by object ID
  my ($p1_objects, $p2_objects) = @_;
  
  # Index P1 objects by ID
  my %p1_by_id;
  for my $rec (@$p1_objects) {
    my $objId = $rec->[1];
    $p1_by_id{$objId} = $rec;
  }
  
  # Add P2 objects that aren't in P1
  for my $rec (@$p2_objects) {
    my $objId = $rec->[1];
    if (!exists $p1_by_id{$objId}) {
      $p1_by_id{$objId} = $rec;
      print "    mergeObjects: added P2 object id=$objId\n" if $debug;
    }
  }   
  return sort { $a->[1] <=> $b->[1] } values %p1_by_id; # Return sorted by ID
}

sub mergeScores {
# mergeScores - Merge P1 and P2 score arrays by player ID
# Scores with same player: P1 wins (might be more current)
# Scores only in P2: add them
# Order by player ID
  my ($p1_scores, $p2_scores) = @_;
  
  # Index P1 scores by player ID
  my %p1_by_player;
  for my $rec (@$p1_scores) {
    my $playerId = $rec->[1];
    $p1_by_player{$playerId} = $rec;
  }
  
  # Add P2 scores that aren't in P1
  for my $rec (@$p2_scores) {
    my $playerId = $rec->[1];
    if (!exists $p1_by_player{$playerId}) {
      $p1_by_player{$playerId} = $rec;
      print "    mergeScores: added P2 score for player $playerId\n" if $debug;
    }
  }
  
  # Return sorted by player ID
  return sort { $a->[1] <=> $b->[1] } values %p1_by_player;
}