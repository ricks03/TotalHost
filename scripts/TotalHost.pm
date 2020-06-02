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
);
# Remarked out functions: FileData FixTime MakeGameStatus checkboxes checkboxnull
#  StarsClean decryptClean StarsFix decryptFix StarsQueue decryptQueue
#  plusone zerofy splitWarnId attackWho
#  showCategory

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
	&LogOut(200,$sqlin,$SQLLog);
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
	# There is a Stars! bug when you generate this way from the command line with / the .x[n] file isn't deleted.
	# So you have to use \ (eg d:\th\games instead of d:/th/games)
	my($GenTurn) = $executable . ' -g' . $NumberofTurns . ' ' . $File_HST . '\\' .  $GameFile . '\\' . $GameFile . '.hst';
	system($GenTurn);
	sleep 3;
  #
  # Clean the .M files
  # Works on a folder-by folder game-by-game basis. 
  # Requires a file named 'clean' in the game folder
  my $cleanFile = $FileHST . '\\' . $GameFile . '\\' . 'clean';
  if ($cleanFiles && -e $cleanFile) { &StarsClean($GameFile); }
  #
  # Update the CHK File
  &Make_CHK($GameFile);
	# Copy files to the correct (safe) location for download
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
  # The race file has a checksum value, so writing out changes will 
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

