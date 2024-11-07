#!/usr/bin/perl
# download.pl
# Download files for TotalHost
# Rick Steeves th@corwyn.net
# 120808

##################################################################
# File Filter    Version 1.0                                     #
# Created 04/15/2010 by Rick Steeves    Last Modified 01/22/10   #
# Used to provide file access while authenticating users         #
# used notes from 															                 #
# http://bytes.com/topic/perl/insights/857373-how-make-file-download-script-perl
##################################################################

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

use CGI qw(:standard);
use CGI::Session qw/-ip-match/;
CGI::Session->name('TotalHost');
use DBI;
use File::Find; # Used for zip/compression
use Archive::Zip; # Used for zip/compression
do 'config.pl';
use TotalHost; 
use StarsBlock; 

$CGI::POST_MAX=1024 * 50;  # max 50K posts
$CGI::DISABLE_UPLOADS = 1;
my $cgi = new CGI;
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
&validate($cgi, $session);

$userlogin = $session->param("userlogin");
$id = $session->param("userid");

# Error checking
(my $domain = $WWW_HomePage) =~ s|^https?://||; # Strip off http or https
if (my $error = $cgi->cgi_error()){  # Is the file too big
	if ($error =~ /^413\b/o) { &error('Maximum data limit exceeded.'); } 
	else { &error('An unknown error has occured.');  }
# Did the request come from this website either http or https
#} elsif  ($ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ m|^\Q$WWW_HomePage|io) { &error('Remote access forbidden.') }
} elsif  ($ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ m|^https?://\Q$domain\E|i) { &error("Remote access forbidden. $ENV{'HTTP_REFERER'}"); }

my %in = $cgi->Vars;
#Now we make sure there is a parameter named "file".
my $file = $in{'file'} or &error('No file selected.');

#Sanitize file name request
if ($file =~ /^(\w+[\w.-]+\.\w+)$/) { $file = $1; }
else { &error('Invalid characters in filename.'); } 


# Extra Sanitize the results to try to prevent someome from wandering aimlessly about
$file =~ s/\\//g;
$file =~ s/\///g;
$file =~ s/://g;
$file =~ s/\"//g;
$file =~ s/\'//g;
$file =~ s/ //g;
my $turn_id = $file;
$turn_id =~ s/(^\w+[\w.-]+\.[mM])(\d{1,2})/$2/;
# Get the name of the game file (file name with no extensions)
my $gamefile = $file; 
$gamefile =~ s/(^\w+[\w.-]+)(\..*)/$1/;
my $download_ok = 0;
my $filetype = '';
my $sql; 

# Check for the right kind of file, .xy or .x[1..99]
# If it's an .xy file, let any user download
if ($file =~ /^(\w+[\w.-]+\.xy)$/) { 
  $download_ok = 1; 
  $filetype='xy';  
  $outputfile = "$Dir_Games/$gamefile/$file"; 
# if it's a .m[n] file, validate who wants it before they get it
} elsif ($file =~ /^(\w+[\w.-]+\.[mM]\d{1,2})$/) { 
	$filetype='m';
	# need to check the database to see whether the logged in user gets access
	# does the game file, player ID, and user ID exist (aka permitted)? 
	# Can only download turn if you have an active user_status > 0
  #$sql = qq|SELECT Games.GameFile, User.User_ID, GameUsers.PlayerID, GameUsers.PlayerStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$gamefile\') AND ((User.User_Login)=\'$userlogin\') AND ((GameUsers.PlayerID)=$turn_id) AND (User.User_Status > 0));|;
  $sql = qq|SELECT Games.GameFile, User.User_ID, GameUsers.PlayerID, GameUsers.PlayerStatus FROM User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login INNER JOIN Games ON Games.GameFile = GameUsers.GameFile WHERE Games.GameFile = \'$gamefile\' AND User.User_Login = \'$userlogin\' AND GameUsers.PlayerID = $turn_id AND User.User_Status > 0;|;
	$db = &DB_Open($dsn);
	my %GameValues;
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); 
    %GameValues = %{$row};
#		while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
    $sth->finish();
    $outputfile = $Dir_Games . '/' . $GameValues{'GameFile'} . '/' . $file;
	}
	else { &error("download: ERROR: Finding user $userlogin to download file $file"); }
  # If the player was found, and not banned from the game (which could get them 
  # access if they hacked the URL
	if ($GameValues{'GameFile'} && $GameValues{'PlayerStatus'} ne '3') { $download_ok = 1; }
	else {
	#see if they are in the game, and the game permits anyone in the game to download
		$sql = qq|SELECT Games.GameFile, Games.SharedM, User.User_ID FROM User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$gamefile\') AND ((User.User_Login)=\'$userlogin\') AND ((Games.SharedM)=Yes));|;
		if (my $sth = &DB_Call($db,$sql)) { 
      my $row = $sth->fetchrow_hashref();
      %GameValues = %{$row};
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
      $sth->finish();
		} 
		else { &error('ERROR: Finding user $userlogin to download shared m file'); }
		if ($GameValues{'GameFile'}) { $download_ok = 1; }
	}
  # Check to permit the host who is not playing to download
  unless ($download_ok == 1) { # Don't need to check if they already can download
		# Determine if the player is in the game
    $sql = qq|SELECT Games.GameFile, Games.HostName, User.User_Login, Games.HostAccess FROM User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$gamefile\') AND ((Games.HostName)=\'$userlogin\'));|;  
		my $playeringame = 0; 
		if (my $sth = &DB_Call($db,$sql)) { 
      my $row = $sth->fetchrow_hashref(); 
      %GameValues = %{$row};
      if ($GameValues{'HostName'} eq $GameValues{'User_Login'} ) { $playeringame = 1; }
      $sth->finish();
		} 
    if ($GameValues{'HostName'} eq $userlogin && !$playeringame && $GameValues{'HostAccess'}) { $download_ok = 1; }
    $outputfile = "$Dir_Games/$gamefile/$file";
  }
	&DB_Close($db);

