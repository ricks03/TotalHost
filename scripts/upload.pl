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
use TotalHost; # eval'd at compile time
use StarStat;  # eval'd at compile time
use StarsBlock;# eval'd at compile time
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
my $valid_file = 0; # assume the file is not a valid file

my $cgi = new CGI; # Create the new CGI Session     
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
$cookie = $cgi->cookie(TotalHost);  # Get the cookie information
# make the user values handy and easy to use
$id = $session->param("userid");
$userlogin = $session->param("userlogin");
&validate($cgi,$session); # Confirm user or Display error and end.

#print $cgi->header(); # Create a page header
 
# If there was an uploaded file
if ($File) {
  $valid_file = &ValidateFileUpload($File);
  my $newPage = qq|$WWW_HomePage$WWW_Scripts/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err|;
  # Redirect to newPage, which solves for reloading the page retaking the action.
  # Nothing can print before this or it breaks.
  #  print $cgi->redirect($newPage);  # Doesn't work
  print "Location: $newPage\n\n";
} else { 
  print $cgi->header(); # Create the HTML page header
  print qq|<meta HTTP-EQUIV="REFRESH" content="2; url=| . $WWW_HomePage . $WWW_Scripts . qq|/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err">|;
  print $cgi->start_html;
  $err .= "$userlogin: File Name must be provided for upload to $GameName." ;
  &LogOut(300,$err,$ErrorLog);
  print $err; 
  print $cgi->end_html;
}

