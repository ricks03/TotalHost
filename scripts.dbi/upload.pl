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
use CGI::Session qw/-ip-match/;
CGI::Session->name('TotalHost');
use File::Basename;
use DBI;
do 'config.pl';
use TotalHost; # eval'd at compile time
use StarStat;  # eval'd at compile time
use StarsBlock;# eval'd at compile time

$CGI::POST_MAX=1024 * 55;  # 16 player Zip file is 52k, formerly max 25K posts

# Read in the post values and clean them a bit
#foreach my $field (param()) { 	$in{$field} = &clean(param($field)); }
my %in;
foreach my $field (param()) {
   my $value = param($field);  # Get the values for the current parameter in list context
   $in{$field} = clean($value);  # Clean and assign to %in hash
}

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
my $client_ip = $ENV{'REMOTE_ADDR'};

my $cgi = CGI->new; # Create the new CGI Session     
my $cookie = $cgi->cookie('TotalHost');  # Get the cookie information
my $session = CGI::Session->new("driver:File", $cookie, {Directory=>"$Dir_Sessions"});
my $sessionid = $session->id unless $sessionid;

# make the user values handy and easy to use
my $id = $session->param("userid");
my $userlogin = $session->param("userlogin");

&validate($cgi,$session); # Confirm user or Display error and end.

#print $cgi->header(); # Create a page header
 
