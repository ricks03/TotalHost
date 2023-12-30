# StarsFix.pl
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191123, 211121 
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
# Return Ship, Fleet, Queue, and Battle block attributes
# Example Usage: StarsFix.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

# An "upgrade" of StarsShip.pl & StarsShipQueue.pl & StarsFleet.pl
# Detects, and mostly can fix and detect fixes of:
# Cheap Colonizer (Design)
# Cheap Starbase (Design & Producton Queue )
# 10th Starbase (Design)
# Starbase Friendly Fire Battle Plan (Battle Plan)
# Space Dock Armor Slot Buffer Overflow (Design)
# Mineral Upload  (Manual Load)
# SS Pop Steal  (Waypoint Change)
# 32k merge     (Waypoint Change or Move/Merge Fleet)                                             
# FreePop (code mostly written but untested as I can't replicte)
#    Testing suggests modifying the .x file and/or the .m file return "unable" on generation.

# The check for Cheap Starbase requires a .queue file to detect the fix.
# Mineral Upload requires a .fleet file for fleet cargo capacity.

use strict;
use warnings;  
#use warnings::unused; 
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
use StarStat; # A Perl module for TotalHost

my $debug = 1;
my $fixFiles = 2; # 0, 1: display, 2:write 

#########################################        
my $filename = $ARGV[0]; # input file
my $outFileName = $ARGV[1];
if (!($filename)) { 
  print "\n\nUsage: StarsFix.pl <input file>\n\n";
  print "Please enter the input file (.X|.M|.HST). Example: \n";
  print "  StarsFix.pl c:\\games\\test.hst\n\n";
  print "Lists block data and can fix (or warn) for detected bug/exploits:\n";
  print "   Colonizer Module remaining when removed (.X|.M|.HST)\n";
  print "   Space Dock overflow (.X|.M|.HST)\n";
  print "   Player with 10th starbase (.X|.M|.HST) (requires .HST pass creating .last for .X)\n";
  print "   Friendly Fire (.X|.M|.HST)\n";
  print "   SS Pop Steal (.X)\n";
  print "   Cheap Starbase (.X) (requires .HST pass creating .queue for .X)\n";
  print "   Mineral Upload (requires .HST pass creating .fleet for .X)\n";
  print "   32k Merge (requires .HST pass creating .fleet for .X)\n";
#  print "   FreePop (requires .HST pass creating .fleet for .X)\n";
  print "\nBy default, a new file will be created if fixed: <filename>.fixed\n\n";
  print "You can create a different file with StarsFix.pl <filename> <newfilename>\n";
  print "  StarsFix.pl <filename> <filename> will overwrite the original file.\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

# for d:\th\games\mygamename\mygamename.m1
my $basefile = basename($filename);    # mygamename.m1
my $gameDir  = dirname($filename);         # d:\th\games\gamename
my ($gameName, $file_player, $file_type, $file_ext) = &FileData ($basefile); 
my $listPrefix =  $gameDir . '\\' . $gameName;

# Get the year of the file
my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($filename);

my %warning; # tracking warnings.

# read Production queue data from export
my %queueList;
if (-e "$listPrefix.HST.queue" ) { 
  my $queueList = &readList("$listPrefix.HST.queue");
  %queueList = %$queueList;
#  &printList(\%queueList);
} else { print "No production queue file detected. Cannot detect production queue exploits\n"; }

# Read Ship Design data from export
my %designList;
if (-e "$listPrefix.HST.design") {
  my $designList = &readList("$listPrefix.HST.design");
  %designList = %$designList;
  #&printList(\%designList);
} else { print "No ship designs file detected.\n"; }

# Read Fleet data from export for: 32k bug, Mineral Upload exploit
my %fleetList;
if (-e "$listPrefix.HST.fleet" ) {
  my $fleetList = &readList("$listPrefix.HST.fleet");
  %fleetList = %$fleetList;
#  &printList(\%fleetList);
} else { print "No fleet file detected. Cannot detect SS Pop Steal and Mineral Upload exploits\n"; }

# Read waypoint data
my %waypointList;
if (-e "$listPrefix.HST.waypoint" ) {
  my $waypointList = &readList("$listPrefix.HST.waypoint");
  %waypointList = %$waypointList;
#  &printList(\%fleetList);
} else { print "No waypoint file detected.\n"; }

# read lastPlayer
my $lastPlayer = -1; # storing the last player # for 10th Starbase
if (-e "$listPrefix.HST.last" && $file_type =~ /x/i) {
  open (LISTFILE,"$listPrefix.HST.last");
  my @lastFile = <LISTFILE>;
  close LISTFILE;
  foreach my $line (@lastFile) {
      chomp($line); 
      $lastPlayer = $line;
  }
}

##############################################
# Read in the binary Stars! file, byte by byte
my $FileValues;
my @fileBytes;
open(STARFILE, "<$filename");
binmode(STARFILE);
while (read(STARFILE, $FileValues, 1)) {
  push @fileBytes, $FileValues; 
}
close(STARFILE);

# Decrypt the data, block by block, and process it
my ($outBytes, $needsFixing, $warning, $fleetList, $queueList, $designList, $waypointList);
# Include the directory to handle the difference between TH and standalone 
($outBytes, $needsFixing, $warning, $fleetList, $queueList, $designList, $waypointList, $lastPlayer) = &decryptFix(dirname($filename), $filename, \@fileBytes,\%fleetList, \%queueList, \%designList, \%$waypointList, $lastPlayer);
my @outBytes = @{$outBytes};
%warning    = %$warning; # Tracking warnings generated
%fleetList  = %$fleetList;
%queueList  = %$queueList;
%designList = %$designList;
%waypointList = %$waypointList;

# Deal with the results.
 # If this isn't a .x file, update the associated List files
if ($file_type =~ /HST/i || $file_type =~ /M/i ) {
  print "Updating List Files...\n";

  if (%designList) { # Output the fleets for a .x pass
#  print "Printing Ship Design List...\n";
#  &printList(\%designList);
  &writeList("$listPrefix.HST.design", \%designList);
  }
  
  if (%queueList) { # Output the production queues for a .x pass
#    print "Printing Production Queue List...\n";
#    &printList(\%queueList);
    &writeList("$listPrefix.HST.queue", \%queueList);
  }
    
  if (%fleetList) { # Output the fleets for a .x pass
#    print "Printing Fleet List...\n";
#    &printList(\%fleetList);
    &writeList("$listPrefix.HST.fleet", \%fleetList);
  }
  
  if (%waypointList) { # Output the fleets for a .x pass
#    print "Printing Waypoint List...\n";
#    &printList(\%waypointList);
    &writeList("$listPrefix.HST.fleet", \%waypointList);
  }
  
  if ($lastPlayer) {# Store the last player value for 10th Starbase for a .x pass
#    print "Printing Last Player...\n";
#    print "Last Player: $lastPlayer\n";
    open (LISTFILE, ">$listPrefix.HST.last");
    print LISTFILE "$lastPlayer"; 
    close LISTFILE;
  }
}

# 
# These really write out for debug purposes. 
# if ($file_type =~ /x/i && -e "$listPrefix.HST.design")   { &writeList("$listPrefix.$file_ext.design", \%designList); }
# if ($file_type =~ /x/i && -e "$listPrefix.HST.queue")    { &writeList("$listPrefix.$file_ext.queue", \%queueList); }
# if ($file_type =~ /x/i && -e "$listPrefix.HST.fleet")    { &writeList("$listPrefix.$file_ext.fleet", \%fleetList); }
# if ($file_type =~ /x/i && -e "$listPrefix.HST.waypoint") { &writeList("$listPrefix.$file_ext.waypoint", \%waypointList); }

# Output any detected warnings
print "\n\nFIX RESULTS:\n";
if (%warning) { 
  foreach my $key (sort keys %warning) {
    print "$key: $warning{$key}\n";
  }
  print "\n";
} else { print "No issues found.\n"; }

# Output the Stars! File with bugs fixed.
# Only create a new file if anything was wrong. 
#if (scalar @outBytes && $fixFiles > 1) {
if ($needsFixing && $fixFiles > 1) {
  # Create the output file name
  my $newFile; 
  if ($outFileName) { $newFile = $outFileName;  } 
  else { $newFile = $gameDir . '\\' . $basefile . '.fixed'; }
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "\n\nFile output: $newFile\n";
  unless ($ARGV[1]) { print "Don't forget to rename $newFile\n\n"; }
}


# sub showDestType {
#   my ($type) = @_;
#   my @category;
#   $category[0] = 'unknown';
#   $category[1] = 'Planet';
#   $category[2] = 'Fleet';
#   $category[4] = 'Deep Space';
#   $category[8] = 'Salvage/Packet/MT/Minefield';
#   return $category[$type];
# }

#     public static int ITEM_ID_INDEX = 0;
#     public static int MASS_INDEX = 7;
#     public static int ARMOR_INDEX = 15;
#     public static int FUEL_INDEX = 14;
#     public static int ITEM_ARMOR_INDEX = 13;
#     public static int SLOT_START_INDEX = 16;
#     public static int ENGINE_COUNT_INDEX = 17;
#     public static int SLOT_COUNT_INDEX = 48;

# sub deleteCargo { 
#   my ($cargo, $cargoCapacity, $fuelCapacity, $cargoRatio, $fuelRatio, $mass) = @_;
#   # Adjust the cargo for the deleted design
#   # BUG: The calculation for the cargo and fuel post design deletion will be +- 1 occasionally. 
#   # BUG: Should also be for split fleets, duplicate code.
#   my @cargo = split( chr(31), $cargo);
#     for (my $k=0; $k <=3; $k++ ){
#       $cargo[$k] = int(.5 + ($cargo[$k] * $cargoRatio)); # adjust the cargo based on the deleted design
#       $mass += $cargo[$k]; 
#     }
#   $cargo[4] = int(.5 + ($cargo[4] * $fuelRatio));
#   
#   return join(chr(31), @cargo), $mass; 
# }

