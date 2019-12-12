#!/usr/bin/perl
# page.pl
# Formerly a RallyPt File
# Core page generation for TotalHost
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

use CGI qw(:standard);
use CGI::Session;
CGI::Session->name('TotalHost');
$CGI::POST_MAX=1024 * 25;  # max 25K posts
use Win32::ODBC;
use TotalHost;
use StarStat; 
do 'config.pl';

my %in;
my %GameValues;
# The _new_ way (from like 10 years ago)
# Clean all incoming /submitted values
foreach my $field (param()) { $in{$field} = &clean(param($field)); }

# if ($ARGV[0]) { 
# 	$in{'GameFile'} = 'alpha';
# 	$sql = qq|SELECT Games.GameFile, Games.GameName, User.User_Login, Games.HostName, GameUsers.PlayerID, GameUsers.DelaysLeft, GameUsers.PlayerStatus, [_PlayerStatus].PlayerStatus_txt FROM [User] INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$in{'GameFile'}\'));|;
# 	&show_player_status($in{'GameFile'},$sql); 
# 	die;
# }

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
$cookie = $cgi->cookie(TotalHost);
&validate($cgi,$session);

print $cgi->header();
# Get the User ID and User Login from the Cookie.
$id = $session->param("userid");
$userlogin = $session->param("userlogin");

&html_top($cgi,$session, $note);

print "<P>\n";

# Print out the debug info for the base/admin user
if (($id == 1 || $id == 6) && $debug) { 
	print qq|<table><tr><td width="$lp_width">lp = $in{'lp'}</td><td width="500">cp=$in{'cp'}</td><td align=center>tp = $in{'tp'}</td><td width="$rp_width" align=right>rp=$in{'rp'}</td></tr></table>\n|;
}

# Set up various defaults for the panels
if ($id && (!($in{'lp'}))) { $in{'lp'} = 'home';}
if ((!($in{'cp'}))) { $in{'cp'} = 'welcome';}
#if ($in{'lp'} eq 'home') { $in{'rp'} = 'games';} 
#if ($in{'lp'} eq 'profile') { $in{'rp'} = 'my_games';} 

# See the debug after the various defaults have been set
if ($id == 1 && $debug) { 
	print qq|<table><tr><td width="$lp_width">lp = $in{'lp'}</td><td width="500">cp=$in{'cp'}</td><td align=center>tp = $in{'tp'}</td><td width="$rp_width" align=right>rp=$in{'rp'}</td></tr></table>\n|;
	print qq|<hr>\n|;
}

### Print results in a top panel
# Used for debug
if ($in{'tp'} eq 'xxx') {
} else { # do nothing
}

#### Left Panel
if ($in{'lp'} eq 'profile') { 
%menu_left = 	(
 				"4Change Password" 		=> "$Location_Scripts/page.pl?lp=profile&cp=edit_password",
 				"1My Profile" 			=> "$Location_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games",
 				"2My Games" 			=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
 				"3My Races" 			=> "$Location_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races",
 				);
} elsif ($in{'lp'} eq 'profile_game') { 
%menu_left = &lp_list_games($id);
# %menu_left = 	(
# # 				"0Games_" 			=> "",
#  				"1My Games" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
#  #				"2My Profile" 	=> "$Location_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games",
# # 				"2XInvite People"	=> "",
# # 				"2Create Game"	=> "",
#  				);
} elsif ($in{'lp'} eq 'profile_race') { 
%menu_left = 	(
 				"1My Races" 	=> "$Location_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races",
 				"0My Profile" 	=> "$Location_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games",
 				"2Upload Race"	=> "$Location_Scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races",
 				);
} elsif ($in{'lp'} eq 'game') { 
%menu_left = 	(
 				"0My Games" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
 				"1Completed Games" 	=> "$Location_Scripts/page.pl?lp=game&cp=welcome&rp=games_complete",
 				"1Games In Progress" 	=> "$Location_Scripts/page.pl?lp=game&cp=welcome&rp=games",
 				"1New Games" 	=> "$Location_Scripts/page.pl?lp=game&cp=show_new&rp=games_new",
# 				"1Replacement Players" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=welcome&rp=games_replacement",
# 				"2XInvite People"	=> "",
 				"2Create Game"	=> "$Location_Scripts/page.pl?lp=game&cp=create_game&rp=",
 				);
} else { 
%menu_left = 	(
 				"1Log In" 			=> "$Location_Scripts/index.pl?cp=login_page",
 				"2Sign Up" 			=> "$Location_Scripts/index.pl?cp=create",
 				"3Reset Password" 	=> "$Location_Scripts/index.pl?cp=reset_user",
 				"4Logout" 			=> "$Location_Scripts/index.pl?cp=logout",
 				"5Erase" 			=> "$Location_Scripts/index.pl?cp=logoutfull",
 				);
}

&html_left(\%menu_left);
print qq|</td>\n|;

# Set the value for any displayed welcome pages.
my $welcome = $File_WWWRoot . '/' . 'welcome.htm';

