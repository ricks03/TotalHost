#!/usr/bin/perl
# upload.pl
# Receive uploaded files for TotalHost
# Rick Steeves th@corwyn.net
# 120808

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

use CGI qw/:standard/;
use Win32::ODBC;
use TotalHost; 
use StarStat;
do 'config.pl';
use File::Basename;

$CGI::POST_MAX=1024 * 25;  # max 25K posts
# Read in the post values and clean them a bit
foreach my $field (param()) { 	$in{$field} = &clean(param($field)); }

my($File) = $in{'File'};
my($GameName) = $in{'GameName'};
my($GameFile) = $in{'GameFile'};
my($NextTurn) = $in{'NextTurn'};
my($GameStatus) = $in{'GameStatus'};
my($User_Login) = $in{'User_Login'};
my($RaceName) = $in{'RaceName'};
my($RaceDescrip) = $in{'RaceDescrip'};
my $err = ''; 

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
$cookie = $cgi->cookie(TotalHost);
&validate($cgi,$session);

print $cgi->header();
# make the user values handy and easy to use
$id = $session->param("userid");
$userlogin = $session->param("userlogin");
my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware);
 
# If there was an uploaded file
$valid_file = 0; # assume the file is not a valid file
if ($File) { 
  $valid_file = &ValidateFileUpload($File); 
} else { 
	&Print_Error; 
}

if  ($valid_file) { 
###	print qq|<meta HTTP-EQUIV="REFRESH" content="0; url=| . $WWW_HomePage . $Location_Scripts . qq|/page.pl?GameFile=$GameFile&lp=profile_game&cp=show_game&rp=show_news">|;
	print qq|<meta HTTP-EQUIV="REFRESH" content="0; url=| . $WWW_HomePage . $Location_Scripts . qq|/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err">|;
} else { 
# 191222 No longer any real need for a delay here, as we pass the error message to the main display
#	print qq|<meta HTTP-EQUIV="REFRESH" content="5; url=| . $WWW_HomePage . $Location_Scripts . qq|/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err">|;
	print qq|<meta HTTP-EQUIV="REFRESH" content="0; url=| . $WWW_HomePage . $Location_Scripts . qq|/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err">|;
}

print end_html;

