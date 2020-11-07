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
use StarsBlock;
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

if ($valid_file) { 
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
    # Don't give users the file location
    $err .= "Invalid File Type for $File by $userlogin"; 
    $invalid = "Invalid File Type for $File, $File_Loc by $userlogin: $file_type $file_ext"; 
    &LogOut(0, "$invalid", $ErrorLog); 
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
  				$err .= "$File not a valid Race ( .r1 ) file"; 
  				&LogOut (0,"ValidateFileUpload: Invalid race file $File in $File_Loc for $userlogin: $err", $ErrorLog);
          &LogOut (0, "ValidateFileUpload: Invalid Race (.r1) File: Deleted $File_Loc",$ErrorLog);
          # Danger deleting user defined files. 
          unlink $File_Loc;
  				return 0; 
  			}
  		} else {
  			$err .= "Invalid Race File upload of $File by $userlogin";
  			&LogOut(0, "ValidateFileUpload: Invalid race file upload of $File to $File_Loc by $userlogin. CheckMagic: $checkmagic, CheckVersion: $checkversion: $err", $ErrorLog);
        # BUG: This is full of security errors, and you could be deleting a file that exists. 
        unlink ($File_Loc);
        &LogOut (0, "Invalid Race File: Deleted $File_Loc",$ErrorLog);
  			return 0;
  		}
    } else {
       $err .= 'You must enter a Race Name for your race (this field is independent of the name in the file). Try Again!';
       &LogOut (0, "Upload: No race name entered for $userlogin",$ErrorLog);
    }
	} elsif ($file_type eq 'x') { # A turn file
		($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($File_Loc);
		&LogOut(300,"ValidateFileUpload: DTS2: $Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware", $LogFile);
		if ( ($dt == 1) && &Check_Magic($Magic, $File_Loc) && &Check_Version($ver, $File_Loc) && &Check_GameFile($game_file) && &Check_Player($file_player,$iPlayer) && &Check_Turn($game_file, $turn) && &Check_GameID($game_file, $lidGame)) {
      # Check (and potentially fix) the .X file for known Stars! exploits
      # Requires the .queue file to detect CleanStarbase
      # Works on a folder-by-folder (game-by-game) basis 
      # Requires a file named 'fix' in the game folder
      my $fixFile = $FileHST . '\\' . $GameFile . '\\' . 'fix';
      if ($fixFiles && -e $fixFile) { 
        &LogOut(200, "ValidateFileUpload: A fixfile: $fixFile fixFiles: $fixFiles, $err, $File_Loc", $LogFile); 
        print "<P>Checking file for exploits ...\n";
        $err .= &StarsFix($File_Loc, $GameFile, $turn);   #$File_Loc includes path
      } 
      if ($err) { &LogOut(0, "ValidateFileUpload: fixFiles $fixFiles, $err, $File_Loc", $ErrorLog); }
      
			&LogOut(100,"ValidateFileUpload: Valid Turn file $File_Loc, moving it", $LogFile);
      
			# Do whatever you would do with a valid change (.x) file
      # BUG: This implies we accept the errored StarsFix file?   In some cases we haven't fixed it.
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
			$err .= "$File not a valid Turn ( .x[n] ) file."; 
      # BUG: Check_Player checks the extension of the file against the starstat value of the player
      # It doesn't actually check the User ID to confirm that user ID can submit the file. 
      # That function should probably be in Check_Player, but Check_Player isn't aware
      # of the other data it will need to figure that out ($id, $userlogin). 
			unless (&Check_Player($file_player,$iPlayer)) { $err .= "Invalid Player ID.\n"; &LogOut(0,"ValidateFileUpload: Invalid Player ID Turn file $File $File_Loc for $userlogin",$ErrorLog);}
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
		$err .= "You've uploaded a zip file, and we\'re not sure what to do with that yet!\n";
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
  $err .= "File Name must be filled in to upload.\n" ;
#  print "<P>$err";
  &LogOut(10,$err,$ErrorLog);
  return 0;
}

sub StarsFix {
  my ($xFile, $GameFile, $turn) = @_; # .x file location includes path   (Uploads)
  my $needsFixing = 0;
  my $queueCounter = 0;
  my %queueList;
  &PLogOut(100,"StarsFix: fixing .x: $xFile", $LogFile);
  
  #read in the .queue file for Cheap Starbase analysis  
  my $queueFile =  $FileHST . '\\' . $GameFile. '\\' . $GameFile . '.hst' . ".$turn" . '.queue';
  if (-e $queueFile ) { 
    my ($Player,$planetId,$itemId,$count,$completePercent,$itemType, $queueSize);
    my @queueFile;
    &PLogOut(200,"StarsFix: Reading in QUEUEFILE $queueFile", $LogFile);
    open (IN_FILE,$queueFile) || die("Cannot open $queueFile file");
    @queueFile = <IN_FILE>;
  	close IN_FILE;
    # Turn the file into a usable hash
    foreach my $line (@queueFile) {
    	chomp($line);
     	($Player,$planetId,$itemId,$count,$completePercent,$itemType, $queueSize)	= split (',', $line);
      # There is no unique combination of values for a queue
      # So using a faux-counter
      $queueList{$queueCounter}{Player} = $Player;
      $queueList{$queueCounter}{planetId} = $planetId;
      $queueList{$queueCounter}{itemId} = $itemId;
      $queueList{$queueCounter}{count} = $count;
      $queueList{$queueCounter}{completePercent} = $completePercent;
      $queueList{$queueCounter}{itemType} = $itemType;
      $queueList{$queueCounter}{queueSize} = $queueSize;
      $queueCounter++;
    }
  }
  
  # Read in the binary Stars! file(s), byte by byte
  my $fileValues;
  my @fileBytes;
  open(StarFile, "<$xFile" );
  binmode(StarFile);
  while ( read(StarFile, $fileValues, 1)) {
    push @fileBytes, $fileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
#  my ($outBytes, $needsFixing, $warning) = &decryptFix(\@fileBytes,\%queueList);
  my ($outBytes, $needsFixing, $warning) = &decryptFix(\%queueList);
  my @outBytes = @{$outBytes};
  my %warning = %$warning;
  
  # Need to return a string since passing an array through a URL is unlikely to work
  my $warning = '';
  foreach my $key (keys %warning) {
    $warning .= $warning{$key} . ",";
  }
  # Output the Stars! file with modified data
  # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
  if ($needsFixing) {
    # Backup the file before we clean it
    # Because otherwise we can't get back to where we were, as the
    # backup is pre-turn generation, so random event will change.
    # BUG: File name is important here, as backups work from the filename
    #   So do we want these to be .x files?
    if ($fixFiles > 1) {  # Don't do unless in write mode
      my $xFilePreFix = 'preFix.' . $xFile;
  	  &PLogOut(300,"StarsFix Backup: $xFile > $xFilePreFix", $LogFile);
   	  copy($xFile, $xFilePreclean);
      &PLogOut(200," StarsFix: Pushing out $xFile post-fixing", $LogFile);
      open ( outFile, '>:raw', "$xFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print outFile $outBytes[$i];
      }
      close ( outFile);
      &PLogOut(200," StarsFix: Fixed $xFile", $LogFile);
    } else { &PLogOut(300," StarsFix: Not in Fix mode for $xFile", $LogFile); }
    return $warning;
  } else { 
  	&PLogOut(300,"StarsFix: $xFile does not need fixing", $LogFile);
    return $warning; 
  }  
}

sub decryptFix {
  my ($queueList) = @_;
  #my @fileBytes = @{$fileBytes};
  my %queueList = %$queueList;

  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my $needsFixing;
  my ($planetId, $ownerId); 
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

    #if ( $debug  > 1) { print "BLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; }
    #if ( $debug  > 1) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
    #if ($debug > 100) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        my $playerId = $decryptedData[0] & 0xFF; 
        my $shipDesigns = $decryptedData[1] & 0xFF;  
        my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); 
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); 
        #print " Starbase Designs: $starbaseDesigns\n";
        $player{$playerId}{shipDesigns} = $shipDesigns;
        $player{$playerId}{planets} = $planets;
        $player{$playerId}{fleets} = $fleets;
        $player{$playerId}{starbaseDesigns} = $starbaseDesigns;
        $designShipTotal +=  $player{$playerId}{shipDesigns};
        $designBaseTotal +=  $player{$playerId}{starbaseDesigns};
        $lastPlayer = $playerId; # keep track of the largest known player Id
      } elsif ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .M and .HST file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
        ### Other stuff after I have the player ID
        my $flags = &read16(\@decryptedData, 2);
        my $isHomeworld = ($flags & 0x80) != 0;
        my $index = 4;
        # More in the block I don't care about right now.       
      } 
      # Detect the Cheap Starbase in the producton queue
      elsif ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
        # if not a .x file, we get the player Id from the most recent planet info
        # because the player info isn't in the ProductionQueueBlock 
        my $index = 0;
        my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
        if ($typeId == 28) { 
          $Player = $ownerId; 
          $index = 0;
       } elsif ($typeId == 29) { # Testing for ProductionQueueChangeBlock
          # planet ID is only in the ProductonQueueChangeBlock
          $planetId = &read16(\@decryptedData, 0);
          $index = 2;
        } 
        #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        if ($typeId == 29 ) {
          # Any change means erasing any old values for this planet
          foreach my $queueCounter (keys %queueList) {
            if (exists ($queueList{$queueCounter}{planetId}) ) { 
                  delete $queueList{$queueCounter}; 
            }
          }  
        }
        for (my $i=$index; $i <= scalar(@decryptedData) -4; $i=$i+4) {
          $chunk1 = &read16(\@decryptedData, $i);
          $chunk2 = &read16(\@decryptedData, $i+2);
          $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
          $count = $chunk1 & 0x3FF; # Bottom 10 bits
          $completePercent = $chunk2 >> 4; #Top 12 bits
          $itemType = $chunk2 & 0xF; # bottom 4 bits
          #print "Queue: Player: $Player, planetId: $planetId, itemId: $itemId, count: $count, %complete: $completePercent, itemType: $itemType, size: $size\n"; 
          $queueCounter++;
          $queueList{$queueCounter}{Player} = $Player;
          $queueList{$queueCounter}{planetId} = $planetId;
          $queueList{$queueCounter}{itemId} = $itemId;
          $queueList{$queueCounter}{count} = $count;
          $queueList{$queueCounter}{completePercent} = $completePercent;
          $queueList{$queueCounter}{itemType} = $itemType;
          $queueList{$queueCounter}{queueSize} = $size;
          # Store an copy that won't be modified
          $queueListHST{$queueCounter}= $queueList{$queueCounter};
        }
        if ($typeId == 29 && $size == 2) { # Clear Queue 
          # Need to clear the ProductionQueue array if this is a clear queue action
          # because we no longer care about what was in this production queue prior
          # If Cheap Starbase bug, clearing the planet queue fixes it.
          foreach my $queueCounter (keys %queueList) {
            if (exists ($queueList{$queueCounter}{planetId}) && $queueList{$queueCounter}{planetId} == $planetId) { 
              #print "CLEARING queue for planet: $queueList{$queueCounter}{planetId}\n";
              delete $queueList{$queueCounter}; 
            }
          }
        }
        # If we changed a queue, check the entire queue for any planets building on the warning
        # The warning list will be shorter, so start there. 
        foreach my $warnId (keys %warning) {
          my $stillBroken = 0;
          my ($player, $designType, $designNumber, $warningType) = &splitWarnId($warnId); 
          if ($warningType eq 'cheap') {
            my $designId = $designNumber + 16;
            foreach my $queueCounter (keys %queueList) {
              if ($queueList{$queueCounter}{Player} == $player &&  $queueList{$queueCounter}{itemId} == $designId) {
                $stillBroken = 1;
              }
            }
          }
          unless ($stillBroken) {
            if (exists ($warning{$warnId}) && $warningType eq 'cheap') { 
              delete $warning{$warnId}; 
            }
          }
        }
      } 
      elsif ($typeId == 26 || $typeId == 27) { # Design & Design Change block
        print "\n\n";
        my $spacedockOverflow = 0;  #Space Dock Overflow
        my $crobyLangston = 0; #Spack Dock overflow additional armor
        if ($typeId == 26 ) { # HST File. 
          # Find design block Player Id Because the player id isn't in Block 26
          # The Design blocks are in order, and the number of them for each player are defined in the player block(s). 
          # And if it seems like a lot of work to ge this info, it is.
          # Find design block player
          $designOwner=0;
          if ($designShipTotalCounter >= $designShipTotal) { # Don't start starbases until the ships are done.
            while ($designOwner <= 0  && $designBaseTotalCounter < $designBaseTotal && $designBasePlayerId <= $lastPlayer) {
               if (exists($player{$designBasePlayerId}{starbaseDesigns}) && $designBaseCounter < $player{$designBasePlayerId}{starbaseDesigns}) {
                  $designBaseCounter++; 
                  $designBaseTotalCounter++; 
                  $designOwner = $designBasePlayerId; 
                  last;
               } else { 
                 $designBasePlayerId++; 
                 $designBaseCounter = 0; 
               }
             }
          } else {
            while ($designOwner <= 0  && $designShipTotalCounter < $designShipTotal && $designShipPlayerId <= $lastPlayer) {
               if (exists($player{$designShipPlayerId}{shipDesigns}) && $designShipCounter < $player{$designShipPlayerId}{shipDesigns}) {
                  $designShipCounter++;
                  $designShipTotalCounter++;
                  $designOwner = $designShipPlayerId; 
                   last;
               } else { $designShipPlayerId++; $designShipCounter = 0; }
            }
          }
          $Player = $designOwner;
        }  
        my $hullId;
        my $index = 0;
        if ( $typeId == 27 ) {# for the two extra bytes in a .x file 
          $index = 2; 
        }   
        my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
        $deleteDesign = $decryptedData[0] % 16;
        if ($deleteDesign == 0) { 
          $designNumber = $decryptedData[1] % 16; 
          $isStarbase = ($decryptedData[1] >> 4) % 2; 
          if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
          else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber); }  # adding a zero lets us sort on key
          
        }
        # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
        if ($deleteDesign) { 
          $isFullDesign =  ($decryptedData[$index] & 0x04); 
          $isTransferred = ($decryptedData[$index+1] & 0x80); 
          $isStarbase = ($decryptedData[$index+1] & 0x40);  
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; 
          $hullId = $decryptedData[$index+2] & 0xFF; 
          if ($isFullDesign) {
            # Since there can be a ship and base with the same designId, 
            # need to be able to keep them separate
            if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
            else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber) ; }  # adding a zero lets us sort on key
            $armor = &read16(\@decryptedData, $index+4);  
            $armorIndex = $index +4; # used to fix the Space Dock overflow
            $slotCount = $decryptedData[$index+6] & 0xFF; 
            $turnDesigned = &read16(\@decryptedData, $index+7); 
            $totalBuilt = &read16(\@decryptedData, $index+9); 
            $totalRemaining = &read16(\@decryptedData, $index+13); 
            $slotEnd = $index+17+($slotCount*4); 
            $shipNameLength = $decryptedData[$slotEnd];          
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            $index = 17;  
            if ($typeId == 27) { $index += 2; } # x files have 2 more bytes
            my $spaceDockIndex = $index; # used for the Space Dock overflow
            # Loop through once for each slot
            my $itemSum = 0; # tracking if all the design slots are empty for the Cheap Starbase bug
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
              $index += 2;
              $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
              $index++;
              $itemCount = $decryptedData[$index];
              $itemSum = $itemSum + $itemCount;
              #my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
              #if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index\n"; }
              #else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index\n";}

              # Colonizer bug
              # Ships with a colonization module removed and the slot left empty can still colonise planets
              # If a colonizer hull is created, and then edited, it's going to put 2 (or more)  entries in the .x file.
              # so need to filter.
              if ($itemId == 0 &&  $itemCategory == 4096 && $itemCount == 0) {
                # Fixing display for those who don't count from 0.
                $err .= 'WARNING: Colonizer bug detected for player ' . &plusone($Player) . ' in ship design slot ' . &plusone($designNumber) . ": $shipName (in slot " . &plusone($itemSlot) . '). ';
                $itemCategory = &read16(\@decryptedData, $index-3);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
                #print "category: $itemCategory  index: $index\n";
                ($decryptedData[$index-3], $decryptedData[$index-2]) = &write16(0); # Category
                $needsFixing = 1;
                if ($fixFiles > 1) {
                  $err .= '  Fixed!!! Slot now truly empty.';
                } else {$err .= '';}
                $warning{$warnId.'-colonizer'} = $err;
                #print "$index: $warnId: $err\n"; 
              }
              # Detect Space Dock Overflow
              # Don't fix it here because we don't know yet at a slot level what the rest of the slots are
              if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory == 8 && $itemCount > 21  && $armor  >= 49518) {  $spacedockOverflow = 1; } 
              # Check for other items that could be increasing armor
              if ( $spacedockOverflow ) { if ($itemCategory == 4 && ($itemId == 6 || $itemId == 3)) { $crobyLangston = $itemCount; } }
              # Step forward for the next slot
              $index++;
            }
            if ($spacedockOverflow) {
              # Fix Space Dock Armor slot Buffer Overflow with super latanium
              # If your race has ISB and RS, building a Space Dock with more than 21 SuperLat in the Armor slot 
              # will result in some sort of error (of massively increased armor)
              # Rick: I had hoped to fix this by simply rewriting the armor value,
              # but armor gets recalculated, so resetting the itemCount is the only choice. 
              $err = 'WARNING: Spacedock Overflow bug of > 21 SuperLatanium detected for player ' . &plusone($Player) . ' in starbase design slot ' . &plusone($designNumber) . ": $shipName. ";
              # reset the $itemCount 
              $decryptedData[$spaceDockIndex+11] = 21; # Armor slot on spacedock
              # Armor value should be 250 + (1500 * $itemCount) / 2
              $armor = 250 + (1500 * 21) / 2; # adjust for 21 Super Latanium
              if ($crobyLangston)  {  $armor += 65 * $crobyLangston; } # add on Croby or Langston armor
              #print "Updated armor value: $armor\n";
              # reset the final armor value for the spacedock overflow bug
              ($decryptedData[$armorIndex], $decryptedData[$armorIndex+1]) = &write16($armor);
              $needsFixing = 1;
              if ($fixFiles > 1) {
                $err .= '  Fixed!!! SuperLatanium set to 21. New armor value: ' . $armor;
              } else {$err .= '';}
              $warning{$warnId.'-dock'} = $err;
              #print "$warnId: $err\n";
            }
            # if we have a starbase with totally empty slots, we definitely don't have a Cheap Starbase
            if ($isStarbase && $itemSum == 0) { 
              $brokenStarbase[$designNumber] = -1; 
              if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
                delete ($warning{$warnId.'-cheap'}); 
              }
            }
          } else { # If it's not a full design
            $mass = &read16(\@decryptedData, 4); 
            $slotEnd = 6; 
            $shipNameLength = $decryptedData[$slotEnd]; 
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          }
          #print "shipName: $shipName\n";
          
          # Detect the 10th starbase design
          if ( $isStarbase && $designNumber == 9 && $deleteDesign && $Player > 0 ) {
            $err = 'WARNING: Player ' . &plusone($Player) . ": Starbase ($shipName) in design slot 10 - Potential Crash if Player 1 Fleet 1 refuels when Last Player has a 10th starbase design.";
            # As I have no fix, no need to flag for fixing
            #print "$warnId: $err\n"; 
            $warning{$warnId.'-ten'} = $err;
          } 
          # Detect the Cheap Starbase exploit    
          # Editing a starbase under construction at planet(s) with no starbase
          # Only need to check starbase orders
          # If the design is deleted we also stop checking 
          if ($typeId == 27 && $isStarbase && $totalBuilt == 0 && !($brokenStarbase[$designNumber]  < 0) ){ # .x and Starbase
            my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
            my $queueCounter;
            foreach my $queueCounter (sort keys %queueList) {
              if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber) { # if the item in the queue is a ship design (4)
                $err = 'WARNING: Cheap Starbase Exploit for Player ' . &plusone($Player) . '. Do not edit a starbase under construction (slot ' . &plusone($designNumber) . ", $shipName).";
                $brokenStarbase[$designNumber] = 1; 
                $index = 19;  
                # Loop through each slot, setting the slot to 0
                for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
                  ($decryptedData[$index], $decryptedData[$index+1]) = &write16(0);
                  $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
                  $index += 2;
                  $decryptedData[$index] = 0;
                  $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
                  $index++;
                  $decryptedData[$index] = 0;
                  $itemCount = $decryptedData[$index];
                  #my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
                  #if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index \n"; }
                  #else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index \n";}
                  $index++;
                }
                $needsFixing = 1;
                if ($fixFiles > 1) {
                  $err .= "  Fixed!!! Starbase design for $shipname reset to blank.";
                } else {$err .= ' '; }
                $warning{$warnId.'-cheap'} = $err;
                #print "$warnId: $err\n";
              }
            }
          }
        } 
        # For the Colonizer bug & Spacedock overflow, track whether the design was 
        # created, but remove the warning if the design was subsequently changed (inc. deleted)
        # (because a later .x file entry modified this designnumber)
        # Store the error in a hash so it's only one / ship / file
        # Will handle for multi-turn .m files.
        if (!$err && $warning{$warnId.'-dock'}) { 
          delete( $warning{$warnId.'-dock'} ); 
        }
        if (!$err && $warning{$warnId.'-colonizer'}) { 
          delete( $warning{$warnId.'-colonizer'} ); 
        }
        # If the 10th starbase has been deleted, clear the warning
        if ( $isStarbase && $designNumber == 9 && $deleteDesign == 0 && $Player > 0 ){
          if ($warning{$warnId.'-ten'}) { 
            delete ($warning{$warnId.'-ten'}); 
          }
        }
        # If the edited Cheap Starbase design is deleted, 
        # delete the queue entries as we no longer care for future checks on this design.
        my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
        if ( ($isStarbase && $deleteDesign == 0) ) {
          # Determine which starbase
          foreach my $queueCounter (sort keys %queueList) {
            if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber ) { # if the item in the queue is a ship design (4)
              if (exists ($queueList{$queueCounter})) { 
                delete $queueList{$queueCounter}; 
              }
            }
          }
          if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
            delete ($warning{$warnId.'-cheap'}); 
          }
        }
        # If the queue was cleared for planet, future queue no longer a problem
        foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
          if ( $queueList{$queueCounter}{queueSize} == 2 ) {
            if (exists ($queueList{$queueCounter})) { 
              delete $queueList{$queueCounter}; 
            }
          }
        }
        # Now that the queues are cleared up, see if we still have a Cheap Starbase problem
        my $stillBroken = 0;   
        foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
          if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber && $queueList{$queueCounter}{completePercent} > 0) { # if the item in the queue is a ship design (4)
             $stillBroken = 1;
          }
        }
        if ($stillBroken) {
          $brokenStarbase[$designNumber] = 1;
        } else {
          #if ($brokenStarbase[$designNumber] == 1) { 
          #  print "Cheap Starbase Player Fix Noted\n"; 
          #}
          $brokenStarbase[$designNumber] = -1;
          if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
            delete ($warning{$warnId.'-cheap'}); 
          }
        }
      } elsif ($typeId == 30) {  # BattlePlan block
        my ($planPlayerId, $planNumber, $primaryTarget,$secondaryTarget,$tactic,$attackWho, $dumpCargo, $planNameLength, $planName);
        my @target = qw(None Any Starbase Armed Bombers Unarmed Fuel Freighters);
        my @tactic = qw(Disengage ifChallenged minToSelf maxNet maxRatio Max);
        my @attackWho = qw(Nobody Enemies Neutral/Enemies Everyone 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16);
        my $err = '';
        # Player 0 Default: 0 4 19 2 5 179 45 113 222 90
        $planPlayerId = ($decryptedData[0] >> 0) & 0x0F; 
        $planNumber = ($decryptedData[0] >> 4) & 0x0F; 
        $tactic = ($decryptedData[1]) & 0x0F; 
        $dumpCargo = ($decryptedData[1] >> 7) & 0x01; 
        $primaryTarget = ($decryptedData[2] >> 0) & 0x0F; 
        $secondaryTarget = ($decryptedData[2] >> 4) & 0x0F; 
        $attackWho = $decryptedData[3]; 
        $planNameLength = $decryptedData[4]; 
        #print "planNameLength: $planNameLength  (using nibbles as characters, not bytes)\n";
        $planName = &decodeBytesForStarsString(@decryptedData[4..4+$planNameLength]);  
        #print "$planPlayerId,$primaryTarget,$secondaryTarget,$tactic,$attackWho,$dumpCargo\n";
        # Detect the BattlePlan Friendly Fire bug
        $warnId = &zerofy($planPlayerId) . '-plan-' . &zerofy($planNumber);
        if (($attackWho) > 3 && $planNumber == 0) { 
           # Fixing display for those who don't count from 0.
           $err .= 'WARNING: Friendly Fire bug detected for Player ' . &plusone($planPlayerId) .  " in Default battle plan against " . &attackWho($attackWho) . '.';
           $decryptedData[3] = 2;
           $needsFixing = 1;
           if ($fixFiles > 1) {
             $err .= ' Fixed!!! Attack Who reset to Neutral/Enemy.';
           } else {$err .= '';}
           #print "$warnId: $err\n"; 
           $warning{$warnId.'-friendly'} = $err;
        }
        # If a subsequent Default battle plan fixes it, clear the warning
        if (!$err && $warning{$warnId.'-friendly'}) { 
          delete( $warning{$warnId.'-friendly'} ); 
        }
      }
      # END OF MAGIC
      # reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, $needsFixing, \%warning;
}

# sub Check_FileName {
# 	# BUG:  Check_FileName Feature not implemented
# 	my ($file_file) = @_; 
# 	&LogOut(0,"Check_FileName for $file_file not implemented",$LogFile);
# 	# Check against the database that this is a valid Game Name
# 	return 1; 
# }
