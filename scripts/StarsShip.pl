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
# Return Ship, Fleet, and Waypoint attributes
# Example Usage: StarsShip.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# But detects the colonizer, spacedock, and 10 starbase issues
#   Although player corrections won't always work within the 
#   contenxt of multiple entries in a .x file.
# This is a simpler, earlier version of the later StarsShipQueue.pl (which 
# eventually became StarsFix.pl

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost

my $debug = 1;
my $fixFiles = 2; # 0, 2: display, write 
my %warning;
my $warnId='';
# Ship parts
my $isFullDesign;
my $deleteDesign;
my $isTransferred;
my $isStarbase;
my $armor;
my $armorIndex; # used to fix Space Dock Overflow
my $itemCountIndex; # used to fix Space Dock Overflow
my $designNumber;
my $pic;
my $slotCount; 
my $slotEnd;
my $mass;   # For full designs, this is calculated
my $fuelCapacity; # calculated  
my $slot;
my $itemId;
my $itemCategory;
my $itemCount;
my $items;
my $turnDesigned; 
my $totalBuilt;
my $totalRemaining;
my $shipNameLength;
my $shipName;
# Array to track waypoint information
my @fleet;  # not used now? 
my %fleetBlock;
my $fleetcounter = 0;
my @waypoint;
my $waypointcounter = 0;
my @fleetMerge;
my $fleetMergeCounter = 0; #Array to track fleet merge orders

