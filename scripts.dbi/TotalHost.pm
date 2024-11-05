#!/usr/bin/perl
# Formerly a RallyPt File
# TotalHost.pm
# Core Library for TotalHost
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


package TotalHost;
our $VERSION = '1.00';  # Use a floating-point string for version numbers
use Net::SMTP; # requires libcrypto-1_1_.dll
use CGI qw(:standard);
use CGI::Session qw/-ip-match/;
use DBI;
use DateTime;
use DateTime::TimeZone;
do 'config.pl';
use StarStat; # eval'd at compile time
use StarsBlock; # eval'd at compile time

CGI::Session->name('TotalHost');

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( 
	print_header
	DB_Open DB_Close DB_Call 
	Mail_Open Mail_Close Mail_Send MailAttach
	Email_Turns Load_EmailAddresses
	GetTime CheckTime GetTimeString LogOut
	validate
	show_html show_notes
	html_top html_head html_banner
	html_left html_right html_bottom
	html_meta html_title html_menu html_footer
	clean_old_sessions get_cookie print_cookie print_redirect 
	checkbox checknull checkboxnull checkboxes fixdate
	SubmitTime
	UpdateLastTurn UpdateNextTurn FixNextTurnDST GenerateTurn clean_name
	rp_list_games list_games LoadGamesInProgress
	Make_CHK Read_CHK Eval_CHK Eval_CHKLine
	Game_Backup File_Date
	clean 
	DaysToAdd ValidTurnTime ValidFreq CheckHolidays LoadHolidays ShowHolidays
  show_race_block
  process_fix process_game_status
  lwp_head check_internet get_internet_down_count internet_log_status clear_internet_log
  call_system  get_user
);
# Remarked out functions: FileData FixTime MakeGameStatus checkboxes checkboxnull
#  showCategory
# clean_filename

# Print header information
sub print_header {
# @_ is the special PERL statement for command line argument items	
#	if (!defined(@_)) { print "Content-type: text/html\n\n"; }
	if (!(@_)) { print "Content-type: text/html\n\n"; }
	else {	print "Location: @_\n\n"; }
}

sub DB_Open {
  my ($dsn) = @_;
  my $dbh = DBI->connect($dsn, $DB_USER, $DB_PASSWORD, {
      RaiseError => 0, # handle errors manually
      PrintError => 0, # don't automatically print errors
      AutoCommit => 1, # auto-commit enabled by default
  });

  if (!$dbh) {
      my $error = "Database: Error connecting to $dsn: " . DBI->errstr;
      &LogOut(0, $error, $ErrorLog);
      return undef;
  } else {
      return $dbh;
  }
}

sub DB_Close {
  my ($dbh) = @_;
  #  my ($dbh, $sth) = @_;
  #if (defined $sth) { $sth->finish(); }
  $dbh->disconnect();
}

# sub DB_Check {
#     my ($sqlin, $db) = @_;
# 
#     if ($db->err) {
#         my $error = "Database: Error in $sqlin: " . $db->err . " * " . $db->errstr . "\n";
#         &LogOut(0, $error, $ErrorLog);
#         return 0;
#     } else {
#         return 1;
#     }
# }

sub DB_Call {
  my ($dbh, $sql) = @_;
  &LogOut(200, $sql, $SQLLog);

  my $sth = $dbh->prepare($sql);
  if (!$sth) {
      &LogOut(0, "Database: Failed to prepare statement: " . $dbh->errstr, $ErrorLog);
      return undef;
  }

  if ($sth->execute()) {
      return $sth;
  } else {
      &LogOut(0, "Database: Failed to execute statement: " . $dbh->errstr, $ErrorLog);
      return undef;
  }
}

sub Mail_Send { # Sends mail to the listed user, with the associated values (to:, Subject, Message)
	my ($smtp, $MailTo, $MailFrom, $Subject, $Message) = @_;
	&LogOut(10,"sending mail: $MailTo, $MailFrom, $Subject, $Message", $LogFile);
	if ($mail_present) {
		$smtp->mail( "$MailFrom" ); 
  	$smtp->to( "$MailTo" ); 
    #$smtp->recipient($recipi);    
  	#Prepare for sending data
		$smtp->data();
		# Set headers
		$smtp->datasend("To: $MailTo\n");
		$smtp->datasend("From: $MailFrom\n");
		$smtp->datasend("Subject: $Subject\n");
		$smtp->datasend("\n");
		#Send message
		$smtp->datasend("$Message\n");
		$smtp->datasend("Service process - Do not reply to this message.\n");
		$smtp->datasend("\n");
		# End message
		$smtp->dataend();  # Bug the last person's email will have a . in it. 
	} else {
    &LogOut(0,"Mail not present: Would send mail: $smtp, $MailTo, $MailFrom, $Subject, $Message", $ErrorLog);
  }
}

sub Mail_Open {
	if ($mail_present) {
		$smtp = Net::SMTP->new($mail_server, Timeout => 60);
		if (!($smtp)) { 
			&LogOut(0, "Mail_Open: ERROR: Failed to Connect to SMTP for $mail_server", $ErrorLog); 
		} else {
			&LogOut(201, "Mail_Open: SMTP $mail_server open", $LogFile); 
		}
		return $smtp;
	}
}

sub Mail_Close  {
	($smtp) = @_;
	if ($mail_present) {
		#$smtp->quit;	
		&LogOut(201, "Mail_Close: Closing mail", $LogFile); 
	}
}

sub MailAttach { 
# Sends mail to the listed user, with the associated values (to:, Subject, Message)
	my ($MailTo, $MailFrom, $Subject, $Message, $GameFile, $PlayerID, $Turn) = @_;
  my $Path;
	&LogOut(200,"MailAttach: $MailTo, $MailFrom, $GameFile, $PlayerID, $Turn",$LogFile);
	use MIME::Lite;
	### Create the multipart container
	my $msg = MIME::Lite->new (
	  From => $MailFrom,
	  To => $MailTo,
	  Subject => $Subject,
	  Type =>'multipart/mixed'
	) or &LogOut(0,"MailAttach: Error creating multipart container: $!",$ErrorLog);
	
  $Message .= "Service process - Do not reply to this message. \n";
	### Add the text message part
	$msg->attach (
	  Type => 'TEXT',
	  Data => $Message
	) or &LogOut(0,"MailAttach: Error adding the text message part: $!",$ErrorLog);
		
	### Add the .m file
  $Path = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.m' . $PlayerID;
	$msg->attach (
	   Type => 'binary',
	   Path => $Path,
	   Disposition => 'attachment'
	) or &LogOut(0,"MailAttach: Error adding $attachment: $!",$ErrorLog);

	### Add the .xy file for the first turn
  if ($Turn eq '2400') { 
    $Path = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.xy';
  	$msg->attach (
  	   Type => 'binary',
  	   Path => $Path,
  	   Disposition => 'attachment'
  	) or &LogOut(0,"MailAttach: Error adding $attachment: $!",$ErrorLog);
	}
	### Send the Message
	MIME::Lite->send('smtp', $mail_server, Timeout=>60);
	$msg->send;
}