# If it's a .r[n] file, validate who wants it before they get it
#} elsif (($file =~ /^(\w+[\w.-]+\.R\d{1,2})$/) || ($file =~ /^(\w+[\w.-]+\.r\d{1,2})$/)) { 
} elsif (($file =~ /^(\w+[\w.-]+\.[Rr]\d{1,2})$/) ) { 
	$filetype = 'r';
	$db = &DB_Open($dsn);
	$sql = qq|SELECT * FROM Races WHERE User_Login='$userlogin' AND RaceFile='$file';|;
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref();
    %RaceValues = %{$row};
    $sth->finish();
	}
	if ($RaceValues{'RaceFile'}) { $download_ok = 1; }
	&DB_Close($db);
  $outputfile = $Dir_Races . "/" . $RaceValues{'User_File'} . "/$file";
# Permit the user to zip up and download their entire game
} elsif ($file =~ /^(\w+[\w.-]+\.zip)$/) { 
	$filetype='zip'; 
	@gamelocation = ($Dir_Games . '/' . $gamefile);
  	# Determine the user's player ID, which is not the same as their user ID
	$sql = qq|SELECT PlayerID, GameFile FROM User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login WHERE (((GameUsers.GameFile)='$gamefile') AND ((User.User_Login)='$userlogin'));|;
	$db = &DB_Open($dsn);
	my %GameValues;
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) { 
     %GameValues = %{$row}; 
     #		while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
  	 $id = $GameValues{'PlayerID'};
  	 $GameFile = $GameValues{'GameFile'};
  	 # Build an array of all of the .m[n], .x[n], and .xy files
  	 # in the game directory determines by $gamefile
  	 find sub { 
        # Grab the files specific to that player, matching only the backup folders
  		  if (($File::Find::name =~ /$GameFile\/\d{4}\/$GameFile\.m$id/i) || ($File::Find::name =~ /$GameFile\/\d{4}\/$GameFile\.x$id/i) || ($File::Find::name =~ /$GameFile\/\d{4}\/$GameFile\.xy/i)) {
  			 # Store those files in an array for later use
  			 push (@list_of_files_to_backup, $File::Find::name); 
    		}
  	 }, @gamelocation;
   }
   $sth->finish();
  } else { &error("ZIP: Failed to find Game: $gamefile associated with User: $userlogin"); }
	&DB_Close($db);

 	#  create a new zip object
 	$obj = Archive::Zip->new();   # new instance
 	#Put each file in the array into the zip file
 	foreach my $file (@list_of_files_to_backup) {
    # Generate a relative path by stripping off the base directory
    my $relative_path = $file;
    # Adjust path to be relative (change this to fit your directory structure)
    $directory_to_backup =  $Dir_Games . '/' . $GameFile; 
    $relative_path =~ s{^$directory_to_backup/}{};
    # Convert forward slashes to backslashes for Windows
    $relative_path =~ s/\//\\/g;
		# Add the file to the files to be zipped array
 		$obj->addFile($file, $relative_path) or &error("Error adding file $file,  $filename, $relative_path");   # add files
 	}
 	$downloadfile = "$GameFile.zip";
 	$outputfile = $Dir_Download . '/' . $downloadfile; 
 	if ($obj->writeToFileNamed("$outputfile") != AZ_OK) {  # write to disk
 	    &error("$userlogin: Error in archive creation for $outputfile!"); $download_ok = 0;
 	} else {	
    $download_ok = 1; 
    umask 0002; 
    chmod 0664, $outputfile;
  }
    