#### Center Panel
if ($in{'cp'} eq 'add_game_friend') { &add_game_friend;
} elsif ($in{'cp'} eq 'accept_game') { &accept_game;
} elsif ($in{'cp'} eq 'invite_game') { &invite_game; 
} elsif ($in{'cp'} eq 'invite_friends') { &invite_friends; 
} elsif ($in{'cp'} eq 'accept_friend_invite') { &accept_friend_invite; 
} elsif ($in{'cp'} eq 'add_friend') { &add_friend; 
} elsif ($in{'cp'} eq 'display_invitations_detail') { 
	print "<td>\n"; &display_invitations_detail; print "</td>\n";
# } elsif ($in{'cp'} eq 'display_game_detail') { 
# 	$sql = qq|SELECT ;|; &display_game_detail($sql); 
} elsif ($in{'cp'} eq 'edit_profile') {  
	$sql = qq|SELECT * FROM [User] WHERE ((User_ID)=$id);|;
	&edit_profile($sql);
} elsif ($in{'cp'} eq 'show_profile') { 
	print "<td>";
	$sql = qq|SELECT * FROM _UserStatus RIGHT JOIN [User] ON [_UserStatus].User_Status = User.User_Status WHERE (((User.User_ID)=$id));|;
	&show_profile($sql);
	print "</td>";
} elsif ($in{'cp'} eq 'update_profile') { &update_profile;
} elsif ($in{'cp'} eq 'edit_password') { &edit_password;
} elsif ($in{'cp'} eq 'change_password') { &change_password;
} elsif ($in{'cp'} eq 'create_game') { 
	&edit_game('create'); 
} elsif ($in{'cp'} eq 'Edit Game') { 
	&edit_game('edit'); 
} elsif ($in{'cp'} eq 'Update Game') { 
	print "<td>"; 
	&update_game($in{'GameFile'}); 
	# send the user back to the right page, either new game or otherwise
#	if ($in{'GameStatus'} ne 7 && $in{'GameStatus'} ne 6) { &show_game($in{'GameFile'});}
#	else { &show_game($in{'GameFile'}); }
  &display_warning;
	if ($in{'GameStatus'} eq '7' || $in{'GameStatus'} eq '6') { &show_game($in{'GameFile'});}
	else { &show_game($in{'GameFile'}); }
	print "</td>";
} elsif ($in{'cp'} eq 'Join Game') {
	print "<td>"; 
	&process_join_game($in{'GameFile'}, $in{'RaceFile'}); 	
	# Display the Game Page
	print &show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Leave Game') {
	print "<td>";
	&process_game_leave($in{'GameFile'}, $in{'PlayerID'});
	&show_game($in{'GameFile'});
	print "</td>";
} elsif ($in{'cp'} eq 'Create Game') { 
	print "<td>"; 
#1800312	$GameFile = &update_game($in{'GameFile'}); 
	$GameFile = &update_game(); # Modified to always create a random game file
	unless ($GameFile eq "CREATE FAILED") { 
    &create_game_size($GameFile, $in{'GameName'}); # update_game either passes along GameFile, or creates a hash to use as the GameFile
  }
	print "</td>";
} elsif ($in{'cp'} eq 'create_game_size') { 
	print "<td>"; 
	$GameFile = $in{'GameFile'}; 
	# update_game either passes along GameFile, or creates a hash to use as the GameFile	
	&create_game_size($GameFile, $in{'GameName'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Create DEF File') { 
	print "<td>"; 
	&create_game_def($in{'GameFile'});
	&show_game($in{'GameFile'});
	print "</td>";
} elsif ($in{'cp'} eq 'Lock Game') { 
	# Option won't present with no players 
	print "<td>"; 	
	&process_game_status($in{'GameFile'}, $sql, 'Lock'); 
	&show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Unlock Game') { 
	print "<td>"; 	
	&process_game_status($in{'GameFile'}, $sql, 'Unlocked'); 
	&show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Restart Game') { 
	print "<td>"; 	
	&process_game_status($in{'GameFile'}, $sql, 'Restart'); 
  &display_warning;
	&show_game($in{'GameFile'}); 
	print "</td>";
#180306 Not used anywhere else
#} elsif ($in{'cp'} eq 'Launch Game') { 
#	print "<td>"; 
#	# If the game fails to launch, don't display the game status, show the new game.
#	if (&process_game_launch($in{'GameFile'})) { &show_game($in{'GameFile'}); }
#	else { &show_game($in{'GameFile'})}
#	print "</td>";
} elsif ($in{'cp'} eq 'DELETE') { &delete_game($in{'GameFile'}); 
} elsif ($in{'cp'} eq 'show_first_game') { 
	print "<td>"; 	
	my $sql = qq|SELECT Games.*, Games.GameStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4) Or (Games.GameStatus)=7 Or (Games.GameStatus)=0  );|;
	my %First;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %First = $db->DataHash(); }	
	else { &LogOut(10,"ERROR: Finding show_first_game",$ErrorLog); }
	&DB_Close($db);
	# If game(s) found, display
	if ($First{'GameFile'}) {
    unless ($First{'GameStatus'} == 7) { &show_game($First{'GameFile'});}
    else { &show_game($First{'GameFile'}); }
	} else {	print "No games found. Are you in any games?\n"; }
	print "</td>";
} elsif ($in{'cp'} eq 'show_new') { 
	print "<td>"; 	
	my $sql = qq|SELECT * FROM Games WHERE GameStatus=7 OR GameStatus=0;|;
	&show_new_games($sql); 
	print "</td>";
} elsif ($in{'cp'} eq 'show_game') { 
 	if ($in{'GameFile'}) { print "<td>"; &show_game($in{'GameFile'}); print "</td>"; }
} elsif ($in{'cp'} eq 'Refresh') { 
	if ($in{'GameFile'}) {  print "<td>"; &show_game($in{'GameFile'}); print "</td>"; }
  $in{'rp'} = 'show_news';
} elsif ($in{'cp'} eq 'show_games') {
#	$sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login GROUP BY Games.GameFile, Games.GameName, Games.GameStatus, User.User_ID HAVING User.User_ID=| . $session->param("userid") . qq|;|;
	$sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName FROM Games ORDER BY Games.GameStatus;|;
	print "<td>"; &list_games($sql, 'All Games'); print "</td>";
} elsif ($in{'cp'} eq 'show_games_inprogress') {
	$sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE GameUsers.User_Login='$userlogin' AND Games.GameStatus>1 AND Games.GameStatus<6 ORDER BY Games.GameStatus;|;
	print "<td>"; &list_games($sql, 'My Games In Progress'); print "</td>";
} elsif ($in{'cp'} eq 'show_my_new') { 
	print "<td>"; &show_my_new(); print "</td>";
} elsif ($in{'cp'} eq 'upload_race') { &upload_race; 
} elsif ($in{'cp'} eq 'show_race') { 
	print "<td>"; 	
	$sql = qq|SELECT * FROM Races WHERE RaceFile = \'$in{'RaceFile'}\' AND User_Login = \'| . $session->param("userlogin") . qq|\';|;
	&show_race($sql); 
	print "</td>"; 
} elsif ($in{'cp'} eq 'show_first_race') {
	print "<td>"; 	
	$sql = qq|SELECT * FROM Races WHERE User_Login = \'| . $session->param("userlogin") . qq|\';|;
	my %First;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %First = $db->DataHash(); }	
	else { &LogOut(10,"ERROR: Finding show_first_race",$ErrorLog); }
	&DB_Close($db);
	$sql = qq|SELECT * FROM Races WHERE RaceFile = \'$First{'RaceFile'}\' AND User_Login = \'| . $session->param("userlogin") . qq|\';|;
	&show_race($sql); 
	print "</td>"; 
} elsif ($in{'cp'} eq 'process_race') { 
	print "<td>";
	print "$in{'status'}";
#	else { print "Processed Race File $in{'File'} for " . $session->param("userlogin"); }
	print "</td>";
} elsif ($in{'cp'} eq 'delete_race') {
	print "<td>"; &delete_race($in{'RaceFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Restore Game') {
		print "<td>\n"; &show_restore($in{'GameFile'}); print "</td>\n";
} elsif ($in{'cp'} eq 'Process Restore') {
		print "<td>\n"; 
    &process_restore($in{'GameFile'},$in{'restore_year'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>\n";
} elsif ($in{'cp'} eq 'Report News') {	
		&submit_news($in{'GameFile'});
} elsif ($in{'cp'} eq 'delete_news') {	
		&delete_news($in{'GameFile'});
} elsif ($in{'cp'} eq 'Submit Article') {
		&process_news($in{'GameFile'}, $in{'NewsPaper'}); 
		if ($in{'GameFile'}) { print "<td>"; &display_warning; &show_game($in{'GameFile'}); print "</td>";}
} elsif ($in{'cp'} eq 'Player Status') { 
		$sql = qq|SELECT Games.GameFile, Games.GameName, User.User_Login, User.User_File, Games.HostName, Games.AnonPlayer, GameUsers.PlayerID, GameUsers.DelaysLeft, GameUsers.PlayerStatus, [_PlayerStatus].PlayerStatus_txt FROM [User] INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$in{'GameFile'}\')) ORDER BY GameUsers.PlayerID;|;
		print "<td>\n"; &show_player_status($in{'GameFile'},$sql); print "</td>\n";
} elsif ($in{'cp'} eq 'Update Player') { 
		print "<td>\n"; 
    &process_player_status($in{'GameFile'}, $in{'User_File'}, $in{'PlayerStatus'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>\n";
} elsif ($in{'cp'} eq 'Pause Game') {
		print "<td>"; 
    &process_game_status($in{'GameFile'}, $sql, 'Pause'); 
    &display_warning;
    &show_game($in{'GameFile'}); 
    print "</td>";
} elsif ($in{'cp'} eq 'UnPause Game') { # unpause the game and reset then the next turn is due
		# Get the time data from the game to determine when the next turn is due
		# BUG: I believe will be broken when you use across DST zones.
		print "<td>"; 
    &process_game_status($in{'GameFile'}, $sql, 'UnPause');
    &display_warning; 
    &show_game($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Delay Game') {
		print "<td>"; &show_delay($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Process Delay') {
		print "<td>"; 
    &process_delay($in{'GameFile'}, $in{'delay_turns'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>"; 
} elsif (($in{'cp'} eq 'Go Inactive') || ($in{'cp'} eq 'Go Active')) {
	print "<td>\n";
	if ($in{'cp'} eq 'Go Inactive') { $playerstatus = 2; $playerstate = 'Inactive';}
	elsif ($in{'cp'} eq 'Go Active') { $playerstatus = 1; $playerstate = 'Active'; } 
  &process_player_status($in{'GameFile'}, $in{'User_File'}, $playerstate); 
  &display_warning;
	&show_game($in{'GameFile'});
	print "</td>\n";
} elsif ($in{'cp'} eq 'End Game') {
		print "<td>"; 
    &process_game_status($in{'GameFile'}, $sql, 'Ended'); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Start Game') {
#		$sql = qq|UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$in{'GameFile'}\' AND HostName=\'$userlogin\';|;
		print "<td>"; 
#    &process_game_launch($in{'GameFile'}); 
#    &show_game($in{'GameFile'}); 
#    print "</td>";
    #180306
    if (&process_game_launch($in{'GameFile'})) { &show_game($in{'GameFile'}); }
	  else { &show_game($in{'GameFile'})}
    print "</td>";
 } elsif ($in{'cp'} eq 'Force Gen') {
		print "<td>"; &submit_forcegen($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Email Players') {
		print "<td>"; &show_email($in{'GameFile'},$in{'GameName'}); print "</td>";
} elsif (($in{'cp'} eq 'process_email') || $in{'cp'} eq 'Send Email') {
		print "<td>"; 
    &process_email($in{'GameFile'}, $in{'Message'},$in{'GameName'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'force_gen') {
		print "<td>"; 
    &process_forcegen($in{'Turns'},$in{'GameFile'}, $userlogin, $in{'EmailPlayers'}, $in{'decrementforcegentimes'});
    &display_warning; 
    &show_game($in{'GameFile'}); 
    print "</td>";
} elsif ($in{'cp'} eq 'Remove PWD') {
		print "<td>"; 
    &display_warning; 
    &show_game($in{'GameFile'});
    print "</td>";
} elsif ($in{'cp'} eq 'Reset Password') {
		print "<td>"; 
    &process_remove_password($in{'GameFile'}, $in{'PlayerID'});
    &display_warning; 
    &show_game($in{'GameFile'});
    print "</td>";
} elsif ($in{'cp'} eq 'DEF File') {
		print "<td>"; &create_game_size($in{'GameFile'}, $in{'GameName'}); print "</td>";
} elsif ($in{'cp'} eq 'Delete Game') {
		print "<td>"; &delete_confirm($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'welcome') {
		&show_html($welcome);
} else {	
	print "<td>\n"; 
	$in{'Type'} = 'Table';
	print "<td>";
  print "<P>My Game Error? CP not found";	
  while ( my ($key, $value) = each(%in) ) { print "<br>$key => $value\n"; }
  print "</td>";
	print "</td>\n";
}

### Right Panel
#&html_right(\%menu_right);
if ($in{'rp'} eq 'my_games') { 
	print "<td width=$rp_width>";
#120715
#	$sql = qq|SELECT Games.*, User.User_Login FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (User.User_ID)=| . $session->param("userid") . qq|;|;
	$sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.HostName FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login GROUP BY Games.GameFile, Games.GameName, Games.GameStatus, User.User_ID HAVING User.User_ID=| . $session->param("userid") . qq| ORDER BY Games.GameStatus;|;
	&rp_list_games($sql, 'My Games');
	print "</td>";
} elsif ($in{'rp'} eq 'show_news') { 
	if (&checkbox($GameValues{'NewsPaper'})) {
		print qq|<td style="background-color:lightgrey;border:1px dashed black;padding: 4px;" width=$width_news><div style="height:$height_news| . qq|px;overflow:auto;">|;
		&show_news($GameValues{'GameFile'}); 
		print "</div></td>";
	}  else { print "<td></td>\n"; }
# Display a list of games in progress
} elsif ($in{'rp'} eq 'games') { 
	print "<td width=$rp_width>";
	$sql = "SELECT * FROM Games WHERE GameStatus>1 AND GameStatus<6;";
	&rp_list_games($sql,'Games In Progress');
	print "</td>";
# Display a list of new games
} elsif ($in{'rp'} eq 'games_new') { 
	print "<td width=$rp_width>";
	$sql = "SELECT * FROM Games WHERE GameStatus = 7 OR GameStatus = 0;";
	&rp_list_games($sql,'New Games');
	print "</td>";
# Display a list of games needing a replacement player
} elsif ($in{'rp'} eq 'games_replacement') { 
	print "<td width=$rp_width>";
	$sql = "SELECT * FROM Games WHERE GameStatus = 5;";
	&rp_list_games($sql,'Games needing Players');
	print "</td>";
# Display a list of completed games
} elsif ($in{'rp'} eq 'games_complete') { 
	print "<td width=$rp_width>";
	$sql = "SELECT * FROM Games WHERE GameStatus = 9;";
	&rp_list_games($sql,'Completed Games');
	print "</td>";
# Display a list of my races
} elsif ($in{'rp'} eq 'my_races') { 
	print "<td width=$rp_width>";
	$sql = qq|SELECT Races.*, User.User_ID FROM [User] INNER JOIN Races ON User.User_Login = Races.User_Login WHERE ((User.User_ID)=| . $session->param("userid") . qq|) ORDER BY RaceName;|;
	&list_races($sql);
	print "</td>";
# Display a list of players
} elsif ($in{'rp'} eq 'list_players') { 
	print "<td width=$rp_width>";
	$sql = qq|SELECT User_Event.GameFile, User.User_Name, User.User_ID, User_Event.Invite_Status FROM User_Event INNER JOIN [User] ON User_Event.User_ID = User.User_ID WHERE (((User_Event.GameFile)=$in{'GameFile'}));|;
	&list_players($sql);
	print "</td>";
#} else { print qq|<td width="$rp_width"></td>\n|;
}

print "</tr></table>\n";
&html_bottom;

##########
sub validate {
	my ($cgi, $session) = @_; 
	# @authorized_users - those users on the access list
	# $true   should authorized_users be permitted, or denied
	if ( $session->param("logged-in") ) {
		$authorized = 1;
	} else {
		$authorized = 0;
		print "Location:$Location_Index\n\n" unless $authorized; 
		exit;
	} 
}

sub edit_password {

print <<eof;
<td>
<form name="login" method=$FormMethod action="$Location_Scripts/page.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
<input type=hidden name="lp" value="profile">
<input type=hidden name="cp" value="change_password">
<table>
<tr><td>New Password:</td><td><input type=text id="pass_temp"></td></tr>
<tr><td>Confirm:</td><td><input type=text id="pass_temp2"></td></tr>
</table>
<input type=hidden name="User_Password" id="User_Password">
<br><input type=submit name="Submit" value="Change Password">
</form>
</td>
eof
}

sub change_password {
	print "<td>";
	$Date =&GetTimeString();
	$userid=$session->param("userid");
	$User_Login = $session->param("userlogin");
	$User_Email = $session->param("email");
	$new_password = $in{'User_Password'};
	$hash = $new_password . $secret_key;
	$userhash = sha1_hex($hash); 
	$db = &DB_Open($dsn);
	$sql = qq|UPDATE User SET User_Password=\'$userhash\', User_Modified=\'$Date\'  WHERE User_ID=$userid;|;
	&LogOut(100,$sql,$SQLLog);
	&DB_Call($db,$sql);
	print "Password changed for $User_Login.\n";
  #email user to let them know
  $MailTo = $User_Email;
  $MailFrom = $mail_from;
  $Subject = "$mail_prefix Password changed for $User_Login";
  $Message = "Password changed for $User_Login";
  &LogOut(100,"Emailed password change for $User_Login", $LogFile);
  $smtp = &Mail_Open;
  &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
  &Mail_Close($smtp);
	print "</td>";
}

sub edit_profile {
	my ($sql) = @_;
	$id = $session->param("userid");
	$db = &DB_Open($dsn);
	print "<td>\n";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	      	($User_ID, $User_Login, $User_First, $User_Last, $User_Email, $User_Bio, $EmailTurn, $EmailList) = $db->Data("User_ID", "User_Login", "User_First", "User_Last", "User_Email", "User_Bio", "EmailTurn", "EmailList");
		}
		$EmailTurn = &checkboxnull($EmailTurn);
		$EmailList = &checkboxnull($EmailList);
	} else { &LogOut(10,"ERROR: Finding edit_profile",$ErrorLog); }
	&DB_Close($db);
print <<eof;
<form name="login" method=$FormMethod action="$Location_Scripts/page.pl">
<input type=hidden name="lp" value="profile">
<input type=hidden name="cp" value="update_profile">
<input type=hidden name="rp" value="">
<table>
<tr><td>First Name:</td><td> <input type=text name="User_First" value="$User_First" size=32 maxlength=32></td></tr>
<tr><td>Last Name:</td><td><input type=text name="User_Last" value="$User_Last" size=32 maxlength=32></td></tr>
<tr><td>Email Address: </td><td><input type=text name="User_Email" value="$User_Email" size=32 maxlength=32></td></tr>
<tr><td>Bio: </td><td><textarea name="User_Bio" value="$User_Bio" cols="40" rows="5">$User_Bio</textarea></td></tr>
</table>
<INPUT type="Checkbox" name="EmailTurn" value = $EmailTurn $Checked[$EmailTurn]>Receive Turns via Email</P>
<INPUT type="Checkbox" name="EmailList" value = $EmailList $Checked[$EmailList]>Receive New Game Notifications</P>
<input type=submit name="Submit" value="Update">
</form>
</td>
eof
}

sub show_profile {
	my ($sql) = @_;
	my %Profile;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { %Profile = $db->DataHash(); }	
	} else { &LogOut(10,"ERROR: Finding show_profile",$ErrorLog); }
	&DB_Close($db);
	print qq|<table>\n|;
	print qq|<tr><td><b>User ID:</b></td><td>$Profile{'User_Login'}</td></tr>\n|;
	print qq|<tr><td><b>Name:</b></td><td>$Profile{'User_First'} $Profile{'User_Last'}</td></tr>\n|;
	print qq|<tr><td><b>Email:</b></td><td>$Profile{'User_Email'}</td></tr>\n|;
	print qq|<tr><td><b>Bio:</b></td><td>$Profile{'User_Bio'}</td></tr>\n|;
	print qq|<tr><td><b>Receive Turns via Email:</b></td><td>$Checked_Display[$Profile{'EmailTurn'}]</td></tr>\n|;
	print qq|<tr><td><b>Receive New Game Notifications:</b></td><td>$Checked_Display[$Profile{'EmailList'}]</td></tr>\n|;
	print qq|<tr><td><b>Member Since:</b></td><td>$Profile{'User_Creation'}</td></tr>\n|;
	print qq|<tr><td><b>Last Modified:</b></td><td>$Profile{'User_Modified'}</td></tr>\n|;
	print qq|<tr><td></td></tr>\n|;
	print qq|<tr><td>$Profile{'User_Status_Detail'}</td></tr>\n|;
	print qq|</table>\n|;

print <<eof
<form name="profile" method=$FormMethod action="$Location_Scripts/page.pl">
<input type=hidden name="lp" value="profile">
<input type=hidden name="cp" value="edit_profile">
<input type=hidden name="rp" value="my_games">
<input type=submit name="Submit" value="Edit Profile">
</form>
eof
}

sub update_profile {
	print "<td>\n";
	my $Date =&GetTimeString();
	my $User_Login = $in{'User_Login'};
	my $User_First = $in{'User_First'};
	my $User_Last = $in{'User_Last'};
	my $username = $in{'User_First'} . " " . $in{'User_Last'};
	my $User_Email = $in{'User_Email'};
	my $User_Bio =$in{'User_Bio'};
	my $EmailTurn = &checkboxnull($in{'EmailTurn'}); 
	my $EmailList = &checkboxnull($in{'EmailList'});
	my $userid=$id;
	my $User_Login = $session->param("userlogin");
	my $db = &DB_Open($dsn);
	my $sql = "UPDATE User SET User_Login='$User_Login', User_First='$User_First',  User_Last='$User_Last', User_Email='$User_Email', User_Bio='$User_Bio', EmailTurn = $EmailTurn, EmailList = $EmailList, User_Modified='$Date' WHERE User_ID=$userid;";
	if (&DB_Call($db,$sql)) { 
		&LogOut(100,"User: User $User_ID updated",$LogFile); 
		$session->param("userlogin",$User_Login);
		$session->param("email",$User_Email);
		print "User Updated\n";
#		&show_profile("SELECT * FROM User WHERE User_ID = $id;");
	} else { &LogOut(10,"ERROR: update_profile failed updating for User $User_Login:$User_ID",$ErrorLog);}
	&DB_Close($db);
	# Need to close the database to get the channges to display immediately.
	&show_profile("SELECT * FROM User WHERE User_ID = $id;");
	print "</td>";
}

sub show_my_new {
	my $counter;
	my $LoopPosition = 0;
	my $create_game = 0;
	my $def_game = 0; 
	my $table;
	# Read in all of the new games
	$sql = qq|SELECT * FROM Games WHERE (GameStatus=6 Or GameStatus=7) AND HostName = \'$userlogin\';|;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
	    while ($db->FetchRow()) {
			$counter++;
			my %GameValues = $db->DataHash();
	#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
			@GameData[$counter] = { %GameValues };
			if ($GameData[$counter]{'GameStatus'} == 6) { $create_game = 1; } # if there are any games in create status
			if ($GameData[$counter]{'GameStatus'} == 7) { $def_game = 1; } # if there are any games in def status
		}
	}
	&DB_Close($db);
	print "<h2>My New Games</h2>\n";
	# Display the new games 
	$table = "<table border=1>\n";
	$table .= "<th>Game Status</th><th>Game Name</th><th>Game File</th>\n";
	if ($create_game || $def_game) {
		$LoopPosition = 1; #Start with the first game in the array.
		while ($LoopPosition <= ($#GameData)) { # work the way through the array
			if ($GameData[$LoopPosition]{'GameStatus'} == 6) {
				$table .= "<tr><td>$GameStatus[$GameData[$LoopPosition]{'GameStatus'}]</td><td>$GameData[$LoopPosition]{'GameName'}</td><td><a href=$Location_Scripts/page.pl?lp=game&cp=create_game_size&rp=&GameFile=$GameData[$LoopPosition]{'GameFile'}&GameName=$GameData[$LoopPosition]{'GameName'}>$GameData[$LoopPosition]{'GameFile'}</a></td></tr>";
			}
			if ($GameData[$LoopPosition]{'GameStatus'} == 7 ) {
				$table .= "<tr><td>$GameStatus[$GameData[$LoopPosition]{'GameStatus'}]</td><td>$GameData[$LoopPosition]{'GameName'}</td><td><a href=$Location_Scripts/page.pl?lp=game&cp=show_game&rp=&GameFile=$GameData[$LoopPosition]{'GameFile'}>$GameData[$LoopPosition]{'GameFile'}</a></td></tr>";
			}
			$LoopPosition++;
		}
	}
	$table .= "</table>\n";
	if ($create_game || $def_game) { print $table; } 
	else { print qq|<P>No New Games. <a href="$Location_Scripts/page.pl?lp=game&cp=create_game&rp=">Create one</a>?\n|; }
}

sub show_new_games {	# Display new games
	my ($sql) = @_; 
	$db = &DB_Open($dsn);
	my $new_found = 0;
	my $table = "";
	print "<h2>New Games</h2>\n";
	$table = "<table border=1>\n";
	$table .= "<th></th><th>Game Name</th><th>Host ID</th><th>Description</th>\n";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
			%GameValues = $db->DataHash();
	#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			$table .= "<tr>\n"; 
			$table .= qq|<td><img src="$StatusBall{$GameStatus[$GameValues{'GameStatus'}]}" alt='Status' border="0">$GameStatus[$GameValues{'GameStatus'}]</td>\n|;  
			$table .= qq|<td><A href="$Location_Scripts/page.pl?lp=game&cp=show_game&rp=&GameFile=$GameValues{'GameFile'}">$GameValues{'GameName'}</a></td>\n|;
			$table .= "<td>$GameValues{'HostName'}</td>\n";
			$table .= "<td>$GameValues{'GameDescrip'}</td>\n";
			$table .= "</tr>"; 
			$new_found++;
		}
	} else { &LogOut(0, "show_new failed", $ErrorLog); }
	$table .= "</table>\n"; 
	if ($new_found) { print $table; }
	else { print qq|No New Games Found. <a href="$Location_Scripts/page.pl?lp=game&cp=create_game&rp=">Create one!</a>|; }
	&DB_Close($db);
}

sub process_game_leave {
	my ($GameFile, $PlayerID) = @_;
	my $sql = qq|DELETE User_Login, GameFile, PlayerID FROM GameUsers WHERE User_Login='$userlogin' AND GameFile='$GameFile' AND PlayerID=$PlayerID;|;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { 
    #print "$userlogin removed from game $GameFile\n";
    &LogOut(100,"$userlogin left game $GameFile", $LogFile);
  }
  # Need to let the host know. Figure out who the host is first.
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
  if (&DB_Call($db,$sql)) { 
    $db->FetchRow(); %GameValues = $db->DataHash(); 
    &LogOut(100,"Fetching Host name for $GameFile", $LogFile);
  }
  $sql = qq|SELECT * FROM User WHERE User_Login = '$GameValues{'HostName'}';|;
  if (&DB_Call($db,$sql)) { 
    $db->FetchRow(); %HostValues = $db->DataHash(); 
    #email host to let them know
    $MailTo = $HostValues{'User_Email'};
    $MailFrom = $mail_from;
    $Subject = "$mail_prefix $GameValues{'GameName'} : User $userlogin Left";
    $Message = "User $userlogin Left Your Game $GameValues{'GameName'} ($GameFile).";
    &LogOut(100,"Emailing host $GameValues{'HostName'} at $HostValues{'User_Email'} for $GameFile about $userlogin leaving", $LogFile);
    $smtp = &Mail_Open;
    &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
	  &Mail_Close($smtp);
  } else { &LogOut(0, "Failed to email host about new player $userlogin leaving $GameFile", $ErrorLog);}
	&DB_Close($db);
}

sub show_turngeneration {
	# Display the turn generation schedule based on gametype

	my ($GameFile, $GameType, $DailyTime, $HourlyTime, $HourFreq, $DayFreq, $AsAvailable) = @_;
	# Display the Turn Generation Schedule formatted for GameType
	print "<P><b>Turn Generation Schedule</b>:\n";
	if ($GameType == 3) { print "Turns generated only when all turns are in.\n"; } 
	elsif ($GameType == 4) { print " Turns Generated Manually.\n"; }
	elsif ($GameType == 2) { 
		print " Turns generated every $HourlyTime hours"; 
		if ($AsAvailable) { print " or when all turns are in"; }
		print ".";
		print "<table border=1><tr>\n";
		for (my $i=0; $i < 7; $i++) { print "<th>$WeekDays[$i]</th>\n"; }
		print "</tr><tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($DayFreq, $i, 1);
	 		if ($day) { print "<td align=center>Yes</td>\n"; }
	 		else { print "<td align=center>No</td>\n"; }
		}
		print "</tr></table>\n";
		# Print the hours turns will generate
		print "Hourly Restrictions:\n";
		print "<table border=1><tr>\n";
		for (my $i=0; $i <=23; $i++) { 
			if ($i/12 == int($i/12)) { print "</tr><tr>\n"; }
		 		my $hour = substr($HourFreq, $i, 1);
		 		if ($hour) { print "<td align=center>$i:00</td>\n"; }
		 		else { print "<td align=center><strike>$i:00<strike></td>\n"; }
			}
			print "</tr></table>\n";
	}
	elsif ($GameType == 1) {
		print " Turns generated daily"; 
		if ($AsAvailable) { print " or when all turns are in"; }
		print ".";
		print "<table border=1><tr>\n";
		for (my $i=0; $i < 7; $i++) { print "<th>$WeekDays[$i]</th>\n"; }
		print "</tr><tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($DayFreq, $i, 1);
	 		my $gen_time = &fixdate($DailyTime) . ':00'; 
	 		if ($day) { print "<td align=center>$gen_time</td>\n"; }
	 		else { print "<td align=center>-</td>\n"; }
		} 
		print "</tr></table>\n";
	} else { print "What kind of game IS this? \n"; &LogOut(0,"GameType Fail for $GameFile, $GameType", $ErrorLog);}
}

# merge of show_game and show_Game_new
sub show_game {  
 	my ($GameFile) = @_;
	my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware);
	my $NextTurn;
	my $HSTFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.hst';
  my ($db, $sql);
  my $players = 1; # Are there players in the game
  my $playeringame;
  my $player_file;  
  &LogOut(100,"Processing show_game for $GameFile",$LogFile);
  
	if ($GameFile) {
		$db = &DB_Open($dsn);
		# Get the values for the current game
		my $sql = qq|SELECT Games.*, User.User_Email FROM [User] INNER JOIN Games ON User.User_Login = Games.HostName WHERE Games.GameFile=\'$GameFile\';|;
		if (&DB_Call($db,$sql)) {
				$db->FetchRow();
				%GameValues = $db->DataHash();
        #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
		}
    
    ######
    # Display the Game Status Data
    print "<table width=100%>\n";
    # Print Game Name (and Year if applicable)
    print "<tr>\n";
		print "<td align=left><h3>$GameValues{'GameName'}</h3></td>";
    # If the game isn't started, it has no CHK or HST file, so checking would (obviously) error
    # We need this early to display the year
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6  && $GameValues{'GameStatus'} != 0) { 
  		($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
	    @CHK = &Read_CHK($GameFile); 
      print qq|<td align="center">Year $HST_Turn</td>|; 
    } else { print qq|<td align="center">Year 2399</td>|; }
    print "</tr>\n";
    # Display the Game Status
    print "<tr>\n";
    if ($GameValues{'GameStatus'} eq 7) { print "<td>Game Status: New Game - Pending new players</td>\n";
		} elsif ($GameValues{'GameStatus'} eq 0) { print "<td>Game Status: New Game - Locked, Waiting for Host to Start</td>\n";
    } else { 
      print "<td align=left>Game Status: @GameStatus[$GameValues{'GameStatus'}] </td>\n"; 
      unless ($GameValues{'GameStatus'} eq 9) { print qq|<td align="center"><A HREF=\"$Location_Scripts/download.pl?file=$GameFile.xy\">$GameFile.xy</A></td>\n|; }
    }
		print "</tr>\n";
    #########
    
    # Display the Host ID and email
    print qq|<tr><td>Host ID: <a href="mailto:$GameValues{'User_Email'}">$GameValues{'HostName'}</a></td><td></td></tr>\n|;
		print "</table>\n";
    
    #Display ForceGen Parameters   
    if ($GameValues{'ForceGen'} && $GameValues{'ForceGenTurns'} && $GameValues{'ForceGenTimes'} && $GameValues{'GameStatus'} != 9) { 
			print "<P><i>Turns generate $GameValues{'ForceGenTurns'} years at a time for the next $GameValues{'ForceGenTimes'} turn generation(s)"; 
			if ($HST_Turn eq '2400' || $HST_Turn eq '2401' || $HST_Turn eq '') { print " not to include years 2400 and 2401, which will generate only one year"; }
			print ".</i>\n";
		}

    #Display when the last turn was generated if it was.
    unless ($GameValues{'GameStatus'} == 7 || $GameValues{'GameStatus'} == 0 )  {
  		if ($GameValues{'LastTurn'}) { print "<br>Last turn generation: " . localtime($GameValues{'LastTurn'}) ." EST\n";}
  		else { print "<br>No turns have been generated yet.\n"; }
    } 

    #Display Next Turn time
    if (($GameValues{'NextTurn'} > 0) && ($GameValues{'GameType'} == 1 || $GameValues{'GameType'} == 2) ) { 
			# Fix the display time for DST
			my $NextTurnDST = &FixNextTurnDST($GameValues{'NextTurn'},$GameValues{'LastTurn'},1);
			if ($GameValues{'GameStatus'} == 4) {
#				print "<br><font color=red>[PAUSED] Next turn due on or before: " . localtime($NextTurnDST) . " EST</font>\n";  #BUG Need to be using DailyTime from database
				print "<br><font color=red>[PAUSED]</font>\n";
			} else {
				if ($GameValues{'GameStatus'} != 9) {
					print "<br>Next turn due on or before: " . localtime($NextTurnDST) . " EST\n";  #BUG Need to be using DailyTime from database
				}
			}
		} 

		# Useful when debugging turn issues to know when the system currently thinks it is.
		print "<P>Now: ". localtime(time()); 
		# If next turn is undefined(0) AND it's a game in progress somehow, display that the 
		# next generation will be immediate
		if ($GameValues{'NextTurn'} ne 0 && $GameValues{'GameStatus'} ne 7 && $GameValues{'GameStatus'} ne 9 && $GameValues{'GameStatus'} ne 4) { 
      print "<P>Will gen with/on the next automated generation"; 
      if ($GameValues{'AsAvailable'}) { print " or when all turns are in"; }
      print ".\n";
    }
    print "\n";
      
    # Display the player information
    # Active Game
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6 && $GameValues{'GameStatus'} != 0) {  
      # Display turn generation schedule
  		&show_turngeneration($GameValues{'GameFile'}, $GameValues{'GameType'}, $GameValues{'DailyTime'}, $GameValues{'HourlyTime'}, $GameValues{'HourFreq'}, $GameValues{'DayFreq'}, $GameValues{'AsAvailable'});
      print "<P>\n";
      # Display Active Game data If an active game and this data exists
		  # display the game and player information from the CHK File
      
      
  		print "<table>\n";
      # This won't execute without a CHK file (not available if the game isn't started)
  		my($Position) = '3';
      # Display player status, one line for each player in the CHK file
  		while (@CHK[$Position]) {  #Write .m file lines
  			my ($CHK_Status, $CHK_Name) = &Eval_CHKLine(@CHK[$Position]);    
  			my($Player) = $Position -2;
  			my $XFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.x' . $Player;
  			my $MFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.m' . $Player;
  			($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($MFile);
  			$TurnYears = $HST_Turn -$turn +1; 
  			# Get the values for the current player
  			$sql = qq|SELECT Games.GameFile, User.User_File, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.PlayerStatus, [_PlayerStatus].PlayerStatus_txt FROM _PlayerStatus INNER JOIN ([User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerID)=$Player));|;
  			if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { %PlayerValues = $db->DataHash(); } }
  			# If the player isn't active indicate such
  			if ($PlayerValues{'PlayerStatus'} == 1) { $del = ""; $del2 = ""; } else { $del = "<del>"; $del2 = "</del>";}

##################        
  			print qq|<tr>\n|;
  			if (($CHK_Status eq 'Out') && $del ) { print qq|<td><img src="$TurnBall{Inactive}" alt='Status' border="0" name="$CHK_Status"></a></td>\n|;} 
  			else { print qq|<td><img src="$TurnBall{$CHK_Status}" alt='Status' border="0" name="$CHK_Status"></a></td>\n|; }  
  			if ($PlayerValues{'User_Login'} eq $userlogin ) { print qq|<td style="border-width: 1px;padding: 1px;border-style: dotted;border-color: gray;">$del|;} 
  			else { 	print "<td>$del"; }
  			if (!($GameValues{'AnonPlayer'} ) || ($PlayerValues{'User_Login'} eq $userlogin) || ($GameValues{'GameStatus'} == 9 ) ) { print "$PlayerValues{'User_Login'}</td>"; }
        else { print "Player $Player: </td>"; }
        print "<td>$del$CHK_Name$del2</td>";
        
        # Display the .m file link
        if ($del) {
          # no link if the player is dead
          print "<td>.m$Player</td>\n";
        } elsif ($GameValues{'SharedM'}) { 
          # Always display link if .m files are shared
  	 			print qq|<td><A href=\"$Location_Scripts/download.pl?file=$GameFile.m$Player\">.m$Player</A></td>\n|;
  	 		} elsif ($PlayerValues{'User_Login'} eq $userlogin ) { 
        # Display link if the logged in user is the player
          print "<td><A href=\"$Location_Scripts/download.pl?file=$GameFile.m$Player\">.m$Player</A></td>\n"; 
  			} else { print "<td>.m$Player</td>\n"; }

        # Display the number of years included in the .m file
  			print qq|<td>|;
  			if ($TurnYears > 1) { print "($TurnYears years)"; }
  			print "</td>\n";
  			if ($CHK_Status eq 'Wrong Year') { 	print "<td><font color=red>$CHK_Status</font></td>\n"; 
  			} else {	
          if ($del) { print "<td>$CHK_Status</td>\n";
          } else { print "<td>$CHK_Status</td>\n"; }
        }
        
        unless ($GameValues{'GameStatus'} == 9) { # Don't display for finished game
    			if (-e $XFile) {
    				my $file_date = -M $XFile;
    				$file_date = &SubmitTime($file_date);
    				print "<td>$file_date</td>\n";
    			} elsif ($del || $CHK_Status eq 'Deceased') { print "<td><i>Inactive</i></td>\n";
    			} else { print "<td>Not Submitted</td>\n"; }
        }
        
        # Display the Remove Password button if applicable
        if ($in{'cp'} eq "Remove PWD" && $session->param("userlogin") eq $GameValues{'HostName'}) {
          print qq|<td align=center>|;
          print "<form>\n";
          print qq|<BUTTON $host_style type="submit" name="Reset Password" value="Reset Password" | . &button_help('RemovePWD') .  qq|>Reset Password</BUTTON>\n|;
          print qq|<input type=hidden name="Reset Password" value="Reset Password">\n|;
          print qq|<input type=hidden name="lp" value="profile_game">\n|;
          print qq|<input type=hidden name="rp" value="my_games">\n|;
          print qq|<input type=hidden name="cp" value="Reset Password">\n|;
          print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
          print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
          print qq|<input type=hidden name="PlayerID" value="$Player">\n|;
          print "</form>\n";
          print qq|</td>|;
        }
  			print "</tr>\n";
#############################        
  			
        # Store the current player ID for future reference
  			# BUG: Likely to fail if the player is in the game twice
  			if ($PlayerValues{'User_Login'} eq $userlogin) { 
  				$current_player = $PlayerValues{'User_Login'}; 
  				$player_status = $PlayerValues{'PlayerStatus'}; 
          $player_file = $PlayerValues{'User_File'};
  			}
  			undef %PlayerValues;
  			$Position++;
  		}
  		print "</table>\n";
  
  		# Only show the ability to upload to an active player in an active game
  		if ((($GameValues{'GameStatus'} == 2 || $GameValues{'GameStatus'} == 3 || $GameValues{'GameStatus'} == 4)) && ($current_player eq $userlogin)) {
  	  		&show_upload($GameValues{'GameName'},$GameFile);
  		} 
    } else {
      # Display Data for New Games 
      print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
  		print qq|<input type=hidden name="lp" value="profile_game">\n|;
  		print qq|<input type=hidden name="rp" value="my_games">\n|;
  		print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
  		print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
  		# Display user information for unstarted games
  		my $UserLogin;
  		my $table;
      my $sql = qq|SELECT Races.RaceName, * FROM GameUsers LEFT JOIN Races ON GameUsers.RaceFile = Races.RaceFile WHERE (((GameUsers.GameFile)='$GameFile')) ORDER BY GameUsers.JoinDate;|;
      
  		if (&DB_Call($db,$sql)) { 
  			$table = "<P><table border=1>\n";
  			$table .= "<th>Pending Player User IDs</th><th>Race Name</th><th>Race File</th><th>Joined</th>\n";
  			# as we won't show the leave game option once it's locked, no need for the table headers for it.
  			if ($GameValues{'GameStatus'} == 7 ) { $table .= "<th></th>"; }
        $players = 0;
  			# Find players currently in the (new) game
  			while ($db->FetchRow()) { 
  				%UserValues = $db->DataHash();
  				$table .= "<tr>\n";
  				$table .= qq|<td>$UserValues{'User_Login'}</td>|;
          # Don't show the race name unless its your own
          if ($userlogin eq $UserValues{'User_Login'}) {$table .= qq|<td align="center">$UserValues{'RaceName'}</td>|; }
          else { $table .= qq|<td><center>-----</center></td>|; }
          if ($userlogin eq $UserValues{'User_Login'}) {$table .= qq|<td>$UserValues{'RaceFile'}</td>|; }
          else { $table .= qq|<td><center>-----</center></td>|; }
  				if ($UserValues{'RaceFile'}) { $table .= qq|<td>| . localtime($UserValues{'JoinDate'}) . qq|</td>\n|; }
  				#Don't permit players to leave or be removed unless the game is still awaiting players.
  				if ($GameValues{'GameStatus'} == 7 ) {  
  				  if ($UserValues{'User_Login'} eq $userlogin) { 
  						# Uses Player ID, which at this point is a semi(random) unique number we can use to remove 
  						# the correct entry if the player has signed up more than once with the same RaceFile
  						$table .= qq|<td><BUTTON $user_style type="submit" name="cp" value="Leave Game" | . &button_help("LeaveGame") . qq|>Leave Game</BUTTON><input type=hidden name="PlayerID" value="$UserValues{'PlayerID'}"></td>\n|; 
#     				} else {
#               # BUG: Not implemented
#     					$table .= qq|<td><BUTTON $user_style type="submit" name="cp" value="Remove Player" | . &button_help("RemovePlayer") . qq|>Remove Player</BUTTON><input type=hidden name="PlayerID" value="$UserValues{'PlayerID'}"></td>\n|; 
            }
  				}
  				$table .= "</tr>\n";
  				$players = 1;
  			} 
  			$table .= "</table>\n";
  			# If there are new players, print the player table otherwise there aren't any.
  			if ($players) { print $table; }
  			else { print "<h3><font color=red>No players yet.</font></h3>\n"; }
  		}
  
  		# Determine if the player is already in the game
  		$sql = qq|SELECT * FROM GameUsers WHERE User_Login = '$userlogin' AND GameFile = '$GameValues{'GameFile'}';|;
  		$playeringame = 0; 
  		if (&DB_Call($db,$sql)) { 
  			if ($db->FetchRow()) { 
  				$playeringame = 1; 
  			}
  		} 
  
  		# Don't prompt to join game if you're already in it and the game doesn't permit duplicates
  		unless (&checknull($GameValues{'NoDuplicates'}) && $playeringame) {
  			# Display the player's races available to join the game.
  			if ($GameValues{'GameStatus'} == 7 ) {
          my $races_exist=0;
  				$sql = qq|SELECT * FROM Races WHERE User_Login = '$userlogin' ORDER BY RaceName;|;
          # Check to see if the player has any uploaded races
          if (&DB_Call($db,$sql)) { 
  				  print "<P>Select from my Available Races:\n";
  				  print qq|<SELECT name=\"RaceFile\">\n|;
  				  if (&DB_Call($db,$sql)) {
  					  while ($db->FetchRow()) { 
  			        #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
                %RaceValues = $db->DataHash(); 
                print qq|<OPTION value="$RaceValues{'RaceFile'}">$RaceValues{'RaceName'}</OPTION>\n|;
  					  }
  				    print qq|</SELECT>\n|;
            }
  				  # Join the game
  				  print qq|<BUTTON $user_style type="submit" name="cp" value="Join Game" | . &button_help("JoinGame") . qq|>Join Game</BUTTON>\n|;
          } else { print "<h3><font color=red>You cannot join the game unless you have a race uploaded to your Profile. Would you like to <a href=\"/scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races\">upload one</a>?</font></h3>\n"; } 
  			} 
  		}
      # Display turn generation schedule
		  &show_turngeneration($GameValues{'GameFile'}, $GameValues{'GameType'}, $GameValues{'DailyTime'}, $GameValues{'HourlyTime'}, $GameValues{'HourFreq'}, $GameValues{'DayFreq'}, $GameValues{'AsAvailable'});
      print "<P>\n";
    }
#    print "</FORM>";   # Duplicate /FORM found 191203
   
    print "<P>\n";
    # Display the Buttons
    # Add all the Host and game related buttons
		print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
		print qq|<input type=hidden name="lp" value="profile_game">\n|;
		print qq|<input type=hidden name="rp" value="my_games">\n|;
		print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
		print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
		print qq|<input type=hidden name="User_File" value="$player_file">\n|; 
        
    $button_count = 1;  # Keep track of the number of buttons displayed
    # Display Refresh Button
    if ($GameValues{'GameStatus'} =~ /^[2349]$/) { print qq|<BUTTON $user_style type="submit" name="cp" value="Refresh" | . &button_help('Refresh') . qq|>Refresh</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Display Start Button
    if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '0') { print qq|<BUTTON $host_style type="submit" name="cp" value="Start Game" | . &button_help('StartGame') . qq|>Start Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Lock the game and prepare to start
		if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '7' && $playeringame) { print qq|<BUTTON $host_style type="submit" name="cp" value="Lock Game" | . &button_help('LockGame') . qq|>Lock Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Unlock the game 
		if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '0') { print qq|<BUTTON $host_style type="submit" name="cp" value="Unlock Game" | . &button_help('UnlockGame') . qq|>Unlock Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Submit a news article
		if ($GameValues{'NewsPaper'} && ($current_player eq $userlogin) && ($GameValues{'GameStatus'} ne '9'))	{ print qq|<BUTTON $user_style type="submit" name="cp" value="Report News" | . &button_help("NewsPaper") . qq|>Report News</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Delay the game
		if ($GameValues{'GameDelay'} && ($GameValues{'GameType'} ne '3') && ($GameValues{'GameStatus'} ne '9') && ($current_player eq $userlogin))	{ print qq|<BUTTON $user_style type="submit" name="cp" value="Delay Game" | . &button_help('GameDelay') . qq|>Delay Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# BUG: Delete News doesn't quite work yet, don't delete
	#	if ($GameValues{'HostName'} eq $session->param("userlogin") && ($GameValues{'NewsPaper'})) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="delete_news" | . &button_help('DeleteNews') . qq|>Delete News</BUTTON>\n|; }
		# Force generate turns
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'HostForce'} && ($GameValues{'GameStatus'} ne '9')) 		{ print qq|<BUTTON $host_style type="submit" name="cp" value="Force Gen" | . &button_help('ForceGen') . qq|>Force Gen</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Restore the game from backup
		if ($GameValues{'GameRestore'} && $GameValues{'HostName'} eq $session->param("userlogin") && ($GameValues{'GameStatus'} ne '9') && ($GameValues{'GameStatus'} ne '0') && ($HST_Turn > 2400)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Restore Game" | . &button_help('GameRestore') . qq|>Restore Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Edit the game
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'HostMod'} ) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Edit Game" | . &button_help('EditGame') .  qq|>Edit Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Change the player status
		if ($GameValues{'HostName'} eq $session->param("userlogin")  && ($GameValues{'GameStatus'} eq '2' || $GameValues{'GameStatus'} eq '4')) 		{ print qq|<BUTTON $host_style type="submit" name="cp" value="Player Status" | . &button_help('PlayerStatus') . qq|>Player Status</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Pause/Unpause the game
		# Must be hosting the game, or in the game if the game permits
		if ($GameValues{'GamePause'} && $current_player eq $userlogin) { $pause_style = $user_style; } else { $pause_style = $host_style; }
		if (($GameValues{'GameStatus'} eq '4') && (($GameValues{'HostName'} eq $session->param("userlogin")) || (&checkbox($GameValues{'GamePause'}) && $current_player eq $userlogin))) { print qq|<BUTTON $pause_style type="submit" name="cp" value="UnPause Game"| . &button_help('GamePause') . qq|>UnPause Game</BUTTON>|; print qq|<input type=hidden name="GamePause" value="$GameValues{'GamePause'}">\n|; $button_count = &button_check($button_count);} 
		if (($GameValues{'GameStatus'} =~ /^[235]$/) && (($GameValues{'HostName'} eq $session->param("userlogin")) || (&checkbox($GameValues{'GamePause'}) && $current_player eq $userlogin))) { print qq|<BUTTON $pause_style type="submit" name="cp" value="Pause Game" | . &button_help('GamePause') . qq|>Pause Game</BUTTON>|; print qq|<input type=hidden name="GamePause" value="$GameValues{'GamePause'}">\n|; $button_count = &button_check($button_count);}
		# End the game
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} eq '2' || $GameValues{'GameStatus'} eq '4')) { print qq|<BUTTON $host_style type="submit" name="cp" value="End Game" | . &button_help('EndGame') . qq|>End Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Restart Game
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'GameStatus'} eq '9') { print qq|<BUTTON $host_style type="submit" name="cp" value="Restart Game" | . &button_help('RestartGame') . qq|>Restart Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Change personal game state from active to inactive and vice versa.
		if (($current_player eq $userlogin) && ($player_status == 1) && ($GameValues{'GameStatus'} ne '9')) { print qq|<BUTTON $user_style type="submit" name="cp" value="Go Inactive" | . &button_help('GoInactive') . qq|>Go Inactive</BUTTON>\n|; $button_count = &button_check($button_count);}
		if (($current_player eq $userlogin) && ($player_status == 2) && ($GameValues{'GameStatus'} ne '9')) { print qq|<BUTTON $user_style type="submit" name="cp" value="Go Active" | . &button_help('GoActive') . qq|>Go Active</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Email Players
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $players) { print qq|<BUTTON $host_style type="submit" name="cp" value="Email Players" | . &button_help('EmailPlayers') . qq|>Email Players</BUTTON>\n|; $button_count = &button_check($button_count);}
 		# Download the zip file. Don't bother displaying zip file option when there IS no history.
		if (($HST_Turn > 2400) && ($current_player eq $userlogin) ) { print qq|<BUTTON $user_style type ="button" name="Download" | . &button_help('GetHistory') . qq| onClick = window.open("$Location_Scripts/download.pl?file=$GameValues{'GameFile'}.zip")>Get History</BUTTON>|; $button_count = &button_check($button_count);}
		# Delete the game
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[04679]$/)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Delete Game" | . &button_help('DeleteGame') .  qq|>Delete Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Remove Password
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[23459]$/)) 	{print qq|<BUTTON $host_style type="submit" name="cp" value="Remove PWD" | . &button_help('RemovePWD') .  qq|>Remove PWD</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Start Game
		if ( $GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '0') { print qq|<BUTTON $host_style type="submit" name="cp" value="Start Game" | . &button_help('StartGame') . qq|>Start Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Set the DEF File
		if ($GameValues{'HostName'} eq $userlogin && ($GameValues{'GameStatus'} eq '6' )) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="DEF File" | . &button_help('DEFFile') .  qq|>DEF File</BUTTON>\n|; $button_count = &button_check($button_count);}
		print qq|</form>\n|;
		&DB_Close($db);
		print qq|<hr><P>|; 
		if ($GameValues{'Notes'}) { print qq|<table border=1 width=100%><tr><td><b>Game Notes</b>: $GameValues{'Notes'}</td></tr></table>\n|; }

		# Display the TH game parameters
		&read_game($GameFile);
		# Display the Stars game parameters
		&read_def($GameFile);
    
	# If there were no new games returned from the original query, display that.
  } else {
		print "<P>No Games found\n";
	}
}

sub button_form {
	# might be useful at some point,but not yet
	my ($GameFile, $Var) = @_;
# moved to config
#	my $host_style = qq|style="color:red;width:120px;height:24;"|;
#	my $user_style = qq|style="width:120px;height:24;"|;
	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
	print qq|<input type=hidden name="rp" value="my_games">\n|;
	print qq|<input type=hidden name="GameFile" value="$GameFile">\n|;
	print qq|</form>\n|;
}

sub button_help {
	my ($string) = @_;
#	my $mod_string = qq|onMouseOver="Help( \'$string\' )" onMouseOut="Help( \'blank\' )"|;
	my $mod_string = qq|onMouseOver="Help( \'$string\' )"|;
	return $mod_string;
}

sub submit_news {
	my ($GameFile) = @_;
	print "<td>\n";
	print "Submit an article to the Galactic News!\n";
	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<TEXTAREA name="NewsPaper" rows=4 cols=40 maxlength="250" onFocus="Help( 'NewsPaper' )" type=Text></TEXTAREA><br>\n|;
	print qq|<input type=hidden name="GameFile" value="$GameFile">\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
	print qq|<input type=hidden name="rp" value="show_news">\n|;
	print qq|<INPUT type="submit" name="cp" value="Submit Article" onMouseOver="Help( \'SubmitArticle\' )" onMouseOut="Help( \'blank\' )">\n|;
	print qq|</form>\n|;
	print "</td>\n";
}

sub create_news { # create a news file
	my ($newsfile) = @_;
	open (OUT_FILE, ">$newsfile") || die("Cannot create $newsfile file");
	print OUT_FILE "0\t0\t2400\tNo News Yet\n";
	close(OUT_FILE);
}

sub delete_news {
	#Read in the news
	my ($GameFile) = @_;
	my $newsfile = $File_HST . '/' . $GameFile . '/' . "$GameFile.news";
	if (!(-e $newsfile)) { 
		print "<P>No news to fix!\n";
	} else { open (IN_FILE,$newsfile) || die("Can\'t open news file");
		print "<td>\n";
		print qq|<i>Gal News: News fit to print or not.</i><p>|; 
		@news = <IN_FILE>;
		close(IN_FILE);
		print "<table>\n";
		foreach my $key (@news) {
	 		($id, $secs, $turn, $story) = split('\t', $key);
	 		if ($secs) { $l_time = localtime($secs); }
			print "<tr>\n";
			print qq|<td><form name="login" method=$FormMethod action="$Location_Scripts/page.pl">\n|;
			print qq|<input type="hidden" name="lp" value="my_games">\n|;
			print qq|<input type="hidden" name="cp" value="show_game">\n|;
			print qq|<input type="hidden" name="rp" value="show_news">\n|;
			print qq|<input type=submit name="Delete" value="Delete">\n|;
			print qq|</FORM></td>\n|;
	 		print "<td><b>$turn</b>: $story</td>";
			print "</tr>\n";
		}
		print "</table>\n";
		print "</td>\n";
	}
}

sub process_game_launch {
	($GameFile) = @_;
	my $counter = 0;
	# Determine how many players there are, and get all the race information
	#Reorder them based on the random player ID generated when they joined the game
	$sql = qq|SELECT * FROM GameUsers WHERE GameFile = '$GameFile' ORDER BY PlayerID;|;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { 
			%GameUserValues = $db->DataHash(); 
#			while ( my ($key, $value) = each(%GameUserValues) ) { print "<br>$key => $value\n"; }
			$counter++;
			@GameUserData[$counter] = { %GameUserValues };
		}
	}

	# Confirm that there are enough players to launch, otherwise abort. 
	if ($counter >= $min_players) {
		# Update all of the the player IDs in the database
		# based on the sort order from the random Player IDs
		for (my $i=1; $i <=$counter; $i++) {
      # Attempt to make the SQL query unique. 
      # BUG: Will fail if the same user joined twice in the same second.
			$sql = 	qq|UPDATE GameUsers SET PlayerID = $i WHERE PlayerID = $GameUserData[$i]{'PlayerID'} AND GameFile = '$GameFile' AND JoinDate = $GameUserData[$i]{'JoinDate'};|;
			&DB_Call($db,$sql);
		}
		# Read the DEF file in, and push it back out with the race file information	
		my $def_file = "$FileHST\\$GameFile\\$GameFile.def"; 
#		print "DEF: $def_file\n";
		my @def_data = ();
		if (-e $def_file) { #Check to see if .def file is there.
			open (IN_FILE,$def_file);
			chomp(@def_data = <IN_FILE>);
			close(IN_FILE);

			# Rewrite the outbound data with the race information
			# Change the outbound def file so if there's an error we still have the original
			$def_file_races = "$FileHST\\$GameFile\\$GameFile.df2";
			open (OUT_FILE, ">$def_file_races");
			print OUT_FILE "$def_data[0]\n"; # Game Name
			print OUT_FILE "$def_data[1]\n"; # Universe Values
			print OUT_FILE "$def_data[2]\n"; # Game Settings
			print OUT_FILE "$counter\n"; # # of players

			# Print out the race information
			my $path;
			for (my $i=1; $i <=$#GameUserData; $i++) {
        # Get the location for the race for this player
        my %UserValues;
    		$sql = qq|SELECT * FROM User WHERE User_Login = \'$GameUserData[$i]{'User_Login'}\';|;
		    if (&DB_Call($db,$sql)) {
				  $db->FetchRow();
				  %UserValues = $db->DataHash();
		    }
  			$path = $FileRaces . '\\' . $UserValues{'User_File'} . '\\' . $GameUserData[$i]{'RaceFile'};
				print OUT_FILE "$path\n";
			}
			# Print out the remaining game data
			for (my $i=4; $i <=12; $i++) {
				print OUT_FILE "$def_data[$i]\n";
			}
			close OUT_FILE; 
		} else { 
			print "Game Definition File $def_file not found!\n"; 
			&LogOut(0,"Game Definition File $def_file not found at launch",$ErrorLog);
			return 0;
		}
 
		# Create the game from the command line
  	my($CreateGame) = $executable . 'stars.exe -a ' . $def_file_races;
		&LogOut(50, "Creating Game $CreateGame", $LogFile);
		#exec causes perl.exe to crash
		#exec($x);
		# Starting system with "1" makes it launch asyncronously
		# important if for some reasons stars hangs (like a corrupt race file).
		system(1,$CreateGame);
		sleep 5;
		# BUG: I don't know how to detect for a corrupt race file that passes starstat.
		my $new_hst_file = "$FileHST\\$GameFile\\$GameFile.hst";
		if (-e $new_hst_file) { 
		  &LogOut(50, "Game $CreateGame Created", $LogFile);
			# set the game status to paused. 
			&process_game_status($GameFile, $sql, 'Launched'); 
			# set the "last submitted date for players to "now". 
			$sql = qq|UPDATE GameUsers SET LastSubmitted = | . time() . qq| WHERE GameFile = \'$in{'GameFile'}\';|;
			if (&DB_Call($db,$sql)) {
				&LogOut(100, "$GameFile User Last Submitted updated at Game Start", $LogFile);
			} else {
				&LogOut(0, "$GameFile User Last Submitted failed to update at Game Start", $ErrorLog);
			}
      
      # Try to figure out when the next turn is due and update the date so
      # it doesn't just start generating
      # (Note it should be paused anyway)
		  ($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs) = &GetTime; 
		  if ($GameValues{'GameType'} == 1 ) {
			  # Determine when the next possible time is that turns are due
			  ($DaysToAdd1, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$WeekDay);
			  # now advance one interval from that, so you have a full interval
#			  ($DaysToAdd2, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$NextDayOfWeek);
			  # Set the time for the next turn on the right day
			  $NewTurn = $CurrentDateSecs + $DaysToAdd1*86400 + $DaysToAdd2*86400 +($GameValues{'DailyTime'} *60*60); 
			  $sql = qq|UPDATE Games SET NextTurn = $NewTurn WHERE GameFile = \'$GameFile'\' AND HostName=\'$userlogin\';|;
      }
      
      
			&DB_Close($db);
			return 1;
		} else {
			print "<P>Game $GameFile Failed to Launch (probably due to a corrupt race file)!";
			&LogOut (0,"Game $GameFile Failed to Launch (probably due to a corrupt race file). $CreateGame", $ErrorLog);
			&DB_Close($db);
			return 0;
		}
	} else { 
		print "<P>You cannot launch a game with only $counter player(s)";
		&LogOut(0, "Attempt to launch $GameFile with only $counter players",$ErrorLog);
		return 0;
	}
}

sub process_news {
	# The news file is stored as .news in the folder for the game
	# The format for each article is id<tab>epochtime<tab>year<tab>story
	# and stored in chronologic order, newest first
	my ($GameFile, $new_news) = @_;
	# Remove HTML tags
	$new_news = &clean($new_news);
	# replace line breaks with HTML break.
	$new_news =~ s/\n/<br>/g;
	my @news;
	my $newsfile = $File_HST . '/' . $GameFile . '/' . "$GameFile.news";
	my $HSTFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.hst';
	($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
	if (!(-e $newsfile)) { # If there's no news file, create one. 
		&create_news($newsfile);
	}
	else { 
		# Validate that the logged in user is a game member before we 
		# let them submit news

		my $valid_submitter = 0; 
		$sql = qq|SELECT * FROM GameUsers WHERE GameFile = \'$GameFile\';|; 
		$db = &DB_Open($dsn);
		if (&DB_Call($db,$sql)) { 	
			while ($db->FetchRow()) { 
				my %UserValues = $db->DataHash(); 
#				if ($UserValues{'User_Login'} eq $userlogin) { $valid_submitter = 1; }
				&LogOut(200, "News User: $UserValues{'User_Login'}  $userlogin", $LogFile); 
				if ($UserValues{'User_Login'} eq $userlogin) { 
          $valid_submitter = 1; 
          &LogOut(200, "Valid news from $userlogin", $LogFile); 
        }
			}
		}
		&DB_Close($db);

		if ($valid_submitter) {
			# Read in the old news
			open (IN_FILE,$newsfile) || die("Can\'t open news file");
			@news = <IN_FILE>;
			close(IN_FILE);
			# Write out the news with the current news at the beginning 
			# (So the data is from new to old)
			$newsfile = ">" . $newsfile;
			open (OUTFILE, $newsfile) || die("Can\'t create news file!");
			print OUTFILE $id . "\t";
			# Get the actual Game Turn about here and store it. 
			print OUTFILE time() . "\t";
			print OUTFILE $HST_Turn . "\t";
			print OUTFILE "$new_news\n";
			print OUTFILE @news;
			close (OUTFILE);
		} else {
			&LogOut (0,"Invalid attempt to update news by  $userlogin for $GameFile", $ErrorLog);
		}
	}
}

sub show_news {
	#Display the current news for a game
	my ($GameFile) = @_;
	my @news;
	my $id, $secs, $turn, $story, $l_time;
	my $newsfile = $File_HST . '/' . $GameFile . '/' . "$GameFile.news";
	# Check to see if there is a news file
	if (!(-e $newsfile)) { # Create the new file
		&create_news($newsfile);
	} else { open (IN_FILE,$newsfile) || die("Can\'t open news file");
		print qq|<i>Gal News: News fit to print or not.</i><p>|; 
		@news = <IN_FILE>;
		close(IN_FILE);
		foreach my $key (@news) {
	 		($id, $secs, $turn, $story) = split('\t', $key);
	 		if ($secs) { $l_time = localtime($secs); }
	 		print "<P><b>$turn</b>: $story\n\n";
		}
	}
}

sub lp_list_games {
	my ($id) = @_;
	my %menu_left;
	%menu_left = 	(
 		"0My Games" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
		"5My Completed" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=welcome&rp=games_complete",
		"1My In Progress" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_games_inprogress&rp=games",
		"4My New Games" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_my_new&rp=games_new",
		"6Create Game"	=> "$Location_Scripts/page.pl?lp=game&cp=create_game&rp=",
		"9<hr>" 	=> ""
	);

	$sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4));|;
	my $db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	    my ($GameName, $GameFile, $NewsPaper) = $db->Data("GameName", "GameFile", "NewsPaper");
      # Change the URL based on whether the game has Galactic News enabled
			if (&checkbox($NewsPaper)) {
				$menu_left{"<i>$GameName</i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=show_news&GameFile=$GameFile|;
			} else { 	$menu_left{"<i>$GameName</i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=&GameFile=$GameFile|; }
		}
	} else { &LogOut(10,"ERROR: Finding list_games",$ErrorLog); }
	&DB_Close($db);
	return %menu_left;
}

sub lp_list_new {
	my ($id) = @_;
	my %menu_left;
	%menu_left = 	(
 		"0My Games" 	=> "$Location_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
		"5My Completed" 	=> "$Location_Scripts/page.pl?lp=game&cp=welcome&rp=games_complete",
		"1My In Progress" 	=> "$Location_Scripts/page.pl?lp=game&cp=welcome&rp=games",
		"4My New Games" 	=> "$Location_Scripts/page.pl?lp=game&cp=show_my_new&rp=games_new",
		"6Create Game"	=> "$Location_Scripts/page.pl?lp=profile_game&cp=create_game&rp=my_games",
		"9<hr>" 	=> ""
	);
# 120714
#	$sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameName = GameUsers.GameName) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND (Games.GameStatus)=7);|;
	$sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM [User] INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND (Games.GameStatus)=7);|;
	my $db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	      ($GameName, $GameFile) = $db->Data("GameName", "GameFile");
			$menu_left{"<i>$GameName<i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=&GameFile=$GameFile|; 
		}
	} else { &LogOut(10,"ERROR: Finding list_new",$ErrorLog); }
	&DB_Close($db);
	return %menu_left;
}