sub Email_Turns { #email turns out to the appropropriate players
	my ($GameFile, $GameVs, $Attach) = @_;
	my %GameVals = %$GameVs;
	my $Message;
#	while ( my ($key, $value) = each(%GameVals) ) { print "<P>$key => $value\n"; }
	# If you're emailing attachments, only do so to people who have requested it
	# Otherwise mail the active people. 
	my $sql = qq|SELECT Games.GameFile, GameUsers.User_Login, User.User_Email, GameUsers.PlayerID, User.EmailTurn, GameUsers.PlayerStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerStatus)=1)) ORDER BY GameUsers.PlayerID;|;
	my ($User_Login, $Email, $PlayerID, $EmailTurn) = &Load_EmailAddresses($GameFile, $sql);
	my @User_Login = @$User_Login;
	my @Email      = @$Email; 
	my @PlayerID   = @$PlayerID;
	my @EmailTurn  = @$EmailTurn;
  my $user_count =  @User_Login;
	&LogOut(201, "Email_Turns: User Count $user_count for $GameFile", $LogFile); 
  # User count is number of players, but the values are in an array
  # So we need to adjust user count to make the range 0 to end of array
	for (my $i = 0; $i <= ($user_count-1); $i++) {
		&LogOut(201, "Email_Turns: Starting Loop to email $Email[$i] for $GameFile", $LogFile); 
		$Message = '';
		# This subject line is here because it has the player information that 
		# isn't available until you get to here. 
 		if ($GameVals{'Subject'}) { $Subject = $GameVals{'Subject'}; 
    } elsif ( $PlayerID == 0 ) { # If this is a host message
      $Subject = qq|$mail_prefix New Turns for $GameFile - Year $GameVals{'HST_Turn'}|;
 		} else { $Subject = qq|$mail_prefix New Turn for $GameFile.m$PlayerID[$i] - Year $GameVals{'HST_Turn'}|; }
		&LogOut(200, "Email_Turns: Subject: $Subject", $LogFile);
		$Message = $GameVals{'Message'} . "\n\n";
    # If there's a next turn scheduled, and the game isn't over
		if ($GameVals{'NextTurn'} > 0 && $GameVals{'GameStatus'} != 9 && $GameVals{'GameStatus'} != 4 && $GameVals{'GameType'} != 3 && $GameVals{'GameType'} != 4 ) {
			$Message .= "Next scheduled turn generation on or after " . localtime($GameVals{'NextTurn'});
			$Message .= ".\n\n";
		}
#    if (&checkbox($GameVals{'AsAvailable'}) == 1 ) { $Message .= "Turns will generate when all turns are in.\n\n"; }

		if ($GameVals{'ForceGen'} == 1  && $GameVals{'GameStatus'} != 4 ) { 
			$Message .= qq|Automated generation will force $GameVals{'ForceGenTurns'} years at a time for the next $GameVals{'ForceGenTimes'} turns|;
			if ($GameVals{'HST_Turn'} eq '2400' || $GameVals{'HST_Turn'} eq '2401' ) { $Message .= ' not including years 2400 and 2401, which will generate only one year'; }
			$Message .= ".\n";
		}
		&LogOut(200, "Email_Turns: Message: $Message", $LogFile);
		if ($Attach && $EmailTurn[$i] == 1) { # If player has email and attach enabled
			&LogOut(200,"Email_Turns: Emailing player w attach: T: $Email[$i], F: $mail_from, G: $GameVals{'GameFile'}, P: $PlayerID[$i], T: $GameVals{'HST_Turn'}",$LogFile);
			&MailAttach($Email[$i], $mail_from, $Subject, $Message, $GameFile, $PlayerID[$i], $GameVals{'HST_Turn'});
		} elsif ( $PlayerID == 0 ) { # If this is email to the host
     	&LogOut(200,"Email_Turns: Emailing host: T: $Email[$i], F: $mail_from, G: $GameVals{'GameFile'}, P: $PlayerID[$i], T: $GameVals{'HST_Turn'}",$LogFile);
			&Mail_Send($smtp, $Email[$i], $mail_from, $Subject, $Message);
			&Mail_Close($smtp);
		} else {
			$smtp = &Mail_Open;
			&LogOut(200,"Email_Turns: Emailing player: $Email[$i], $mail_from, $Subject, $Message",$LogFile);
			&Mail_Send($smtp, $Email[$i], $mail_from, $Subject, $Message);
			&Mail_Close($smtp);
		}
	}
}

sub Load_EmailAddresses {
	my ($GameFile, $sql) = @_;
	my @User_Login, @Email, @PlayerID;
  my %Host;
	&LogOut(300,"Load_EmailAddresses: Email game name: $GameFile",$LogFile);   
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
		my $MailCounter = 0; # Game counter
    while (my $row = $sth->fetchrow_hashref()) {
      (@User_Login[$MailCounter], @Email[$MailCounter], @PlayerID[$MailCounter], @EmailTurn[$MailCounter]) =  ($row->{'User_Login'}, $row->{'User_Email'}, $row->{'PlayerID'}, $row->{'EmailTurn'});
			&LogOut(100,"      Load_EmailAddresses: Will mail for $GameFile to User Name: $User_Login[$MailCounter] PlayerID: $PlayerID[$MailCounter] Email: $Email[$MailCounter]",$LogFile);
			$MailCounter++;
		}
    $sth->finish();
	}
  $sql = qq|SELECT Games.GameName, Games.HostName, User.User_Email, User.EmailTurn FROM User INNER JOIN Games ON User.User_Login = Games.HostName WHERE Games.GameFile = \'$GameFile\';|;
  if ( my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %Host = %{$row}; 
    $sth->finish();
  }	

  #BUG: A player in the game more than once will be in the list more than once. 
  # Only add the host if they're not in the game
  if (!grep { $_ eq $Host{'HostName'} } @User_Login) {
    push @User_Login, $Host{'HostName'};
    push @Email, $Host{'User_Email'};
    push @PlayerID, 0;  # The host doesnt have a player ID
    push @EmailTurn, $Host{'EmailTurn'}; # Use Host turn value to whether they get emailed
  }
	&DB_Close($db);
	return \@User_Login, \@Email, \@PlayerID, \@EmailTurn;
}

sub GetTime {
	# Figure out all time values for this iteration. Global Values
	$CurrentEpoch = time();
	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($CurrentEpoch); 
	$Month = $WrongMonth + 1; 
	$Year = $WrongYear + 1900;
	$SecOfDay = ($Minute * 60) + ($Hour*60*60) + $Second;
	$CurrentDateSecs = $CurrentEpoch - $SecOfDay;
#	$Interval = 24 * 60 * 60;
	if ($DayofMonth <=7) { $WeekofMonth = 1;}
	elsif ($DayofMonth >7 && $DayofMonth <=14) { $WeekofMonth = 2;}
	elsif ($DayofMonth >14 && $DayofMonth <=21) { $WeekofMonth = 3;}
	elsif ($DayofMonth >22 && $DayofMonth <=28) { $WeekofMonth = 4;}
	elsif ($DayofMonth >28 && $DayofMonth <=31) { $WeekofMonth = 5;}
  
  return  ($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs);
}

# Returns CSecofDay along with everything else
sub CheckTime { #Determine information for a specified time in seconds of a day
	my($TimetoCheck) = @_;  # Pass in Epoch Time
	($CSecond, $CMinute, $CHour, $CDayofMonth, $CWrongMonth, $CWrongYear, $CWeekDay, $CDayofYear, $CIsDST) = localtime($TimetoCheck); 
	$CMonth = $CWrongMonth + 1; 
	$CYear = $CWrongYear + 1900;
	$CSecOfDay = ($CMinute * 60) + ($CHour*60*60) + $CSecond;
	return ($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay);
}

sub GetTimeString {
	# Figure out all time values for this iteration and return formatted string
	my $CurrentEpoch = time();
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($CurrentEpoch); 
	my $Month = $WrongMonth + 1; 
	my $Year = $WrongYear + 1900;
	my $SecOfDay = ($Minute * 60) + ($Hour*60*60) + $Second;
	$CurrentDateSecs = $CurrentEpoch - $SecOfDay;
#	$Interval = 24 * 60 * 60;
	if ($DayofMonth <=7) { $WeekofMonth = 1;}
	elsif ($DayofMonth >7 && $DayofMonth <=14) { $WeekofMonth = 2;}
	elsif ($DayofMonth >14 && $DayofMonth <=21) { $WeekofMonth = 3;}
	elsif ($DayofMonth >22 && $DayofMonth <=28) { $WeekofMonth = 4;}
	elsif ($DayofMonth >28 && $DayofMonth <=31) { $WeekofMonth = 5;}
	return sprintf "%2d/%02d/%04d %02d:%02d:%02d", $Month,$DayofMonth,$Year,$Hour,$Minute,$Second;
}

sub LogOut {
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
    if ($LogFile) {
      if (($Logging) <= 9) { $Logging = ' ' . $Logging; } # Fix for log file format
      if (($Logging) <= 99) { $Logging = ' ' . $Logging; } # Fix for log file format
  		$PrintString = localtime(time()) . ' : ' . $Logging . ' : ' . $PrintString;
      # Debug
  #my $user = &get_user();
  #$PrintString .= ": User: $user";
  		open (LOGFILE, ">>$LogFileDate");
  		print LOGFILE "$PrintString\n\n";
  		close LOGFILE;
      umask 0002; 
      chmod 0664, $LogFileDate; 
    } else { print "$PrintString\n"; }
	}


}