###########################################################
sub ValidateFileUpload {
	my ($File) = @_;
	# BUG: Lower case the file name, so it's consistent everywhere. 
	my $GameValues;
	# Save the file out so we can do further analysis with it
	my $File_Loc = &Save_File($File); 
	&LogOut(400, "ValidateFileUpload: File_Loc = $File_Loc",$LogFile);
  # Clean up the file name for IE6 which includes path
  $File = basename($File);
	# Break the filename into component parts
	my ($game_file, $file_player, $file_type, $file_ext) = &FileData ($File); 
	&LogOut(300,"ValidateFileUpload: File type = $file_type",$LogFile); 
	#&LogOut(200, "File Data: $game_file, $file_player, $file_type, $file_ext", $LogFile);     In StarStat.pm
	# If it's not the right type of file at all, who cares about anything else; toss it but give the user a vague hint
	unless (&Check_FileType($file_type)) { 
    $invalid = "Invalid File Type for $File, $File_Loc by $userlogin: $file_type, $file_ext"; 
    $err .= $invalid . "\n"; &LogOut(0, "$invalid", $ErrorLog); 
    return 0;
  }

	# Race Files
	if ($file_type eq 'r') {
    # Check to make sure the Rane Name was entered
    if ($RaceName) {
      # Confirm there's not already a entry with that name
      $sql = qq|SELECT RaceName from Races where RaceName = '$RaceName' AND User_Login = '$userlogin';|;
  		$db=&DB_Open($dsn);
      if (&DB_Call($db,$sql)) { $db->FetchRow(); %RaceValues = $db->DataHash(); }
      &DB_Close($db);
      if ($RaceValues{'RaceName'}) {
  				$err .= "Race Name $RaceName already exists in your profile.\n"; 
  				&LogOut (0,"ValidateFileUpload: Race Name $RaceName already exists in profile for UserLogin: $err", $ErrorLog);
          &LogOut (0,"ValidateFileUpload: Invalid Race DB Entry: Deleted $File_Loc",$ErrorLog);
          # BUG: Danger deleting user-defined files. 
          unlink $File_Loc;
          return 0;    
      }
      
  		# check the file for valid information
  		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
  
      my $checkmagic = &Check_Magic($Magic, $File_Loc);
      my $checkversion = &Check_Version($ver, $File_Loc);
  		if ( $checkmagic && $checkversion ) { # If this is indeed a valid Stars file
  
  			if ( $dt == 5 ) { # If it is a race file
  				# If the file doesn't exist already
          # Read in the user information so we know where to put the race file
          $sql = qq|SELECT * FROM User WHERE User_Login = '$userlogin';|;
  				$db=&DB_Open($dsn);
          if (&DB_Call($db,$sql)) { $db->FetchRow(); %UserValues = $db->DataHash(); }
          &DB_Close($db);
  	      &LogOut(200,"$sql",$SQLLog); 
  
          my $racefiledir = $FileRaces . '\\' . $UserValues{'User_File'};  
          # If the User Race folder doesn't exist, create it. 
          if (not(-e($racefiledir))) {
            unless (mkdir $racefiledir) { &LogOut(0,"ValidateFileUpload: Failed to create Race Directory $racefiledir",$ErrorLog); }
          }
          #write out the race name to where it is supposed to go.
   		    my $Race_Destination = $racefiledir . '\\' . $File;  
          
   				if (not(-e $Race_Destination)) { #if the file does not already exist
  					# Add the new race to the database
  					$db=&DB_Open($dsn);
  					$sql = "INSERT INTO Races (RaceName, RaceFile, User_Login, RaceDescrip, User_File) VALUES ('$RaceName', '$File', '$userlogin', '$RaceDescrip', '$UserValues{'User_File'}');";
  					if (&DB_Call($db,$sql)) { # If the SQL query is not a failure
  							$err .= "Database Updated. ";
  							&LogOut(200, "ValidateFileUpload: Race Database Updated for $userlogin, $File: $err",$LogFile);
  							if (&Move_Race($File_Loc, $Race_Destination)) { # move the race to its final location
   								$err .= "Race File $File Uploaded.\n";
  								&LogOut(200,"ValidateFileUpload: $File $File_Loc moved to $Race_Destination for $userlogin: $err", $LogFile);
  								return 1; 
  							} else { 
  								$err .= "RaceFile $File failed to move/upload\n"; 
  								&LogOut(0,"ValidateFileUpload: $File $File_Loc failed to move to $Race_Destination for $userlogin: $err", $ErrorLog);
                  &LogOut(0,"ValidateFileUpload: Race File Failed to Move: Deleted $File_Loc",$ErrorLog);
                  return 0;
  							}
  					} else {
  						$err .= "File $File failed to insert into database. Had you entered a race name?";
  						&LogOut(0,"ValidateFileUpload: Failed to insert $File into database for $userlogin: $err", $ErrorLog);
              # Danger deleting a user defined file. 
              unlink $File_Loc;
  						return 0;
  					}
  					&DB_Close($db);
  				} else {
  					$err .= "Race File with that name: $File already exists";
            # Delete the temp file
            unlink ($File_Loc);
  					&LogOut(0, "ValidateFileUpload: Race File: $File $File_Loc already exists at $Race_Destination: $err", $ErrorLog); 
  					return 0; 
  				}
  			} else { 
  				$err .= "$File not a valid Race ( .r1 ) file\n"; 
  				&LogOut (0,"ValidateFileUpload: Invalid race file $File in $File_Loc for $userlogin: $err", $ErrorLog);
          &LogOut (0, "ValidateFileUpload: Invalid Race (.r1) File: Deleted $File_Loc",$ErrorLog);
          # Danger deleting user defined files. 
          unlink $File_Loc;
  				return 0; 
  			}
  		} else {
  			$err .= "Invalid Race File upload of $File by $userlogin\n";
  			&LogOut(0, "ValidateFileUpload: Invalid race file upload of $File to $File_Loc by $userlogin. CheckMagic: $checkmagic, CheckVersion: $checkversion: $err", $ErrorLog);
        # BUG: This is full of security errors, and you could be deleting a file that exists. 
        unlink ($File_Loc);
        &LogOut (0, "Invalid Race File: Deleted $File_Loc",$ErrorLog);
  			return 0;
  		}
    } else {
       $err .= "You must enter a Race Name for your race (this field is independent of the name in the file). Try Again!";
       &LogOut (0, "Upload: No race name entered for $userlogin",$ErrorLog);
    }
	} elsif ($file_type eq 'x') { # A turn file
		($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		&LogOut(300,"ValidateFileUpload: DTS2: $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware", $LogFile);
		if ( ($dt == 1) && &Check_Magic($Magic, $File_Loc) && &Check_Version($ver, $File_Loc) && &Check_GameFile($game_file) && &Check_Player($file_player,$iPlayer) && &Check_Turn($game_file, $turn) && &Check_GameID($game_file, $lidGame)) {
			&LogOut(100,"ValidateFileUpload: Valid Turn file $File_Loc, moving it",$LogFile);
      
      # Get the fix information
      # BUG: Logic will have to change here if we want a file which detects the need
      # For a fix we don't currently fox for to not save. 
      if ($fixFiles) { $err .= &StarsFix($File_Loc); }  #$File_Loc includes path 
      &LogOut(200, "ValidateFileUpload: fixFiles $fixFiles, $err, $File_Loc", $LogFile); 
      
			# Do whatever you would do with a valid change (.x) file
			if (&Move_Turn($File, $game_file)) {
				$db = &DB_Open($dsn);
				# update the Last Submitted Field
				$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.LastSubmitted = | . time() . qq| WHERE GameUsers.GameFile=\'$game_file\' AND GameUsers.User_Login=\'$userlogin\';|;
				if (&DB_Call($db, $sql)) {
					&LogOut(200, "ValidateFileUpload: Last Submitted updated for $File, $File_Loc, $game_file for $userlogin", $LogFile); 
				} else {
					&LogOut(200, "ValidateFileUpload: Last Submitted update FAILED $File, $File_Loc, in $game_file for $userlogin", $ErrorLog); 
				}
        # BUG: Need to determine if the game is AsAvailable, to generate as turns are uploaded.
# 				$sql = "SELECT * FROM Games WHERE GameFile = \'$game_file\';";
# 				if (&DB_Call($db,$sql)) {
# 					# Load all game values into the array
# 	    			while ($db->FetchRow()) {
# 						%GameValues = $db->DataHash();
# #						while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
# 					}
# 				}
#         if ($GameValues{'AsAvailable'} == 1 ) {
#           # If the game is AsAvailable, check to see if all Turns are in and whether we should generate. 
#           # The easiest way is likely to run TurnMake for the game
#           # since TurnMake is currently not a function
#           my $MakeTurn = "TurnMake.pl $GameValues{'GameFile'}";
#           &LogOut(100, "$MakeTurn, $LogFile");
#           &System($MakeTurn);
#         }
				&DB_Close($db);
        &Make_CHK($game_file);   # BUG: - should really pull value from database, not user-input
				return 1; 
			} else { 
				&LogOut(0,"ValidateFileUpload: File $File $File_Loc, $game_file failed to move for $userlogin",$ErrorLog);
        unlink ($File_Loc);
				####################################################################
				# If the file already exists at the destination, delete the temp one
				####################################################################
			}
		} else { 
			# display error messages when it's not a valid file. 
			$err .= "$File not a valid Turn ( .x[n] ) file. \n"; 
			unless (&Check_Player($file_player,$iPlayer)) { $err .= "Invalid Player ID\n"; &LogOut(0,"ValidateFileUpload: Invalid Player ID Turn file $File $File_Loc for $userlogin",$ErrorLog);}
			unless (&Check_Turn($game_file, $turn)) { $err .= "Wrong Year!\n"; &LogOut(0,"ValidateFileUpload: Invalid Year Turn file $File $File_Loc for $userlogin",$ErrorLog);}
			unless (&Check_GameID($game_file, $lidGame)) { $err .= "Wrong Game!\n"; &LogOut(0,"ValidateFileUpload: Invalid Game Turn file $File $File_Loc for $userlogin",$ErrorLog);}
			# delete file from file system
      unlink $File_Loc;
			return 0; 
		}
	# Zip files
	} elsif ($file_type eq 'z') {
		# Extract Zip files and check all the files inside somehow :-)
		################################################################
		$err .= "<P>You've uploaded a zip file, and we\'re not sure what to do with that yet!\n";
#		print $err;
		&LogOut(0,$err,$ErrorLog);
	} else { 
		$err .=  "$file_type is an invalid file type for $userlogin\n";
#    print $err;
		&LogOut(0,"ValidateFileUpload: Invalid File Type: $file_type, $File, $File_Loc, $userlogin: $err",$ErrorLog);
		return 0;  
	}
}

sub Move_Turn {
	use File::Copy;
	# Move the turn from the temp location to its final destination
	my ($Turn_File, $Turn_Name) = @_; 
 	my($Turn_Source)= $File_Upload . '/' . $Turn_File;  
 	my($Turn_Destination)= $File_HST . '/' . $Turn_Name . '/' . $Turn_File;  
	# If we got to here the file is valid, so we can overwrite
	move($Turn_Source, $Turn_Destination) or return 0;
	&LogOut(100,"Turn File $Turn_File moved from $Turn_Source > $Turn_Destination",$LogFile);
	return 1; 
}

sub Move_Race {
	use File::Copy;
	# Move the race from the temp location to its final destination
	my ($Race_Source, $Race_Destination) = @_; 
 	if (not(-e $Race_Destination)) { #if the file does not already exist
		move($Race_Source, $Race_Destination);
		&LogOut(100,"Race File moved from $Race_Source to $Race_Destination",$LogFile);
		return 1;
  } else {
		#otherwise tell them the file already exists
		&LogOut(0,"Move_Race: Race file $Race_Source already exists at $Race_Destination--nice try: $err",$ErrorLog);
		return 0;
  }
}

sub Save_File {
	my ($File) = @_; 
  # Strip any path information off the uploaded File
  # Since for some reason some browsers (IE6) include it
  use File::Basename;
  if ($File) { $FileName = basename($File); }
	my $File_Loc= $File_Upload . '/' . $FileName;  #write out the race name to where it is supposed to go.
	&LogOut(100,"Writing out $FileName for $File to $File_Loc",$LogFile);
	open (OUTFILE,">$File_Loc") || &LogOut(0,"Error writing file $File_Loc",$ErrorLog);
	binmode(OUTFILE);
	while (read($File,$data,1024)) { print OUTFILE $data;   }
	close(OUTFILE); 
	return $File_Loc; 
}

sub Print_Error {
  $err .= "<P>File Name must be filled in to upload.</p>\n" ;
#  print "<P>$err";
  &LogOut(10,$err,$ErrorLog);
  return 0;
}

# sub Check_FileName {
# 	# BUG:  Check_FileName Feature not implemented
# 	my ($file_file) = @_; 
# 	&LogOut(0,"Check_FileName for $file_file not implemented",$LogFile);
# 	# Check against the database that this is a valid Game Name
# 	return 1; 
# }
