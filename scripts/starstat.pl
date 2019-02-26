#!/usr/bin/perl
# starstat.pl
# Read in the data from any stars file to validate it.
# Rick Steeves th@corwyn.net
# 120129
# Version 1.1

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
@dt = ("XY", "Log", "Host", "Turn", "Hist", "Race", "Max");
@fDone = ('Turn Saved','Turn Saved/Submitted');
@fMulti = ('Single Turn', 'Multiple Turns');
@fGameOver = ('Game In Progress', 'Game Over'); 
@fShareware = ('Registered','Shareware'); 
@fInUse = ('Host instance not using file','Host instance using file'); # No idea what this value is.

my $filename = $ARGV[0];
print "File is $filename\n";
if ($filename eq '') { print "Please enter the file to examine. Example c:\\games\\meat.m6. "; die; }
##########################
open(StarFile, "$filename");
binmode(StarFile);
read(StarFile, $FileValues, 22);
close(StarFile);

$unpack = "A2A4h8SSSS";
#$Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts)
@FileValues = unpack($unpack,$FileValues);
($Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts) = @FileValues;
print join(',', @FileValues) . "\n";
#print "Header\t$Header\n"; #Header
print "Magic\t$Magic\n"; #
print "lidGame\t$lidGame\n"; 

# Game Version
$ver = dec2bin($ver);
#print "ver:$ver\n";
$verInc = substr($ver,11,5);
$verMinor = substr($ver,4,7);
$verMajor = substr($ver,0,4);
$verMajor = bin2dec($verMajor);
$verMinor = bin2dec($verMinor);
$verInc = bin2dec($verInc);
$ver = $verMajor . "." . $verMinor . "." . $verInc;
print "Version\t$ver\n";

# Turn
$turn=$turn + 2400;
print "turn\t$turn\n"; #

# Player Number
$iPlayer = &dec2bin($iPlayer);
$iPlayer = substr($iPlayer,11,5);
$iPlayer = bin2dec($iPlayer);
$iPlayer=$iPlayer +1; # Correcting for 0-15
print "iPlayer = $iPlayer\n"; 

# dts
# Convert DTS to binary so we can pull the values back out
print "\n";
$dts = dec2bin($dts);
print "\ndts\t$dts\n";

# File Type
$dt = substr($dts, 8,15);
$dt = bin2dec($dt);
print $dt . ":" . @dt[$dt] . ':' . @dt_verbose[$dt] . "\n";

# These are 1 character, so there's no need to convert them back to decimal
# Turn state (.x file only)
$fDone = substr($dts, 7,1);
#print "fDone\t$fDone\n";
print $fDone . ':' . @fDone[$fDone] . "\n";

# Host instance is using this file (dtHost, dtTurn).
$fInUse = substr($dts, 6, 1);
print $fInUse . ':' . @fInUse[$fInUse] . "\n";

# Are multiple turns included (.m only)
$fMulti = substr($dts, 5,1);
print $fMulti . ':' . @fMulti[$fMulti] . "\n";

# Is the Game Over
$fGameOver = substr($dts, 4,1);  # Probably 4
print $fGameOver . ':' . @fGameOver[$fGameOver] . "\n";

# Shareware
$fShareware = substr($dts, 3, 1);
print $fShareware . ':' . @fShareware[$fShareware] . "\n";

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