sub validate {
	my ($cgi, $session) = @_; # receive two args
	if ( $session->param("logged-in") ) {
    	return 1;  # if logged in, don't bother going further
	} else {
	print $cgi->header();

print <<eof;
<html>
<body>
<meta http-equiv="Refresh" content="900000;url=/">
You are not authorized to perform this function. 
</body></html>
eof
exit(0);
	}
}

sub show_html {
	# Take a HTML file and import it into the TH interface
	print '<td>';
	my ($File) = @_; 
	if (-f $File) { #Check to see if file is there.
		open (IN_FILE,$File) || &LogOut(0,"show_html: cannot open $File!", $ErrorLog); 
		my(@File) = <IN_FILE>;
		close(IN_FILE);
		foreach my $key (@File) {
			if ($key =~ /\<html\>|\<HTML\>|\<body\>|\<BODY\>|\<title\>|\<TITLE\>|\<head\>|\<HEAD\>/) { next;}
			else { print "$key\n"; }
		}
	} else { print "<P>File $File not found.\n"; &LogOut(0, "show_html: File $File not found", $ErrorLog)}
	print '</td>';
}

sub show_notes {
  # Display a list of all the files in the /Notes folder and their text.
  use File::Find;
  my @htm_files;
  my $directory = $Dir_WWWRoot . '/Notes';
	# Display all the notes
	print '<td>';
  print "<h2>List of TH Tool Tips</h2>\n";  
  find(
      sub {
          if ( $_ =~ /\.htm$/i ) { # Check if the file ends with .htm
              push @htm_files, $File::Find::name;  # Add full path to the file
          }
      },
      $directory
  );

  # Print all .htm files
  foreach my $file (@htm_files) {
    my $filename = $file;
    $filename =~ s|.*/||;      # Remove the path
    $filename =~ s/\.[^.]+$//; # Remove the extension
    print "<P>$filename:\n";      
    open my $fh, '<', $file || &LogOut(0,"show_notes: cannot open $file!", $ErrorLog);
    while (my $line = <$fh>) {
      print $line;  # Print each line of the file
    }
    close $fh;
    print "\n";  # Add a newline after the file contents
  }
	print '</td>';
}


sub html_top {
	($cgi, $session) = @_;
	print "<html>\n";
	&html_head;
	print "<body>\n";
	&html_banner($cgi, $session);
	&html_menu;
}

sub html_head {
	print "<head>\n";
	&html_title("TotalHost");
	&html_meta;
print <<eof;
<link rel="stylesheet" type="text/css" href="/chrometheme/chromestyle.css" />
<script type="text/javascript" src="/chromejs/chrome.js">
/***********************************************
* Chrome CSS Drop Down Menu- (c) Dynamic Drive DHTML code library (www.dynamicdr
ive.com)
* This notice MUST stay intact for legal use
* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
***********************************************/
</script>

<style>
.menulines{
border:1px solid white;
}
.menulines a{
text-decoration:none;
color:black;
}
</style>

<script language="JavaScript1.2">

/*
Highlight menu effect script: By Dynamicdrive.com
For full source, Terms of service, and 100s DTHML scripts
Visit http://www.dynamicdrive.com
*/

function borderize(what,color){
what.style.borderColor=color
}

function borderize_on(e){
if (document.all)
source3=event.srcElement
else if (document.getElementById)
source3=e.target
if (source3.className=="menulines"){
borderize(source3,"black")
}
else{
while(source3.tagName!="TABLE"){
source3=document.getElementById? source3.parentNode : source3.parentElement
if (source3.className=="menulines")
borderize(source3,"black")
}
}
}

function borderize_off(e){
if (document.all)
source4=event.srcElement
else if (document.getElementById)
source4=e.target
if (source4.className=="menulines")
borderize(source4,"white")
else{
while(source4.tagName!="TABLE"){
source4=document.getElementById? source4.parentNode : source4.parentElement
if (source4.className=="menulines")
borderize(source4,"white")
}
}
}
</script>
<script type="text/javascript" src="/sha1.js"></script>
<script type="text/javascript">
     hash = hex_sha1("string");
</script>

<script>
function Help( name ) {
  // if ( name.length > 8 ) name = name.substring( 0, 8 )
  name = "$WWW_Notes" + name + ".htm"
  var ifr = document.getElementById('ifr');
  ifr.setAttribute('src', name);
}
</script>
<script type="text/javascript" src="/sha1.js"></script>
<script type="text/javascript"> hash = hex_sha1("string"); </script>
</head>
eof
}

sub html_banner {
	($cgi, $session) = @_;
	$hello = 'User: ' . $session->param("userlogin");
	$cookie = $cgi->cookie(TotalHost);
	$id = $session->param("userid");
	$login = $session->param("userlogin");
	print qq|<table width=100%>\n|;
	print qq|<tr height=50>\n<td width=20% align=left><a href="/"><img src=$WWW_Image| . qq|TotalHost.jpg alt="Total Host" border=0></a></td>\n|;
#	print qq|<td name=notes><iframe id ="ifr" src="$WWW_Notes| . qq|blank.htm" name="your_name" marginwidth=0 marginheight=0 width="400" height="25" frameborder="0" scrolling="auto"></iframe></td>|;
	print qq|<td name="notes"></td>|;

#	if ( $cookie ) { print qq|<td width=30%>ID: $id Login: $login</td>\n|;}
	if ( $cookie && $debug) { print qq|<td width=20%>Cookie: $cookie</td>\n|;}
 	if ( $session->param("logged-in") ) {
		print qq|<td width=10%>$hello</td>\n|;
 		print qq|<td align=right width=5%><a href=$WWW_Scripts/account.pl?action=logout>Log Out</a></td>\n|;
# 		print qq|<td align=right width=5%><a href=$WWW_Scripts/account.pl?action=logoutfull>Erase</a></td>\n|;
 	}
	print qq|</tr>\n</table>\n|;
}

sub html_left {
	my %menu_left = %{shift()};
# 	my(%menu_left) = %{$_[0]};   another way to do this
 	print qq|<table id="maintable" border="0" width="100%" cellspacing="10" cellpadding="0">\n|;
 	print qq|<tr id="left" valign="top">\n|;
 	print qq|<td width="$lp_width">\n|;
	print qq|<table border="0" width="$lp_width" cellspacing="0" cellpadding="0" onMouseover="borderize_on(event)" onMouseout="borderize_off(event)">\n|;
#	while( my ($menu, $url) = each %menu_left ) {
	foreach $menu (sort keys %menu_left) {
		$url = $menu_left{$menu};
		$menu =~ s/[0-9]//;
		if ($menu =~ /_/) {
			$menu =~ s/_//;
			print qq|<tr><td width="100%" bgcolor="#E6E6E6"><font face="Arial" size="3"><b>$menu</b></font></td></tr>\n|;
		} else {
			print qq|<tr><td width="100%" class="menulines"><font face="Arial" size="2"><a href="$url">$menu</a></font></td></tr>\n|;
    	}
	}
	print qq|</table>\n|;

	print qq|<P><hr>\n|;
	print qq|<iframe id = "ifr" src="$WWW_Notes| . qq|blank.htm" name="your_name" marginwidth=0 marginheight=0 width="$lp_width" height="$height_help" frameborder="0" scrolling="auto"></iframe>\n|;
	print qq|<table border=0>\n|;
	print qq|<tr>\n<td id="help" align=left>\n|;
	print qq|</td>\n</tr>\n|;
	print qq|</table>\n|;
}

sub html_right {
	my %menu_right = %{shift()};
	print qq|<td width="$rp_width">\n|;
	print qq|<table border="0" width="$rp_width" cellspacing="0" cellpadding="0">\n|;
 	print qq|<tr><td width="100%">TBD</td></tr>\n|;
	print qq|</table></td>\n|;
}

sub html_bottom {
	&html_footer;
	print "</body></html>";
}

sub html_meta {
	print qq|<meta name="description" content="Total Host">\n|;
	print qq|<meta name="keywords" content="Stars! games">\n|;
}

sub html_title {
	my ($title) = @_;
	print "<title>$title</title>";
}