# If there was an uploaded file
if ($File) {
  $valid_file = &ValidateFileUpload($File);
  my $newPage = qq|$WWW_Scripts/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err|;
  # Redirect to newPage, which solves for reloading the page retaking the action.
  # Nothing can print before this or it breaks.
  #  print $cgi->redirect($newPage);  # Doesn't work
  print "Location: $newPage\n\n";
} else { 
  print $cgi->header(); # Create the HTML page header
  print qq|<meta HTTP-EQUIV="REFRESH" content="2; url=| . $WWW_Scripts . qq|/page.pl?GameFile=$GameFile&File=$in{'File'}&Name=$in{'Name'}&lp=$in{'lp'}&cp=$in{'cp'}&rp=$in{'rp'}&status=$err">|;
  print $cgi->start_html;
  $err .= "$userlogin: File Name must be provided for upload." ;
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
  $File = basename($File);   # Clean up the file name for IE6 which includes path
	# Break the filename into component parts
	my ($file_prefix, $file_player, $file_type, $file_ext) = &FileData ($File); 
	&LogOut(300,"ValidateFileUpload: File type = $file_type",$LogFile); 
	#&LogOut(200, "File Data: $file_prefix, $file_player, $file_type, $file_ext", $LogFile);     In StarStat.pm
	# If it's not the right type of file at all, who cares about anything else; toss it but give the user a vague hint
	unless (&Check_FileType($file_type)) { 
    # Don't give users the file location
    $err .= "Invalid File Type by $userlogin"; 
    &LogOut(0, "Invalid File Type for $File_Loc by $userlogin: $file_type, $file_ext, $client_ip", $ErrorLog); 
    return 0;
  }   
  
	# Race Files
	if ($file_type eq 'r') {
    # Check to make sure the Race Name was entered
    if ($RaceName) {
      # Confirm there's not already a entry with that name
      my $row;
      $sql = qq|SELECT RaceName from Races where RaceName = '$RaceName' AND User_Login = '$userlogin';|;
  		$db=&DB_Open($dsn);
      if (my $sth = &DB_Call($db,$sql)) { 
        $row = $sth->fetchrow_hashref(); %RaceValues = %{$row}; 
        $sth->finish();
      }
      &DB_Close($db);
      if ($RaceValues{'RaceName'}) {
  				$err .= "Race Name $RaceName already exists in your profile."; 
  				&LogOut (0,"ValidateFileUpload: Race Name $RaceName already exists in profile for $userlogin: $err, $File_Loc, $client_ip", $ErrorLog);
          if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
          return 0;    
      }
      
      # Check to see if the race file is corrupt
      if (&checkRaceCorrupt($File_Loc)) {
        $err .= 'This race file is corrupt! Caused by making the plural name too short. Recreate the race or fix it with StarsRace.exe !!';
        &LogOut (0, "ValidateFileUpload: Race file $File_Loc corrupt for $userlogin",$ErrorLog);
        if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
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
  				$db = &DB_Open($dsn);
          if (my $sth = &DB_Call($db,$sql)) { 
            my $row = $sth->fetchrow_hashref(); %UserValues = %{$row};  
            $sth->finish();
          }
          &DB_Close($db);
  	      &LogOut(200,"$sql",$SQLLog); 
  
          my $racefiledir = "$Dir_Races/$UserValues{'User_File'}";  
          # If the User Race folder doesn't exist, create it. 
          if (not(-e($racefiledir))) {
            my $call = "mkdir $racefiledir";
            my $exit_code = system($call);  # Where 0 is success
            if ($exit_code) { &LogOut(0,"ValidateFileUpload: Failed to create Race Directory, $racefiledir, $client_ip",$ErrorLog); }
            #unless (mkdir $racefiledir) { &LogOut(0,"ValidateFileUpload: Failed to create Race Directory $racefiledir",$ErrorLog); }
          }
          #write out the race name to where it is supposed to go.
          $File = lc($File);
   		    my $Race_Destination = "$racefiledir/$File"; 
   				if (not(-f $Race_Destination)) { #if the file does not already exist
						if (&Move_Race($File_Loc, $Race_Destination)) { # move the race to its final location
							$err .= "Race File $File Uploaded.\n";
							&LogOut(200,"ValidateFileUpload: $File $File_Loc moved to $Race_Destination for $userlogin: $err", $LogFile);
        			# Add the new race to the database
    					$db = &DB_Open($dsn);
    					$sql = "INSERT INTO Races (RaceName, RaceFile, User_Login, RaceDescrip, User_File) VALUES ('$RaceName', '$File', '$userlogin', '$RaceDescrip', '$UserValues{'User_File'}');";
      				if (my $sth = &DB_Call($db,$sql)) { # If the SQL query is not a failure
      					#$err .= "Database updated"; # This causes a crash. No idea why
      					&LogOut(200, "ValidateFileUpload: Race Database Updated for User: $userlogin, File: $File, $err",$LogFile);
                $sth->finish();
    					} else {
    						$err .= "File $File failed to insert into database. Had you entered a race name?";
    						&LogOut(0,"ValidateFileUpload: Failed to insert $File into database for $userlogin: $err, $client_ip", $ErrorLog);
              }
    					&DB_Close($db);
							return 1; 
						} else { 
							$err .= "RaceFile $File failed to move/upload\n"; 
							&LogOut(0,"ValidateFileUpload: Race file $File_Loc failed to move to $Race_Destination for $userlogin: $err", $ErrorLog);
              if (-f $File_Loc ) { unlink $File_Loc; &LogOut(0,"Race file $File_Loc unlinked: $err", $ErrorLog);} #user-input cleaned as much as I can. 
              return 0;
						}
						return 0;
  				} else {
  					$err .= "<b>ERROR: Race File: $File already exists. Delete the race that uses that file (or rename the file you are uploading) and try again!</b>";
            if (-f $File_Loc ) { unlink $File_Loc; }  # Delete the temp file
  					&LogOut(0, "ValidateFileUpload: Race File: $File $File_Loc already exists at $Race_Destination: $err, $client_ip", $ErrorLog); 
  					return 0; 
  				}
  			} else { 
  				$err .= uc($File) . " not a valid Race ( .r1 ) file."; 
          &LogOut (0, "ValidateFileUpload: Invalid Race (.r1) File: Deleted $File_Loc for $userlogin",$ErrorLog);
          if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
  				return 0; 
  			}
  		} else {
  			$err .= "Failed Race File upload of $File by $userlogin";
  			&LogOut(0, "ValidateFileUpload: Invalid race file upload of $File_Loc by $userlogin. CheckMagic: $checkmagic, CheckVersion: $checkversion: $err, $client_ip", $ErrorLog);
        if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
  			return 0;
  		}
    } else {
       $err .= 'You must enter a Race Name for your race (this field is independent of the name in the file). Try Again!';
       &LogOut(0, "Upload: No race name entered for $userlogin, $client_ip",$ErrorLog);
    }
	} elsif ($file_type eq 'x') { # A turn file
 		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		&LogOut(300,"ValidateFileUpload: DTS2: $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware, $client_ip", $LogFile);
    # Validate the .x file
	  # DT: 'Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File'
    # $err results will display at the top of the game page when it refreshes, comma-delimited
    if (!($dt == 1))                                { $err .= 'Not a Stars! .x file'; &LogOut(0,"ValidateFileUpload: Invalid .x file dt = $dt, $File_Loc for $userlogin, $client_ip",$ErrorLog); }
    elsif (!(&Check_Magic($Magic, $File_Loc)))      { $err .= "Invalid Magic $Magic"; &LogOut(0,"ValidateFileUpload: Invalid Magic $Magic, $File_Loc for $userlogin, $client_ip",$ErrorLog); }
    elsif (!(&Check_Version($ver, $File_Loc)))      { $err .= "Invalid Version $ver"; &LogOut(0,"ValidateFileUpload: Invalid version $ver, $File_Loc for $userlogin, $client_ip",$ErrorLog); }
    elsif (!(&Check_GameFile($file_prefix)))          { $err .= "Invalid Game File $file_prefix"; &LogOut(0,"ValidateFileUpload: Invalid game file $file_prefix for $userlogin, $client_ip",$ErrorLog); }
    # Check_Player checks the extension of the file against the starstat value of the player
  	elsif (!(&Check_Player($file_player,$iPlayer))) { $err .= 'Invalid Player ID'; &LogOut(0,"ValidateFileUpload: Invalid Player ID Turn file $File $File_Loc for $userlogin, $client_ip",$ErrorLog); }
    # Check_Turn validates that this file is fo rthe correct turn.
		elsif (!(&Check_Turn($file_prefix, $turn)))       { $err .= "Wrong Year! ($turn)"; &LogOut(0,"ValidateFileUpload: Invalid Year Turn file $File $File_Loc for $userlogin, $client_ip",$ErrorLog);}
    # Check_GameID validates that the file is the correct file ID fo rthis game
		elsif (!(&Check_GameID($file_prefix, $lidGame)))  { $err .= 'Wrong Game ID!'; &LogOut(0,"ValidateFileUpload: Invalid Game ID $file_prefix, $lidGame $File_Loc $File for $userlogin, $client_ip",$ErrorLog); }
    # Check_User validates that this user is the correct user for this turn
		elsif (!(&Check_User($file_prefix, $userlogin, $iPlayer)))  { $err .= "Wrong User!"; &LogOut(0,"ValidateFileUpload: Invalid User $file_prefix, $file_player,$iPlayer $File_Loc $File for $userlogin, $client_ip",$ErrorLog); }
    # Check that the turn won't trigger a serial/hardware conflict
		elsif (my $errSerial = &checkSerials($File_Loc))  { $err .= "$errSerial"; &LogOut(0,"ValidateFileUpload: Serial/hardware error $err $File_Loc for $userlogin, $client_ip",$ErrorLog); }

    # If any critical errors have been reported, error. Delete the file.
    if ($err) { 
      &LogOut(0, "ValidateFileUpload: Error $err, $errSerial , $client_ip", $ErrorLog); 
      # Pass the results to $err for display
      $err = 	$File . " not a valid .x[n] file: $err $errSerial. DISCARDING FILE"; 
      if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
      return 0; 
    } else {&LogOut(300, "ValidateFileUpload: No errors for $in{'GameFile'}", $LogFile); }
    
    # Unless there was an error, move the file to the game folder
    unless ($err) { 
			# Do whatever you would do with a valid change (.x) file
			if (&Move_Turn($File, $file_prefix)) {
        $makeCHKrun = 0; # Let's not run MakeCHK more than we have to
				$db = &DB_Open($dsn);
				# update the Last Submitted Field
				$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.LastSubmitted = | . time() . qq| WHERE GameUsers.GameFile=\'$file_prefix\' AND GameUsers.User_Login=\'$userlogin\';|;
				if (my $sth = &DB_Call($db, $sql)) {
					&LogOut(200, "ValidateFileUpload: Last Submitted updated for $File, $File_Loc, $file_prefix for $userlogin, $client_ip", $LogFile);
          $sth->finish();
				} else {
					&LogOut(200, "ValidateFileUpload: Last Submitted update FAILED $File, $File_Loc, in $file_prefix for $userlogin, $client_ip", $ErrorLog); 
				}
        
        # Now that the file is legit, fix anything else wrong with it.
        # Check (and potentially fix) the .x file for known Stars! exploits
        # Requires List files (.fleet, .queue, etc)
        # Requires a file named 'fix' in the game folder as an additional safety net 
        my $fixFile = "$Dir_Games/$GameFile/fix";
        my $warning; 
        if ($fixFiles && -f $fixFile) { 
          &LogOut(300, "ValidateFileUpload: fixfile: $fixFile fixFiles: $fixFiles, $File_Loc, $client_ip", $LogFile); 
          my $gameDir = "$Dir_Games/$GameFile";
          $warning = &StarsFix($gameDir, "$gameDir/$file_prefix.$file_ext", $turn);
          &LogOut(200, "ValidateFileUpload: $gameDir, $warning, $client_ip", $LogFile); 
          if ($warning) {
            # Append any errors from the Fix to the display
            $err .= $warning;
            # Append the error(s) to the .warnings file
            &process_fix($file_prefix, "$warning");
            &LogOut(0, "ValidateFileUpload: fixFiles $fixFiles, $err, $turn, $File_Loc, $client_ip", $ErrorLog);
          }
        }
 
        # If the game is AsAvailable, check to see if all Turns are in and whether we should generate. 
   			$sql = qq|SELECT * FROM Games WHERE GameFile = \'$file_prefix\';|;
 				# Load game values into the array
        if (my $sth = &DB_Call($db,$sql)) { 
          my $row = $sth->fetchrow_hashref(); %GameValues = %{$row}; 
          $sth->finish();
        } # Should return only one value
				&DB_Close($db);
        if ($GameValues{'AsAvailable'} == 1 ) { # Don't immediately generate As Available if the file generated warnings
          if ($warning) {
            $err .= "Not immediately generating As Available game $file_prefix due to Warnings. Will generate on next turn check interval however.\n";
            &LogOut(100, "upload: AsAvailable $err for $GameFile $userlogin", $LogFile);
          } else {
            # Run TurnMake for the game. TurnMake will handle for emails, .chk file, etc.
            #my $MakeTurn = "perl -I $Dir_Scripts $Dir_Scripts/TurnMake.pl $GameFile >/dev/null";
            my $MakeTurn = "$PerlLocation -I $Dir_Scripts $Dir_Scripts/TurnMake.pl $GameFile >/dev/null";
            &LogOut(100, "upload.pl: Calling system for $MakeTurn", $LogFile);
            #chdir($WINE_path) or &LogOut(0,"Cannot change directory: $WINE_path",$ErrorLog);
            # There's a recursion problem when calling TurnMake using call_system, because then TurnMake calls TurnMake.
            # Don't need to use sudo, because this is being called by apache2, running as www-data
            my $exit_status = system($MakeTurn); # Starting system with 1 makes it launch asynchronously, in case Stars! hangs
            if ($exit_status > 0) { $makeCHKrun = 1; }  # Since TurnMake.pl could run Make_CHK, no need to run it twice
            &LogOut(0, "upload: Ending call: $MakeTurn, Exit Status: $exit_status", $LogFile); 
          	sleep 2;
          }
        }
        # BUG: it's not runnig Make_CHK  when AsAvailable. This could mean running it twice, but at least it will run
        if  ($makeCHKrun != 256 ) { &Make_CHK($file_prefix); } # Only run if we haven't already, 256 is running Stars!, 1 is Turns Missing
        #&Make_CHK($file_prefix);
				return 1; 
			} else { 
        # If the file failed to move, report and remove. 
        $err .= "<P>File failed to move!\n";
				&LogOut(0,"ValidateFileUpload: File $File $File_Loc, $file_prefix failed to move for $userlogin, $client_ip",$ErrorLog);
        if (-f $File_Loc ) { unlink $File_Loc; } #user-input cleaned as much as I can. 
        return 0;
			}
		}
	# Zip files
	} elsif ($file_type eq 'z') {  # Check_Filetype checks the first letter
		# Extract Zip files and check all the files inside
    use Archive::Zip;    
    
    # Path to the zip file and the destination directory
    my $zip_file = $File_Loc;
    my $final_destination_dir = $Dir_Games . "/$GameFile";
    my $all_files_valid = 1; # Initialize a flag to track if all files pass validation    
    my @extracted_files; # Store extracted files for later copying  
    my $xy_present = 0;
    my $hst_present = 0;
        
    my $file_size = -s $zip_file; # Get the size in bytes and don't unzip if it's too big
    # 16-player, zipped, is 40k in 2400, 52k in 2401 (with no turns submitted)
    if ($file_size >= 55 * 1024) { 
      $err .= "The zip file is too large ($file_size bytes). It must be smaller than 20 KB.";
      &LogOut(0,"The zip file $zip_file is too large ($file_size bytes). It must be smaller than 20 KB.", $ErrorLog); 
      $all_files_valid = 0;
    } 
    
    my $zip = Archive::Zip->new($zip_file);
    if (!$zip) { # Open the zip file
      $err .=  "Cannot read Zip file: $!";
      &LogOut(100,"Cannot read $zip_file: $!", $ErrorLog);  
      $all_files_valid = 0;
    } 
     
    # Check for subdirectories in the zip file
    foreach my $member ($zip->members()) {
      if ($member->isDirectory()) {
        $err .= "The zip file contains subdirectories, which are not allowed.";
        &LogOut(100, "The zip file $member contains subdirectories, which are not allowed", $ErrorLog); 
        $all_files_valid = 0;
        last;
      } 
    } 
      
    my @members = $zip->members();
    foreach my $member (@members) {  
      # Extract the file to the extraction directory
      my $file_name = $member->fileName();
      my $extracted_path = "$Dir_Upload/$file_name";
      
      # Prevent extraction of files outside the intended directory
      if ($file_name =~ /\.\.|^\//) {
          $err .= "Unsafe file $file_name. ";
          &LogOut (0,"Skipping potentially unsafe file: $filename", $ErrorLog);
          $all_files_valid = 0;
          next;
      }
      
      $member->extractToFileNamed($extracted_path);
      if (!$member) {
        $err .= "Failed to extract $file_name: $!";
        &LogOut(100,"Failed to extract $file_name: $!",$ErrorLog);
        $all_files_valid = 0;
        next;
      } 
      # Check if the file has a valid extension
      my $valid_extensions = qr/\.((m\d{1,2})|xy|hst)$/i; # .m1 to .m99, .xy, or .hst
      unless ($file_name =~ $valid_extensions) { 
        $err .= "Invalid file extension for '$file_name'. Must be .m*, .xy, or .hst. ";
        &LogOut ("Invalid file extension for '$file_name'. Must be .m*, .xy, or .hst. ", $ErrorLog); 
        $all_files_valid = 0;
        next;
      }      
      my ($base, $dir, $ext) = fileparse($file_name, qr/\.[^.]*/); # Extract file extension
      $ext = lc($ext);  # Lower-case the extension   
      if ($ext =~ /xy/) { $xy_present = 1; }
      if ($ext =~ /hst/) { $hst_present = 1; }
      
      # Rename the file to the specified base name with its extension
      my $new_file_path = "$Dir_Upload/$GameFile$ext";
      
      # Rename if necessary
      if (!rename($extracted_path, $new_file_path)) { 
        $err .= "Failed to rename $extracted_path to $new_file_path: $!";
        &LogOut(100,"Failed to rename $extracted_path to $new_file_path: $!", $ErrorLog);
        $all_files_valid = 0;  
        next;
      } 
      $extracted_path = $new_file_path;  # Update the path after renaming
      &LogOut(100,"Renamed $file_name to $GameFile$ext",$ErrorLog); 
  
      # Run validations using starstat and Check_Magic/Check_Version
      my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($extracted_path);
      my $checkmagic = &Check_Magic($Magic, $extracted_path);
      my $checkversion = &Check_Version($ver, $extracted_path);
     
      # If any file fails validation, stop processing
      unless ($checkmagic && $checkversion) {
        $err .= "Validation failed for file: $file_name. ";
        &LogOut(100, "Validation failed for file: $file_name", $ErrorLog);
        $all_files_valid = 0;
        next;
      }
      # Keep track of the extracted files
      push @extracted_files, $extracted_path if $checkmagic && $checkversion;
    }  
    # If all files passed validation, copy them to the final destination
    # after some additional varification
    if ($all_files_valid && $xy_present && $hst_present && scalar(@extracted_files) >= 3 && scalar(@extracted_files) <= 18) {
      # Ensure the final destination directory exists
      if (!-d $final_destination_dir) { # Check if directory doesn't exist
        if (!mkdir $final_destination_dir) {
          $err .= "Failed to create directory $final_destination_dir: $!";
          &LogOut(100, "Failed to create directory $final_destination_dir: $!", $ErrorLog);
          exit 1; # Exit the script if directory creation fails
        } 
        &LogOut(100, "Created directory: $final_destination_dir", $ErrorLog);
      } 
      foreach my $file (@extracted_files) {
        my $destination_path = "$final_destination_dir/" . basename($file);
        if (!copy($file, $destination_path)) { 
          $err .= "Failed to copy file to destination.";
          &LogOut(100, "Failed to copy $file to $destination_path: $!", $ErrorLog);
          next;
        } 
        # Set permissions to 660
        if (!chmod 0660, $destination_path) { 
          $err .= "Failed to set permissions for destination path.";
          &LogOut(100,"Failed to set permissions for $destination_path: $!", $ErrorLog);
        } 
      }
      &LogOut(200, "Zip File: All files have been validated, unzipped, renamed (if needed), and copied to $final_destination_dir for ID: $id, GameFile: $GameFile", $LogFile);
      &Make_Zip_Game($id, $GameFile);
    # Redirect the UI to the Replace Player Player UI
      $in{'cp'} = 'Replace Player';  
    } else {
      if (!$xy_present) { $err .= "No .xy file present. "; }
      if (!$hst_present) { $err .= "No .hst file present. "; }
      $err .= "One or more files failed validation. No files were copied.";
      &LogOut(200,"One or more files failed validation. No files were copied, $err", $ErrorLog);
      return 0;
    }
    # Cleanup: Delete only the extracted files (not directories) and the orginal zip
    foreach my $file (@extracted_files) {
      if (-f $file) { unlink $file or &LogOut(0,"Zip File: Failed to delete $file: $!", $Error_Log); } 
    } 
    if (-f $zip_file) { unlink $zip_file or &LogOut(0,"Zip File: Failed to delete $zip_file: $!", $Error_Log); }     
	} else { 
		$err .=  qq|$file_type is an invalid file type for $userlogin\n|;
		&LogOut(0,"ValidateFileUpload: Invalid File Type: $file_type, $File, $File_Loc, $userlogin: $err, $client_ip",$ErrorLog);
		return 0;  
 	}  
}