sub list_races {
	my ($sql) = @_;
	$db = &DB_Open($dsn);
	my $c = 0;
	if ($in{'rp'} eq 'my_races') { 	print qq|<u>My Races</u>\n|; }
	else {print qq|<u>Races</u>\n|;}
	print "<table>\n";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	      ($RaceName, $RaceFile) = $db->Data("RaceName", "RaceFile");
			$c++;
			if ($in{'rp'} eq 'my_races') {
				print qq|<tr><td><a href=$Location_Scripts/page.pl?lp=profile_race&cp=show_race&rp=my_races&RaceFile=$RaceFile>$RaceName</a></td></tr>\n|;
			} else { print qq|<tr><td><a href=$Location_Scripts/page.pl?lp=profile_race&cp=show_race&rp=list_races&RaceFile=$RaceFile>$RaceName</a></td></tr>\n|; }
		}
		unless ($c) {print "<tr><td>  No races found</td></tr>";}
	} else { &LogOut(10,"ERROR: Finding list_races",$ErrorLog);}
	print "</table>\n";
	&DB_Close($db);
}

sub show_race {
	my ($sql) = @_;
  use StarsBlock;
	my %RaceValues;
	$db = &DB_Open($dsn);
	my $c=0; 
	if (&DB_Call($db,$sql)) {
	    while ($db->FetchRow()) { %RaceValues = $db->DataHash(); $c++; }
	} else { &LogOut(10,"ERROR: Finding show_race",$ErrorLog); }
	&DB_Close($db);
	if ($c) {
		# Get $ver
    my $racepath = $FileRaces . '\\' . $RaceValues{'User_File'};
#		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($RaceValues{'RaceFile'},$FileRaces);
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($RaceValues{'RaceFile'},$racepath);
		print <<eof;
<table>
<tr><td>Race Name:</td><td>$RaceValues{'RaceName'}</td></tr>
<tr><td>Race Description:</td><td>$RaceValues{'RaceDescrip'}</td></tr>
<tr><td>Race File Name:</td><td><A HREF="/scripts/download.pl?file=$RaceValues{'RaceFile'}">$RaceValues{'RaceFile'}</A></td></tr>
<tr><td>Stars! Version:</td><td>$ver</td></tr>
</table>
eof

my $racefile =  $racepath . '\\' . $RaceValues{'RaceFile'};
&show_race_block($racefile);

print <<eof;
<form name="login" method=$FormMethod action="$Location_Scripts/page.pl">
<input type="hidden" name="lp" value="profile_race">
<input type="hidden" name="cp" value="delete_race">
<input type="hidden" name="rp" value="my_races">
<input type="hidden" name="RaceFile" value="$RaceValues{'RaceFile'}">
<input type=submit name="Delete Race" value="Delete Race">
</FORM>
eof
		} else {
			print "<P>No Races Found. Would you like to <a href=\"/scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races\">upload one</a>?\n";
#			&LogOut(0,"$userlogin failed to download Race File $racefile", $ErrorLog);
		}
}