# sub StarsClean {
#   my ($GameFile) = @_;
#   # Removes shared "privileged" information from a .M file for TotalHost
# #  my $cleanFiles = 1; # 0, 1, 2: display, clean but don't write, write. See config.pl
#   my @mFiles;      
#   my $filename;
#   my $inDir = $FileHST . "\\" . $GameFile;
#   
#   #Validate directory 
#   unless (-d $inDir  ) { 
#     &LogOut(0,"StarsClean: Failed to find $inDir for cleaning $GameFile", $ErrorLog);
#   }
#   
#   # Get all the file names in the directory
#   # Reading the dir is easier than figuring out the number of players in the game
#   opendir(BIN, $inDir) or &LogOut(0,"StarsClean: Failed to open $inDir for cleaning $GameFile", $ErrorLog);
#   my $file;
#   my $fullName;
#   while (defined ($file = readdir BIN)) {
#     next if $file =~ /^\.\.?$/; # skip . and ..
#     next unless ($file =~  /(^.*\.[Mm]\d*$)/); #prefiltering for .m files
#     $fullName = $inDir . '\\' . $file;
#     push @mFiles, $fullName;
#   }
#   if (@mFiles == 0) { &LogOut(0,"StarsClean: Failed to find any files in $inDir for cleaning $GameFile", $ErrorLog); }
# 
#   foreach my $mFile (@mFiles) {
#     &LogOut(100,"StarsClean: cleaning $mFile in $GameFile", $LogFile);
#     # Read in the binary Stars! file(s), byte by byte
#     my $fileValues;
#     my @fileBytes;
#     
#     open(StarFile, "<$mFile" );
#     binmode(StarFile);
#     while ( read(StarFile, $fileValues, 1)) {
#       push @fileBytes, $fileValues; 
#     }
#     close(StarFile);
#     
#     # Decrypt the data, block by block
#     # and modify appropriately
#     my ($outBytes, $needsCleaning) = &decryptClean(@fileBytes);
#     my @outBytes = @{$outBytes};
#     
#     # Output the Stars! file with modified data
#     # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
#     if ($needsCleaning) {
#       # Backup the file before we clean it
#       # Because otherwise we can't get back to where we were, as the actual
#       # backup is pre-turn generation, so random event will change.
#       # BUG: File name is important here, as backups work from the filename
#       #   So do we want these to be .m files?
# 
# #      if ($cleanFiles > 1) {  # Don't do unless in clean write mode
#         my $mFilePreclean = "preclean." . $mFile;
# 		    &LogOut(300,"StarsClean Backup: $mFile > $mFilePreclean", $LogFile);
# 	 	    copy($mFile, $mFilePreclean);
#         &LogOut(200," StarsClean: Pushing out $mFile post-cleaning for $GameFile", $LogFile);
#         open ( outFile, '>:raw', "$mFile" );
#         for (my $i = 0; $i < @outBytes; $i++) {
#           print outFile $outBytes[$i];
#         }
#         close ( outFile);
#         &LogOut(200," StarsClean: Cleaned $mFile for $GameFile", $LogFile);
# #      } else { &LogOut(300," StarsClean: Not in Clean mode for $GameFile", $LogFile); }
#     }
#   } 
# }
# 
# sub decryptClean {
#   my (@fileBytes) = @_;
#   my @block;
#   my @data;
#   my ($decryptedData, $encryptedBlock, $padding);
#   my @decryptedData;
#   my @encryptedBlock;
#   my @outBytes;
#   my $needsCleaning = 0;
#   my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
#   my ($random, $seedA, $seedB, $seedX, $seedY );
#   my ($blockId, $size, $data );
#     # For Object Block 43 
#   my $objectId;    
#   my $count = -1;
#   my $number;
#   my $owner;
#   my $type; # 0 = minefield, 1 = packet/salvage, 2 = wormhole, 3 = MT
#   # For MT
#   my ($warp, $metBits, $itemBits, $turnNo, $turnNoDisplay);
#   #For minefields
#   my ($mineCount, $mineDetonate, $mineType);
#   #For wormholes
#   my ($wormholeId, $targetId, $beenThrough, $canSee, $stability);
#   # For packets
#   my ($targetAndSpeed, $destPlanetId, $WarpSpeedMinus4, $WarpOverMDLimit);
#   
#   # For Player Block 6
#   my ($playerId, $ShipSlotsUsed, $PlanetCount);
#   my ($FleetAndStarBaseDesignCount, $FleetCount, $StarBaseDesignCount); 
#   my ($fullDataFlag, $fullDataBytes);
#   my $playerRelations; # byte, 0 neutral, 1 friend, 2 enemy
#   # The values used when cleaning race values. Defaults to Humanoids
#   my @resetRace =  ( 81,0,1,0,0,0,0,0,50,50,50,15,15,15,85,85,85,15,3,3,3,3,3,3,35,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,15,96,35,0,0,0,10,10,10,10,10,5,10,0,1,1,1,1,1,1,9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 );
# 
#   my $LogOutput;
# 
#   my $offset = 0; #Start at the beginning of the file
#   while ($offset < @fileBytes) {
#     # Get block info and data
#     ($blockId, $size, $data ) = &parseBlock(\@fileBytes, $offset);
#     @data = @{ $data }; # The non-header portion of the block
#     @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
#     if ($blockId == 43 ) { $debug = 1;  } else { $debug = 0;}
#     # FileHeaderBlock, never encrypted
#     if ($blockId == 8 ) {
#       # We always have this data before getting to block 6, because block 8 is first
#       # If there are two (or more) block 8s, the seeds reset for each block 8
#       ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block );
#       unless ($Magic eq 'J3J3') { &LogOut(100,"decryptClean: One of the files is not a .M file. Stopped along the way.", $ErrorLog); }
#       ($seedA, $seedB ) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
#       $seedX = $seedA; # Used to reverse the decryption
#       $seedY = $seedB; # Used to reverse the decryption
#       push @outBytes, @block;
#     } else {
#       # Everything else needs to be decrypted
#       ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB ); 
#       @decryptedData = @{ $decryptedData };    
#       # WHERE THE MAGIC HAPPENS
#       # Process the decrypted bytes
#       if ($blockId == 43) { # Check for special attributes in the Object Block
#         if ($size == 2) {
#           my $count = &read16(\@decryptedData, 0);
#         } else {
#           $objectId =  &read16(\@decryptedData, 0);
#           $number = $objectId & 0x01FF;
#           $owner = ($objectId & 0x1E00) >> 9;
#           $type = $objectId >> 13;
#           # Mystery Trader
#           if (&isMT($type)) {
#             $needsCleaning = 1;
#             $x = &read16(\@decryptedData, 2);
#             $y = &read16(\@decryptedData, 4);
#       			$metBits = &read16(\@decryptedData, 12);
#       			$itemBits = &read16(\@decryptedData, 14);
#       			$turnNo = &read16(\@decryptedData, 16); # Which doesn't report turn like everything else
#             $turnNoDisplay =  $turnNo + 2401;
#             my $MTPart = &getMTPartName($itemBits);
#             $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
# 
#             if ($cleanFiles) { 
#               # Reset players who has traded with MT
#               ($decryptedData[12], $decryptedData[13]) = &resetPlayers($Player, &read16(\@decryptedData, 12));
#               # reset values for display
#               $metBits = &read16(\@decryptedData, 12);
#               # Reset the MT Part
#               $decryptedData[14] = 0;
#               $decryptedData[15] = 0;
#               # reset part values for display
#       			  $itemBits = &read16(\@decryptedData, 14);
#               $MTPart = &getMTPartName($itemBits);
#             }
#             $LogOutput = "$turnNoDisplay: Mystery Trader: $x, $y met: " . &getPlayers($metBits) . ", $MTPart";
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
#           # Minefields
#           } elsif (&isMinefield($type)) {
#             $needsCleaning = 1;
#             $x = &read16(\@decryptedData, 2); # 2 bytes
#             $y = &read16(\@decryptedData, 4); # 2 bytes
#             $canSee = &read16(\@decryptedData, 10);
#             $turnNo = &read16(\@decryptedData, 16);
#             $turnNoDisplay =  $turnNo + 2401;
#             $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
#             if ($cleanFiles) {
#               # Hard to find any data here as not much is known of the format
#               # Reset players who can see the minefield
#               ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
#               # reset values for display
#               $canSee = &read16(\@decryptedData, 10);
#             }
#             $LogOutput = "$turnNoDisplay: MineField: $x, $y canSee: " . &getPlayers($canSee);
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
#           #Wormholes
#           } elsif (isWormhole($type)) {
#             $needsCleaning = 1;
#             $x = &read16(\@decryptedData, 2);
#             $y = &read16(\@decryptedData, 4);
#     	      $canSee = &read16(\@decryptedData, 8);
#     	      $beenThrough = &read16(\@decryptedData, 10);
#     	      $targetId = &read16(\@decryptedData, 12) % 4096;   
#             $turnNo = &read16(\@decryptedData, 16);
#             $turnNoDisplay =  $turnNo + 2401;
#             $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
#             if ($cleanFiles) { 
#               # Reset players who can see wormhole
#               ($decryptedData[8], $decryptedData[9]) = &resetPlayers ($Player, &read16(\@decryptedData, 8));
#               # reset values for display
#     	        $canSee = &read16(\@decryptedData, 8);
#               # Reset players who are known to have been through
#               ($decryptedData[10], $decryptedData[11]) = &resetPlayers ($Player, &read16(\@decryptedData, 10));
#               # reset values for display
#               $beenThrough = &read16(\@decryptedData, 10);
#             }
#             $LogOutput = "$turnNoDisplay: Wormhole: $x, $y beenThrough: " . &getPlayers($beenThrough) . ", canSee: " . &getPlayers($canSee);
#             &LogOut(100,"decryptClean: $LogOutput", $LogFile);
#           } elsif (&isMinefield($type)) {
#             # Packet
#             # nothing decoded enough to clean
#           } 
#         }
#       }
#       if ($blockId == 6) { # Player Block
#         my $PRT = $decryptedData[76];
#         if ($PRT == 3) {
#           # Reset the info the CA player can see
#           $needsCleaning = 1;
#           $LogOutput = &showRace(\@decryptedData,$size);
#           &LogOut(400,"decryptClean: $LogOutput", $LogFile);
#           if ($cleanFiles) {   
#             @decryptedData = &resetRace(\@decryptedData,$Player);
#           }
#           $LogOutput = &showRace(\@decryptedData,$size); 
#           &LogOut(400,"decryptClean: $LogOutput", $LogFile);
#         }
#       }
#     # END OF MAGIC
#     #reencrypt the data for output
#     ($encryptedBlock, $seedX, $seedY) = &encryptBlock(\@block, \@decryptedData, $padding, $seedX, $seedY);
#     @encryptedBlock = @ { $encryptedBlock };
#     push @outBytes, @encryptedBlock;
#   }
#   $offset = $offset + (2 + $size); 
#   }
#   return \@outBytes, $needsCleaning;
# }
# 
# sub StarsFix {
#   my ($xFile) = @_; # .x file location includes path   (Uploads)
#   my $needsFixing;
#   # Fixes data coming in from an .x file
#   #  my $fixFiles = 1; # 0, 1, 2: display, clean but don't write, write. See config.pl
#  
#   &LogOut(100,"StarsFix: fixing $xFile", $LogFile);
#   # Read in the binary Stars! file(s), byte by byte
#   my $fileValues;
#   my @fileBytes;
#   open(StarFile, "<$xFile" );
#   binmode(StarFile);
#   while ( read(StarFile, $fileValues, 1)) {
#     push @fileBytes, $fileValues; 
#   }
#   close(StarFile);
#   
#   # Decrypt the data, block by block
#   # So we have choices here. 
#   # BUG: Right now, warning or not, needs fixing or not, let the game save 
#   # It will have fixed for the colonizer bug if necessary which means write it back out.
#   # $needsFixing means write the file back out. 
# 
#   my ($outBytes, $needsFixing, $warning, $fleetList, $fleetMerge, $queueListHST) = &decryptFix(@fileBytes);
#   my @outBytes = @{$outBytes};
#   my %warning = %$warning;
#   
#   # Need to return a string since passing an array through a URL is unlikely to work
#   my $warning = '';
#   foreach my $key (keys %warning) {
#     $warning .= $warning{$key} . ",";
#   }
#   # Output the Stars! file with modified data
#   # Since we don't need to rewrite the file if nothing needs cleaning, let's not (safer)
#   if ($needsFixing) {
#     # Backup the file before we clean it
#     # Because otherwise we can't get back to where we were, as the
#     # backup is pre-turn generation, so random event will change.
#     # BUG: File name is important here, as backups work from the filename
#     #   So do we want these to be .x files?
#     if ($fixFiles > 1) {  # Don't do unless in write mode
#       my $xFilePreFix = 'preFix.' . $xFile;
#   	  &LogOut(300,"StarsFix Backup: $xFile > $xFilePreFix", $LogFile);
#    	  copy($xFile, $xFilePreclean);
#       &LogOut(200," StarsFix: Pushing out $xFile post-fixing", $LogFile);
#       open ( outFile, '>:raw', "$xFile" );
#       for (my $i = 0; $i < @outBytes; $i++) {
#         print outFile $outBytes[$i];
#       }
#       close ( outFile);
#       &LogOut(200," StarsFix: Fixed $xFile", $LogFile);
#     } else { &LogOut(300," StarsFix: Not in Fix mode for $xFile", $LogFile); }
#     return $warning;
#   } else { 
#   	&LogOut(300,"StarsFix: $xFile does not need fixing", $LogFile);
#     return $warning; 
#   }  # BUG: Right now, it will ALWAYS permit the file to save
#      # If we don't want it to save when it shouldn't then this 
#      # return should be a 0;
# }
# 
# sub decryptFix {
#   my (@fileBytes) = @_;
#   my @block;
#   my @data;
#   my ($decryptedData, $encryptedBlock, $padding);
#   my @decryptedData;
#   my @encryptedBlock;
#   my @outBytes;
#   my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
#   my ($random, $seedA, $seedB, $seedX, $seedY);
#   my ($typeId, $size, $data);
#   my $offset = 0; #Start at the beginning of the file
#   my $needsFixing;
#   my ($planetId, $ownerId); 
#   my @queueBlock;
#   my $fleetMergeCount = 0;
#   while ($offset < @fileBytes) {
#     # Get block info and data
#     ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
#     @data = @{ $data }; # The non-header portion of the block
#     @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
#      print "<P>BLOCK typeId: $typeId, Offset: $offset, Size: $size\n"; 
#     if ($debug > 100) { print "BLOCK RAW: Size " . @block . ":\n" . join ("", @block), "\n"; }
#     # FileHeaderBlock, never encrypted
#     if ($typeId == 8) { # File Header Block
#       # We always have this data before getting to block 6, because block 8 is first
#       # If there are two (or more) block 8s, the seeds reset for each block 8
#       ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
#       ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
#       $seedX = $seedA; # Used to reverse the decryption
#       $seedY = $seedB; # Used to reverse the decryption
#       push @outBytes, @block;
#     } else {
#       # Everything else needs to be decrypted
#       ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
#       @decryptedData = @{ $decryptedData };
#       if ( $debug  > 1) { print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; }
#       # WHERE THE MAGIC HAPPENS
#       if ($typeId == 6) { # Player Block
#         my $playerId = $decryptedData[0] & 0xFF; 
#         #print "Player Id: $playerId\n";
#         my $shipDesigns = $decryptedData[1] & 0xFF;  
#         #print " Ship Designs: $shipDesigns\n";
#         my $planets = ($decryptedData[2] & 0xFF) + (($decryptedData[3] & 0x03) << 8); 
#         #print " Planets: $planets\n";
#         my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);  
#         #print " Fleets: $fleets\n";
#         my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4); 
#         #print " Starbase Designs: $starbaseDesigns\n";
#         $player{$playerId}{shipDesigns} = $shipDesigns;
#         $player{$playerId}{planets} = $planets;
#         $player{$playerId}{fleets} = $fleets;
#         $player{$playerId}{starbaseDesigns} = $starbaseDesigns;
#         $designShipTotal +=  $player{$playerId}{shipDesigns};
#         $designBaseTotal +=  $player{$playerId}{starbaseDesigns};
#         $lastPlayer = $playerId; # keep track of the largest known player Id
#       } elsif ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
#         # This always precedes the Production Queue in the .M and .HST file
#         $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
#         print "Planet ID: $planetId\n";
#         $ownerId = ($decryptedData[1] & 0xF8) >> 3;
#         if ($ownerId == 31) { $ownerId = -1; }
#         ### Other stuff after I have the player ID
#         my $flags = &read16(\@decryptedData, 2);
#         my $isHomeworld = ($flags & 0x80) != 0;
# 	      my $isInUseOrRobberBaron = ($flags & 0x04) != 0;
# 	      my $hasEnvironmentInfo = ($flags & 0x02) != 0;
# 	      my $bitWhichIsOffForRemoteMiningAndRobberBaron = ($flags & 0x01) != 0;
# 	      my $weirdBit = ($flags & 0x8000) != 0;
# 	      my $hasRoute = ($flags & 0x4000) != 0;
# 	      my $hasSurfaceMinerals = ($flags & 0x2000) != 0;
# 	      my $hasArtifact = ($flags & 0x1000) != 0;
# 	      my $hasInstallations = ($flags & 0x0800) != 0;
# 	      my $isTerraformed = ($flags & 0x0400) != 0;
# 	      my $hasStarbase = ($flags & 0x0200) != 0;
#         my $index = 4;
#         # More in the block I don't care about right now.       
#       } 
#       # Detect the Cheap Starbase in the producton queue
#       elsif ( $typeId == 28 || $typeId == 29) { # ProductionQueueBlock and ProductionQueueChangeBlock
#         # if not a .x file, we get the player Id from the most recent planet info
#         # because the player info isn't in the ProductionQueueBlock 
#         my $index = 0;
#         my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
#         if ($typeId == 28) { 
#           $Player = $ownerId; 
#           $index = 0;
#        } elsif ($typeId == 29) { # Testing for ProductionQueueChangeBlock
#           # planet ID is only in the ProductonQueueChangeBlock
#           $planetId = &read16(\@decryptedData, 0);
#           $index = 2;
#         } 
#         #$planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
#         print "QUEUE Planet ID: $planetId\n";
#         if ($typeId == 29 ) {
#           # Any change means erasing any old values for this planet
#           foreach my $queueCounter (keys %queueList) {
#             if (exists ($queueList{$queueCounter}{planetId}) ) { 
#                   delete $queueList{$queueCounter}; 
#             }
#           }  
#         }
#         for (my $i=$index; $i <= scalar(@decryptedData) -4; $i=$i+4) {
#           $chunk1 = &read16(\@decryptedData, $i);
#           $chunk2 = &read16(\@decryptedData, $i+2);
#           $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
#           $count = $chunk1 & 0x3FF; # Bottom 10 bits
#           $completePercent = $chunk2 >> 4; #Top 12 bits
#           $itemType = $chunk2 & 0xF; # bottom 4 bits
#           print "Queue: Player: $Player, planetId: $planetId, itemId: $itemId, count: $count, %complete: $completePercent, itemType: $itemType, size: $size\n"; 
#           $queueCounter++;
#           $queueList{$queueCounter}{Player} = $Player;
#           $queueList{$queueCounter}{planetId} = $planetId;
#           $queueList{$queueCounter}{itemId} = $itemId;
#           $queueList{$queueCounter}{count} = $count;
#           $queueList{$queueCounter}{completePercent} = $completePercent;
#           $queueList{$queueCounter}{itemType} = $itemType;
#           $queueList{$queueCounter}{queueSize} = $size;
#           # Store an copy that won't be modified
#           $queueListHST{$queueCounter}= $queueList{$queueCounter};
#         }
#         if ($typeId == 29 && $size == 2) { # Clear Queue 
#           # Need to clear the ProductionQueue array if this is a clear queue action
#           # because we no longer care about what was in this production queue prior
#           # If Cheap Starbase bug, clearing the planet queue fixes it.
#           foreach my $queueCounter (keys %queueList) {
#             if (exists ($queueList{$queueCounter}{planetId}) && $queueList{$queueCounter}{planetId} == $planetId) { 
#               #print "CLEARING queue for planet: $queueList{$queueCounter}{planetId}\n";
#               delete $queueList{$queueCounter}; 
#             }
#           }
#         }
#         # If we changed a queue, check the entire queue for any planets building on the warning
#         # The warning list will be shorter, so start there. 
#         foreach my $warnId (keys %warning) {
#           print "Checking for warning $warnId\n";
#           my $stillBroken = 0;
#           my ($player, $designType, $designNumber, $warningType) = &splitWarnId($warnId); 
#           if ($warningType eq 'cheap') {
#             my $designId = $designNumber + 16;
#             foreach my $queueCounter (keys %queueList) {
#               if ($queueList{$queueCounter}{Player} == $player &&  $queueList{$queueCounter}{itemId} == $designId) {
#                 $stillBroken = 1;
#                 print "Still broken\n";
#               }
#             }
#           }
#           unless ($stillBroken) {
#             if (exists ($warning{$warnId}) && $warningType eq 'cheap') { 
#               print "CLEARING Cheap Starbase warning for $warnId\n";
#               delete $warning{$warnId}; 
#             }
#           }
#         }
#       } 
#       elsif ($typeId == 26 || $typeId == 27) { # Design & Design Change block
#         print "\n\n";
#         my $spacedockOverflow = 0;  #Space Dock Overflow
#         my $crobyLangston = 0; #Spack Dock overflow additional armor
#         if ($typeId == 26 ) { # HST File. 
#           # Find design block Player Id Because the player id isn't in Block 26
#           # The Design blocks are in order, and the number of them for each player are defined in the player block(s). 
#           # And if it seems like a lot of work to ge this info, it is.
#           # Find design block player
#           $designOwner=0;
#           if ($designShipTotalCounter >= $designShipTotal) { # Don't start starbases until the ships are done.
#             while ($designOwner <= 0  && $designBaseTotalCounter < $designBaseTotal && $designBasePlayerId <= $lastPlayer) {
#                if (exists($player{$designBasePlayerId}{starbaseDesigns}) && $designBaseCounter < $player{$designBasePlayerId}{starbaseDesigns}) {
#                   $designBaseCounter++; 
#                   $designBaseTotalCounter++; 
#                   $designOwner = $designBasePlayerId; 
#                   last;
#                } else { 
#                  $designBasePlayerId++; 
#                  $designBaseCounter = 0; 
#                }
#              }
#           } else {
#             while ($designOwner <= 0  && $designShipTotalCounter < $designShipTotal && $designShipPlayerId <= $lastPlayer) {
#                if (exists($player{$designShipPlayerId}{shipDesigns}) && $designShipCounter < $player{$designShipPlayerId}{shipDesigns}) {
#                   $designShipCounter++;
#                   $designShipTotalCounter++;
#                   $designOwner = $designShipPlayerId; 
#                    last;
#                } else { $designShipPlayerId++; $designShipCounter = 0; }
#             }
#           }
#           $Player = $designOwner;
#           print "Design Owner: $designOwner\n";
#         }  
#         print "Player: $Player\n";
#         my $hullId;
#         my $index = 0;
#         if ( $typeId == 27 ) {# for the two extra bytes in a .x file 
#           $index = 2; 
#           print "Design Change.......\n";
#         }   
#         my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
#         $deleteDesign = $decryptedData[0] % 16;
#         if ($deleteDesign == 0) { 
#           $designNumber = $decryptedData[1] % 16; 
#           print "Delete designNumber: $designNumber\n";
#           $isStarbase = ($decryptedData[1] >> 4) % 2; 
#           print "isStarbase: $isStarbase\n";  
#           if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
#           else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber); }  # adding a zero lets us sort on key
#           
#         }
#         # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
#         if ($deleteDesign) { 
#           $isFullDesign =  ($decryptedData[$index] & 0x04); 
#           print "isFullDesign: $isFullDesign\n";
#           $isTransferred = ($decryptedData[$index+1] & 0x80); 
#           print "isTransferred: $isTransferred\n";
#           $isStarbase = ($decryptedData[$index+1] & 0x40);  
#           print "isStarbase: $isStarbase\n";
#           $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; 
#           print "designNumber: $designNumber\n";
#           $hullId = $decryptedData[$index+2] & 0xFF; 
#           print "HullId: $hullId \n";
#           $pic = $decryptedData[$index+3] & 0xFF; 
#           print "pic: $pic\n";  
#           if ($hullId == 29) { $pic = 4*31; }  # No idea why these pics are swapped
#           elsif ($hullId == 31) { $pic = 4*29; }
#           if ($isFullDesign) {
#             # Since there can be a ship and base with the same designId, 
#             # need to be able to keep them separate
#             if ($isStarbase) { $warnId = &zerofy($Player) . '-base-' . &zerofy($designNumber);} # adding a zero lets us sort on key
#             else { $warnId = &zerofy($Player) . '-ship-' . &zerofy($designNumber) ; }  # adding a zero lets us sort on key
#             $armor = &read16(\@decryptedData, $index+4);  
#             print "armor: $armor\n";
#             $armorIndex = $index +4; # used to fix the Space Dock overflow
#             $slotCount = $decryptedData[$index+6] & 0xFF; 
#             print "slotCount: $slotCount\n";  # Actual number of slots
#             $turnDesigned = &read16(\@decryptedData, $index+7); 
#             print "turnDesigned: " . $turnDesigned . "\n";
#             $totalBuilt = &read16(\@decryptedData, $index+9); 
#             print "totalBuilt: $totalBuilt\n";
#             $totalRemaining = &read16(\@decryptedData, $index+13); 
#             print "totalRemaining: $totalRemaining\n";
#             $slotEnd = $index+17+($slotCount*4); 
#             print "slotEnd: $slotEnd\n";
#             $shipNameLength = $decryptedData[$slotEnd];          
#             print "shipNameLength: $shipNameLength  (using nibbles as characters, not bytes)\n";
#             $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
#             $index = 17;  
#             if ($typeId == 27) { $index += 2; } # x files have 2 more bytes
#             my $spaceDockIndex = $index; # used for the Space Dock overflow
#             # Loop through once for each slot
#             my $itemSum = 0; # tracking if all the design slots are empty for the Cheap Starbase bug
#             for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
#               print "$index:\t";
#               $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
#               $index += 2;
#               $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
#               $index++;
#               $itemCount = $decryptedData[$index];
#               $itemSum = $itemSum + $itemCount;
#               my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
#               if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index\n"; }
#               else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index\n";}
# 
#               # Colonizer bug
#               # Ships with a colonization module removed and the slot left empty can still colonise planets
#               # If a colonizer hull is created, and then edited, it's going to put 2 (or more)  entries in the .x file.
#               # so need to filter.
#               if ($itemId == 0 &&  $itemCategory == 4096 && $itemCount == 0) {
#                 # Fixing display for those who don't count from 0.
#                 $err .= '***Colonizer bug detected for player ' . &plusone($Player) . ' in ship design slot ' . &plusone($designNumber) . ": $shipName (in slot " . &plusone($itemSlot) . '). ';
#                 $itemCategory = &read16(\@decryptedData, $index-3);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
#                 print "category: $itemCategory  index: $index\n";
#                 ($decryptedData[$index-3], $decryptedData[$index-2]) = &write16(0); # Category
#                 $needsFixing = 1;
#                 if ($fixFiles > 1) {
#                   $err .= '  Fixed!!! Slot now truly empty.';
#                 } else {$err .= '';}
#                 $warning{$warnId.'-colonizer'} = $err;
#                 print "$index: $warnId: $err\n"; 
#               }
#               # Detect Space Dock Overflow
#               # Don't fix it here because we don't know yet at a slot level what the rest of the slots are
#               if ( $isStarbase && $hullId == 33 && $itemId == 11  && $itemCategory == 8 && $itemCount > 21  && $armor  >= 49518) {  $spacedockOverflow = 1; } 
#               # Check for other items that could be increasing armor
#               if ( $spacedockOverflow ) { if ($itemCategory == 4 && ($itemId == 6 || $itemId == 3)) { $crobyLangston = $itemCount; } }
#               # Step forward for the next slot
#               $index++;
#             }
#             if ($spacedockOverflow) {
#               # Fix Space Dock Armor slot Buffer Overflow with super latanium
#               # If your race has ISB and RS, building a Space Dock with more than 21 SuperLat in the Armor slot 
#               # will result in some sort of error (of massively increased armor)
#               # Rick: I had hoped to fix this by simply rewriting the armor value,
#               # but armor gets recalculated, so resetting the itemCount is the only choice. 
#               $err = '***Spacedock Overflow bug of > 21 SuperLatanium detected for player ' . &plusone($Player) . ' in starbase design slot ' . &plusone($designNumber) . ": $shipName. ";
#               # reset the $itemCount 
#               $decryptedData[$spaceDockIndex+11] = 21; # Armor slot on spacedock
#               # Armor value should be 250 + (1500 * $itemCount) / 2
#               $armor = 250 + (1500 * 21) / 2; # adjust for 21 Super Latanium
#               if ($crobyLangston)  {  $armor += 65 * $crobyLangston; } # add on Croby or Langston armor
#               print "Updated armor value: $armor\n";
#               # reset the final armor value for the spacedock overflow bug
#               ($decryptedData[$armorIndex], $decryptedData[$armorIndex+1]) = &write16($armor);
#               $needsFixing = 1;
#               if ($fixFiles > 1) {
#                 $err .= '  Fixed!!! SuperLatanium set to 21. New armor value: ' . $armor;
#               } else {$err .= '';}
#               $warning{$warnId.'-dock'} = $err;
#               print "$warnId: $err\n";
#             }
#             # if we have a starbase with totally empty slots, we definitely don't have a Cheap Starbase
#             if ($isStarbase && $itemSum == 0) { 
#               $brokenStarbase[$designNumber] = -1; 
#               if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
#                 delete ($warning{$warnId.'-cheap'}); 
#               }
#             }
#           } else { # If it's not a full design
#             $mass = &read16(\@decryptedData, 4); 
#             $slotEnd = 6; 
#             $shipNameLength = $decryptedData[$slotEnd]; 
#             $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
#           }
#           print "shipName: $shipName\n";
#           
#           # Detect the 10th starbase design
#           if ( $isStarbase && $designNumber == 9 && $deleteDesign && $Player > 0 ) {
#             $err = '***Warning: Player ' . &plusone($Player) . ": Starbase ($shipName) in design slot 10 - Potential Crash if Player 1 Fleet 1 refuels when Last Player has a 10th starbase design.";
#             # As I have no fix, no need to flag for fixing
#             print "$warnId: $err\n"; 
#             $warning{$warnId.'-ten'} = $err;
#           } 
#           # Detect the Cheap Starbase exploit    
#           # Editing a starbase under construction at planet(s) with no starbase
#           # Only need to check starbase orders
#           # If the design is deleted we also stop checking 
#           if ($typeId == 27 && $isStarbase && $totalBuilt == 0 && !($brokenStarbase[$designNumber]  < 0) ){ # .x and Starbase
#             my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
#             my $queueCounter;
#             foreach my $queueCounter (sort keys %queueList) {
#               if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber) { # if the item in the queue is a ship design (4)
#                 $err = '***Warning: Cheap Starbase Exploit for player ' . &plusone($Player) . '. Do not edit a starbase under construction (slot ' . &plusone($designNumber) . ": $shipName) !\n";
#                 $brokenStarbase[$designNumber] = 1; 
#                 $index = 19;  
#                 # Loop through each slot, setting the slot to 0
#                 for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
#                   ($decryptedData[$index], $decryptedData[$index+1]) = &write16(0);
#                   $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
#                   $index += 2;
#                   $decryptedData[$index] = 0;
#                   $itemId = &read8($decryptedData[$index]); # Use current value of index, and increment by 1
#                   $index++;
#                   $decryptedData[$index] = 0;
#                   $itemCount = $decryptedData[$index];
#                   my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
#                   if ( $category_str && $item_str ) { print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount, index: $index \n"; }
#                   else { print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount, index: $index \n";}
#                   $index++;
#                 }
#                 $needsFixing = 1;
#                 if ($fixFiles > 1) {
#                   $err .= '  Fixed!!! Starbase design ' . &plusone($designNumber) . ' reset to blank.';
#                 } else {$err .= ' '; }
#                 $warning{$warnId.'-cheap'} = $err;
#                 print "$warnId: $err\n";
#               }
#             }
#           }
#         } 
#         # For the Colonizer bug & Spacedock overflow, track whether the design was 
#         # created, but remove the warning if the design was subsequently changed (inc. deleted)
#         # (because a later .x file entry modified this designnumber)
#         # Store the error in a hash so it's only one / ship / file
#         # Will handle for multi-turn .m files.
#         if (!$err && $warning{$warnId.'-dock'}) { 
#           delete( $warning{$warnId.'-dock'} ); 
#           print "Spacedock Player Fix Noted for $warnId\n";
#         }
#         if (!$err && $warning{$warnId.'-colonizer'}) { 
#           delete( $warning{$warnId.'-colonizer'} ); 
#           print "Colonizer/Spacedock Player Fix Noted for $warnId\n";
#         }
#         # If the 10th starbase has been deleted, clear the warning
#         if ( $isStarbase && $designNumber == 9 && $deleteDesign == 0 && $Player > 0 ){
#           if ($warning{$warnId.'-ten'}) { 
#             delete ($warning{$warnId.'-ten'}); 
#             print "10th Starbase Player Fix Noted for $warnId\n";
#           }
#         }
#         # If the edited Cheap Starbase design is deleted, 
#         # delete the queue entries as we no longer care for future checks on this design.
#         my $queueDesignNumber = 16 + $designNumber; # the queue starts starbase design numbers after the ship design numbers
#         if ( ($isStarbase && $deleteDesign == 0) ) {
#           # Determine which starbase
#           foreach my $queueCounter (sort keys %queueList) {
#             if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber ) { # if the item in the queue is a ship design (4)
#               if (exists ($queueList{$queueCounter})) { 
#                 delete $queueList{$queueCounter}; 
#               }
#             }
#           }
#           if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
#             delete ($warning{$warnId.'-cheap'}); 
#           }
#         }
#         # If the queue was cleared for planet, future queue no longer a problem
#         foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
#           if ( $queueList{$queueCounter}{queueSize} == 2 ) {
#             if (exists ($queueList{$queueCounter})) { 
#               delete $queueList{$queueCounter}; 
#             }
#           }
#         }
#         # Now that the queues are cleared up, see if we still have a Cheap Starbase problem
#         my $stillBroken = 0;   
#         foreach my $queueCounter (keys %queueList) { # Loop through all the items in the queue
#           if ($queueList{$queueCounter}{Player} == $Player && $queueList{$queueCounter}{itemType} == 4 && $queueList{$queueCounter}{itemId} == $queueDesignNumber && $queueList{$queueCounter}{completePercent} > 0) { # if the item in the queue is a ship design (4)
#              $stillBroken = 1;
#           }
#         }
#         if ($stillBroken) {
#           $brokenStarbase[$designNumber] = 1;
#         } else {
#           if ($brokenStarbase[$designNumber] == 1) { print "Cheap Starbase Player Fix Noted\n"; }
#           $brokenStarbase[$designNumber] = -1;
#           if (exists ($warning{$warnId.'-cheap'}) && $warning{$warnId.'-cheap'}) { 
#             delete ($warning{$warnId.'-cheap'}); 
#           }
#         }
#       } elsif ($typeId == 30) {  # BattlePlan block
#         my ($planPlayerId, $planNumber, $primaryTarget,$secondaryTarget,$tactic,$attackWho, $dumpCargo, $planNameLength, $planName);
#         my @target = qw(None Any Starbase Armed Bombers Unarmed Fuel Freighters);
#         my @tactic = qw(Disengage ifChallenged minToSelf maxNet maxRatio Max);
#         my @attackWho = qw(Nobody Enemies Neutral/Enemies Everyone 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16);
#         my $err = '';
#         # Player 0 Default: 0 4 19 2 5 179 45 113 222 90
#         $planPlayerId = ($decryptedData[0] >> 0) & 0x0F; 
#         print "Plan: Player:$planPlayerId\t";  # 4 bits starting at bit 0.
#         $planNumber = ($decryptedData[0] >> 4) & 0x0F; 
#         print "Plan:$planNumber\t";
#         $tactic = ($decryptedData[1]) & 0x0F; 
#         print "Tactic:" . $tactic[$tactic] . "($tactic)\t";
#         $dumpCargo = ($decryptedData[1] >> 7) & 0x01; 
#         print "Dump:$dumpCargo\t"; # 1 bit  starting at bit 7.
#         $primaryTarget = ($decryptedData[2] >> 0) & 0x0F; 
#         print "Pri:" . $target[$primaryTarget] . "($primaryTarget)\t"; 
#         $secondaryTarget = ($decryptedData[2] >> 4) & 0x0F; 
#         print "Sec:" . $target[$secondaryTarget] . "($secondaryTarget)\t"; 
#         $attackWho = $decryptedData[3]; 
#         print "Attack:". $attackWho[$attackWho] . "($attackWho)\t";
#         $planNameLength = $decryptedData[4]; 
#         #print "planNameLength: $planNameLength  (using nibbles as characters, not bytes)\n";
#         $planName = &decodeBytesForStarsString(@decryptedData[4..4+$planNameLength]);  
#         print "Name: $planName\t";
#         print "\n";
#         #print "$planPlayerId,$primaryTarget,$secondaryTarget,$tactic,$attackWho,$dumpCargo\n";
#         # Detect the BattlePlan Friendly Fire bug
#         print "<P>Prewarn\n";
#         $warnId = &zerofy($planPlayerId) . '-plan-' . &zerofy($planNumber);
#         print "<P>post warn\n";
#         print "<P>($attackWho) > 3 && $planNumber == 0\n";
#         if (($attackWho) > 3 && $planNumber == 0) { 
#            # Fixing display for those who don't count from 0.
#            print "<P>PRe Plus\n";
#            $err .= '***Friendly Fire bug detected for player ' . &plusone($planPlayerId) .  " in Default battle plan against " . &attackWho($attackWho) . '.';
#            $decryptedData[3] = 2;
#            $needsFixing = 1;
#            if ($fixFiles > 1) {
#              $err .= ' Fixed!!! Attack Who reset to Neutral/Enemy.';
#            } else {$err .= '';}
#            print "$warnId: $err\n"; 
#            
#            $warning{$warnId.'-friendly'} = $err;
#         }
#         # If a subsequent Default battle plan fixes it, clear the warning
#         print "<P>prdelete\n";
#         if (!$err && $warning{$warnId.'-friendly'}) { 
#           delete( $warning{$warnId.'-friendly'} ); 
#           print "Friendly Fire Player Fix Noted for $warnId\n";
#         }
#       }
#       # END OF MAGIC
#       print "<P>MAGIC OVER\n";
#       # reencrypt the data for output
#         ($encryptedBlock, $seedX, $seedY) = &encryptBlock( \@block, \@decryptedData, $padding, $seedX, $seedY);
#         @encryptedBlock = @ { $encryptedBlock };
#         push @outBytes, @encryptedBlock;
#     }
#     $offset = $offset + (2 + $size); 
#   }
#   print "<P>RETURN\n";
#   return \@outBytes, $needsFixing, \%warning, \%fleetList, \@fleetMerge, \%queueListHST;
# }
# 
# 
# sub StarsQueue {
# # Generate a queue file (used by Fix for Cheap Starbase detection)
#   my ($GameDir, $GameFile, $turn) = @_;
#   print "GameDir: $GameDir\n";
#   # Read in the .HST File
#   my $filename = $GameDir . '\\' . $GameFile . '.HST';
#   open(StarFile, "<$filename");
#   binmode(StarFile);
#   while (read(StarFile, $FileValues, 1)) {
#     push @fileBytes, $FileValues; 
#   }
#   close(StarFile);
#   # Decrypt the data, block by block
#   my $queueList = &decryptQueue(@fileBytes);
#   my %queueList = %$queueList;
#   # write out the unmodified queue list
#   my $queueFile = $GameDir . '\\' . $GameFile . '.HST' . ".$turn" . '.queue';
#   print "Filename : $filename, queueFile: $queueFile\n";
#   if (-d $GameDir) { # Check to make sure we're putting the .queue in the right place
#     open (QUEUEFILE, ">$queueFile");
#     foreach my $queueCounter (keys %queueList) {
#       print QUEUEFILE "$queueList{$queueCounter}{Player},$queueList{$queueCounter}{planetId},$queueList{$queueCounter}{itemId},$queueList{$queueCounter}{count},$queueList{$queueCounter}{completePercent},$queueList{$queueCounter}{itemType},$queueList{$queueCounter}{queueSize}\n";
#     }
#     close QUEUEFILE;
#     &LogOut(100, "Done writing out $queueFile", $LogFile)
#   } else { &LogOut (0,"StarsQueue: Directory $GameDir Missing for $queueDir", $ErrorLog); }
# }
# 
# sub decryptQueue {
#   my (@fileBytes) = @_;
#   my @block;
#   my @data;
#   my ($decryptedData, $encryptedBlock, $padding);
#   my @decryptedData;
#   my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic);
#   my ($random, $seedA, $seedB, $seedX, $seedY);
#   my ($typeId, $size, $data);
#   my $offset = 0; #Start at the beginning of the file
#   my ($planetId, $ownerId); 
#   my %queueList;
#   my $queueCounter=0;
#   while ($offset < @fileBytes) {
#     # Get block info and data
#     ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
#     @data = @{ $data }; # The non-header portion of the block
#     @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question
#     # FileHeaderBlock, never encrypted
#     if ($typeId == 8) { # File Header Block
#       # We always have this data before getting to block 6, because block 8 is first
#       # If there are two (or more) block 8s, the seeds reset for each block 8
#       ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic) = &getFileHeaderBlock(\@block);
#       ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
#       $seedX = $seedA; # Used to reverse the decryption
#       $seedY = $seedB; # Used to reverse the decryption
#       push @outBytes, @block;
#     } else {
#       # Everything else needs to be decrypted
#       ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
#       @decryptedData = @{ $decryptedData };
#       #print "\nBLOCK typeId: $typeId, Offset: $offset, Size: $size\t"; 
#       #print "DATA DECRYPTED:" . join (" ", @decryptedData), "\n"; 
#       # WHERE THE MAGIC HAPPENS
#       if ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
#         # This always precedes the Production Queue in the .M and .HST file
#         $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
#         $ownerId = ($decryptedData[1] & 0xF8) >> 3;
#         if ($ownerId == 31) { $ownerId = -1; }
#       } 
#       # Detect the Cheap Starbase in the producton queue
#       elsif ( $typeId == 28 && $ownerId >= 0 ) { # ProductionQueueBlock from owned planets
#         # if not a .x file, we get the player Id from the most recent planet info
#         # because the player info isn't in the ProductionQueueBlock 
#         my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
#         $Player = $ownerId; 
#         for (my $i=0; $i <= scalar(@decryptedData) -4; $i=$i+4) {
#           $chunk1 = &read16(\@decryptedData, $i);
#           $chunk2 = &read16(\@decryptedData, $i+2);
#           $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
#           $count = $chunk1 & 0x3FF; # Bottom 10 bits
#           $completePercent = $chunk2 >> 4; #Top 12 bits
#           $itemType = $chunk2 & 0xF; # bottom 4 bits
#           $queueCounter++;
#           $queueList{$queueCounter}{Player} = $Player;
#           $queueList{$queueCounter}{planetId} = $planetId;
#           $queueList{$queueCounter}{itemId} = $itemId;
#           $queueList{$queueCounter}{count} = $count;
#           $queueList{$queueCounter}{completePercent} = $completePercent;
#           $queueList{$queueCounter}{itemType} = $itemType;
#           $queueList{$queueCounter}{queueSize} = $size;
#         }
#       } 
#       # END OF MAGIC
#     }
#     $offset = $offset + (2 + $size); 
#   }
#   return \%queueList;
# }
# 
# sub plusone{
# # Increment the value of a number as one for display to end users
# # (who problably don't count from 0)
#   my ($val) = @_;
#   $val++;
#   return $val;
# } 
# 
# sub zerofy {
# # make a 1 digit number 2 digits
#   my ($val) = @_;
#   if ($val < 10  && $val >=0 ) { return "0" . $val; }
#   else { return $val; } 
# }
# 
# sub splitWarnId {
#   # I probably should make this another hash of hashes, but it would mean redesigning the warnId... again.
# 	my ($warnId)  = @_;
# 	my ($player, $designType, $designNumber, $warningType) = split ('-',$warnId);
# 	$player = $player *1; # deZerofy
# 	$designNumber = $designNumber * 1; # deZerofy
# 	return ($player, $designType, $designNumber, $warningType);
# }
# 
# sub attackWho {
#    my ($value) = @_;
#    #Nobody, Enemies, Neutral/Enemies, Everyone, [Players] 
#    my @category = qw(Nobody Enemies Neutral/Enemies Everyone);
#    if ($value > 3) { my $player = $value -4; return "Player$player"; }
#    else { return $category[$value]; }
# }
# 
# sub showCategory {
#   my ($category, $item) = @_;
#   my @category;
#   my %item;
# #             Empty = 0,
# #             Engine = 1,
# #             Scanners = 2,
# #             Shields = 4,
# #             Armor = 8,
# #             BeamWeapon = 0x10,
# #             Torpedo = 0x20
# #             Bomb = 0x40,
# #             MiningRobot = 0x80,
# #             MineLayer = 0x100,
# #             Orbital = 0x200,
# #             Planetary = 0x400,
# #             Electrical = 0x800,
# #             Mechanical = 0x1000,
# 
#   $category[0] = 'Empty';
#   $category[1] = 'Engine';
#   $category[2] = 'Scanners';
#   $category[4] = 'Shields';
#   $category[8] = 'Armor';
#   $category[16] = 'BeamWeapon';
#   $category[32] = 'Torpedo';
#   $category[64] = 'Bomb';
#   $category[128] = 'MiningRobot';
#   $category[256] = 'MineLayer';
#   $category[512] = 'Orbital';
#   $category[1024] = 'Planetary'; # Assumed since it appears to be the only missing one
#   $category[2048] = 'Electrical';
#   $category[4096] = 'Mechanical';
#   $category[6144] = 'Orbital Or Electrical';
# 
#   $item{'0'} =  [ qw ( empty ) ]; 
#   $item{'1'} =  [ qw ( SettlerDelight Jump5 Mizer Hump6 Legs7 Alpha8 Trans9 Inter10 Enigma Trans10 NHRS Sub Trans TransSuper TransMizer Galaxy ) ];
#   $item{'2'} =  [ qw ( Bat Rhino Mole DNA Possum PickPocket Chameleon Ferret Dolphin Gazelle RNA Cheetah Elephant Eagle Robber Peerless) ];
#   $item{'4'} =  [ qw ( Mole Cow Wolverine Croby Shadow Bear Langston Gorilla Elephant Complete ) ];
#   $item{'8'} =  [ qw ( Tritanium Crobmium CarbonicArmor Strobnium OrganicArmor Kelarium FieldedKelarium DepletedNeutronium Neutronium MegaPoly Valanium Superlatanium ) ];
#   $item{'16'} = [ qw ( Laser X-Ray MiniGun YakimoraPhaser Blackjack Phaser PulsedSapper ColloidalPhaser GatlingGun MiniBlaster Bludgeon MarkIVBlaster PhasedSapper HeavyBlaster GatlingNeutrino MyopicDisruptor Blunderbuss Disruptor MultiContainedMunition SyncroSapper MegaDisruptor BigMuthaCannon StreamingPulverizer Anti-MatterPulverizer ) ]; 
#   $item{'32'} = [ qw ( Alpha Beta Delta Epsilon Rho Upsilon Omega AntiMatter Jihad Juggernaut Doomsday Armageddon ) ];
#   $item{'64'} = [ qw ( LadyFinger BlackCat M-70 M-80 Cherry LBU-17 LBU-32 LBU-74 HushaBoom Retro Smart Neutron EnrichedNeutron Peerless Annihilator ) ];
#   $item{'128'} = [ qw ( Midget Mini Miner Maxi Super Ultra Orbital ) ]; 
#   $item{'256'} = [ qw ( Mine40 Mine50 Mine80 Mine130 Heavy50 Heavy110 Heavy200 Speed20 Speed30 Speed50 ) ];
#   $item{'512'} = [ qw ( SG250 SG300 SG600 SG500 SGany SG800  SGanyany Mass5 Mass6 Mass7 Mass8 Mass9 Mass10 Mass11 Mass12 Mass13 ) ];
#   $item{'1024'} = [ qw ( Viewer50 Viewer90 Viewer150 Viewer220 Viewer280 Viewer320 Snooper400 Snooper500 Snooper620 ) ];
#   $item{'2048'} = [ qw ( TransportCloak StealthCloak Super-StealthCloak Ultra-StealthCloak MultiFunction BattleComputer BattleSuperComputer BattleNexus Jammer10 Jammer20 Jammer30 Jammer50 EnergyCapacitor FluxCapacitor EnergyDampener TachyonDetector Anti-matterGenerator) ];
#   $item{'4096'} = [ qw ( Colonization OrbitalCon Cargo SuperCargo MultiCargo Fuel SuperFuel ManeuveringJet Overthruster BeamDeflector ) ];
#   $item{'6194'} = [ qw ( empty ) ];
# 
#   return ($category[$category],$item{$category}[$item]);
# }

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