sub html_menu {

print qq|<div class="chromestyle" id="chromemenu">|;
print qq|<ul>|;
print qq|<li><table width=200><tr width=200><td width=200></td></tr></table></li>|;
print qq|<li><a href="$WWW_Scripts/index.pl?lp=home">Home</a></li>|;
if ($session->param("userid")) { print qq|<li><a href="$WWW_Scripts/page.pl?lp=profile&cp=show_profile" rel="dropmenu3">Profile</a></li>|; }
if ($session->param("userid")) { print qq|<li><a href="$WWW_Scripts/page.pl?lp=game&cp=show_first_game&rp=games" rel="dropmenu4">Games</a></li>|; }
#print qq|<li><a href="$WWW_Scripts/index.pl" rel="dropmenu4">Info</a></li>|;
#print qq|<li><a href="#" rel="dropmenu5">Info</a></li>\n|;
print qq|<li><a href="$WWW_Scripts/index.pl?lp=home" rel="dropmenu5">Quick Info</a></li>\n|;
print qq|</ul></div>|;

print qq|<!--3rd drop down menu -->\n|;
print qq|<div id="dropmenu3" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games">My Profile</a>\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game">My Games</a>\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races">My Races</a>\n|;
print qq|<a href="$WWW_Scripts/index.pl?lp=home&cp=started">Getting Started</a>\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=profile&cp=edit_password">Change Password</a>\n|;
print qq|</div>\n|;

print qq|<!--4th drop down menu -->\n|;
print qq|<div id="dropmenu4" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=game&cp=show_games&rp=games">Games</a>\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=my_games">My Games</a>\n|;
print qq|<a href="$WWW_Scripts/page.pl?lp=game&cp=show_new&rp=my_games">New Games</a>\n|;
print qq|</div>\n|;

print qq|<!--5th drop down menu --> \n|;
print qq|<div id="dropmenu5" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$WWW_Scripts/index.pl?lp=home&cp=features">Features</a>\n|;
print qq|<a href="$WWW_Scripts/index.pl?lp=home&cp=faq">FAQ</a>\n|;
print qq|<a href="$WWW_Scripts/index.pl?lp=home&cp=orderofevents">Order of Events</a>\n|;
print qq|<a href="$WWW_Scripts/index.pl?lp=home&cp=tips">Tips</a>\n|;
print qq|</div>\n|;


print <<eof;
<script type="text/javascript">
cssdropdown.startchrome("chromemenu")
</script>
eof
}

sub html_footer {
  use Cwd;
  print "Working Dir:" . getcwd() . " Path: $ENV{'PATH'} PERL5LIB: $ENV{'PERL5LIB'}, Display: $ENV{'DISPLAY'}, WINE Prefix: $ENV{'WINEPREFIX'}, WINE Overrides: $ENV{'WINEDLLOVERRIDES'}";
	print qq|\n<hr>\n<font size="-1"><table width=100%><tr><td width=200></td><td><a href="$WWW_Scripts/index.pl?cp=privacypolicy">Privacy Policy</a></td><td><a href="$WWW_Scripts/index.pl?cp=termsofuse">Terms of Use</a></td><td><A href="mailto:TH\@corwyn.net">Contact Us</A></td></font>\n|;
}

sub clean_old_sessions {
  my $sessions;
  my @stat;
  my $days;
	# Clean the server
	if (int(rand(20)) == 1) { # Only run ~ 1 out of xtimes it's called
  		# expire old sessions
  		$sessions = $Dir_Sessions .'*';  # match all files in the sessions folder
  		while (my $file = glob($sessions)) {
    		@stat=stat $file;   # Age of file in seconds
    		$days = (time()-$stat[9]) / (60*60*24); # Age of file in days
    		if (-f $file) { unlink $file if ($days > 90); }
  		}
	} 
}

sub get_cookie {
	my ($cgi) = @_; 
    $sessionid = $cgi->cookie('TotalHost') || undef;
	return ($sessionid);
}

sub print_cookie {
  ($cgi) = @_;
  $cookie = $cgi->cookie
    (-NAME	=>	'TotalHost', 
	 -VALUE	=>	"$sessionid", 
     -PATH => '/',
	 -EXPIRES=>	"+6M",
	 );
   print $cgi->header(-cookie=> [$cookie]);
}

sub print_redirect {
	($cgi, $sessionid, $redirect) = @_;
     $cookie = $cgi->cookie
     (-NAME	=>	'TotalHost', 
 	 -VALUE	=>	"$sessionid", 
      -PATH => '/',
 	 -EXPIRES=>	"+6M",
 	 );
	print $cgi->redirect( -URL => $redirect, -cookie=> [$cookie]);
}

sub fixdate {
	my ($value) = @_;
	if ($value < 10) { $value = '0' . $value; }
	return $value;
}

sub SubmitTime{
	my ($daytime) = @_;
	my $answer = '';
 	if ($daytime < .0006944) { $answer = int($daytime*86400) . " seconds ago";}
# 	elsif ($daytime < .04167) { $answer = int($daytime * 1440 ) . " minute(s) ago"; }
  elsif ($daytime < .04167) { $answer = "Recently";}
	elsif ($daytime < 1) { $answer = int($daytime * 24 ) . " hour(s) ago";}
	elsif ($daytime >= 1) { $answer = int($daytime) . " day(s) ago";}
	return $answer;
}

#change nulls to "O"
sub checkboxnull {
  local($checkboxnull) = shift(@_);
	if (length($checkboxnull) == 0 ) { return(0); } 
	else {	return(1); }
}

sub checkbox {
	# fix checkbox results
	my ($fix) = @_;
	if ($fix) { $return = 1; } else { $return = 0; }
	return $return;
}

#change nulls to Yes or No
sub checkboxes {
	local($checkboxnull) = shift(@_);
	if (length($checkboxnull) == 0) { return('No'); }
	else { return('Yes'); }
}

# sub checknull {  # Make something null return 0 else return the value
# 	my ($value) = @_;
# #	&LogOut(10,"CHECKNULLSUB: $value",$ErrorLog);
# 	if ($value eq '' || $value eq 0) { return 0;}
# #	else { return $value; }
# 	else { return 1; }
# }

sub checknull {  # Make something null return 0 else return the value
	my ($value) = @_;
	if ($value eq '') { return 0;}
	else { return $value;}

}

# Very important subroutine -- get rid of all the naughty
# metacharacters from the file name. If there are, we
# complain bitterly and die.
# sub clean_filename {
#    my ($name) = @_;
# #   if ($name=~/^[\w\._-]+$/) {
# 	if ($name =~ /^[A-Za-z0-9]+$/) {
# 		my $clean_name = lc(substr($name,0,8));
# 		&LogOut(200, "clean_filename: $clean_name",$LogFile);
# 		return $clean_name;
# 	} else {
#       print "<STRONG>Naughty characters detected. Only ";
#       print 'alphanumerics are allowed. A random game file name will be assigned to you.</STRONG>';
#       &LogOut(0,'clean_filename: Attempt to use naughty characters in File Name $name',$ErrorLog);
# 		return 0;
#    }
# }

sub list_games {
	my ($sql, $type) = @_;
	my $db = &DB_Open($dsn);
	my $countgames=0;
  my $rp;
	print qq|<h2>$type</h2>\n|;
	print "<table border = 1>\n";
  print "<tr><th></th><th>Name</th><th>Status</th><th>Host</th><th>Description</th></tr>\n";
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
      $countgames++;
    	($GameName, $GameFile, $GameStatus, $GameDescrip, $HostName, $NewsPaper) = ($row->{'GameName'}, $row->{'GameFile'}, $row->{'GameStatus'}, $row->{'GameDescrip'}, $row->{'HostName'}, $row->{'NewsPaper'}); 
      if ($NewsPaper) { $rp = 'show_news'; } else { $rp = 'my_games'; } # The URL should only include news if there's news.
 			print qq|<tr>|;
			# Display Game Status
			print qq|<td><img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a></td>\n|;
			# change the links for new games and running games, since their results should be different
			if ($GameStatus == 6 || $GameStatus == 7) {
				#Display Game Name
				print qq|<td>&nbsp&nbsp<a href=$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=$rp&GameFile=$GameFile>$GameName</a></td>|;
			} else {
				#Display Game Name
				print qq|<td>&nbsp&nbsp<a href=$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=$rp&GameFile=$GameFile>$GameName</a></td>|;
			}
			# Display Game Status
			print qq|<td>$GameStatus[$GameStatus]</td>\n|;
			# Display Game Host
			print qq|<td>$HostName</td>\n|;
			# Display Game Description
			print qq|<td>$GameDescrip</td>\n|;
			print qq|</tr>\n|;
  	}
		if (!($countgames)) { print "<tr><td>&nbsp&nbsp No Games Found</td></tr>"; }
    $sth->finish();
	} else { &LogOut(10,"list_games: ERROR Finding list_games",$ErrorLog); }
	print "</table>\n";
	&DB_Close($db);
}