sub upload_race {
print <<eof;
<td>
<FORM method=$FormMethod action="$Location_Scripts/upload.pl" name="my_form" enctype="multipart/form-data">
<input type="hidden" name="lp" value="profile_race">
<input type="hidden" name="cp" value="process_race">
<input type="hidden" name="rp" value="my_races">
eof
print qq|	<TABLE>\n|;
print qq|		<TR><TD>Race Name:</TD> <TD><INPUT type="text" | . &button_help("RaceName") . qq|name="RaceName" size="30"> (Mandatory)</TD></TR> \n|;
print qq|		<TR><TD>Race Description:</TD> <TD><TEXTAREA name="RaceDescrip" | . &button_help("RaceDescrip") . qq| rows="4" cols="50"></TEXTAREA></TD></TR>  \n|;
print qq|		<TR><TD>File:</TD> <TD><INPUT type="file" name="File" size="30"></TD></TR>        \n|;
print qq|	</TABLE>       \n|;
print qq|<INPUT type="submit" name="submit" value="Upload Race">  \n|;
print qq|</FORM>   \n|;
print qq|</td> \n|;
}

sub delete_race {
	my ($RaceFile) = @_;
	# Need to check to be sure the race is not currently signed up for any not ended games
	$db = &DB_Open($dsn);
	#$sql = qq|SELECT User.User_ID, GameUsers.GameFile, GameUsers.RaceFile FROM [User] INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login WHERE User.User_ID=$id AND GameUsers.RaceFile=\'$RaceFile\';|;
  # modified 190217 to not include finished games
  #$sql = qq|SELECT User.User_ID, GameUsers.GameFile, GameUsers.RaceFile, Games.GameName, Games.GameStatus FROM Games INNER JOIN ([User] INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login) ON (User.User_Login = Games.HostName) AND (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((User.User_ID)=$id) AND ((GameUsers.RaceFile)=\'$RaceFile\') AND ((Games.GameStatus)<>9));|;
  $sql = qq|SELECT User.User_ID, GameUsers.GameFile, Races.RaceName, GameUsers.RaceFile, Games.GameName, Games.GameStatus FROM ([User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON (User.User_Login = GameUsers.User_Login) AND (User.User_Login = Games.HostName)) INNER JOIN Races ON User.User_Login = Races.User_Login WHERE (((User.User_ID)=$id) AND ((GameUsers.RaceFile)=\'$RaceFile\') AND ((Games.GameStatus)<>9));|;
	my $counter =0;
  my %GameValues;
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { 
			$counter++; 
			%GameValues = $db->DataHash();
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
		}
	}
#	if ($counter) {
	if ($GameValues{'RaceFile'}) {
		print "<P><font color=red>$GameValues{'RaceName'} ($GameValues{'RaceFile'}) cannot be deleted, as it is currently associated with at least one game:  $GameValues{'GameName'}</font>\n";
	# otherwise delete it
	} else { 
		print "<P>Deleting Race ...\n";
		# To make the data clean and safe, pull the data directly from the database first to sanitize the results
		$sql = qq|SELECT * FROM Races WHERE User_Login=\'$userlogin\' AND RaceFile = \'$RaceFile\'|;
		if (&DB_Call($db,$sql)) {
			while ($db->FetchRow()) { 
         %RaceValues = $db->DataHash();
#				($RaceFiled, $User_Login) = $db->Data('RaceFile', 'User_Login');
#				print "$RaceFiled for $User_Login confirmed...\n";
			} 
#		} else { print qq|<P>RaceFile $RaceFile not found as $RaceFiled for User $User_Login\n|; }
		} else { print qq|<P>RaceFile $RaceFile not found as $RaceValues{'RaceFile'} for User $User_Login\n|; }
		if ($RaceValues{'RaceFile'} && $RaceValues{'User_Login'}) {
			$sql= "DELETE RaceFile, User_Login FROM Races WHERE (RaceFile=\'$RaceValues{'RaceFile'}\' AND User_Login=\'$RaceValues{'User_Login'}\');";
			&LogOut(200,"delete_race: $sql",$SQLLog);
			if (&DB_Call($db,$sql)) { print qq|<P>Race $RaceValues{'RaceName'} deleted from database.\n|; }
			my $race_file = $FileRaces . '\\' . $RaceValues{'User_File'} . '\\' . $RaceValues{'RaceFile'};
			$race_file = &clean($race_file);
			unlink($race_file);
      if (-e $race_file) {
        print "Race file $RaceValues{'RaceFile'} failed to delete from file system";
        &LogOut(0,"Race file $RaceValues{'RaceFile'} failed to file delete for $userlogin",$ErrorLog);
        
      } else {
        print "Race file $RaceValues{'RaceFile'} deleted from file system.";
        &LogOut(100,"Race file $RaceValues{'RaceFile'} deleted from file system for $userlogin",$LogFile);
      }
		}
	}
	&DB_Close($db);
}

# sub invite_friends {
# 	# Enter a friendship invite
# 	print qq|<td>\n|;
# 	print qq|<form method=$FormMethod action="$Location_Scripts/page.pl">\n|;
# 	print qq|<input type=hidden name="lp" value="friends">\n|;
# 	print qq|<input type=hidden name="cp" value="add_friend">\n|;
# 	print qq|<input type=hidden name="rp" value="friends">\n|;
# 	print qq|<table>\n|;
# 	print qq|<tr>\n|;
# 	print qq|<td>Email Address of Friend: </td><td><input type=text name="Email_Address" value=""></td>\n|;
# 	print qq|</tr><tr>\n|;
# 	print qq|<td><input type=submit name="Submit" value="Add Friend"></td>\n|;
# 	print qq|</tr>\n|;
# 	print qq|</table>\n|;
# 	print qq|Will only work if they're a member\n|;
# 	print qq|</form>\n|;
# 	print qq|</td>\n|;
# }
# 
# sub invite_game {
# 	print qq|<td>\n|;
# 	print qq|<form method=$FormMethod action="$Location_Scripts/page.pl">\n|;
# 	print qq|<input type=hidden name="lp" value="game">\n|;
# 	print qq|<input type=hidden name="cp" value="add_game_friend">\n|;
# 	print qq|<input type=hidden name="rp" value="friends">\n|;
# 	print qq|<input type=hidden name="GameFile" value=$in{'GameFile'}>\n|;
# 	print qq|<table>\n|;
# 	print qq|<tr>\n|;
# 	print qq|<td>Email Address of Friend: </td><td><input type=text name="Email_Address" value=""></td>\n|;
# 	print qq|</tr><tr>\n|;
# 	print qq|<td><input type=submit name="Submit" value="Add Friend to Game"></td>\n|;
# 	print qq|</tr>\n|;
# 	print qq|</table>\n|;
# 	print qq|Will only work if they are a member\n|;
# 	print qq|</form>\n|;
# 	print qq|</td>\n|;
# }
# 
# sub display_invitations_detail {
# 	$db=&DB_Open($dsn);
# 	# Display all the Friend invitations
# 	$sql = qq|SELECT User_Friends.*, User.* FROM User_Friends INNER JOIN [User] ON User_Friends.User_ID = User.User_ID WHERE (((User_Friends.Friend_ID)=$id));|;
# 	print "<P>Accept Friend Invitation from: \n";
# 	print "<table>\n";
# 	if (&DB_Call($db,$sql)) {
# 		while ($db->FetchRow()) {
# 	      	($User_Name, $UniqueID) = $db->Data("User_Name", "UniqueID");
# 			if ($UniqueID) {
# 				print qq|<tr><td><a href=$Location_Scripts/page.pl?lp=&cp=>$User_Name</a></td></tr>\n|;
# 			}
# 		}
# 	} else { }
# 	print "</table>\n";
# 	&DB_Close($db);
# }
# 
# sub accept_game {
# 	print qq|<td>\n|;
# 	$Date = &GetTimeString();
# 	$db=&DB_Open($dsn);
# 	$sql = qq|SELECT * FROM User_Event WHERE UniqueID='$in{'id'}';|;
# 	if (&DB_Call($db,$sql)) {
# 		while ($db->FetchRow()) {
# 	      		($Event_User_ID, $User_ID, $GameFile, $UniqueID) = $db->Data("Event_User_ID", "User_ID", "GameFile", "UniqueID");
# 		}
# 		if ($Event_User_ID) {
# 			# If a result was found, update the table
# 			$sql = qq|UPDATE User_Event SET Date_Response='$Date', Invite_Status=3, UniqueID='', Num_Attendees=1 WHERE Event_User_ID=$Event_User_ID;|;
# 			if (&DB_Call($db,$sql)) {
# 				print qq|You've joined the event\n|;
# 			}
# 		} else { &LogOut(10, "ERROR: accept_game for non-extant game",$ErrorLog); }
# 	} else { &LogOut(10, "ERROR: accept_game",$ErrorLog)
# 	}
# 	&DB_Close($db);
# 	print qq|</td>\n|;
# }
# 
# sub add_game_friend {
# 	use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
# 	($sql) = @_;
# 	print "<td>\n";
# 	$Date = &GetTimeString();
# 	$GameFile = $in{'GameFile'};
# 	$sql = qq|SELECT * FROM User WHERE User_Email = '$in{'Email_Address'}';|;
# 	$db = &DB_Open($dsn);
# 	if (&DB_Call($db,$sql)) {
# 		while ($db->FetchRow()) {
# 			($Friend_ID, $Friend_Name, $Friend_Email) = $db->Data("User_ID", "User_Name", "User_Email");
# 		}
# 	} else { &LogOut(100, "ERROR in add_game_friend",$ErrorLog); }
# 	#email invitation to friend
# 	$inviteid = $secret_key . $Friend_ID;
# 	$inviteid = sha1_hex($inviteid);
# 	$Subject = $mail_prefix . 'Event Invitation';
# 	$Message = "\n\nYou have been invited to an Event!\n";
# 	$Message .= "To accept the invitation, select the link below:\n";
# 	$Message .= "$WWW_HomePage$Location_Scripts" . "/page.pl?lp=games&cp=accept_game&id=$inviteid";
# 	$smtp = &Mail_Open;
# 	&Mail_Send($smtp, $Friend_Email, $mail_from, $Subject, $Message);
# 	&Mail_Close($smtp);
# 	&LogOut(100,"ID: $id invited FriendID:$Friend_ID to Event:$GameFile",$LogFile);
# 	# update database with friends invite status
# 	$sql = qq|INSERT INTO User_Event ([GameFile], [User_ID], [Invite_Status], [UniqueID], [Date_Issued]) VALUES ($in{'GameFile'},$Friend_ID,1,'$inviteid','$Date');|;
# 	&LogOut(100,$sql,$LogFile);
# 	if (&DB_Call($db,$sql)) { print "<P>Invitation Sent to $Friend_Name\n"; 
# 	} else {}
# 	&Close_DB($db);
# 	print "</td>\n";
# }

sub list_players {
	($sql) = @_;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
			($GameFile, $User_ID, $User_Name, $Invite_Status) = $db->Data("GameFile", "User_ID", "User_Name", "Invite_Status");
			print qq|<a href="$Location_Scripts/page.pl?lp=$in{'lp'}&cp=show_friend&rp=&User_ID">$User_Name</a><br>\n|;
		}
	} else { &LogOut(10,"ERROR: Finding list_players",$ErrorLog); }
}
          
