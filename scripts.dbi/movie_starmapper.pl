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

# This pulls the turns from the TH backup dir(s), so the last turn will only be
# there if the game is ended.
use File::Copy;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Path 'rmtree';
do 'config.pl';
use TotalHost;
use StarsBlock;

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


my $GameFile = $ARGV[0]; # input file
if (!($GameFile)) { 
  print "\n\nUsage: movie_starmapper.pl <game file prefix>\n\n";
  print "Please enter the game file name. Example: \n";
  print "  movie_starmapper.pl abdd466g\n\n";
  print "Creates a map of a game\'s play:\n";
  print "A new file will be created: <filename>.mov\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}

# Name of the Game (the prefix for the .xy file)
my $sourcedir = "$Dir_Games/$GameFile";
# Where to output the .ini, .pcx, and .bat files
my $destdir = $sourcedir . '.mov';
# Where final GIF will live
my $moviePath = $Dir_Graphs . '/movies';

#StarMapper
my $DataOutFile;
my @numbers;
my $number; 
my $file1;
my $file2;

# Copy/Backup all the game files to a different location, as we'll be changing them.
print "Backing up files from $sourcedir to $destdir\n";
dircopy($sourcedir, $destdir);

# Get all of the years  from the backup subdirectories
# Expectation is folder is turn/year
opendir(DIRS, $destdir) || die("Cannot open $destdir\n"); 
@AllDirs = sort readdir(DIRS);
closedir(DIRS);
# Include only directories with exactly four digits in their names
@AllDirs = grep { /^\d{4}$/ } @AllDirs;

# Get the race names, and remove passwords
# Loop through all of the directories to reset the passwords on the .m files
# On the first pass through, grab the player names
my $firstPass = 1;
foreach $dirname (@AllDirs) {
  next if $dirname =~ /^\.\.?$/; # skip . and ..
  if ($dirname =~ /BACKUP/) {  next; }  # Skip the default stars Backup folder(s)
  my $isdir = "$destdir/$dirname";
  print "isdir: $isdir\n";
  unless (-d $isdir) { next; } # Skip if the directory is a file
  print "IsDir = $isdir\n";
  opendir (DIR, "$destdir/$dirname") or die "can't open directory $destdir/$dirname\n";
  while (defined($filename = readdir (DIR))) {
    next if $filename =~ /^\.\.?$/; # skip . and ..
    # Grab the race names from the first ..hst file
    if ($firstPass) {
      $firstPass = 0; # Don't do this again
      my $HST = "$destdir/$dirname/" . $GameFile . '.hst';
      if (-e $HST) {
        @singularRaceNames = &getRaceNames($HST);
        print "Singular Race Names: @singularRaceNames" . "\n";
      } else { die ".hst file $HST not found\n"; }
    }
    # Only for the .m files
    if ($filename =~ /^(\w+[\w.-]+\.[Mm]\d{1,2})$/) { 
      my $MFile = "$destdir/$dirname/$filename";
      print "\tRemoving Password: $MFile\n";
      # Remove the password
      &StarsPWD($MFile);
    }
  }
  closedir(DIR);
  print "\n";
}

# Determine the race names to provide output for StarMapper
# Race names must be the Singular
@numbers = (1.. scalar @singularRaceNames);

# Generate the Stars! data files
#   Generate the .map file (need only one)
#   Stars! -dm mygame.m1    <-- Dump the universe definition and exit
my $map;
$map = $WINE_executable . ' -dm ' .  "$Dir_WINE\\$WINE_Games\\\\$GameFile\.mov" . "\\\\2400\\\\$GameFile" . '.m' . $numbers[0];

print "DM: $map\n";

my $exit_status = &call_system ($map);
# copy out the map file. You need only one
$file1 = $destdir . '/2400/' . $GameFile . '.map';
$file2 = $destdir . '/' . uc($GameFile) . '.MAP';
print "Copy $file1 > $file2\n";
copy("$file1","$file2") or die "Copy MAP failed: $!";
# Wait patiently, Stars! doesn't like to be launched over and over.
sleep 2;

#   Generate the .pla files
#   Stars! -dp mygame.m1    <-- Dump player 1's planets and exit
# Assumes only directories with turn files
print "Moving on to PLA files\n";
foreach $dirname (@AllDirs) { # Dirname is the year value
  my $pla;
	# Skip all . directories
	if ($dirname =~ /\./) {  next; }
	# Skip the default Stars! Backup folder(s) if present
	if ($dirname =~ /BACKUP/) {  next; }

	foreach $number (@numbers) {
  
#   	$pla = $executable;
# 		$pla .= ' -dp ' . $destdir . '\\' . $dirname . '\\' . $GameFile . '.m' . $number;
# 		$file1 = $destdir . '\\' . $dirname . '\\' . $GameFile . '.p' . $number;
#     $file2 = $destdir . '\\' . $GameFile . ' ' . $dirname . '.p' . $number;  

		$pla = $WINE_executable . " -dp  $Dir_WINE\\$WINE_Games\\\\$GameFile\.mov\\\\$dirname\\\\$GameFile" . '.m' . $number;
    print "DP: $pla\n";
		$file1 = "$destdir/$dirname/$GameFile" . '.p' . $number;
    $file2 = "$destdir/$GameFile $dirname" . '.p' . $number;
		#print "pla: $pla\n";
    unless (-e $file2) {  # If the file is already there, no need to create
  		my $exit_status = &call_system($pla);
  		# and move/rename the file to the format/location for starmapper
  		print "$file1 > $file2\n";
  		copy($file1,$file2) or die "Copy PLA failed for $file1, $file2: $!";
  		# Wait patiently, Stars! doesn't like to be launched over and over.
  		sleep 2;
    }
	}
}

# configure the Starmapper ini file
#$DataOutFile = $destdir . '\\' . $GameFile . '.ini';
$DataOutFile = $destdir . '/' . $GameFile . '.ini';
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
print INIFILE ";blue\n";
print INIFILE "player02=000 000 255\n";
print INIFILE ";orange\n";
print INIFILE "player03=255 140 000\n";
print INIFILE ";red\n";
print INIFILE "player04=255 000 000\n";
print INIFILE ";cyan\n";
print INIFILE "player05=0 255 255\n";
print INIFILE ";green\n";
print INIFILE "player06=000 255 000\n";
print INIFILE ";yellow\n";
print INIFILE "player07=255 255 000\n";
print INIFILE ";white\n";
print INIFILE "player08=255 255 255\n";
print INIFILE ";\n";
print INIFILE "player09=000 000 175\n";
print INIFILE ";teal\n";
print INIFILE "player10=0 128 128\n";
print INIFILE ";purple\n";
print INIFILE "player11=128 0 128\n";
print INIFILE ";violet\n";
print INIFILE "player12=238 130 238\n";
print INIFILE ";fuchsia\n";
print INIFILE "player13=255 0 255\n";
print INIFILE ";teal\n";
print INIFILE "player14=000 225 225\n";
print INIFILE ";thistle\n";
print INIFILE "player15=216 191 216\n";
print INIFILE ";\n";
print INIFILE "player16=000 195 195\n";
print INIFILE "\n";
close INIFILE;

# configure the Starmapper command file
# my $starmapper = 'd:\th\utils\starmapper\starmapper121\starmapper.bat';
#$DataOutFile = $destdir . '\\' . 'starmapper_' . $GameFile . '.bat';
$MapOutFile = $destdir . '/' . 'Starmapper_' . $GameFile . '.sh';
open (MAPFILE, ">$MapOutFile");
my $mapfile = $starmapper . " $GameFile";
foreach $number (@numbers) { $mapfile .= " $number"; }
print MAPFILE $mapfile . "\n";
close MAPFILE;
chmod 0770, $MapOutFile;
chdir $destdir;
$exit_status = &call_system($MapOutFile); # Run starmapper

# Initialize the Image command file
if (-f $MapOutFile) {
  $ImgOutFile = $destdir . '/image_' . $GameFile . '.sh';
  open (IMGFILE, ">$ImgOutFile");
  # Create an animated gif from the Starmapper .PCX files.
  # my $imagemagick = 'C:\Program Files\ImageMagick-6.8.3-Q16\convert';
  #print IMGFILE "\"" . $imagemagick . "\"" . " -loop 1 -delay 100 " . " \"$destdir\\$GameFile *.PCX\" $moviePath" . '\\movie_' . "$GameFile.gif\n";
  print IMGFILE $imagemagick . " -loop 1 -delay 100 " . " \"$destdir/$GameFile *.pcx\" $moviePath" . "/$GameFile.gif\n";
  close IMGFILE;
  chmod 0770, $ImgOutFile;
  $exit_status = &call_system($ImgOutFile);  # Run imagemagic (requires successful starmapper)
  $GifFile = "$Dir_Graphs/movies/$GameFile.gif";
  chmod 0440, $GifFile; 
} else { print "Can\'t create $ImgOutFile, because $MapOutFile is missing"; }


die "Done! Delete the folder $destdir\n";
#if ($destdir) { rmtree($destdir) or die "$!: for directory $destdir\n"; }

##########################################
##########################################
sub fixlen {
	# If the player number is only one digit, make it two
	my ($len) = @_;
	if (length($len) == 1) { $len = "0" . $len; }
	return $len;
}