sub Make_Zip_Game {
  # Set up an uploaded, validated zip game. Get the player count from the .chk file
  my ($id, $GameFile) = @_;  # $id is the logged-in user, and thus the host creating the game
  my $sql; 
  # run Make_CHK
  my @CHK = &Read_CHK($GameFile); # There's no .chk file in an uploaded turn, but Read_CHK will make one
  # Determine # of players
  my $num_players = (scalar @CHK) -3;  # There are 3 starting lines to a .chk file we need to remove
  # Get the game data for the game
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile'|;
  my $db = &DB_Open($dsn);
  if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); 
    %GameValues = %{$row};  
    &LogOut(300,"Make_Zip_Game: Get Game data from $GameFile", $LogFile);
    $sth->finish();
  }
  # Add all the players (who are all the host) to the game 
   for (my $i = 1; $i <= $num_players; $i++) {
     $GameValues{'RaceFile'} = undef; # We don't have a race file for a zip game
     $GameValues{'RaceID'} = 0; # We don't have a race ID for a zip game  
     my $now = time();
     $sql = qq|INSERT INTO GameUsers (GameName, GameFile, RaceFile, RaceID, User_Login, DelaysLeft, PlayerID, PlayerStatus, JoinDate, LastSubmitted) VALUES ('$GameValues{'GameName'}','$GameFile','$GameValues{'RaceFile'}',$GameValues{'RaceID'},'$GameValues{'HostName'}',$GameValues{'NumDelay'},$i,1,$now,0);|;
     if (my $sth = &DB_Call($db,$sql)) { $sth->finish(); }
   } 
  # Pause the game so the host can update the players
  $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameFile\';|;
  if (my $sth = &DB_Call($db,$sql)) {  $sth->finish(); } 
  &DB_Close($db);
}