###########################################################
sub ValidateFileUpload {
	my ($File) = @_; # Uploaded file
	my $GameValues;          
	# Save the file out so we can do further analysis with it
	my $File_Loc = &Save_File($File); 
	&LogOut(400, "ValidateFileUpload: File_Loc = $File_Loc",$LogFile);
  $File = lc(basename($File));   # Clean up the file name for IE6 which includes path
	# Break the filename into component parts
	my ($file_prefix, $file_player, $file_type, $file_ext) = &FileData ($File); 
	&LogOut(300,"ValidateFileUpload: File type = $file_type",$LogFile); 
	#&LogOut(200, "File Data: $file_prefix, $file_player, $file_type, $file_ext", $LogFile);     In StarStat.pm
	# If it's not the right type of file at all, who cares about anything else; toss it but give the user a vague hint
	unless (&Check_FileType($file_type)) { 
    # Don't give users the file location
    $err .= "Invalid File Type for $File_Loc by $userlogin"; 
    &LogOut(0, "Invalid File Type for $File_Loc by $userlogin: $file_type $file_ext", $ErrorLog); 
    return 0;
  }   
  
	# Race Files
	if ($file_type eq 'r') {
    # Check to make sure the Race Name was entered
    if ($RaceName) {
      # Confirm there's not already a entry with that name
      $sql = qq|SELECT RaceName from Races where RaceName = '$RaceName' AND User_Login = '$userlogin';|;
  		$db=&DB_Open($dsn);
      if (&DB_Call($db,$sql)) { $db->FetchRow(); %RaceValues = $db->DataHash(); }
      &DB_Close($db);
      if ($RaceValues{'RaceName'}) {
  				$err .= 'Race Name $RaceName already exists in your profile.'; 
  				&LogOut (0,"ValidateFileUpload: Race Name $RaceName already exists in profile for $userlogin: $err $File_Loc", $ErrorLog);
          unlink $File_Loc; #user-input cleaned as much as I can. 
          return 0;    
      }
      
      # Check to see if the race file is corrupt
      if (&checkRaceCorrupt($File_Loc)) {
        $err .= 'This race file is corrupt! Caused by making the plural name too short. Recreate the race or fix it with StarsRace.exe !!';
        &LogOut (0, "ValidateFileUpload: Race file $File_Loc corrupt for $userlogin",$ErrorLog);
        unlink $File_Loc; #user-input cleaned as much as I can. 
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
  
          my $racefiledir = "$DirRaces\\$UserValues{'User_File'}";  
          # If the User Race folder doesn't exist, create it. 
          if (not(-e($racefiledir))) {
            unless (mkdir $racefiledir) { &LogOut(0,"ValidateFileUpload: Failed to create Race Directory $racefiledir",$ErrorLog); }
          }
          #write out the race name to where it is supposed to go.
   		    my $Race_Destination = "$racefiledir\\$File";  
   				if (not(-e $Race_Destination)) { #if the file does not already exist
  					# Add the new race to the database
  					$db=&DB_Open($dsn);
  					$sql = "INSERT INTO Races (RaceName, RaceFile, User_Login, RaceDescrip, User_File) VALUES ('$RaceName', '$File', '$userlogin', '$RaceDescrip', '$UserValues{'User_File'}');";
  					if (&DB_Call($db,$sql)) { # If the SQL query is not a failure
  							$err .= "Database updated. ";
  							&LogOut(200, "ValidateFileUpload: Race Database Updated for $userlogin, $File: $err",$LogFile);
  							if (&Move_Race($File_Loc, $Race_Destination)) { # move the race to its final location
   								$err .= "Race File $File Uploaded.\n";
  								&LogOut(200,"ValidateFileUpload: $File $File_Loc moved to $Race_Destination for $userlogin: $err", $LogFile);
  								return 1; 
  							} else { 
  								$err .= "RaceFile $File failed to move/upload\n"; 
  								&LogOut(0,"ValidateFileUpload: Race file $File_Loc failed to move to $Race_Destination for $userlogin: $err", $ErrorLog);
                  return 0;
  							}
  					} else {
  						$err .= "File $File failed to insert into database. Had you entered a race name?";
  						&LogOut(0,"ValidateFileUpload: Failed to insert $File into database for $userlogin: $err", $ErrorLog);
              unlink $File_Loc; #user-input cleaned as much as I can. 
  						return 0;
  					}
  					&DB_Close($db);
  				} else {
  					$err .= "<b>ERROR: Race File: $File already exists. Delete that Race (or rename your file) and try again! $Race_Destination</b>";
            unlink ($File_Loc); # Delete the temp file
  					&LogOut(0, "ValidateFileUpload: Race File: $File $File_Loc already exists at $Race_Destination: $err", $ErrorLog); 
  					return 0; 
  				}
  			} else { 
  				$err .= uc($File) . " not a valid Race ( .r1 ) file."; 
          &LogOut (0, "ValidateFileUpload: Invalid Race (.r1) File: Deleted $File_Loc for $userlogin",$ErrorLog);
          unlink $File_Loc; #user-input cleaned as much as I can. 
  				return 0; 
  			}
  		} else {
  			$err .= "Invalid Race File upload of $File by $userlogin";
  			&LogOut(0, "ValidateFileUpload: Invalid race file upload of $File_Loc by $userlogin. CheckMagic: $checkmagic, CheckVersion: $checkversion: $err", $ErrorLog);
        unlink ($File_Loc); #user-input cleaned as much as I can. 
  			return 0;
  		}
    } else {
       $err .= 'You must enter a Race Name for your race (this field is independent of the name in the file). Try Again!';
       &LogOut (0, "Upload: No race name entered for $userlogin",$ErrorLog);
    }
	} elsif ($file_type eq 'x') { # A turn file
 		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		&LogOut(300,"ValidateFileUpload: DTS2: $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware", $LogFile);
    # Validate the .x file
	  # DT: 'Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File'
    # $err results will display at the top of the game page when it refreshes, comma-delimited
    if (!($dt == 1))                                { $err .= 'Not a Stars! .x file'; &LogOut(0,"ValidateFileUpload: Invalid .x file dt = $dt, $File_Loc for $userlogin",$ErrorLog); }
    elsif (!(&Check_Magic($Magic, $File_Loc)))      { $err .= "Invalid Magic $Magic"; &LogOut(0,"ValidateFileUpload: Invalid Magic $Magic, $File_Loc for $userlogin",$ErrorLog); }
    elsif (!(&Check_Version($ver, $File_Loc)))      { $err .= "Invalid Version $ver"; &LogOut(0,"ValidateFileUpload: Invalid version $ver, $File_Loc for $userlogin",$ErrorLog); }
    elsif (!(&Check_GameFile($file_prefix)))          { $err .= "Invalid Game File $file_prefix"; &LogOut(0,"ValidateFileUpload: Invalid game file $file_prefix for $userlogin",$ErrorLog); }
    # Check_Player checks the extension of the file against the starstat value of the player
  	elsif (!(&Check_Player($file_player,$iPlayer))) { $err .= 'Invalid Player ID'; &LogOut(0,"ValidateFileUpload: Invalid Player ID Turn file $File $File_Loc for $userlogin",$ErrorLog); }
    # Check_Turn validates that this file is fo rthe correct turn.
		elsif (!(&Check_Turn($file_prefix, $turn)))       { $err .= "Wrong Year! ($turn)"; &LogOut(0,"ValidateFileUpload: Invalid Year Turn file $File $File_Loc for $userlogin",$ErrorLog);}
    # Check_GameID validates that the file is the correct file ID fo rthis game
		elsif (!(&Check_GameID($file_prefix, $lidGame)))  { $err .= 'Wrong Game ID!'; &LogOut(0,"ValidateFileUpload: Invalid Game ID $file_prefix, $lidGame $File_Loc $File for $userlogin",$ErrorLog); }
    # Check_User validates that this user is the correct user for this turn
		elsif (!(&Check_User($file_prefix, $userlogin, $iPlayer)))  { $err .= "Wrong User!"; &LogOut(0,"ValidateFileUpload: Invalid User $file_prefix, $file_player,$iPlayer $File_Loc $File for $userlogin",$ErrorLog); }
    # Check that the turn won't trigger a serial/hardware conflict
		elsif (my $errSerial = &checkSerials($File_Loc))  { $err .= "$errSerial"; &LogOut(0,"ValidateFileUpload: Serial/hardware error $err $File_Loc for $userlogin",$ErrorLog); }

    # If any critical errors have been reported, error. Delete the file
    if ($err) { 
      &LogOut(0, "ValidateFileUpload: Error $err $errSerial", $ErrorLog); 
      # Pass the results to $err for display
      $err = 	uc($File) . " not a valid .X[n] file: $err $errSerial. DISCARDING FILE"; 
      unlink $File_Loc; # #user-input cleaned as much as I can. 
      return 0; 
    } else {&LogOut(300, "ValidateFileUpload: No errors for $in{'GameFile'}", $LogFile); }
    
    # Unless there was an error, move the file to the game folder
    unless ($err) { 
			# Do whatever you would do with a valid change (.x) file
		  &LogOut(100,"ValidateFileUpload: Valid Turn file $File_Loc, moving it to $DirGames\\$GameFile", $LogFile);      
			if (&Move_Turn($File, $file_prefix)) {
				$db = &DB_Open($dsn);
				# update the Last Submitted Field
				$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.LastSubmitted = | . time() . qq| WHERE GameUsers.GameFile=\'$file_prefix\' AND GameUsers.User_Login=\'$userlogin\';|;
				if (&DB_Call($db, $sql)) {
					&LogOut(200, "ValidateFileUpload: Last Submitted updated for $File, $File_Loc, $file_prefix for $userlogin", $LogFile); 
				} else {
					&LogOut(200, "ValidateFileUpload: Last Submitted update FAILED $File, $File_Loc, in $file_prefix for $userlogin", $ErrorLog); 
				}
        
        # Now that the file is legit, fix anything else wrong with it.
        # Check (and potentially fix) the .x file for known Stars! exploits
        # Requires List files (.fleet, .queue, etc)
        # Requires a file named 'fix' in the game folder as an additional safety net 
        my $fixFile = "$DirGames\\$GameFile\\fix";
        my $warning; 
        if ($fixFiles && -e $fixFile) { 
          &LogOut(300, "ValidateFileUpload: fixfile: $fixFile fixFiles: $fixFiles, $File_Loc", $LogFile); 
          my $gameDir = "$DirGames\\$GameFile";
          $warning = &StarsFix($gameDir, "$gameDir\\$file_prefix.$file_ext", $turn);
          &LogOut(200, "ValidateFileUpload: $gameDir, $warning", $LogFile); 
          if ($warning) {
            # Append any errors from the Fix to the display
            $err .= $warning;
            # Append the error(s) to the .warning file
            &process_fix($file_prefix, "$warning");
            &LogOut(0, "ValidateFileUpload: fixFiles $fixFiles, $err, $turn, $File_Loc", $ErrorLog);
          }
        }
 
        # If the game is AsAvailable, check to see if all Turns are in and whether we should generate. 
   			$sql = "SELECT * FROM Games WHERE GameFile = \'$file_prefix\';";
 				# Load game values into the array
        if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); } # Should return only one value
        if ($GameValues{'AsAvailable'} == 1 ) { # Don't immediately generate As Available if the file generated warnings
          if ($warning) {
            $err .= "Not immediately generating As Available game $file_prefix due to Warnings. Will generate on next turn check interval however.\n";
            &LogOut(100, "Upload: AsAvailable $err for $GameFile $userlogin", $LogFile);
          } else {
            # Run TurnMake for the game since TurnMake is currently not a function
            # TurnMake will handle for emails, CHK file, etc.
            my $MakeTurn = "perl -I $DirScripts $DirScripts\\TurnMake.pl $GameFile >nul";
            &LogOut(100, "Upload: AsAvailable $MakeTurn", $LogFile);
            system($MakeTurn); # Starting system with 1 makes it launch asynchronously, in case Stars! hangs
          }
        }
				&DB_Close($db);
        &Make_CHK($file_prefix);   # User-input cleaned as best we can.
				return 1; 
			} else { 
        # If the file failed to move, report and remove. 
        $err .= "<P>File failed to move!\n";
				&LogOut(0,"ValidateFileUpload: File $File $File_Loc, $file_prefix failed to move for $userlogin",$ErrorLog);
        unlink ($File_Loc);
        return 0;
			}
		}
	# Zip files
	} elsif ($file_type eq 'z') {
		# Extract Zip files and check all the files inside somehow :-)
		################################################################
		$err .= qq|You've uploaded a zip file, and we\'re not sure what to do with that yet!\n|;
		&LogOut(0,$err,$ErrorLog);
	} else { 
		$err .=  qq|$file_type is an invalid file type for $userlogin\n|;
		&LogOut(0,"ValidateFileUpload: Invalid File Type: $file_type, $File, $File_Loc, $userlogin: $err",$ErrorLog);
		return 0;  
 	}
}