sub edit_game {
	my ($type) = @_;
	print "<td>";
	$db = &DB_Open($dsn);
	if ($type eq 'edit') {
		$sql = qq|SELECT * FROM Games WHERE GameFile = \'$in{'GameFile'}\' AND HostName = \'$userlogin\';|;
		%GameValues;
		if (&DB_Call($db,$sql)) {
			while ($db->FetchRow()) { %GameValues = $db->DataHash(); 
	#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			}
		}
	}

	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<TABLE><TR>\n|;
	print qq|		<TD>Game Name:</TD>\n|;
  if ($type eq 'create') {
	 print qq|		<TD><INPUT name="GameName" maxlength="30" | . &button_help("GameName") . qq| value="$GameValues{'GameName'}"> </TD><TD>(Mandatory)</TD>\n|;
  } else { print qq|		<TD>$GameValues{'GameName'}</TD><TD></TD>\n|;}
	print qq|	</TR><TR>\n|;
 	if ($type eq 'create') {
 		print qq|		<TD>Game File Name:</TD>\n|;
#180312 		print qq|<TD><INPUT name="GameFile" maxlength="8" | . &button_help("GameFile") . qq| value="$GameFile{'GameFile'}"> </TD><TD>(Will be random if blank)</TD>\n|;
 		print qq|<TD>Will be randomly created</TD><TD></TD>\n|;
 		print qq|</TR></TR>\n|;
 	}
	print qq|		<TD>Host User ID:</TD>\n|;
	print qq|<td><SELECT name=\"HostName\">|;
	if ($type eq 'edit') {
		print qq|<OPTION value="$GameValues{'HostName'}" SELECTED>$GameValues{'HostName'}</OPTION>\n|;
	} elsif ($type eq 'create') {
		print qq|<OPTION value="$userlogin" SELECTED>$userlogin</OPTION>\n|;
	}		
	# Let the user select from those with accounts (should it be only those playing the game?)
	$sql = "SELECT * FROM User;";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { %HostValues = $db->DataHash(); 
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			print qq|<OPTION value="$HostValues{'User_Login'}">$HostValues{'User_Login'}</OPTION>\n|;
		}
	}
	print qq|</SELECT></td>|;
	&DB_Close($db);

	print qq|</TR><TR>\n|;
	print qq|<TD>Game Description: </TD>\n|;
	print qq|<TD><TEXTAREA name=GameDescrip | . &button_help("GameDescrip") . qq| type=Text value="$GameValues{'GameDescrip'}">$GameValues{'GameDescrip'}</TEXTAREA></TD>\n|;
	print qq|</TR><TR>\n|;
  # print the player number options
	print qq|<TD>Max Players: </TD>\n|;
  print qq|<td><SELECT name="MaxPlayers"> | . &button_help("MaxPlayers") . qq|\n|;
 	if ($GameValues{'MaxPlayers'}) { print qq|<OPTION value=$GameValues{'MaxPlayers'} SELECTED>$GameValues{'MaxPlayers'}\n|; }
  else { print qq|<OPTION value=16 SELECTED>16\n|; }
 	foreach (my $i=1; $i <= 16; $i++) { print qq|<OPTION value=$i>$i\n|; }
 	print qq|</SELECT></td></tr><tr>\n|;
  print qq|<TD>Type of Game:</TD>\n|;
	print qq|</TR><TR><TD>\n|;
	my $daily, $hourly, $required, $allin;
	if ($GameValues{'GameType'} == 1)     { $daily = 1; }
	elsif ( $GameValues{'GameType'} == 2) { $hourly = 1; }
	elsif ( $GameValues{'GameType'} == 4) { $required =1; }
	elsif ( $GameValues{'GameType'} == 3) { $allin =1; }
	elsif ($type eq 'create') { $daily=1; }
	# Print out all of the hours of the day
	print qq|<table><tr><td align=left><INPUT name="GameType" type="radio" value=1 onFocus="Help( 'Daily' )" onMouseOver="Help( \'Daily\' )" onMouseOut="Help( \'blank\' )" $Checked[$daily]>Daily</td>\n|;
	print qq|<td><SELECT name=\"DailyTime\">\n|;
	for (my $i=0; $i < 24; $i++) {
		if ($i == $GameValues{'DailyTime'}) { 	print qq|<OPTION value=\"| . $i . qq|\" SELECTED>| . &fixdate($i) .  qq|:00 EST</OPTION>\n|; }
		# default select 9 pm.
		elsif ($type eq 'create' && $i == 21) { print qq|<OPTION value=\"| . $i . qq|\" SELECTED>| . &fixdate($i) .  qq|:00 EST</OPTION>\n|; }
		else { print qq|<OPTION value=\"| . $i . qq|\">| . &fixdate($i) .  qq|:00 EST</OPTION>\n|; }
	}
	print qq|</SELECT></td></tr>|;
	# print all the hourly options
	print qq|<tr><td align=left><INPUT name="GameType" type="radio" value=2 | . &button_help("Hourly") . qq| $Checked[$hourly]>Hourly</td>\n|;
	print qq|<td><SELECT name="HourlyTime">\n|;
	foreach my $key (@HourlyTime) { 
		if ($key == $GameValues{'HourlyTime'}) { print qq|<OPTION value=$key SELECTED>$key\n|; }
		elsif ($type eq 'create' && $key eq '48') { print qq|<OPTION value=$key SELECTED>$key\n|; }
		else { print qq|<OPTION value=$key>$key\n|;}
	}
	print qq|</SELECT></td></tr></table>\n|;

	print qq|<INPUT name="GameType" type="radio" value=3 | . &button_help("AsRequired") . qq| $Checked[$required]>As Required<BR>\n|;
	print qq|<INPUT name="GameType" type="radio" value=4 | . &button_help("AllIn") . qq| $Checked[$allin]>All In<BR>\n|;
	print qq|</TD></TR><TR><TD>\n|;

	# Select which days turns should generate
	if ($type eq 'create') { $GameValues{'DayFreq'} = $default_daily; }
	print qq|<b><U>Days Turns should Generate</U></b><BR>\n|;
	for (my $i=0; $i <7; $i++) {
		my $pos = substr($GameValues{'DayFreq'},$i,1);
		print qq|<INPUT type="checkbox" name="$WeekDays[$i]" value="$pos" | . &button_help("DayFreq") . qq| $Checked[$pos]>$WeekDays[$i]<BR>|;
	}
	print qq|</TD>\n|;
	print qq|</TR></TABLE>\n|;

	# Select the hours on which a turn should generate
	if ($type == 'create') { $GameValues{'HourFreq'} = $default_hourly;}
	if ($GameValues{'GameType'} == 2 || $type eq 'create') {
		print qq|<b><U>Hours Turns should Generate (ignored for daily games)</U></b><BR>\n|;
		print "<table><tr>\n";
		for (my $i = 0; $i <=23; $i++) {
			my $name = "hour" . $i;
			if ($i/12 == int($i/12)) { print "</tr><tr>"; }
			my $pos = substr($GameValues{'HourFreq'},$i,1);
			print qq|<td><INPUT type="checkbox" name="$name" value="$pos" onFocus="Help( 'HourFreq' )"  onMouseOver="Help( \'HourFreq\' )" onMouseOut="Help( \'blank\' )" $Checked[$pos]>$i:00<td>\n|;
		}
		print "</tr></table>\n";
	}
	print qq|<P>\n|;
	print qq|<INPUT type="checkbox" name="ForceGen" | . &button_help("EnableForceGen") . qq| $Checked[$GameValues{'ForceGen'}]>Enable Force Generate for\n|;
	# If ForceGenTurns isn't set, make the default 2. 
	unless ($GameValues{'ForceGenTurns'}) { $GameValues{'ForceGenTurns'} = 2; }
	print qq|<INPUT name="ForceGenTurns" size=3 | . &button_help("ForceGenTurns") . qq| value=$GameValues{'ForceGenTurns'}> turn(s) at a time\n|;
	# If ForceGenTurns isn't set, make the default 15
	unless ($GameValues{'ForceGenTimes'}) { $GameValues{'ForceGenTimes'} = 14; }
	print qq|<INPUT name="ForceGenTimes" size=3 | . &button_help("ForceGenTimes") . qq| value=$GameValues{'ForceGenTimes'}> times.</P>\n|;
	if ($type eq 'create') {$GameValues{'NumDelay'} = $default_numdelay; $GameValues{'MinDelay'} = $default_mindelay; }
	print qq|<INPUT type="checkbox" name="GameDelay" | . &button_help("GameDelay") . qq| $Checked[$GameValues{'GameDelay'}]>Players can Delay game\n|;
	print qq|<INPUT name="NumDelay" size=3 | . &button_help("NumDelay") . qq| value=$GameValues{'NumDelay'}> times.\n|;
	print qq|Delays reset when the sum drops below <INPUT name="MinDelay" size=3 | . &button_help("MinDelay") . qq| value=$GameValues{'MinDelay'}>.\n|;
	unless ($GameValues{'AutoInactive'}) { if ($type eq 'create') { $GameValues{'AutoInactive'} = 0; }}
	print qq|<P>Players will automatically go Inactive after missing <INPUT name="AutoInactive" size=2 | . &button_help("AutoInactive") . qq| value=$GameValues{'AutoInactive'}> turns ("0" is disabled).\n|;
  print qq|<P><TABLE><TR><TD>\n|;
	if ($type eq 'create') { $GameValues{'HostMod'} = 1; }
	print qq|<b><INPUT type="checkbox" name="HostMod" | . &button_help("HostMod") . qq| $Checked[$GameValues{'HostMod'}]>Host can Modify Game Settings</b>\n|;
	print qq|</TD><TD>\n|;
	# Default to generate if all turns are in
	unless ($GameValues{'AsAvailable'}) { if ($type eq 'create') { $GameValues{'AsAvailable'} = 1; }}
	print qq|<INPUT type="checkbox" name="AsAvailable" | . &button_help("AsAvailable") . qq| $Checked[$GameValues{'AsAvailable'}]>Generate As Available\n|;
	print qq|</TD><TD>\n|;
	print qq|<INPUT type="checkbox" name="OnlyIfAvailable" | . &button_help("OnlyIfAvailable") . qq| $Checked[$GameValues{'OnlyIfAvailable'}]>Generate ONLY if all turns are in\n|;
	print qq|</TD></TR><TR>\n|;
	print qq|<TD><INPUT type="checkbox" name="HostForceGen" | . &button_help("HostForceGen") . qq| $Checked[$GameValues{'HostForce'}]>Host can Force Generate</TD>\n|;
	# Default to No Duplicates when creating game
	unless ($GameValues{'NoDuplicates'}) { if ($type eq 'create') { $GameValues{'NoDuplicates'} = 1; }}
	print qq|<TD><INPUT type="checkbox" name="NoDuplicates" | . &button_help("NoDuplicates") . qq| $Checked[$GameValues{'NoDuplicates'}]>No Duplicate Players </TD>\n|;
	print qq|</TR><TR>\n|;
	# Default to Host can restore games from backup
	unless ($GameValues{'GameRestore'}) { if ($type eq 'create') { $GameValues{'GameRestore'} = 1; }}
	print qq|<TD><INPUT type="checkbox" name="GameRestore" | . &button_help("GameRestore") . qq| $Checked[$GameValues{'GameRestore'}]>Host can Restore Turns from Backup </TD>\n|;
	# Default to Anonymous Players
	unless ($GameValues{'AnonPlayer'}) { if ($type eq 'create') { $GameValues{'AnonPlayer'} = 1; }}
	print qq|<TD><INPUT type="checkbox" name="AnonPlayer" | . &button_help("AnonPlayer") . qq| $Checked[$GameValues{'AnonPlayer'}]>Anonymous Players</TD>\n|;
	print qq|</TR><TR>\n|;
	print qq|<TD><INPUT type="checkbox" name="GamePause" | . &button_help("GamePause") . qq| $Checked[$GameValues{'GamePause'}]>Players can Pause game</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="ObserveHoliday" | . &button_help("ObserveHoliday") . qq| $Checked[$GameValues{'ObserveHoliday'}]>Observe Holidays</TD>\n|;
	print qq|</TR><TR>\n|;
	print qq|<TD><INPUT type="checkbox" name="Newspaper" | . &button_help("NewsPaper") . qq| $Checked[$GameValues{'NewsPaper'}]>Galactic News	</TD>\n|;
	# BUG: Email submit isn't implemented
	#print qq|<TD><INPUT type="checkbox" name="EmailSubmit" | . &button_help("EmailSubmit") . qq| $Checked[$GameValues{'EmailSubmit'}]>Submit Via Email</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="SharedM" | . &button_help("SharedM") . qq| $Checked[$GameValues{'SharedM'}]>Shared M Files	</TD>\n|;
	print qq|</TR></TABLE>\n|;
	print qq|<P>Notes: <TEXTAREA name=Notes  rows=4 cols=80 | . &button_help("GameNotes") . qq| type=Text value="$GameValues{'Notes'}">$GameValues{'Notes'}</TEXTAREA>|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
	print qq|<input type=hidden name="rp" value="my_games">\n|;

	if ($type eq 'edit') {	
			print qq|<input type=hidden name="type" value="edit">\n|;
			print qq|<input type=hidden name="GameStatus" value="$GameValues{'GameStatus'}">\n|;
			print qq|<input type=hidden name="GameFile" value="$in{'GameFile'}">\n|; 
			print qq|<input type=hidden name="GameName" value="$in{'GameName'}">\n|; 
			print qq|<P><BUTTON $host_style type="submit" name="cp" value="Update Game">Update Game</BUTTON>\n|;
	}
	else { 
		print qq|<input type=hidden name="type" value="create">\n|; 
		print qq|<P><BUTTON $host_style type="submit" name="cp" value="Create Game">Create Game</BUTTON>\n|;
	}
 	print qq|</form></td>\n|;
}

sub delete_confirm {
	my ($GameFile) = @_;
	print "<td>";
	$db = &DB_Open($dsn);
	$sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\' AND HostName = \'$userlogin\';|;
	%GameValues;
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { %GameValues = $db->DataHash(); 
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
		}
	}
	&DB_Close($db);

  print qq|<H1>Delete Game: $GameValues{'GameName'}</H1>|;
	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|Confirm you want to delete \"$GameValues{'GameName'}\", File name $GameFile\n|;
	print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|; 
	print qq|<P><BUTTON $host_style type="submit" name="cp" value="delete_game">DELETE</BUTTON>\n|;
	print qq|<BUTTON $user_style type="submit" name="cp" value="show_games">CANCEL</BUTTON>\n|;
  print qq|<input type=hidden name="lp" value="game">\n|; 
 	print qq|</FORM></td>\n|;
}

sub delete_game {
	my ($GameFile) = @_;
	print "<td>";
	my $db = &DB_Open($dsn);
	my $sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\' AND HostName = \'$userlogin\';|;
	my %GameValues;
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { %GameValues = $db->DataHash(); 
			#while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
		}
	}
  # Confirm that the user logged in is the host, and that the game returns from the sql query 
  # matches the request
  if ($userlogin eq ($GameValues{'HostName'}) && ($GameValues{'GameFile'} eq $GameFile) && $GameFile) {
    # Delete the entries from the Games database
    $sql = qq|DELETE Games.GameFile, Games.HostName FROM Games WHERE Games.GameFile=\'$GameValues{'GameFile'}\' AND Games.HostName=\'$userlogin\';|;
  	&DB_Call($db,$sql);
    print qq|<P>Game database entries deleted for: $GameValues{'GameName'}.\n|;
    # Delete the entries from the GameUser database
    # (Shoulnd't be necessary, as the relationship should take them out
    $sql = qq|DELETE GameUsers.GameFile, Games.HostName FROM GameUsers WHERE GameUsers.GameFile=\'$GameValues{'GameFile'}\';|;
   	&DB_Call($db,$sql);
    print qq|<P>Game user database entries deleted for: $GameValues{'GameName'}.\n|;
  	&DB_Close($db);
  
    # Delete the files, carefully using the database values, not the user input.
    $dir = $File_HST . '/' . $GameValues{'GameFile'};
    # Get the functions to remove a directory
    use File::Path 'rmtree';
    if(-e $dir && $GameValues{'GameFile'} && (length($GameValues{'GameFile'}) > 0)) { 
      
      rmtree(&clean($dir));
#      print "<P>$dir\n";
      print "<P>Game files deleted for: $GameValues{'GameName'}.";
    } else { 
      print "<P>Game Directory $GameValues{'GameFile'} Does not Exist."; 
      &LogOut(0,"Delete of Game Directory $GameValues{'GameFile'} by $userlogin failed as it does not exist.",$ErrorLog);
    }

    print qq|<P>Game \"$GameValues{'GameName'}\" Deleted!</H1>|;
    &LogOut(0,"$GameValues{'GameName'}, $GameValues{'GameFile'} Deleted by $userlogin",$ErrorLog);
  } else { 
    print "<P>Failed to delete $GameFile, $GameValues{'GameName'}, $GameValues{'GameFile'} for $userlogin\n";
    &LogOut(0,"$GameValues{'GameName'}, $GameValues{'GameFile'} FAILED TO DELETE by $userlogin",$ErrorLog);
  }
 	print qq|</td>\n|;
}


sub update_game {
#180312	my ($GameFile) = @_;
	$in{'GameName'} = &clean($in{'GameName'});
	$in{'GameDescrip'} = &clean($in{'GameDescrip'});
  my $GameFile =  $in{'GameFile'};
  # set boundaries on MaxPlayers
  if ($in{'MaxPlayers'} < 0 | $in{'MaxPlayers'} > 16) { $in{'MaxPlayers'} = 16;}
  else { $MaxPlayers = $in{'MaxPlayers'}; }
	my $DayFreq = &MakeDayFreq; #defaults to Sunday
	my $HourFreq = &MakeHourFreq; 
	if (!$in{'HourlyTime'}) { $in{'HourlyTime'} = '24'; } # If time hasn't been set, make the default 24 hours
	my $GameStatus = $in{'GameStatus'};
	my $AsAvailable = &checkboxnull($in{'AsAvailable'});
	my $OnlyIfAvailable = &checkboxnull($in{'OnlyIfAvailable'});
	my $ForceGen = &checkboxnull($in{'ForceGen'});
	my $ForceGenTurns = &checknull($in{'ForceGenTurns'});
	my $ForceGenTimes = &checknull($in{'ForceGenTimes'});
  #Prevent abuse of ForceGen
  if  (($ForceGenTurns * $ForceGenTimes ) > 500) {
    if ($ForceGenTurns > 10) { $ForceGenTurns = 10; }
    if ($ForceGenTimes > 50) { $ForceGenTime = 50; }
  }
  my $AutoInactive = $in{'AutoInactive'}; 
  # Validate AutoInactive
  $AutoInactive = &clean($AutoInactive);
  if ($AutoInactive =~ /^\d+\z/) {} else { $AutoInactive = 0; };
	my $HostMod = &checkboxnull($in{'HostMod'}); 
	my $HostForceGen = &checkboxnull($in{'HostForceGen'}); 
	my $NoDuplicates = &checkboxnull($in{'NoDuplicates'});
	my $GameRestore = &checkboxnull($in{'GameRestore'});
	my $AnonPlayer = &checkboxnull($in{'AnonPlayer'});
	my $GamePause = &checkboxnull($in{'GamePause'});
	my $GameDelay = &checkboxnull($in{'GameDelay'});
	my $NumDelay = &checknull($in{'NumDelay'});
	my $MinDelay = &checknull($in{'MinDelay'});
	my $ObserveHoliday = &checkboxnull($in{'ObserveHoliday'});
	my $NewsPaper = &checkboxnull($in{'Newspaper'});
	my $SharedM = &checkboxnull($in{'SharedM'});
	$in{'Notes'} = &clean($in{'Notes'});

 	$db = &DB_Open($dsn);
	if ($in{'type'} eq 'edit') {
   	my $sql = qq|Update Games  SET 
								GameDescrip = '$in{'GameDescrip'}',
								DailyTime = $in{'DailyTime'},  
								HourlyTime = '$in{'HourlyTime'}', 
						 		GameType = $in{'GameType'}, 
								GameStatus = $GameStatus, 
								AsAvailable = '$AsAvailable',  
								OnlyIfAvailable = '$OnlyIfAvailable',
								DayFreq = '$DayFreq', 
								HourFreq = '$HourFreq', 
								ForceGen= '$ForceGen',  
								ForceGenTurns = $ForceGenTurns, 
								ForceGenTimes = $ForceGenTimes,   
								HostMod = '$HostMod', 
								HostForce = '$HostForceGen',
								NoDuplicates = '$NoDuplicates',  
								GameRestore = '$GameRestore',
								AnonPlayer = '$AnonPlayer',
								GamePause = '$GamePause',
								GameDelay = '$GameDelay', 
								NumDelay = $NumDelay, 
								MinDelay = $MinDelay, 
								ObserveHoliday = '$ObserveHoliday',
								NewsPaper = '$NewsPaper',
								SharedM = '$SharedM',
								Notes = '$in{'Notes'}', 
								MaxPlayers = $MaxPlayers, 
                AutoInactive = $AutoInactive
								WHERE GameFile = '$GameFile' AND HostName = '$userlogin';|;
		if (&DB_Call($db,$sql)) { 
      print "<P>Game Updated!\n"; 
      #Get the game values for emailing edit information.
      # And email all the players that the game has changed.
      $sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|;
    	if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
     	# Notify all players who want to be notified that the game status has changed. 
    	$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Game Parameters Edited|;
    	$GameValues{'Message'} = "Game Parameters have been edited for $GameValues{'GameName'} ($GameFile). Please review Game page for any changes.\n";
    	&Email_Turns($GameFile, \%GameValues, 0);
    } else { print "Update failed\n"; &LogOut(0,"$in{'GameName'} update failed for $userlogin", $ErrorLog); }
	} elsif ($in{'type'} eq 'create') {
#180312		$CleanGameFile = &clean_filename($GameFile);
#180312		&LogOut(200,"update_game GF $GameFile CGF $CleanGameFile",$LogFile);
#180312		# If the file name isn't ok, create a random one.
#180312		unless ($CleanGameFile) {
			# Need to create a random gamefile name
			use Digest::SHA1  qw(sha1_hex);
			$CleanGameFile = substr(sha1_hex(time()), 5, 8); # Should be random enough
			&LogOut(50,"Creating random GameFile $CleanGameFile for $in{'GameName'}",$LogFile);
#180312		}
		my $sql = qq|INSERT INTO Games (GameFile,HostName,GameName,GameDescrip,DailyTime,HourlyTime,GameType,GameStatus,AsAvailable,OnlyIfAvailable,DayFreq,HourFreq,ForceGen,ForceGenTurns,ForceGenTimes,HostMod,HostForce,NoDuplicates,GameRestore,AnonPlayer,GamePause,GameDelay,NumDelay,MinDelay,ObserveHoliday,NewsPaper,SharedM,Notes,MaxPlayers) VALUES ('$CleanGameFile','$userlogin','$in{'GameName'}','$in{'GameDescrip'}',$in{'DailyTime'},'$in{'HourlyTime'}',$in{'GameType'},6,'$AsAvailable','$OnlyIfAvailable','$DayFreq','$HourFreq','$ForceGen',$ForceGenTurns,$ForceGenTimes,'$HostMod','$HostForceGen','$NoDuplicates','$GameRestore','$AnonPlayer','$GamePause','$GameDelay',$NumDelay, $MinDelay,'$ObserveHoliday','$NewsPaper','$SharedM','$in{'Notes'}',$MaxPlayers);|;
		if (&DB_Call($db,$sql)) { } 
		else { 
      print "Create failed\n"; 
      &LogOut(0,"$in{'GameFile'} create failed with $sql for $userlogin", $ErrorLog);
#      $CleanGameFile = "Game Creation Failed. Please Try Again.";
      $CleanGameFile = "CREATE FAILED";
    }
	}
  &DB_Close($db);
	return $CleanGameFile; 
}

sub create_game_size {
	my ($GameFile, $GameName) = @_;
	print <<eof;
<H2>Game Parameters For $GameName</H2>
<FORM action="$Location_Scripts/page.pl" method=$FormMethod>
	<TABLE cellpadding="2">
		<TR><TH>Size</TH><TH>Position</TH><TH>Density</TH><TH></TH></TR>
		<TR>
			<TD>
				<INPUT type="Radio" name="Size" value="0" title="Tiny">Tiny<BR>
				<INPUT type="Radio" name="Size" value="1" title="Small">Small<BR>
				<INPUT type="Radio" name="Size" value="2" title="Medium" checked>Medium<BR>
				<INPUT type="Radio" name="Size" value="3" title="Large">Large<BR>
				<INPUT type="Radio" name="Size" value="4" title="Huge">Huge<BR>
			</TD>
			<TD>
				<INPUT type="Radio" name="Distance" value="0" title="Close">Close<BR>
				<INPUT type="Radio" name="Distance" value="1" title="Moderate">Moderate<BR>
				<INPUT type="Radio" name="Distance" value="2" title="Farther">Farther<BR>
				<INPUT type="Radio" name="Distance" value="3" title="Distant" CHECKED>Distant
			</TD>
			<TD>
				<INPUT type="Radio" name="Density" value="0" title="Sparse">Sparse<BR>
				<INPUT type="Radio" name="Density" value="1" title="Normal">Normal<BR>
				<INPUT type="Radio" name="Density" value="2" title="Dense" checked>Dense<BR>
				<INPUT type="Radio" name="Density" value="3" title="Packed">Packed
			</TD>
			<TD>
				<INPUT type="Checkbox" name="Beginner" title="Beginner: Maximum Minerals">Beginner: Maximum Minerals<BR>
				<INPUT type="Checkbox" name="SlowTech" title="Slower Tech Advances" checked>Slower Tech Advances<BR>
				<INPUT type="Checkbox" name="AccelBBS" title="Accelerated BBS Play" checked>Accelerated BBS Play<BR>
				<INPUT type="Checkbox" name="NoRandom" title="No Random Events">No Random Events<BR>
				<INPUT type="Checkbox" name="Alliance" title="Computer Players form Alliances">Computer Players form Alliances<BR>
				<INPUT type="Checkbox" name="PublicScores" title="Public Player Scores">Public Player Scores<BR>
				<INPUT type="Checkbox" name="Clumping" title="Clumping">Galaxy Clumping<BR>
			</TD>
		</TR>
	</TABLE>

<P>Victory is declared when a player:</P>
eof

   #Own x planets
	print qq|<INPUT type="Checkbox" name="BoxPlanets" CHECKED>Owns\n|;
	print qq|<SELECT name="Planets">\n|;
	&optionloop(20,100,5,100);
	print qq|</SELECT>% of all planets<BR>\n|;
	#Attains x tech in y fields
	print qq|<INPUT type=\"Checkbox\" name=\"BoxTech\">Attains Tech\n|;
	print qq|<SELECT name=\"Tech\">\n|;
	&optionloop(8,26,1,22);
	print qq|</SELECT> in\n|;
	print qq|<SELECT name=\"TechFields\">\n|;
	&optionloop(2,6,1,4);
	print qq|</SELECT>fields.<BR>\n|;
	#exceeds score
	print qq|<INPUT type=\"Checkbox\" name=\"BoxScore\">Exceeds a score of\n|;
	print qq|<SELECT name=\"Score\">\n|;
	&optionloop(1000,20000,1000,11000);
	print qq|</SELECT><BR>\n|;
	#exceeds second place score
	print qq|<INPUT type=\"Checkbox\" name=\"BoxSecondScore\" selected>Exceeds second place score by\n|;
	print qq|<SELECT name=\"SecondScore\">\n|;
	&optionloop(10,100,10,100);
	print qq|</SELECT>%<BR>\n|;
	#production capacity
	print qq|<INPUT type=\"Checkbox\" name=\"BoxProduction\">Has a production capacity of\n|;
	print qq|<SELECT name=\"Production\">\n|;
	&optionloop(10,500,10,100);
	print qq|</SELECT>thousand.<BR>\n|;
	#Owns capital ships
	print qq|<INPUT type=\"Checkbox\" name=\"BoxCapital\">Owns\n|;
	print qq|<SELECT name=\"Capital\">\n|;
	&optionloop(10,300,10,100);
	print qq|</SELECT>capital ships.<BR>\n|;
	#highest score
	print qq|<INPUT type=\"Checkbox\" name=\"BoxHighScore\">Has the highest score after\n|;
	print qq|<SELECT name=\"HighScore\">\n|;
	&optionloop(30,900,10,100);
	print qq|</SELECT>years.<br>\n|;
	#Winner must meet x criteria
	print qq|Winner must meet <SELECT name=\"Criteria\">\n|;
	&optionloop(1,3,1,1);
	print qq|</SELECT>of the above criteria.<BR>\n|;
	#X years must pass
	print qq|At least <SELECT name=\"Years\">\n|;
	&optionloop(30,500,10,50);
	print qq|</SELECT>years must pass before a winner is declared.<BR>\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
#	print qq|<input type=hidden name="rp" value="my_games">\n|;
	print qq|<input type=hidden name="GameFile" value="$GameFile">\n|; 
  #Notify Email List
	print qq|<P><INPUT type="Checkbox" name="NotifyList" | . &button_help("NotifyList") . qq|CHECKED>Notify Email List for New Game Notification\n|;
  #
	print qq|<P><BUTTON $host_style type="submit" name="cp" value="Create DEF File">Create DEF File</BUTTON>\n|; 
	print qq|</FORM>\n|;
}

sub create_game_def {
	my ($GameFile) = @_;
	my $GameDEF = $File_HST . '/' . $GameFile . '/' . $GameFile . '.def';
	my $GameXY = $FileHST . '\\' . $GameFile . '\\' . $GameFile . '.xy';
	my $GameDEFAppend = ">>" . $GameDEF;
	my $GameDEFCreate = ">" . $GameDEF;

	# Write To file
	if (-e $GameDEF) { #if there is already a .def file error out
		&LogOut(0, "Failed to write $GameDEF for $userlogin",$ErrorLog); 
#		die ('There is already a $GameDEF file.'); 
	}
	else { #if not, make one
		# Create the directory
		my $HST_Location = $File_HST . '/' . $GameFile;
		mkdir $HST_Location || &LogOut(0, "Cannot create $HST_Location, $userlogin", $ErrorLog); 
	
		# Create the def file
		open (DEFOUT, $GameDEFCreate) || &LogOut(0, "Cannot create $GameDEF file, $userlogin", $ErrorLog);
    $db = &DB_Open($dsn);
    # Get the name of the game
		$sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\' AND HostName ='$userlogin';|;
		if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { %GameValues = $db->DataHash(); } }
 
		print DEFOUT "$GameValues{'GameName'}\n";
		$Size = $in{'Size'};
		$Distance = $in{'Distance'};
		$Density = $in{'Density'};
		print DEFOUT "$Size $Density $Distance\n";
	
		$Beginner = &checkboxnull($in{'Beginner'});
		$SlowTech = &checkboxnull($in{'SlowTech'});
		$AccelBBS = &checkboxnull($in{'AccelBBS'});
		$NoRandom = &checkboxnull($in{'NoRandom'});
		$Alliance = &checkboxnull($in{'Alliance'});
		$PublicScores = &checkboxnull($in{'PublicScores'});
		$Clumping = &checkboxnull($in{'Clumping'});
		print DEFOUT "$Beginner $SlowTech $AccelBBS $NoRandom $Alliance $PublicScores $Clumping\n";
		# Currently there are no players, so include that
		print DEFOUT "0\n";

		$BoxPlanets = &checkboxnull($in{'BoxPlanets'});
		$BoxTech = &checkboxnull($in{'BoxTech'});
		$BoxScore = &checkboxnull($in{'BoxScore'});
		$BoxSecondScore = &checkboxnull($in{'BoxSecondScore'});
		$BoxProduction = &checkboxnull($in{'BoxProduction'});
		$BoxCapital= &checkboxnull($in{'BoxCapital'});
		$BoxHighScore = &checkboxnull($in{'BoxHighScore'});
	
		# Output to file win conditions;
		print DEFOUT "$BoxPlanets $in{'Planets'}\n";
		print DEFOUT "$BoxTech $in{'Tech'} $in{'TechFields'}\n";
		print DEFOUT "$BoxScore $in{'Score'}\n";
		print DEFOUT "$BoxSecondScore $in{'SecondScore'}\n";
		print DEFOUT "$BoxProduction $in{'Production'}\n";
		print DEFOUT "$BoxCapital $in{'Capital'}\n";
		print DEFOUT "$BoxHighScore $in{'HighScore'}\n";
		print DEFOUT "$in{'Criteria'} $in{'Years'}\n";
		print DEFOUT "$GameXY\n";
		# Close file
		close (DEFOUT);
		# update the database to reflect that the def file is created for this game
		my $sql = qq|UPDATE Games SET GameStatus = 7 WHERE GameFile = \'$GameFile\' AND HostName ='$userlogin';|;
		&DB_Call($db,$sql);
    
    # Email all players with new game email notification enabled
    # in their profile that there's a new game
    # If the option to notify was selected
    if (&checkboxnull($in{'NotifyList'})) {
      my %UserValues;
      my $Subject = "$mail_prefix New Game: $GameValues{'GameName'}";
      my $Message = "A new game has been created on Stars! TotalHost ($WWW_HomePage). Log In and check it out!\n\n";
      $Message .= $GameValues{'Notes'};
      $Message .= "\n\n";
      # Acquire all of the appropriate users
      $sql = qq|SELECT * FROM User WHERE EmailList=1;|;
      if (&DB_Call($db,$sql)) {
        while ($db->FetchRow()) {
          %UserValues = $db->DataHash();
      #			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
          # Email all the players
          &LogOut(200,"Emailing player about new game $GameValues{'GameName'} $GameValues{'GameFile'}: $UserValues{'User_Login'}, $mail_from, $Subject, $Message",$LogFile);
          $smtp = &Mail_Open;
          &Mail_Send($smtp, $UserValues{'User_Email'}, $mail_from, $Subject, $Message);
          &Mail_Close($smtp);
        }
      }
    }
    &DB_Close($db);
	}
}

