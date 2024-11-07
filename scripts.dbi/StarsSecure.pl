#!/usr/bin/perl
# StarsSecure.pl
# Scan .x files for serial/hardware conflicts
# Also tells you if the same computer is more than one player.
#
# Rick Steeves th@corwyn.net
# 211101

#     Copyright (C) 2021 Rick Steeves
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

use strict;
use warnings;   
#use warnings::unused;   
use StarsBlock; # A Perl Module from TotalHost
use StarStat; # A Perl module from TotalHost
use File::Basename;  # Used to get filename components
my ($file_prefix, $file_player, $file_type, $file_ext);
my $inDir = $ARGV[0];  # scan Directory
my $inFile = $ARGV[1]; # input file

print "\n";

if (!($inDir)) { 
  print "\nReports .x serial/hardware status.\n";
  print "\nUsage: \n\tStarsSecure.pl <File Directory> \n\n";
  print "Example: \n";
  print "\tStarsSecure.pl c:\\games\\ \n\n";
  print "If there's more than one game in the same folder, you can \n";
  print "specify the game on the command line:\n";
  print "\tStarsSecure.pl c:\\games\\ c:\\games\\Game.x1 \n\n";
  print "While this tries to protect from invalid files, it won\'t always. \n";
  print "Don\'t do that.\n";
  exit;
} 

#Validate directory existence
unless (-d $inDir ) { print "Directory: $inDir does not exist!\n"; exit;  }

# Fix if you leave the / off the directory, now OS aware
if ($inDir =~ /\\/) {
  if (substr($inDir,-1) ne '\\') {  $inDir = $inDir . '\\'; }
} elsif ( $inDir =~ /\//) {
  if (substr($inDir,-1) ne '/') {  $inDir = $inDir . '/'; }
}

# if a file is specified, check to see if it exists
if ($inFile) {
  if (-e $inFile) {
    ($file_prefix, $file_player, $file_type, $file_ext) = &FileData (basename($inFile)); 
  } else {
    print "File: $inFile does not exist!\n"; exit;
  }
}

# Read in all files in the directory $inDir and store block 9 data+ for each file
my %block9;
opendir(DIR, $inDir) or print "Directory: Can\'t opendir $inDir\n";; 
while (defined(my $file = readdir(DIR))) {  
    my $FileValues;
    my @fileBytes;
    my $filename =  $inDir . $file;
		next unless ($file =~ /^(\w+[\w.-]+\.[xX]\d{1,2})$/); # skip unless it's a .x[n] file
    print "$filename\n";
    # This regexp skips the ARGV[1] value
    # index might be better here than regexp
    #next if ($inFile && $inFile =~ /$file/i); # Skip for the case-insensitive file we started with 
    if ($inFile && !($file =~ /$file_prefix/i)) { next; } # Skip if it's a different file 
    open(StarFile, "<$filename" );
    binmode(StarFile);
    while ( read(StarFile, $FileValues, 1)) {
      push @fileBytes, $FileValues; 
    }
    close(StarFile);
  
    # Decrypt the data, block by block
    my @block9data = &decrypt_Serials(@fileBytes);
    $block9{$file} = [@block9data]; # store array in a hash
}
closedir(DIR);
print "\n";

# Loop through the stored .x files
foreach my $file1 ( sort keys %block9 ) {
  print "Checking: $file1\n";
  # Check it against all the files in the array
  foreach my $file2 ( sort keys %block9 ) {
    if ($file1 eq $file2) { next; } # if it's the same file then skip it
    # Check to see if the serial numbers are the same
    if (@{$block9{$file1}}[0] eq @{$block9{$file2}}[0]) {
      # If the serial numbers are the same, the hardware hashes must be the same
      if (@{$block9{$file1}}[1] eq @{$block9{$file2}}[1]) {
        print "\tInfo   : $file1 same serial/hardware hash as $file2\n";
      } else { 
        print "\tDANGER : $file1 same serial as $file2, but different hardware hash\n"; 
      }
    } else { 
      print "\tOK     : $file1 different serial than $file2\n"; 
    } 
  } 
  print "\n";
} 

exit;

sub decrypt_Serials {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $padding);
  my @decryptedData;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($seedA, $seedB);
  my ($FileValues, $typeId, $size);
  my $offset = 0; #Start at the beginning of the file
  my ($hardware, $serial);
  
  ###########################################################################
  # Because we're just reading a directory, validate that what we're reading
  # is actually a Stars! file
  $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
  ($typeId, $size) = &parseBlock($FileValues, $offset);
  @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
  ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
  unless ($Magic eq 'J3J3') { print "\tNon-Stars! .x file detected. Exiting..."; exit;}
  ##########################################################################3

  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ($typeId, $size) = &parseBlock($FileValues, $offset);
    # increased performance by not defining @data AND @block by shift'ing it twice
    #    true across all the copies of this function
    #@data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    if ($typeId == 8) { # File Header Block, never encrypted
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block );
      ($seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
    } else {
      # Everything else needs to be decrypted
       shift @block; # Drop the first two entries so we wouldn't need @data;
       shift @block; # and instead could use @block
      #($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@block, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 9) {
        #// szWork[0] - szWork[3] : Label C:
        #// szWork[4] - szWork[5] : C: date/time of volume
        #// szWork[6] - szWork[8] : Label D:
        #// szWork[9]             : D: date/time of volume
        #// szWork[10]            : C: and D: drive size in 100's of MB

        $serial = &read32(\@decryptedData, 2);  # serial number, blocks 2-5
        $hardware = pack("C*", @decryptedData[6..16]); #get the hardware hash as a string
        return ($serial, $hardware); # might as well stop immediately
      }
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
}