sub Move_Turn {
	use File::Copy;
	# Move the turn from the temp location to its final destination
	my ($Turn_File, $Turn_Name) = @_; 
 	my($Turn_Source)= $Dir_Upload . '/' . $Turn_File;  
 	my($Turn_Destination)= $Dir_Games . '/' . $Turn_Name . '/' . $Turn_File;  
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
	my $File_Loc= $Dir_Upload . '/' . $FileName;  #write out the race name to where it is supposed to go.
	&LogOut(100,"Writing out $FileName / $File to $File_Loc for $userlogin",$LogFile);
	open (OUTFILE,">$File_Loc") || &LogOut(0,"Error writing file $File_Loc for $userlogin",$ErrorLog);
	binmode(OUTFILE);
	while (read($File,$data,1024)) { print OUTFILE $data;   }
	close(OUTFILE); 
	return $File_Loc; 
}

sub Check_User {
  # Confirm the user submitting the file is actually in the game and the correct player
  my ($file_prefix, $user_login, $playerId) = @_;
  my $sql = qq|SELECT * from GameUsers WHERE User_Login =\'$user_login\' AND GameFile = \'$file_prefix\' AND PlayerID = $playerId;|;
  $db=&DB_Open($dsn);
  if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
  &DB_Close($db);
  if ($GameValues{'User_Login'} eq $user_login) { 
    &LogOut(200,"Check_User: $file_prefix, $user_login, $playerId, $sql",$LogFile);
    return 1;
  } else {
    &LogOut(0,"Check_User: Attempt to upload turn for different player: $file_prefix, $user_login",$ErrorLog);
    return 0;
  }
}

