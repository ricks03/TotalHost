#!/usr/bin/perl
# movie_starmapper.pl
# Stars Movie Creator
# For use with starmapper 1.21
# Rick Steeves th@corwyn.net
# 200226
# version .03

#     Copyright (C) 2012 Rick Steeves
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

# Backs up game and history
# Resets passwords on .m files, and find the race names
# Creates all of the .map file and .pla files to generate "movies" from Starmapper
# Creates Starmapper .ini file
#     <gamefile>.ini
# Creates batch file to run Starmapper 
#     starmapper_<gamefile>.bat - run Starmapper for each year to create .pcx files
# Creates batch to run ImageMagick
#     image_<gamefile>.bat  - convert Starmapper .pcx files to animated movie_GameFile.gif
# Runs batch files systematically

# Assumes that the stars turn files are available in some structure 
# (currently <whatever>\<year>)

#use strict; 
#use warnings;

use File::Copy;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Path 'rmtree';
use TotalHost;
use StarsBlock;
do 'config.pl';

# # Location of Stars! EXE (see config.pl)
# my $executable= 'D:\TH\Stars!\stars26j\stars.exe';
# # Location of ImageMagic convert applications
# my $imagemagick = 'C:\Program Files\ImageMagick-6.8.3-Q16\convert';
# # Location of the starmapper executable (Java)
# my $starmapper = 'd:\th\utils\starmapper\starmapper121\starmapper.bat';

my @singularRaceNames;
my @AllDirs; # The list of all directories
my $dirname; # individual directory name
my $filename; # individual file name

# Name of the Game (the prefix for the .xy file)
my $GameFile = 'CFDE7F2C';  
my $sourcedir = $FileHST . '\\' . $GameFile;
# Where to output the .ini, .pcx, and .bat files
my $destdir = $sourcedir . '.mov';
# Where final GIF will live
my $moviePath = $FileDownloads . '\\movies';

#StarMapper
my $DataOutFile;
my @numbers;
my $number; 
my $file1;
my $file2;

# Copy/Backup all the game files to a different location, as we'll be changing them.
dircopy($sourcedir, $destdir);

# Get all of the years  from the backup subdirectories
# Expectation is folder is turn/year
opendir(DIRS, $destdir) || die("Cannot open $destdir\n"); 
@AllDirs = readdir(DIRS);
closedir(DIRS);

# Get the race names, and remove passwords
# Loop through all of the directories to reset the passwords on the .m files
# On the first pass through, grab the player names
my $firstPass = 1;
foreach $dirname (@AllDirs) {
  next if $dirname =~ /^\.\.?$/; # skip . and ..
  if ($dirname =~ /BACKUP/) {  next; }  # Skip the default stars Backup folder(s)
  my $isdir = "$destdir\\$dirname";
  unless (-d $isdir) { next; } # Skip if the directory is a file
  
  opendir (DIR, "$destdir\\$dirname") or die "can't open directory $destdir\\$dirname\n";
  while (defined($filename = readdir (DIR))) {
    next if $filename =~ /^\.\.?$/; # skip . and ..
    # Grab the race names from the first .HST file
    if ($firstPass) {
      $firstPass = 0; # Don't do this again
      my $HST = "$destdir\\$dirname\\" . $GameFile . '.HST';
      &getRaceNames($HST);
#      print "Singular: @singularRaceNames" . "\n";
    }
    # Only for the .M files
    if ($filename =~ /^(\w+[\w.-]+\.[Mm]\d{1,2})$/) { 
      my $MFile = "$destdir\\$dirname\\$filename";
      print "\tMFile: $MFile\n";
      # Remove the password
      &StarsPWD($MFile);
    }
  }
  closedir(DIR);
}

# Determine the race names to provide output for StarMapper
# Race names must be the Singular
@numbers = (1.. scalar @singularRaceNames);

# Generate the Stars! data files
#   Generate the .map file (need only one)
#   Stars! -dm mygame.m1    <-- Dump the universe definition and exit
my $map;
$map = $executable;
$map .= ' -dm ' . $destdir . '\\2400\\' . $GameFile . '.m' . $numbers[0];
print "map: $map\n";
system ($map);
# copy out the map file. You need only one
$file1 = $destdir . '\\2400\\' . $GameFile . '.map';
$file2 = $destdir . '\\' .$GameFile . '.map';
print "$file1 > $file2\n";
copy("$file1","$file2") or die "Copy MAP failed: $!";
# Wait patiently, Stars! doesn't like to be launched over and over.
sleep 2;