# Message file download
} elsif ($file =~ /^(\w+[\w.-]+\.msg)$/) { 
	$filetype='msg'; 
	$gamelocation = $Dir_Games . '/' . $gamefile; # Get the location for the current turns
 
	# Determine the user's player ID, which is not the same as their user ID
	#$sql =qq|SELECT PlayerID, GameFile FROM User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login WHERE (((GameUsers.GameFile)='$gamefile') AND ((User.User_Login)='$userlogin'));|;
  # updated to include host access (if host access is enabled, give all messages)
  # 240923
  $sql = qq|SELECT GameUsers.PlayerID, GameUsers.GameFile, Games.HostAccess FROM Games INNER JOIN (User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login) ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((GameUsers.GameFile)='$gamefile') AND ((User.User_Login)='$userlogin' ) OR ((GameUsers.GameFile='$gamefile') AND (Games.HostName)='$userlogin') AND ((Games.HostAccess)=True));|;  
  #$sql = qq|SELECT GameUsers.PlayerID, GameUsers.GameFile, Games.HostAccess FROM Games INNER JOIN (User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login) ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((GameUsers.GameFile)='$gamefile') AND ((User.User_Login)='$userlogin' AND (User.User_Login > 0)) OR ((GameUsers.GameFile='$gamefile') AND (Games.HostName)='$userlogin') AND ((Games.HostAccess)=True));|;  
	$db = &DB_Open($dsn);
	my %GameValues;
  # read in the player values
  my @messageFiles;
  my $messageFile;
  my $hostAccess;
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) { 
      %GameValues = %{$row}; 
      $id = $GameValues{'PlayerID'};
      $GameFile = $GameValues{'GameFile'};
      $hostAccess = $GameValues{'HostAccess'}; # Is Host Access set (0|1)
      push @messageFiles, $GameFile . '.m' . $id; # Check for .m file
      push @messageFiles,  $GameFile . '.x' . $id; # Check for .x file
      # remove any previous out-of-date message file
      $messageFile =  $gamelocation . '/' . $GameFile  . '.msg';
      if (-f $messageFile && $hostAccess) { unlink $messageFile; }
      unless ($hostAccess) { 
        #$unlinkFile .=  $messageFile . $id;
        $unlinkFile .=  $messageFile;
        if (-f  $unlinkFile) { unlink  $unlinkFile; } 
      }
    }
    $sth->finish();
  } else { &error("Download: Failed to find Game $gamefile associated with this User $userlogin"); }
	&DB_Close($db);
  # read in messages from the player files  
  foreach my $filename (@messageFiles) {
    $fullFileName = $gamelocation . '/' . $filename;
    # Read in the file data
    my @fileBytes;
    if (-f $fullFileName) {  # read in the file if it exists
      open(StarFile, "<$fullFileName" );
      binmode(StarFile);
      while ( read(StarFile, $FileValues, 1)) {
        push @fileBytes, $FileValues; 
      }
      close(StarFile);

      my ($outBytes) = &decryptMessages(@fileBytes);  # get the message data
      my @outBytes = @{ $outBytes };
      open (MESSAGEFILE, ">>$messageFile"); # write out the messages to a file
      unless (scalar (@outBytes)) { print MESSAGEFILE $filename . ',' . "No message(s) found.\n"; }
      else {
        foreach my $message (@outBytes) {
          print MESSAGEFILE $filename . ','; # include the file name
          # Output the message to a file
          print MESSAGEFILE $message;
        }
      }
      close MESSAGEFILE;
      umask 0002; 
      chmod 0664, $messageFile;
    }
  }
  # Change the default name of the file to be player-specific
  $file = $messageFile;
	$outputfile = $GameFile . '.msg';
  unless ($hostAccess) { $outputfile .= $id; }
  $download_ok = 1;
  ######################################################
  ######################################################  
  
  # If the file type wasn't one of the predefined ones, error out.
  } else { &error("User $userlogin authorized. Invalid file type $file $filetype"); }
  
  if ($download_ok) { &download($file,$outputfile) or &error("User $userlogin authorized, but an unknown error has occured.");  }
  else { &error("User $userlogin Unauthorized.") 
}