sub MakeDayFreq { #Make the day turn frequency
  #Needs to Build turn freq here
  $Sunday = &checkboxnull($in{'Sun.'});
  $Monday = &checkboxnull($in{'Mon.'});
  $Tuesday = &checkboxnull($in{'Tues.'});
  $Wednesday = &checkboxnull($in{'Wed.'});
  $Thursday = &checkboxnull($in{'Thurs.'});
  $Friday = &checkboxnull($in{'Fri.'});
  $Saturday = &checkboxnull($in{'Sat.'});
  $DayFreq = $Sunday . $Monday . $Tuesday . $Wednesday . $Thursday . $Friday . $Saturday;
  if ($DayFreq eq '0000000') { $DayFreq = '1000000'; } #default to Sunday if nothing is selected
  return($DayFreq);
}

sub MakeHourFreq { #Make the hour turn frequency
	my @hour;
	my $HourFreq = ""; 
	for (my $i = 0; $i <=23; $i++) {
		$h = "hour" . $i;
		$hour[$i] = &checkboxnull($in{"$h"});
		$HourFreq = $HourFreq . $hour[$i];
	}
	if ($HourFreq eq '000000000000000000000000') { $DayFreq = '000000001111111111111100'; } #default to not after 10
	return($HourFreq);
}

sub read_def {
	my ($game_file) = @_;
	my @Universe, @Victory;
	my @Universe_Size = qw(Tiny Small Medium Large Huge);
	my @Density = qw(Sparse Normal Dense Packed);
	my @Positions = qw(Close Moderate Farther Distant);
	my $def_file = "$File_HST/$game_file/$game_file.def"; 
	my @def_data = ();
	if (-e $def_file) { #Check to see if file is there.
		open (IN_FILE,$def_file);
		chomp(@def_data = <IN_FILE>);
		close(IN_FILE);
		my $GameName = $def_data[0]; 
		my ($univ_size, $univ_dense, $univ_start, $univ_random) =  split(' ',$def_data[1]);
		my ($univ_mins, $univ_slowtech, $univ_bbs, $univ_norandom, $univ_alliance, $univ_public, $univ_clumping) = split(' ',$def_data[2]);
		my $num_players = $def_data[3];
		my $skip = 4 + $num_players;
		my ($vc_planets, $vc_percent) = split(' ',$def_data[$skip]);
		my ($vc_tech, $vc_techlevel, $vc_techfields) = split(' ',$def_data[$skip+1]);
		my ($vc_score, $vc_scoreamt) = split(' ',$def_data[$skip+2]);
		my ($vc_exceed, $vc_exceed_percent) = split(' ',$def_data[$skip+3]);
		my ($vc_prod, $vc_prodcapacity) = split(' ',$def_data[$skip+4]);
		my ($vc_capital, $vc_capitalnum) = split(' ',$def_data[$skip+5]);
		my ($vc_turns, $vc_years) = split(' ',$def_data[$skip+6]);
		my ($vc_meet, $vc_minyears) = split(' ',$def_data[$skip+7]);
		my $gamefile = $def_data[$skip+8];
		my @Vals = ();
		push (@Vals, "$Universe_Size[$univ_size] Universe");
	 	push (@Vals, "$Density[$univ_dense] Density");
		push (@Vals, "$Positions[$univ_start] Players");
		# I don't really want to display this!
	#	if ($univ_random) { push(@Vals, "Game Seed: $univ_random"); }
	 	if ($univ_mins) { push (@Vals, "Max Mins"); }
	 	if ($univ_slowtech) { push (@Vals, "Slow Tech"); }
	 	if ($univ_bbs) { push (@Vals, "Accel. BBS"); }
	 	if ($univ_norandom) { push (@Vals, "No Random"); }
		if ($univ_alliance) { push (@Vals, "AIs Ally"); }
		if ($univ_public) { push (@Vals, "Public Scores"); }
		if ($univ_clumping) { push (@Vals, "Galaxy Clump"); }

		if ($vc_planets) { push (@Vals, "Owns $vc_percent% of all planets"); }
		if ($vc_tech) { push (@Vals, "Attains Tech $vc_techlevel in $vc_techfields fields"); }
		if ($vc_score) { push (@Vals, "Exceeds a score of $vc_scoreamt"); }
		if ($vc_exceed) { push (@Vals, "Exceeds 2nd place score by $vc_exceed_percent%"); }
	 	if ($vc_prod) { push (@Vals, "Production capacity of $vc_prod,000"); }
		if ($vc_capital) { push (@Vals, "Owns $vc_capitalnum capital ships"); }
		if ($vc_turns) { push (@Vals, "Highest score after $vc_years years"); }
		push (@Vals, "Meet $vc_meet victory criteria after $vc_minyears years");
		my $c = 0;
		my $col=3;
		print "\n<P><B>Stars! Settings:</B>\n";
		print qq|<table border=1 width=100% style="font-size:0.8em;">|;
		print qq|<tr>|;
		foreach my $key (@Vals) {
			print "<td>$key</td>";$c++;
			if ($c/$col == int($c/$col)) { print qq|</tr><tr>|; }
		}	
		print qq|</tr></table>|;
	} else { 
		print "<P>Game Definition File not found!\n"; 
		&LogOut(0,"Game Definition File $def_file not found for $userlogin",$ErrorLog);
	}
 	return \@Universe, \@Victory;
}

