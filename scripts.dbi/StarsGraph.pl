#!/usr/bin/perl
# StarsGraph.pl
# Stars Resource Graph
# Rick Steeves th@corwyn.net
# 200602

#     Copyright (C) 2020 Rick Steeves
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

# Graph the resource scores for a Stars! Game
#
# Creates gamename.png
# Assumes that the stars turn files are available in the correct structure 
# (currently <whatever>\<year>)

use strict;
use warnings;  
use FindBin;
use lib $FindBin::Bin;

use GD qw(gdTinyFont);  # for font names
use GD::Graph::lines;
use File::Basename;
use StarsBlock;

my @AllDirs; # The list of all directories
my $dirname; # individual directory name
my $debug = 0;

#########################################        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: StarsGraph.pl <game.hst>\n\n";
  print "Please enter the game HST file. Example: \n";
  print "\tStarsGraph.pl c:\\stars\\game.hst\n";
  print "\tStarsGraph.pl c:\\stars\\game.hst <destination path>\n\n";
  print "Creates a graph of a game\'s resources:\n";
  print "A new file will be created: c:\\stars\\<filename>.png or <destination path><filename>.png\n\n";
  print "This program requires a history of game files, stored in subfolders by year ( /2401/, etc.)\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
unless (-e $ARGV[0]) { print "File: $filename does not exist!\n"; exit; }

my ($basefile, $sourcedir, $ext, $prefix, $dir);
# for c:\stars\mygamename.m1
$basefile = basename($filename);    # mygamename.m1
$sourcedir  = dirname($filename);         # c:\stars
#($ext) = $basefile =~ /(\.[^.]+)$/; # .m1
($prefix, $dir, $ext) = fileparse($basefile, qr/\.[^.]*/);
my $GameFile = $prefix; # Name of the Game (the prefix for the .xy file)

unless (-d $sourcedir) { die "Directory $sourcedir does not exist!\n"; }
my $graphPath = "$sourcedir/$GameFile.png"; # Where final image will live
if ($ARGV[1]) { $graphPath= $ARGV[1] . '/' . $GameFile . '.png'; } 

# Get all of the years from the backup subdirectories
# Expectation is folder structure is game/year
opendir(DIRS, $sourcedir) || die("Cannot open $sourcedir\n"); 
@AllDirs = sort { $a <=> $b } grep { /^\d{4}$/ } readdir(DIRS);
closedir(DIRS);

# Get the race names, and resource count
# Loop through all of the directories 
# On the first pass through, grab the player names
my $firstPass = 1;
my %score; 
my $lastturn;
my $highscore=0;
my @turns;
my @singularRaceNames;
my $singularRaceNames;
my $score;

foreach $dirname (@AllDirs) {
  next if $dirname =~ /^\.\.?$/; # skip . and ..
  if ($dirname =~ /BACKUP/) { next; }  # Skip the default stars Backup folder(s)
  unless ($dirname =~ /[0-9][0-9][0-9][0-9]/) { next; }  # Skip if not a year folder
  my $isdir = "$sourcedir/$dirname";
  unless (-d $isdir) { next; } # Skip if the directory is a file
  print "Year: $dirname\n";
  push @turns, $dirname;

  # Grab race names from first year that has a .hst
  if ($firstPass) {
    my $HST = "$sourcedir/$dirname/$GameFile.hst";
    if (-f $HST) {
      $firstPass = 0; # Only set to 0 when .hst is actually found
      ($singularRaceNames, my $score) = &getScores($HST);
      @singularRaceNames = @{$singularRaceNames};
      print "Singular: @singularRaceNames\n";
    }
    # If no .hst this year, firstPass stays 1 and we try the next year
  }

  opendir(DIR, "$sourcedir/$dirname") or die "can't open directory $sourcedir/$dirname\n";
  while (defined(my $mfile = readdir(DIR))) {
    next if $mfile =~ /^\.\.?$/; # skip . and ..
    # Only for the .m files - score blocks aren't in the .hst file
    if ($mfile =~ /^(\w+[\w.-]+\.[Mm]\d{1,2})$/) {
      $lastturn = $dirname;
      my $MFile = "$sourcedir/$dirname/$mfile";
      my (undef, $score, $player) = &getScores($MFile);
      $score{$player}{$dirname} = $score; # use $dirname as key, not $turn
      #if ($score > $highscore) { $highscore = $score; }
      if (defined $score && $score > $highscore) { $highscore = $score; }
    }
  }
  closedir(DIR);
}
# Zero out year 2400 scores - starting year has no meaningful scores
foreach my $player (keys %score) {
  $score{$player}{'2400'} = 0 if exists $score{$player}{'2400'};
}