sub Move_Turn {
	use File::Copy;
	# Move the turn from the temp location to its final destination
	my ($Turn_File, $Turn_Name) = @_; 
 	my($Turn_Source)= $Dir_Upload . '/' . $Turn_File;  
 	my($Turn_Destination)= $Dir_Games . '/' . $Turn_Name . '/' . lc($Turn_File);  
	# If we got to here the file is valid, so we can overwrite
	move($Turn_Source, $Turn_Destination) or return 0;
	&LogOut(100,"Turn File $Turn_File moved from $Turn_Source > $Turn_Destination",$LogFile);
	return 1; 
}

sub Move_Race {
	use File::Copy;
	# Move the race from the temp location to its final destination
	my ($Race_Source, $Race_Destination) = @_; 
 	if (not(-f $Race_Destination)) { #if the file does not already exist
		if (move($Race_Source, $Race_Destination)) {
		  &LogOut(100,"Race File moved from $Race_Source to $Race_Destination",$LogFile);
		  return 1;
    } else { &LogOut(100,"Race File failed to move from $Race_Source to $Race_Destination, $client_ip",$ErrorLog); return 0;}
  } else {
		#otherwise tell them the file already exists
		&LogOut(0,"Move_Race: Race file $Race_Source already exists at $Race_Destination--nice try: $err, $client_ip",$ErrorLog);
		return 0;
  }
}