#   Generate the .pla files
#   Stars! -dp mygame.m1    <-- Dump player 1's planets and exit
# Assumes only directories with turn files
foreach $dirname (@AllDirs) {
  my $pla;
	# Skip all . directories
	if ($dirname =~ /\./) {  next; }
	# Skip the default Stars! Backup folder(s) if present
	if ($dirname =~ /BACKUP/) {  next; }

	foreach $number (@numbers) {
		$pla = $executable;
		$pla .= ' -dp ' . $destdir . '\\' . $dirname . '\\' . $GameFile . '.m' . $number;
		#print "pla: $pla\n";
		system ($pla);
		# and move/rename the file to the format/location for starmapper
		$file1 = $destdir . '\\' . $dirname . '\\' . $GameFile . '.p' . $number;
    $file2 = $destdir . '\\' . $GameFile . ' ' . $dirname . '.p' . $number;
		print "$file1 > $file2\n";
		copy($file1,$file2) or die "Copy PLA failed for $file1, $file2: $!";
		# Wait patiently, Stars! doesn't like to be launched over and over.
		sleep 2;
	}
}

# configure the Starmapper ini file
$DataOutFile = $destdir . '\\' . $GameFile . '.ini';
open (INIFILE, ">$DataOutFile");
print INIFILE "; Starmapper ini file for $GameFile\n";
print INIFILE "[players]\n";
# display all of the players in the starmapper format
my $count = 0; 
foreach $number (@numbers) { print INIFILE 'player' . &fixlen($number) . '=' . $singularRaceNames[$count] . "\n"; $count++;}
print INIFILE "\n";
# Create the starmapper color template section
print INIFILE "[colors]\n";
print INIFILE ";here are the colors for players, overriding default colors, in rgb color space\n";
print INIFILE ";the same as with keys is with color components, but they must be >=0 and <=255\n";
print INIFILE ";grey\n";
print INIFILE "player01=192 192 192\n";
print INIFILE ";yellow\n";
print INIFILE "player02=255 255 000\n";
print INIFILE ";blue\n";
print INIFILE "player03=000 000 255\n";
print INIFILE ";orange\n";
print INIFILE "player04=255 140 000\n";
print INIFILE ";red\n";
print INIFILE "player05=255 000 000\n";
print INIFILE ";purple\n";
print INIFILE "player06=0 255 255\n";
print INIFILE ";green\n";
print INIFILE "player07=000 255 000\n";
print INIFILE ";white\n";
print INIFILE "player08=255 255 255\n";
print INIFILE ";\n";
print INIFILE "player09=000 000 175\n";
print INIFILE ";\n";
print INIFILE "player10=225 225 000\n";
print INIFILE ";\n";
print INIFILE "player11=195 195 000\n";
print INIFILE ";\n";
print INIFILE "player12=165 165 000\n";
print INIFILE ";\n";
print INIFILE "player13=000 255 255\n";
print INIFILE ";\n";
print INIFILE "player14=000 225 225\n";
print INIFILE ";\n";
print INIFILE "player15=000 195 195\n";
print INIFILE ";\n";
print INIFILE "player16=000 195 195\n";
print INIFILE "\n";
close INIFILE;

# configure the Starmapper command file
$DataOutFile = $destdir . '\\' . 'starmapper_' . $GameFile . '.bat';
open (MAPFILE, ">$DataOutFile");
my $mapfile = $starmapper . " $GameFile";
foreach $number (@numbers) { $mapfile .= " $number"; }
print MAPFILE $mapfile . "\n";
close MAPFILE;
system($DataOutFile);

# Initialize the Image command file
$DataOutFile = $destdir . '\\image_' . $GameFile . '.bat';
open (IMGFILE, ">$DataOutFile");
# Create an animated gif from the Starmapper .PCX files.
print IMGFILE "\"" . $imagemagick . "\"" . " -loop 1 -delay 100 " . " \"$destdir\\$GameFile *.PCX\" $moviePath" . '\\movie_' . "$GameFile.gif\n";
close IMGFILE;
system($DataOutFile);

if ($destdir) { rmtree($destdir) or die "$!: for directory $destdir\n"; }

##########################################
##########################################
sub fixlen {
	# If the player number is only one digit, make it two
	my ($len) = @_;
	if (length($len) == 1) { $len = "0" . $len; }
	return $len;
}

sub getRaceNames {
  my ($HST) = @_;
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  open(StarFile, "<$HST" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  # Decrypt the data, block by block
  &decryptNameBlock(@fileBytes);
}
  
################################################################
sub decryptNameBlock {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY );
  my ($blockId, $size, $data );
  my $offset = 0; #Start at the beginning of the file
  my $debug = 0;
  while ($offset < @fileBytes) {
    # Get block info and data
    ($blockId, $size, $data ) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($debug > 1) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($blockId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } elsif ($blockId == 6 ) {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      my $playerId = $decryptedData[0];
      my $fullDataFlag = ($decryptedData[6] & 0x04);
      my $index = 8;
      if ($fullDataFlag) { 
        # The player names are at the end which is not a fixed length
        $index = 112;
        my $playerRelationsLength = $decryptedData[112]; 
        $index = $index + $playerRelationsLength + 1;
      } 
      my $singularNameLength = $decryptedData[$index] & 0xFF;
      my $singularMessageEnd = $index + $singularNameLength;
      my $singularRaceName = &decodeBytesForStarsString(@decryptedData[$index..$singularMessageEnd]);
      push @singularRaceNames, $singularRaceName;
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
}