sub read_game {
	# Read in the game paramenters and create a table
	my ($game_file) = @_;
	my $sql = qq|SELECT * FROM Games WHERE Gamefile = \'$game_file\';|;
	my %GameValues;
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
	&DB_Close($db);
	my @Values = ();
	if     ($GameValues{'GameType'} == 1) { push(@Values, "Daily Turn Gen, $GameValues{'DailyTime'}:00"); }
	elsif ( $GameValues{'GameType'} == 2) { push(@Values, "Hourly Turn Gen, $GameValues{'DailyTime'} hours");}
	elsif ( $GameValues{'GameType'} == 3) { push(@Values, "Turns Gen Only when All Turns are In"); }
	elsif ( $GameValues{'GameType'} == 4) { push(@Values, "Turns as Required"); }
	else { push(@Values, "Unknown Turn Gen"); }	
	if (&checkbox($GameValues{'ForceGen'})) { 
		my $str = "ForceGen $GameValues{'ForceGenTurns'} Turns at a Time $GameValues{'ForceGenTimes'} Time(s)";
		push (@Values, "$str");
	}
	if ($GameValues{'HostMod'}) { push (@Values, "Host can Modify Game Settings"); }
	if ($GameValues{'AsAvailable'}) { push (@Values, "Will Generate if All Turns are In"); }
	if ($GameValues{'OnlyIfAvailable'}) { push (@Values, "Generate ONLY if All Turns Are In"); }
	if ($GameValues{'HostForce'}) { push (@Values, "Host can Force Generate"); }
	if ($GameValues{'NoDuplicates'}) { push (@Values, "No Duplicate Players"); }
	if ($GameValues{'GameRestore'}) { push (@Values, "Host can Restore Turns from Backup"); }
	if ($GameValues{'AnonPlayer'}) { push (@Values, "Anonymous Players"); }
	if ($GameValues{'GamePause'}) { push (@Values, "Players can Pause Game"); }
	if ($GameValues{'GameDelay'}) { push (@Values, "Players can Delay up to $GameValues{'NumDelay'} Times, Reset Min. $GameValues{'MinDelay'}"); }
	if ($GameValues{'ObserveHoliday'}) { push (@Values, "Observe Holidays"); }
	if ($GameValues{'NewsPaper'}) { push (@Values, "Galactic News"); }
	if ($GameValues{'SharedM'}) { push (@Values, "Shared M Files"); }
	if ($GameValues{'AutoInactive'}) { push (@Values, "AutoInactive after $GameValues{'AutoInactive'} turns missed"); }
	if ($GameValues{'MaxPlayers'}) { push (@Values, "Max $GameValues{'MaxPlayers'} players allowed to join"); }
	my $c = 0;
	my $col=3;
	print "<P><B>TotalHost Settings:</B>\n";
	print qq|<table border=1 width=100% style="font-size:0.8em;">|;
	print qq|<tr>|;
	foreach my $key (@Values) { 
		print "<td>$key</td>"; $c++;
		if ($c/$col == int($c/$col)) { print qq|</tr><tr>|; }
	}
	print qq|</tr></table>|;
 	return @Values;
}

sub show_restore {
	# Build the page for restoring a game
	my ($GameFile) = @_;
  my %GameValues;
	my $BackupDir = $File_HST . '/' . $GameFile;
	# Read in all the directories to build the options
	opendir(DIRS, $BackupDir) || die("Cannot open $BackupDir\n"); 
	@AllDirs = readdir(DIRS);
	closedir(DIRS);
	$db = &DB_Open($dsn);
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
	&DB_Close($db);
  print qq|<h2>Restore Game for: $GameValues{'GameName'}</h2>\n|;
 	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
	print qq|<table><tr>\n|;
	print qq|<td>Restore to Game Year</td>\n|;
 	print qq|<td><SELECT name="restore_year">\n|;
 	foreach $name (@AllDirs) {
 		if ($name =~ /\./) {  next; } # No need to display the .
 		if ($name =~ /^BACKUP.*/) {  next; }   # No need to display the singular Backup folder
 		$bck = $BackupDir . '/' . $name;
 		if (-d $bck) { print qq|<OPTION value=$name>$name</OPTION>\n|; }
 	}
	print qq|</SELECT></td>\n|;
 	print qq|<td><INPUT type=\"hidden\" name=\"GameFile\" value =\"$GameFile\"></td>\n|;
	print qq|</tr><tr>\n|;
	print qq|<td><INPUT type="submit" name="cp" value="Process Restore" onMouseOver="Help( \'GameRestore\' )" onMouseOut="Help( \'blank\' )"></td>\n|;
	print qq|</tr></table>\n|;
	print qq|</form>\n|;
}

sub process_restore {
	($GameFile,$restore_year) = @_;
	use File::Copy;
  
  $db = &DB_Open($dsn);
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
	&DB_Close($db);
  
	print "<br>Restoring Game Year $restore_year for: $GameValues{'GameName'}....\n";
	&LogOut(49, "Restoring Game Year $restore_year for $GameFile",$LogFile);
	my $Backup_Source        = $File_HST . '/' . $GameFile . '/' . $restore_year;
	my $Backup_Destination   = $File_HST . '/' . $GameFile;

	# Remove .x files, as they'll potentially be from the wrong turn and muck things up
	&LogOut(100,"Removing any extraneous .x files  from $Backup_Destination...",$LogFile);
	opendir(DIR, $Backup_Destination) or die "<P>Can\'t opendir $Backup_Destination to remove .x files!\n"; 
	@AllFiles = readdir(DIR);
	closedir(DIR);
	# all directories are files, but not all files are directories
	foreach $file (@AllFiles) {
	 	my $Backup_Destination_File = $Backup_Destination . '/' . $file;
		if ($file =~ /^\./) { next; } # Skip the things I don't want to process
		if ($file =~ /^\.\./) { next; } # Skip the things I don't want to process
		if ($file =~ /\.XY/) { next; } # Skip the things I don't want to process
		unless (-d "$Backup_Destination_File") {
			# It would be nice to narrow this down to only the range of .x files from 1-16
			# but my skills at regexp escape me
			if ($file =~ /^.*\.X.*/) {
				&LogOut(100,"Deleting File: $file: $Backup_Destination_File",$LogFile);
				unlink($Backup_Destination_File);
			}
		}
	}
	# Restore files from backup
	opendir(DIR, $Backup_Source) or die "<P>Can\'t opendir $Backup_Source for Restore!\n"; 
	while (defined($file = readdir(DIR))) {
 		next unless (-f "$Backup_Source/$file");
	 	my $Backup_Source_File      = $Backup_Source . '/' . $file;
	 	my $Backup_Destination_File = $Backup_Destination . '/' . $file; 
	 	copy($Backup_Source_File, $Backup_Destination_File);
		&LogOut(100,"Copy $Backup_Source_File to $Backup_Destination_File",$LogFile);
	}
	closedir(DIR);
	print "<P>Game restored!\n";
	# Notify all players who want to be notified that the game status has changed. 
	$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Restored from Backup|;
	$GameValues{'Message'} = "Game: $GameValues{'GameName'} restored to year $restore_year.\n";
	&Email_Turns($GameFile, \%GameValues, 0);

}

sub process_game_status {
	# Change the current game state and report such.
  # $sql doesn't really do anything, as nothing actually passes a $sql string,
  #   must be from an architecture change a while ago
	my ($GameFile, $sql, $state) = @_;
	my $success =0; 
	$db = &DB_Open($dsn);
  # Get the information about the game in question
  # Since this can be reached by players (Pause) needs to not filter for $userlogin
  $sql_local = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|;
	if (&DB_Call($db,$sql_local)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
  my $state_set = 0;
	if ($state eq 'Pause') {
    if ($GameValues{'GamePause'}) {
      # If players are allowed to pause the game
      $sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET Games.GameStatus = 4 WHERE Games.GameFile = \'$in{'GameFile'}\' AND GameUsers.User_Login=\'$userlogin\' AND Games.GamePause=1;|;
      $GameValues{'GameStatus'} = 4; # When used later
      $state_set = 1;
    } else {
      # Only the host can update the game
      $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
      $GameValues{'GameStatus'} = 4; # When used later
      $state_set = 1;
    }
    # Rebuild the .CHK file in case there's a problem
    &Make_CHK($GameValues{'GameFile'});
  } elsif ($state eq 'UnPause') {
    # Try to figure out when the next turn is due and update the date so
    # it doesn't just start generating
		($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs) = &GetTime; 
		if ($GameValues{'GameType'} == 1 ) {     
			# Determine when the next possible time is that turns are due
			($DaysToAdd1, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$WeekDay);
			# now advance one interval from that, so you have a full interval
			($DaysToAdd2, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$NextDayOfWeek);
			# Set the time for the next turn on the right day
			$NewTurn = $CurrentDateSecs + $DaysToAdd1*86400 + $DaysToAdd2*86400 +($GameValues{'DailyTime'} *60*60); 
      if (!$isDST) { $NewTurn = $NewTurn + (60*60); }
      $GameValues{'GameStatus'} = 2; # So the value is changed if used later before a query.
			$sql = qq|UPDATE Games SET GameStatus = 2, NextTurn = $NewTurn WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
      $GameValues{'GameStatus'} = 2; # When used later
      $state_set = 1;
		} else { # BUG: Doesn't fix next turn for other game types
			$sql = qq|UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
      $GameValues{'GameStatus'} = 2; # When used later
      $state_set = 1;
		}
    # Rebuild the .CHK file in case there's a problem
    &Make_CHK($GameValues{'GameFile'});
  } elsif ($state eq 'Lock') {
   	$sql = qq|UPDATE Games SET GameStatus = 0 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 0; # When used later
    $state_set = 1;
  } elsif ($state eq 'Launched') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
    # Rebuild the .CHK file in case there's a problem
    &Make_CHK($GameValues{'GameFile'});
  } elsif ($state eq 'Unlocked') {
    $sql = qq|UPDATE Games SET GameStatus = 7 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 7; # When used later
    $state_set = 1;
  } elsif ($state eq 'Ended') {
    $sql = qq|UPDATE Games SET GameStatus = 9 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\';|;
    $GameValues{'GameStatus'} = 9; # When used later
    $state_set = 1;
  } elsif ($state eq 'Restart') {
    $sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameValues{'GameFile'}\' AND HostName=\'$userlogin\' AND GameStatus = 9;|;
    $GameValues{'GameStatus'} = 4; # When used later
    $state_set = 1;
  } else {
		&LogOut(100,"process_game_status for $GameFile failed: $state", $ErrorLog);
  }
  
  if ($state_set) {
  	if (&DB_Call($db,$sql)) { 
  		&LogOut(100,"$GameFile set to $state for $sql for $userlogin", $LogFile);
  		$success = 1;
  	} else { 
  		print "<P>Game $GameFile failed to $state\n"; 
  		&LogOut(0, "Game $GameFile failed to $state for $userlogin for $sql", $ErrorLog); 
  	}
	  &DB_Close($db);
  }
  
	if ($success) {
	# Notify all players who want to be notified that the game status has changed. 
		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Status updated to $state|;
		$GameValues{'Message'} = "The Game Status for $GameValues{'GameName'} has been updated to $state.\n";
#     if ($state eq 'UnPause') { 
#       $GameValues{'Message'} .= "The next turn will generate ";
#       $GameValues{'Message'} .= localtime ($NextTurn);
#       $GameValues{'Message'} .= "\n"; 
#     }
		&Email_Turns($GameFile, \%GameValues, 0);
	} else {
  	&LogOut(0, "Game $GameFile failed success to $state for $userlogin for $sql", $ErrorLog); 
  }
}

sub process_join_game {
	my ($GameFile, $RaceFile) = @_;
	my %GameValues;
	my $countdupes = 0;
  my $playercount = 1; # used to determine MaxPlayers; first row is 0
	$db = &DB_Open($dsn);
	# Get the necessary game data to add the user
	$sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (&DB_Call($db,$sql)) { $db->FetchRow(); %GameValues = $db->DataHash(); }
	#	while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }

  #Count number of players signed up
	$sql = qq|SELECT  * FROM GameUsers WHERE GameFile = '$GameFile';|;
	if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { $playercount++; }  }
  # If the number of players is greater than permitted, don't allow it
  if ($playercount > $GameValues{'MaxPlayers'}) { 
    print "<P><font color=red>This game already has the Max Players signed up!</font>"; 
    &LogOut(0, "$userlogin Failed to join game $GameFile because the game was at MaxPlayers $GameValues{'MaxPlayers'}", $LogFile);
  } else {
  	# If the game only permits the user to be in the game once, check to be sure the
  	# user is only in the game once. 
  	if (&checkbox($GameValues{'NoDuplicates'})) {
  		$sql = qq|SELECT  * FROM GameUsers WHERE User_Login = '$userlogin' AND GameFile = '$GameFile';|;
  		if (&DB_Call($db,$sql)) { if ($db->FetchRow()) { $countdupes++; } }
  	}
  	if ($countdupes) {
  		print "<P><font color=red>This game does not permit you to join more than once.</font>\n"; 
  		&LogOut(50,"$userlogin attempted to join $GameFile more than once", $ErrorLog);
  	} else {
  		# the player IDs must be unique. This number will be used to determine player order in
  		# the game when it's created, and will be reset to 1-16 then
  		my $random_number = rand(); $random_number = int($random_number*100000);
  		# Insert the user into the game 
  		my $now = time();
  		$sql = qq|INSERT INTO GameUsers (GameName, GameFile, RaceFile, User_Login, DelaysLeft, PlayerID, PlayerStatus, JoinDate) VALUES ('$GameValues{'GameName'}','$GameFile','$RaceFile','$userlogin',$GameValues{'NumDelay'},$random_number,1, $now);|;
  		if (&DB_Call($db,$sql)) { 
  			&LogOut(100,"$userlogin Joined Game $GameFile", $LogFile);
        # need to email the host that someone has joined. 
        # Get the host's email information
        $sql = qq|SELECT * FROM User WHERE User_Login = '$GameValues{'HostName'}';|;
        if (&DB_Call($db,$sql)) { 
          $db->FetchRow(); %HostValues = $db->DataHash(); 
          # Now email host to let them know
          $MailTo = $HostValues{'User_Email'};
          $MailFrom = $mail_from;
          $Subject = "$mail_prefix $GameValues{'GameName'} : User $userlogin Joined";
          $Message = "User $userlogin Joined your new game $GameValues{'GameName'} ($GameValues{'GameName'}).";
          $smtp = &Mail_Open;
          &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
  	      &Mail_Close($smtp);
        } else { &LogOut(0, "Failed to email host $GameValues{'HostName'} about new player $userlogin join of $GameFile", $ErrorLog);}
  		} else { 
        print "<P>Failed to join game $GameValues{'GameName'}\n"; 
        &LogOut(0, "$userlogin Failed to join game $GameFile, $GameValues{'GameName'}", $LogFile); 
      }
    }
  }
	&DB_Close($db);
}

sub show_delay {
	# interface for a player to delay a game
	($GameFile) = @_;
	my $sql;
	my %GameValues;
	# make sure the user actually has a delay available
	# probably need to know type of game? 
	$sql = qq|SELECT Games.GameName, Games.GameFile, Games.GameType, Games.LastTurn, Games.NextTurn, Games.DayFreq, Games.HourFreq, Games.HourlyTime, Games.DailyTime, Games.NumDelay, Games.AsAvailable, Games.MinDelay, Games.NewsPaper, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.DelaysLeft FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((Games.GameFile)='$GameFile') AND ((GameUsers.User_Login)='$userlogin') AND ((GameUsers.PlayerID) Is Not Null));|;
	# Provide an interface for the user to select their delay
	print "<td>";
	$db = &DB_Open($dsn);
	my $counter =0;
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) { %GameValues = $db->DataHash(); $counter++;
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
		}
	}
	&DB_Close($db);
	print "<H2>Submit a delay for: $GameValues{'GameName'}</H2>\n";
	if ($GameValues{'GameType'} == 3) { print "Turns generated only when all turns are in.\n"; } 
  	elsif ($GameValues{'GameType'} == 4) { print " Turns generated manually.\n"; }
  	elsif ($GameValues{'GameType'} == 2) { 
		print " Turns generated every $GameValues{'HourlyTime'} hours"; 
		if ($GameValues{'AsAvailable'}) { print " or when all turns are in"; }
		print ".";
		print "<table border=1><tr>\n";
		for (my $i=0; $i < 7; $i++) { print "<th>$WeekDays[$i]</th>\n"; }
		print "</tr><tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($GameValues{'DayFreq'}, $i, 1);
	 		if ($day) { print "<td align=center>Yes</td>\n"; }
	 		else { print "<td align=center>No</td>\n"; }
		}
		print "</tr></table>\n";
		print "Hourly Restrictions:\n";
		print "<table border=1><tr>\n";
		for (my $i=0; $i <=23; $i++) { 
			if ($i/12 == int($i/12)) { print "</tr><tr>\n"; }
		 		my $hour = substr($GameValues{'HourFreq'}, $i, 1);
		 		if ($hour) { print "<td align=center>$i:00</td>\n"; }
		 		else { print "<td align=center><strike>$i:00<strike></td>\n"; }
			}
			print "</tr></table>\n";
	}	elsif ($GameValues{'GameType'} == 1) {
		print " Turns generated daily"; 
		if ($GameValues{'AsAvailable'}) { print " or when all turns are in"; }
		print ".";

		print "<table border=1><tr>\n";
		for (my $i=0; $i < 7; $i++) { print "<th>$WeekDays[$i]</th>\n"; }
		print "</tr><tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($GameValues{'DayFreq'}, $i, 1);
	 		my $gen_time = &fixdate($GameValues{'DailyTime'}) . ':00'; 
	 		if ($day) { print "<td align=center>$gen_time</td>\n"; }
	 		else { print "<td align=center>-</td>\n"; }
		} 
		print "</tr></table>\n";
  } else { print "What kind of game IS this? \n"; &LogOut(0,"show_delay GameType Fail for $GameFile, $GameValues{'GameType'}", $ErrorLog);}
	if ($GameValues{'LastTurn'} > 0) { print "<br>Last turn generation: " . localtime($GameValues{'LastTurn'}) ."\n"; }
	else { print "<br>A turn has never been generated for this game.\n"; }
	if ($GameValues{'NextTurn'} > 0 ) { print "<P>Next turn currently due " . localtime($GameValues{'NextTurn'}) . "\n"; }
	else { print "Turns are due immediately.\n"; }

	if ($GameValues{'DelaysLeft'} > 1 ) {print qq|<P>You have $GameValues{'DelaysLeft'} delays left for this game. Your available delays will restore to $GameValues{'NumDelay'} if the sum across all players drops below $GameValues{'MinDelay'}.\n|; }
	elsif ($GameValues{'DelaysLeft'} == 1 ) { print qq|<P>You have $GameValues{'DelaysLeft'} delay left in this game. Use it wisely!\n|; }
	else { print qq|<P>You have no delays left in this game. Hope that they reset soon!\n|; }
  # If the player has delays left, display the option to select them
  if ($GameValues{'DelaysLeft'} > 0) {
   	print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
  	print qq|<input type=hidden name="lp" value="profile_game">\n|;
  	if (&checkbox($GameValues{'NewsPaper'})) { print qq|<input type=hidden name="rp" value="show_news">\n|; }
   	print qq|<INPUT type=\"hidden\" name=\"GameFile\" value =\"$GameFile\">\n|;
  	print qq|<table><tr>\n|;
  	print qq|<td>Delay Game</td>\n|;
   	print qq|<td><SELECT name="delay_turns">\n|;
  	for (my $i=1; $i<=$GameValues{'DelaysLeft'}; $i++) {
  		print qq|<OPTION value=$i>$i\n|;
  	}
  	print qq|</SELECT> interval.</td>\n|;
  	print qq|</tr><tr>\n|;
  	print qq|<td><INPUT type="submit" name="cp" value="Process Delay" onMouseOver="Help( \'GameDelay\' )" onMouseOut="Help( \'blank\' )"></td>\n|;
  	print qq|</tr></table>\n|;
    print qq|</form>\n|;
  }
}

