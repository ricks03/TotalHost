#!/usr/bin/perl
# starstat.pm
# Core Library for TotalHost and StarStat
# Formerly a RallyPt File
# Rick Steeves th@corwyn.net
# 120209

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

package StarStat;
do 'config.pl';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( 
	starstat bin2dec dec2bin
	Check_Version
	Check_FileType
	Check_Player
	Check_Turn
	Check_GameFile  
	Check_GameID 
	Check_dt
	Check_Magic
	FileData
	ValidateFile
	Fix_Version
	SLogOut
);
 
# Used by the starstat function
@dt_verbose = ('Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File');
@dt = qw(XY Log Host Turn Hist Race Max);
@fDone = ('Turn Saved','Turn Saved/Submitted');
@fMulti = ('Single Turn', 'Multiple Turns');
@fGameOver = ('Game In Progress', 'Game Over'); 
@fShareware = ('Registered','Shareware'); 
@fInUse = ('Host instance not using file','Host instance using file'); # No idea what this value is.
%Version = ('1.2a' => '1.1a', '2.65' => '2.0a', '2.81j' => '2.6i', '2.83.0' => '2.6jrc4');

sub dec2bin {
	#my $str = unpack("B32", pack("N", shift));
	#$str =~ s/^0+(?=\d)//;
	# This doesn't match stuff online because I changed from 32- to 16-bit
	my $str = unpack("B16", pack("n", shift));
	return $str;
}

sub bin2dec { return unpack("N", pack("B32", substr("0" x 32 . shift, -32))); }

sub starstat { 
	my $filename, $FileValues, $Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts;
	my $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware; 

	($filename) = @_; 
	open(StarFile, "$filename");
	binmode(StarFile);
	read(StarFile, $FileValues, 22);
	close(StarFile);

# 211104 BUG: At some point I changed this string to SA4LSSsS but I don't
# know why, and then it didn't line up with statstat.pl	
# The change is A2 to S (string) and h8 to L (which is probably a long)
#  $unpack = "A2A4h8SSSS";
	$unpack = 'SA4LSSsS';
	#$Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts
	@FileValues = unpack($unpack,$FileValues);
	($Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts) = @FileValues;
	# Game Version
	$ver = dec2bin($ver);
	$verInc = substr($ver,11,5);
	$verMinor = substr($ver,4,7);
	$verMajor = substr($ver,0,4);
	$verMajor = bin2dec($verMajor);
	$verMinor = bin2dec($verMinor);
	$verInc = bin2dec($verInc);
	$ver = $verMajor . "." . $verMinor . "." . $verInc;
	$ver = &Fix_Version($ver);
	# Turn
	$turn=$turn + 2400;
	# Player Number
	$iPlayer = &dec2bin($iPlayer);
	$iPlayer = substr($iPlayer,11,5);
	$iPlayer = bin2dec($iPlayer);
	$iPlayer=$iPlayer +1; # Correcting for 0-15
	
	# dts
	# Convert DTS to binary so we can pull the values back out
	$dts = dec2bin($dts);
	# File Type
	$dt = substr($dts, 8,15);
	$dt = bin2dec($dt);
	# These are 1 character, so there's no need to convert them back to decimal
	# Turn state (.x file only)
	$fDone = substr($dts, 7,1);
	# Host instance is using this file (dtHost, dtTurn).
	$fInUse = substr($dts, 6, 1);
	# Are multiple turns included (.m only)
	$fMulti = substr($dts, 5,1);
	# Is the Game Over
	$fGameOver = substr($dts, 4,1);  # Probably 4
	# Shareware
	$fShareware = substr($dts, 3, 1);
  
	return $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware;
}

sub Check_Version {
	my ($ver, $File) = @_; 
#	if ($ver eq '2.6jrc4') { 
	if ($ver eq '2.83.0' || $ver  eq '2.6jrc4') { 
  	&SLogOut(400,"Correct Check_Version: $File $version", $LogFile);
		return 1; 
	} else { 
#		print "<P>Incorrect version $ver\n";
		&SLogOut(0,"Incorrect version $ver ($Version{$ver}) in $File",$ErrorLog);
		return 0; 
	}
}

