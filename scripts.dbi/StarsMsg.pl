#!/usr/bin/perl
# StarsMsg.pl
# Displays Stars! Messages
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 191119 , 191126, 191203
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

# Example Usage: StarsMsg.pl c:\stars\game.m1
#
# Derived from decryptor.py and decryptor.java from
# https://github.com/stars-4x/starsapi  
#
# Displays player messages
# .hst files don't have message blocks.

use strict;
use warnings;  
use FindBin;
use lib $FindBin::Bin;
 
use File::Basename;  # Used to get filename components
use StarsBlock; # A Perl Module from TotalHost

my @Files; # .m files in the directory
my @mDirs; # subdirs with turns in them     
my $inName = $ARGV[0]; # input file
my $filename = $inName;

if (!($inName)) { 
  print "\n\nDisplays the Player Messages in a Stars! file (.x, .m).\n";
  print "\nUsage: StarsMsg.pl <input> \n";
  print "  StarsMsg.pl c:\\games\\test.m6\n\n";
  print "  StarsMsg.pl c:\\games\\test.x6\n\n";
  print "  StarsMsg.pl c:\\games will list all messages in the folder\n";
  print "    If there are 2xxx subfolders, it will scan through those too!\n";
  exit;
}

print "FileName: $inName\n"; 

#Validate directory or file 
unless (-e $inName || -d $inName) { 
  print "Requested object: $inName does not exist!\n"; exit; 
}

# Get all the file names in the directory, or just the one name
# Note that directories test for files, but files don't test
# for directories
#if (-e $inName && -f _) { 
if (-e $inName && -f $inName) { # if it exists, and it's just a file (not a directory)
  # If a single .m or .x file name was specified
  if ($inName =~ /^.*\.[MmXx]\d*$/) { $Files[0] = $inName; }
  else { die "File $inName does not appear to be a .m or .x file\n"; }
} elsif (-d $inName) {  
  # If a directory name was specified
  my $file;
  opendir(BIN, $inName) or die "Cannot open directory $inName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    # Add any subdirs in the right format
    if ( $file =~ /^2[0-9][0-9][0-9]/ ) { # won't work if into the turn 3xxx but whatever
      push @mDirs, "$inName/$file";
      next;
    }
    next unless ($file =~ (/^.*\.(m|x)$/i)); #prefiltering for .m and .x files
    push @Files, "$inName/$file";
  }
}

# OK, now lets get all the files from any potential backup subdirectories
foreach my $dirName (@mDirs) {
  my $file;
  opendir(BIN, $dirName) or die "Cannot open directory $dirName\n";
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~ /^.*\.(m|x|hst)$/i); #prefiltering for .m / .x / .hst files
    push @Files, "$dirName/$file";
    print "Backups: $dirName/$file\n";
  }
}

if (@Files == 0) { 
  die "Something went wrong. There\'s no information.\nDid you specify a .m, or .x[n] file?\n"; 
}

my ($basefile, $dir, $ext);   
foreach $filename (@Files) {
  print "Loop directory: Filename $filename\n";
  # Loop through for each .m|x file in the directory
  $basefile = basename($filename);    # mygamename.m1
  $dir  = dirname($filename);         # c:\stars
  $dir =~ s/\\/\//g;  # normalize to forward slashes
  ($ext) = $basefile =~ /(\.[^.]+)$/; # .m1  extension
  
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  print "\nFor File: $filename\n";
  open(StarFile, "<$filename" );
  binmode(StarFile);
  while ( read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  my ($outBytes, $messages) = &decryptMessages(\@fileBytes, $ext);
  my @messages = @{ $messages };
  unless (scalar (@messages)) { print "No message(s) found.\n" };  
  foreach my $message (@messages) {
    print $message;
  }
}
