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


use Net::SMTP;
use CGI qw(:standard);
use CGI::Session qw/-ip-match/;
CGI::Session->name('TotalHost');
package TotalHost;
use StarStat;
use StarsBlock;
do 'config.pl';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( 
	print_header
	DB_Open DB_Close DB_Call DB_Check 
	Mail_Open Mail_Close Mail_Send MailAttach
	Email_Turns Load_EmailAddresses
	GetTime CheckTime GetTimeString LogOut
	validate
	show_html
	html_top html_head html_banner
	html_left html_right html_bottom
	html_meta html_title html_menu html_footer
	clean_old_sessions get_cookie print_cookie print_redirect 
	checkbox  checknull checkboxnull checkboxes fixdate
	SubmitTime
	UpdateLastTurn UpdateNextTurn FixNextTurnDST GenerateTurn clean_name
	rp_list_games list_games LoadGamesInProgress
	Make_CHK Read_CHK Eval_CHK Eval_CHKLine
	Game_Backup File_Date
	clean clean_filename
	DaysToAdd ValidTurnTime ValidFreq CheckHolidays LoadHolidays ShowHolidays
  show_race_block
  StarsClean StarsFix decryptClean decryptFix
);
# Remarked out functions: FileData FixTime MakeGameStatus checkboxes checkboxnull

# Print header information
sub print_header {
# @_ is the special PERL statement for command line argument items	
#	if (!defined(@_)) { print "Content-type: text/html\n\n"; }
	if (!(@_)) { print "Content-type: text/html\n\n"; }
	else {	print "Location: @_\n\n"; }
}

sub DB_Open {
	($dsn) = @_;
   if (!($db = new Win32::ODBC($dsn))){   
		$error = "Database: Error: connecting to $dsn " . Win32::ODBC::Error();
		&LogOut(0, $error, $ErrorLog);
   } else { return $db;	}
}

sub DB_Close {
	($db)=@_;
	$db->Close();
}

sub DB_Check { #Check to see if an error was returned by the database call
	my ($sqlin, $ErrNum,$ErrText,$ErrConn) = @_;
	if ($ErrNum) { 
		$error = "Database: Error in $sqlin: " . $ErrNum . " * " . $ErrText . "*" . $ErrConn . "\n";
     	&LogOut(0, $error, $ErrorLog);
		return 0;
	} else {return  1; }
}

sub DB_Call {
	my ($db,$sqlin) = (@_);
  $db->Sql($sqlin);
  ($ErrNum, $ErrText, $ErrConn) = $db->Error();
	&LogOut(100,$sqlin,$SQLLog);
	return &DB_Check ($sqlin, $ErrNum, $ErrText, $ErrConn);
}

sub Mail_Send { # Sends mail to the listed user, with the associated values (to:, Subject, Message)
	my ($smtp, $MailTo, $MailFrom, $Subject, $Message) = @_;
	&LogOut(10,"sending mail: $smtp, $MailTo, $MailFrom, $Subject, $Message", $LogFile);
	if ($mail_present) {
		$smtp->mail( "$MailFrom" ); 
    	$smtp->to( "$MailTo" ); 
    	#Prepare for sending data
		$smtp->data();
		# Set headers
		$smtp->datasend("To: $MailTo\n");
		$smtp->datasend("From: $MailFrom\n");
		$smtp->datasend("Subject: $Subject\n");
		$smtp->datasend("\n");
		#Send message
		$smtp->datasend("$Message\n");
		$smtp->datasend("Service process - Do not reply to this message. \n\n");
		$smtp->datasend("\n");
		# End message
		$smtp->dataend();
	} else {
    &LogOut(0,"Mail not present: Would send mail: $smtp, $MailTo, $MailFrom, $Subject, $Message", $ErrorLog);
  }
}

sub Mail_Open {
	if ($mail_present) {
		$smtp = Net::SMTP->new($mail_server, Timeout => 60);
		if (!($smtp)) { 
			&LogOut(0, "Mail_Open: ERROR: Failed to Connect to SMTP", $ErrorLog); 
		} else {
			&LogOut(201, "Mail_Open: SMTP $mail_server open", $LogFile); 
		}
		return $smtp;
	}
}

sub Mail_Close  {
	($smtp) = @_;
	if ($mail_present) {
		$smtp->quit;	
		&LogOut(201, "Mail_Close: Closing mail", $LogFile); 
	}
}

sub MailAttach { 
# Sends mail to the listed user, with the associated values (to:, Subject, Message)
	my ($MailTo, $MailFrom, $Subject, $Message, $Path) = @_;
	&LogOut(200,"MailAttach: $MailTo, $MailFrom, $Subject, $Message, $Path",$LogFile);
	use MIME::Lite;
	### Create the multipart container
	my $msg = MIME::Lite->new (
	  From => $MailFrom,
	  To => $MailTo,
	  Subject => $Subject,
	  Type =>'multipart/mixed'
	) or &LogOut(0,"MailAttach: Error creating multipart container: $!",$ErrorLog);
	
	### Add the text message part
	$msg->attach (
	  Type => 'TEXT',
	  Data => $Message
	) or &LogOut(0,"MailAttach: Error adding the text message part: $!",$ErrorLog);
		
	### Add the file
	$msg->attach (
	   Type => 'binary',
	   Path => $Path,
	   Disposition => 'attachment'
	) or &LogOut(0,"MailAttach: Error adding $attachment: $!",$ErrorLog);
	
	### Send the Message
	MIME::Lite->send('smtp', $mail_server, Timeout=>60);
	$msg->send;
}