sub rp_list_games {
	my ($sql, $type) = @_;
	my $db = &DB_Open($dsn);
	my $countgames=0;
	print qq|<u>$type</u>\n|;
	print "<table>\n";
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
 			$countgames++;
 	    ($GameName, $GameFile, $GameStatus) = ($row->{'GameName'}, $row->{'GameFile'}, $row->{'GameStatus'});
 			print qq|<tr><td>|;
 			print  qq|<img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a>|; 
      if ($GameStatus == 7) { print qq|&nbsp&nbsp<a href=$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a>|;
      } else { print qq|&nbsp&nbsp<a href=$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a>|; }
 			print qq|</td></tr>\n|;
		}
		if (!($countgames)) { print "<tr><td>&nbsp&nbsp No Games Found</td></tr>"; }
    $sth->finish();
	} else { &LogOut(10,"ERROR: Finding list_games",$ErrorLog); }
	print "</table>\n";
	&DB_Close($db);
}

sub LoadGamesInProgress {
	my ($db,$sql) = @_;
	my $GameCounter = 0;  # Game counter
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {  # Load all game values into the array
      my %GameValues = %{$row};
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
			@GameData[$GameCounter] = { %GameValues };
			$GameCounter++;
		}
    $sth->finish();
	}
#   	for $href ( @GameData ) { print "{ "; for $role ( keys %$href ) { print "$role=$href->{$role} "; } print "}\n"; }
	return \@GameData;
}  

sub Make_CHK { 
# Updates the .chk file for a game
	my($GameFile) = @_;
  # Stars! does not like forward slashes as command-line parameters
  my($CheckGame) = $WINE_executable . ' -v ' . "$Dir_WINE\\$WINE_Games\\\\$GameFile\\\\$GameFile\.hst";

  ##system($CheckGame);
  #chdir("/home/www-data/.wine/drive_c") or die "Cannot change directory: $!";
  #my $exit_status = system($CheckGame);
  my $chkfile = "$Dir_Games/$GameFile/$GameFile" . '.chk';
  &LogOut(200, "Make_CHK: Running for $GameFile, $CheckGame, $chkfile", $LogFile);  
  my $exit_status = &call_system($CheckGame,0); # Make_CHK
  if (-f $chkfile) {
    umask 0002; 
    chmod 0664, $chkfile; 
  }
  # print "Command failed with exit status: $exit_status\n";
	#sleep 2;
}

sub Read_CHK { 
# Returns the values from an existing .chk file for a game
	my($GameFile) = @_;
	my @CHK;
	my $CHK_FILE = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.chk';
  &LogOut(200, "Read_CHK: Running for $CHK_FILE", $LogFile);
  # IF for some reason there's no .chk file, make one. 
  unless (-e $CHK_FILE) { &Make_CHK($GameFile); }
  open (IN_CHK,$CHK_FILE) || &LogOut(0,"Read_CHK: Cannot open stupid .chk file $CHK_FILE for $GameFile",$ErrorLog);
  chomp (@CHK = <IN_CHK>);
 	close(IN_CHK);
 	return @CHK;
}

sub Eval_CHK { 
# Evaluate the existing .CHK file for a game and determine if all turns are in.
	my($GameFile) = @_;
	my($CHKFile) = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.chk'; 
	my($ToGenerate) = 'True';	
	if (-f $CHKFile) { #Check to see if .CHK file is there.
		# Read in appropriate .CHK file
		open (IN_CHK,$CHKFile) || &LogOut(0,'Eval_CHK: Cannot open .chk file $CHKFile',$ErrorLog);
		my(@CHK) = <IN_CHK>;
	 	close(IN_CHK);
		my($Position) = '3';
  		while (@CHK[$Position]) { # For each line, check to see if turn is not in
			if (index(@CHK[$Position], 'turned in') == -1) { $ToGenerate = 'False'; }
	  		$Position++;  	
		}
	}
	# If there is no .chk file, don't auto generate just to be safe	
  # And try to create one for the next loop.
	else { $ToGenerate = 'False'; &Make_CHK($GameFile);}
	return($ToGenerate);
}

