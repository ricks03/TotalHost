# StarsSerial.pl
# NOT WORKING
#
# Rick Steeves
# starsah@corwyn.net
# Version History
# 210518
#
#     Copyright (C) 2031 Rick Steeves
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


# Generates a Stars Serial Number (or checks to see if one is valid)
#
# Example Usage: 
# StarsSerial.pl
# or
# StarsSerial.pl SERIALNUMBER

use strict;
use warnings;   

# Get the serial from the command line
my $lSerial = $ARGV[0]; # input file

# DEBUG: Just set it
$lSerial = 'SAH62J1E';

if ($lSerial) { 
   &FValidSerialLong($lSerial);
} else {
   &createSerial();
}

###########################################################
#BOOL FValidSerialLong(unsigned long lSerial)
sub FValidSerialLong {

  my ($lSerial) = @_;
    # GlobalSettings=IUK30dFAN9eY1pKABAL3tVcWUpnp
    
  my $lSeries; #unsigned long lSeries;
  my $lNumber; #unsigned long lNumber;

	$lSeries = $lSerial;
	for (my $i = 0; $i < 4; $i++) {
		$lSeries = int($lSeries / 36);
        print "lSeries: $lSeries\n"
    }

	$lNumber = $lSeries;
	for (my $i = 0; $i < 4; $i++) {
		$lNumber = int($lNumber * 36);
         print "lNumber: $lNumber\n"
   }

	$lNumber = $lSerial - $lNumber;

	if ($lNumber < 100 || $lNumber > 1500000) {
		return 0; #false
  }
        
# A=0, B=1, C=2, D=3, E=4, F=5, G=6, 
	if (   $lSeries != 18 # /*S*/ 
        && $lSeries != 22 # /*W*/ 
        && $lSeries !=  2 # /*C*/ 
        && $lSeries !=  4 # /*E*/ 
        && $lSeries !=  6 # /*G*/
    ) {
	  return 0; #false
    }

	return 1; # true
}

sub createSerial {

}


# Note: Also look at the filtering of the starting letter in
# FValidSerialLong
#BOOL FValidSerialNo(char *psz, long *plSerial)
sub FValidSerialNo {
  my ($psz, $plSerial) = @_;
  my @psz;
  @psz = split(//,$psz);
  my $lSerial = &LongFromSerialCH($psz[0]); #long lSerial = LongFromSerialCh(psz[0]);
  my $lCur;   # long lCur;
  my $lBuild; # long lBuild;
  my $i ; #  int i;
  my $l;  #  long l;
 
  if ($lSerial < 0x20) {
    $lSerial=$lSerial^0x15; #$lSerial ^= 0x15;  # back out XOR
  }
      $lSerial = $lSerial * 36 + &LongFromSerialCh($psz[1]);
      $lSerial = $lSerial * 36 + &LongFromSerialCh($psz[4]);
      $lSerial = $lSerial * 36 + &LongFromSerialCh($psz[7]);
      $lSerial = $lSerial * 36 + &LongFromSerialCh($psz[3]);
 
      if ($plSerial) {
            $plSerial = $lSerial;
      }
 
      &PushRandom(11,17);
      $lCur = $lSerial;
      &Randomize2($lCur); # Use the bottom 14 bits
      $lCur = $lCur >> 14;
      $lBuild = 0;
 
      for ($i = 0; $i < 3; $i++) {
        for ($l = $lCur & 0x0f; $l >= 0; $l--) {
                  &Random(256);
        }
        $lBuild = ($lBuild << 8) + &Random(256);
        $lCur >>= 4;
      }
 
      &PopRandom();  # Restore the random number generator
      $l = &LongFromSerialCh($psz[2]);
 
      if ($l != ($lBuild % 36)) {
            return 0; #fFalse;
      }
 
      $lBuild /= 36;
      $l = &LongFromSerialCh($psz[5]);
 
      if ($l != ($lBuild % 36)) {
        return 0; #fFalse;
      }
 
      $lBuild /= 36;
      $l = &LongFromSerialCh($psz[6]);
 
      if ($l != ($lBuild % 36)) {
            return 0; # fFalse;
      }
 
      return 1; #fTrue;
    }
 
#long LongFromSerialCh(char ch)
sub LongFromSerialCh {
  my ($ch) = @_;
  my $l; #long l;
  
  if ($ch >= 'A' && $ch <= 'Z') {
        $l = $ch - 'A';
  } else { 
        $l = $ch - '0' + 26;
  }
  
  if ($l >= 0x20) {
        return $l;
  } else {
        return $l ^ 0x15;
  }
}
 
 
sub PopRandom() {
}

#// A better more thorough randomizer
#VOID Randomize2(DWORD dw)
sub Randomize2 {
     ($dw) = @_;
      my ($a, $b);
      
      $a = (int) ($dw & 0x7f);
      $b = (int) (($dw>>7) & 0x7f);
 
      $a ^= 0x35;
      $b ^= 0x5c;
 
      if ($a == $b)
            $b = ($b+1) & 0x7f;
      $lRandSeed1 = (long) $rgPrimes[$a];
      $lRandSeed2 = (long) $rgPrimes[$b];
    }
} 
 
#/* Return a random integer between 0 and MaxValue - 1. */
#int Random(int MaxValue)
int Random {
    ($MaxValue) = @_;
    my ($si, $s2, $z, $k); #long s1, s2, z, k;
 
      $s1 = lRandSeed1;
      $s2 = lRandSeed2;
      $k = $s1 / 53668;  #k = s1 / 53668L;
      $s1 = 40014 * ($s1 - $k * 53668) - $k * 12211; # s1 = 40014L * (s1 - k * 53668L) - k * 12211L;
      if ($s1 < 0) { #if (s1 < 0L)
            $s1 += 2147483563; #2147483563L;
 
      $k = $s2 / 52774; #k = s2 / 52774L;
      $s2 = 40692 * ($s2 - $k * 52774) - $k * 3791; #s2 = 40692L * (s2 - k * 52774L) - k * 3791L;
      if ($s2 < 0) {
            $s2 += 2147483399; #s2 += 2147483399L;
      }
      $z = $s1 - $s2;
      if ($z < 1) {   #if (z < 1L)
            $z += 2147483562; #z += 2147483562L;

      $lRandSeed1 = $s1;
      $lRandSeed2 = $s2;
 
      Assert($z >= 0);
 
      if ($MaxValue <= 0) {
            return 0;
      }
      return $z % $MaxValue  #return (unsigned) z % (unsigned) MaxValue;
    }
# The compiled key is stored in the stars.ini file under this name:
#From strings.src: IniGlobalSet,    "GlobalSettings"