sub Save_File {
	my ($File) = @_; 
  # In Windows, Stars! turns are saved as upper case (esp. the file extension). In 
  #   Linux, the file extensions when created are lower case. So everything uploaded as 
  #   lower case appears to be the ideal simplest path. 
  #$File = lc($File);
  # Strip any path information off the uploaded File
  # Since for some reason some browsers (IE6) include it
  use File::Basename;
  if ($File) { 
    $FileName = basename($File); 
    my $File_Loc = $Dir_Upload . '/' . $FileName;  #write out the race file to where it is supposed to go.
    &LogOut(100,"Writing out $FileName / $File to $File_Loc for $userlogin",$LogFile);
    open (OUTFILE,">$File_Loc") || &LogOut(0,"Error writing file $File_Loc for $userlogin, $client_ip",$ErrorLog);
    binmode(OUTFILE);
    while (read($File,$data,1024)) { print OUTFILE $data;   }
    close(OUTFILE); 
    #&LogOut(100,"chmod $mode, $File_Loc",$ErrorLog);
    umask 0002; 
    chmod 0660, $File_Loc;
    return $File_Loc;
  } 
}

sub Check_User {
  # Confirm the user submitting the file is actually in the game and the correct player
  my ($file_prefix, $user_login, $playerId) = @_;
  my $sql = qq|SELECT * from GameUsers WHERE User_Login =\'$user_login\' AND GameFile = \'$file_prefix\' AND PlayerID = $playerId;|;
  my $db=&DB_Open($dsn);
  if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};
    $sth->finish();  
  }
  &DB_Close($db);
  if ($GameValues{'User_Login'} eq $user_login) { 
    &LogOut(200,"Check_User: $file_prefix, $user_login, $playerId, $sql",$LogFile);
    return 1;
  } else {
    &LogOut(0,"Check_User: Attempt to upload turn for different player: $file_prefix, $user_login, $client_ip",$ErrorLog);
    return 0;
  }
}