$highscore = $highscore+1000; # Just makes it graph better. 

# Determine the race names 
# Race names must be the Singular
#@numbers = (1.. scalar @singularRaceNames);

my @data;
push @data, \@turns; # put turns into data array

foreach my $playerId (sort keys %score) {
  my @pscore;
  my $lastScore = 0;
  print "Player: $playerId\t";
  foreach my $turn (@turns) {  # iterate @turns not player's own keys
    push @pscore, $score{$playerId}{$turn};  # undef if missing, GD graphs as gap
#     if (defined $score{$playerId}{$turn}) { # BG: Keep the score for missing years
#       $lastScore = $score{$playerId}{$turn};
#    }
  }
  print "score: @pscore";
  print "\n";
  push @data, \@pscore;
}

# my @data = ( [@turns],   # Turns
#              # Player 1 resources
#              [ 2,  5,  16.8,  18, 19, 22.6, 26, 32, 34, 39,
#                43, 48, 49, 49, 54.2, 58, 68, 72, 79 ],
#              # Player 2 resources
#              [ 11,  18,  29.4,  35.7, 36, 38.2, 36, 41, 45, 49,
#                50, 51, 51.4, 52.6, 53.2, 54, 67, 73, 78 ],
#              # Player 3 resources
#              [ 5,  8,  24,  32, 37, 40, 50, 55, 61, 63,
#                61, 60, 65.5, 68, 71, 69, 73, 73.5, 78, 78.5],
#              # Player 4 resources
#              [ 4.25,  8.9, 19, 21, 25, 24, 27, 29, 33, 35,
#                41, 40, 45, 42, 44, 49, 51, 58, 61, 66],
#              # Player 5 resources
#              [ 2,  11,  9,  9.2, 9.8, 10.1, 8.2, 8.5, 9, 7,
#                6, 5.5, 6.5, 5.2, 4.5, 4.2, 4, 3, 2, 1 ],
#              # Player 6 resources
#              [ 3.5,  8,  22,  22.5, 23, 25, 25, 25, 26, 21,
#                20, 19.2, 19.7, 21, 18, 23, 17, 12, 10, 5],
#              # Player 7 resources
#              [ 6.5,  12.8,  31.7,  34, 32, 29, 19, 20.5, 28, 35,
#               34, 33, 30, 28, 25, 21, 20, 16, 11, 9]
#      );

my $graph = new GD::Graph::lines( );
    
$graph->set(
        title             => "$GameFile",
        x_label           => 'Year',
        y_label           => 'Resources',
        y_max_value       => $highscore,
        x_tick_number     => 'auto',
        y_tick_number     => 10,
        x_all_ticks       => 1,
        y_all_ticks       => 0,
        y_label_skip      => 3,
        y_number_format   => '%d',
        transparent       => 0,
        bgclr             => 'white',
    );

$graph->set_legend_font(gdTinyFont);
$graph->set_legend(@singularRaceNames);

my $gd = $graph->plot( \@data );
open OUT, ">$graphPath" or die "Couldn't open for output: $!";
binmode(OUT);
print OUT $gd->png( );
close OUT;

print "$graphPath created!\n";