sub process_delay {
	# Edit the game turn and add a delay
	($GameFile, $delay_turns) = @_;
	my $sql, $NextTurn, $CurrentDateSecs, $SecOfDay;
	my $FirstDayToAdd, $SecondDayToAdd, $NextDayOfWeek;
	my $ToDelay = 0;
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST);
	my %GameValues;
	my $db = &DB_Open($dsn);
	$sql = qq|SELECT Games.GameName, Games.GameFile, Games.DailyTime, Games.NextTurn, Games.LastTurn, Games.GameType, Games.NumDelay, Games.MinDelay, Games.DayFreq, Games.HourlyTime, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.DelaysLeft FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((Games.GameFile)='$GameFile') AND ((GameUsers.User_Login)='$userlogin') AND ((GameUsers.PlayerID) Is Not Null));|;
	# make sure the user actually has a delay available, and get other game-related values
	if (&DB_Call($db,$sql)) { if ($db->FetchRow()) { %GameValues = $db->DataHash(); } 	}
	if ($GameValues{'DelaysLeft'} >= $delay_turns) {
		#decrement the user's number of delays
		if ( $delay_turns == 0) { $delay = 1; } else { $delay = $delay_turns; }
		$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.DelaysLeft = [DelaysLeft]-$delay WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.User_Login)=\'$userlogin\') AND ((GameUsers.PlayerID) Is Not Null));|;
		if (&DB_Call($db,$sql)) { 
			&LogOut(100, "$userlogin delays decreased by $delay for $GameValues{'GameFile'}.",$LogFile); 
			#	Set Game Status to Player Delay [3] / Flag game as player timeout/delayed (so we can display it). 
			$sql = qq|Update Games SET GameStatus = 3 WHERE GameFile = \'$GameFile\'|;
			if (&DB_Call($db,$sql)) { 
				&LogOut(200, "process_delay: Game Status set to Delayed for $GameFile by $userlogin.",$LogFile); 
				# Increment the number of delays for the game
				$sql = qq|Update Games SET DelayCount = DelayCount + $delay WHERE GameFile = \'$GameFile\'|;
				if (&DB_Call($db,$sql)) { 
          $ToDelay = 1; 
          &LogOut(200, "prcoess_delay: Increase DelayCount + $delay for $GameFile by $userlogin.",$LogFile); 
        } else { &LogOut(200, "process_delay: Increase DelayCount failed for $GameFile by $userlogin.",$LogFile);}
			} else { &LogOut(0,"process_delay: Game Status failed to Delay for $delay_turns turns for $GameFile by $userLogin",$ErrorLog); }
		} else { &LogOut(0,"$userlogin delays failed to decrease for process_delays = $delay_turns  $delay", $ErrorLog); }
		#Determine how long to delay the game
		$NextTurn = $GameValues{'NextTurn'};
		#Loop through for each delay separately, since the schedule could vary
		for (my $i=0; $i<$delay_turns; $i++) {
			if ( $GameValues{'GameType'} == 1 ) {
				($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($NextTurn); 
				# Since we're calculating from "now" you need to go to the next interval, and then to the next interval
				# to have the time come out right for a delay.
				($DaysToAdd, $NextDayOfWeek) =  &DaysToAdd($GameValues{'DayFreq'}, $WeekDay);
				$SecOfDay = ($Minute * 60) + ($Hour*60*60) + $Second;
				# Cleverly make sure the time resets back to the "default" time
				$NextTurn = $NextTurn + ($DaysToAdd * 86400) -$SecOfDay + ($GameValues{'DailyTime'} * 60 * 60);
				#
				# BUG: Check valid Turn Time here (holidays, etc)
				#
			} elsif ( $GameValues{'GameType'} == 2) {
				my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($NextTurn); 
				$NextTurn = $NextTurn + (($GameValues{'HourlyTime'} * 60 * 60) );
# 				while (&ValidTurnTime($NextTurn,'Hour',\%GameValues) ne 'True') { 
 				while (&ValidTurnTime($NextTurn,'Hour',$GameValues{'DayFreq'}, $GameValues{'HourFreq'}) ne 'True') { 
 					# Get the weekday of the new turn so we can see if it's ok
 					($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = localtime($NextTurn);
 					# Move to the next available hour
 					print "New Weekday: $CWeekDay   timeFreq = $GameValues{'HourlyTime'}\n";
 					$NextTurn = $NextTurn + $GameValues{'HourlyTime'}*60*60;
 					print "<P>Next Turn" . localtime($NextTurn);
 				}
			} else { &LogOut(0,"Delay Failed for $GameFile wrong game type",$ErrorLog); }
		}
		# And then delay by that much
		if (&UpdateNextTurn($db,$NextTurn,$GameFile,$GameValues{'LastTurn'})) {
			my $log =  "process_delay: $userlogin delayed $GameFile $delay_turns from " . localtime($GameValues{'NextTurn'}) . " ($GameValues{'NextTurn'}) to " . localtime($NextTurn) . " ($NextTurn)";
			&LogOut(100, $log,$LogFile);
			# EMail all the players that the game has been delayed
			$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Turn Delay|;
			$GameValues{'Message'} = qq|A player has Delayed the $GameValues{'GameName'} game for $delay_turns turn(s).|;
			$GameValues{'NextTurn'} = $NextTurn;
			&Email_Turns($GameFile, \%GameValues, 0);
		}
		else { &LogOut(0, "Turn for $GameFile failed to process_delay",$ErrorLog); }
		# check to see if we're too low on delays
		$sql = qq|SELECT Games.GameFile, Sum(GameUsers.DelaysLeft) AS SumOfDelaysLeft, Games.MinDelay FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) GROUP BY Games.GameFile, Games.MinDelay HAVING (((Games.GameFile)=\'$GameFile\'));|;
		if (&DB_Call($db,$sql)) { $db->FetchRow(); ($SumOfDelaysLeft, $MinDelay) = $db->Data("SumOfDelaysLeft", "MinDelay"); }
		# If we're too low on delays, reset everyone
		if ($SumOfDelaysLeft < $MinDelay) { 
			$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.DelaysLeft = [NumDelay] WHERE (((Games.GameFile)=\'$GameFile\'));|;
			if (&DB_Call($db,$sql)) { 
				$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Turn Delays reset|;
				$GameValues{'Message'} = qq|A recent player for the $GameValues{'GameName'} game has delayed the game, causnig a reset of the number of player delays available. You can now delay the game $GameValues{'NumDelay'} times.|;
				&Email_Turns($GameFile, \%GameValues, 0);
				&LogOut(100, "process_delay: $GameFile delays reset to $GameValues{'NumDelay'} due to $userlogin request of $delay_turns",$LogFile); 
			}
		}
	} else { print "<P>You don't have enough delays left. Sorry!\n"; 
		&LogOut(50, "$userlogin tried to delay $GameFile for $delay_turns, but did not have enough",$LogFile); 
	}
	&DB_Close($db);
}

# Display File Upload
sub show_upload { # Uses $GameName and $GameFile
	my($GameName,$GameFile) = @_;
	print qq|<FORM method="$FormMethod" action="$Location_Scripts/upload.pl" name="my_form" enctype="multipart/form-data">\n|;
	print qq|<table><tr>\n|;
	print qq|<td><INPUT type="file" name="File" size="30"></td>\n|;
	print qq|<td><INPUT type="submit" name="submit" value="Upload Turn" | . &button_help('SendFile') . qq|></td>\n|;
	print qq|</tr></table>\n|;
	# send GameName
	print qq|<INPUT type="hidden" name="GameName" value="$GameName">\n|;
	print qq|<INPUT type="hidden" name="GameFile" value="$GameFile">\n|;
	print qq|<INPUT type="hidden" name="lp" value="profile_game">\n|;
	print qq|<INPUT type="hidden" name="cp" value="show_game">\n|;
	print qq|<INPUT type="hidden" name="rp" value="show_news">\n|;
  print qq|</FORM>\n|;
}

# Show current player status
sub show_player_status {
	my ($GameFile, $sql) = @_;
	my %PlayerValues;
	my @PlayerData, @Status, @TXT;
	my $counter = 0;
	# Read in all the player data
	$db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { 
		while ($db->FetchRow()) { 
			%PlayerValues = $db->DataHash(); 
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			push (@PlayerData, { %PlayerValues });
		}
	} 
	# Get the different player statuses
	$sql = qq|SELECT * FROM _PlayerStatus;|;
	if (&DB_Call($db,$sql)) { 
		while ($db->FetchRow()) { 
			($Status, $TXT) = $db->Data("PlayerStatus", "PlayerStatus_txt");
			push (@Status, $Status);
			push (@TXT, $TXT);
		}
	}
	&DB_Close($db);
	print "<H2>Update Player Status for: $PlayerData[0]{'GameName'}</H2>\n";
	print "<table>\n";
  	my $LoopPosition = 0; #Start with the first player in the array.
  	while ($LoopPosition <= ($#PlayerData)) { # work the way through the array
		print "<tr>\n";
 		print qq|<FORM action="$Location_Scripts/page.pl" method=$FormMethod>\n|;
		print qq|<input type=hidden name="lp" value="profile_game">\n|;
		print qq|<input type=hidden name="rp" value="my_games">\n|;
		print qq|<input type=hidden name="User_File" value="$PlayerData[$LoopPosition]{'User_File'}">\n|;
		print qq|<input type=hidden name="GameFile" value="$GameFile">\n|;
		print "<td>User ID:</td>\n";
    # Display the player IDs unless the game has anonymous players.
    if (!($PlayerData[0]{'AnonPlayer'} )) { 
      print qq|<td>$PlayerData[$LoopPosition]{'User_Login'}</td>\n|;
    } else {
      print qq|<td>Player $PlayerData[$LoopPosition]{'PlayerID'}</td>\n|;
    }
    print qq|<td><SELECT name="PlayerStatus">\n|;
		foreach my $key (@TXT) { 
			if ($PlayerData[$LoopPosition]{'PlayerStatus_txt'} eq $key) { print qq|<OPTION value=$key SELECTED>$key\n|; }
			else { print qq|<OPTION value=$key>$key\n|; }
		}
		print qq|</SELECT>\n|;
		print qq|</td>\n|;
		print qq|<td><INPUT type="submit" name="cp" value="Update Player" onMouseOver="Help( \'PlayerStatus\' )" onMouseOut="Help( \'blank\' )">\n|; 
		print qq|</td>\n|;
		print qq|</form>\n|;
		print qq|</tr>\n|;
		$LoopPosition++;
	}
	print "</table>\n";
}

sub process_player_status {
# Process the results of a host changing a player status. 
	my ($GameFile, $UserFile, $PlayerStatus) = @_;
	my $update = 0;
	my $db = &DB_Open($dsn);
	# Get the valid player statuses from the database
	$sql = qq|SELECT * FROM _PlayerStatus;|;
	if (&DB_Call($db,$sql)) { 
		while ($db->FetchRow()) { 
			($Status, $TXT) = $db->Data("PlayerStatus", "PlayerStatus_txt");
			if ($TXT eq $PlayerStatus) { $update = $Status; }
		}
	}
  # If the player status matches an entry in the database
	if ($update) {
#		$sql = qq|UPDATE _PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus SET GameUsers.PlayerStatus = $update WHERE (((Games.HostName)=\'$userlogin\') AND ((Games.GameFile)=\'$GameFile\') AND ((GameUsers.User_File)=\'$UserFile\'));|;
    $sql = qq|UPDATE [User] INNER JOIN (Games INNER JOIN (_PlayerStatus INNER JOIN GameUsers ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus) ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login SET GameUsers.PlayerStatus = $update WHERE (((Games.HostName)=\'$userlogin\') AND ((Games.GameFile)=\'$GameFile\') AND ((User.User_File)=\'$UserFile\'));|;
		if (&DB_Call($db,$sql)) { 
#			print "<P>User $User Updated for $GameFile\n";
   		&LogOut(100, "Status updated to $playerstate for $in{'GameFile'} by $userlogin",$LogFile);
		} else { &LogOut(10,"ERROR: player_status failed updating for User $User_Login in $GameFile",$ErrorLog);}
	} else { &LogOut(10,"ERROR: Invalid attempt to update player_status=$update for $User_Login by $userlogin for $GameFile",$ErrorLog);}
  # And email affected player(s)
  # First, get the name and email address of all the players for this game. 
  $sql = qq|SELECT Games.GameFile, Games.GameName, User.User_Login, User.User_Email, GameUsers.PlayerID, GameUsers.PlayerStatus, [_PlayerStatus].PlayerStatus_txt FROM [User] INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\'));|;
	if (&DB_Call($db,$sql)) { 
		while ($db->FetchRow()) { 
			%PlayerValues = $db->DataHash(); 
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			push (@PlayerData, { %PlayerValues });
      # Tease out who the current user is
      # BUG: Won't work if it's the host changing the player status
      #if ($PlayerValues{'User_Login'} eq $userlogin) { $User = $PlayerValues{'User_Login'}}
		}
	} 
	&DB_Close($db);
  # Next, loop through the list to email all the players and let them know what's happened. 
  my $LoopPosition = 0; #Start with the first player in the array.
  $MailFrom = $mail_from;
#  $Subject = "$mail_prefix $PlayerData[0]{'GameName'} : Player Status Change to $PlayerStatus";
  # Not displaying the player name solves several problems, not the lease
  # not having that value, and revealing anonymous players
  $Subject = "$mail_prefix $PlayerData[0]{'GameName'} : Player Status Change";
  $Message = "User $User status changed in $PlayerData[0]{'GameName'}.";
  while ($LoopPosition <= ($#PlayerData)) { # work the way through the array
    $MailTo = $PlayerData[$LoopPosition]{'User_Email'};
    $smtp = &Mail_Open;
    &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
    $LoopPosition++;
  }
  &Mail_Close($smtp); 
}
  
sub submit_forcegen {
# Display the interface to force generate turns. 
	my ($GameFile) = @_;
	my %GameValues;
	my $sql = qq|SELECT Games.* FROM Games WHERE (((Games.GameFile)='$GameFile') AND ((Games.HostName)='$userlogin'));|;
	my $db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { %GameValues = $db->DataHash(); } }
	&DB_Close($db);
	# Get the current gate status
	my $HSTFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.hst';
	($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);

	print "<H2>Force Generate Turns for: $GameValues{'GameName'}</H2>\n";
	print "<P>Current Year: $HST_Turn\n";
	print qq|<form method=$FormMethod action="$Location_Scripts/page.pl">\n|;
	print qq|<input type="hidden" name="GameFile" value="$GameFile">\n|;
	print qq|<input type="hidden" name="lp" value="profile_game">\n|;
	print qq|<input type="hidden" name="cp" value="force_gen">\n|;
	if (&checkbox($GameValues{'NewsPaper'})) { print qq|<input type="hidden" name="rp" value="show_news">\n|; }
	print "<table><tr>\n";
	print "<td>Generate:</td>\n";
	print qq|<td><SELECT name="Turns">\n|;
	for (my $i=1; $i < $max_forcegen; $i++) { print qq|<OPTION value=$i $Selected[$i]>$i\n|; }
	print qq|</SELECT></td>\n|;
	print qq|<td>turn(s)</td></tr>\n|;
	print qq|<tr><td>Email Turn to Players with Email enabled:</td><td><INPUT type="checkbox" name="EmailPlayers" onFocus="Help( 'EmailPlayersForceGen' )" onMouseOver="Help( \'EmailPlayersForceGen\' )" onMouseOut="Help( \'blank\' )" CHECKED></td></tr>\n|;
	if ($GameValues{'ForceGenTimes'} > 0) {
    print qq|<tr><td>Decrement ForceGen Times:</td><td><INPUT type="checkbox" name="decrementforcegentimes" onFocus="Help( 'DecrementForceGenTimes' )" onMouseOver="Help( \'DecrementForceGenTimes\' )" onMouseOut="Help( \'blank\' )" CHECKED></td></tr>\n|;
	}
  print qq|<td><INPUT type="submit" name="submit" value="Force Generate Turns"></td>\n|;
	print qq|</tr></table>\n|;
}  

sub process_forcegen {
# Process turn force generation
	my($NumberofTurns, $GameFile, $userlogin, $EmailPlayers, $decrementforcegentimes) = @_;
	my %GameValues;
	my $sql = qq|SELECT * FROM Games WHERE HostName = \'$userlogin\' AND GameFile = \'$GameFile\';|;     
	my $db = &DB_Open($dsn);
	if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { %GameValues = $db->DataHash(); } }
	# Only the game host can force gen
	if ($GameValues{'HostName'} eq $userlogin && $GameValues{'HostForce'}) {
		&GenerateTurn($NumberofTurns, $GameFile);
		print "<P>$NumberofTurns turn(s) force generated for: $GameValues{'GameName'}\n";
		&UpdateLastTurn($db, time(), $GameFile); # update the last gen date. 
    # If the user selected to update the forcegen counter
    if (&checkbox($decrementforcegentimes)) {
    	$NumberofTimes = $GameValues{'ForceGenTimes'} -1;
			# Update NumberofTimes
			$sql = "UPDATE Games SET ForceGenTimes = $NumberofTimes WHERE GameFile = \'$GameValues{'GameFile'}\'";
			if (&DB_Call($db,$sql)) { &LogOut(200,"Decremented ForceGenTimes for $GameValues{'GameFile'}",$LogFile); }
			else { &LogOut(200,"Failed to Decrement ForceGenTimes for $GameValues{'GameFile'}",$ErrorLog);}
			if ($NumberofTimes <= 0) { #If the game is no longer forced, unforce game
				$sql = "UPDATE Games SET ForceGen = 0 WHERE GameFile = \'$GameValues{'GameFile'}\'";
				if (&DB_Call($db,$sql)) { &LogOut(200,"Forcegen set to 0 for $GameValues{'GameFile'}",$LogFile) }
				else { &LogOut(0,"Failed to set forcegen to 0 for $GameValues{'GameFile'}",$ErrorLog); }
			}
		}
    # Update for other references to this value (in emails) without having to repoll database
    $GameValues{'ForceGenTimes'} = $NumberofTimes ;    
	} else { my $x = "$GameValues{'GameFile'} $GameValues{'HostName'}: $userlogin is not authorized to ForceGen: $GameValues{'HostForce'}"; print $x; &LogOut(0,$x,$ErrorLog); }
	&DB_Close($db);

	#Check to see if the players should be notified
	$EmailPlayers = &checkboxnull($EmailPlayers);
	if ($EmailPlayers) {
		print "<P>Emailing players...\n";
		my $HSTFile = $File_HST . '/' . $GameFile . '/' . $GameFile . '.hst';
		($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Force Generated to Year $HST_Turn|;
		$GameValues{'Message'} = "Host Manually Force Generated Turn for $GameValues{'GameName'}\n";
		$GameValues{'HST_Turn'} = $HST_Turn;
		&Email_Turns($GameFile, \%GameValues, 1);
	}
}

sub process_remove_password {
  my ($GameFile, $PlayerID) = @_;
  use StarsBlock;  
  use File::Copy;
  # Get the relevant Game Data
 	my $sql = qq|SELECT * FROM Games WHERE HostName = \'$userlogin\' AND GameFile = \'$GameFile\';|;
  my $db = &DB_Open($dsn);
 	if (&DB_Call($db,$sql)) { if ($db->FetchRow()) { %GameValues = $db->DataHash(); } }
  # Backup the existing .m file
  my $Backup_Source_File      = $File_HST . '/' .  $GameValues{'GameFile'} . '/' . $GameValues{'GameFile'} . '.m' . $PlayerID;
  my $Backup_Destination_File = $Backup_Source_File . '.bak'; 
 	copy($Backup_Source_File, $Backup_Destination_File);
 	&LogOut(100,"Copy $Backup_Source_File to $Backup_Destination_File",$LogFile);
  # Remove the password
  my $PasswordRemove = &StarsPWD($GameFile, $PlayerID);
  if ($PasswordRemove) { print  "Password removed"; }
  # Email the player and host the password has been reset
  # my $EmailPlayers = &checkboxnull($GameValues{'EmailPlayers'});
  # This is a big deal, so we always want to notify everyone.
# 	if ($EmailPlayers) {
 		print "<P>Emailing players...\n";
 		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Password Reset for Player $PlayerID|;
 		$GameValues{'Message'} = "The Host has reset the password for Player $PlayerID in $GameValues{'GameName'}\n";
 		&Email_Turns($GameFile, \%GameValues, 0);
# 	}
  &LogOut(100,"Password reset for $GameFile, $PlayerID", $LogFile);
  print 'Password removed. Remember to Save and Submit with a new password.';
	&DB_Close($db);
}

sub show_email {
# Display the interface to send email to all the players.
	my ($GameFile, $GameName) = @_;
print <<eof;
<td>
<H2>Send Email to all players in: $GameName  </H2>
<FORM method=$FormMethod action="$Location_Scripts/page.pl" name="my_form">
<input type="hidden" name="lp" value="game">
<input type="hidden" name="GameFile" value="$GameFile">
<input type="hidden" name="GameName" value="$GameName">
	<TABLE>
		<TR><TD>Message:</TD> <TD><TEXTAREA name="Message" rows="4" cols="50"></TEXTAREA></TD></TR>
	</TABLE>
	<BUTTON $host_style type="submit" name="cp" value="process_email">Send Email</BUTTON>
</FORM>
</td>
eof
}

sub process_email {
# This routine sends email to all the players of a game.
	my ($GameFile, $Message, $GameName) = @_; 
	$GameValues{'Subject'} = qq|$mail_prefix $GameName : Message from Host|;
	$GameValues{'Message'} = "$Message\n";
	&Email_Turns($GameFile, \%GameValues, 0);
	print qq|Email sent!|;
	&LogOut(100, "Email sent to all players for $GameFile : $Message",$LogFile); 
}

sub optionloop {
# Used to create a list of HTML options
	my ($startloop,$endloop,$countloop,$selected) = @_; 
	for (my $i = $startloop; $i <= $endloop; $i = $i + $countloop) {
		if ($i != $selected) { print qq|<OPTION value=| . $i . qq|>| . $i . qq|</OPTION>\n|; } 
		else { print qq|<OPTION value=| . $i . qq| SELECTED>| . $i . qq|</OPTION>\n|;
	   }
	}
}

sub display_warning {
    print "<P><font color=red>Warning: Using the Browser Reload function will repeat the last Action.</font>";
}

sub button_check {
  my ($button_count) = @_;
  if  ( ($button_count / 5) == int ($button_count/5) ) {
    print '<br>';
  } 
  $button_count++;
  return $button_count;
}

# sub GetTime {
# 	# Figure out all time values for this iteration. Global Values
# 	$CurrentEpoch = time();
# 	($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($CurrentEpoch); 
# 	$Month = $WrongMonth + 1; 
# 	$Year = $WrongYear + 1900;
# 	$SecOfDay = ($Minute * 60) + ($Hour*60*60) + $Second;
# 	$CurrentDateSecs = $CurrentEpoch - $SecOfDay;
# #	$Interval = 24 * 60 * 60;
# 	if ($DayofMonth <=7) { $WeekofMonth = 1;}
# 	elsif ($DayofMonth >7 && $DayofMonth <=14) { $WeekofMonth = 2;}
# 	elsif ($DayofMonth >14 && $DayofMonth <=21) { $WeekofMonth = 3;}
# 	elsif ($DayofMonth >22 && $DayofMonth <=28) { $WeekofMonth = 4;}
# 	elsif ($DayofMonth >28 && $DayofMonth <=31) { $WeekofMonth = 5;}
# 
#   return  $Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST;
# }