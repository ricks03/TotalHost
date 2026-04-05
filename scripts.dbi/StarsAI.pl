#!/usr/bin/perl
# StarsAI.pl
# Toggles a player from Human <> Human (Inactive) 
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 200604  Version 1.0
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
# Example Usage: StarsAI.pl c:\stars\game.m1
#
# Toggles a player from Human <> Human (Inactive) 
# The password to view AI turn files is "viewai"
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  

use strict;
use warnings;   
use FindBin;
use lib $FindBin::Bin;

use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost
do 'config.pl';
my $debug = 0;

my @aiStatus = qw(Active Inactive CA PP HE IS SS AR);
my @aiSkill = qw(Easy Standard Harder Expert);
my @aiRace = ('HE', 'SS', 'IS', 'CA', 'PP', 'AR', 'Human Inactive/Expansion');
my @prts = qw (HE SS WM CA IS SD PP IT AR JOAT );

my $filename = $ARGV[0]; # input HST file
my $playerAI = $ARGV[1]; # Player number
my $newStatus  = $ARGV[2]; # The value you want the AI to be
my $outFileName = $ARGV[3]; #New file name (defaults to .ai)
# my @aiStatus = qw(Active Inactive CA PP HE IS SS AR);
# my @aiSkill = qw(Easy Standard Harder Expert);
# my @aiRace = ('HE', 'SS', 'IS', 'CA', 'PP', 'AR', 'Human Inactive/Expansion');
# my @prts = qw (HE SS WM CA IS SD PP IT AR JOAT );
my $LogFile;

if (!($filename)) { 
  print "\n\nUsage: StarsAI.pl <Game HST file> <Player 1-16> <new Player status (optional)> <output file (optional)>\n\n";
  print "Possible Player Status options: " . join(',',@aiStatus) . "\n\n";
  print "Example: \n";
  print "  StarsAI.pl c:/games/test.hst 1 Inactive\n";
  print "changes the player to Inactive\n\n";
  print "By default, a new file will be created: <filename>.ai\n";
  print "You can create a different file with StarsAI.pl <filename> <PlayerID 1-16> <new Player status> <newfilename>\n";
  print "  StarsAI.pl <filename> <PlayerID 1-16> <new Player status> <filename> will overwrite the original file.\n\n";
  print "The password to view AI turn files is \"viewai\"\n";
  print "\nAs always when using any tool, it's a good idea to back up your file(s).\n";
  exit;
}
# Validate that the file exists
if (-d $ARGV[0]) { print "$filename is a directory!\n"; exit; }
unless (-e $ARGV[0]) { print "File $filename does not exist!\n"; exit; }
if ( defined ($ARGV[1] )) {
  if ($ARGV[1] > 16 || $ARGV[1] < 1) { die "Player must be between 1 and 16\n"; }
} 

# Simpler to use 1-16 above because a null is a 0;
if (defined($playerAI)) { $playerAI--; }
#Smartmatch deprecated
#unless ($ARGV[2] ~~ @aiStatus || !defined($ARGV[2])) { print "Player status must be:  " . join(",",@aiStatus) . "\n"; exit; }

#Validates that $ARGV[2] (the newStatus) is either a value that exists in @aiStatus (Active Inactive CA PP HE IS SS AR), OR
#Not defined at all (no argument passed)
my %validStatus = map { $_ => 1 } @aiStatus;
if (defined($ARGV[2]) && !$validStatus{$ARGV[2]}) { 
    print "Player status must be: " . join(",",@aiStatus) . "\n"; 
    exit; 
}

my ($basefile, $dir, $ext);
$basefile = basename($filename);    # mygamename.m1
$dir  = dirname($filename);         # c:\stars
$dir =~ s/\\/\//g;  # normalize to forward slashes
($ext) = $basefile =~ /(\.[^.]+)$/; # .m1

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
my ($outBytes, $messages) = &decryptAI(\@fileBytes, $playerAI, $newStatus, 0); # logging
# Print all messages
foreach my $msg (@$messages) { print "$msg\n"; }

if ($outBytes) {
  my @outBytes = @{$outBytes};
  my $newFile; 
  if ($outFileName) { $newFile = $outFileName; } # Create the output file name
  else { $newFile = $dir . '/' . $basefile . '.ai'; }
  
  # Output the Stars! File with updated player status
  open (OutFile, '>:raw', "$newFile");
  for (my $i = 0; $i < @outBytes; $i++) {
    print OutFile $outBytes[$i];
  }
  close (OutFile);
  
  print "File output: $newFile\n";
  unless ($ARGV[3]) { print "Don't forget to rename $newFile\n"; }
} else { print "Nothing to do\n"; }