sub Email_Turns { #email turns out to the appropropriate players
	my ($GameFile, $GameVs, $Attach) = @_;
	my %GameVals;
	my $Message;
	my $sql;
	%GameVals = %$GameVs;
#	while ( my ($key, $value) = each(%GameVals) ) { print "<P>$key => $value\n"; }
	if ($Attach) {
		# If you're emailing attachments, only do so to people who have requested it
		$sql = qq|SELECT Games.GameFile, GameUsers.User_Login, User.User_Email, GameUsers.PlayerID, User.EmailTurn, GameUsers.PlayerStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\') AND ((User.EmailTurn)=-1) AND ((GameUsers.PlayerStatus)=1));|;
	} else {
		# Otherwise mail the active people. 
		$sql = qq|SELECT Games.GameFile, GameUsers.User_Login, User.User_Email, GameUsers.PlayerID, User.EmailTurn, GameUsers.PlayerStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerStatus)=1));|;
	}
	my ($User_Login, $Email, $PlayerID) = &Load_EmailAddresses($GameFile, $sql);
	my @User_Login = @$User_Login;
	my @Email = @$Email; 
	my @PlayerID = @$PlayerID;
  my $user_count =  @User_Login;
	&LogOut(201, "Email_Turns: User Count $user_count for $GameFile", $LogFile); 
#	for (my $i = 0; $i <= $#User_Login; $i++) {
  # User count is number of players, but the values are in an array
  # So we need to adjust user count to make the range 0 to end of array
	for (my $i = 0; $i <= ($user_count-1); $i++) {
		&LogOut(201, "Email_Turns: Starting Loop to email for $GameFile", $LogFile); 
		$Message = '';
		# This subject line is here because it has the player information that 
		# isn't available until you get to here. 
 		if ($GameVals{'Subject'}) { $Subject = $GameVals{'Subject'}; }
 		else { $Subject = qq|$mail_prefix New Turn for $GameFile.m$PlayerID[$i] - Year $GameVals{'HST_Turn'}|; }
		&LogOut(200, "Email_Turns: Subject: $Subject", $LogFile);
		$Message = $GameVals{'Message'};
		$Message .= "\n\n";
    # If there's a next turn scheduled, and the game isn't over
		if ($GameVals{'NextTurn'} > 0 && $GameVals{'GameStatus'} != 9 && $GameVals{'GameStatus'} != 4 ) {
			$Message .= "Next scheduled turn generation on or after " . localtime($GameVals{'NextTurn'});
			if (&checkbox($GameVals{'AsAvailable'}) == 1 ) { $Message .= " or when all turns are in"; }
			$Message .= ".\n\n";
		}
		if ($GameVals{'ForceGen'} == 1  && $GameVals{'GameStatus'} != 4 ) { 
			$Message .= qq|Automated generation will force $GameVals{'ForceGenTurns'} years at a time for the next $GameVals{'ForceGenTimes'} turns|;
			if ($HST_Turn eq '2400' || $HST_Turn eq '2401' ) { $Message .= " not including years 2400 and 2401, which will generate only one year"; }
			$Message .= ".\n";
		}
		&LogOut(200, "Email_Turns: Message: $Message", $LogFile);
		if ($Attach) {
			my $Path = $File_HST . '/' . $GameFile . '/' . $GameFile . '.m' . $PlayerID[$i];
			&LogOut(200,"Email_Turns: Emailing turn: $Email[$i], $mail_from, $Subject, $Message, $Path",$LogFile);
			&MailAttach($Email[$i], $mail_from, $Subject, $Message, $Path);
		} else {
			&LogOut(201, "Email_Turns: Opening mail",$LogFile); 
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
	&LogOut(100,"      Load_EmailAddresses: Email game name: $GameFile",$LogFile);   
	# added that you must be active to receive emails
#	my $sql = qq|SELECT Games.GameFile, GameUsers.User_Login, User.User_Email, GameUsers.PlayerID, User.EmailTurn, GameUsers.PlayerStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\') AND ((User.EmailTurn)=-1) AND ((GameUsers.PlayerStatus)=1));|;
	my $db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		my $MailCounter = 0; # Game counter
	    while ($db->FetchRow()) {
				(@User_Login[$MailCounter], @Email[$MailCounter], @PlayerID[$MailCounter]) = $db->Data("User_Login", "User_Email", "PlayerID");
				&LogOut(100,"      Load_EmailAddresses: Will mail for $GameFile to User Name: $User_Login[$MailCounter] PlayerID: $PlayerID[$MailCounter] Email: $Email[$MailCounter]",$LogFile);
				$MailCounter++;
			}
	}
	&DB_Close($db);
	return \@User_Login, \@Email, \@PlayerID;
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
#		print $PrintString . "\n";
    if ($LogFile) {
  		$PrintString = localtime(time()) . " : " . $Logging . " : " . $PrintString;
  		open (LOGFILE, ">>$LogFileDate");
  		print LOGFILE "$PrintString\n\n";
  		close LOGFILE;
    } else { print "$PrintString\n"; }
	}
}

