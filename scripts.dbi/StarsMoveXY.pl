#!/usr/bin/perl
# StarsMove.pl
# Reads planet coordinates from .xy file and updates plnaet and fleet coordinates in .xy, .hst and .m files
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 250206  Version 1.0 - Initial version for moving planets and updating fleet coordinates
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

# Moves planets and updates fleet coordinates
# Example Usage: StarsMoveXY.pl c:\stars\game.xy 1

use strict;
use warnings;   
use FindBin;
use lib $FindBin::Bin;

use File::Basename;
use StarsBlock;

my @planetNames = &planetNames;

my $filename = $ARGV[0]; # input file (.xy)
my $csvMode = $ARGV[1]; # Set to 1 to export CSV, 2 to import and modify

if (!($filename)) { 
  print "\n\nUsage: StarsMoveXY.pl <file.xy> [mode]\n\n";
  print "Please enter the input .xy file. Example: \n";
  print "  StarsMoveXY.pl c:\\games\\test.xy\n\n";
  print "With no mode parameter: displays planet coordinates.\n";
  print "Add a 2nd command-line parameter of 1 to export coordinates to CSV.\n";
  print "Add a 2nd command-line parameter of 2 to import CSV and update all related files.\n";
  print "\nMode 2 will update:\n";
  print "  - Planet coordinates in .xy file\n";
  print "  - Fleet coordinates in .hst file\n";
  print "  - Fleet coordinates in all .m files\n";
  print "  - Check for wormhole collisions\n";
  print "\nAll output files will have _mv suffix (e.g., game_mv.xy)\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $ext);
$basefile = basename($filename);
$dir  = dirname($filename);
($ext) = $basefile =~ /(\.[^.]+)$/;

unless ($ext =~ /xy/i) { # Validate it's a .xy file
  print "Error: Input file must be the .xy file!\n"; 
  exit; 
}

my $coords_ref;

# Discover related files
my ($hst_file, @m_files) = &discover_game_files($filename);

if ($csvMode && $csvMode == 1) { # Process based on mode
  # Mode 1: Export planet coordinates from .xy file
  my (undef, undef, $planet_coords) = &process_xy_file($filename, undef, 1);
  my ($base, $dir) = fileparse($filename, qr/\.[^.]*/);
  &print_homeworlds($hst_file, $planet_coords);
  my $csv_filename = $filename;
  $csv_filename =~ s/\.[^.]+$/_coords.csv/;
  print "Mode 1: Exporting planet coordinates to CSV\n";
  print "Coordinates exported to: $csv_filename\n";

} elsif ($csvMode && $csvMode == 2) {
  # Mode 2: Import CSV and update all files
  print "Mode 2: Importing CSV and updating all game files\n";
    
  # Process .xy file first to get coordinate mapping
  print "Processing .xy file...\n";
  my ($xy_outBytes, $coord_mapping) = &process_xy_file($filename, undef, 2);
  
  if (!$coord_mapping || !%{$coord_mapping}) {
    die "Error: No coordinate mapping created from CSV!\n";
  }
  
  print "Coordinate mapping loaded: " . scalar(keys %{$coord_mapping}) . " planets to update\n";
  
  # Check for wormhole collisions in .hst file only
  print "Checking for wormhole collisions...\n";
  my @collision_warnings = &check_wormhole_collisions($hst_file, $coord_mapping);
  
  if (@collision_warnings) {
    print "*** ERROR: Wormhole collision(s) detected! ***\n";
    foreach my $warning (@collision_warnings) {
      print "  $warning\n";
    }
    die "Aborting: Cannot proceed with wormhole collisions.\n";
  }
  print "No collisions detected.\n";
  
  if ($xy_outBytes) {  # Write updated .xy file
    print "Processing $filename...\n";
    my $xy_output = $filename;
    $xy_output =~ s/(\.[^.]+)$/_mv$1/;
    &write_output_file($xy_output, $xy_outBytes);
  }
  
  print "Processing $hst_file...\n";   # Process .hst file
  my $hst_outBytes = &process_fleet_file($hst_file, $coord_mapping);
  if ($hst_outBytes) {
    my $hst_output = $hst_file;
    $hst_output =~ s/(\.[^.]+)$/_mv$1/;
    &write_output_file($hst_output, $hst_outBytes);
  }
    
  foreach my $m_file (@m_files) { # Process all .m files
    print "\nProcessing $m_file...\n";
    my $m_outBytes = &process_fleet_file($m_file, $coord_mapping);
    if ($m_outBytes) {
      my $m_output = $m_file;
      $m_output =~ s/(\.[^.]+)$/_mv$1/;
      &write_output_file($m_output, $m_outBytes);
    }
  }  
  print "\n=== All files updated successfully ===\n";
  print "Updated files have _mv suffix\n"; 
} else {
  # Mode 0: Display planet information (default)
  my (undef, undef, $planet_coords) = &process_xy_file($filename, undef, 0);
  &print_homeworlds($hst_file, $planet_coords);
}

sub discover_game_files { ### Discover related game files (.hst and .m*)
  my ($xy_file) = @_;
  my ($base, $dir, $ext) = fileparse($xy_file, qr/\.[^.]*/);
  
  my $hst_file = "$dir$base.hst";
  my @m_files;
  
  # Find all .m files (m1, m2, etc.)
  for (my $i = 1; $i <= 16; $i++) {
    my $m_file = "$dir$base.m$i";
    if (-e $m_file) {
      push @m_files, $m_file;
    }
  }
  
  print "Discovered files:\n";  
  unless ($hst_file && -e $hst_file) {   # Check that .hst file exists
    die "ERROR: .hst file not found: $hst_file\n";
  }   
  unless (@m_files) {  # Check that at least one .m file exists
    die "ERROR: No .m files found\n";
  }  
  print "  HST: $hst_file\n";
  print "  M files:\n";
  foreach my $mf (@m_files) {
    print "    $mf\n";
  }
  print "\n";
  return ($hst_file, @m_files);
}

sub check_wormhole_collisions { ### Check for wormhole collisions (.hst file only)
  my ($hst_file, $coord_mapping) = @_;
  my @warnings;
  my %wormholes; # Store all wormhole positions
  
  # Collect all new planet positions
  my %new_planet_positions;
  foreach my $old_key (keys %{$coord_mapping}) {
    my ($newX, $newY) = @{$coord_mapping->{$old_key}};
    my $new_key = "$newX,$newY";
    $new_planet_positions{$new_key} = 1;
  }
    
  
  # %wormholes = &scan_for_wormholes($hst_file);  # Check HST file for wormholes
  my ($homeworlds, $wormholes_ref) = &scan_hst_file($hst_file); # Check HST file for wormholes
  %wormholes = %{$wormholes_ref};
  
  # Check for collisions
  foreach my $wh_key (keys %wormholes) {
    if (exists $new_planet_positions{$wh_key}) {
      push @warnings, "Wormhole at $wh_key conflicts with new planet position";
    }
  }  
  return @warnings;
}


sub process_xy_file { ### Process .xy file (mode 0=display, 1=export, 2=import)
  my ($file, $coords_ref, $mode) = @_;  
  my @fileBytes;
  open my $fh, '<', $file or die "Cannot open $file: $!";
  binmode($fh);
  my $FileValues;
  while (read($fh, $FileValues, 1)) { push @fileBytes, $FileValues; }
  close($fh);
  my ($outBytes, $coord_mapping, $planet_coords) = &decryptBlockXY(\@fileBytes, $coords_ref, $mode, $file);
  return ($outBytes, $coord_mapping, $planet_coords);}

sub process_fleet_file { ### Process fleet file (.hst or .m)
  my ($file, $coord_mapping) = @_;  
  my @fileBytes;
  open my $fh, '<', $file or die "Cannot open $file: $!";
  binmode($fh);
  my $FileValues;
  while (read($fh, $FileValues, 1)) { push @fileBytes, $FileValues; }
  close($fh);  
  my $outBytes = &decryptBlockFleet(\@fileBytes, $coord_mapping);  
  return $outBytes;
}

sub write_output_file { ### Write output file
  my ($filename, $outBytes_ref) = @_;
  my @outBytes = @{$outBytes_ref};
  # write file
  open (my $OutFile, '>:raw', $filename) or die "Cannot create output file $filename: $!";
  for (my $i = 0; $i < @outBytes; $i++) {
    print $OutFile $outBytes[$i];
  }
  close($OutFile);
}

sub decryptBlockXY {  ### Decrypt and process .xy file blocks
  my ($fileBytes_ref, $coords_ref, $mode, $xy_filename) = @_;
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
  my %GameValues;
  my %coord_mapping; # Maps "oldX,oldY" -> [newX, newY]
  my @planet_coords; # Collected in mode 1 for CSV export and homeworld lookup
    
  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    @block = @fileBytes[$offset .. $offset+(2+$size)-1];
    
    if ($typeId == 8) {
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ($seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA;
      $seedY = $seedB;
      
      # Validate that this is a new game (turn 0) when in export or modify mode
      if (($mode == 1 || $mode == 2) && $turn > 0) {
        my $game_year = $turn + 2400;
        my $mode_name = $mode == 1 ? "export" : "modify";
        die "\nERROR: Cannot $mode_name planet coordinates for games in progress.\n" .
            "       The current game year is $game_year. StarsMove will only work on new games (year 2400).\n\n";
      }
      push @outBytes, @block;
      
    } elsif ($typeId == 0) { ### FileFooterBlock
      push @outBytes, @block;
    } else {
      my @data = @block[2..$#block];
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB);
      @decryptedData = @{$decryptedData};
      
      my @planetBytes;
      my @new_planetBytes;
      
      if ($typeId == 7) { # Planet block - process coordinates        
        $GameValues{'UniverseId'} = &read32(\@decryptedData, 0);
        my $mdSize = &read16(\@decryptedData, 4);
        $GameValues{'GalaxyXY'} = ($mdSize * 400) + 400;
        $GameValues{'NumPlanets'} = &read16(\@decryptedData, 10);
        $GameValues{'turn'} = &read16(\@decryptedData, 18);
               
        if ($mode == 2 && !$coords_ref) {  # Load CSV if in import mode
          my $csv_filename = $xy_filename;
          $csv_filename =~ s/\.[^.]+$/_coords.csv/;
          
          unless (-e $csv_filename) { die "CSV file $csv_filename does not exist!\n";  }
          
          $coords_ref = &read_coords_csv($csv_filename, $GameValues{'GalaxyXY'});
          print "Loaded coordinates from: $csv_filename\n";
        }
        
        # Process planet coordinates
        # Planet bytes follow Block 7's encrypted data as unencrypted trailing data
        my $index = $offset + 2 + $size;  # Past Block 7 header + encrypted data
        my $read_x = 1000;
        my $write_x = 1000;
        my $planetId = 1;
        my $end_index = $index + $GameValues{'NumPlanets'} * 4;
        
        # Extract planet bytes as raw characters (NOT converted to numbers)
        @planetBytes = @fileBytes[$index .. $end_index-1];
        
        for (my $i = $index; $i < $end_index; $i+=4) {
          # Read bytes and convert to number for this record only
          my $b0 = ord($fileBytes[$i]);
          my $b1 = ord($fileBytes[$i+1]);
          my $b2 = ord($fileBytes[$i+2]);
          my $b3 = ord($fileBytes[$i+3]);
          my $record = $b0 | ($b1 << 8) | ($b2 << 16) | ($b3 << 24);
          my $name_id = ($record >> 22) & 0x3FF;
          my $x_coord = ($record & 0x3FF) + $read_x;
          $read_x = $x_coord;
          my $y_coord = ($record >> 10) & 0xFFF;
          my $planetName = $planetNames[$name_id];
          
          # Display for mode 0
          if ($mode == 0) {  print "Planet ID: $planetId, Name: $planetNames[$name_id], x: $x_coord, y: $y_coord\n"; }
          
          if ($mode == 0 || $mode == 1) {
            push @planet_coords, {
              id => $planetId,
              name => $planetName,
              x => $x_coord,
              y => $y_coord,
              newX => $x_coord,
              newY => $y_coord
            };
          }
          
          if ($mode == 2 && $coords_ref) { # Import mode
            my $new_x;
            my $new_y;
            
            if ($coords_ref->{$planetId}) {
              $new_x = $coords_ref->{$planetId}{newX};
              $new_y = $coords_ref->{$planetId}{newY};
              
              # Build coordinate mapping for fleet updates
              my $old_key = "$x_coord,$y_coord";
              $coord_mapping{$old_key} = [$new_x, $new_y];
            } else {
              $new_x = $x_coord;
              $new_y = $y_coord;
            }
            
            my $x_delta = $new_x - $write_x;
                        
            if ($x_delta < 0) { # Validate that X delta is non-negative (X must not decrease)
              die "\nERROR: Invalid planet coordinates in CSV.\n" .
                "       Planet $planetId has X=$new_x, but the previous planet has X=$write_x.\n" .
                "       Planet X coordinates must be non-decreasing (each planet's X >= previous planet's X).\n" .
                "       This is required by Stars! delta-encoding format.\n\n";
            }           
            
            if ($x_delta > 1023) { # Validate that X delta fits in 10 bits (0-1023)
              die "\nERROR: X coordinate delta too large.\n" .
                "       Planet $planetId: X delta = $x_delta (max is 1023).\n" .
                "       Planets must be closer together in X coordinate.\n\n";
            }
            
            $write_x = $new_x;
            my $new_record = ($name_id << 22) | ($new_y << 10) | ($x_delta & 0x3FF);
            
            push @new_planetBytes, chr(($new_record) & 0xFF);
            push @new_planetBytes, chr(($new_record >> 8) & 0xFF);
            push @new_planetBytes, chr(($new_record >> 16) & 0xFF);
            push @new_planetBytes, chr(($new_record >> 24) & 0xFF);
          }
          $planetId++;
        }
        
        # Validate CSV entries 
        if ($mode == 2 && $coords_ref) {
          my $numPlanets = $GameValues{'NumPlanets'};
          
          # Warn about CSV entries with planet IDs outside valid range
          foreach my $csvId (keys %$coords_ref) {
            unless ($csvId >= 1 && $csvId <= $numPlanets) { warn "WARNING: CSV contains planet ID $csvId which is outside valid range (1-$numPlanets)\n"; }
          }
          
          # Warn if CSV doesn't cover all planets
          my $csv_count = scalar(keys %$coords_ref);
          if ($csv_count != $numPlanets) { print "NOTE: CSV has $csv_count entries but game has $numPlanets planets. Unchanged planets will keep original coordinates.\n"; }
        }
        
        # Export CSV
        if ($mode == 1 && @planet_coords) {
          my $csv_filename = $xy_filename;
          $csv_filename =~ s/\.[^.]+$/_coords.csv/;
          
          open my $CSV, '>', $csv_filename or die "Cannot create CSV file $csv_filename: $!";
          print $CSV "PlanetID,Name,X,Y,newX,newY\n";
          
          foreach my $planet (@planet_coords) {
            print $CSV "$planet->{id},$planet->{name},$planet->{x},$planet->{y},$planet->{newX},$planet->{newY}\n";
          }
          close $CSV;
        }
      }
      
      # Re-encrypt all encrypted blocks (including Block 7)
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @{$encryptedBlock};
      push @outBytes, @encryptedBlock;
      
      # CRITICAL: Sync decryption seeds for next block
      $seedA = $seedX;
      $seedB = $seedY;
      
      # Offset advancement - special handling for Block 7
      if ($typeId == 7) {
        # Write planet bytes (unencrypted trailing data after Block 7)
        if (@new_planetBytes) { push @outBytes, @new_planetBytes;
        } else {  push @outBytes, @planetBytes; }
        # Advance offset past header + encrypted data + planet bytes
        $offset = $offset + (2 + $size + ($GameValues{'NumPlanets'} * 4));
      } else {  $offset = $offset + (2 + $size); }# For other encrypted blocks, advance past header + data
    }
    
    # For blocks 8 and 0 that didn't go through decryption
    if ($typeId == 8 || $typeId == 0) {
      $offset = $offset + (2 + $size);
    }
  }  
  return (\@outBytes, \%coord_mapping, \@planet_coords);
}

################################################################
sub decryptBlockFleet { # Decrypt and process fleet blocks in .hst or .m files
  my ($fileBytes_ref, $coord_mapping) = @_;
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
  my $fleets_updated = 0;
  my $ownerId; 
  my $fleetId; #needs to persist so it's available for follow-on Blocks 19 & 20
  my $waypointId = 0; # value is implicit as it's the order the waypoints appear after the fleet block
  
  while ($offset < @fileBytes) {
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    @block = @fileBytes[$offset .. $offset+(2+$size)-1];
    
    if ($typeId == 8) { #FileHeaderBlock
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ($seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA;
      $seedY = $seedB;
      
      # Validate that this is a new game (turn 0)
      if ($turn > 0) {
        my $game_year = $turn + 2400;
        die "\nERROR: Cannot modify fleet coordinates for games in progress.\n" .
          "       The current game year is $game_year (turn $turn).\n" .
          "       StarsMoveXY will only modify new games (year 2400, turn 1).\n\n";
      }      
      push @outBytes, @block;      
    } elsif ($typeId == 0) { # FileFooterBlock
      push @outBytes, @block;      
    } else {
      my @data = @block[2..$#block];
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB);
      @decryptedData = @{$decryptedData};
            
      if ($typeId == 16 || $typeId == 17) { # Check for fleet blocks (16 and 17)
        $waypointId = 0; # reset the waypoint Id for a new fleet
        # Extract fleet ID and owner ID
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $ownerId = ($decryptedData[1] >> 1) & 0x0F;  # iplr: 4 bits per struct.h _fleetid
        
        # Fleet coordinates are at bytes 8 and 10
        my $fleet_x = &read16(\@decryptedData, 8);
        my $fleet_y = &read16(\@decryptedData, 10);
        my $old_key = "$fleet_x,$fleet_y";
        
        if (exists $coord_mapping->{$old_key}) {
          my ($new_x, $new_y) = @{$coord_mapping->{$old_key}};
          # Only update if coordinates actually changed
          if ($new_x != $fleet_x || $new_y != $fleet_y) {
            # Update coordinates in decrypted data
            $decryptedData[8] = $new_x & 0xFF;
            $decryptedData[9] = ($new_x >> 8) & 0xFF;
            $decryptedData[10] = $new_y & 0xFF;
            $decryptedData[11] = ($new_y >> 8) & 0xFF;
            
            $fleets_updated++;
            print "  Fleet #$fleetId (Player $ownerId) updated: ($fleet_x,$fleet_y) -> ($new_x,$new_y)\n";
          }
        }
      } elsif ($typeId == 19 || $typeId == 20) { # waypoint block 20 in .m/.hst files. 8 Bytes
        #define rtOrderA        19  // Turn   Zero or more follow an rtShipA or rtFleetA
        #define rtOrderB        20  // Turn   Same as an rtOrder but w/o Task structure
        # We'll never have WP 20 (.m/.hst) && WP 28/29 (.x)
        # Fleet ID and waypoint number need to be tracked separately
        # since they're not in this block, although they're always in the preceding fleet block 16
        # Additional waypoints are stored immediately thereafter as Block 19s or 20s

        my ($waypoint_x, $waypoint_y, $targetId, $warp, $taskId, $targetType, $validTask, $noAutoTrack);
        my %waypoint; # to store waypoints in a hash
        my $playerId = $Player; # from last pass of fleet block
        
 			  $waypoint_x = &read16(\@decryptedData, 0);  
        $waypoint_y = &read16(\@decryptedData, 2);
        $targetId = &read16(\@decryptedData, 4);    
        $warp = ($decryptedData[6] >> 4) & 0x0F;       # Bits 4-7 of byte 6
        $taskId = $decryptedData[6] & 0x0F;            # Bits 0-3 of byte 6
        $targetType = $decryptedData[7] & 0x0F;        # grobj (bits 0-3) 0-Unknown, 1-planet, 2-fleet, 4-deep space, 8-wormhole/trader/minefield/salvage
        $validTask = ($decryptedData[7] >> 4) & 0x01;  # fValidTask (bit 4)
        $noAutoTrack = ($decryptedData[7] >> 5) & 0x01;# fNoAutoTrack (bit 5)
        
        # Store basic waypoint data
        %waypoint = (
          x => $waypoint_x,
          y => $waypoint_y,
          targetId => $targetId,
          warp => $warp,
          taskId => $taskId,
          targetType => $targetType,
          validTask => $validTask,
          noAutoTrack => $noAutoTrack,
        );

        if ( $typeId == 19) { # waypoint task orders          
          #define grTaskNone      0
          #define grTaskNil       0
          #define grTaskXPort     1
          #define grTaskColonize	2
          #define grTaskMine      3
          #define grTaskMerge     4
          #define grTaskRecycle   5
          #define grTaskLayMines  6
          #define grTaskPatrol    7
          #define grTaskRoute     8
          #define grTaskSell      9
          #define grTaskMax      10
          # Read task-specific data based on taskId
          if ($validTask && $taskId != 0) {
            if ($taskId == 1) {
              my @transport = ();
              for (my $i = 0; $i < 5; $i++) {
                my $offset = 12 + ($i * 2);
                my $itemaction = &read16(\@decryptedData, $offset);
                my $quantity = $itemaction & 0x0FFF;        # bits 0-11
                my $action = ($itemaction >> 12) & 0x0F;    # bits 12-15
                
                push @transport, {
                  quantity => $quantity,
                  action => $action,
                  # Mineral types: 0=Ironium, 1=Boranium, 2=Germanium, 3=Colonists, 4=Fuel
                  type => $i,
                };
              }
              $waypoint{transport} = \@transport;
            }
            elsif ($taskId == 6) { # Read TASKLAYMINES at offset 12
              $waypoint{mineTime} = &read16(\@decryptedData, 8);
              $waypoint{mineTimeOld} = &read16(\@decryptedData, 10);
            }
            elsif ($taskId == 7) { # Read TASKPATROL at offset 12
              $waypoint{patrolWarp} = &read16(\@decryptedData, 8);
              $waypoint{patrolDist} = &read16(\@decryptedData, 10);
            }
            elsif ($taskId == 9) { # Read TASKSELL at offset 12
              $waypoint{sellToPlayer} = &read16(\@decryptedData, 8);
            }
          }
        }

        # Store task waypoint data
        %waypoint = (
          warp => $warp,
          taskId => $taskId,
          targetType => $targetType,
          validTask => $validTask,
          noAutoTrack => $noAutoTrack,
        );
        $waypoint{$ownerId}{$fleetId}{$waypointId} = { %waypoint };
        
        # Check if waypoint destination needs to be updated
        # Write back out the new waypoint data. 
        my $old_key = "$waypoint_x,$waypoint_y";
        if (exists $coord_mapping->{$old_key}) {
          my ($new_x, $new_y) = @{$coord_mapping->{$old_key}};
          # Only update if coordinates actually changed
          if ($new_x != $waypoint_x || $new_y != $waypoint_y) {
            # Write back out the new waypoint data
            $decryptedData[0] = $new_x & 0xFF;
            $decryptedData[1] = ($new_x >> 8) & 0xFF;
            $decryptedData[2] = $new_y & 0xFF;
            $decryptedData[3] = ($new_y >> 8) & 0xFF;
            print "\tWaypoint #$waypointId (Fleet #$fleetId) updated: ($waypoint_x,$waypoint_y) -> ($new_x,$new_y)\n";
          }
        }
        $waypointId++; # increment the waypoint Id in case there are more waypoints
      }
      
      # Re-encrypt and store
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @{$encryptedBlock};
      push @outBytes, @encryptedBlock;
    }
    
    $offset = $offset + (2 + $size);
  }  
  return \@outBytes;
}

sub read_coords_csv { # Read and validate coordinates from CSV
  my ($csv_file, $galaxy_xy) = @_;
  my %coords;
  my %seen_coords;
  my @errors;
  
  open my $CSV, '<', $csv_file or die "Cannot open CSV file $csv_file: $!";
  my $header = <$CSV>;
  
  my $min_coord = 0;
  my $max_coord = $galaxy_xy + 1000;
  
  while (my $line = <$CSV>) {
    chomp $line;
    my ($planetId, $name, $x, $y, $newX, $newY) = split /,/, $line;
    
    # Validate numeric values
    unless (defined($planetId) && $planetId =~ /^\d+$/) {
      push @errors, "Invalid planet ID: '$planetId' (must be numeric)";
      next;
    }
    unless (defined($newX) && $newX =~ /^\d+$/) {
      push @errors, "Planet $planetId has invalid newX: '$newX' (must be numeric)";
      next;
    }
    unless (defined($newY) && $newY =~ /^\d+$/) {
      push @errors, "Planet $planetId has invalid newY: '$newY' (must be numeric)";
      next;
    }
    
    # Check for duplicates
    my $coord_key = "$newX,$newY";
    if (exists $seen_coords{$coord_key}) {
      push @errors, "Duplicate coordinates found: Planet $planetId and Planet $seen_coords{$coord_key} both at ($newX, $newY)";
    }
    $seen_coords{$coord_key} = $planetId;
    
    # Check range
    if ($newX < $min_coord || $newX > $max_coord) {
      push @errors, "Planet $planetId newX=$newX is out of range ($min_coord to $max_coord)";
    }
    if ($newY < $min_coord || $newY > $max_coord) {
      push @errors, "Planet $planetId newY=$newY is out of range ($min_coord to $max_coord)";
    }
    
    $coords{$planetId} = { newX => $newX, newY => $newY };
  }
  close $CSV;
  
  if (@errors) {
    print "\nValidation errors found in CSV:\n";
    foreach my $error (@errors) {
      print "  ERROR: $error\n";
    }
    die "\nAborting due to validation errors.\n";
  }  
  print "CSV validation passed: No duplicates, all coordinates in range ($min_coord to $max_coord)\n";
  return \%coords;
}

sub print_homeworlds { ### Print homeworld names and coordinates from HST block 6
  my ($hst_file, $planet_coords) = @_;

  # Build planet lookup by ID
  my %planet_by_id;
  for my $p (@{$planet_coords}) {
    $planet_by_id{$p->{id}} = $p;
  }

  my ($homeworlds, $wormholes) = &scan_hst_file($hst_file);
  return unless @{$homeworlds};
  
  print "Homeworlds:\n";
  for my $hw (@{$homeworlds}) {
    my $p = $planet_by_id{ $hw->{planet_id} };
    if ($p) {
      printf "  Player %d: %s (Planet ID %d) at (%d, %d)\n",
        $hw->{player}, $p->{name}, $p->{id}, $p->{x}, $p->{y};
    } else {
      printf "  Player %d: Planet ID %d (not found in .xy)\n",
        $hw->{player}, $hw->{planet_id};
    }
  }
  print "\n";
}

sub scan_hst_file { ### Extract homeworld planet IDs from block 6 in HST file
  my ($hst_file) = @_;
  my @homeworlds;
  my %wormholes;
  my @fileBytes;

  open my $fh, '<', $hst_file or die "Cannot open $hst_file: $!";
  binmode($fh);
  my $FileValues;
  while (read($fh, $FileValues, 1)) { push @fileBytes, $FileValues; }
  close($fh);

  my $offset = 0;
  my ($seedA, $seedB);
  my $player = 0;

  while ($offset < @fileBytes) {
    my $fv = $fileBytes[$offset + 1] . $fileBytes[$offset];
    my ($typeId, $size) = &parseBlock($fv, $offset);
    my @block = @fileBytes[$offset .. $offset+(2+$size)-1];

    if ($typeId == 8) {
      my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti, $dt) = &getFileHeaderBlock(\@block);
      ($seedA, $seedB) = &initDecryption($binSeed, $fShareware, $Player, $turn, $lidGame);

    } elsif ($typeId != 0) {
      my @data = @block[2..$#block];
      my ($decryptedData, $seedA_new, $seedB_new) = &decryptBytes(\@data, $seedA, $seedB);
      $seedA = $seedA_new;
      $seedB = $seedB_new;
      my @d = @{$decryptedData};

      if ($typeId == 6) {
        $player++;
        my $fullDataFlag = $d[6] & 0x04;
        if ($fullDataFlag) {
          my $planet_id = &read16(\@d, 8) + 1;  # Convert 0-based to 1-based
          push @homeworlds, { player => $player, planet_id => $planet_id };        }
      } elsif ($typeId == 43) {  # Object block - wormholes
        if ($size > 2) {
          my $objectId = &read16(\@d, 0);
          my $type = $objectId >> 13;
          if (&isWormhole($type)) {
            my $x = &read16(\@d, 2);
            my $y = &read16(\@d, 4);
            $wormholes{"$x,$y"} = 1;
          }
        }
      }
    }
    $offset = $offset + (2 + $size);
  }
  return (\@homeworlds, \%wormholes);
}