my %hullType; 
$hullType{'0'} = [ 15,1,"Small Freighter",0,0,0,0,0,0,0,25,20,12,0,17,0,70,130,25,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,85,51,49,55,53,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'1'} = [ 15,2,"Medium Freighter",1,0,0,0,3,0,0,60,40,20,0,19,4,210,450,50,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,86,50,48,56,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'2'} = [ 15,3,"Large Freighter",2,0,0,0,8,0,0,125,100,35,0,21,8,1200,2600,150,1,2,6146,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,102,34,48,38,70,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'3'} = [ 15,4,"Super Freighter",3,0,0,0,13,0,0,175,125,45,0,21,12,3000,8000,400,1,3,6146,3,12,5,2048,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,136,34,64,40,72,104,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'4'} = [ 15,5,"Scout",4,0,0,0,0,0,0,8,10,4,2,4,16,0,50,20,1,1,2,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,65,8,255,255,50,54,52,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'5'} = [ 15,6,"Frigate",5,0,0,0,6,0,0,8,12,4,2,4,20,0,125,45,1,1,2,2,6462,3,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,68,8,255,255,49,55,53,51,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'6'} = [ 15,7,"Destroyer",6,0,0,0,3,0,0,30,35,15,3,5,24,0,280,200,1,1,48,1,48,1,6462,1,8,2,4096,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,67,8,255,255,66,21,117,70,68,35,99,0,0,0,0,0,0,0,0,0 ];
$hullType{'7'} = [ 15,8,"Cruiser",7,0,0,0,9,0,0,90,85,40,5,8,28,0,600,700,1,2,6148,1,6148,1,48,2,48,2,6462,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
$hullType{'8'} = [ 15,9,"Battle Cruiser",8,0,0,0,10,0,0,120,120,55,8,12,32,0,1400,1000,1,2,6148,2,6148,2,48,3,48,3,6462,3,12,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
$hullType{'9'} = [ 15,10,"Battleship",9,0,0,0,13,0,0,222,225,120,25,20,36,0,2800,2000,1,4,6146,1,4,8,48,6,48,6,48,2,48,2,48,4,8,6,2048,3,2048,3,0,0,0,0,0,0,0,0,0,0,11,138,12,255,255,48,56,38,20,84,2,98,70,52,34,66,0,0,0,0,0 ];
$hullType{'10'} = [ 15,11,"Dreadnought",10,0,0,0,16,0,0,250,275,140,30,25,40,0,4500,4500,1,5,12,4,12,4,48,6,48,6,2048,4,2048,4,48,8,48,8,8,8,52,5,52,5,6462,2,0,0,0,0,0,0,13,138,12,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
$hullType{'11'} = [ 15,12,"Privateer",11,0,0,0,4,0,0,65,50,50,3,2,44,250,650,150,1,1,12,2,6146,1,6462,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,67,16,103,67,65,55,87,37,101,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'12'} = [ 15,13,"Rogue",12,0,0,0,8,0,0,75,60,80,5,5,48,500,2250,450,1,2,12,3,6400,2,2,1,6462,2,6462,2,6400,2,2048,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,132,16,118,51,65,70,102,72,20,116,38,18,114,0,0,0,0,0,0,0 ];
$hullType{'13'} = [ 15,14,"Galleon",13,0,0,0,11,0,0,125,105,70,5,5,52,1000,2500,900,1,4,12,2,12,2,6462,3,6462,3,6400,2,6144,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,132,16,118,50,64,19,115,21,117,54,86,72,0,0,0,0,0,0,0,0 ];
$hullType{'14'} = [ 15,15,"Mini-Colony Ship",14,0,0,0,0,0,0,8,3,2,0,2,56,10,150,10,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'15'} = [ 15,16,"Colony Ship",15,0,0,0,0,0,0,20,20,10,0,15,60,25,200,20,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'16'} = [ 15,17,"Mini Bomber",16,0,0,0,1,0,0,28,35,20,5,10,64,0,120,50,1,1,64,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,192,20,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'17'} = [ 15,18,"B-17 Bomber",17,0,0,0,6,0,0,69,150,55,10,10,68,0,400,175,1,2,64,4,64,4,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,192,20,255,255,49,51,53,55,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'18'} = [ 15,19,"Stealth Bomber",18,0,0,0,8,0,0,70,175,55,10,15,72,0,750,225,1,2,64,4,64,4,6146,1,2048,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,192,20,255,255,50,36,68,38,70,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'19'} = [ 15,20,"B-52 Bomber",19,0,0,0,15,0,0,110,280,90,15,10,76,0,750,450,1,3,64,4,64,4,64,4,64,4,6146,2,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,192,20,255,255,49,19,83,37,69,55,51,0,0,0,0,0,0,0,0,0 ];
$hullType{'20'} = [ 15,21,"Midget Miner",20,0,0,0,0,0,0,10,20,10,0,3,80,0,210,100,1,1,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,24,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'21'} = [ 15,22,"Mini-Miner",21,0,0,0,2,0,0,80,50,25,0,6,84,0,210,130,1,1,6146,1,128,1,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,24,255,255,50,54,36,68,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'22'} = [ 15,23,"Miner",22,0,0,0,6,0,0,110,110,32,0,6,88,0,500,475,1,2,6154,2,128,2,128,1,128,2,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'23'} = [ 15,24,"Maxi-Miner",23,0,0,0,11,0,0,110,140,32,0,6,92,0,850,1400,1,3,6154,2,128,4,128,1,128,4,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'24'} = [ 15,25,"Ultra-Miner",24,0,0,0,14,0,0,100,130,30,0,6,96,0,1300,1500,1,2,6154,3,128,4,128,2,128,4,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'25'} = [ 15,26,"Fuel Transport",25,0,0,0,4,0,0,12,50,10,0,5,100,0,750,5,1,1,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,28,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'26'} = [ 15,27,"Super-Fuel Xport",26,0,0,0,7,0,0,111,70,20,0,8,104,0,2250,12,1,2,4,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,28,255,255,50,52,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'27'} = [ 15,28,"Mini Mine Layer",27,0,0,0,0,0,0,10,20,8,2,5,108,0,400,60,1,1,256,2,256,2,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,16,255,255,50,36,68,54,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'28'} = [ 15,29,"Super Mine Layer",28,0,0,0,15,0,0,30,30,20,3,9,112,0,2200,1200,1,3,256,8,256,8,12,3,6146,3,6400,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,16,255,255,49,35,67,53,39,71,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'29'} = [ 15,30,"Nubian",29,0,0,0,26,0,0,100,150,75,12,12,124,0,5000,5000,1,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,0,0,0,0,0,0,13,130,16,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
$hullType{'30'} = [ 15,31,"Mini Morph",30,0,0,0,8,0,0,70,100,30,8,8,120,150,400,250,1,2,6462,3,6462,1,6462,1,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
$hullType{'31'} = [ 15,32,"Meta Morph",31,0,0,0,10,0,0,85,120,50,12,12,116,300,700,500,1,3,6462,8,6462,2,6462,2,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
$hullType{'32'} = [ 16,1,"Orbital Fort",32,0,0,0,0,0,0,0,80,24,0,34,128,0,0,100,2560,1,48,12,12,12,48,12,12,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,138,0,255,255,68,36,70,100,66,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'33'} = [ 16,2,"Space Dock",33,0,0,0,4,0,0,0,200,40,10,50,132,200,0,250,2560,1,48,16,12,24,48,16,4,24,2048,2,2048,2,48,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,140,0,102,68,34,20,65,71,116,38,102,98,0,0,0,0,0,0,0,0 ];
$hullType{'34'} = [ 16,3,"Space Station",34,0,0,0,0,0,0,0,1200,240,160,500,136,-1,0,500,2560,1,48,16,4,16,48,16,12,16,4,16,2048,3,48,16,2048,3,48,16,2560,1,12,16,0,0,0,0,0,0,0,0,12,142,0,102,68,66,5,3,88,80,133,100,131,36,48,70,56,0,0,0,0 ];
$hullType{'35'} = [ 16,4,"Ultra Station",35,0,0,0,12,0,0,0,1200,240,160,600,140,-1,0,1000,2560,1,48,16,2048,3,48,16,4,20,4,20,2048,3,48,16,2048,3,48,16,2560,1,12,20,48,16,12,20,2048,3,48,16,16,144,0,102,68,36,80,66,88,98,38,70,3,131,56,100,102,48,34,5,133 ];
$hullType{'36'} = [ 16,5,"Death Star",36,0,0,0,17,0,0,0,1500,240,160,700,144,-1,0,1500,2560,1,48,32,2048,4,2048,4,4,30,4,30,2048,4,48,32,2048,4,48,32,2560,1,12,20,2048,4,12,20,2048,4,48,32,16,146,0,102,68,20,96,65,104,98,38,71,2,130,40,116,102,32,34,6,134 ];

#########################################        
my $filename = $ARGV[0]; # input file
my $outFileName = $ARGV[1];
if (!($filename)) { 
  print "\n\nUsage: StarsShip.pl <input file>\n\n";
  print "Please enter the input file (.X|.M|.HST). Example: \n";
  print "  StarsShip.pl c:\\games\\test.m1\n\n";
  print "Lists all ship data and fixes (or warns) for detected bugs:\n";
  print "   Colonizer Module remaining when removed\n";
  print "   Space Dock overflow\n";
  print "   Player with 10th starbase\n";
  print "By default, a new file will be created: <filename>.fix\n\n";
  print "You can create a different file with StarsShip.pl <filename> <newfilename>\n";
  print "  StarsShip.pl <filename> <filename> will overwrite the original file.\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $dir, $basename, $ext);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1
$basename = $basefile;
$basename =~  s/$ext//;

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
my ($outBytes, $needsFixing, $warning) = &decryptShip(@fileBytes);
#my ($outBytes, $needsFixing, $warning) = &decryptShip();
my @outBytes = @{$outBytes};
%warning = %$warning;

# my $fleetLoop =0;
# while ($fleetLoop <= ($#fleet)) {
#  print "Fleet: fleetId: $fleet[$fleetLoop]{'id'}, ownerId: $fleet[$fleetLoop]{'owner'}, x: $fleet[$fleetLoop]{'x'}, y: $fleet[$fleetLoop]{'y'}\n";
#  $fleetLoop++;
# }

print "\n\nFLEET INFO:\n";

for my $key (keys %fleetBlock) {
#  print "fleetId:$key  player:$fleetBlock{$key}{'player'}, ownerId:$fleetBlock{$key}{'owner'}, x:$fleetBlock{$key}{'x'}, y:$fleetBlock{$key}{'y'}, battlePlan:$fleetBlock{$key}{'battlePlan'}\n";
  my @shipCount = @{$fleetBlock{$key}{'shipCount'}};
  print "$key,$fleetBlock{$key}{'player'},$fleetBlock{$key}{'owner'},$fleetBlock{$key}{'x'},$fleetBlock{$key}{'y'},$fleetBlock{$key}{'battlePlan'},";
  my $shipct = 0;
  foreach my $val (@shipCount) {
    if ($val ) { print "$val";}
    else { print "0";}
   if ($shipct <15) { print ","; }
    $shipct++;
  }
  print "\n";
}

my $waypointLoop = 0;
while ($waypointLoop <= ($#waypoint)) {
 print "Waypoint: fleetId: $waypoint[$waypointLoop]{'id'}, ownerId: $waypoint[$waypointLoop]{'owner'}, xDest: $waypoint[$waypointLoop]{'x'}, yDest: $waypoint[$waypointLoop]{'y'}, positionId: $waypoint[$waypointLoop]{'position'}\n";
 $waypointLoop++;
}

print "\nRESULTS:\n";
if (%warning) { 
  foreach my $key (keys %warning)
  {
    print "$key: $warning{$key}\n";
  }
  print "\n";
} else { print "No issues found\n"; }

# Only create a new file if anything was wrong. 
#if (scalar @outBytes && $fixFiles > 1) {
if ($needsFixing && $fixFiles > 1) {
  # Create the output file name
  my $newFile; 
  if ($outFileName) { $newFile = $outFileName;  } 
  else { $newFile = $dir . '\\' . $basefile . '.fix'; }
  #if ($debug) { $newFile = $dir . '\\' . $basefile . '.fix';  } # Just for me
  
  # Output the Stars! File with bugs fixed.
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "\n\nFile output: $newFile\n";
  unless ($ARGV[1]) { print "Don't forget to rename $newFile\n\n"; }
}

################################################################
sub decryptShip {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $needsFixing;
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($debug > 1) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    if ($debug > 100) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
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
      if ( $debug  > 1) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
      # WHERE THE MAGIC HAPPENS
      
      # Detect the Colonizer, Spack Dock SuperLatanium, and 10 starbase design bugs
      if ($typeId == 26 || $typeId == 27) { # Design & Design Change block
      print "\nTurn: " . ($turn+2400) . "\tPlayer ID: $Player\n";
        my $hullId;
        my $index = 0;
        my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
        $deleteDesign = $decryptedData[0] % 16;
        if ($deleteDesign == 0) { 
          $designNumber = $decryptedData[1] % 16; 
          print "Delete designNumber: $designNumber\n";
          $isStarbase = ($decryptedData[1] >> 4) % 2; 
          print "isStarbase: $isStarbase\n";  
        }
        if ( $typeId == 27 ) { $index = 2; } # for the two extra bytes in a .x file  
        # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
        if ($deleteDesign) { 
          $isFullDesign =  ($decryptedData[$index] & 0x04); print "isFullDesign: $isFullDesign\n";
          $isTransferred = ($decryptedData[$index+1] & 0x80); print "isTransferred: $isTransferred\n";
          $isStarbase = ($decryptedData[$index+1] & 0x40);  print "isStarbase: $isStarbase\n";
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; print "designNumber: $designNumber\n";
          $hullId = $decryptedData[$index+2] & 0xFF; print "HullId: $hullId (" . &showHull($hullId, 2) . ")\n";
          unless ($isStarbase) { $fuelCapacity = &showHull($hullId, 17); }
          $pic = $decryptedData[$index+3] & 0xFF; print "pic: $pic\n";  
          if ($hullId == 29) { $pic = 4*31; }  # No idea why these pics are swapped
          elsif ($hullId == 31) { $pic = 4*29; }
          if ($isFullDesign) {
            # Since there can be a ship and base with the same hullId, 
            # need to be able to keep them separate
            if ($isStarbase) { $warnId = "base" . $designNumber; }
            else { $warnId = "ship" . $designNumber; }
            $armor = &read16(\@decryptedData, $index+4);  print "armor: $armor\n";
            $armorIndex = $index +4; # used to fix the Space Dock overflow
            $slotCount = $decryptedData[$index+6] & 0xFF; print "slotCount: $slotCount\n";  # Actual number of slots
            $turnDesigned = &read16(\@decryptedData, $index+7); print "turnDesigned: " . $turnDesigned . "\n";
            $totalBuilt = &read16(\@decryptedData, $index+9); print "totalBuilt: $totalBuilt\n";
            $totalRemaining = &read16(\@decryptedData, $index+13); print "totalRemaining: $totalRemaining\n";
            $slotEnd = $index+17+($slotCount*4); print "slotEnd: $slotEnd\n";
            $shipNameLength = $decryptedData[$slotEnd];          
            print "shipNameLength: $shipNameLength  (using nibbles as characters, not bytes)\n";
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            $index = 17;  
            if ($typeId == 27) { $index += 2; } # x files have 2 more bytes
            # Loop through once for each slot
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
              $index += 2;
              $itemId = &read8($decryptedData[$index++]); # Use current value of index, and increment by 1
              $itemCountIndex = $index; # used for the Space Dock overflow. 
              $itemCount = &read8($decryptedData[$index++]);
              my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
              if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount\n"; }
              else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount\n";}

              # Calculate actual fuel in hull (just because, in theory, I can)
              if ( $itemCount > 0 && !$isStarbase){
#                 my $key =  ($itemCategory << 8) | ( $itemId & 0xFF);
#                 mass += slot.count * Items.itemMasses.get(key); 
#                 if (itemCategory == Items.TechCategory.Mechanical.getMask()) 
                if ( &getMask($itemCategory, 12) ) {
                  if ($itemId == 5) { $fuelCapacity += $itemCount * 250;  }
                  if ($itemId == 6) { $fuelCapacity += $itemCount * 500;  }
                }
#                if ($itemCategory == Items.TechCategory.Electrical.getMask()) {
                if ( &getMask($itemCategory, 11) ) {
                  if ($itemId == 16) { $fuelCapacity += $itemCount * 200; print "Adding fuel\n"; }
                }
              }

              # Fix the colonizer bug
              # Ships with a colonisation module removed and the slot left empty can still colonise planets
              # If a colonizer hull is created, and then edited, it's going to put 2 (or more)  entries in the .x file.
              # so also need to filter.
              if ($itemId == 0 &&  $itemCategory == 4096 && $itemCount == 0) {
                $err .= "***Colonizer bug detected in ship design slot $designNumber: $shipName (slot $itemSlot). ";
                if ($fixFiles > 1) {
                  $err .= "  Fixed!!!";
                  ($decryptedData[$index-4], $decryptedData[$index-3]) = &write16(0);
                  $needsFixing = 1;
                } else {$err .= " ";}
                $warning{$warnId} = $err;
                print $err . "\n"; 
              }
              # Fix Space Dock Armor slot Buffer Overflow with super latanium
              # If your race has ISB and RS, building a Space Dock with more than 21 SuperLat in the Armor slot 
              # will result in some sort of error (of massively increased armor)
              # Rick: I had hoped to fix this by simply rewriting the armor value. But it gets recalculated,
              # so resetting the itemCount is the only choice. 
              if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory == 8 && $itemCount >=22  && $armor  >= 49518) {
                $err = "***Spacedock Overflow bug of > 21 SuperLatanium detected in starbase design slot $designNumber: $shipName. ";
                if ($fixFiles > 1) {
                  $err .= "  Fixed!!! ";
                  # reset the $itemCount 
                  $decryptedData[$itemCountIndex] = 21;
                  # Armor value should be 250 + (1500 * $itemCount) / 2
                  $armor = 250 + (1500 * 21) / 2; # correct for 21 Super Latanium
                  # reset the final armor value for the spacedock overflow bug
                  ($decryptedData[$armorIndex], $decryptedData[$armorIndex+1]) = &write16($armor);
                  $needsFixing = 1;
                } else {$err .= " ";}
                $warning{$warnId} = $err;
                print $err . "\n";
              }
            }
          } else { # If it's not a full design
            $mass = &read16(\@decryptedData, 4); 
            $slotEnd = 6; 
            $shipNameLength = $decryptedData[$slotEnd]; 
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          }
          if (!$isStarbase && $isFullDesign) { print "fuelCapacity(Ship): $fuelCapacity\n"; }
          print "shipName: $shipName\n";
          
          # Detect the 10th starbase design
          if ( $isStarbase && $designNumber == 9 && $deleteDesign && $Player > 0 ) {
            $err = "***Warning: Player $Player: Starbase ($shipName) in design slot 10 - Potential Crash if Player 1 Fleet 1 refuels when Last Player has a 10th starbase design";
            print $err . "\n"; 
            $warning{'ten'} = $err;
          } 
        } 
        # For the Colonizer bug & Spacedock overflow track whether the design was 
        # created, but remove the warning if the design was subsequently changed/deleted.
        # If this designNumber is broken, set warning. Otherwise clear warning
        # (because a later .x file entry fixed this designnumber)
        # Store the error in a hash so it's only one / ship / file
        # Will handle for multi-turn .m files.
        if (!$err && $warning{$warnId}) { 
          delete( $warning{$warnId} ); 
          print "Player Fix Noted\n";
        }
        # If the 10th starbase has been deleted, clear the warning
        if ( $isStarbase && $designNumber == 9 && $deleteDesign == 0 && $Player > 0 ){
          if ($warning{'ten'}) { 
            delete ($warning{'ten'}); 
            print "Player Fix Noted\n";
          }
        }
      }
      # Part of the detection of the minefield 0-coordinate bug, but 
      # the fleet block isn't mapped well-enough for me to figure out the coordinates
      # easily
      # THIS WOULD HAVE BEEN LESS WORK IF I'D KNOWN THIS WAS FIXED IN JRC4
      elsif ($typeId == 4 || $typeId == 5 ) { # waypoint block (add/change) in .x files , waypoint block (20)
#        if ($debug ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
#        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
        # Detect ships moving pure east/west or pure north/south
        # BUG: Doesn't work yet. Will need starting coordinates of fleet.
        my %waypoint; # to store waypoints in a hash
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
#        print "Waypoint4 Block: fleetId: $fleetId, ownerId: $ownerId, test: $test, xDest: $xDest, yDest: $yDest, positionId: $positionObjectId, unk = $unknownBitsWithWarp, PositionType: $positionObjectType, warp: $warp\n";
        $waypoint{'id'} = $fleetId;
        $waypoint{'owner'} = $ownerId;
        $waypoint{'x'} = $xDest;
        $waypoint{'y'} = $yDest;
        $waypoint{'position'} = $positionObjectId;
        $waypoint[$waypointcounter] = { %waypoint };
        $waypointcounter++;
      }
#       # THIS ALSO NOT NEEDED AS MINEFIELD WAYPOINT PROBLEMS FIXED IN JRC4
#       elsif ($typeId == 20 ) { # waypoint block in .m files , waypoint block (20)
#       # BUG: NOT WORKING
# #        if ($debug ) { print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
# #        if ($debug) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
#         # Detect ships moving pure east/west or pure north/south
#         # BUG: Doesn't work yet. Will need starting coordinates of fleet.
#         my %waypoint; # to store waypoints in a hash
# #        my $fleetId = $decryptedData[0]; 
# #        my $ownerId = $decryptedData[1]; 
# #        my $positionObjectId = &read16(\@decryptedData, 2);
# 			  my $xDest = &read16(\@decryptedData, 0);  #CORRECT
#         my $yDest = &read16(\@decryptedData, 2);  #CORRECT
#         my $fleetId = $decryptedData[3]; #Incorrect
#         my $ownerId = $decryptedData[4]; #Incorrect
#         
# #        my $yDest = &read16(\@decryptedData, 6);  
# #        my $unknownBitsWithWarp = $decryptedData[6] & 0x0F;
# #        my $positionObjectType = $decryptedData[7] & 0xFF;
# #        my $fullWaypointData;
# #        my $warp =  $decryptedData[10] >> 4; 
#         my $warp =  ($decryptedData[6] & 0xFF) >> 4;
#         my $waypointTask = $decryptedData[6] & 0x0F;
#         my $positionObject = &read16(\@decryptedData, 4);
# #        print "WaypointM Block: fleetId: $fleetId, ownerId: $ownerId, test: $test, xDest: $xDest, yDest: $yDest, positionId: $positionObjectId, unk = $unknownBitsWithWarp, PositionType: $positionObjectType, warp: $warp\n";
#         print "Waypoint20 Block: xDest: $xDest, yDest: $yDest, warp: $warp, task: $waypointTask, positionObject: $positionObject, " . &dec2bin($decryptedData[3]) . " " . &dec2bin($decryptedData[4]). " " . &dec2bin($decryptedData[5]). "\n";
#         $waypoint{'id'} = $fleetId;
#         $waypoint{'owner'} = $ownerId;
#         $waypoint{'x'} = $xDest;
#         $waypoint{'y'} = $yDest;
#         $waypoint{'position'} = 'null';
#         $waypoint[$waypointcounter] = { %waypoint };
#         $waypointcounter++;
#       }

      elsif ($typeId == 16 ) { # Fleet block and partial fleet block
        # don't care about a partial fleet block (17), as that would be a different
        # player's fleet.
        my %fleet; # To store the values in a hash
        my ($byte5);
        my ($fleetId, $ownerId, $hull);
        my ($byte2, $byte3); # who knows
        my $kindByte; # 3 for most partial, 4 for robber baron, 7 for full
        my $positionObjectId;
        my $index;
        my $fileLength;
        my ($iLength, $bLength, $gLength);
        my ($popLength, $fuelLength);
        my $contentsLengths;
        my ($ironium, $boranium, $germanium);
        my ($x, $y);
        my ($deltaX, $deltaY);  # partial fleet data
        my ($shipTypes);
        my ($damagedShipTypes); # full fleet data
        my @damagedShipInfo;    # full fleet data
        my @shipCount;
        my $mask;
        my ($population, $fuel);
        my ($warp, $waypointCount);
        my ($unknownBitsWithWarp); # partial fleet data
        my $battlePlan; # full fleet data
        
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $ownerId = $decryptedData[1] >> 1;
        $byte2 = $decryptedData[2];
	      $byte3 = $decryptedData[3];
        $kindByte = $decryptedData[4];
        $byte5 = $decryptedData[5];
        my $shipCountTwoBytes;
        if (($byte5 & 8) == 0) { $shipCountTwoBytes = 1; 
        } else  {$shipCountTwoBytes = 0; }
        $positionObjectId = &read16(\@decryptedData, 6);
        $x = &read16(\@decryptedData, 8);
        $y = &read16(\@decryptedData, 10);
        $shipTypes = &read16(\@decryptedData, 12); # counted from the right side
        $index = 14;
        $mask = 1;
        for (my $bit = 0; $bit < 16; $bit++) {
          if (($shipTypes & $mask) != 0) {
            if ($shipCountTwoBytes) {
              $shipCount[$bit] = &read16(\@decryptedData, $index);
              $index += 2;
            } else {
              $shipCount[$bit] = &read8($decryptedData[$index]);
              $index += 1;
            }
          } else { $shipCount[$bit] =0; } # Pad out the array
          $mask <<= 1;
        }
        #print "\n\nshipTypes: " . &dec2bin($shipTypes) . "\n";
        my $shipct =0 ;
        foreach my $val (@shipCount) {
          if ($val ) { print "designNumber: $shipct   shipCount: $val\n";}
          else { print "designNumber: $shipct   shipCount: 0\n";}
          $shipct++;
        }
        # PARTIAL_KIND = 3, PICK_POCKET_KIND = 4, FULL_KIND = 7;
        #if ($kindByte != 7 && $kindByte != 4 && $kindByte != 3) {
        if ($kindByte == 7 || $kindByte == 4) {
          $contentsLengths = &read16(\@decryptedData, $index);
          $iLength = $contentsLengths & 0x03;
          $iLength = 4 >> (3 - $iLength);
          $bLength = ($contentsLengths & 0x0C) >> 2;
          $bLength = 4 >> (3 - $bLength);
          $gLength = ($contentsLengths & 0x30) >> 4;
          $gLength = 4 >> (3 - $gLength);
          $popLength = ($contentsLengths & 0xC0) >> 6;
          $popLength = 4 >> (3 - $popLength);
          $fuelLength = $contentsLengths >> 8;
          $fuelLength = 4 >> (3 - $fuelLength);
          $index += 2;
          $ironium = &readN(\@decryptedData, $index, $iLength);
          $index += $iLength;
          $boranium = &readN(\@decryptedData, $index, $bLength);
          $index += $bLength;
          $germanium = &readN(\@decryptedData, $index, $gLength);
          $index += $gLength;
          $population = &readN(\@decryptedData, $index, $popLength);
          $index += $popLength;
          $fuel = &readN(\@decryptedData, $index, $fuelLength);
          $index += $fuelLength;
        } 
        if ($kindByte == 7) {
          $damagedShipTypes = &read16(\@decryptedData, $index);
          $index += 2;
          $mask = 1;
          for (my $bit = 0; $bit < 16; $bit++) {
            if (($damagedShipTypes & $mask) != 0) {
              $damagedShipInfo[$bit] = \&read16(\@decryptedData, $index);
              $index += 2;
            }
            $mask <<= 1;
          }
          $battlePlan = &read8($decryptedData[$index++]);
          $waypointCount = &read8($decryptedData[$index++]);
        } else {
          $deltaX = &read8($decryptedData[$index++]);
          $deltaY = &read8($decryptedData[$index++]);
          $warp = $decryptedData[$index] & 15;
          $unknownBitsWithWarp = $decryptedData[$index] & 0xF0;
          $index++;
          $index++;
          $mass = &read32(\@decryptedData, $index);
          $index += 4;
        }
        $x = &read16(\@decryptedData, 8); # Correct  (likely only in full block?)
        $y = &read16(\@decryptedData, 10); # Correct (likely only in full block?)
        print "Fleet Block: fleetId: $fleetId, ownerId: $ownerId, x: $x, y: $y, battlePlan: $battlePlan, shipTypes:" . &dec2bin($shipTypes) . "\n";
        #$fleet{'id'} = $fleetId;
        $fleet{'player'} = $Player; # BUG: Are these different than "owner"? Likely
        $fleet{'owner'} = $ownerId;
        $fleet{'x'} = $x;
        $fleet{'y'} = $y;
        $fleet{'battlePlan'} = $battlePlan;
        $fleet{'shipTypes'}  = &dec2bin($shipTypes);
        $fleet{'shipCount'}  = \@shipCount; # This array doesn't have counts for any design after the last one with a number.
        #$fleet[$fleetcounter] = { %fleet };
        $fleetBlock{$fleetId} = { %fleet };
        #$fleetcounter++;
      } elsif ($typeId == 37) {  # Fleet Merge block
        my $fleetNumber1 = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        print "Fleet Number1: $fleetNumber1\n";
        my $fleetNumber2 = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 1) << 8);
        print "Fleet Number2: $fleetNumber2\n";
        # Yeah, I could store this in binary. But why do that to myself.
        $fleetMerge[$fleetMergeCounter] = "$fleetNumber1" . ',' . $fleetNumber2;
        $fleetMergeCounter++;
      }
      # END OF MAGIC
      # reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  
  # If the data was not reset, no need to write the file back out
  # Faster, less risk of corruption
  return \@outBytes, $needsFixing, \%warning;
  #return \@outBytes;
}

sub showHull {
  my ($hullType, $position) = @_;
  if ($hullType{$hullType}[$position]) {  return $hullType{$hullType}[$position]; }
  else { return $hullType; }
}

# sub showCategory {
#   my ($category, $item) = @_;
#   my @category;
#   my %item;
# #             Empty = 0,
# #             Engine = 1,
# #             Scanners = 2,
# #             Shields = 4,
# #             Armor = 8,
# #             BeamWeapon = 0x10,
# #             Torpedo = 0x20
# #             Bomb = 0x40,
# #             MiningRobot = 0x80,
# #             MineLayer = 0x100,
# #             Orbital = 0x200,
# #             Planetary = 0x400,
# #             Electrical = 0x800,
# #             Mechanical = 0x1000,
# 
#   $category[0] = "Empty";
#   $category[1] = "Engine";
#   $category[2] = "Scanners";
#   $category[4] = "Shields";
#   $category[8] = "Armor";
#   $category[16] = "BeamWeapon";
#   $category[32] = "Torpedo";
#   $category[64] = "Bomb";
#   $category[128] = "MiningRobot";
#   $category[256] = "MineLayer";
#   $category[512] = "Orbital";
#   $category[1024] = "Planetary"; # Assumed since it appears to be the only missing one
#   $category[2048] = "Electrical";
#   $category[4096] = "Mechanical";
#   $category[6144] = "Orbital Or Electrical";
# 
#   $item{'0'} =  [ qw ( empty ) ]; 
#   $item{'1'} =  [ qw ( SettlerDelight Jump5 Mizer Hump6 Legs7 Alpha8 Trans9 Inter10 Enigma Trans10 NHRS Sub Trans TransSuper TransMizer Galaxy ) ];
#   $item{'2'} =  [ qw ( Bat Rhino Mole DNA Possum PickPocket Chameleon Ferret Dolphin Gazelle RNA Cheetah Elephant Eagle Robber Peerless) ];
#   $item{'4'} =  [ qw ( Mole Cow Wolverine Croby Shadow Bear Langston Gorilla Elephant Complete ) ];
#   $item{'8'} =  [ qw ( Tritanium Crobmium CarbonicArmor Strobnium OrganicArmor Kelarium FieldedKelarium DepletedNeutronium Neutronium MegaPoly Valanium Superlatanium ) ];
#   $item{'16'} = [ qw ( Laser X-Ray MiniGun YakimoraPhaser Blackjack Phaser PulsedSapper ColloidalPhaser GatlingGun MiniBlaster Bludgeon MarkIVBlaster PhasedSapper HeavyBlaster GatlingNeutrino MyopicDisruptor Blunderbuss Disruptor MultiContainedMunition SyncroSapper MegaDisruptor BigMuthaCannon StreamingPulverizer Anti-MatterPulverizer ) ]; 
#   $item{'32'} = [ qw ( Alpha Beta Delta Epsilon Rho Upsilon Omega Jihad Juggernaut Doomsday Armageddon ) ];
#   $item{'64'} = [ qw ( LadyFinger BlackCat M-70 M-80 Cherry LBU-17 LBU-32 LBU-74 HushaBoom Retro Smart Neutron EnrichedNeutron Peerless Annihilator ) ];
#   $item{'128'} = [ qw ( Midget Mini Miner Maxi Super Ultra Orbital ) ]; 
#   $item{'256'} = [ qw ( Mine40 Mine50 Mine80 Mine130 Heavy50 Heavy110 Heavy200 Speed20 Speed30 Speed50 ) ];
#   $item{'512'} = [ qw ( SG250 SG300 SG600 SG500 SGany SG800  SGanyany Mass5 Mass6 Mass7 Mass8 Mass9 Mass10 Mass11 Mass12 Mass13 ) ];
#   $item{'1024'} = [ qw ( Viewer50 Viewer90 Viewer150 Viewer220 Viewer280 Viewer320 Snooper400 Snooper500 Snooper620 ) ];
#   $item{'2048'} = [ qw ( TransportCloak StealthCloak Super-StealthCloak Ultra-StealthCloak MultiFunction BattleComputer BattleSuperComputer BattleNexus Jammer10 Jammer20 Jammer30 Jammer50 EnergyCapacitor FluxCapacitor EnergyDampener TachyonDetector Anti-matterGenerator) ];
#   $item{'4096'} = [ qw ( Colonization OrbitalCon Cargo SuperCargo MultiCargo Fuel SuperFuel ManeuveringJet Overthruster BeamDeflector ) ];
#   $item{'6194'} = [ qw ( empty ) ];
# 
#   return ($category[$category],$item{$category}[$item]);
# }

# sub waypointTask {
#   my ($task) = @_;
#   if ($task == 0) { return "No Task"; }
#   elsif ($task == 1) { return "?"; }
#   elsif ($task == 3) { return "?"; }
#   elsif ($task == 4) { return "?"; }
#   elsif ($task == 5) { return "?"; }
#   elsif ($task == 6) { return "?"; }
#   elsif ($task == 7) { return "?"; }
#   elsif ($task == 9) { return "?"; }
# }

# sub getMask {
# # Return true if the associated bit is set for the number
#   my ($number, $position) = @_;
#   my $new_num = $number >> ($position ); 
#     # if it results to '1' then bit is set, 
#     # else it results to '0' bit is unset 
#   my $check = $new_num &1;
#   return ($check); 
# } 

#     public static int ITEM_ID_INDEX = 0;
#     public static int MASS_INDEX = 7;
#     public static int ARMOR_INDEX = 15;
#     public static int FUEL_INDEX = 14;
#     public static int ITEM_ARMOR_INDEX = 13;
#     public static int SLOT_START_INDEX = 16;
#     public static int ENGINE_COUNT_INDEX = 17;
#     public static int SLOT_COUNT_INDEX = 48;

# CSV position 18 is fuel
# 1,1,"Stargate 100/250",1,0,0,5,5,0,0,0,400,100,40,40,144,100,250,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,2,"Stargate any/300",2,0,0,6,10,0,0,0,500,100,40,40,145,-1,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,3,"Stargate 150/600",3,0,0,11,7,0,0,0,1000,100,40,40,146,150,600,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,4,"Stargate 300/500",4,0,0,9,13,0,0,0,1200,100,40,40,147,300,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,5,"Stargate 100/any",5,0,0,16,12,0,0,0,1400,100,40,40,148,100,-1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,6,"Stargate any/800",6,0,0,12,18,0,0,0,1400,100,40,40,149,-1,800,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,7,"Stargate any/any",7,0,0,19,24,0,0,0,1600,100,40,40,150,-1,-1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,8,"Mass Driver 5",8,4,0,0,0,0,0,0,140,48,40,40,151,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,9,"Mass Driver 6",9,7,0,0,0,0,0,0,288,48,40,40,152,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,10,"Mass Driver 7",10,9,0,0,0,0,0,0,1024,200,200,200,153,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,11,"Super Driver 8",11,11,0,0,0,0,0,0,512,48,40,40,154,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,12,"Super Driver 9",12,13,0,0,0,0,0,0,648,48,40,40,155,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,13,"Ultra Driver 10",13,15,0,0,0,0,0,0,1936,200,200,200,156,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,14,"Ultra Driver 11",14,17,0,0,0,0,0,0,968,48,40,40,157,11,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,15,"Ultra Driver 12",15,20,0,0,0,0,0,0,1152,48,40,40,158,12,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 1,16,"Ultra Driver 13",16,24,0,0,0,0,0,0,1352,48,40,40,159,13,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,1,"Laser",1,0,0,0,0,0,0,1,5,0,6,0,28,1,10,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,2,"X-Ray Laser",2,0,3,0,0,0,0,1,6,0,6,0,29,1,16,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,3,"Mini Gun",3,0,5,0,0,0,0,3,10,0,16,0,20,2,13,12,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,4,"Yakimora Light Phaser",4,0,6,0,0,0,0,1,7,0,8,0,19,1,26,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,5,"Blackjack",5,0,7,0,0,0,0,10,7,0,16,0,14,0,90,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,6,"Phaser Bazooka",6,0,8,0,0,0,0,2,11,0,8,0,21,2,26,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,7,"Pulsed Sapper",7,5,9,0,0,0,0,1,12,0,0,4,17,3,82,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,8,"Colloidal Phaser",8,0,10,0,0,0,0,2,18,0,14,0,192,3,26,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,9,"Gatling Gun",9,0,11,0,0,0,0,3,13,0,20,0,26,2,31,12,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,10,"Mini Blaster",10,0,12,0,0,0,0,1,9,0,10,0,24,1,66,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,11,"Bludgeon",11,0,13,0,0,0,0,10,9,0,22,0,15,0,231,10,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,12,"Mark IV Blaster",12,0,14,0,0,0,0,2,15,0,12,0,25,2,66,7,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,13,"Phased Sapper",13,8,15,0,0,0,0,1,16,0,0,6,18,3,211,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,14,"Heavy Blaster",14,0,16,0,0,0,0,2,25,0,20,0,193,3,66,5,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,15,"Gatling Neutrino Cannon",15,0,17,0,0,0,0,3,17,0,28,0,30,2,80,13,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,16,"Myopic Disruptor",16,0,18,0,0,0,0,1,12,0,14,0,194,1,169,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,17,"Blunderbuss",17,0,19,0,0,0,0,10,13,0,30,0,13,0,592,11,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,18,"Disruptor",18,0,20,0,0,0,0,2,20,0,16,0,27,2,169,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,19,"Multi Contained Munition",19,21,21,0,0,16,12,8,40,6,40,6,111,3,140,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,20,"Syncro Sapper",20,11,21,0,0,0,0,1,21,0,0,8,16,3,541,14,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,21,"Mega Disruptor",21,0,22,0,0,0,0,2,33,0,30,0,195,3,169,6,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,22,"Big Mutha Cannon",22,0,23,0,0,0,0,3,23,0,36,0,31,2,204,13,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,23,"Streaming Pulverizer",23,0,24,0,0,0,0,1,16,0,20,0,22,1,433,9,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 2,24,"Anti-Matter Pulverizer",24,0,26,0,0,0,0,2,27,0,22,0,23,2,433,8,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,1,"Alpha Torpedo",1,0,0,0,0,0,0,25,5,9,3,3,87,4,5,0,35,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,2,"Beta Torpedo",2,0,5,1,0,0,0,25,6,18,6,4,88,4,12,1,45,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,3,"Delta Torpedo",3,0,10,2,0,0,0,25,8,22,8,5,89,4,26,1,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,4,"Epsilon Torpedo",4,0,14,3,0,0,0,25,10,30,10,6,92,5,48,2,65,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,5,"Rho Torpedo",5,0,18,4,0,0,0,25,12,34,12,8,93,5,90,2,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,6,"Upsilon Torpedo",6,0,22,5,0,0,0,25,15,40,14,9,94,5,169,3,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,7,"Omega Torpedo",7,0,26,6,0,0,0,25,18,52,18,12,95,5,316,4,80,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,8,"Anti Matter Torpedo",8,0,11,12,0,0,21,8,50,3,8,1,108,6,60,0,85,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,9,"Jihad Missile",9,0,12,6,0,0,0,35,13,37,13,9,200,5,85,0,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,10,"Juggernaut Missile",10,0,16,8,0,0,0,35,16,48,16,11,201,5,150,1,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,11,"Doomsday Missile",11,0,20,10,0,0,0,35,20,60,20,13,202,6,280,2,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 3,12,"Armageddon Missile",12,0,24,10,0,0,0,35,24,67,23,16,203,6,525,3,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,1,"Lady Finger Bomb",1,0,2,0,0,0,0,40,5,1,20,0,35,1,6,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,2,"Black Cat Bomb",2,0,5,0,0,0,0,45,7,1,22,0,36,1,9,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,3,"M-70 Bomb",3,0,8,0,0,0,0,50,9,1,24,0,37,1,12,6,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,4,"M-80 Bomb",4,0,11,0,0,0,0,55,12,1,25,0,38,1,17,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,5,"Cherry Bomb",5,0,14,0,0,0,0,52,11,1,25,0,39,1,25,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,6,"LBU-17 Bomb",6,0,5,0,0,8,0,30,7,1,15,15,32,1,2,16,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,7,"LBU-32 Bomb",7,0,10,0,0,10,0,35,10,1,24,15,33,1,3,28,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,8,"LBU-74 Bomb",8,0,15,0,0,12,0,45,14,1,33,12,34,1,4,45,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,9,"Hush-a-Boom",9,0,12,0,0,12,12,5,5,1,5,0,182,1,30,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,10,"Retro Bomb",10,0,10,0,0,0,12,45,50,15,15,10,174,1,0,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,11,"Smart Bomb",11,0,5,0,0,0,7,50,27,1,22,0,112,1,13,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,12,"Neutron Bomb",12,0,10,0,0,0,10,57,30,1,30,0,113,1,22,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,13,"Enriched Neutron Bomb",13,0,15,0,0,0,12,64,25,1,36,0,114,1,35,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,14,"Peerless Bomb",14,0,22,0,0,0,15,55,32,1,33,0,115,1,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 4,15,"Annihilator Bomb",15,0,26,0,0,0,17,50,28,1,30,0,116,1,70,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,1,"Total Terraform �3",1,0,0,0,0,0,0,0,70,0,0,0,184,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,2,"Total Terraform �5",2,0,0,0,0,0,3,0,70,0,0,0,185,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,3,"Total Terraform �7",3,0,0,0,0,0,6,0,70,0,0,0,186,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,4,"Total Terraform �10",4,0,0,0,0,0,9,0,70,0,0,0,187,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,5,"Total Terraform �15",5,0,0,0,0,0,13,0,70,0,0,0,188,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,6,"Total Terraform �20",6,0,0,0,0,0,17,0,70,0,0,0,180,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,7,"Total Terraform �25",7,0,0,0,0,0,22,0,70,0,0,0,172,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,8,"Total Terraform �30",8,0,0,0,0,0,25,0,70,0,0,0,164,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,9,"Gravity Terraform �3",9,0,0,1,0,0,1,0,100,0,0,0,160,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,10,"Gravity Terraform �7",10,0,0,5,0,0,2,0,100,0,0,0,161,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,11,"Gravity Terraform �11",11,0,0,10,0,0,3,0,100,0,0,0,162,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,12,"Gravity Terraform �15",12,0,0,16,0,0,4,0,100,0,0,0,163,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,13,"Temp Terraform �3",13,1,0,0,0,0,1,0,100,0,0,0,168,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,14,"Temp Terraform �7",14,5,0,0,0,0,2,0,100,0,0,0,169,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,15,"Temp Terraform �11",15,10,0,0,0,0,3,0,100,0,0,0,170,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,16,"Temp Terraform �15",16,16,0,0,0,0,4,0,100,0,0,0,171,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,17,"Radiation Terraform �3",17,0,1,0,0,0,1,0,100,0,0,0,176,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,18,"Radiation Terraform �7",18,0,5,0,0,0,2,0,100,0,0,0,177,7,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,19,"Radiation Terraform �11",19,0,10,0,0,0,3,0,100,0,0,0,178,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 5,20,"Radiation Terraform �15",20,0,16,0,0,0,4,0,100,0,0,0,179,15,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,1,"Viewer 50",1,0,0,0,0,0,0,0,100,10,10,70,80,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,2,"Viewer 90",2,0,0,0,0,1,0,0,100,10,10,70,81,90,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,3,"Scoper 150",3,0,0,0,0,3,0,0,100,10,10,70,82,150,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,4,"Scoper 220",4,0,0,0,0,6,0,0,100,10,10,70,83,220,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,5,"Scoper 280",5,0,0,0,0,8,0,0,100,10,10,70,90,280,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,6,"Snooper 320X",6,3,0,0,0,10,3,0,100,10,10,70,84,-320,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,7,"Snooper 400X",7,4,0,0,0,13,6,0,100,10,10,70,85,-400,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,8,"Snooper 500X",8,5,0,0,0,16,7,0,100,10,10,70,86,-500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,9,"Snooper 620X",9,7,0,0,0,23,9,0,100,10,10,70,91,-620,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,10,"SDI",10,0,0,0,0,0,0,0,15,5,5,5,72,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,11,"Missile Battery",11,5,0,0,0,0,0,0,15,5,5,5,73,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,12,"Laser Battery",12,10,0,0,0,0,0,0,15,5,5,5,74,24,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,13,"Planetary Shield",13,16,0,0,0,0,0,0,15,5,5,5,75,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,14,"Neutron Shield",14,23,0,0,0,0,0,0,15,5,5,5,76,38,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 6,15,"Genesis Device",15,20,10,10,20,10,20,0,5000,0,0,0,175,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,1,"Robo-Midget Miner",1,0,0,0,0,0,0,80,50,14,0,4,138,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,2,"Robo-Mini-Miner",2,0,0,0,2,1,0,240,100,30,0,7,139,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,3,"Robo-Miner",3,0,0,0,4,2,0,240,100,30,0,7,140,12,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,4,"Robo-Maxi-Miner",4,0,0,0,7,4,0,240,100,30,0,7,141,18,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,5,"Robo-Super-Miner",5,0,0,0,12,6,0,240,100,30,0,7,142,27,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,6,"Robo-Ultra-Miner",6,0,0,0,15,8,0,80,50,14,0,4,143,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,7,"Alien Miner",7,5,0,0,10,5,5,20,20,8,0,2,181,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 7,8,"Orbital Adjuster",8,0,0,0,0,0,6,80,50,25,25,25,173,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,1,"Mine Dispenser 40",1,0,0,0,0,0,0,25,45,2,10,8,128,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,2,"Mine Dispenser 50",2,2,0,0,0,0,4,30,55,2,12,10,129,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,3,"Mine Dispenser 80",3,3,0,0,0,0,7,30,65,2,14,10,130,8,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,4,"Mine Dispenser 130",4,6,0,0,0,0,12,30,80,2,18,10,131,13,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,5,"Heavy Dispenser 50",5,5,0,0,0,0,3,10,50,2,20,5,135,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,6,"Heavy Dispenser 110",6,9,0,0,0,0,5,15,70,2,30,5,136,11,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,7,"Heavy Dispenser 200",7,14,0,0,0,0,7,20,90,2,45,5,137,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,8,"Speed Trap 20",8,0,0,2,0,0,2,100,60,30,0,12,132,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,9,"Speed Trap 30",9,0,0,3,0,0,6,135,72,32,0,14,133,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 8,10,"Speed Trap 50",10,0,0,5,0,0,11,140,80,40,0,15,134,5,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,1,"Colonization Module",1,0,0,0,0,0,0,32,10,12,10,10,106,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,2,"Orbital Construction Module",2,0,0,0,0,0,0,50,20,20,15,15,107,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,3,"Cargo Pod",3,0,0,0,3,0,0,5,10,5,0,2,96,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,4,"Super Cargo Pod",4,3,0,0,9,0,0,7,15,8,0,2,97,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,5,"Multi Cargo Pod",5,5,0,0,11,5,0,9,25,12,0,3,118,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,6,"Fuel Tank",6,0,0,0,0,0,0,3,4,6,0,0,104,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,7,"Super Fuel Tank",7,6,0,4,14,0,0,8,8,8,0,0,105,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,8,"Maneuvering Jet",8,2,0,3,0,0,0,5,10,5,0,5,102,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,9,"Overthruster",9,5,0,12,0,0,0,5,20,10,0,8,103,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,10,"Jump Gate",10,16,0,20,20,16,0,10,40,0,0,50,208,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 9,11,"Beam Deflector",11,6,6,0,6,6,0,1,8,0,0,10,209,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,1,"Transport Cloaking",1,0,0,0,0,0,0,1,3,2,0,2,98,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,2,"Stealth Cloak",2,2,0,0,0,5,0,2,5,2,0,2,99,70,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,3,"Super-Stealth Cloak",3,4,0,0,0,10,0,3,15,8,0,8,100,140,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,4,"Ultra-Stealth Cloak",4,10,0,0,0,12,0,5,25,10,0,10,101,540,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,5,"Multi Function Pod",5,11,0,11,0,11,0,2,15,5,0,5,189,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,6,"Battle Computer",6,0,0,0,0,0,0,1,6,0,0,15,165,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,7,"Battle Super Computer",7,5,0,0,0,11,0,1,14,0,0,25,166,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,8,"Battle Nexus",8,10,0,0,0,19,0,1,15,0,0,30,167,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,9,"Jammer 10",9,2,0,0,0,6,0,1,6,0,0,2,120,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,10,"Jammer 20",10,4,0,0,0,10,0,1,20,1,0,5,121,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,11,"Jammer 30",11,8,0,0,0,16,0,1,20,1,0,6,122,30,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,12,"Jammer 50",12,16,0,0,0,22,0,1,20,2,0,7,123,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,13,"Energy Capacitor",13,7,0,0,0,4,0,1,5,0,0,8,127,10,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,14,"Flux Capacitor",14,14,0,0,0,8,0,1,5,0,0,8,190,20,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,15,"Energy Dampener",15,14,0,8,0,0,0,2,50,5,10,0,124,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,16,"Tachyon Detector",16,8,0,0,0,14,0,1,70,1,5,0,125,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 10,17,"Anti-matter Generator",17,0,12,0,0,0,7,10,10,8,3,3,126,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,1,"Mole-skin Shield",1,0,0,0,0,0,0,1,4,1,0,1,42,25,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,2,"Cow-hide Shield",2,3,0,0,0,0,0,1,5,2,0,2,43,40,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,3,"Wolverine Diffuse Shield",3,6,0,0,0,0,0,1,6,3,0,3,44,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,4,"Croby Sharmor",4,7,0,0,4,0,0,10,15,7,0,4,40,60,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,5,"Shadow Shield",5,7,0,0,0,3,0,2,7,3,0,3,41,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,6,"Bear Neutrino Barrier",6,10,0,0,0,0,0,1,8,4,0,4,45,100,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,7,"Langston Shell",7,12,0,9,0,9,0,10,20,10,2,6,183,125,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,8,"Gorilla Delagator",8,14,0,0,0,0,0,1,11,5,0,6,46,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,9,"Elephant Hide Fortress",9,18,0,0,0,0,0,1,15,8,0,10,47,300,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 11,10,"Complete Phase Shield",10,22,0,0,0,0,0,1,20,12,0,15,119,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,1,"Bat Scanner",1,0,0,0,0,0,0,2,1,1,0,1,59,0,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,2,"Rhino Scanner",2,0,0,0,0,1,0,5,3,3,0,2,48,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,3,"Mole Scanner",3,0,0,0,0,4,0,2,9,2,0,2,49,100,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,4,"DNA Scanner",4,0,0,3,0,0,6,2,5,1,1,1,52,125,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,5,"Possum Scanner",5,0,0,0,0,5,0,3,18,3,0,3,61,150,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,6,"Pick Pocket Scanner",6,4,0,0,0,4,4,15,35,8,10,6,56,80,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,7,"Chameleon Scanner",7,3,0,0,0,6,0,6,25,4,6,4,63,160,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,8,"Ferret Scanner",8,3,0,0,0,7,2,2,36,2,0,8,53,185,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,9,"Dolphin Scanner",9,5,0,0,0,10,4,4,40,5,5,10,54,220,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,10,"Gazelle Scanner",10,4,0,0,0,8,0,5,24,4,0,5,50,225,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,11,"RNA Scanner",11,0,0,5,0,0,10,2,20,1,1,2,60,230,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,12,"Cheetah Scanner",12,5,0,0,0,11,0,4,50,3,1,13,62,275,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,13,"Elephant Scanner",13,6,0,0,0,16,7,6,70,8,5,14,55,300,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,14,"Eagle Eye Scanner",14,6,0,0,0,14,0,3,64,3,2,21,51,335,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,15,"Robber Baron Scanner",15,10,0,0,0,15,10,20,90,10,10,10,57,220,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 12,16,"Peerless Scanner",16,7,0,0,0,24,0,4,90,3,2,30,58,500,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,1,"Tritanium",1,0,0,0,0,0,0,60,10,5,0,0,64,50,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,2,"Crobmnium",2,0,0,0,3,0,0,56,13,6,0,0,65,75,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,3,"Carbonic Armor",3,0,0,0,0,0,4,25,15,0,0,5,70,100,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,4,"Strobnium",4,0,0,0,6,0,0,54,18,8,0,0,68,120,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,5,"Organic Armor",5,0,0,0,0,0,7,15,20,0,0,6,71,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,6,"Kelarium",6,0,0,0,9,0,0,50,25,9,1,0,67,180,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,7,"Fielded Kelarium",7,4,0,0,10,0,0,50,28,10,0,2,78,175,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,8,"Depleted Neutronium",8,0,0,0,10,3,0,50,28,10,0,2,79,200,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,9,"Neutronium",9,0,0,0,12,0,0,45,30,11,2,1,69,275,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,10,"Mega Poly Shell",10,14,0,0,14,14,6,20,65,18,6,6,110,400,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,11,"Valanium",11,0,0,0,16,0,0,40,50,15,0,0,66,500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 13,12,"Superlatanium",12,0,0,0,24,0,0,30,100,25,0,0,77,1500,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,1,"Settler's Delight",1,0,0,0,0,0,0,2,2,1,0,1,8,1,0,0,0,0,0,0,0,140,275,480,576,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,2,"Quick Jump 5",2,0,0,0,0,0,0,4,3,3,0,1,0,0,0,0,25,100,100,100,180,500,800,900,1080,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,3,"Fuel Mizer",3,0,0,2,0,0,0,6,11,8,0,0,9,3,0,0,0,0,0,35,120,175,235,360,420,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,4,"Long Hump 6",4,0,0,3,0,0,0,9,6,5,0,1,1,0,0,0,20,60,100,100,105,450,750,900,1080,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,5,"Daddy Long Legs 7",5,0,0,5,0,0,0,13,12,11,0,3,2,0,0,0,20,60,70,100,100,110,600,750,900,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,6,"Alpha Drive 8",6,0,0,7,0,0,0,17,28,16,0,3,3,0,0,0,15,50,60,70,100,100,115,700,840,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,7,"Trans-Galactic Drive",7,0,0,9,0,0,0,25,50,20,20,9,4,0,0,0,15,35,45,55,70,80,90,100,120,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,8,"Interspace-10",8,0,0,11,0,0,0,25,60,18,25,10,12,5,0,0,10,30,40,50,60,70,80,90,100,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,9,"Enigma Pulsar",9,7,0,13,5,9,0,20,40,12,15,11,109,6,0,0,0,0,0,0,65,75,85,95,105,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,10,"Trans-Star 10",10,0,0,23,0,0,0,5,10,3,0,3,117,0,0,0,5,15,20,25,30,35,40,45,50,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,11,"Radiating Hydro-Ram Scoop",11,2,0,6,0,0,0,10,8,3,2,9,7,2,0,0,0,0,0,0,0,165,375,600,720,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,12,"Sub-Galactic Fuel Scoop",12,2,0,8,0,0,0,20,12,4,4,7,5,0,0,0,0,0,0,0,85,105,210,380,456,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,13,"Trans-Galactic Fuel Scoop",13,3,0,9,0,0,0,19,18,5,4,12,6,0,0,0,0,0,0,0,0,88,100,145,174,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,14,"Trans-Galactic Super Scoop",14,4,0,12,0,0,0,18,24,6,4,16,10,0,0,0,0,0,0,0,0,0,65,90,108,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,15,"Trans-Galactic Mizer Scoop",15,4,0,16,0,0,0,11,20,5,2,13,11,0,0,0,0,0,0,0,0,0,0,70,84,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
# 14,16,"Galaxy Scoop",16,5,0,20,0,0,0,8,12,4,2,9,191,4,0,0,0,0,0,0,0,0,0,0,60,0,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