sub validate {
	my ($cgi, $session) = @_; # receive two args
	if ( $session->param("logged-in") ) {
    	return 1;  # if logged in, don't bother going further
	} else {
	#print $cgi->redirect( -URL => $rdurl);
# added 120219 I hope it's right
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
	if (-e $File) { #Check to see if file is there.
		open (IN_FILE,$File) || die('Can\'t open file');
		my(@File) = <IN_FILE>;
		close(IN_FILE);
		foreach my $key (@File) {
			if ($key =~ /\<html\>|\<HTML\>|\<body\>|\<BODY\>|\<title\>|\<TITLE\>|\<head\>|\<HEAD\>/) { next;}
			else { print "$key\n"; }
		}
	} else { print "<P>File $File not found.\n"; &LogOut(0, "show_html: File $File not found", $ErrorLog)}
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
	print qq|<tr height=50>\n<td width=20% align=left><a href="$WWW_HomePage"><img src=$WWW_Image| . qq|TotalHost.jpg alt="Total Host" border=0></a></td>\n|;
#	print qq|<td name=notes><iframe id ="ifr" src="$WWW_Notes| . qq|blank.htm" name="your_name" marginwidth=0 marginheight=0 width="400" height="25" frameborder="0" scrolling="auto"></iframe></td>|;
	print qq|<td name="notes"></td>|;

#	if ( $cookie ) { print qq|<td width=30%>ID: $id Login: $login</td>\n|;}
	if ( $cookie && $debug) { print qq|<td width=20%>Cookie: $cookie</td>\n|;}
 	if ( $session->param("logged-in") ) {
		print qq|<td width=10%>$hello</td>\n|;
 		print qq|<td align=right width=5%><a href=$Location_Scripts/account.pl?action=logout>Log Out</a></td>\n|;
# 		print qq|<td align=right width=5%><a href=$Location_Scripts/account.pl?action=logoutfull>Erase</a></td>\n|;
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
# added for help system 120214
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
print qq|<li><a href="$Location_Scripts/index.pl?lp=home">Home</a></li>|;
if ($session->param("userid")) { print qq|<li><a href="$Location_Scripts/page.pl?lp=profile&cp=show_profile" rel="dropmenu3">Profile</a></li>|; }
if ($session->param("userid")) { print qq|<li><a href="$Location_Scripts/page.pl?lp=game&cp=show_first_game&rp=games" rel="dropmenu4">Games</a></li>|; }
#print qq|<li><a href="$Location_Scripts/index.pl" rel="dropmenu4">Info</a></li>|;
#print qq|<li><a href="#" rel="dropmenu5">Info</a></li>\n|;
print qq|<li><a href="$Location_Scripts/index.pl?lp=home" rel="dropmenu5">Quick Info</a></li>\n|;
print qq|</ul></div>|;

# print qq|<table><tr>|;
# print qq|<td width=200></td>|;
# print qq|<td>&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</li>|;
# print qq|<td><a href="$Location_Scripts/index.pl?lp=home">Home</a></li>|;
# if ($session->param("userid")) { print qq|<td><a href="$Location_Scripts/page.pl?lp=profile&cp=show_profile">Profile</a></li>|; }
# if ($session->param("userid")) { print qq|<td><a href="$Location_Scripts/page.pl?lp=game&rp=games">Games</a></li>|; }
# #print qq|<li><a href="$Location_Scripts/index.pl" rel="dropmenu4">Info</a></li>|;
# print qq|</tr></table></div>|;

print qq|<!--3rd drop down menu -->\n|;
print qq|<div id="dropmenu3" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games">My Profile</a>\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game">My Games</a>\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races">My Races</a>\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=profile&cp=edit_password">Change Password</a>\n|;
print qq|</div>\n|;


print qq|<!--4th drop down menu -->\n|;
print qq|<div id="dropmenu4" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=game&cp=show_games&rp=">Games</a>\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news">My Games</a>\n|;
print qq|<a href="$Location_Scripts/page.pl?lp=game&cp=show_new">New Games</a>\n|;
print qq|</div>\n|;

print qq|<!--5th drop down menu --> \n|;
print qq|<div id="dropmenu5" class="dropmenudiv" style="width: 150px;">\n|;
print qq|<a href="$Location_Scripts/index.pl?lp=home&cp=downloads">Downloads</a>\n|;
print qq|<a href="$Location_Scripts/index.pl?lp=home&cp=faq">FAQ</a>\n|;
print qq|<a href="$Location_Scripts/index.pl?lp=home&cp=features">Features</a>\n|;
print qq|<a href="$Location_Scripts/index.pl?lp=home&cp=orderofevents">Order of Events</a>\n|;
print qq|<a href="$Location_Scripts/index.pl?lp=home&cp=tips">Tips</a>\n|;
print qq|</div>\n|;

print <<eof;
<script type="text/javascript">
cssdropdown.startchrome("chromemenu")
</script>
eof
}

sub html_footer {
	print qq|\n<hr>\n<font size="-1"><table width=100%><tr><td width=200></td><td><a href="$WWW_HomePage/scripts/index.pl?cp=privacypolicy">Privacy Policy</a></td><td><a href="$WWW_HomePage/scripts/index.pl?cp=termsofuse">Terms of Use</a></td><td><A href="mailto:TH\@corwyn.net">Contact Us</A></td></font>\n|;
}

sub clean_old_sessions {
	# Clean the server
	if (int(rand(10)) == 1) {
  		# expire old sessions
  		$filez = $session_dir ."/*";
  		while ($file = glob($filez)) {
    		@stat=stat $file; 
    		$days = (time()-$stat[9]) / (60*60*24);
    		unlink $file if ($days > 30);
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
#  	if ($daytime < .0006944) { $answer = int($daytime*86400) . " seconds ago";}
# 	elsif ($daytime < .04167) { $answer = int($daytime * 1440 ) . " minute(s) ago"; }
  if ($daytime < .04167) { $answer = " recently\n";}
	elsif ($daytime < 1) { $answer = int($daytime * 24 ) . " hour(s) ago";}
	elsif ($daytime >= 1) { $answer = int($daytime) . " day(s) ago";}
	return $answer;
}

#change nulls to "O"
sub checkboxnull {
  local($checkboxnull) = shift(@_);
	if (length($checkboxnull) == 0) { return(0); } 
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
sub clean_filename {
   my ($name) = @_;
#   if ($name=~/^[\w\._-]+$/) {
	if ($name =~ /^[A-Za-z0-9]+$/) {
		my $clean_name = lc(substr($name,0,8));
		&LogOut(200, "clean_filename: $clean_name",$LogFile);
		return $clean_name;
	} else {
      print "<STRONG>Naughty characters detected. Only ";
      print 'alphanumerics are allowed. A random game file name will be assigned to you.</STRONG>';
      &LogOut(0,'clean_filename: Attempt to use naughty characters in File Name $name',$ErrorLog);
		return 0;
   }
}

sub list_games {
	my ($sql, $type) = @_;
	my $db = &DB_Open($dsn);
	my $countgames=0;
	print qq|<h2>$type</h2>\n|;
	print "<table border = 1>\n";
  print "<tr><th></th><th>Name</th><th>Status</th><th>Host</th><th>Description</th></tr>\n";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
			$countgames++;
 	    ($GameName, $GameFile, $GameStatus, $GameDescrip, $HostName) = $db->Data("GameName", "GameFile", "GameStatus", "GameDescrip", "HostName");
 			print qq|<tr>|;
			# Display Game Status
			print qq|<td><img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a></td>\n|;
			# change the links for new games and running games, since their results should be different
			if ($GameStatus == 6 || $GameStatus == 7) {
				#Display Game Name
				print qq|<td>&nbsp&nbsp<a href=$Location_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a></td>|;
			} else {
				#Display Game Name
				print qq|<td>&nbsp&nbsp<a href=$Location_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a></td>|;
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
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
			$countgames++;
 	    ($GameName, $GameFile, $GameStatus) = $db->Data("GameName", "GameFile", "GameStatus");
 			print qq|<tr><td>|;
 			print  qq|<img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a>|; 
# 			if ($GameStatus == 2) { print  qq|<img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a>|; }
# 			if ($GameStatus == 4) { print  qq|<img src="$StatusBall{Paused}" alt='Status' border="0"></a>|; }
# 			if ($GameStatus == 3) { qq|<img src="$StatusBall{Inactive}" alt='Status' border="0"></a>|; }
# 			if ($GameStatus == 9) { print qq|<img src="$StatusBall{$GameStatus[$GameStatus]}" alt='$GameStatus[$GameStatus]' border="0"></a>|; }
# 			if ($GameStatus == 7) { print qq|<img src="$StatusBall{Awaiting Players}" alt='Status' border="0"></a>|; }
      if ($GameStatus == 7) { print qq|&nbsp&nbsp<a href=$Location_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a>|;
      } else { print qq|&nbsp&nbsp<a href=$Location_Scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$GameFile>$GameName</a>|; }
 			print qq|</td></tr>\n|;
		}
		if (!($countgames)) { print "<tr><td>&nbsp&nbsp No Games Found</td></tr>"; }
	} else { &LogOut(10,"ERROR: Finding list_games",$ErrorLog); }
	print "</table>\n";
	&DB_Close($db);
}

sub LoadGamesInProgress {
	my ($db,$sql) = @_;
	my $GameCounter; 
	&LogOut(10,"Loading from Game database",$LogFile);
	if (&DB_Call($db,$sql)) {
		# Load all game values into the array
		$GameCounter = 0; # Game counter
	    while ($db->FetchRow()) {
			$GameCounter++;
			my %GameValues = $db->DataHash();
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
			@GameData[$GameCounter] = { %GameValues };
		}
	}
#   	for $href ( @GameData ) { print "{ "; for $role ( keys %$href ) { print "$role=$href->{$role} "; } print "}\n"; }
	return \@GameData;
}  

# sub Get_CHK { 
# # Updates the CHK file and returns the values
# 	my($GameFile) = @_;
# 	my @CHK;
#   &LogOut(200, "Running Get_CHK", $LogFile);
#   &Make_CHK($GameFile);
# #   my($CheckGame) = $executable . ' -v ' . $FileHST . '\\' . $GameFile . '\\' . $GameFile . '.hst';
# #   system($CheckGame);
# #	sleep 1;
#   @CHK = &Read_CHK($GameFile);
# # 	my $CHK_FILE = $File_HST . '/' . $GameFile . '/' . $GameFile . '.chk';
# #   open (IN_CHK,$CHK_FILE) || &LogOut(0,"<P>Cannot open stupid .chk file $CHK_FILE for $GameFile after $CheckGame",$ErrorLog);
# #   chomp (@CHK = <IN_CHK>);
# #  	close(IN_CHK);
#  	return @CHK;
# }

sub Make_CHK { 
# Updates the CHK file for a game
	my($GameFile) = @_;
  my($CheckGame) = $executable . ' -v ' . $FileHST . '\\' . $GameFile . '\\' . $GameFile . '.hst';
  &LogOut(200, "Make_CHK: Running for $GameFile, $CheckGame", $LogFile);
  system($CheckGame);
	sleep 2;
}

sub Read_CHK { 
# Returns the values from an existing CHK file for a game
	my($GameFile) = @_;
	my @CHK;
	my $CHK_FILE = $File_HST . '/' . $GameFile . '/' . $GameFile . '.chk';
  &LogOut(200, "Read_CHK: Running for $CHK_FILE", $LogFile);
  # IF for some reason there's no CHK file, make one. 
  unless (-f $CHK_FILE) { &Make_CHK($GameFile); }
  open (IN_CHK,$CHK_FILE) || &LogOut(0,"Read_CHK: Cannot open stupid .chk file $CHK_FILE for $GameFile",$ErrorLog);
  chomp (@CHK = <IN_CHK>);
 	close(IN_CHK);
 	return @CHK;
}

sub Eval_CHK { 
# Evaluate the existing .chk file for a game and determine if all turns are in.
	my($GameFile) = @_;
	my($CHKFile) = $File_HST . '/' . $GameFile . '/' . $GameFile . '.chk'; 
	my($ToGenerate) = 'True';	
	if (-e $CHKFile) { #Check to see if .chk file is there.
		# Read in appropriate .chk file
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
# Evaluate one of the lines from a chk file
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
    return 'Error'; }
}

sub UpdateNextTurn { #Update the database for the time that the next turn should generate.
# Fix Next Turn for DST
	my($db,$NextTurn, $GameFile, $LastTurn) = @_;
	$NextTurn = &FixNextTurnDST($NextTurn, $LastTurn, 0); 
	my $upd = "UpdateNextTnext Next turn for $GameFile updated to $NextTurn: " . localtime($NextTurn);
	&LogOut(50,$upd,$LogFile);
	$sql = qq|UPDATE Games SET NextTurn = $NextTurn WHERE GameFile = \'$GameFile\';|;
	if (&DB_Call($db,$sql)) { return 1;	} 
	else { return 0; }
}

sub UpdateLastTurn { 
#Update the database for the time that the next turn should generate.
	my($db, $LastTurn, $GameFile) = @_;
	my $upd = "UpdateLastTurn: Last turn for $GameFile updated to $LastTurn: " . localtime($LastTurn);
	&LogOut(50,$upd,$LogFile);
	$sql = qq|UPDATE Games SET LastTurn = $LastTurn WHERE GameFile = \'$GameFile\';|;
	if (&DB_Call($db,$sql)) { return 1;	} 
	else { return 0; }
}

sub FixNextTurnDST {
	# Check to see if the next turn is in a different time zone than the last one, 
	# and adjust the value by one hour if necessary
	# Display determines whether you're trying to display information that's already been 
	# changed so it needs to be adjusted in the other direction.
	# 
	my ($NextTurn, $LastTurn, $Display) = @_;
	my $NextTurnDST, $LastTurnDST; 
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST); 
	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $LastTurnDST) = localtime($LastTurn); 
	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $NextTurnDST) = localtime($NextTurn); 

	if ($Display) {
		# If displaying the next turn time
		# If actually adjusting the next turn time
		if ($LastTurnDST == $NextTurnDST) { return $NextTurn; }
		elsif ($LastTurnDST > $NextTurnDST) { return $NextTurn + 3600; }
		elsif ($LastTurnDST < $NextTurnDST) { return $NextTurn - 3600; }
		# If something went wrong, do nothing and just return what it was previously.
		else { &LogOut(0, "FixNextTurnDST(1): Check_DST FAILED $Display", $ErrorLog); return $NextTurn; }

	} else {
		# If actually adjusting the next turn time
		if ($LastTurnDST == $NextTurnDST) { return $NextTurn; }
		elsif ($LastTurnDST < $NextTurnDST) { return $NextTurn + 3600; }
		elsif ($LastTurnDST > $NextTurnDST) { return $NextTurn - 3600; }
		# If something went wrong, do nothing and just return what it was previously.
		else { &LogOut(0, "FixNextTurnDST(2): Check_DST FAILED $Display", $ErrorLog); return $NextTurn; }
	}
}

sub GenerateTurn { # Generate a turn and refresh files
	use File::Copy;
	my($NumberofTurns, $GameFile) = @_;
	# Backup the existing Turn
	if ($turn = &Game_Backup($GameFile)) { &LogOut(200,"GenerateTurn: Gamefile $GameFile Backed up for Turn: $turn",$LogFile); }
	# Generate the actual Stars! turns
	# There is a Stars! bug when you generate this way  from the command line with / the .x[n] file isn't deleted.
	# So you have to use \ (eg d:\th\games instead of d:/th/games)
	my($GenTurn) = $executable . ' -g' . $NumberofTurns . ' ' . $File_HST . '\\' .  $GameFile . '\\' . $GameFile . '.hst';
	system($GenTurn);
	sleep 3;
  #
  # About here clean the .M files
  &StarsClean($GameFile);
  #
  # Update the CHK File
  &Make_CHK($GameFile);
	#Copy files to the correct (safe) location for download
  # BUG: Why do we do this? 
	my $turn_dir = $File_HST . '/' .  $GameFile . '/';
	my @turn_files = ();
	opendir(DIR, $turn_dir) or &LogOut(0,"GenerateTurn: Can\'t opendir $turn_dir for $GameFile",$ErrorLog); 
	while (defined($file = readdir(DIR))) {
		next unless (-f "$turn_dir/$file");
		# Backup the log files, the turn files, the news file, and the CHK file
    # Except this backup is done earlier in the Game_backup sub?
    # BUG: 191204 Why exactly are we copying the files over to the download folder?
    # Some old design point I've forgotten about? 
    # Turns are currently downloaded from their native location.
    # BUG: The delete game function likely doesn't look in the download folder for cleanup.
    #  Download.pl looks in the actual game folder.
    #
    # Create the directory if it does not exist
    my $newdir = $File_Download . '/' . $GameFile;
    unless (-d  $newdir ) {  mkdir $newdir || &LogOut(0, "GenerateTurn: Cannot create $newdir, $userlogin", $ErrorLog); }
		if ($file =~ /\.M|\.X|\.x|\.news|\.CHK/) {
# 191204 If this is truly where things should download from, no need for the CHK And .X file
#		if ($file =~ /\.M|\.X|\.x/) {
	 		my($Game_Source)= $File_HST . '/' . $GameFile . '/' . $file;  
	 		my($Game_Destination)= $File_Download . '/' . $GameFile . '/' . $file;  
			&LogOut(200,"GenerateTurn: copy $Game_Source > $Game_Destination",$LogFile);
	 		copy($Game_Source, $Game_Destination);
		} 
	}
	closedir(DIR);
	&LogOut(200,"GenerateTurn: Turns for $GameFile moved to $turn_dir",$LogFile);
}	

sub Game_Backup {  # Backup the current game
	my ($file_name) = @_;
	use File::Copy;
	# Copy the file to a backup location
 	my($Game_Source)= $File_HST . '/' . $file_name ;  #
	my ($HST_File) = $Game_Source . '/' . $file_name . '.hst';
	my($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HST_File);
	my $Game_Backup = $Game_Source . '/' . $turn; 
	my @turn_files = ();
	opendir(DIR, $Game_Source) or &LogOut(0,"<P>Game_Backup: Can\'t opendir $Game_Source for Backup",$ErrorLog); 
	mkdir $Game_Backup;
  &LogOut(100,"Backup: $Game_Backup", $LogFile);
	while (defined($file = readdir(DIR))) {
		# Skip forward unless it's actually a file
 		next unless (-f "$Game_Source/$file");
	 	my($Game_Source)= $Game_Source . '/' . $file;  #
	 	my($Game_Destination)= $Game_Backup . '/' . $file;  #w
		&LogOut(300,"Game_Backup: $Game_Source > $Game_Destination", $LogFile);
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
	my($DayFreq, $DayOfWeekToday,$DailyTime,$SecOfDay) = @_;
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
#	my($ValidTurnTimeTest, $WhentoTestFor, $GameValues) = @_;	
#	my $GameValues = %$GameValues;
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
	if (&DB_Call($db,$sql)) {
		# Load all game values into the array
		&LogOut(200,"LoadHolidays...",$LogFile);
	  	while ($db->FetchRow()) {
#			(@Holiday[$HolidayCounter], @Holiday_txt[$HolidayCounter], @Nationality[$HolidayCounter]) = $db->Data("Holiday", "Holiday_txt", "Nationality");
			my %HolidayValues = $db->DataHash();
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
			@Holiday[$HolidayCounter] = { %HolidayValues };
			$HolidayCounter++;
		}
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

sub dbh_connect {
	#Pull game information from the database.	$dsn = "TotalHost";
	# If there's an error, say why
	my $dsn_name = 'dbi:ODBC:' . $dsn;
    my ($dbh);
    $dbh = DBI->connect($dsn_name, $db_user, $db_pass, { PrintError => 0, AutoCommit => 1 });
    if (! defined($dbh) ) {
		print "dbh_connect: Error connecting to DSN '$dsn_name'\n";
        print "Error was:\n";
        print "$DBI::errstr\n";         # $DBI::errstr is the error received from the SQL server
        return 0;
    }
    return $dbh;
}

sub db_sql {
	my ($sql, $sth, $rc);
    $sql = shift;
    if (! ($sql) ) {
		&LogOut(0, "db_sql: Must pass SQL statement to db_sql!",$ErrorLog);
		return 0;
	}
	# Verify that we are connected to the database
	if (! ($dbh) || ! ($sth = $dbh->prepare("GO") )) {
		# Attempt to reconnect to the database
		if (! dbh_connect() ) {
			&LogOut(0, "db_sql: Unable to connect to database",$ErrorLog);
			exit;   # Unable to reconnect, exit the script gracefully
        }
    } else {
		$sth->execute;      # Execute the "GO" statement
		$sth->finish;       # Tell the SQL server we are done
	}
	$sth = $dbh->prepare($sql);     # Prepare the SQL statement passed to db_sql
	# Check that the statement prepared successfully
	if(! defined($sth) || ! ($sth)) {
		&LogOut(0, "db_sql: Failed to prepare SQL statement:$DBI::errstr",$ErrorLog);
#		print "$DBI::errstr\n";
		# Check for a connection error -- should not occur
		if ($DBI::errstr =~ /Connection failure/i) {
			if (! dbh_connect() ) { &LogOut(0, "db_sql: Unable to connect to database.", $ErrorLog); exit; }
			else {
				&LogOut(0, "db_sql: Database connection re-established, attempting to prepare again.",$ErrorLog);
				$sth = $dbh->prepare($sql);
			}
		}
		# Check to see if we recovered
 		if ( ! defined( $sth ) || ! ($sth) ) {
			&LogOut(0, "db_sql: Unable to prepare SQL statement: $sql", $ErrorLog);
			return 0;
		}
	}
	# Attempt to execute our prepared statement
	$rc = $sth->execute;
	if (! defined( $rc ) ) {
		# We failed, print the error message for troubleshooting
		&LogOut(0, "Unable to execute prepared SQL statement:$DBI::errstr $sql", $ErrorLog);
		return 0;
	}
	# All is successful, return the statement handle
	return $sth;
}

sub show_race_block {
  # Displays Race attributes in TotalHost
  # Note that the race file has a checksum value, so writing out changes will 
  # fail.
  my ($RaceFile, $Player) = @_;
  use File::Basename;  # Used to get filename components
  
  $filename = $RaceFile;
  
  # Validate that the file exists
  unless (-e $filename) { &LogOut(0,"show_race_block: RaceFile $filename does not exist!", $ErrorLog); }
  
  # Read in the binary Stars! file, byte by byte
  my $FileValues;
  my @fileBytes;
  open(StarFile, "<$filename");
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  
  # Decrypt the data, block by block
  &displayBlockRace(@fileBytes);
}

sub StarsClean {
  my ($GameFile) = @_;
  # Removes shared "privileged" information from a .M file for TotalHost
#  my $cleanFiles = 1; # 0, 1, 2: display, clean but don't write, write. See config.pl
  my @mFiles;      
  my $filename;
  my $inDir = $FileHST . "\\" . $GameFile;
  
  #Validate directory 
  unless (-d $inDir  ) { 
    &LogOut(0,"StarsClean: Failed to find $inDir for cleaning $GameFile", $ErrorLog);
  }
  
  # Get all the file names in the directory
  # Reading the dir is easier than figuring out the number of players in the game
  opendir(BIN, $inDir) or &LogOut(0,"StarsClean: Failed to open $inDir for cleaning $GameFile", $ErrorLog);
  my $file;
  my $fullName;
  while (defined ($file = readdir BIN)) {
    next if $file =~ /^\.\.?$/; # skip . and ..
    next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
    $fullName = $inDir . '\\' . $file;
    push @mFiles, $fullName;
  }
  if (@mFiles == 0) { &LogOut(0,"StarsClean: Failed to find any files in $inDir for cleaning $GameFile", $ErrorLog); }

  foreach my $mFile (@mFiles) {
    &LogOut(100,"StarsClean: cleaning $mFile in $GameFile", $LogFile);
    # Read in the binary Stars! file(s), byte by byte
    my $fileValues;
    my @fileBytes;
    
    open(StarFile, "<$mFile" );
    binmode(StarFile);
    while ( read(StarFile, $fileValues, 1)) {
      push @fileBytes, $fileValues; 
    }
    close(StarFile);
    
    # Decrypt the data, block by block
    # and modify appropriately
    my ($outBytes, $needsCleaning) = &decryptClean(@fileBytes);
    my @outBytes = @{$outBytes};
    
    # Output the Stars! file with modified data
    # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
    if ($needsCleaning) {
      # Backup the file before we clean it
      # Because otherwise we can't get back to where we were, as the actual
      # backup is pre-turn generation, so random event will change.
      # BUG: File name is important here, as backups work from the filename
      #   So do we want these to be .m files?

      if ($cleanFiles > 1) {  # Don't do unless in clean write mode
        my $mFilePreclean = "preclean." . $mFile;
		    &LogOut(300,"StarsClean Backup: $mFile > $mFilePreclean", $LogFile);
	 	    copy($mFile, $mFilePreclean);
        &LogOut(200," StarsClean: Pushing out $mFile post-cleaning for $GameFile", $LogFile);
        open ( outFile, '>:raw', "$mFile" );
        for (my $i = 0; $i < @outBytes; $i++) {
          print outFile $outBytes[$i];
        }
        close ( outFile);
        &LogOut(200," StarsClean: Cleaned $mFile for $GameFile", $LogFile);
      } else { &LogOut(300," StarsClean: Not in Clean mode for $GameFile", $LogFile); }
    }
  } 
}

sub StarsFix {
  my ($xFile) = @_; # includes path
  my $needsFixing;
  # Fixes data coming in from an .x file
  #  my $fixFiles = 1; # 0, 1, 2: display, clean but don't write, write. See config.pl
 
  &LogOut(100,"StarsFix: fixing $xFile", $LogFile);
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
  # So we have choices here. 
  # Right now, warning or not, needs fixing or not, let the game save 
  # It will have fixed for the colonizer bug if necessary which means write it back out.
  # $needsFixing means write the file back out. 
  my ($outBytes, $needsFixing, $warning) = &decryptFix(@fileBytes);
  my @outBytes = @{$outBytes};
  
  # Output the Stars! file with modified data
  # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
  if ($needsFixing) {
    # Backup the file before we clean it
    # Because otherwise we can't get back to where we were, as the actual
    # backup is pre-turn generation, so random event will change.
    # BUG: File name is important here, as backups work from the filename
    #   So do we want these to be .x files?
    if ($fixFiles > 1) {  # Don't do unless in clean write mode
      my $xFilePreFix = "preFix." . $xFile;
  	  &LogOut(300,"StarsFix Backup: $xFile > $xFilePreFix", $LogFile);
   	  copy($xFile, $xFilePreclean);
      &LogOut(200," StarsFix: Pushing out $xFile post-fixing", $LogFile);
      open ( outFile, '>:raw', "$xFile" );
      for (my $i = 0; $i < @outBytes; $i++) {
        print outFile $outBytes[$i];
      }
      close ( outFile);
      &LogOut(200," StarsFix: Fixed $xFile", $LogFile);
    } else { &LogOut(300," StarsFix: Not in Fix mode for $xFile", $LogFile); }
    return $warning;
  } else { 
  	&LogOut(300,"StarsFix: $xFile does not need fixing", $LogFile);
    return $warning; 
  }  # BUG: Right now, it will ALWAYS permit the file to save
     # If we don't want it to save when it shouldn't the this 
     # return should be a 0;
}

sub decryptClean {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my $needsCleaning = 0;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY );
  my ($blockId, $size, $data );
    # For Object Block 43 
  my $objectId;    
  my $count = -1;
  my $number;
  my $owner;
  my $type; # 0 = minefield, 1 = packet/salvage, 2 = wormhole, 3 = MT
  # For MT
  my ($warp, $metBits, $itemBits, $turnNo, $turnNoDisplay);
  #For minefields
  my ($mineCount, $mineDetonate, $mineType);
  #For wormholes
  my ($wormholeId, $targetId, $beenThrough, $canSee, $stability);
  # For packets
  my ($targetAndSpeed, $destPlanetId, $WarpSpeedMinus4, $WarpOverMDLimit);
  
  # For Player Block 6
  my ($playerId, $ShipSlotsUsed, $PlanetCount);
  my ($FleetAndStarBaseDesignCount, $FleetCount, $StarBaseDesignCount); 
  my ($fullDataFlag, $fullDataBytes);
  my $playerRelations; # byte, 0 neutral, 1 friend, 2 enemy
  # The values used when cleaning race values. Defaults to Humanoids
  my @resetRace =  ( 81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 );

  my $LogOutput;

  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($blockId, $size, $data ) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    if ($blockId == 43 ) { $debug = 1;  } else { $debug = 0;}
    # FileHeaderBlock, never encrypted
    if ($blockId == 8 ) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
      unless ($Magic eq "J3J3") { &LogOut(100,"decryptClean: One of the files is not a .M file. Stopped along the way.", $ErrorLog); }
      ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
      @decryptedData = @{ $decryptedData };    
      # WHERE THE MAGIC HAPPENS
      # Process the decrypted bytes
      if ($blockId == 43) { # Check for special attributes in the Object Block
        if ($size == 2) {
          my $count = &read16(\@decryptedData, 0);
        } else {
          $objectId =  &read16(\@decryptedData, 0);
          $number = $objectId & 0x01FF;
          $owner = ($objectId & 0x1E00) >> 9;
          $type = $objectId >> 13;
          # Mystery Trader
          if (&isMT($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
      			$metBits = &read16(\@decryptedData, 12);
      			$itemBits = &read16(\@decryptedData, 14);
      			$turnNo = &read16(\@decryptedData, 16); # Which doesn't report turn like everything else
            $turnNoDisplay =  $turnNo + 2401;
            my $MTPart = &getMTPartName($itemBits);
            $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);

            if ($cleanFiles) { 
              # Reset players who has traded with MT
              ($decryptedData[12], $decryptedData[13]) = &resetPlayers($Player, &read16(\@decryptedData, 12));
              # reset values for display
              $metBits = &read16(\@decryptedData, 12);
              # Reset the MT Part
              $decryptedData[14] = 0;
              $decryptedData[15] = 0;
              # reset part values for display
      			  $itemBits = &read16(\@decryptedData, 14);
              $MTPart = &getMTPartName($itemBits);
            }
            $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);
          # Minefields
          } elsif (&isMinefield($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2); # 2 bytes
            $y = &read16(\@decryptedData, 4); # 2 bytes
            $canSee = &read16(\@decryptedData, 10);
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);
            if ($cleanFiles) {
              # Hard to find any data here as not much is known of the format
              # Reset players who can see the minefield
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $canSee = &read16(\@decryptedData, 10);
            }
            $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);
          #Wormholes
          } elsif (isWormhole($type)) {
            $needsCleaning = 1;
            $x = &read16(\@decryptedData, 2);
            $y = &read16(\@decryptedData, 4);
    	      $canSee = &read16(\@decryptedData, 8);
    	      $beenThrough = &read16(\@decryptedData, 10);
    	      $targetId = &read16(\@decryptedData, 12) % 4096;   
            $turnNo = &read16(\@decryptedData, 16);
            $turnNoDisplay =  $turnNo + 2401;
            $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);
            if ($cleanFiles) { 
              # Reset players who can see wormhole
              ($decryptedData[8], $decryptedData[9]) = &resetPlayers ($Player, &read16(\@decryptedData, 8));
              # reset values for display
    	        $canSee = &read16(\@decryptedData, 8);
              # Reset players who are known to have been through
              ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
              # reset values for display
              $beenThrough = &read16(\@decryptedData, 10);
            }
            $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
            &LogOut(100,"decryptClean: $LogOutput", $LogFile);
          } elsif (&isMinefield($type)) {
            # Packet
            # nothing decoded enough to clean
          } 
        }
      }
      if ($blockId == 6) { # Player Block
        my $PRT = $decryptedData[76];
        if ($PRT == 3) {
          # Reset the info the CA player can see
          $needsCleaning = 1;
          $LogOutput = &showRace(\@decryptedData,$size);
          &LogOut(400,"decryptClean: $LogOutput", $LogFile);
          if ($cleanFiles) {   
            @decryptedData = &resetRace(\@decryptedData,$Player);
          }
          $LogOutput = &showRace(\@decryptedData,$size); 
          &LogOut(400,"decryptClean: $LogOutput", $LogFile);
        }
      }
    # END OF MAGIC
    #reencrypt the data for output
    ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
    @encryptedBlock = @ { $encryptedBlock };
    push @outBytes, @encryptedBlock;
  }
  $offset = $offset + (2 + $size); 
  }
  return \@outBytes, $needsCleaning;
}

