#!/usr/bin/perl
# graph_score.pl
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
# Creates graph_gamename.   png
# Assumes that the stars turn files are available in some structure 
# (currently <whatever>\<year>)

#use warnings;

use GD;      # for font names
use GD::Graph::lines;
use StarsBlock;
do 'config.pl';

my @singularRaceNames;
my @AllDirs; # The list of all directories
my $dirname; # individual directory name

#########################################        
my $filename = $ARGV[0]; # input file
if (!($filename)) { 
  print "\n\nUsage: graph_score.pl <input file>\n\n";
  print "Please enter the game file name. Example: \n";
  print "  graph_score.pl abdd466g\n\n";
  print "Creates a graph of a game\'s resources:\n";
  print "A new file will be created: <filename>.png\n\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}


# Name of the Game (the prefix for the .xy file)
my $GameFile = $filename;  
my $sourcedir = $FileHST . '\\' . $GameFile;
unless (-d $sourcedir) { die "Directory $sourcedir does not exist!\n"; }
# Where final image will live
my $graphPath = $FileDownloads . '\\graphs' . '\\' . $filename . '.png';

# Get all of the years from the backup subdirectories
# Expectation is folder is turn/year
opendir(DIRS, $sourcedir) || die("Cannot open $sourcedir\n"); 
@AllDirs = readdir(DIRS);
closedir(DIRS);

# Get the race names, and resource count
# Loop through all of the directories 
# On the first pass through, grab the player names
my $firstPass = 1;
my %score; 
my $lastturn;
my $highscore=0;
my @turns;
foreach $dirname (@AllDirs) {
  next if $dirname =~ /^\.\.?$/; # skip . and ..
  if ($dirname =~ /BACKUP/) {  next; }  # Skip the default stars Backup folder(s)
  my $isdir = "$sourcedir\\$dirname";
  unless (-d $isdir) { next; } # Skip if the directory is a file
  print "Year: $dirname\n";
  push @turns, $dirname;
  opendir (DIR, "$sourcedir\\$dirname") or die "can't open directory $sourcedir\\$dirname\n";
  while (defined($filename = readdir (DIR))) {
    next if $filename =~ /^\.\.?$/; # skip . and ..
    # Grab the race names from the first .HST file
    if ($firstPass) {
      $firstPass = 0; # Don't do this again
      my $HST = "$sourcedir\\$dirname\\" . $GameFile . '.HST';
      if (-e $HST) {
        ($singularRaceNames, $score) = &getRaceNames($HST);
        @singularRaceNames = @{$singularRaceNames};
        print "Singular: @singularRaceNames" . "\n";
      } else { die "HST file $HST not found\n"; }
    }
    # Only for the .M files
    if ($filename =~ /^(\w+[\w.-]+\.[Mm]\d{1,2})$/) { 
      $lastturn = $dirname;
      my $MFile = "$sourcedir\\$dirname\\$filename";
      my ($singularRaceNames, $score, $turn, $player) = &getRaceNames($MFile);
      if ($dirname eq '2400') { $score = 0; }
      print "\tScore: $player, $score\n";
      $score{$player}{$turn} = $score;
      if ($score > $highscore) { $highscore = $score; }
    }
  }
  closedir(DIR);
}
$highscore = $highscore+1000; # Just makes it graph better. BUG: Should probably also round it to the nearest 10000

# Determine the race names 
# Race names must be the Singular
#@numbers = (1.. scalar @singularRaceNames);

print "TURNS: @turns\n";
push @data, \@turns; # put turns into data array

foreach my $playerId (sort keys %score) {
  my @pscore;
  print "Player: $playerId\n";
  foreach my $turn (sort {$score{$playerId}{$a} <=> $score{$playerId}{$b}} keys %{ $score{$playerId} }) {
    print "turn: $turn\t";
    print "$score{$playerId}{$turn}\t";
    print "\n";
    push @pscore,$score{$playerId}{$turn};
  }
  push @data, \@pscore;
  print "\n";
}


# Just need to figure out how to convert the player scores into an array

# my @data = ( [@turns],   # Turns
# 
#              # Player 1 resources
#              [ 2,  5,  16.8,  18, 19, 22.6, 26, 32, 34, 39,
#                43, 48, 49, 49, 54.2, 58, 68, 72, 79 ],
# 
#              # Player 2 resources
#              [ 11,  18,  29.4,  35.7, 36, 38.2, 36, 41, 45, 49,
#                50, 51, 51.4, 52.6, 53.2, 54, 67, 73, 78 ],
# 
#              # Player 3 resources
#              [ 5,  8,  24,  32, 37, 40, 50, 55, 61, 63,
#                61, 60, 65.5, 68, 71, 69, 73, 73.5, 78, 78.5],
# 
#              # Player 4 resources
#              [ 4.25,  8.9, 19, 21, 25, 24, 27, 29, 33, 35,
#                41, 40, 45, 42, 44, 49, 51, 58, 61, 66],
# 
#              # Player 5 resources
#              [ 2,  11,  9,  9.2, 9.8, 10.1, 8.2, 8.5, 9, 7,
#                6, 5.5, 6.5, 5.2, 4.5, 4.2, 4, 3, 2, 1 ],
# 
#              # Player 6 resources
#              [ 3.5,  8,  22,  22.5, 23, 25, 25, 25, 26, 21,
#                20, 19.2, 19.7, 21, 18, 23, 17, 12, 10, 5],
# 
#              # Player 7 resources
#              [ 6.5,  12.8,  31.7,  34, 32, 29, 19, 20.5, 28, 35,
#               34, 33, 30, 28, 25, 21, 20, 16, 11, 9]
#      );

my $graph = new GD::Graph::lines( );
# $graph->set(
#         title             => "$GameFile",
#         x_label           => 'Year',
#         y_label           => 'Resources',
#         y_max_value       => $highscore,
#         y_tick_number     => 500,
#         x_all_ticks       => 1,
#         y_all_ticks       => 1,
#         x_label_skip      => 3,
#     );
    
$graph->set(
        title             => "$GameFile",
        x_label           => 'Year',
        y_label           => 'Resources',
        y_max_value       => $highscore,
        y_label_skip      => 3,
        y_tick_number     => 10,
        y_number_format   => '%d',
        x_tick_number     => 'auto',
        x_all_ticks       => 1,
    );


$graph->set_legend_font(GD::gdFontTiny);
$graph->set_legend(@singularRaceNames);

my $gd = $graph->plot( \@data );

open OUT, ">$graphPath" or die "Couldn't open for output: $!";
binmode(OUT);
print OUT $gd->png( );
close OUT;

#####################################
sub getRaceNames {
  my ($HST) = @_;
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  my @singularRaceNames;
  open(StarFile, "<$HST" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  # Decrypt the data, block by block
  my ($singularRaceNames, $score, $turn, $player) = &decryptNameBlock(@fileBytes);
  @singularRaceNames = @{$singularRaceNames};
#  @score = @{$score};
  return \@singularRaceNames, $score, $turn, $player;
}

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
  my @singularRaceNames;
  my %score;
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
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };  
      # WHERE THE MAGIC HAPPENS
      if ($blockId == 6 ) {  #PlayerBlock
        my $playerId = $decryptedData[0] & 0xFF;
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
      } elsif ($blockId == 45) { # PlayerScoresBlock
        my $playerId     = ($decryptedData[0] >> 0) & 0x0F; 
        my $resources    = &read16(\@decryptedData, 8); # Not EXACTLY the same
#        print "PlayerId: $playerId, Res: $resources\n";
        if ($Player == $playerId) { $score = $resources; }
      }
    }
    # END OF MAGIC
    $offset = $offset + (2 + $size); 
  }
  return \@singularRaceNames, $score, $turn, $Player;
}