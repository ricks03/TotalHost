# StarsClean.pl
# Clean shared information out of .m files
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191114 - Started dev
# 191122 - Added player read
# 191123 - Added CA clean
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

# Removes "privileged" information from a .m file
#
# .m files include other player information about:
#    Mystery Trader (tech offered and who has met with him)
#    wormholes (who can and can't see, who has jumped in and who hasn't)
#    minefields (who can see it)
#    CA (more player information on other races than appropriate)

# Example Usage: StarsClean.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
# And takes inspiration from Xyligun's StarsKnowledgeCleaner.exe

#Some of the bytes in minefields differ from player to player inexplicably

#Currently:
# Cleans MT cargo (sets to "research")
# Cleans who has visited mystery trader (only player)
# Cleans who has seen minefields (only player)
# Cleans who has seen wormholes (only player)
# Cleans who has been through a wormhole (only player)
# Cleans CA known player information

use strict;
use warnings;   
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
my $debug = 0; # Enable better debugging output. Bigger the better
my $cleanFiles = 1; # 0, 1, 2: display, clean but don't write, write 

# For Object Block 43 
my $objectId;    
my $count = -1;
my $number;
my $owner;
my $type; # 0 = minefield, 1 = packet/salvage, 2 = wormhole, 3 = MT
my ($x, $y);
# For MT
my ($xDest, $yDest);
my $warp;
my $metBits;
my $itemBits;
my $turnNo;
my $turnNoDisplay;
#For minefields
my $mineCount;
my $mineDetonate;
my $mineType;
#For wormholes
my $wormholeId;
my $targetId;
my $beenThrough;    
my $canSee;
my $stability;
# For packets
my $targetAndSpeed;
my ($destPlanetId, $WarpSpeedMinus4, $WarpOverMDLimit);
my ($ironium, $boranium, $germanium);
#holding values for unknown variables
my ($unk1, $unk2, $unk3, $unk4, $unk5) = '';  

# For Player Block 6
my $playerId;  # int , 1 byte
my $ShipSlotsUsed;   # intm 1 byte
my $PlanetCount;       # int, 2 bytes
my $FleetAndStarBaseDesignCount;        # int , 2 bytes
my $FleetCount; # 12 bits
my $StarBaseDesignCount; # 4 bits
my $logo;          # int
my $fullDataFlag;  # boolean
my $fullDataBytes; # byte
my $playerRelations; # byte, 0 neutral, 1 friend, 2 enemy
my $nameBytes;     #byte
my $byte7 = 1;
my @singularRaceName;
my @pluralRaceName;

#my @resetRace =  ( 0,6,2,0,6,16,15,1,81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,2,2,6,183,222,219,22,116,214,7,183,222,219,22,116,214 );
# The values used when cleaning race values. Defaults to Humanoids
my @resetRace =  ( 81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 );

##########  
my @fileBytes;
my @mFiles;      
my $inName = $ARGV[0]; # input file
my $outName = $ARGV[1];
my $filename;

if (!($inName)) { 
  print "\n\nRemoves other player minefield, MT, wormhole, and race information from .M files.\n";
  print "\n\nUsage: StarsClean.pl <input> <output (optional)>\n\n";
  print "Please enter the .M input. Example: \n";
  print "  StarsClean.pl c:\\games\\test.m6\n\n";
  print "For files, by default, a new file will be created: <filename>.clean\n\n";
  print "You can create a different file with: StarsClean.pl <filename> <newfilename>\n";
  print "  StarsClean.pl <filename> <filename> will overwrite the original file.\n\n";
  print "Also works for all .M files in a directory. Example: \n";
  print "  StarsClean.pl c:\\games\n";
  print "  or\n"; 
  print "  StarsClean.pl c:\\games1 c:\\games2  <directory2 must exist>\n\n";
  print "  StarsClean c:\\games c:\\games will overwrite the local files.\n\n";
  print "The script will try to save you if you choose file and directories poorly,\n";
  print "  but as always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

#Validate directory or file 
unless (-d $inName || -e $inName ) { 
  print "Requested object: $inName does not exist!\n"; exit; 
}

# Get all the file names in the directory, or just the one name
# Note that directories test for files, but files don't test
# for directories
if (-d $inName) {  
  # If a directory name was specified
  my $file;
  my $fullName;
  opendir(BIN, $inName) or die "Cannot open directory $inName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
    $fullName = $inName . '\\' . $file;
    push @mFiles, $fullName;
  }
} elsif (-e $inName) { 
  # If a .m file name was specified
  if ($inName =~ /^.*\.[mM]\d*$/) {   $mFiles[0] = $inName; }
}

if (@mFiles == 0) { 
  die "Something went wrong. There\'s no information\nDid you specify a .M file?\n"; 
}

foreach $filename (@mFiles) {
# Loop through for each .m file in the directory
# and clean it
  my ($basefile, $dir, $ext);
  # for c:\stars\mygamename.m1
  $basefile = basename($filename);    # mygamename.m1
  $dir  = dirname($filename);         # c:\stars
  ($ext) = $basefile =~ /(\.[^.]+)$/; # .m  extension
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  @fileBytes = ();
  open(StarFile, "<$filename" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my ($outBytes, $needsCleaning) = &decryptClean(@fileBytes);
  my @outBytes = @{$outBytes};
  
  # Create the output file name(s)
  # taking into account the paths provided. 
  my $newFile; 
  if (-e $inName) {
    # if the outName was defined
    if ($outName) {   $newFile = $outName;  } 
    # Otherwise, safety first
    else { $newFile = $dir . '\\' . $basefile . '.clean'; }
    # and because I dont like fiddling with it when debugging
    if ($debug) { $newFile = "f:\\clean_" . $basefile;  } # Just for me
  } elsif (-d $inName && $inName eq $outName ) {
    # if inName was a directory, and outName is the same location
    # overwrite the existing files
    $newFile = $dir . '\\' . $basefile;
  } elsif (-d $outName) {
    # Otherwise create the files in the new location.   
    $newFile = $outName . '\\' . $basefile; 
  } else { die "What happened to the name?\n"; }
  
  # Output the Stars! File with modified data
  # Don't do unless in clean write mode and needsCleaning
  if ($cleanFiles > 1 && $needsCleaning) {
    open ( CLEANFILE, '>:raw', "$newFile" );
    for (my $i = 0; $i < @outBytes; $i++) {
      print CLEANFILE $outBytes[$i];
    }
    close ( CLEANFILE);
    
    print "File output: $newFile\n";
    unless ($ARGV[1] || -d $inName ) { print "Don't forget to rename $newFile\n"; }
  }
} 