sub Check_FileType {
	my ($file_type) = @_; 
	$file_type = lc($file_type);
	# z is for zip files (and just assuming .zip)
	my @types = ('x','r','z');
	&SLogOut(400,"Check_FileType: $file_type", $LogFile);
	return exists {map { $_ => 1 } @types}->{$file_type};
}

sub Check_Player {
	my ($iPlayer, $file_player) = @_; 
	if ($iPlayer == $file_player) { 
		&SLogOut(400,"Correct Player ID DTS: $iPlayer, File: $file_player",$LogFile);
		return 1; 
	} else {
		&SLogOut(0,"Incorrect Player ID DTS: $iPlayer, File: $file_player",$ErrorLog);
		return 0; 
	}
}

sub Check_Turn {
	# Check against the existing game that this is for the correct turn.
	my ($file_prefix, $x_turn) = @_;
	my $Game_Loc = $Dir_Games . '/' . $file_prefix . '/' . $file_prefix . '.hst';
	# Check to see if the HST file exists at all
	if (-e $Game_Loc) {
		# Get the data for the game
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($Game_Loc);
		if ($turn == $x_turn) {
			&SLogOut(400,"Turn $x_turn matches Hosted Turn $turn",$LogFile);
			return 1; 
		} else {
			&SLogOut(0,"Turn $x_turn DOES NOT MATCH HOSTED Turn $turn\nFile NOT ACCEPTED",$ErrorLog);
			return 0;
		}
	} else {
		&SLogOut(0,"No game exists for Game: $file_prefix",$ErrorLog);
		return 0;
	}
}

sub Check_GameFile {
  # Where file_prefix is the game prefix of the file name
  my($file_prefix) = @_;
  my $Game_Loc = $Dir_Games . '/' . $file_prefix . '/' . $file_prefix . '.hst';
  if (-e $Game_Loc) {
  	&SLogOut(400,"Game Exists at $Game_Loc: Game File = $file_prefix",$LogFile);
  	return 1;
  } else { 
	  &SLogOut(0,"Game does not exist at $Game_Loc for Game File $file_prefix",$ErrorLog);
	  return 0
  }
}

sub Check_GameID {
	# Check in the database or file system to see that the Game ID is valid
	my ($file_prefix, $Game_ID) = @_;
	my $Game_Loc = $Dir_Games . '/' . $file_prefix . '/' . $file_prefix . '.hst';
	# Check to see if the HST file exists at all
	if (-e $Game_Loc) {
		# Get the data for the game
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($Game_Loc);
		if ($lidGame == $Game_ID) {
			&SLogOut(400,"Game ID $Game_ID matches Hosted Game ID $lidGame",$LogFile);
			return 1; 
		} else {                                                     
			&SLogOut(0,"<P>Game ID $Game_ID DOES NOT MATCH HOSTED Game ID $lidGame\nFile NOT ACCEPTED",$ErrorLog);
			return 0;
		}
	} else {
		&SLogOut(0,"No game exists for Game: $file_prefix",$ErrorLog);
		return 0;
	}
}

sub Check_dt {
	my ($dt) = @_; 
	&SLogOut(400,"<P>DT: @dt_verbose[$dt]  @dt[$dt]",$LogFile);
	return 1; 
}

sub Check_Magic {
	my ($Magic, $File) = @_; 
	if ($Magic eq 'J3J3') {
		&SLogOut(400,"Valid Stars! File $File $Magic",$LogFile);
		return 1; 
	} else { 
		&SLogOut(0,"Not a valid Stars! File $File $Magic",$ErrorLog);
		return 0; 
	}
}