##########################################
sub download {
  my ($file, $outputfile) = @_;
  #my $file = $_[0] or return(0);
	# For a race file, download from the race file location
	if ($filetype eq 'r' || $filetype eq 'm' || $filetype eq 'xy') {
   	open(DLFILE, '<', "$outputfile") or return(0);
	  # this prints the download headers with the file size included
	  # so you get a progress bar in the dialog box that displays during file downloads. 
	  print $cgi->header(-type            => 'application/x-download',
	                    -attachment      => $file,
	                    -Content_length  => -s "$outputfile",
		);
	# download the zipped up game from the zip location.
	} elsif ($filetype eq 'zip') {
   	open(DLFILE, '<:raw', "$outputfile") or return(0);
	  # this prints the download headers with the file size included
	  # so you get a progress bar in the dialog box that displays during file downloads. 
	  print $cgi->header(-type            => 'application/zip',
	                    -attachment      => $file,
	                    -Content_length  => -s "$outputfile",
		);
	# download the message file.
	} elsif ($filetype eq 'msg') {       
   	open(DLFILE, '<', "$file") or return(0); 
	  # this prints the download headers with the file size included
	  # so you get a progress bar in the dialog box that displays during file downloads. 
	  print $cgi->header(-type            => 'text/html',
#                        -charset        => 'utf-8',
#                       -attachment      => "$downloadmsgfile",
# 	                    -Content_length  => -s "$file",
		);
	} 
  binmode DLFILE;
  print while <DLFILE>;
  close (DLFILE);
  # Delete the .zip file if that's what we're doing as it's temporary anyway.
  if ($filetype eq 'zip' && -f $outputfile) { unlink $outputfile; }
  return(1);
}

sub error {
   print $cgi->header(-type=>'text/html'),
         $cgi->start_html(-title=>'Error'),
         $cgi->h3("Error: $_[0]"),
         $cgi->end_html;
   log_error($_[0]) if ($logging > 50);
   exit(0);
}

sub log_error {
   my $error = $_[0];
   # Hacking into place using errorlog instead of a local function
   my $params = join(':::', map{"$_=$in{$_}"} keys %in) || 'no params';
   $error = join('","',time, 
                      scalar localtime(),
                      $ENV{'REMOTE_ADDR'},
                      $ENV{'SERVER_NAME'},
                      $ENV{'HTTP_HOST'},
                      $ENV{'HTTP_REFERER'},
                      $ENV{'HTTP_USER_AGENT'},
                      $ENV{'SCRIPT_NAME'},
                      $ENV{'REQUEST_METHOD'},
                      $params,
                      $error);
  my $logentry = $params . "::" . $error;
  &LogOut(0, "download: $error", $ErrorLog);
}
