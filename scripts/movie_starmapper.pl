#!/usr/bin/perl
# movie_starmapper.pl
# Stars Movie Creator
# For use with starmapper 1.21
# Rick Steeves th@corwyn.net
# 130309
# version .02

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

# Creates all of the .map and .pla files to generate "movies" from starmapper
# And then creates batch files to create the starmap .pcx files, 
# convert the .pcx files to .jpg with ImageMagick, and then display the .jpg files
# with polyview

# Assumes that the stars turn files are available in some structure 
# (currently <whatever>\<year>)
# tho modifying that within the code is fairly simple.

# Builds a number of batch files to be run in order:
# starmapper_<gamefile>.bat - to run starmapper for each year and create the .pcx file
# image_<gamefile>.bat  - to use imagemagick to convert the .pcx files to .jpg

# It also creates a <gamefile>.pvs file to use with polyview. Copy of polyview required, 
# available at http://www.polybytes.com/
# polyview <gamefile>.pvs

# NOTE: requires/expects starmapper and polyview in the same folder

use File::Copy;

# Name of the Game (the prefix for the .xy file)
$GameFile = "seasons";  

# Stars EXE
$executable= "D:\\TH\\Stars!\\stars26j\\stars.exe";

# Location of ImageMagic convert applications
$image = "C:\\Program Files\\ImageMagick-6.8.3-Q16\\convert";

# Path of the game backups
# Assumes a structure of <path>\<turn year>
$path = "Y:\\TH\\Games\\$GameFile";

# Location of the starmap executable
$starmap = "d:\\th\\utils\\starmapper\\starmapper121\\starmapper.bat";

# Where to output the .ini, .pcx, and .bat files
$outputpath = "c:\\temp\\";

# Determine the players to provide output
@numbers = (1,2,3,4,5,6,7);
@passwords = ('','','','175','adastra','','');
# Race names must be the Singular
@names = ('Dwarf','Humanoid','Vulpine','Dharma','Xhanpharxu','Turkey','Random');

# Get a listing of all of the backup directories
$BackupDir = $path;
opendir(DIRS, $BackupDir) || die("Cannot open $BackupDir\n"); 
@AllDirs = readdir(DIRS);
closedir(DIRS);

# configure the Starmapper command file
$DataOutFile = $outputpath . "starmapper_" . $GameFile . ".bat";
open (MAPFILE, ">$DataOutFile");
$mapfile = $starmap . " $GameFile";
foreach $number (@numbers) { $mapfile .= " $number"; }
print MAPFILE $mapfile . "\n";
close MAPFILE;

# configure the Starmapper ini file
$DataOutFile = $outputpath . $GameFile . ".ini";
open (INIFILE, ">$DataOutFile");
print INIFILE "; Starmapper ini file for $GameFile\n";
print INIFILE "[players]\n";
# display all of the players in the starmapper format
$count = 0; 
foreach $number (@numbers) { print INIFILE "player" . &fixlen($number) . "=" . $names[$count] . "\n"; $count++;}
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

# Initialize the Image command file
$DataOutFile = $outputpath . $GameFile . "_image" . ".bat";
open (IMGFILE, ">$DataOutFile");
# Initialize the polyview comand file
$DataOutFile = $outputpath . $GameFile . ".pvs";
open (POLYFILE, ">$DataOutFile");

foreach $name (@AllDirs) {
	# skip the . directories
	if ($name =~ /\./) {  next; }
	# Skip the default stars backup dir, if present
	if ($name =~ /BACKUP/) {  next; }
	# Output the command to convert to jpg for imagemagik
	print IMGFILE "\"" . $image . "\"" . " \"$outputpath$GameFile $name.PCX\" $outputpath$name.jpg\n";
	# output the command for polyview to work
	print POLYFILE "\"$name.jpg\" /t1\n";
}
close IMGFILE;
close POLYFILE;

# Create the Polyvies Start File
$DataOutFile = $outputpath . "start.bat";
open (STARTFILE, ">$DataOutFile");
print STARTFILE "polyview $GameFile" . ".pvs";
close STARTFILE;

# Generate all the .map files
#   Stars! -dm mygame.m1    <-- Dump the universe definition and exit
# Generate all of the .pla files
#   Stars! -dp mygame.m1    <-- Dump player 1's planets and exit

foreach $name (@AllDirs) {
	# Skip all . directories
	if ($name =~ /\./) {  next; }
	# Sjip the default stars Backup folder if present
	if ($name =~ /BACKUP/) {  next; }

	# generate the MAP file
	$map = $executable;
	if ($passwords[$count]) { $map .= ' -p ' . $passwords[$count]; }
	$map .= ' -dm ' . $path . "\\" . $name . "\\" . $GameFile . ".m" . $numbers[0];
	print "map: $map\n";
	system ($map);

	# Generate the PLA files
	$count = 0;
	foreach $number (@numbers) {
		$pla = $executable;
		if ($passwords[$count]) { $pla .= ' -p ' . $passwords[$count]; }
		$pla .= ' -dp ' . $path . "\\" . $name . "\\" . $GameFile . ".m" . $number;
		print "pla: $pla\n";
		system ($pla);
		# and move/rename the file to the format for starmapper
		$file1 = $path . "\\" . $name . "\\" . $GameFile . ".p" . $number;
		$file2 = $outputpath . $GameFile . " " . $name . ".p" . $number;
		print "$file1 > $file2\n";
		copy("$file1","$file2") or die "Copy PLA failed: $!";
		$count++;
		# Wait patiently, stars doesn't like to be launched over and over.
		sleep 1;
	}
}

# copy out the map file. You need only one
$file1 = $path . "\\" . "2400\\" . $GameFile . ".map";
$file2 = $outputpath . $GameFile . ".map";
print "$file1 > $file2\n";
copy("$file1","$file2") or die "Copy MAP failed: $!";

##########################################
sub fixlen {
	# If the player number is only one digit, make it two
	my ($len) = @_;
	if (length($len) == 1) { $len = "0" . $len; }
	return $len;
}