sub FileData {
	# break out the incoming file name to useful bits
	my ($File) = @_;
	$File = lc($File); 
  # Strip off any directory
  # $File =~ s{^.*[:\\/]}{}s;     # remove the leading path  
	my $file_prefix = lc($File);
	$file_prefix=~ s/(.*)(\..+)/$1/;
	my $file_player = lc($File);
	$file_player =~ s/(.*)(\.)(.)(.*)/$4/;
	my $file_type = lc($File); 
	$file_type =~ s/(.*)(\.)(.)(.*)/$3/;
	my $file_ext = lc($File);
	$file_ext =~ s/(.*)(\.)(.*)/$3/;
	&SLogOut(400, "FileData: $file_prefix, $file_player, $file_type, $file_ext",$LogFile);
  # Fixing output that's incorrect for HST files
  if ($file_ext =~ /HST/i ) { 
    $file_type='hst'; 
    $file_player = 16;
  }
	return $file_prefix, $file_player, $file_type, $file_ext; 	
}

sub ValidateFile {
 	my ($File, $FilePath) = @_;
#	$FilePath =~ s/\\/\//g; # "fix" the file path so it's consistent for \
 	my $File_Loc = $FilePath . '\\' . $File;
	if (!(-e $File_Loc)) { &SLogOut(0, "Validate file $File_Loc not found", $ErrorLog); return 0; }
	# Break the filename apart into component parts
	my ($file_prefix, $file_player, $file_type, $file_ext) = &FileData($File); 
	unless (&Check_FileType($file_type)) { return 0; }
	# Race Files
	if ($file_type eq 'r') {
		# check the file for information
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		if ( &Check_Magic($Magic, $File_Loc) && &Check_Version($ver, $File_Loc)) {
			if ( $dt == 5) { #print "Valid Race File\n"; 
				return $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware;
			} else { &SLogOut(0,"$File_Loc Not a Race ( .r1) File",$ErrorLog); return $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware;} 
		} else { &SLogOut(0,"$File_Loc Not a valid Race ( .r1 ) file",$ErrorLog); return $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware; }
	# Log files
	} elsif ($file_type eq 'x') {
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		if ( ($dt == 1) && &Check_Magic($Magic, $File_Loc) && &Check_Version($ver, $File_Loc) && &Check_GameFile($file_prefix) && &Check_Player($file_player,$iPlayer) && &Check_Turn($file_prefix, $turn) && &Check_GameID($file_prefix, $lidGame)) {
			return $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware;
		} else { &SLogOut(0,"$File_Loc Not a valid Turn ( .x[n] ) file",$ErrorLog); return 0; }
	} else { 
		&SLogOut(0,"$file_type is an invalid file type",$ErrorLog);
		return 0;  
	}
}

sub Fix_Version { 
	# Make the stars version # display as the game version
	my ($ver) = @_;
  return $Version{$ver};
#	if ($ver eq '2.83.0') { return '2.6jrc4'; }
#	else { return $ver; }
}

sub SLogOut {
	my($Logging, $PrintString, $LogFile) = (@_);
  # Get Date information to set up logs to roll over weekly
  my $CurrentEpoch = time();
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($CurrentEpoch); 
	my $Month = $WrongMonth + 1; 
	my $Year = $WrongYear + 1900;
  if ($DayofMonth <=7) { $WeekofMonth = 1;}
	elsif ($DayofMonth >7 && $DayofMonth <=14) { $WeekofMonth = 2;}
	elsif ($DayofMonth >14 && $DayofMonth <=21) { $WeekofMonth = 3;}
	elsif ($DayofMonth >21 && $DayofMonth <=28) { $WeekofMonth = 4;}
	elsif ($DayofMonth >28 && $DayofMonth <=31) { $WeekofMonth = 5;}
  my $LogFileDate = $LogFile . '.' . $Year . '.' . $Month . '.' . $WeekofMonth; 

	if ($Logging <= $logging) { 
		$PrintString = localtime(time()) . " : $Logging : " . $PrintString;
		open (LOGFILE, ">>$LogFileDate");
		print LOGFILE "$PrintString\n\n";
		close LOGFILE;
	}
}