sub Eval_CHKLine { 
# Evaluate one of the lines from a .chk file
	my ($ChkResult) = @_;
	my $ChkStatus, $ChkPlayer = '';
	# Possible results: turned in, still out, not in the right game, dead, not on the right year, error
	foreach $key (keys(%TurnResult)) {
		if (index($ChkResult, $key) >= 0 ) { $ChkStatus = $TurnResult{$key}; }
	}
	$ChkPlayer = $ChkResult;
	$ChkPlayer =~ s/(.*: )(\")(.*)(\")(.*)/$3/;
	if ($ChkStatus) { return $ChkStatus, $ChkPlayer; }
	else { 
    &LogOut(0,"Eval_CHKLine: Fail for no \$ChkResult in TurnResult array, $ChkResult",$ErrorLog);
    #return "Error";
    return "Error: $ChkResult"; 
  }
}

sub UpdateNextTurn { #Update the database for the time that the next turn should generate.
	my($db,$NextTurn, $GameFile, $LastTurn) = @_;
  # Fix Next Turn for DST
  # 221110 Time is already fixed for DST earlier, so don't fix it again!
	#$NextTurn = &FixNextTurnDST($NextTurn, $LastTurn, 0); 
	my $upd = "UpdateNextTurn for $GameFile updated to $NextTurn: " . localtime($NextTurn);
	&LogOut(50,$upd,$LogFile);
	$sql = qq|UPDATE Games SET NextTurn = $NextTurn WHERE GameFile = \'$GameFile\';|;
	if (my $sth = &DB_Call($db,$sql)) { 
    $sth->finish();
    return 1;	
  } 
	else { return 0; }
}

sub UpdateLastTurn { 
#Update the database for the time that the next turn should generate.
	my($db, $LastTurn, $GameFile) = @_;
	my $upd = "UpdateLastTurn: Last turn for $GameFile updated to $LastTurn: " . localtime($LastTurn);
	&LogOut(50,$upd,$LogFile);
	$sql = qq|UPDATE Games SET LastTurn = $LastTurn WHERE GameFile = \'$GameFile\';|;
	if (my $sth = &DB_Call($db,$sql)) {
    $sth->finish(); 
    return 1;	
  } 
	else { return 0; }
}

# sub FixNextTurnDST {
# 	# Check to see if the next turn is in a different time zone than the last one, 
# 	# and adjust the value by one hour if necessary
# 	# Display determines whether you're trying to display information that's already been 
# 	# changed so it needs to be adjusted in the other direction.
# 	# 
# 	my ($NextTurn, $LastTurn, $Display) = @_;
# 	my $NextTurnDST, $LastTurnDST; 
# 	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST); 
# 	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $LastTurnDST) = localtime($LastTurn); 
# 	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $NextTurnDST) = localtime($NextTurn); 
# 
# 	if ($Display) {
# 		# If displaying the next turn time
# 		if ($LastTurnDST == $NextTurnDST) { return $NextTurn; }
# 		elsif ($LastTurnDST > $NextTurnDST) { return $NextTurn + 3600; }
# 		elsif ($LastTurnDST < $NextTurnDST) { return $NextTurn - 3600; }
# 		# If something went wrong, do nothing and just return what it was previously.
# 		else { &LogOut(0, "FixNextTurnDST(1): Check_DST FAILED $Display", $ErrorLog); return $NextTurn; }
# 
# 	} else {
# 		# If actually adjusting the next turn time
# 		if ($LastTurnDST == $NextTurnDST) { return $NextTurn; }
# 		elsif ($LastTurnDST < $NextTurnDST) { return $NextTurn + 3600; }
# 		elsif ($LastTurnDST > $NextTurnDST) { return $NextTurn - 3600; }
# 		# If something went wrong, do nothing and just return what it was previously.
# 		else { &LogOut(0, "FixNextTurnDST(2): Check_DST FAILED $Display", $ErrorLog); return $NextTurn; }
# 	}
# }

sub FixNextTurnDST {
    # Adjusts the next turn time if DST changes between turns
    # Arguments:
    #   $NextTurn - the timestamp of the next turn
    #   $LastTurn - the timestamp of the last turn
    #   $Display  - a flag to determine if this is for display purposes
	  # Display determines whether you're trying to display information that's already been 
	  # changed so it needs to be adjusted in the other direction.

    my ($NextTurn, $LastTurn, $Display) = @_;

    # Create DateTime objects for LastTurn and NextTurn
    my $dt_last = DateTime->from_epoch(epoch => $LastTurn, time_zone => $timezone);
    my $dt_next = DateTime->from_epoch(epoch => $NextTurn, time_zone => $timezone);
    
    # Determine DST status for LastTurn and NextTurn
    my $last_is_dst = $dt_last->is_dst;
    my $next_is_dst = $dt_next->is_dst;

    # Check and adjust based on DST difference
    if ($Display) {
        # If displaying the next turn time
        if ($last_is_dst == $next_is_dst) {
            return $NextTurn;  # No adjustment needed
        } elsif ($last_is_dst && !$next_is_dst) {
            return $NextTurn + 3600;  # DST -> standard time (add an hour)
        } elsif (!$last_is_dst && $next_is_dst) {
            return $NextTurn - 3600;  # standard time -> DST (subtract an hour)
        }
    } else {
        # If actually adjusting the next turn time
        if ($last_is_dst == $next_is_dst) {
            return $NextTurn;  # No adjustment needed
        } elsif (!$last_is_dst && $next_is_dst) {
            return $NextTurn + 3600;  # standard time -> DST (add an hour)
        } elsif ($last_is_dst && !$next_is_dst) {
            return $NextTurn - 3600;  # DST -> standard time (subtract an hour)
        }
    }
    
    # Log error if something unexpected happens
    &LogOut(0, "FixNextTurnDST: Unexpected DST status NextTurn: $NextTurn, LastTurn: $LastTurn", $ErrorLog);
    return $NextTurn;
}


sub GenerateTurn { # Generate a turn and refresh files
	use File::Copy;
	my($NumberofTurns, $GameFile) = @_;
	# Backup the existing Turn
	if ($turn = &Game_Backup($GameFile)) { &LogOut(200,"GenerateTurn: Gamefile $GameFile Backed up for Turn: $turn",$LogFile); }
	# Generate the actual Stars! turns
	# There is a Stars! bug when you generate this way from the command line with / the .x[n] file isn't deleted.
	# So you have to use \ (eg d:\th\games instead of d:/th/games)
  # Because Stars! does the forcegen, there are no backups of the interim turns
  
	my($GenTurn) = $WINE_executable . ' -g' . $NumberofTurns . ' ' . "$Dir_WINE\\$WINE_Games\\\\$GameFile\\\\$GameFile\.hst";
  print "\tGenerating a turn for $GameFile\n";
  &LogOut(200, "GenerateTurn: Generating a turn for $GameFile for $GenTurn", $LogFile);    
	my $exit_status = &call_system($GenTurn,2); # GenerateTurn
  &LogOut(200, "GenerateTurn: Done Generating a turn for $GameFile with $GenTurn", $LogFile);
	#sleep 4;
}	

sub Game_Backup {  # Backup the current game folder
	my ($file_name) = @_;
	use File::Copy;
	# Copy the file to a backup location
 	my($Game_Source)= $Dir_Games . '/' . $file_name ;  #
	my ($HST_File) = $Game_Source . '/' . $file_name . '.hst';
	my($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HST_File);
	my $Game_Backup = $Game_Source . '/' . $turn; 
	opendir(DIR, $Game_Source) or &LogOut(0,"<P>Game_Backup: Can\'t opendir $Game_Source for Backup",$ErrorLog); 
  my $call = "mkdir $Game_Backup";
  my $exit_code = system($call);  # Where 0 is success
	#mkdir $Game_Backup;
  &LogOut(100,"Backup: $Game_Backup", $LogFile);
	while (defined($file = readdir(DIR))) {
		# Skip forward unless it's actually a file
 		next unless (-f "$Game_Source/$file");
	 	my($Game_Source)= $Game_Source . '/' . $file;  #
	 	my($Game_Destination)= $Game_Backup . '/' . $file;  #w
		&LogOut(400,"Game_Backup: $Game_Source > $Game_Destination", $LogFile);
	 	copy($Game_Source, $Game_Destination);
	}
	closedir(DIR);
	return $turn;
}

sub File_Date {
	($file) = @_;
  	use File::stat;
	my $date_array = localtime( (stat $file)[9] );
	return $date_array;
}

sub clean {
	# Clean incoming data and try to make it SQL and directory safe
	my ($data) = @_;
	
	$data =~ s/<(.*?)>//g; # remove HTML tags
	$data =~ s/\;//g;  # no ;
	$data =~ s/\"//g;  # no "
	$data =~ s/\'//g;  # no '
	$data =~ s/\.\.//g; # no ..
	$data =~ s/\*//g; # no *
	$data =~ s/\%//g; # no %
	return $data;
}

sub DaysToAdd {  
	# Check to see how many days should be added to a turn  Needs $DayFreq and $WeekDay
	# If $Dailytime and $SecOfDay are blank they have no effect
	my($DayFreq, $DayOfWeekToday, $DailyTime, $SecOfDay) = @_;
	my($NextDayOfWeek) = $DayOfWeekToday + 1;
	my($DaysToAdd) = 1;

	# If today is a day of turn generation prior to when a turn should generate
	# then don't advance the day of the week, because it's before the turn
	# should generate on the day of, not after the turn should generate
	my $DailyTimeSecs = $DailyTime * 60 *60;
	if (($SecOfDay < $DailyTimeSecs ) && (substr($DayFreq, $DayOfWeekToday, 1))) { return 0, $DayOfWeekToday; }

	for (my $i=0; $i <7; $i++) { # If loop to prevent runaway of previous while statement so it can't check more than 7 times
		if ($NextDayOfWeek eq '7') { $NextDayOfWeek = 0; } # loop back to the beginning of the week if necessary
    	my($Tomorrow) = substr($DayFreq, $NextDayOfWeek, 1); #determine the value 0/1 for the next day
		if ($Tomorrow ne '0') { #if a turn should be generated return num days to add
			&LogOut(200,"DaysToAdd: Need to add $DaysToAdd days to turn.",$LogFile);
			return $DaysToAdd, $NextDayOfWeek;
		}
		else { 
			$DaysToAdd++; 
		} 
		# else go to the next day of the week and check again
		$NextDayOfWeek++;
	}
	return 0,0;  # If no days to add were found, which really shouldn't happen
}

sub ValidTurnTime { #Determine whether submitted time is valid to generate a turn
	my($ValidTurnTimeTest, $WhentoTestFor, $Day, $Hour) = @_;	
	&LogOut(100,"ValidTurnTime: $ValidTurnTimeTest, WhentoTestfor: $WhentoTestFor",$LogFile);
	my($Valid) = 'True';
	#Check to see if it's a holiday
# 	if ($GameValues{'ObserveHoliday'} > 0){ 
# 			local($Holiday) = &CheckHolidays($ValidTurnTimeTest, $db);
# 			if ($Holiday eq 'True') { $Valid = 'False'; }
# 	}
	my ($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = localtime($ValidTurnTimeTest);
	#Check to see if it's a valid Day
#	my($DayFreq_local) = &ValidFreq($GameValues{'DayFreq'},$CWeekDay);	if (($WhentoTestFor) eq 'Day') {
  my($DayFreq) = &ValidFreq($Day,$CWeekDay);
  if ($DayFreq eq 'False') { $Valid = 'False'; }
	#Check to see if it's a valid hour
	if (($WhentoTestFor) eq 'Hour') {
#		my($HourlyTime_local) = &ValidFreq($GameValues{'HourFreq'},$CHour);
  	my($HourlyTime) = &ValidFreq($Hour,$CHour);
  	if ($HourlyTime eq 'False') { $Valid = 'False'; }
	}
	&LogOut(200,"   ValidTurnTime: Valid = $Valid ",$LogFile);
	return($Valid);
}

sub ValidFreq { #is the hour or day valid
	my($ValuetoCompare, $TimeUnit) = @_;
	if ( substr($ValuetoCompare,$TimeUnit,1) == 0 ) { 
		return('False'); } #If the proposed unit shouldn't be generated on, return false.
	else { return('True');
	}
}

sub CheckHolidays { #Check to see if today is a holiday, and return True or False
	my($HolidaytoCheck, $db) = @_;
	&LogOut(100,"CheckHolidays: Checking holidays for $HolidaytoCheck",$LogFile);
	my @Holiday = &LoadHolidays($db); 
	($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST) = localtime($HolidaytoCheck);
	my($LoopHolidays) = 0;
	my($IsHoliday) = 'False';	
	my $Month = $CMonth +1; # Correct for Perl Months
	my $Year = 1900 + $CYear; # Correct for Perl Years
	while (@Holiday[$LoopHolidays]) { #While there are holidays to check
		my $HolidayValues = $Holiday[$LoopHolidays];
		my %value = %$HolidayValues;
#		if ((substr(@Holiday[$LoopHolidays],0,4) == $Year) and (substr(@Holiday[$LoopHolidays],5,2) == $Month) and (substr(@Holiday[$LoopHolidays],8,2) == $CDayofMonth)) { 
		if ((substr($value{'Holiday'},0,4) == $Year) and (substr($value{'Holiday'},5,2) == $Month) and (substr($value{'Holiday'},8,2) == $CDayofMonth)) { 
			&LogOut(50,"CheckHolidays: Woohoo, $value{'Holiday'} is a holiday",$LogFile);			
			$IsHoliday = 'True'; 
			return($IsHoliday); # No need to stick around once we know it's a holiday
		}
		$LoopHolidays++;
	}
	&LogOut(200,"CheckHolidays: IsHoliday = $IsHoliday",$LogFile);
	return($IsHoliday); 
}

sub LoadHolidays { #Load the Holiday Values from the Database
	my ($db) = @_;
	my $HolidayCounter = 0;
	my $sql = 'SELECT Holiday, Holiday_txt, Nationality FROM _Holidays ORDER BY Holiday;';
	if (my $sth = &DB_Call($db,$sql)) {
		# Load all game values into the array
		&LogOut(200,"LoadHolidays...",$LogFile);
    while (my $row = $sth->fetchrow_hashref()) { 
      %HolidayValues = %{$row};
#			(@Holiday[$HolidayCounter], @Holiday_txt[$HolidayCounter], @Nationality[$HolidayCounter]) = $db->Data("Holiday", "Holiday_txt", "Nationality");
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
		  @Holiday[$HolidayCounter] = { %HolidayValues };
		  $HolidayCounter++;
		}
    $sth->finish();
	}
	return @Holiday;
}

sub ShowHolidays {
	$db = &DB_Open($dsn);
	&LogOut(200, "ShowHolidays running",$LogFile); 
	my @Holiday = &LoadHolidays($db); 
	print "<table>\n";
	for (my $i=0; $i <=$#Holiday; $i++) { 
		my $HolidayValues = $Holiday[$i];
		my %value = %$HolidayValues;
	 		my $valsub = substr($value{'Holiday'}, 0, 10); 
	 		print "<tr>\n";
	 		print "<td>$valsub</td><td>$value{'Holiday_txt'}</td>\n";
	 		print "</tr>\n";
	}
	print "</table>\n";
}

sub show_race_block {
  # Displays Race attributes in TotalHost
  my ($RaceFile, $Player) = @_;
  use File::Basename;  # Used to get filename components
  
  $filename = $RaceFile;
  
  # Validate that the file exists
  unless (-f $filename) { &LogOut(0,"show_race_block: RaceFile $filename does not exist!", $ErrorLog); }
  
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  open(StarFile, "<$filename") || &LogOut(0,"show_race_block: RaceFile $filename failed to open!", $ErrorLog);
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  &displayBlockRace(@fileBytes);
}

sub process_fix {
	# When the Fix scripts run (detecting errors) they need to log somewhere. 
  # And then be available on the display.
  # The warning/fix file is stored as .warnings in the folder for the game
	## The format for each entry is id<tab>epochtime<tab>year<tab>result
	## and stored in chronologic order, newest first
  # Called from upload.pl
	my ($GameFile, $newWarning) = @_;
	my @fixes;
	my $warningfile = $Dir_Games . '/' . $GameFile . '/' . "$GameFile" . '.warnings';
	my $HSTFile = $Dir_Games . '/' . $GameFile . '/' . "$GameFile" . '.hst';
	($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
	if (!(-f $warningfile)) { # If there's no fix file, create one. 
  	open (OUT_FILE, ">$warningfile") || &LogOut (0,"process_fix: Failed to create $warningfile for $GameFile", $ErrorLog); 
  	print OUT_FILE "\n";
  	close(OUT_FILE);
    umask 0002; 
    chmod 0664, $warningfile;
	}

	# Read in the old fixes
	open (IN_FILE, $warningfile) || &LogOut (0,"process_fix: Failed to read $warningfile for $GameFile", $ErrorLog);
	@fixes = <IN_FILE>;
	close(IN_FILE);
	# Write out the fixes with the current news at the beginning (So the data is from new to old)
	$warningfile = '>' . $warningfile;
	&LogOut (200,"process_fix: Update .warnings with $newWarning for $GameFile", $ErrorLog);
	open (OUTFILE, $warningfile) || &LogOut (0,"process_fix: failed to open fix file $warningfile", $ErrorLog);

  # Since these are CSV,
  @newWarning = split(',', $newWarning);
  foreach my $warning (@newWarning) { 
	  print OUTFILE "Turn:$HST_Turn\t";
	  print OUTFILE localtime() . "\t";
    print OUTFILE "\t$warning\n"; 
  }
  # Now append the old warnings
	print OUTFILE @fixes;
	close (OUTFILE);
}

sub process_game_status {
	# Change the current game state and report such.
	my ($GameFile, $state, $userlogin) = @_;
	my $success = 0;
  my %GameValues; 
	my $db = &DB_Open($dsn);
  # Get the information about the game in question
  # Since this can be reached by players (Pause) needs to not filter for $userlogin
  $sql_local = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|;
	if (my $sth = &DB_Call($db,$sql_local)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row}; 
    $sth->finish();
  }
  my $state_set = 0;
	if ($state eq 'Pause') {
    if ($GameValues{'GamePause'}) {       # If players are allowed to pause the game
#      $sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET Games.GameStatus = 4 WHERE Games.GameFile = \'$in{'GameFile'}\' AND GameUsers.User_Login=\'$userlogin\' AND Games.GamePause=1;|;
      #$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) SET Games.GameStatus = 4 WHERE Games.GameFile = \'$GameFile\' AND GameUsers.User_Login=\'$userlogin\' AND Games.GamePause=1;|;
      $sql = qq|UPDATE Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile SET Games.GameStatus = 4 WHERE (GameUsers.User_Login=\'$userlogin\' AND Games.GameFile=\'$GameFile\' AND Games.GamePause=1) OR (Games.GameFile=\'$GameFile\') AND (Games.HostName=\'$userlogin\');|;
    } else { # Only the host can update the game
      $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    }
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
  } elsif ($state eq 'UnPause') {
    # Try to figure out when the next turn is due and update the date so it doesn't just start generating
		($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs) = &GetTime; 
		if ($GameValues{'GameType'} == 1 ) { # Daily game    
			# Determine when the next possible time is that turns are due
			($DaysToAdd1, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$WeekDay);
			# now advance one interval from that, so you have a full interval
			($DaysToAdd2, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$NextDayOfWeek);
			# Set the time for the next turn on the right day
			$NewTurn = $CurrentDateSecs + $DaysToAdd1*86400 + $DaysToAdd2*86400 +($GameValues{'DailyTime'} *60*60); 
      #if (!$isDST) { $NewTurn = $NewTurn + (60*60); }
      # 221110 Fixing for DST
      $NewTurn = &FixNextTurnDST($NewTurn, time(), 0);
      $GameValues{'GameStatus'} = 2; # So the value is changed if used later before a query.
			$sql = qq|UPDATE Games SET GameStatus = 2, NextTurn = $NewTurn WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
		} elsif ($GameValues{'GameType'} == 2) { # Hourly game
			# Determine when the next possible time is that turns are due
      # BUG: This doesn't include the calculation from FixNextTimeDST
      # Generate the next turn now + number of hours (sliding)
      $NewTurn = time() + ($GameValues{'HourlyTime'} *60 *60); 
      #221110 Fixing for DST
      $NewTurn = &FixNextTurnDST($NewTurn, time(), 0);
      # Make sure we're generating on a valid day
      while (&ValidTurnTime($NewTurn,'Day',$GameValues{'DayFreq'}, $GameValues{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + ($GameValues{'HourlyTime'} *60*60); }
      # Make sure we're generating on a valid hour
      while (&ValidTurnTime($NewTurn,'Hour',$GameValues{'DayFreq'}, $GameValues{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + 3600; } 
			$sql = qq|UPDATE Games SET GameStatus = 2, NextTurn = $NewTurn WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
		} else {
      # BUG: Is there an issue here for DST?
      $NewTurn = time()+86400;  # There really is no time the next turn will be due. Add a day so there's a buffer.
			$sql = qq|UPDATE Games SET GameStatus = 2, NextTurn = $NewTurn WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    }
    $GameValues{'GameStatus'} = 2; # When used later
    $state_set = 1;
    &Make_CHK($GameValues{'GameFile'}); # Rebuild the .chk file in case there's a problem
    &updateList($GameValues{'GameFile'}, 1); # Rebuild the List files in case there's a problem
  } elsif ($state eq 'Locked') {
   	$sql = qq|UPDATE Games SET GameStatus = 0 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 0; # When used later
    $state_set = 1;
    &LogOut(200,$sql,$LogFile);
  } elsif ($state eq 'Unlocked') {
    $sql = qq|UPDATE Games SET GameStatus = 7 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 7; # When used later
    $state_set = 1;
  } elsif ($state eq 'Launched') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
    &Make_CHK($GameValues{'GameFile'}); # Rebuild the .chk file in case there's a problem
  } elsif ($state eq 'Ended') {
    $sql = qq|UPDATE Games SET GameStatus = 9 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 9; # When used later
    $state_set = 1;
    # Back up the last turn. Useful for how movie making works, as it reads the backed up turns
	  if (my $turn = &Game_Backup($GameValues{'GameFile'})) { &LogOut(200,"Ended: Gamefile $GameValues{'GameFile'} Backed up for Turn: $turn",$LogFile); }
  } elsif ($state eq 'Restart') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\' AND GameStatus = 9;|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
  # Adding outage detection / Protection
  } elsif ($state eq 'Paused-Internet Outage') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND (GameStatus = 2 OR GameStatus = 3);|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
  } elsif ($state eq 'Paused-Power Outage') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND (GameStatus = 2 OR GameStatus = 3);|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
  } else {
		&LogOut(100,"process_game_status: for $GameFile failed: $state", $ErrorLog);
  }
  
  if ($state_set) {
  	if (my $sth = &DB_Call($db,$sql)) { 
  		&LogOut(100,"process_game_status: $GameFile set to $state for $sql for $userlogin", $LogFile);
  		$success = 1;
      $sth->finish(); 
  	} else { 
  		print "<P>Game $GameFile failed to $state\n"; 
  		&LogOut(0, "process_game_status: Game $GameFile failed to $state for $userlogin for $sql", $ErrorLog); 
  	}
	  &DB_Close($db);
  }
  
	if ($success) {
	   # Notify all players
		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Status updated to $state|;
		$GameValues{'Message'} = "Game status for $GameValues{'GameName'} has been updated to $state.\n";
    # Customize the message depending on the status change.
    if ($state eq 'Locked') { $GameValues{'Message'}              .= "\nNo new players can join the game.\n"; 
    } elsif ($state eq 'Unlocked') { $GameValues{'Message'}       .= "\nPlayers can again join the game.\n"; 
    } elsif ($state eq 'Pause') { $GameValues{'Message'}          .= "\nAutomated turn generation is suspended.\n"; 
    } elsif ($state eq 'UnPause' && ($GameValues{'GameType'} == 1 || $GameValues{'GameType'} == 2) ) { $GameValues{'Message'} .= "\nAutomated turn generation will renew.\n"; 
    } elsif ($state eq 'Paused-Internet Outage') { $GameValues{'Message'} .= "\nInternet access was lost but is now restored. Automated turn generation was suspended as a safety measure.\n"; 
    } elsif ($state eq 'Paused-Power Outage') { $GameValues{'Message'}    .= "\nPower to the server was lost but is now restored. Automated turn generation was paused as a safety measure. Your host should UnPause the game soon.\n"; 
    } 
    if ($state eq 'Launched') { # First turn 
      $GameValues{'Message'} .= "\nGames default to Paused on game start to provide time for review prior to automated turn generation. Time to take your first turn! \n";
      $GameValues{'HST_Turn'} = '2400'; # Faster than checking the new file for the turn data
      &Email_Turns($GameFile, \%GameValues, 1); # Attach files to initial turn
    } else { &Email_Turns($GameFile, \%GameValues, 0); }
	} else {
  	&LogOut(0, "Game $GameFile failed success to $state for $userlogin for $sql", $ErrorLog); 
  }
}

# A sub function to wrap up the head call, since it's 
# duplicated in LWP::Simple and GGI
sub lwp_head {
  require LWP::Simple;
  return LWP::Simple::head(@_);
}

# Check if the Internet is up
sub check_internet {
  # Net::Ping requires root privs
  #my $p = Net::Ping->new("icmp");
  #return $p->ping("$internet_site");  # Check against a reliable host
  require LWP::Simple;
  my $url = "https://$internet_site";
  if (lwp_head($url)) {
    return 1;
  } else {
    return 0;
  }
}


# Get the number of consecutive Internet "down" records
sub get_internet_down_count {
  my $count = 0;
  open (OUTFILE, "<$internet_status_log") or return 0;  # Return 0 if file doesn't exist
  while (my $line = <OUTFILE>) {
      chomp($line);
      if ($line =~ /Internet is down/) {
          $count++;
      } else {
          $count = 0;  # Reset if we find an "up" status
      }
  }
  close OUTFILE;
  return $count;
}

# Log the Internet status with a timestamp
sub internet_log_status {
  my ($status) = @_;
  my $timestamp = &GetTimeString;
  open (OUTFILE, '>>', $internet_status_log) or print "Could not open $internet_status_log: $!\n";  # or do { print "Could not open $internet_status_log\n"; &LogOut(0,"Could not open $internet_status_log",$ErrorLog); die; }
  print OUTFILE "$timestamp - $status\n";
  print "$timestamp - $status\n";
  close OUTFILE;
  umask 0002; 
  chmod 0664, $internet_status_log;
}

# Clear the log file (used when Internet comes back up)
sub clear_internet_log {
  open (OUTFILE, ">$internet_status_log") or print "Could not open $internet_status_log: $!\n";
  close OUTFILE;
  umask 0002; 
  chmod 0664, $internet_status_log;
}

# A centralized place to make system calls
sub call_system {
  my ($call, $delay) = @_;  
  # Detect if this is being called from CLI or apache2
  # If running as apache, then it's already user www-data. Otherwise make it www-data
  #if ($ENV{'GATEWAY_INTERFACE'}) {
  if ($ENV{'REQUEST_METHOD'}) {
    &LogOut(400,  "call_system: Running as CGI", $LogFile);
  } else {
    $call = "sudo -u $apache_user " . $call;
    &LogOut(400, "call_system: Running from CLI",$LogFile);
  }
  &LogOut(0,"call_system: Starting call: $call",$LogFile);

  #system($CheckGame);
  my $exit_status = system($call);
  # print "Command failed with exit status: $exit_status\n";
  &LogOut(0, "call_system: Ending call: $call, Exit Status: $exit_status", $LogFile); 
	sleep $delay;
  # When a command exits with status 1, Perl's system function returns 1 << 8, which is 256.
  # The actual exit status of the command can be retrieved by shifting the returned value back 8 bits to the right.
  # my $exit_code = $status >> 8;
  return $exit_status;
}

# Return the current user context, mostly used for debug
sub get_user {
  my $user_id = $>; # Get effective user ID
  my $user_info = getpwuid($user_id);  # Get user info
  return $user_info;
}
