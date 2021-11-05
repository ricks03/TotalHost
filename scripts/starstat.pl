#!/usr/bin/perl
# starstat.pl
# Read in the data from any stars file to validate it.
# Rick Steeves th@corwyn.net
# 120129, 201105
# Version 1.2
# Updated for multi-year files


#     Copyright (C) 2012 Rick Steeves
# 
#     This program is free software: you can redistribute it and/or modify
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

@dt_verbose = ('Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File');
@dt = ('XY', 'Log', 'Host', 'Turn', 'Hist', 'Race', 'Max');
@fDone = ('Turn Saved','Turn Saved/Submitted');
@fMulti = ('Single Turn', 'Multiple Turns');
@fGameOver = ('Game In Progress', 'Game Over'); 
@fShareware = ('Registered','Shareware'); 
@fInUse = ('Host instance not using file','Host instance using file'); 
%Version = ('1.2a' => '1.1a', '2.65' => '2.0a', '2.81j' => '2.6i', '2.83.0' => '2.6jrc4');

use constant  dtXY   => 0; 
use constant  dtLog  => 1; 
use constant  dtHost => 2; 
use constant  dtTurn => 3; 
use constant  dtHist => 4; 
use constant  dtRace => 5;
use constant  dtMax  => 6;

my $filename = $ARGV[0];
if ($filename eq '') { print "Displays status information about a Stars! game file.\n\tPlease enter the file to examine. Example c:\\games\\meat.m6.\n"; die; }
else { print "File is $filename\n"; }
##########################
open(StarFile, "$filename") || die "Unable to open $filename for reading.";
binmode(StarFile);
read(StarFile, $FileValues, 22);
seek (StarFile, -2, 2);
read (StarFile, $lasttwo, 2);
close(StarFile);

# 2 bytes: Header
# 4 bytes: (0/3): Magic
# 4 bytes: (4/7): GameID
# 2 bytes: (8/9): version
# 2 bytes: (10/11): turn number
# 2 bytes: (12/13): Player and encryption seed
# 1 byte: File type
#   Bit 0 (1) - Turn Submitted
#   Bit 1 (2) - Host is using file
#   Bit 2 (4) - Multiple turns in .m file
#   Bit 3 (8) - Game over
#   Bit 4 (16)- Shareware Version

# BUG: At some point I changed this string to SA4LSSsS but I don't
# know why, and then it didn't line up with statstat.pl	
# The chase is A2 to S (string) and h8 to L (which is probably a long)
#  $unpack = "A2A4h8SSSS";
	$unpack = "SA4LSSsS";
#$Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts
@FileValues = unpack($unpack,$FileValues);
($Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts) = @FileValues;

unless ( $Magic == 'J3J3' ) { die "StarStat: $filename does not appear to be a Stars! File.\n"; }

print join(',', @FileValues) . "\n";
#print "Header\t$Header\n"; #Header
print "Magic:\t$Magic\n"; #
print "lidGame:\t$lidGame\n"; 

# Game Version
$ver = dec2bin($ver);
$verInc = substr($ver,11,5);
$verMinor = substr($ver,4,7);
$verMajor = substr($ver,0,4);
$verMajor = bin2dec($verMajor);
$verMinor = bin2dec($verMinor);
$verInc = bin2dec($verInc);
#$verInc = $ver & 0x1F; #five leftmost bits 000xxxxx
#$verMinor = $ver & 1E0; #00000000xxx00000
#$verMajor = $ver & F000; #xxxx000000000000
$ver = "$verMajor" . "." . "$verMinor" . "." . "$verInc";

print "Version:\t$ver (" . $Version{$ver} . ")\n";

# Turn
$turn=$turn + 2400;
print "turn:\t$turn\n";

# Player Number
$iPlayer = &dec2bin($iPlayer);
$iPlayer = substr($iPlayer,11,5);
$iPlayer = bin2dec($iPlayer);
#$iPlayer = $iPlayer & 0x1F;
$iPlayer=$iPlayer +1; # Correcting for 0-15
print "iPlayer:\t$iPlayer\n"; 

# Encryption seed
# (0 in the File Header Block)
$binSeed = substr($iPlayer,0,11);
$seed = bin2dec($binSeed);
print "Seed:\t$seed\n"; 

# dts
# Convert DTS to binary so we can pull the values back out
$dts = dec2bin($dts);
print "dts:\t$dts\n";

# File Type
$dt = substr($dts, 8,15);
$dt = bin2dec($dt);
print "dt:\t$dt" . ":" . @dt[$dt] . ':' . @dt_verbose[$dt] . "\n";

# These are 1 character, so there's no need to convert them back to decimal
# Turn state (.x file only)
$fDone = substr($dts, 7,1);
#$fDone = $dts & 0x01;
#print "fDone\t$fDone\n";
print $fDone . ':' . @fDone[$fDone] . "\n";

# Host instance is using this file (dtHost, dtTurn).
$fInUse = substr($dts, 6, 1);
#$fInUse = ($dts & 0x02) >> 1;
print $fInUse . ':' . @fInUse[$fInUse] . "\n";

# Are multiple turns included (.m only)
$fMulti = substr($dts, 5,1);
#$fMulti = ($dts & 0x04) >> 2;
print $fMulti . ':' . @fMulti[$fMulti] . "\n";

# Is the Game Over
$fGameOver = substr($dts, 4,1);  # Probably 4
#$fGameOver = ($dts & 0x08) >> 3;
print $fGameOver . ':' . @fGameOver[$fGameOver] . "\n";

# Shareware
$fShareware = substr($dts, 3, 1);
#$fShareware = ($dts & 0x10) >> 4;
print $fShareware . ':' . @fShareware[$fShareware] . "\n";

# Unknown
$unknown = substr($dts, 0, 1);  # is not always 1|0
#$unknown = ($dts & 0x80) >> 7;


print "\n";
print "Stars! Version: $Version{$ver}";
if ($fInUse) { print " (In Use) "; }
print "\n";
print "Unique Game Id Number: $lidGame\n";
print "Game Year:\t$turn"; 
if ( $dt == dtTurn && $fMulti ) { $lastYear = unpack('S', $lasttwo) + 2400; print " to " . $lastYear; }
if ( $fGameOver ) { print " - Game Over"; }
print "\n";
if ( $iPlayer != -1  && $iPlayer != 32 ) { print "Player: " . $iPlayer; } # HST files have a value of 32
if ( $fShareware ) { print " - Shareware"; }
if ( $fDone && $dt == dtLog ) {  print " - Submitted"; }
print "\n";


#############
sub dec2bin {
	#my $str = unpack("B32", pack("N", shift));
	#$str =~ s/^0+(?=\d)//;
	# This doesn't match stuff online because I changed from 32- to 16-bit
	my $str = unpack("B16", pack("n", shift));
	return $str;
}
sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub read8 {
# Convert unsigned byte to integer.
  my ($b) = @_;
	return $b & 0xFF;
}

sub read16 {
#	 Read a 16 bit little endian integer from a byte array
  my ($data, $offset) = @_;
  #my @data = @{ $data };
	return &read8($data[$offset+1]) << 8 | &read8($data[$offset]);
}