sub decryptFix {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my @encryptedBlock;
  my @outBytes;
  my $needsCleaning = 0;
  my $logOutput;
  my $warning;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ($typeId, $size, $data);
  my $offset = 0; #Start at the beginning of the file
  while ($offset < @fileBytes) {
    # Get block info and data
    ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
    @data = @{ $data }; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
    # FileHeaderBlock, never encrypted
    if ($typeId == 8) {
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      # Detect the Colonizer, Spack Dock SuperLatanuim, and 10 starbase design bugs
      if ($typeId == 27) { # Design & Design Change block in .x files
        my $index = 2; # there are two extra bytes in a .x file
        $deleteDesign = $decryptedData[0] % 16;
        if ($deleteDesign == 0) { 
          $designToDelete = $decryptedData[1] % 16;  $logOutput .= "designToDelete: $designToDelete\n";
          $isStarbase = ($decryptedData[1] >> 4) % 2; $logOutput .= "isStarbase: $isStarbase\n";
        }
        # If the order is to delete a design, the rest of this isn't there.
        unless (!$deleteDesign) { 
          $isFullDesign =  ($decryptedData[$index] & 0x04); $logOutput .= "isFullDesign: $isFullDesign\n";
          my $byte1 = $decryptedData[$index+1];
          $isStarbase = ($decryptedData[$index+1] & 0x40);  $logOutput .= "isStarbase: $isStarbase\n";
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; $logOutput .= "designNumber: $designNumber\n";
          if ($isFullDesign) {
            $armor = &read16(\@decryptedData, $index+4);  $logOutput .= "armor: $armor\n";
            $slotCount = $decryptedData[$index+6] & 0xFF; $logOutput .= "slotCount: $slotCount\n";  # Actual number of slots
            $slotEnd = $index+17+($slotCount*4); $logOutput .= "slotEnd: $slotEnd\n";
            $shipNameLength = $decryptedData[$slotEnd];          
            for (my $i = $index+19; $i < $slotEnd-1; $i+=4) {
              $itemId = $decryptedData[$i]; #print "$i: ItemId: $itemId \n";
              $itemCount =  $decryptedData[$i+1]; #print "$i: itemCount: $itemCount \n";
              $itemCategory0 = $decryptedData[$i+2]; #print "$i: slotId: $slotId \n";
              $itemCategory1 = $decryptedData[$i+3]; #print "$i: itemCategory: $itemCategory \n";  # Whether in the first or second set of 8
              #############################################################3
              # Detect (and potentially fix) ship design issues
              # Fix the colonizer bug
              # Note the "," at the end is used as a filter on display
              if ($itemCategory0 == 0 &&  $itemCategory1 == 16 &&  $itemId == 0 && $itemCount == 0) {
                $warning .= "Colonizer Bug detected in design slot $designNumber: ";
                $warning .= "$shipName. ";
                if ($fixFiles > 1) {$warning .= ' Fixing!!! ,';} else {$warning .= " ,";}
                $decryptedData[$i+3] = 0; # fixing bug by setting the slot to empty
                $needsCleaning = 1;
              }
              # Detect Space Dock Armor slot Buffer Overflow
              if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory0 == 8 && $itemCount >=22  && $armor  >= 49518) {
                # BUG: Currently warning but not fixing spacedock bug
                $warning .= "Spacedock Bug! Spacedock Armor Overflow (> 22 superlatanium slots) detected in design slot $designNumber: ";
                $warning .= "$shipName. ,";
                $needsCleaning = 0;
              }
              # Detect the 10th starbase design
            }
            if ($isStarbase &&  $designNumber == 9) {
              #BUG: Currently warning but not fixing Starbase bug
              $warning .= "10 Starbases! Potential Crash if Player #1 has fleet #1 in orbit of a starbase and refuels when the Last (?) Player has a 10th starbase design. ,";
              $needsCleaning = 0;
            }
          } else { $slotEnd = 6; $shipNameLength = $decryptedData[$slotEnd]; }
          $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          &LogOut(100,"decryptFix: $LogOutput", $LogFile);
        }
      }
      # END OF MAGIC
      #reencrypt the data for output
      ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
      @encryptedBlock = @ { $encryptedBlock };
      push @outBytes, @encryptedBlock;
    }
    $offset = $offset + (2 + $size); 
  }
  return \@outBytes, $needsCleaning, $warning;
}

##########################################

# 
# $sql = qq|SELECT User.* FROM [User] WHERE User.EmailList=Yes;|;
# 
# sub Email_Players {
# my ($sql, $GameFile, $GameName) = @_;
# my $db = &DB_Open($dsn);
# if (&DB_Call($db,$sql)) { if ($db->FetchRow()) { %PlayerValues = $db->DataHash(); } 	}
# &DB_Close($db);
# 
# $url = qq|$WWW_HomePage$Location_Scripts/page.pl?lp=game&cp=show_game&rp=&GameFile=$GameFile|
# $Subject = qq|$mail_prefix New Game Created on TotalHost|;
# $Message = qq|A new game has been created on <a href="$url">TotalHost</a>.|;
# 
# 
# for (my $i = 0; $i <= $#User_Login; $i++) {
# &LogOut(200, "Opening mail",$LogFile); 
# $smtp = &Mail_Open;
# &LogOut(200,"Emailing player: $Email[$i], $mail_from, $Subject, $Message",$LogFile);
# &Mail_Send($smtp, $Email[$i], $mail_from, $Subject, $Message);
# &Mail_Close($smtp);
# 
# }