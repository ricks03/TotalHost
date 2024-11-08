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

#use strict;
#use warnings;   
#use warnings::unused;   

use CGI qw(:standard);
use CGI::Session;
CGI::Session->name('TotalHost');
$CGI::POST_MAX=1024 * 25;  # max 25K posts
use DBI;
use DateTime;
use DateTime::TimeZone;
do 'config.pl';
use TotalHost;
use StarStat; 

my %in;
my %GameValues; # This passes values from the CP panels into the RP panels
# Clean all incoming /submitted values
#foreach my $field (param()) { $in{$field} = &clean(param($field)); }
foreach my $field (param()) {
   my $value = param($field);  # Get the values for the current parameter in list context
   $in{$field} = clean($value);  # Clean and assign to %in hash
}

# if ($ARGV[0]) { 
# 	$in{'GameFile'} = 'alpha';
# 	$sql = qq|SELECT Games.GameFile, Games.GameName, User.User_Login, Games.HostName, GameUsers.PlayerID, GameUsers.DelaysLeft, GameUsers.PlayerStatus, _PlayerStatus.PlayerStatus_txt FROM User INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$in{'GameFile'}\'));|;
# 	&show_player_status($in{'GameFile'},$sql); 
# 	die;
# }

# Clean old session files
&clean_old_sessions();

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
my $cookie = $cgi->cookie(TotalHost);
&validate($cgi,$session);

print $cgi->header();
# Get the User ID and User Login from the Cookie.
my $id = $session->param("userid");
my $userlogin = $session->param("userlogin");
my $timezone = $session->param("timezone");

# API output for the Java client
if ($in{'client'} eq 'java') {
    print "<html><body>\n";
    &show_client($in{'GameFile'});
    print "<body></html>\n";
    &LogOut(100,"client: %in{'client'}, GameFile: $GameFile",$LogFile);
    exit;
}

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
 				"1My Profile" 			    => "$WWW_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games",
 				"2My Games" 			      => "$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=my_games",
 				"3My Races" 		       	=> "$WWW_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races",
 				"4Getting Started" 			=> "$WWW_Scripts/index.pl?lp=home&cp=started",
 				"5Change Password" 		  => "$WWW_Scripts/page.pl?lp=profile&cp=edit_password",
 				);
} elsif ($in{'lp'} eq 'profile_game') { 
%menu_left = &lp_list_games($id);
} elsif ($in{'lp'} eq 'profile_race') { 
%menu_left = 	(
 				"0My Profile" 	=> "$WWW_Scripts/page.pl?lp=profile&cp=show_profile&rp=my_games",
 				"1My Races" 	  => "$WWW_Scripts/page.pl?lp=profile_race&cp=show_first_race&rp=my_races",
 				"2Upload Race"	=> "$WWW_Scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races",
 				);
} elsif ($in{'lp'} eq 'game') { 
%menu_left = 	(
 				"0My Games" 	         => "$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=my_games",
 				"1Games In Progress" 	 => "$WWW_Scripts/page.pl?lp=game&cp=show_games_inprogress&rp=games",
 				"2New Games" 	         => "$WWW_Scripts/page.pl?lp=game&cp=show_new&rp=games_new",
 				"3Completed Games" 	   => "$WWW_Scripts/page.pl?lp=game&cp=show_games_completed&rp=games_complete",
# 				"1Replacement Players" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=welcome&rp=games_replacement",
# 				"2XInvite People"	=> "",
 				"4Create Game"	       => "$WWW_Scripts/page.pl?lp=game&cp=create_game&rp=",
 				);
} elsif ($in{'lp'} eq 'hosting') { 
%menu_left = 	(
 				"0Features" 	      => "$WWW_Scripts/scripts/index.pl?lp=home&cp=features",
 				"1Create Game" 	    => "$WWW_Scripts/scripts/page.pl?lp=game&cp=create_game&rp=",
 				"2Turn Generation" 	=> "$WWW_Scripts/scripts/index.pl?lp=home&cp=turngeneration",
 				"3Recent Changes" 	=> "$WWW_Scripts/scripts/index.pl?lp=home&cp=recentchanges",
# 				"1Replacement Players" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=welcome&rp=games_replacement",
# 				"2XInvite People"	=> "",
 				);
} else { 
# %menu_left = 	(
#  				"1Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
#  				"2Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create",
#  				"3Reset Password" 	=> "$WWW_Scripts/index.pl?cp=reset_user",
#  				"4Logout" 			=> "$WWW_Scripts/index.pl?cp=logout",
#  				"5Erase" 			=> "$WWW_Scripts/index.pl?cp=logoutfull",
#  				);
  if (!($userlogin)) { $menu_left{'1Log In'} = "$WWW_Scripts/index.pl?cp=login_page"; }
  if (!($userlogin)) { $menu_left{'2Sign Up'} = "$WWW_Scripts/index.pl?cp=create"; }
  $menu_left{'3Reset Password'} = "$WWW_Scripts/index.pl?cp=reset_user";
  $menu_left{'4Logout'} = "$WWW_Scripts/index.pl?cp=logout";
  $menu_left{'5Erase'} = "$WWW_Scripts/index.pl?cp=logoutfull";
}

&html_left(\%menu_left);
print qq|</td>\n|;

# Set the value for any displayed welcome pages.
my $welcome = $Dir_WWWRoot . '/' . 'welcome.htm';

#### Center Panel
if ($in{'cp'} eq 'edit_profile') {  
	my $sql = qq|SELECT * FROM User WHERE ((User_ID)=$id);|;
	&edit_profile($sql);
} elsif ($in{'cp'} eq 'show_profile') { 
	print "<td>";
	my $sql = qq|SELECT * FROM _UserStatus RIGHT JOIN User ON _UserStatus.User_Status = User.User_Status WHERE (((User.User_ID)=$id));|;
	&show_profile($sql);
	print "</td>";
} elsif ($in{'cp'} eq 'update_profile') { &update_profile;
} elsif ($in{'cp'} eq 'edit_password') { &edit_password;
} elsif ($in{'cp'} eq 'change_password') { &change_password;
} elsif ($in{'cp'} eq 'create_game') { 
	&edit_game('create'); 
} elsif ($in{'cp'} eq 'Edit Game') { 
	&edit_game('edit'); 
  if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Update Game') { 
	print "<td>";
	&update_game($in{'GameFile'}); 
  if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
	# send the user back to the right page, either new game or otherwise
  &display_warning;
  &show_game($in{'GameFile'});
	print "</td>";
  if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }# if news was enabled, it needs to display
} elsif ($in{'cp'} eq 'Join Game') {
	print "<td>"; 
	&process_join_game($in{'GameFile'}, $in{'RaceID'}); 	
	print &show_game($in{'GameFile'});  # Display the Game Page
	print "</td>";
} elsif ($in{'cp'} eq 'Leave Game') {
	print "<td>";
	&process_game_leave($in{'GameFile'}, $in{'PlayerID'});
	&show_game($in{'GameFile'});
	print "</td>";
} elsif ($in{'cp'} eq 'Remove Player') {
	print "<td>";
	&process_game_remove($in{'GameFile'}, $in{'PlayerID'});
	&show_game($in{'GameFile'});
	print "</td>";
} elsif ($in{'cp'} eq 'Create Game') { 
	print "<td>"; 
	$GameFile = &update_game(); # Modified to always create a random game file
	unless ($GameFile eq 'CREATE FAILED') { 
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
	&process_game_status($in{'GameFile'}, 'Locked', $userlogin); 
	&show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Unlock Game') { 
	print "<td>"; 	
	&process_game_status($in{'GameFile'}, 'Unlocked', $userlogin); 
	&show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'Restart Game') { 
	print "<td>"; 	
	&process_game_status($in{'GameFile'}, 'Restart', $userlogin); 
  &display_warning;
	&show_game($in{'GameFile'}); 
	print "</td>";
} elsif ($in{'cp'} eq 'DELETE' || $in{'cp'} eq 'delete_game') { &delete_game($in{'GameFile'}); 
} elsif ($in{'cp'} eq 'show_first_game') { 
	my $sql = qq|SELECT Games.*, Games.GameStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4) Or (Games.GameStatus)=7 Or (Games.GameStatus)=0  );|;
	my %First;
	my $db = &DB_Open($dsn);
 	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); 
    %First = %{$row};  # Dereference the hash reference into %Profile
    $sth->finish();
  }
 	else { &LogOut(10,"ERROR: Finding show_first_game",$ErrorLog); }
	&DB_Close($db);
	# If game(s) found, display
	print "<td>"; 	
	if ($First{'GameFile'}) {
    unless ($First{'GameStatus'} == 7) { &show_game($First{'GameFile'});}
    else { &show_game($First{'GameFile'}); }
	} else {	 $in{'rp'} eq 'games'; print "No active games found for your ID.\n"; $in{'rp'} = 'games'; }
	print "</td>";
} elsif ($in{'cp'} eq 'show_new') { 
	my $sql = qq|SELECT * FROM Games WHERE GameStatus=7 OR GameStatus=0;|;
	print "<td>"; &show_new_games($sql); print "</td>";
} elsif ($in{'cp'} eq 'show_game') { 
 	if ($in{'GameFile'}) { 
   print "<td>"; &show_game($in{'GameFile'}); print "</td>"; 
   if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }   }
} elsif ($in{'cp'} eq 'Refresh') { 
	if ($in{'GameFile'}) {  
    print "<td>"; 
    &show_game($in{'GameFile'}); 
    print "</td>"; 
    if ($GameValues{'NewsPaper'}) { 
    $in{'rp'} = 'show_news'; 
  }   
}
# CANCEL is also here due to a browser defect
# Depending on the browser, it uses the label instead of the value
# And the CANCEL button uses the value of "show_games"
} elsif ($in{'cp'} eq 'show_games' || $in{'cp'} eq 'CANCEL') {
	my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName, Games.NewsPaper FROM Games ORDER BY Games.GameStatus, Games.NextTurn DESC;|;
	print "<td>"; &list_games($sql, 'All Games'); print "</td>";
} elsif ($in{'cp'} eq 'show_my_games_inprogress') {
	my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName, Games.NewsPaper FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE GameUsers.User_Login='$userlogin' AND Games.GameStatus>1 AND Games.GameStatus<6 ORDER BY Games.GameStatus;|;
	print "<td>"; &list_games($sql, 'My Games In Progress'); print "</td>";
} elsif ($in{'cp'} eq 'show_games_inprogress') {
	my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName, Games.NewsPaper FROM Games WHERE Games.GameStatus>1 AND Games.GameStatus<6 ORDER BY Games.GameStatus;|;
	print "<td>"; &list_games($sql, 'Games In Progress'); print "</td>";
} elsif ($in{'cp'} eq 'show_games_completed') {
	my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus, Games.GameDescrip, Games.HostName, Games.NewsPaper FROM Games WHERE Games.GameStatus=9 ORDER BY Games.GameStatus;|;
	print "<td>"; &list_games($sql, 'Completed Games'); print "</td>";
} elsif ($in{'cp'} eq 'show_my_new') { 
	print "<td>"; &show_my_new(); print "</td>";
} elsif ($in{'cp'} eq 'upload_race') { &upload_race; 
} elsif ($in{'cp'} eq 'show_race') { 
	print "<td>"; 	
  if ($in{'RaceID'}) {
	  $sql = qq|SELECT * FROM Races WHERE RaceID = $in{'RaceID'} AND User_Login = \'| . $session->param("userlogin") . qq|\';|;
  } else { $sql = ''; }
	&show_race($sql); 
	print "</td>"; 
} elsif ($in{'cp'} eq 'show_first_race') {
	my $sql = qq|SELECT * FROM Races WHERE User_Login = \'| . $session->param("userlogin") . qq|\';|;
	my %First;
	my $db = &DB_Open($dsn);
  # Get the first race from the list
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %First = %{$row}; 
    $sth->finish();
  }	
	else { &LogOut(10,"ERROR: Finding show_first_race $sql",$ErrorLog); }
	&DB_Close($db);  
  if ($First{'RaceID'}) { 
  	$sql = qq|SELECT * FROM Races WHERE RaceID = $First{'RaceID'} AND User_Login = \'| . $session->param("userlogin") . qq|\';|;
  } else { $sql =''; }
	print "<td>"; 	
  &show_race($sql); 
	print "</td>"; 
} elsif ($in{'cp'} eq 'process_race') { 
	print "<td>"; print "$in{'status'}"; 	print "</td>";
#	else { print "Processed Race File $in{'File'} for " . $session->param("userlogin"); }
} elsif ($in{'cp'} eq 'delete_race') {
	print "<td>"; &delete_race($in{'RaceID'}); print "</td>";
} elsif ($in{'cp'} eq 'Restore Game') {
		print "<td>\n"; &show_restore($in{'GameFile'}); print "</td>\n";
} elsif ($in{'cp'} eq 'Process Restore') {
		print "<td>\n"; 
    &process_restore($in{'GameFile'},$in{'restore_year'}); 
    &display_warning;
    &show_game($in{'GameFile'}); 
    print "</td>\n";
} elsif ($in{'cp'} eq 'Report News') {	
		&submit_news($in{'GameFile'});
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Submit Article') {
		&process_news($in{'GameFile'}, $in{'NewsPaper'}); 
		if ($in{'GameFile'}) { print "<td>"; &display_warning; &show_game($in{'GameFile'}); print "</td>";}
} elsif ($in{'cp'} eq 'Player Status') { 
		my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.NewsPaper, User.User_Login, User.User_File, Games.HostName, Games.AnonPlayer, GameUsers.PlayerID, GameUsers.DelaysLeft, GameUsers.PlayerStatus, _PlayerStatus.PlayerStatus_txt FROM User INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$in{'GameFile'}\')) ORDER BY GameUsers.PlayerID;|;
		print "<td>\n"; &show_player_status($in{'GameFile'},$sql); print "</td>\n";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Update Player') { 
		print "<td>\n"; 
    &process_player_status($in{'GameFile'}, $in{'User_File'}, $in{'NewPlayerStatus'}, $in{'PlayerStatus'}, $in{'PlayerID'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>\n";
} elsif ($in{'cp'} eq 'Pause Game') {
		print "<td>"; 
    &process_game_status($in{'GameFile'}, 'Pause', $userlogin); 
    &display_warning;
    &show_game($in{'GameFile'}); 
    print "</td>";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'UnPause Game') { # unpause the game and reset then the next turn is due
		print "<td>"; 
    &process_game_status($in{'GameFile'}, 'UnPause', $userlogin);
    &display_warning; 
    &show_game($in{'GameFile'}); print "</td>";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Delay Turn') {
		print "<td>"; &show_delay($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'Process Delay') {
		print "<td>"; 
    &process_delay($in{'GameFile'}, $in{'delay_turns'}, $in{'PlayerID'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>"; 
} elsif (($in{'cp'} eq 'Go Idle') || ($in{'cp'} eq 'Go Active')) {
  my ($playerstatus, $newplayerstate);
	print "<td>\n";
	if ($in{'cp'} eq 'Go Idle') { $playerstatus = 4; $newplayerstate = 'Idle';}
	elsif ($in{'cp'} eq 'Go Active') { $playerstatus = 1; $newplayerstate = 'Active'; }
  # There's a difference in process_player_status when User Submitted > no player ID. 
  &process_player_status($in{'GameFile'}, $in{'User_File'}, $newplayerstate, $in{'PlayerStatus'}, -1); 
  &display_warning;
	&show_game($in{'GameFile'});
  if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
	print "</td>\n";
} elsif ($in{'cp'} eq 'End Game') {
		print "<td>"; 
    &process_game_status($in{'GameFile'}, 'Ended', $userlogin); 
    &display_warning;
    &show_game($in{'GameFile'}); 
    print "</td>";
} elsif ($in{'cp'} eq 'Start Game') {
		print "<td>"; 
    if (&process_game_launch($in{'GameFile'})) { &show_game($in{'GameFile'}); }
	  else { &show_game($in{'GameFile'})}
    print "</td>";
 } elsif ($in{'cp'} eq 'Force Gen') {
		print "<td>"; &submit_forcegen($in{'GameFile'}); print "</td>";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Email Players') {
		print "<td>"; &show_email($in{'GameFile'},$in{'GameName'}); print "</td>";
} elsif (($in{'cp'} eq 'process_email') || $in{'cp'} eq 'Send Email') {
		print "<td>"; 
    &process_email($in{'GameFile'}, $in{'Message'}, $in{'GameName'}); 
    &display_warning;
    &show_game($in{'GameFile'}); print "</td>";
} elsif ($in{'cp'} eq 'force_gen') {
		print "<td>"; 
    &process_forcegen($in{'Turns'},$in{'GameFile'}, $userlogin, $in{'EmailPlayers'}, $in{'decrementforcegentimes'});
    &updateList($in{'GameFile'}, 1); # update List files for exploit detection
    &cleanFiles($in{'GameFile'}); # Clean the .m files of player information
    &Make_CHK($in{'GameFile'});
    &display_warning; 
    &show_game($in{'GameFile'}); 
    print "</td>";
} elsif ($in{'cp'} eq 'Remove PWD') {
		print "<td>"; 
    &display_warning; 
    &show_game($in{'GameFile'});
    print "</td>";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
} elsif ($in{'cp'} eq 'Replace Player') {
		print "<td>"; 
    &display_warning; 
    &show_game($in{'GameFile'});
    print "</td>";
} elsif ($in{'cp'} eq 'Switch') {
		print "<td>"; 
    &display_warning; 
    &process_switch_player($in{'GameFile'}, $in{'PlayerID'}, $in{'ReplaceName'});
    # Don't need to rebuild the .chk file
    &show_game($in{'GameFile'});
    print "</td>";
} elsif ($in{'cp'} eq 'Reset Password') {
		print "<td>"; 
    &process_remove_password($in{'GameFile'}, $in{'PlayerID'});
    &display_warning; 
    &show_game($in{'GameFile'});
    print "</td>";
    if ($GameValues{'NewsPaper'}) { $in{'rp'} = 'show_news'; }
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
if ($in{'rp'} eq 'my_games') { 
	print "<td width=$rp_width>";
	my $sql = qq|SELECT Games.GameFile, Games.GameName, Games.GameStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login GROUP BY Games.GameFile, Games.GameName, Games.GameStatus, User.User_ID HAVING User.User_ID=| . $session->param("userid") . qq| ORDER BY Games.GameStatus;|;
	&rp_list_games($sql, 'My Games');
	print "</td>\n";
} elsif ($in{'rp'} eq 'show_news') { 
		print qq|<td style="background-color:lightgrey;border:1px dashed black;padding: 4px;" width=$width_news><div style="height:$height_news| . qq|px;overflow:auto;">|;
		&show_news($GameValues{'GameFile'}); 
		print "</div></td>\n";
# Display a list of games in progress
} elsif ($in{'rp'} eq 'games') { 
	print "<td width=$rp_width>";
	my $sql = "SELECT GameName, GameFile, GameStatus FROM Games WHERE GameStatus>1 AND GameStatus<6;";
	&rp_list_games($sql,'Games In Progress');
	print "</td>\n";
# Display a list of new games
} elsif ($in{'rp'} eq 'games_new') { 
	print "<td width=$rp_width>";
	my $sql = "SELECT GameName, GameFile, GameStatus FROM Games WHERE GameStatus = 7 OR GameStatus = 0;";
	&rp_list_games($sql,'New Games');
	print "</td>\n";
# Display a list of games needing a replacement player
} elsif ($in{'rp'} eq 'games_replacement') { 
	print "<td width=$rp_width>";
	my $sql = "SELECT GameName, GameFile, GameStatus FROM Games WHERE GameStatus = 5;";
	&rp_list_games($sql,'Games needing Players');
	print "</td>\n";
# Display a list of completed games
} elsif ($in{'rp'} eq 'games_complete') { 
	print "<td width=$rp_width>";
	my $sql = "SELECT GameName, GameFile, GameStatus FROM Games WHERE GameStatus = 9 ORDER BY Games.NextTurn DESC;";
	&rp_list_games($sql,'Completed Games');
	print "</td>\n";
# Display a list of my races
} elsif ($in{'rp'} eq 'my_races') { 
	print "<td width=$rp_width>";
	my $sql = qq|SELECT Races.*, User.User_ID FROM User INNER JOIN Races ON User.User_Login = Races.User_Login WHERE ((User.User_ID)=| . $session->param("userid") . qq|) ORDER BY RaceName;|;
	&list_races($sql);
	print "</td>\n";
# Display a list of players
} elsif ($in{'rp'} eq 'list_players') { 
	print "<td width=$rp_width>";
	my $sql = qq|SELECT User_Event.GameFile, User.User_Name, User.User_ID, User_Event.Invite_Status FROM User_Event INNER JOIN User ON User_Event.User_ID = User.User_ID WHERE (((User_Event.GameFile)=$in{'GameFile'}));|;
	&list_players($sql);
	print "</td>\n";
#} else { print qq|<td width="$rp_width"></td>\n|;
}

print "</tr>\n</table>\n";
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
<form name="login" method=$FormMethod action="$WWW_Scripts/page.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
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
	my $Date =&GetTimeString();
	my $userid=$session->param("userid");
	my $User_Login = $session->param("userlogin");
	my $User_Email = $session->param("email");
	my $new_password = $in{'User_Password'};
	my $hash = $new_password . $secret_key;
	my $userhash = sha1_hex($hash); 
	my $db = &DB_Open($dsn);
	my $sql = qq|UPDATE User SET User_Password=\'$userhash\', User_Modified=\'$Date\'  WHERE User_ID=$userid;|;
	my $sth = &DB_Call($db,$sql);
  $sth->finish(); 

	print "Password changed for $User_Login.\n";
  #email user to let them know
  my $MailTo = $User_Email;
  my $MailFrom = $mail_from;
  my $Subject = "$mail_prefix Password changed for $User_Login";
  my $Message = "Password changed for $User_Login";
  &LogOut(100,"Emailed password change for $User_Login", $LogFile);
  my $smtp = &Mail_Open;
  &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
  &Mail_Close($smtp);
	print "</td>\n";
}

sub edit_profile {
	my ($sql) = @_;     
	my $id = $session->param("userid");
  my ($User_ID, $User_Login, $User_First, $User_Last, $User_Email, $User_Bio, $EmailTurn, $EmailList, $User_Timezone);

	my $db = &DB_Open($dsn); 
	print "<td>\n";
	if (my $sth = &DB_Call($db,$sql)) {
    my $row = $sth->fetchrow_hashref();
       # Extract the desired columns
    ($User_ID, $User_Login, $User_First, $User_Last, $User_Email, $User_Bio, $EmailTurn, $EmailList, $User_Timezone) =  ($row->{'User_ID'}, $row->{'User_Login'}, $row->{'User_First'}, $row->{'User_Last'}, $row->{'User_Email'}, $row->{'User_Bio'}, $row->{'EmailTurn'}, $row->{'EmailList'}, $row->{'User_Timezone'});
#		$EmailTurn = &checkboxnull($EmailTurn);
#		$EmailList = &checkboxnull($EmailList);
    $sth->finish();
  } else { &LogOut(10,"ERROR: Finding edit_profile",$ErrorLog); }
	&DB_Close($db);
print <<eof;
<form name="login" method=$FormMethod action="$WWW_Scripts/page.pl">
<input type=hidden name="lp" value="profile">
<input type=hidden name="cp" value="update_profile">
<input type=hidden name="rp" value="">
<input type=hidden name="User_ID" value="$User_ID">
<input type=hidden name="User_Login" value="$User_Login">
<table>
<tr><td>First Name:</td><td> <input type=text name="User_First" value="$User_First" size=32 maxlength=32></td></tr>
<tr><td>Last Name:</td><td><input type=text name="User_Last" value="$User_Last" size=32 maxlength=32></td></tr>
<tr><td>Email Address: </td><td><input type=text name="User_Email" value="$User_Email" size=32 maxlength=32></td></tr>  
<tr><td>Bio: </td><td><textarea name="User_Bio" value="$User_Bio" cols="40" rows="5">$User_Bio</textarea></td></tr>
<tr><td>TimeZone: </td>
<td>
<select name="User_Timezone">
eof

foreach my $t (@timezones) { 
  if ($t eq $User_Timezone) {  print qq|<OPTION value="$User_Timezone" SELECTED>$User_Timezone</OPTION>|; }
  else { print qq|<OPTION value="$t">$t</OPTION>\n|; } 
}

print <<eof;
</select>
</td></tr>
</table>
<INPUT type="Checkbox" name="EmailTurn" value=$EmailTurn $Checked[$EmailTurn]>Receive Turns via Email</P>
<INPUT type="Checkbox" name="EmailList" value=$EmailList $Checked[$EmailList]>Receive New Game Notifications</P>
<input type=submit name="Submit" value="Update">
</form>
<form>
eof

print "</form></td>\n";
}

sub show_profile {
	my ($sql) = @_;
	my %Profile;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    my $row = $sth->fetchrow_hashref(); 
    %Profile = %{$row};  
    $sth->finish();
  }
  &DB_Close($db);
#   foreach my $key (keys %Profile) {
#     print "$key => $Profile{$key}\n";
#   }
	print qq|<table>\n|;
	print qq|<tr><td><b>User ID:</b></td><td>$Profile{'User_Login'}</td></tr>\n|;
	print qq|<tr><td><b>Name:</b></td><td>$Profile{'User_First'} $Profile{'User_Last'}</td></tr>\n|;
	print qq|<tr><td><b>Email:</b></td><td>$Profile{'User_Email'}</td></tr>\n|;
	print qq|<tr><td><b>Serial:</b></td><td>$Profile{'User_Serial'}</td></tr>\n|;
	print qq|<tr><td><b>Bio:</b></td><td>$Profile{'User_Bio'}</td></tr>\n|;
	print qq|<tr><td><b>Timezone:</b></td><td>$Profile{'User_Timezone'}</td></tr>\n|;
	print qq|<tr><td><b>Receive Turns via Email:</b></td><td>$Checked_Display[$Profile{'EmailTurn'}]</td></tr>\n|;
	print qq|<tr><td><b>Receive New Game Notifications:</b></td><td>$Checked_Display[$Profile{'EmailList'}]</td></tr>\n|;
	print qq|<tr><td><b>Member Since:</b></td><td>$Profile{'User_Creation'}</td></tr>\n|;
	print qq|<tr><td><b>Last Modified:</b></td><td>$Profile{'User_Modified'}</td></tr>\n|;
	print qq|<tr><td></td></tr>\n|;
	print qq|<tr><td>$Profile{'User_Status_Detail'}</td></tr>\n|;
	print qq|</table>\n|;

print <<eof
<form name="profile" method=$FormMethod action="$WWW_Scripts/page.pl">
<input type=hidden name="lp" value="profile">
<input type=hidden name="cp" value="edit_profile">
<input type=hidden name="rp" value="my_games">
<input type=submit name="Submit" value="Edit Profile">
</form>
eof
}

sub update_profile {
  use Email::Valid;
	print "<td>\n";
	my $Date = &GetTimeString();
	my $User_Login = $in{'User_Login'};
#	my $User_Login = $session->param("userlogin");
	my $User_ID = $in{'User_ID'};
	my $User_First = $in{'User_First'};
	my $User_Last = $in{'User_Last'};
	my $User_Email = $in{'User_Email'};
  my $valid_email = Email::Valid->address($User_Email);
	my $User_Bio =$in{'User_Bio'};
  my $User_Timezone = $in{'User_Timezone'};
  print "TimeZone: $User_Timezone\n";
  $session->param("timezone", $User_Timezone);  
  $session->flush;  # This saves the changes to the session
	my $EmailList = &checkboxnull($in{'EmailList'});
	my $EmailTurn = &checkboxnull($in{'EmailTurn'});
  
  if ($User_First && $User_Last && $User_Login && $User_Email && $valid_email && $User_ID) {
  	my $db = &DB_Open($dsn);
  	#my $sql = "UPDATE User SET User_Login='$User_Login', User_First='$User_First',  User_Last='$User_Last', User_Email='$User_Email', User_Bio='$User_Bio', EmailTurn = $EmailTurn, EmailList = $EmailList, User_Modified='$Date' WHERE User_ID=$userid;";
  	my $sql = qq|UPDATE User SET User_First='$User_First',  User_Last='$User_Last', User_Email='$User_Email', User_Bio='$User_Bio', User_Timezone='$User_Timezone', EmailTurn = $EmailTurn, EmailList = $EmailList, User_Modified='$Date' WHERE User_ID=$User_ID AND User_Login='$User_Login';|;
  	if (my $sth = &DB_Call($db,$sql)) { 
  		&LogOut(100,"User: User $User_ID : $User_Login updated",$LogFile); 
#  		$session->param("userlogin",$User_Login);
  		$session->param("email",$User_Email);
  		print "User Updated\n";
      $sth->finish();
  	} else { &LogOut(10,"ERROR: update_profile failed updating for User:$User_Login:$User_ID:$User_ID",$ErrorLog);}
  	&DB_Close($db);
	# Need to close the database to get the changes to display immediately.
  } else {
    # tell the user they screwed up
    print "<P>Sorry, but there was a problem with your submission:\n";
    print "<ul>\n";
    unless ($User_First) { print "<li>First Name is a required field.</li>\n"; }
    unless ($User_Last)  { print "<li>Last Name is a required field.</li>\n"; }
    unless ($User_Email) { print "<li>Email Address is a required field.</li>\n";}
    if ($User_Email && !$valid_email) { print "<li>The email address you entered ( $User_Email ) does not detect as valid.</li>\n";  }
    print "</ul>\n";
    print "<P>Please try again!<P>\n";
    &LogOut(200,"Account: User1: $User_First, User2: $User_Last, Login: $User_Login, Email: $User_Email",$ErrorLog);
  }
  my $userid = $session->param("userid");
	&show_profile("SELECT * FROM User WHERE User_ID = $userid;");
	print "</td>\n";
}

sub show_my_new {
	my $counter;
	my $LoopPosition = 0;
	my $create_game = 0;
	my $def_game = 0; 
	my $table;
	# Read in all of the new games
	my $sql = qq|SELECT * FROM Games WHERE (GameStatus=6 Or GameStatus=7) AND HostName = \'$userlogin\';|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { 
      $counter++; 
      %GameValues = %{$row};
	#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
			@GameData[$counter] = { %GameValues };
			if ($GameData[$counter]{'GameStatus'} == 6) { $create_game = 1; } # if there are any games in create status
			if ($GameData[$counter]{'GameStatus'} == 7) { $def_game = 1; } # if there are any games in def status
		}
    $sth->finish();
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
				$table .= "<tr><td>$GameStatus[$GameData[$LoopPosition]{'GameStatus'}]</td><td>$GameData[$LoopPosition]{'GameName'}</td><td><a href=$WWW_Scripts/page.pl?lp=game&cp=create_game_size&rp=new_games&GameFile=$GameData[$LoopPosition]{'GameFile'}&GameName=$GameData[$LoopPosition]{'GameName'}>$GameData[$LoopPosition]{'GameFile'}</a></td></tr>\n";
			}
			if ($GameData[$LoopPosition]{'GameStatus'} == 7 ) {
				$table .= "<tr><td>$GameStatus[$GameData[$LoopPosition]{'GameStatus'}]</td><td>$GameData[$LoopPosition]{'GameName'}</td><td><a href=$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=new_games&GameFile=$GameData[$LoopPosition]{'GameFile'}>$GameData[$LoopPosition]{'GameFile'}</a></td></tr>\n";
			}
			$LoopPosition++;
		}
	}
	$table .= "</table>\n";
	if ($create_game || $def_game) { print $table; } 
	else { print qq|<P>No New Games. <a href="$WWW_Scripts/page.pl?lp=game&cp=create_game&rp=new_games">Create one</a>?\n|; }
}

sub show_new_games {	# Display new games
	my ($sql) = @_; 
	my $db = &DB_Open($dsn);
	my $new_found = 0;
	my $table = "";
	print "<h2>New Games</h2>\n";
	$table = "<table border=1>\n";
	$table .= "<th></th><th>Game Name</th><th>Host ID</th><th>Description</th>\n";
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { 
      %GameValues = %{$row};
	#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			$table .= "<tr>\n"; 
			$table .= qq|<td><img src="$StatusBall{$GameStatus[$GameValues{'GameStatus'}]}" alt='Status' border="0">$GameStatus[$GameValues{'GameStatus'}]</td>\n|;  
			$table .= qq|<td><A href="$WWW_Scripts/page.pl?lp=game&cp=show_game&rp=new_games&GameFile=$GameValues{'GameFile'}">$GameValues{'GameName'}</a></td>\n|;
			$table .= "<td>$GameValues{'HostName'}</td>\n";
			$table .= "<td>$GameValues{'GameDescrip'}</td>\n";
			$table .= "</tr>\n"; 
			$new_found++;
		}
    $sth->finish();
	} else { &LogOut(0, "show_new failed", $ErrorLog); }
	&DB_Close($db);
	$table .= "</table>\n"; 
	if ($new_found) { print $table; }
	else { print qq|No New Games Found. <a href="$WWW_Scripts/page.pl?lp=game&cp=create_game&rp=">Create one!</a>|; }
}

sub process_game_leave {
  # Leave a game that has not yet started.
	my ($GameFile, $PlayerID) = @_;
	#my $sql = qq|DELETE User_Login, GameFile, PlayerID FROM GameUsers WHERE User_Login='$userlogin' AND GameFile='$GameFile' AND PlayerID=$PlayerID;|;
	my $sql = qq|DELETE FROM GameUsers WHERE User_Login='$userlogin' AND GameFile='$GameFile' AND PlayerID=$PlayerID;|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
    &LogOut(100,"$userlogin left game $GameFile", $LogFile);
    $sth->finish(); 
  }
  # Need to let the host know. Figure out who the host is first.
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
  if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};  
    &LogOut(100,"Fetching Host name for $GameFile", $LogFile);
    $sth->finish();
  }
  $sql = qq|SELECT * FROM User WHERE User_Login = '$GameValues{'HostName'}';|;
  if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %HostValues = %{$row};  
    #email host to let them know
    my $MailTo = $HostValues{'User_Email'};
    my $MailFrom = $mail_from;
    my $Subject = "$mail_prefix $GameValues{'GameName'} : User $userlogin Left";
    my $Message = "User $userlogin left your game $GameValues{'GameName'} ($GameFile)."; # Same answer for Remove as Leave
    &LogOut(100,"Emailing host $GameValues{'HostName'} at $HostValues{'User_Email'} for $GameFile about $userlogin leaving", $LogFile);
    my $smtp = &Mail_Open;
    &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
	  &Mail_Close($smtp);
    $sth->finish();
  } else { &LogOut(0, "Failed to email host about new player $userlogin leaving $GameFile", $ErrorLog);}
	&DB_Close($db);
}

sub process_game_remove {
  # Remove a player from a game that has not yet started (much like process_game_leave)
	my ($GameFile, $PlayerID) = @_;
	#my $sql = qq|DELETE User_Login, GameFile, PlayerID FROM GameUsers WHERE GameFile='$GameFile' AND PlayerID=$PlayerID;|;
  #my $sql = qq|DELETE GameUsers.* FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((Games.HostName)='$userlogin') AND ((GameUsers.GameFile)='$GameFile') AND ((GameUsers.PlayerID)=$PlayerID));|;
  #my $sql = qq|DELETE GameUsers FROM GameUsers INNER JOIN Games ON Games.GameFile = GameUsers.GameFile WHERE Games.HostName = '$userlogin' AND GameUsers.GameFile = '$GameFile' AND GameUsers.PlayerID = $PlayerID;|;
  #my $sql = qq|DELETE FROM GameUsers INNER JOIN Games ON Games.GameFile = GameUsers.GameFile WHERE Games.HostName = '$userlogin' AND GameUsers.GameFile = '$GameFile' AND GameUsers.PlayerID = $PlayerID;|;
  my $sql = qq|DELETE GameUsers FROM GameUsers JOIN Games ON Games.GameFile = GameUsers.GameFile WHERE Games.HostName =  '$userlogin' AND GameUsers.GameFile = '$GameFile' AND GameUsers.PlayerID = $PlayerID;|;
 	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
    &LogOut(100,"$userlogin removed $playerID removed from game $GameFile $sql" , $LogFile);
    $sth->finish(); 
  }
	&DB_Close($db);
}

sub show_turngeneration {
	# Display the turn generation schedule based on gametype
	my ($GameFile, $GameType, $DailyTime, $HourlyTime, $HourFreq, $DayFreq, $AsAvailable) = @_;
  my $output='';
# 	# Display the Turn Generation Schedule formatted for GameType
 	$output .= "<P><b>Turn Generation Schedule</b>:\n";
	# Display the Turn Generation Schedule formatted for GameType
	if ($GameType == 4) { $output .= "Turns generated only when all turns are in.\n"; } 
	elsif ($GameType == 3) { $output .= " Turns Generated Manually.\n"; }
	elsif ($GameType == 2) { 
    if ($HourlyTime >=1) {
		  $output .= " Turns generated every $HourlyTime hours"; 
    } elsif ($HourlyTime < 1) {
      my $minutes = int(($HourlyTime * 60) + .5);
      $output .=  " Turns generated every $minutes minutes";
    }
		if ($AsAvailable) { $output .=  " or when all turns are in"; }
		$output .=  ".\n";
		$output .=  "<table border=1>\n<tr>\n";
		for (my $i=0; $i < 7; $i++) { $output .= "<th>$WeekDays[$i]</th>\n"; }
		$output .=  "</tr>\n<tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($DayFreq, $i, 1);
	 		if ($day) { $output .=  "<td align=center>Yes</td>\n"; }
	 		else { $output .=  "<td align=center>No</td>\n"; }
		}
		$output .=  "</tr>\n</table>\n";
		# Print the hours turns will generate
		$output .=  "\n";
		$output .=  "<table border=1><tr>\n";
		for (my $i=0; $i <=23; $i++) { 
			if ($i/12 == int($i/12)) { $output .= "</tr><tr>\n"; }
		 		my $hour = substr($HourFreq, $i, 1);
		 		if ($hour) { $output .=  "<td align=center>$i:00</td>\n"; }
		 		else { $output .=  "<td align=center><strike>$i:00<strike></td>\n"; }
			}
			$output .=  "</tr>\n</table>\n";
	}
	elsif ($GameType == 1) {
		$output .=  " Turns generated daily"; 
		if ($AsAvailable) { $output .=  " or when all turns are in"; }
		$output .=  ".";
		$output .=  "<table border=1><tr>\n";
		for (my $i=0; $i < 7; $i++) { $output .=  "<th>$WeekDays[$i]</th>\n"; }
		$output .=  "</tr>\n<tr>\n";
		for (my $i=0; $i < 7; $i++) {
	 		my $day = substr($DayFreq, $i, 1);
	 		my $gen_time = &fixdate($DailyTime) . ':00'; 
	 		if ($day) { $output .=  "<td align=center>$gen_time</td>\n"; }
	 		else { $output .=  "<td align=center>-</td>\n"; }
		} 
		$output .=  "</tr></table>\n";
	} else { $output .=  "What kind of game IS this? \n"; &LogOut(0,"GameType Fail for $GameFile, $GameType", $ErrorLog);}
  return $output;
}

sub show_game {  
 	my ($GameFile) = @_;
	my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware);
	my $NextTurn;
	my $HSTFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.hst';
  my ($db, $sql);
  my $players = 1; # Are there players in the game
  my $playeringame;   
  my $player_file;  
  my $playercount;
  my @CHK;  
  &LogOut(100,"Processing show_game for $GameFile",$LogFile);
  # Set the user's timezone if valid
  my $dtnow = DateTime->now(time_zone => 'UTC');  # Create a DateTime object with the current time in UTC
  
	if ($GameFile) {
		$db = &DB_Open($dsn);
		# Get the values for the current game
		$sql = qq|SELECT Games.*, User.User_Email, User.User_Timezone FROM User INNER JOIN Games ON User.User_Login = Games.HostName WHERE Games.GameFile=\'$GameFile\';|;
		if (my $sth = &DB_Call($db,$sql)) {
      while (my $row = $sth->fetchrow_hashref()) {
        %GameValues = %{$row};  # Dereference the hash reference into %Profile
      }
      #while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
      $sth->finish();
		}

		# Determine if the player is already in the game
		$sql = qq|SELECT * FROM GameUsers WHERE User_Login = '$userlogin' AND GameFile = '$GameValues{'GameFile'}';|;
		$playeringame = 0; 
		if (my $sth = &DB_Call($db,$sql)) { 
      if (my @row = $sth->fetchrow_array()) { $playeringame = 1; }
      $sth->finish();
		} 
   
    # Display the Game Status Data
    if ($in{'status'}) { 
      &display_warning($in{'status'}); 
      # Display the warning if the error still exists
      if ($in{'status'} =~ /bug/ && $in{'status'} !~ /Fixed/) { print qq|<P>You can resubmit a corrected .x file to remove alert.</P>|; }
    }
    print "<table width=100%>\n";
    # Print Game Name (and Year if applicable)
    print "<tr>\n";
		print "<td align=left><b>$GameValues{'GameName'}</b></td>\n";
    # If the game isn't started, it has no .chk or .hst file, so checking would (obviously) error
    # We need this early to display the year
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6  && $GameValues{'GameStatus'} != 0) { 
  		($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
	    @CHK = &Read_CHK($GameFile); 
      print qq|<td align="center">Year $HST_Turn</td>\n|; 
    } else { print qq|<td align="center">Year 2399  ($GameValues{'GameFile'})</td>\n|; }
    print "</tr>\n";

    # Display the Game Status
    print "<tr>\n";
    if ($GameValues{'GameStatus'} eq 7) { print "<td>Game Status: New Game - Pending new players</td>\n";
		} elsif ($GameValues{'GameStatus'} eq 0) { print "<td>Game Status: New Game - Locked, Waiting for Host to Start</td>\n";
    } else { 
      print "<td align=left>Game Status: @GameStatus[$GameValues{'GameStatus'}]";
      if  ($GameValues{'GameStatus'} == 3) { print " $GameValues{'DelayCount'} times."; }
      print "</td>\n";
      print qq|<td align="center"><A HREF=\"$WWW_Scripts/download.pl?file=$GameFile.xy\">$GameFile.xy</A></td>\n|; 
    }
		print "</tr>\n";
    
    # Display associated game-related images 
    # There should be no movie file unless the game is ended. 
    if ($GameValues{'GameStatus'} == 9) {
      # Display the animated gif file created with movie_starmapper.pl
      my $movieFile = $Dir_Graphs . "/movies/" . $GameValues{'GameFile'} . '.gif';
      if (-f $movieFile) {
        print "<tr><td><img align=left src=\"/downloads/movies/" . $GameValues{'GameFile'} . ".gif\"></td></tr>\n";
      } else { print "<tr><td><i>No movie available</i></td></tr>\n"; }
      # Display the resources chart created with graph_score.pl
      my $graphFile = $Dir_Graphs . "/graphs/" . $GameValues{'GameFile'} . '.png';
      if (-f $graphFile) {
        print "<tr><td><img align=left src=\"/downloads/graphs/" . $GameValues{'GameFile'} . ".png\"></td></tr>\n";
      } else { print "<tr><td><i>No graph available</i></td></tr>\n"; }
    }
    
    # Display the Host ID and email
    print qq|<tr><td>Host ID: <a href="mailto:$GameValues{'User_Email'}">$GameValues{'HostName'}</a></td><td></td></tr>\n|;
		print "</table>\n";
    
    #Display ForceGen Parameters   
    if ($GameValues{'ForceGen'} && $GameValues{'ForceGenTurns'} && $GameValues{'ForceGenTimes'} && $GameValues{'GameStatus'} != 9) { 
			print "<P><i>Turns generate $GameValues{'ForceGenTurns'} years at a time for the next $GameValues{'ForceGenTimes'} turn generation(s)"; 
			if ($HST_Turn eq '2400' || $HST_Turn eq '2401' || $HST_Turn eq '') { print " not to include years 2400 and 2401, which will generate only one year"; }
			print ".</i>\n";
		}

    #Display Next Turn time
    if (($GameValues{'NextTurn'} > 0) && ($GameValues{'GameType'} == 1 || $GameValues{'GameType'} == 2) ) { 
			# Fix the display time for DST
			#my $NextTurnDST = &FixNextTurnDST($GameValues{'NextTurn'},$GameValues{'LastTurn'},1);
			if ($GameValues{'GameStatus'} == 4) {
				print "<br><font color=red>[PAUSED]</font>\n";
			} else {
				if ($GameValues{'GameStatus'} != 9) {
          my $next_turn_epoch = $GameValues{'NextTurn'};
          my $dtnext = DateTime->from_epoch(epoch => $next_turn_epoch, time_zone => 'UTC');
          if (DateTime::TimeZone->is_valid_name($timezone)) {
            $dtnext->set_time_zone($timezone);
            my $dtduration = $dtnext->epoch - $dtnow->epoch;           # Get hours and minutes until next turn
            my $sign = ($dtduration < 0) ? '-' : '';  # Use '-' if in the past
            my $dthours = int($dtduration / 3600);  # Calculate total hours
            my $dtminutes = int(($dtduration % 3600) / 60);  # Calculate remaining minutes
            print "<br><b>Next turn due on or before: " . $dtnext->strftime('%Y-%m-%d %H:%M:%S %Z') . " ($sign" . abs($dthours) . " hours, " . abs($dtminutes) . " minutes)</b>\n";
          } else {
            print "<br>Invalid timezone: $timezone\n";
          }
          print "<br>\n";
				}
			}
		} 

    #Display when the last turn was generated if it was.
    unless ($GameValues{'GameStatus'} == 7 || $GameValues{'GameStatus'} == 0 )  {
  		if ($GameValues{'LastTurn'}) { 
#         print "<br>Last turn generation: " . strftime("%Y-%m-%d %H:%M:%S %Z", localtime($GameValues{'LastTurn'})) . "\n";
         my $dtlast = DateTime->from_epoch(epoch => $GameValues{'LastTurn'}, time_zone => 'UTC');
        if (DateTime::TimeZone->is_valid_name($timezone)) {
          $dtlast->set_time_zone($timezone);
          print "<br>Last turn generation: " . $dtlast->strftime('%Y-%m-%d %H:%M:%S %Z') . "\n";
        } else {
          print "<br>Invalid timezone: $timezone\n";
        }
      }	else { print "<br>No turns have been generated yet.\n"; }
    } 
    
#     print "<br>Now: ". strftime("%Y-%m-%d %H:%M:%S %Z", localtime(time())); 
    if (DateTime::TimeZone->is_valid_name($timezone)) {
      $dtnow->set_time_zone($timezone);
      print "<br>Now: " . $dtnow->strftime('%Y-%m-%d %H:%M:%S %Z');
    } else {
      print "<br>Invalid timezone: $timezone\n";
    }
    
		# If next turn is undefined(0) AND it's a game in progress somehow, display that the 
		# next generation will be immediate
		if ($GameValues{'NextTurn'} ne 0 && $GameValues{'GameStatus'} ne 7 && $GameValues{'GameStatus'} ne 9 && $GameValues{'GameStatus'} ne 4 && $GameValues{'GameType'} ne 4) { 
      print "<P>Will gen with/on the next automated generation.\n";
    }
    print "\n";
      
    # Display the player information
    # Active Game
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6 && $GameValues{'GameStatus'} != 0) {  
      # Display turn generation schedule
  		my $turngen = &show_turngeneration($GameValues{'GameFile'}, $GameValues{'GameType'}, $GameValues{'DailyTime'}, $GameValues{'HourlyTime'}, $GameValues{'HourFreq'}, $GameValues{'DayFreq'}, $GameValues{'AsAvailable'});
      print $turngen;
      print "<P>\n";
      # Display Active Game data if an active game and this data exists
		  # display the game and player information from the .chk File
      
  		print "<table>\n";
      # This won't execute without a .chk file (not available if the game isn't started)
  		my($Position) = '3';
      my $Player = 0;
      my ($del, $del2); # html delete tag
      # Display player status, one line for each player in the .chk file
  		while (@CHK[$Position]) {  #Write .m file lines
  			my ($CHK_Status, $CHK_Name) = &Eval_CHKLine(@CHK[$Position]);    
        # If an error is reported in the .chk file (like Host File Locked) report it and then move on.
        if ($CHK_Status =~ /Error/) { print qq|<tr><td colspan="5">$CHK_Status</td></tr>|; $Position++; next; }
        $Player++;
  			my $XFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.x' . $Player;
  			my $MFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.m' . $Player;
  			($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($MFile);
  			$TurnYears = $HST_Turn - $turn +1; 
  			# Get the values for the current player
  			$sql = qq|SELECT Games.GameFile, User.User_File, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.PlayerStatus, _PlayerStatus.PlayerStatus_txt FROM _PlayerStatus INNER JOIN (User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login) ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerID)=$Player));|;
  			if (my $sth = &DB_Call($db,$sql)) {
          while (my $row = $sth->fetchrow_hashref()) { %PlayerValues = %{$row};  } 
          $sth->finish();
        }

  			# Modify display based on player status. If the player isn't active indicate such
  			if ($PlayerValues{'PlayerStatus'} == 1) { $del = ''; $del2 = ''; 
        } elsif ($PlayerValues{'PlayerStatus'} == 4) { $del = '<i>'; $del2 = '</i>';
        } elsif ($PlayerValues{'PlayerStatus'} == 3) { $del = '<small>'; $del2 = '</small>';
        } elsif ($PlayerValues{'PlayerStatus'} == 2) { $del = '<del>'; $del2 = '</del>';}
        if ($CHK_Status eq 'Deceased') { $del = '<del>'; $del2 = '</del>';}

  			print qq|<tr>\n|;
  			if (($CHK_Status eq 'Out') && $del ) { print qq|<td><img src="$TurnBall{Idle}" alt='Status' border="0" name="$CHK_Status"></a></td>\n|;} 
        # BUG: WHat does this do for a result of a hacked race file
  			else { print qq|<td><img src="$TurnBall{$CHK_Status}" alt='Status' border="0" name="$CHK_Status"></a></td>\n|; }  
  			if ($PlayerValues{'User_Login'} eq $userlogin ) { print qq|<td style="border-width: 1px;padding: 1px;border-style: dotted;border-color: gray;">$del|;} 
  			else { 	print "<td>$del"; }
        
        if (!($GameValues{'AnonPlayer'} ) || ($PlayerValues{'User_Login'} eq $userlogin) || ($GameValues{'GameStatus'} == 9 ) || ($GameValues{'HostName'} eq $userlogin && $GameValues{'HostAccess'})) { print "$PlayerValues{'User_Login'}</td>"; }
        else { print "Player $Player: </td>"; }
        
        print "<td>$del$CHK_Name$del2</td>";
        
        # Display the .m file link
        if (-f $MFile) { # Only show if the file is present)
          if ($del) {
            # no link if the player is dead
            print "<td>.m$Player</td>\n";
          } elsif ($GameValues{'SharedM'} ) { # Don't if game over
            # Always display link if .m files are shared
    	 			print qq|<td><A href=\"$WWW_Scripts/download.pl?file=$GameFile.m$Player\">.m$Player</A></td>\n|;
    	 		} elsif ($PlayerValues{'User_Login'} eq $userlogin  ) { 
            # Display link if the logged in user is the player
            print "<td><A href=\"$WWW_Scripts/download.pl?file=$GameFile.m$Player\">.m$Player</A></td>\n"; 
          } elsif (!$playeringame && $GameValues{'HostName'} eq $userlogin && $GameValues{'HostAccess'}) {
            # Display link if player is host but not in game
            print "<td><A href=\"$WWW_Scripts/download.pl?file=$GameFile.m$Player\">.m$Player</A> (Host Access)</td>\n"; 
    			} else { print "<td>.m$Player</td>\n"; }

          # Display the number of years included in the .m file
    			print qq|<td>|;
    			if ($TurnYears > 1) { print "($TurnYears years)"; }
    			print "</td>\n";
          
    			if ($CHK_Status eq 'Wrong Year') { 	print "<td><font color=red>$CHK_Status</font></td>\n"; 
    			} else {	
            if ($del) { print "<td>$del$CHK_Status$del2</td>\n";
            } else { print "<td>$CHK_Status</td>\n"; }
          }
        } else { print "<td>.m missing</td>\n<td></td>\n<td></td>\n"; }
                   
        unless ($GameValues{'GameStatus'} == 9) { # Don't display for finished game
          print '<td>';
          if (-f $XFile) {  
#             if ($del) {
#             # no link if the player is dead
#               print ".x$Player\n";
#             } elsif ($GameValues{'SharedM'}) { 
#               # Always display link if .m files are shared
#       	 			print qq|<A href=\"$WWW_Scripts/download.pl?file=$GameFile.x$Player\">.x$Player</A>\n|;
#       	 		} elsif ($PlayerValues{'User_Login'} eq $userlogin ) { 
#               # Display link if the logged in user is the player
#               print "<A href=\"$WWW_Scripts/download.pl?file=$GameFile.x$Player\">.x$Player</A>\n"; 
#             } elsif (!$playeringame && $GameValues{'HostName'} eq $userlogin && $GameValues{'HostAccess'}) {
#               # Display link if player is host but not in game
#               print "<A href=\"$WWW_Scripts/download.pl?file=$GameFile.x$Player\">.x$Player</A> (Host Access)\n"; 
#       			} else { print ".x$Player\n"; }

    				my $file_date = -M $XFile;
    				$file_date = &SubmitTime($file_date);
    				print "$file_date\n";
    			} else { print "Not Submitted\n"; }         
          
          if ($PlayerValues{'PlayerStatus'} == 4) { print ' (Idle)'; }
          elsif ($PlayerValues{'PlayerStatus'} == 3) { print ' (Banned)'; }
          elsif ($PlayerValues{'PlayerStatus'} == 2) { print ' (Inactive-Housekeeping AI)'; }
          if ($CHK_Status eq 'Deceased') { print " -Deceased"; }
          if (@CHK[$Position] =~ /HACKER/) { print ' (HACKED FILE)'; }; # Hacked race file
          print "</td>\n";
        }
        
        # Display the Remove Password button if applicable
        if ($in{'cp'} eq 'Remove PWD' && $session->param("userlogin") eq $GameValues{'HostName'}) {
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
        
        # Display the Replace Player Button if applicable
        if ($in{'cp'} eq 'Replace Player' && $session->param("userlogin") eq $GameValues{'HostName'}) {
      		# Get the User List
	        print qq|<td valign="bottom"><form><SELECT name=\"ReplaceName\">|;
          # Sort and limit to active players
        	$sql = "SELECT * FROM User WHERE User_Status=1 ORDER BY User_Login;";
        	if (my $sth = &DB_Call($db,$sql)) {
        		while (my $row = $sth->fetchrow_hashref()) { %ReplaceValues = %{$row};  
        #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
        			print qq|<OPTION value="$ReplaceValues{'User_Login'}">$ReplaceValues{'User_Login'}</OPTION>\n|;
        		}
            $sth->finish();
        	}
        	print qq|</SELECT>|;
  
          print qq|<BUTTON $host_style type="submit" name="Switch" value="Switch" | . &button_help('Switch') .  qq|>Switch</BUTTON>\n|;
          print qq|<input type=hidden name="Switch" value="Switch">\n|;
          print qq|<input type=hidden name="lp" value="profile_game">\n|;
          print qq|<input type=hidden name="rp" value="my_games">\n|;
          print qq|<input type=hidden name="cp" value="Switch">\n|;
          print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
          print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
          print qq|<input type=hidden name="PlayerID" value="$Player">\n|;
          print "</form>\n";
          print qq|</td>|;
        }

  			print "</tr>\n";
  			
        # Store the current player ID for future reference
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
  		if (($GameValues{'GameStatus'} =~ /^[234]$/) && ($current_player eq $userlogin)) {
  	  		&show_upload($GameValues{'GameName'},$GameFile);
  		} 
    } else {
      # Display Data for New Games 
#       print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
#   		print qq|<input type=hidden name="lp" value="profile_game">\n|;
#   		print qq|<input type=hidden name="rp" value="my_games">\n|;
#   		print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
#   		print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
      my $formPrefix = qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod><input type=hidden name="lp" value="profile_game"><input type=hidden name="rp" value="my_games"><input type=hidden name="GameFile" value="$GameValues{'GameFile'}"><input type=hidden name="GameName" value="$GameValues{'GameName'}">|;
      my $formSuffix = qq|</FORM>|;
  		# Display user information for unstarted games
  		my $UserLogin;
  		my $table;
      #my $sql = qq|SELECT Races.RaceName, Races.RaceID, * FROM GameUsers LEFT JOIN Races ON (GameUsers.User_Login = Races.User_Login) AND (GameUsers.RaceID = Races.RaceID)  WHERE (((GameUsers.GameFile)='$GameFile')) ORDER BY GameUsers.JoinDate;|;
      my $sql = qq|SELECT Races.RaceName, Races.RaceID, GameUsers.* FROM GameUsers LEFT JOIN Races ON (GameUsers.User_Login = Races.User_Login) AND (GameUsers.RaceID = Races.RaceID)  WHERE (((GameUsers.GameFile)='$GameFile')) ORDER BY GameUsers.JoinDate;|;
      if (my $sth = &DB_Call($db,$sql)) { 
  			$table = "<P><table border=1>\n";
  			$table .= "<tr><th>Pending Player User IDs</th><th>Race Name</th><th>Race File</th><th>Joined</th>";
        $players = 0;
  			# Find players currently in the (new) game
  			while (my $row = $sth->fetchrow_hashref()) { 
          %UserValues = %{$row};  
          if ($playercount == 0) { # only on the first player
      			# as we won't show the remove player once it's locked, no need for the table headers for it.
      			if ($GameValues{'GameStatus'} == 7 && $userlogin eq $GameValues{'HostName'}) { $table .= "<th>Remove</th>"; }
      			# as we won't show the game option once it's locked, no need for the table headers for it.
      			if ($GameValues{'GameStatus'} == 7 && $userlogin eq $UserValues{'User_Login'}) { $table .= "<th>Leave</th>"; }
            $table .= "</tr>\n";
          }
  				$table .= "<tr>\n";
  				$table .= qq|<td>$UserValues{'User_Login'}</td>|;
          # Don't show the race name unless its your own
          if ($userlogin eq $UserValues{'User_Login'}) {$table .= qq|<td align="center">$UserValues{'RaceName'}</td>|; }
          else { $table .= qq|<td><center>-----</center></td>|; }
          if ($userlogin eq $UserValues{'User_Login'}) {$table .= qq|<td>$UserValues{'RaceFile'}</td>|; }
          else { $table .= qq|<td><center>-----</center></td>|; }
  				if ($UserValues{'RaceID'}) { $table .= qq|<td>| . localtime($UserValues{'JoinDate'}) . qq|</td>\n|; }
  				#Don't permit players to leave or be removed unless the game is still awaiting players.
  				if ($GameValues{'GameStatus'} == 7 ) {  
            if ( $userlogin eq $GameValues{'HostName'} ) { #remove player as host
     					$table .= qq|$formPrefix<td><BUTTON $host_style type="submit" name="cp" value="Remove Player" | . &button_help("RemovePlayer") . qq|>Remove Player</BUTTON><input id="$UserValues{'PlayerID'}" type=hidden name="PlayerID" value="$UserValues{'PlayerID'}"></td>$formSuffix\n|; 
            }
  				  if ($userlogin eq $UserValues{'User_Login'}) {  # Leave game as player
  						# Uses Player ID, which at this point is a semi(random) unique number we can use to remove 
  						# the correct entry if the player has signed up more than once with the same RaceFile
  						$table .= qq|$formPrefix<td><BUTTON $user_style type="submit" name="cp" value="Leave Game" | . &button_help("LeaveGame") . qq|>Leave Game</BUTTON><input type=hidden name="PlayerID" value="$UserValues{'PlayerID'}"></td>$formSuffix\n|;
            } 
  				}
  				$table .= "</tr>\n";
  				$players = 1;
          $playercount++;
  			} 
        $sth->finish();
  			$table .= "</table>\n";
  			# If there are new players, print the player table otherwise there aren't any.
  			if ($players) { print $table; }
  			else { print "<h3><font color=red>No players yet.</font></h3>\n"; }
  		}
      
      # prevent display if the game is maxxed
      if ($playercount < $GameValues{'MaxPlayers'}) {
    		# Don't prompt to join game if you're already in it and the game doesn't permit duplicates
    		unless (&checknull($GameValues{'NoDuplicates'}) && $playeringame) {
          print $formPrefix;
    			# Display the player's races available to join the game.
    			if ($GameValues{'GameStatus'} == 7 ) {
            my $races_exist=0;
    				$sql = qq|SELECT * FROM Races WHERE User_Login = '$userlogin' ORDER BY RaceName;|;
            # Check to see if the player has any uploaded races
            if (my $sth = &DB_Call($db,$sql)) { 
    					while (my $row = $sth->fetchrow_hashref()) { 
                %RaceValues = %{$row};  
                $races_exist++;
                if ($races_exist == 1 ) { # only the first line
        				  print "<P>Select from my Available Races:\n";
        				  print qq|<SELECT name=\"RaceID\">\n|;
                }
                print qq|<OPTION value=$RaceValues{'RaceID'}>$RaceValues{'RaceName'}</OPTION>\n|;
               }
              $sth->finish();
            }
            if ($races_exist) { 
    				  # Join the game
  				    print qq|</SELECT>\n|;
  				    print qq|<BUTTON $user_style type="submit" name="cp" value="Join Game" | . &button_help("JoinGame") . qq|>Join Game</BUTTON>\n|;
            } else { print "<h3><font color=red>You cannot join a game without a race in your Profile. Would you like to <a href=\"/scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races\">upload one</a>?</font></h3>\n"; } 
    			} 
          print $formSuffix;  print "\n";
    		} else { print "<P>You can sign up only once. Host did not permit duplicate players.\n"; }
        } else { print "<P>No additional signups available. Game has reached the maximum player limit."; }
      # Display turn generation schedule
		  my $turngen = &show_turngeneration($GameValues{'GameFile'}, $GameValues{'GameType'}, $GameValues{'DailyTime'}, $GameValues{'HourlyTime'}, $GameValues{'HourFreq'}, $GameValues{'DayFreq'}, $GameValues{'AsAvailable'});
      print $turngen; 
      
    }
   
    print "<P>\n";
    # Display the Buttons
    # Add all the Host and game related buttons
		print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
		print qq|<input type=hidden name="lp" value="profile_game">\n|;
		print qq|<input type=hidden name="rp" value="my_games">\n|;
		print qq|<input type=hidden name="GameFile" value="$GameValues{'GameFile'}">\n|;
		print qq|<input type=hidden name="GameName" value="$GameValues{'GameName'}">\n|;
		print qq|<input type=hidden name="User_File" value="$player_file">\n|; 
        
    my $button_count = 1;  # Keep track of the number of buttons displayed
    # Display Refresh Button
    if ($GameValues{'GameStatus'} =~ /^[23479]$/) { print qq|<BUTTON $user_style type="submit" name="cp" value="Refresh" | . &button_help('Refresh') . qq|>Refresh</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Start Game Display Start Button
    if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '0' && $playercount > 0) { print qq|<BUTTON $host_style type="submit" name="cp" value="Start Game" | . &button_help('StartGame') . qq|>Start Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Lock the game and prepare to start
#		if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '7' && $playeringame) { print qq|<BUTTON $host_style type="submit" name="cp" value="Lock Game" | . &button_help('LockGame') . qq|>Lock Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '7') { print qq|<BUTTON $host_style type="submit" name="cp" value="Lock Game" | . &button_help('LockGame') . qq|>Lock Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Unlock the game 
		if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} eq '0') { print qq|<BUTTON $host_style type="submit" name="cp" value="Unlock Game" | . &button_help('UnlockGame') . qq|>Unlock Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Submit a news article by player or host
		if ($GameValues{'NewsPaper'} && ($current_player eq $userlogin || $GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} ne '9'))	{ print qq|<BUTTON $user_style type="submit" name="cp" value="Report News" | . &button_help("NewsPaper") . qq|>Report News</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Delay the game
		if ($GameValues{'GameDelay'} && ($GameValues{'GameType'} ne '3') && ($GameValues{'GameStatus'} ne '9') && ($current_player eq $userlogin))	{ print qq|<BUTTON $user_style type="submit" name="cp" value="Delay Turn" | . &button_help('GameDelay') . qq|>Delay Turn</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Force generate turns
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'HostForce'} && ($GameValues{'GameStatus'} ne '9')) 		{ print qq|<BUTTON $host_style type="submit" name="cp" value="Force Gen" | . &button_help('ForceGen') . qq|>Force Gen</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Restore the game from backup
		if ($GameValues{'GameRestore'} && $GameValues{'HostName'} eq $session->param("userlogin") && ($GameValues{'GameStatus'} ne '9') && ($GameValues{'GameStatus'} ne '0') && ($HST_Turn > 2400)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Restore Game" | . &button_help('GameRestore') . qq|>Restore Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Edit the game
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'HostMod'} ) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Edit Game" | . &button_help('EditGame') .  qq|>Edit Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Change the player status
		if ($GameValues{'HostName'} eq $session->param("userlogin")  && ($GameValues{'GameStatus'} =~ /^[234]$/)) 		{ print qq|<BUTTON $host_style type="submit" name="cp" value="Player Status" | . &button_help('PlayerStatus') . qq|>Player Status</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Pause/Unpause the game
		# Must be hosting the game, or in the game if the game permits
		if ($GameValues{'GamePause'} && $current_player eq $userlogin) { $pause_style = $user_style; } else { $pause_style = $host_style; }
		if (($GameValues{'GameStatus'} eq '4') && (($GameValues{'HostName'} eq $session->param("userlogin")) || (&checkbox($GameValues{'GamePause'}) && $current_player eq $userlogin))) { print qq|<BUTTON $pause_style type="submit" name="cp" value="UnPause Game"| . &button_help('GameUnPause') . qq|>UnPause Game</BUTTON>|; print qq|<input type=hidden name="GamePause" value="$GameValues{'GamePause'}">\n|; $button_count = &button_check($button_count);} 
		if (($GameValues{'GameStatus'} =~ /^[235]$/) && (($GameValues{'HostName'} eq $session->param("userlogin")) || (&checkbox($GameValues{'GamePause'}) && $current_player eq $userlogin))) { print qq|<BUTTON $pause_style type="submit" name="cp" value="Pause Game" | . &button_help('GamePause') . qq|>Pause Game</BUTTON>|; print qq|<input type=hidden name="GamePause" value="$GameValues{'GamePause'}">\n|; $button_count = &button_check($button_count);}
		# End the game
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[234]$/)) { print qq|<BUTTON $host_style type="submit" name="cp" value="End Game" | . &button_help('EndGame') . qq|>End Game</BUTTON>\n|; $button_count = &button_check($button_count);}
    # Restart Game
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $GameValues{'GameStatus'} eq '9') { print qq|<BUTTON $host_style type="submit" name="cp" value="Restart Game" | . &button_help('RestartGame') . qq|>Restart Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Change personal game state from active to Idle and vice versa.
		if (($current_player eq $userlogin) && ($player_status == 1) && ($GameValues{'GameStatus'} ne '9')) { print qq|<BUTTON $user_style type="submit" name="cp" value="Go Idle" | . &button_help('GoIdle') . qq|>Go Idle</BUTTON>\n|; $button_count = &button_check($button_count);}
		if (($current_player eq $userlogin) && ($player_status == 4) && ($GameValues{'GameStatus'} ne '9')) { print qq|<BUTTON $user_style type="submit" name="cp" value="Go Active" | . &button_help('GoActive') . qq|>Go Active</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Email Players
		if ($GameValues{'HostName'} eq $session->param("userlogin") && $players) { print qq|<BUTTON $host_style type="submit" name="cp" value="Email Players" | . &button_help('EmailPlayers') . qq|>Email Players</BUTTON>\n|; $button_count = &button_check($button_count);}
 		# Download the zip file. Don't bother displaying zip file option when there IS no history.
		if (($HST_Turn > 2400) && ($current_player eq $userlogin) ) { print qq|<BUTTON $user_style type="button" name="Download" | . &button_help('GetHistory') . qq| onClick = window.open("$WWW_Scripts/download.pl?file=$GameValues{'GameFile'}.zip")>Get History</BUTTON>\n|; $button_count = &button_check($button_count);}
 		# Download messages from .m and .x
		if (($current_player eq $userlogin) && ($HST_Turn >=2400))  { print qq|<BUTTON $user_style type="button" name="Messages" | . &button_help('Messages')   . qq| onClick = window.open("$WWW_Scripts/download.pl?file=$GameValues{'GameFile'}.msg")>Messages</BUTTON>\n|; $button_count = &button_check($button_count);}
		elsif (($GameValues{'HostName'} eq $session->param("userlogin") ) && ($HST_Turn >=2400) && $GameValues{'HostAccess'} ) { print qq|<BUTTON $host_style type="button" name="Messages" | . &button_help('Messages') . qq| onClick = window.open("$WWW_Scripts/download.pl?file=$GameValues{'GameFile'}.msg")>Messages</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Delete the game
    # Give me admin access to delete all of them, but the delete function requires game name and Host ID to match
    # And I don't have host id when I get there because I'm matching on user to be more secure.
		#if (($GameValues{'HostName'} eq $session->param("userlogin") || $userlogin eq 'rsteeves') && ($GameValues{'GameStatus'} =~ /^[04679]$/)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Delete Game" | . &button_help('DeleteGame') .  qq|>Delete Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[04679]$/)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Delete Game" | . &button_help('DeleteGame') .  qq|>Delete Game</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Remove Password
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[23459]$/)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Remove PWD" | . &button_help('RemovePWD') .  qq|>Remove PWD</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Replace Player
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[23459]$/)) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="Replace Player" | . &button_help('ReplacePlayer') .  qq|>Replace Player</BUTTON>\n|; $button_count = &button_check($button_count);}
		#Movies
    my $movieFile = $Dir_Graphs . "/movies/movie_$GameFile.gif";
    # Don't provide button if there's already a movie. 
    my $animateFile = "$Dir_Games/$GameValues{'GameFile'}/2400"; 
		if (($GameValues{'HostName'} eq $session->param("userlogin")) && ($GameValues{'GameStatus'} =~ /^[9]$/) && (not -f $movieFile) && (-d $animateFile) && (-f $imagemagick) && (-e $starmapper)) 	{print qq|<BUTTON $host_style type="submit" name="cp" value="Movie" | . &button_help('Animate') .  qq|>Animate</BUTTON>\n|; $button_count = &button_check($button_count);}
		# Set the DEF File
		if ($GameValues{'HostName'} eq $userlogin && ($GameValues{'GameStatus'} eq '6' )) 	{ print qq|<BUTTON $host_style type="submit" name="cp" value="DEF File" | . &button_help('DEFFile') .  qq|>DEF File</BUTTON>\n|; $button_count = &button_check($button_count);}
		print qq|</FORM>\n|;
		&DB_Close($db); 
    
    # Display the Fixed information 
    # don't display until the game is in progress. 
    my $fixfile = "$Dir_Games/$GameFile/fix";
#    if ($GameValues{'HostName'} eq $userlogin && $GameValues{'GameStatus'} =~ /^[2345]$/ && $HST_Turn != 2400 && -f $fixenabled) { 
    if ($GameValues{'GameStatus'} =~ /^[2345]$/ && -f $fixfile) { 
      &show_fix($GameFile); 
    }
  
		print qq|<hr><P>|;  
		if ($GameValues{'Notes'}) { print qq|<table border=1 width=100%><tr><td><b>Game Notes</b>: $GameValues{'Notes'}</td></tr></table>\n|; }

		# Display the TH game parameters
		&read_game($GameFile);
		# Display the Stars game parameters
		&read_def($GameFile);

    my $messagefile = "$Dir_Games/$GameFile/$GameFile.messages";
    # Create the .messages file if it's not there
    if ($GameValues{'PublicMessages'} && (!(-f $messagefile))) { &publicMessages($GameFile)}; # create public .messages file
    
    # Display Player Messages
    # don't display until the game is in progress. 
    if ($GameValues{'GameStatus'} =~ /^[2345]$/ && -f $messagefile) { 
      &show_messages($GameFile); 
    }
    
	# If there were no new games returned from the original query, display that.
  } else {
		print "<P>No Games found\n";
	}
}

sub show_client {  
 	my ($GameFile) = @_;
  use POSIX qw(strftime);
	my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware);
	my $HSTFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.hst';
	my $XYFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.xy';
  my ($db, $sql);
  my $players = 1; # Are there players in the game
  my @CHK;
  my $schedule;
  my $status;  
  &LogOut(100,"Processing show_client for $GameFile",$LogFile);
  my $dtnow = DateTime->now(time_zone => 'UTC');  # Create a DateTime object with the current time in UTC
  
	if ($GameFile) {
		$db = &DB_Open($dsn);
		# Get the values for the current game
		$sql = qq|SELECT Games.*, User.User_Email FROM User INNER JOIN Games ON User.User_Login = Games.HostName WHERE Games.GameFile=\'$GameFile\';|;
		if (my $sth = &DB_Call($db,$sql)) {
        my $row = $sth->fetchrow_hashref(); 
        %GameValues = %{$row};  
        #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
      $sth->finish();
		}

    # Display the Game Status Data
    if ($in{'status'}) { 
      &display_warning($in{'status'}); 
      # Display the warning if the error still exists
      if ($in{'status'} =~ /bug/ && $in{'status'} !~ /Fixed/) { $status .= qq|You can resubmit a corrected .x file to remove alert.|; }
    }
    $status .= $in{'status'};
    
    # Print Game Name (and Year if applicable)
		print "<br>game-name=$GameValues{'GameName'}\n";
		print "<br>short-game-name=$GameValues{'GameFile'}\n";
    # We need this early to display the year
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6  && $GameValues{'GameStatus'} != 0) { 
  		($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
      @CHK = &Read_CHK($GameFile); 
      print qq|<br>game-year=$HST_Turn\n|; 
    } else { print qq|game-year=2399 \n|; }

    # Display the Game Status
    if ($GameValues{'GameStatus'} eq 7) { $status .= "New Game - Pending new players\n";
		} elsif ($GameValues{'GameStatus'} eq 0) { $status.="New Game - Locked, Waiting for Host to Start\n";
    } else { 
      $status.= "@GameStatus[$GameValues{'GameStatus'}]";
      if  ($GameValues{'GameStatus'} == 3) { $status .= " $GameValues{'DelayCount'} times."; }
    }
    print "<br>status=$status\n";
    
    # Display the Host ID and email
    print qq|<br>hosted-by=$GameValues{'HostName'}\n|;
        
    #Display Next Turn time
    if (($GameValues{'NextTurn'} > 0) && ($GameValues{'GameType'} == 1 || $GameValues{'GameType'} == 2) ) { 
			# Fix the display time for DST
# 			my $NextTurnDST = &FixNextTurnDST($GameValues{'NextTurn'},$GameValues{'LastTurn'},1);
			if ($GameValues{'GameStatus'} == 4) {
				print "<br>next-gen=[PAUSED]\n";
			} else {
				if ($GameValues{'GameStatus'} != 9) {
#           my $time_difference =  $NextTurnDST - time();
#           my $hours = int($time_difference / 3600);                # Total hours
#           my $minutes = int(($time_difference % 3600) / 60);       # Remaining minutes
#					print "<br>next-gen-time=Next turn due on or before: " . $dtnext->strftime('%Y-%m-%d %H:%M:%S %Z') . " ($sign" . abs($dthours) . " hours, " . abs($dtminutes) . " minutes)</b>\n";
          my $next_turn_epoch = $GameValues{'NextTurn'};
          my $dtnext = DateTime->from_epoch(epoch => $next_turn_epoch, time_zone => 'UTC');
          if (DateTime::TimeZone->is_valid_name($timezone)) {
            $dtnext->set_time_zone($timezone);
            my $dtduration = $dtnext->epoch - $dtnow->epoch;           # Get hours and minutes until next turn
            my $sign = ($dtduration < 0) ? '-' : '';  # Use '-' if in the past
            my $dthours = int($dtduration / 3600);  # Calculate total hours
            my $dtminutes = int(($dtduration % 3600) / 60);  # Calculate remaining minutes
            print "<br><b>next-gen-time=Next turn due on or before: " . $dtnext->strftime('%Y-%m-%d %H:%M:%S %Z') . " ($sign" . abs($dthours) . " hours, " . abs($dtminutes) . " minutes)</b>\n";
          } else {
            print "<br>next-gen-time=Invalid timezone: $timezone\n";
          }
				}
			}
		} elsif ( $GameValues{'GameType'} == 3 ) {
    	print "<br>next-gen-time=Turns generated as Required.\n";
    } elsif ( $GameValues{'GameType'} == 4) {
    	print "<br>next-gen-time=Turns generated when all turns are in.\n";
    }

    #Display when the last turn was generated if it was.
    unless ($GameValues{'GameStatus'} == 7 || $GameValues{'GameStatus'} == 0 )  {
  		if ($GameValues{'LastTurn'}) { 
#        print "<br>last-gen=" . strftime("%Y-%m-%d %H:%M:%S %Z", localtime($GameValues{'LastTurn'})) . "\n";
        my $dtlast = DateTime->from_epoch(epoch => $GameValues{'LastTurn'}, time_zone => 'UTC');
        if (DateTime::TimeZone->is_valid_name($timezone)) {
          $dtlast->set_time_zone($timezone);
          print "<br>last-gen: " . $dtlast->strftime('%Y-%m-%d %H:%M:%S %Z') . "\n";
        } else { print "<br>Invalid timezone: $timezone\n"; }
  		} else { print "<br>last-gen=No turns have been generated yet.\n"; }
    } 
    
    # Get the time the game started by using the .xy file time stamp
    my @stats = stat($XYFile);
    my $mtime = $stats[9];
    print "<br>game-created=" . strftime("%Y-%m-%d %H:%M:%S %Z", localtime($mtime)) . "\n"; 
    
    # Get the time for "now"
    print "<br>current-time=" . strftime("%Y-%m-%d %H:%M:%S %Z", localtime(time())); 
    
    #Display ForceGen Parameters   
    if ($GameValues{'ForceGen'} && $GameValues{'ForceGenTurns'} && $GameValues{'ForceGenTimes'} && $GameValues{'GameStatus'} != 9) { 
			$schedule="Turns generate $GameValues{'ForceGenTurns'} years at a time for the next $GameValues{'ForceGenTimes'} turn generation(s)"; 
			if ($HST_Turn eq '2400' || $HST_Turn eq '2401' || $HST_Turn eq '') { $schedule .= " not to include years 2400 and 2401, which will generate only one year"; }
			$schedule .= ".\n";
		}
    
		# If next turn is undefined(0) AND it's a game in progress somehow, display that the 
		# next generation will be immediate
    if ($GameValues{'NextTurn'} ne 0 && $GameValues{'GameStatus'} ne 7 && $GameValues{'GameStatus'} ne 9 && $GameValues{'GameStatus'} ne 4 && $GameValues{'GameType'} ne 4) { 
      # print "<br>next-gen-time=" . strftime("%Y-%m-%d %H:%M:%S %Z", localtime($GameValues{'NextTurn'})) . "\n";
      print "<br>next-gen-time=Will gen with/on the next automated generation.\n";
    }
   
    $schedule .= &show_turngeneration($GameValues{'GameFile'}, $GameValues{'GameType'}, $GameValues{'DailyTime'}, $GameValues{'HourlyTime'}, $GameValues{'HourFreq'}, $GameValues{'DayFreq'}, $GameValues{'AsAvailable'}); 
    print "<br>schedule=$schedule\n";
    
    # Display the player information
    # Active Game
    if ($GameValues{'GameStatus'} != 7 && $GameValues{'GameStatus'} != 6 && $GameValues{'GameStatus'} != 0) { 
      # Display Active Game data if an active game and this data exists
		  # display the game and player information from the .chk File
      
      # This won't execute without a .chk file (not available if the game isn't started)
  		my($Position) = '3';
      my $Player = 0;
      # Display player status, one line for each player in the .chk file
  		while (@CHK[$Position]) {  #Write .m file lines
  			my ($CHK_Status, $CHK_Name) = &Eval_CHKLine(@CHK[$Position]);    
        # If an error is reported in the CHK file (like Host File Locked) report it and then move on.
        if ($CHK_Status =~ /Error/) { print qq|$CHK_Status|; $Position++; next; }
        $Player++;
  			my $XFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.x' . $Player;
  			my $MFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.m' . $Player;
  			($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($MFile);
  			$TurnYears = $HST_Turn - $turn +1; 
  			# Get the values for the current player
  			$sql = qq|SELECT Games.GameFile, User.User_File, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.PlayerStatus, _PlayerStatus.PlayerStatus_txt FROM _PlayerStatus INNER JOIN (User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login) ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerID)=$Player));|;
  			if (my $sth = &DB_Call($db,$sql)) { 
          while (my $row = $sth->fetchrow_hashref()) { %PlayerValues = %{$row};  } 
          $sth->finish();
        }
  			# Modify display based on player status. If the player isn't active indicate such

        print "<br>player" . $Player . "-race=$CHK_Name";
                
  			if ($CHK_Status eq 'Wrong Year') { 	print "<br><font color=red>$CHK_Status</font>\n"; 
  			} else { print "<br>player" . $Player . "-turn=$CHK_Status"; }

        # Display the number of years included in the .m file
  			if ($TurnYears > 1) { print " ($TurnYears years)"; }
                 
        if (-f $XFile) {  
  				my $file_date = -M $XFile;
  				$file_date = &SubmitTime($file_date);
  				print " $file_date";
  			} else { print " Not Submitted"; }         
        
        if ($PlayerValues{'PlayerStatus'} == 4) { print ' (Idle)'; }
        elsif ($PlayerValues{'PlayerStatus'} == 3) { print ' (Banned)'; }
        elsif ($PlayerValues{'PlayerStatus'} == 2) { print ' (Inactive-Housekeeping AI)'; }
        if ($CHK_Status eq 'Deceased') { print " -Deceased"; }
        print "\n";
        
        # Store the current player ID for future reference
  			if ($PlayerValues{'User_Login'} eq $userlogin) { 
  				$current_player = $PlayerValues{'User_Login'}; 
  				$player_status = $PlayerValues{'PlayerStatus'}; 
  			}
  			undef %PlayerValues;
  			$Position++;
  		}
  	# If there was no game returned from the original query, display that.
    } else {
  		print "<br>No Games found\n";
  	}
		&DB_Close($db);   
  }
}

sub button_form {
	# might be useful at some point,but not yet
	my ($GameFile, $Var) = @_;
# moved to config
#	my $host_style = qq|style="color:red;width:120px;height:24;"|;
#	my $user_style = qq|style="width:120px;height:24;"|;
	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
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
  
  # GameValues for display of NewsPaper
  my $sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};  
    $sth->finish();
  }
	&DB_Close($db);	

	print "<td>\n";
	print "Submit an article to the Galactic News!\n";
	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
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
	open (OUT_FILE, ">$newsfile") || &LogOut(50, "create_news: failed to open $newsfile", $ErrorLog);
	print OUT_FILE "0\t0\t2400\tNo News Yet\n";
	close(OUT_FILE);
}

sub process_game_launch {
	($GameFile) = @_;
	my $counter = 0;
  
  #Get Game User Values
	# Determine how many players there are, and get all the race information
	# Reorder them based on the random player ID generated when they joined the game
	my $sql = qq|SELECT * FROM GameUsers WHERE GameFile = '$GameFile' ORDER BY PlayerID;|;
  #my $sql = qq|SELECT User.User_Email, User.EmailTurn, * FROM User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login WHERE (((GameUsers.GameFile)='$GameFile')) ORDER BY GameUsers.PlayerID;|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { 
      %GameUserValues = %{$row}; 
#			while ( my ($key, $value) = each(%GameUserValues) ) { print "<br>$key => $value\n"; }
			$counter++;
			@GameUserData[$counter] = { %GameUserValues };
		}
    $sth->finish();
	}

  # Get Game Values
	my $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { 
      %GameValues = %{$row};  
#			while ( my ($key, $value) = each(%GameUserValues) ) { print "<br>$key => $value\n"; }
		}
    $sth->finish();
	}

	# Confirm that there are enough players to launch, otherwise abort. 
	if ($counter >= $min_players) {
		# Update all of the player IDs in the database
		# based on the sort order from the random Player IDs
		for (my $i=1; $i <=$counter; $i++) {
      # Attempt to make the SQL query unique. 
			$sql = 	qq|UPDATE GameUsers SET PlayerID = $i WHERE PlayerID = $GameUserData[$i]{'PlayerID'} AND GameFile = '$GameFile' AND JoinDate = $GameUserData[$i]{'JoinDate'} AND RaceID = $GameUserData[$i]{'RaceID'};|;
			my $sth = &DB_Call($db,$sql);
      $sth->finish(); 
		}
		# Read the DEF file in, and push it back out with the race file information	
		my $def_file = "$Dir_Games/$GameFile/$GameFile.def"; 
		my @def_data = ();
		if (-f $def_file) { #Check to see if .def file is there.
			open (IN_FILE,$def_file) || &LogOut(0,"process_game_launch: cannot open $def_file!", $ErrorLog);
			chomp(@def_data = <IN_FILE>);
			close(IN_FILE);

			# Rewrite the outbound data with the race information
			# Change the outbound def file so if there's an error we still have the original
			$def_file_races = "$Dir_Games/$GameFile/$GameFile.df2";
			open (OUT_FILE, ">$def_file_races");
			print OUT_FILE "$def_data[0]\n"; # Game Name
			print OUT_FILE "$def_data[1]\n"; # Universe Values
			print OUT_FILE "$def_data[2]\n"; # Game Settings
			print OUT_FILE "$counter\n"; # of players

			# Print out the race information
			my $path;
			for (my $i=1; $i <=$#GameUserData; $i++) {
        # Get the location for the race for this player
        my %UserValues;
    		$sql = qq|SELECT * FROM User WHERE User_Login = \'$GameUserData[$i]{'User_Login'}\';|;
		    if (my $sth = &DB_Call($db,$sql)) {
          my $row = $sth->fetchrow_hashref();
          %UserValues = %{$row};
          $sth->finish();
		    }
  			#$path = "$Dir_Races/$UserValues{'User_File'}/$GameUserData[$i]{'RaceFile'}";
				$path = "$Dir_WINE$WINE_Races\\$UserValues{'User_File'}\\$GameUserData[$i]{'RaceFile'}";
				print OUT_FILE "$path\n";
			}
			# Print out the remaining game data
			for (my $i=4; $i <=12; $i++) {
				print OUT_FILE "$def_data[$i]\n";
			}
			close OUT_FILE; 
      umask 0002; 
      chmod 0664, $def_file_races;
		} else { 
			print "Game Definition File for $GameFile not found!\n"; 
			&LogOut(0,"Game Definition File $def_file not found at launch",$ErrorLog);
			return 0;
		}
 
		# Create the game from the command line
		#exec causes perl.exe to crash
		#exec($x);
		# Starting system with "1" makes Stars! launch asyncronously
		# important if for some reasons Stars! hangs (like a corrupt race file).
    # If this just won't work, try rebooting the PC because Stars! is hung up somewhere (at least, fixed it once)
    # We need to add another slash here for the wine CLI
  	my ($CreateGame) = $WINE_executable . ' -a ' . "$Dir_WINE\\$WINE_Games\\\\$GameFile\\\\$GameFile\.df2";   # Need the extra \\s
		&LogOut(50, "Creating Game $CreateGame", $LogFile);
    #chdir("/home/www-data/.wine/drive_c") or die "Cannot change directory: $!";
		#system(1,$CreateGame);
		my $exit_status = &call_system($CreateGame,0); # Creating game

		sleep 4; # Give Stars! time to create all the files

		my $new_hst_file = "$Dir_Games/$GameFile/$GameFile.hst";
		if (-f $new_hst_file) { 
		  &LogOut(50, "Game $CreateGame Created", $LogFile);
			# set the "last submitted date for players to "now". 
			$sql = qq|UPDATE GameUsers SET LastSubmitted = | . time() . qq| WHERE GameFile = \'$in{'GameFile'}\';|;
			if (my $sth = &DB_Call($db,$sql)) {
				&LogOut(100, "$GameFile User Last Submitted updated at Game Start", $LogFile);
        $sth->finish(); 
			} else {
				&LogOut(0, "$GameFile User Last Submitted failed to update at Game Start", $ErrorLog);
			}
      
      # Try to figure out when the next turn is due and update the date so
      # it doesn't just start generating
      # (Note it should be paused anyway)
		  my ($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs) = &GetTime; 
		  if ($GameValues{'GameType'} == 1 ) {   
			  # Determine when the next possible time is that turns are due
			  ($DaysToAdd1, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$WeekDay);
			  # now advance one interval from that, so you have a full interval
#			  ($DaysToAdd2, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$NextDayOfWeek);
			  # Set the time for the next turn on the right day
			  $NewTurn = $CurrentDateSecs + $DaysToAdd1*86400 + $DaysToAdd2*86400 +($GameValues{'DailyTime'} *60*60);
        # 221110 Fixing for DST 
        $NewTurn = &FixNextTurnDST($NewTurn, time(),0);
			  $sql = qq|UPDATE Games SET NextTurn = $NewTurn WHERE GameFile = \'$GameFile\' AND HostName=\'$userlogin\';|;
  			if (my $sth = &DB_Call($db,$sql)) {
  				&LogOut(100, "NextTurn set to $NextTurn for $GameFile and $userlogin", $LogFile);
          $sth->finish(); 
  			} else {
  				&LogOut(0, "Failed to update NextTurn for $Gamefile and $userLogin, $sql", $ErrorLog);
  			}
      }
      
      # Create the initial List file(s)
      &updateList($GameFile, 1);      
      # There's no need to clean the initial .m files, because there's no other player data included for the CA. 
      # set the game status to paused and send email 
			&process_game_status($GameFile, 'Launched', $userlogin); 
			&DB_Close($db);
			return 1;
		} else {
			print "<P>Game $GameFile Failed to Launch! (probably due to a corrupt race file): $CreateGame";
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

sub show_fix {
	#Display the current fixes for a game
	my ($GameFile) = @_;
	my @fixes;
	my $warningfile = "$Dir_Games/$GameFile/$GameFile.warnings";
	# Check to see if there is a warnings file
	if (!(-f $warningfile)) { # Create the new warning file if it doesn't exist
  	open (OUT_FILE, ">$warningfile") || &LogOut(100, "show_fix: could not create $warningfile", $ErrorLog); 
  	close(OUT_FILE);
    umask 0002; 
    chmod 0664, $warningfile;

	} 
  open (IN_FILE,$warningfile) || &LogOut(100, "show_fix: could not open $warningfile", $ErrorLog);
	@fixes = <IN_FILE>;
	close(IN_FILE);
  # Only print fixes if there are fixes
  if (@fixes) {  
    print qq|<hr>|; 
    print "<b>Results of the Bug/Exploit Detection:</b><P>";
		foreach my $key (@fixes) {
      print "$key<br>\n";
		}
#    } else { print "No fixes for bugs/cheats have been processed. Yeay!\n"; }
  } 
}

sub show_messages {
	#Display the current messages for a game
	my ($GameFile) = @_;
	my @messages;
	my $messagefile = "$Dir_Games/$GameFile/$GameFile.messages";
	# Check to see if there is a .messages file
	if ((-f $messagefile)) { 
    open (IN_FILE,$messagefile) || &LogOut(100, "show_messages: could not open $messagefile", $ErrorLog);
  	@messages = <IN_FILE>;
  	close(IN_FILE);
    # Only print messages if there are messages
    if (@messages) {  
      print qq|<hr>|; 
      print "<b>Player Messages:</b><P>";
  		foreach my $key (@messages) {
        print "$key<br>\n";
  		}
    } 
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
	my $newsfile = "$Dir_Games/$GameFile/$GameFile.news";
	my $HSTFile = "$Dir_Games/$GameFile/$GameFile.hst";
	my ($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
	if (!(-f $newsfile)) { # If there's no news file, create one. 
		&create_news($newsfile);
	}
	# Validate that the logged in user is a game member before we let them submit news

	my $valid_submitter = 0; 
	my $sql = qq|SELECT * FROM GameUsers WHERE GameFile = \'$GameFile\';|; 
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 	
    while (my $row = $sth->fetchrow_hashref()) { 
      my %UserValues = %{$row};  
			&LogOut(200, "News User: $UserValues{'User_Login'}  $userlogin", $LogFile); 
			if ($UserValues{'User_Login'} eq $userlogin) { 
        $valid_submitter = 1; 
        &LogOut(200, "Valid news from $userlogin", $LogFile); 
      }
		}
    $sth->finish();
	}
  # And then check to see if they're a host instead
  unless ($valid_submitter) {
		$sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|; 
		if (my $sth = &DB_Call($db,$sql)) { 	
      while (my $row = $sth->fetchrow_hashref()) { 
        my %UserValues = %{$row};  
				&LogOut(200, "News Host: $UserValues{'HostName'}  $userlogin", $LogFile); 
				if ($UserValues{'HostName'} eq $userlogin) { 
          $valid_submitter = 1; 
          &LogOut(200, "Valid news from host $userlogin", $LogFile); 
        }
			}
      $sth->finish();
    }
  }
	&DB_Close($db);

	if ($valid_submitter) {
		# Read in the old news
		open (IN_FILE,$newsfile) ||&LogOut(50, "Can\'t open news file $newsfile", $ErrorLog); 
		@news = <IN_FILE>;
		close(IN_FILE);
		# Write out the news with the current news at the beginning 
		# (So the data is from new to old)
		$newsfile = ">" . $newsfile;
		open (OUTFILE, $newsfile) || &LogOut(50, "Can\'t create news file $newsfile", $ErrorLog); 
		print OUTFILE $userlogin . "\t";  
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

sub show_news {
	#Display the current news for a game
	my ($GameFile) = @_;
	my @news;
	my ($id, $secs, $turn, $story, $l_time);
	my $newsfile = "$Dir_Games/$GameFile/$GameFile.news";
	# Check to see if there is a news file
	if (!(-f $newsfile)) { # Create the new file
		&create_news($newsfile);
	} else { open (IN_FILE,$newsfile) || &LogOut (0,"Can\'t open news file $newsfile", $ErrorLog);
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
 		"0My Games" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=my_games",
		"5My Completed" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=welcome&rp=games_complete",
		"1My In Progress" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=show_games_inprogress&rp=games",
		"4My New Games" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=show_my_new&rp=games_new",
		"6Create Game"	=> "$WWW_Scripts/page.pl?lp=game&cp=create_game&rp=",
		"9<hr>" 	=> ""
	);

  #	my $sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4));|;
	#my $sql = qq|SELECT GameName, GameFile, NewsPaper WHERE ((GameStatus)=2 Or (GameStatus)=3 Or (GameStatus)=4);|;
  my $sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4)) ORDER BY GameName;|;
  #my $sql = qq|SELECT Games.*, User.User_Login FROM User INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND ((Games.GameStatus)=2 Or (Games.GameStatus)=3 Or (Games.GameStatus)=4));|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
      my ($GameName, $GameFile, $NewsPaper) = ($row->{'GameName'}, $row->{'GameFile'}, $row->{'NewsPaper'});
      # Add a chacater to $GameName as part of html_left that will strip off the first character
      # Without this games with a number in the name will have it stripped out later. 
      # Making the number increment means the trick of using teh hash to sume results won't work.
      $GameName = '0' . $GameName;
      # Change the URL based on whether the game has Galactic News enabled
		  if (&checkbox($NewsPaper)) {
		    $menu_left{"<i>$GameName</i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=show_news&GameFile=$GameFile|;
		  } else { 	$menu_left{"<i>$GameName</i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=&GameFile=$GameFile|; }
		}
    $sth->finish();
	} else { &LogOut(10,"lp_list_games: Error finding list_games $sql",$ErrorLog); }
	&DB_Close($db);
	return %menu_left;
}

sub lp_list_new {
	my ($id) = @_;
	my %menu_left;
	%menu_left = 	(
 		"0My Games" 	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=show_first_game&rp=show_news",
		"5My Completed" 	=> "$WWW_Scripts/page.pl?lp=game&cp=welcome&rp=games_complete",
		"1My In Progress" 	=> "$WWW_Scripts/page.pl?lp=game&cp=welcome&rp=games",
		"4My New Games" 	=> "$WWW_Scripts/page.pl?lp=game&cp=show_my_new&rp=games_new",
		"6Create Game"	=> "$WWW_Scripts/page.pl?lp=profile_game&cp=create_game&rp=my_games",
		"9<hr>" 	=> ""
	);
	my $sql = qq|SELECT Games.*, User.User_Login, Games.GameStatus FROM User INNER JOIN (Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile) ON User.User_Login = GameUsers.User_Login WHERE (((User.User_ID)=$id) AND (Games.GameStatus)=7);|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
	    ($GameName, $GameFile) = ($row->{'GameName'}, $row->{'GameFile'});   
			$menu_left{"<i>$GameName<i>"} = qq|page.pl?lp=profile_game&cp=show_game&rp=&GameFile=$GameFile|; 
		}
    $sth->finish();
	} else { &LogOut(10,"ERROR: Finding list_new $sql",$ErrorLog); }
	&DB_Close($db);
	return %menu_left;
}

sub list_races {
	my ($sql) = @_;
	my $db = &DB_Open($dsn);
	my $c = 0;
	if ($in{'rp'} eq 'my_races') { 	print qq|<u>My Races</u>\n|; }
	else {print qq|<u>Races</u>\n|;}
	print "<table>\n";
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
	    my ($RaceName, $RaceFile, $RaceID) = ($row->{'RaceName'}, $row->{'RaceFile'}, $row->{'RaceID'});
			$c++;
			if ($in{'rp'} eq 'my_races') {
				print qq|<tr><td><a href=$WWW_Scripts/page.pl?lp=profile_race&cp=show_race&rp=my_races&RaceID=$RaceID>$RaceName</a></td></tr>\n|;
			} else { print qq|<tr><td><a href=$WWW_Scripts/page.pl?lp=profile_race&cp=show_race&rp=list_races&RaceID=$RaceID>$RaceName</a></td></tr>\n|; }
		}
    $sth->finish();
		unless ($c) {print "<tr><td>  No races found</td></tr>";}
	} else { &LogOut(10,"ERROR: Finding list_races $sql",$ErrorLog);}
	print "</table>\n";
	&DB_Close($db);
}

sub show_race {
	my ($sql) = @_;
  use StarsBlock;
	my %RaceValues;
	my $c=0; 
  if ($sql) {
  	$db = &DB_Open($dsn);
  	if (my $sth = &DB_Call($db,$sql)) {
        while (my $row = $sth->fetchrow_hashref()) {  %RaceValues = %{$row}; $c++; };  # Dereference the hash reference into %Profile
        $sth->finish();
  	} else { &LogOut(10,"ERROR: Finding show_race $sql", $ErrorLog); }
  	&DB_Close($db);
  }
	if ($c) {
		# Get $ver
    my $racepath = $Dir_Races . '/' . $RaceValues{'User_File'};
		my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($RaceValues{'RaceFile'},$racepath);
		print <<eof;
<table>
<tr><td>Race Name:</td><td>$RaceValues{'RaceName'}</td></tr>
<tr><td>Race Description:</td><td>$RaceValues{'RaceDescrip'}</td></tr>
<tr><td>Race File Name:</td><td><A HREF="/scripts/download.pl?file=$RaceValues{'RaceFile'}">$RaceValues{'RaceFile'}</A></td></tr>
<tr><td>Stars! Version:</td><td>$ver</td></tr>
</table>
eof

&show_race_block("$racepath/$RaceValues{'RaceFile'}");

print <<eof;
<form name="login" method=$FormMethod action="$WWW_Scripts/page.pl">
<input type="hidden" name="lp" value="profile_race">
<input type="hidden" name="cp" value="delete_race">
<input type="hidden" name="rp" value="my_races">
<input type="hidden" name="RaceID" value="$RaceValues{'RaceID'}">
<input type=submit name="Delete Race" value="Delete Race">
</FORM>
eof
		} else {
			print "<P>No Races found. Would you like to <a href=\"/scripts/page.pl?lp=profile_race&cp=upload_race&rp=my_races\">upload one</a>?\n";
#			&LogOut(0,"$userlogin failed to download Race File $racefile", $ErrorLog);
		}
}

sub upload_race {
print <<eof;
<td>
<FORM method=$FormMethod action="$WWW_Scripts/upload.pl" name="my_form" enctype="multipart/form-data">
<input type="hidden" name="lp" value="profile_race">
<input type="hidden" name="cp" value="process_race">
<input type="hidden" name="rp" value="my_races">
eof
print qq|	<TABLE>\n|;
print qq|		<TR>\n<TD>Race Name:</TD> <TD><INPUT type="text" | . &button_help("RaceName") . qq|name="RaceName" size="30"> (Mandatory)</TD>\n</TR> \n|;
print qq|		<TR>\n<TD>Race Description:</TD> <TD><TEXTAREA name="RaceDescrip" | . &button_help("RaceDescrip") . qq| rows="4" cols="50" maxlength="50"></TEXTAREA></TD>\n</TR>  \n|;
print qq|		<TR>\n<TD>File:</TD> <TD><INPUT type="file" name="File" size="30"></TD>\n</TR>        \n|;
print qq|	</TABLE>       \n|;
print qq|<INPUT type="submit" name="submit" value="Upload Race">  \n|;
print qq|</FORM>   \n|;
print qq|</td> \n|;
}

sub delete_race {
	my ($RaceID) = @_;
	# Need to check to be sure the race is not currently signed up for any not ended games
	$db = &DB_Open($dsn);
	#$sql = qq|SELECT User.User_ID, GameUsers.GameFile, GameUsers.RaceFile FROM User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login WHERE User.User_ID=$id AND GameUsers.RaceFile=\'$RaceFile\';|;
  # modified 190217 to not include finished games
  #$sql = qq|SELECT User.User_ID, GameUsers.GameFile, GameUsers.RaceFile, Games.GameName, Games.GameStatus FROM Games INNER JOIN (User INNER JOIN GameUsers ON User.User_Login = GameUsers.User_Login) ON (User.User_Login = Games.HostName) AND (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((User.User_ID)=$id) AND ((GameUsers.RaceFile)=\'$RaceFile\') AND ((Games.GameStatus)<>9));|;
  $sql = qq|SELECT User.User_ID, GameUsers.GameFile, Races.RaceName, GameUsers.RaceFile, GameUsers.RaceID, Games.GameName, Games.GameStatus FROM (User INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON (User.User_Login = GameUsers.User_Login) AND (User.User_Login = Games.HostName)) INNER JOIN Races ON User.User_Login = Races.User_Login WHERE (((User.User_ID)=$id) AND ((GameUsers.RaceID)=$RaceID) AND ((Games.GameStatus)<>9));|;
	my $counter =0;
  my %GameValues;
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { 
      $counter++; 
      %GameValues = %{$row}; 
#			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
		}
    $sth->finish();
	}
#	if ($counter) {
	if ($GameValues{'RaceID'}) {
		print "<P><font color=red>$GameValues{'RaceName'} ($GameValues{'RaceFile'}) cannot be deleted, as it is currently associated with at least one game:  $GameValues{'GameName'}</font>\n";
	# otherwise delete it
	} else { 
		print "<P>Deleting race ...\n";
		# To make the data clean and safe, pull the data directly from the database first to sanitize the results
		$sql = qq|SELECT * FROM Races WHERE User_Login=\'$userlogin\' AND RaceID = $RaceID|;
		if (my $sth = &DB_Call($db,$sql)) {
      while (my $row = $sth->fetchrow_hashref()) {
         %RaceValues = %{$row}; 
         #				($RaceFiled, $User_Login) = $db->Data('RaceFile', 'User_Login');
			} 
      $sth->finish();
		} else { print qq|<P>RaceID $RaceID not found as $RaceValues{'RaceID'} for User $User_Login\n|; }
		if ($RaceValues{'RaceID'} && $RaceValues{'User_Login'}) {
			#$sql= "DELETE RaceID, User_Login FROM Races WHERE (RaceID=$RaceValues{'RaceID'} AND User_Login=\'$RaceValues{'User_Login'}\');";
			$sql= "DELETE FROM Races WHERE (RaceID=$RaceValues{'RaceID'} AND User_Login=\'$RaceValues{'User_Login'}\');";
			&LogOut(200,"delete_race: $sql",$SQLLog);
			if (my $sth = &DB_Call($db,$sql)) { 
        print qq|<P>Race $RaceValues{'RaceName'} deleted from database.\n|;
        $sth->finish();  
      }
			my $race_file = $Dir_Races . '/' . $RaceValues{'User_File'} . '/' . $RaceValues{'RaceFile'};
			$race_file = &clean($race_file);
			if (-f $race_file) { unlink($race_file); }
      if (-f $race_file) {
        print "Race file $RaceValues{'RaceFile'} failed to delete from file system";
        &LogOut(0,"Race ID: $RaceValues{'RaceID'}, File: $RaceValues{'RaceFile'} failed to file delete for $userlogin",$ErrorLog);
        
      } else {
        print "Race file $RaceValues{'RaceFile'} deleted from file system.";
        &LogOut(100,"Race ID: $RaceValues{'RaceID'}, File $RaceValues{'RaceFile'} deleted from file system for $userlogin",$LogFile);
      }
		}
	}
	&DB_Close($db);
}

sub list_players {
	($sql) = @_;
	$db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {
			($GameFile, $User_ID, $User_Name, $Invite_Status) = ($row->{'GameFile'}, $row->{'User_ID'}, $row->{'User_Name'}, ($row->{'Invite_Status'})); 
			print qq|<a href="$WWW_Scripts/page.pl?lp=$in{'lp'}&cp=show_friend&rp=&User_ID">$User_Name</a><br>\n|;
		}
    $sth->finish();
	} else { &LogOut(10,"ERROR: Finding list_players",$ErrorLog); }
}
          
sub edit_game {
	my ($type) = @_;
	print "<td>";
	$db = &DB_Open($dsn);
	if ($type eq 'edit') {
		$sql = qq|SELECT * FROM Games WHERE GameFile = \'$in{'GameFile'}\' AND HostName = \'$userlogin\';|;
		if (my $sth = &DB_Call($db,$sql)) {
      while (my $row = $sth->fetchrow_hashref()) { %GameValues = %{$row}; }
      $sth->finish();
		}
	}

	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<TABLE><TR>\n|;
	print qq|		<TD>Game Name:</TD>\n|;
  if ($type eq 'create') {
	 print qq|		<TD><INPUT name="GameName" maxlength="30" | . &button_help("GameName") . qq| value="Change me"> </TD><TD>(Mandatory)</TD>\n|;
  } else { print qq|		<TD>$GameValues{'GameName'}</TD><TD></TD>\n|;}
	print qq|	</TR><TR>\n|;
 	if ($type eq 'create') {
 		print qq|		<TD>Game File Name:</TD>\n|;
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
	if ($type eq 'edit') {
  	# Let the user select from those with accounts (should it be only those playing the game?)
  	$sql = "SELECT * FROM User ORDER BY User_Login;";
  	if (my $sth = &DB_Call($db,$sql)) {
      while (my $row = $sth->fetchrow_hashref()) { %HostValues = %{$row}; 
  #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
  			print qq|<OPTION value="$HostValues{'User_Login'}">$HostValues{'User_Login'}</OPTION>\n|;
  		}
      $sth->finish();
 	}
  }
	print qq|</SELECT></td>|;
	&DB_Close($db);

	print qq|</TR><TR>\n|;
	print qq|<TD>Game Description: </TD>\n|;
	print qq|<TD><TEXTAREA name=GameDescrip | . &button_help("GameDescrip") . qq| type=Text value="$GameValues{'GameDescrip'}">$GameValues{'GameDescrip'}</TEXTAREA></TD>\n|;
	print qq|</TR><TR>\n|;
  
  
  # print the player number options when the game isn't started
  if ($GameValues{'GameStatus'} =~ /^[23459]$/ ) { print qq|<input type=hidden name="MaxPlayers" value="$GameValues{'MaxPlayers'}">\n|; 
  } else {
  	print qq|<TD>Max Players: </TD>\n|;
    print qq|<td><SELECT name="MaxPlayers"> | . &button_help("MaxPlayers") . qq|\n|;
   	if ($GameValues{'MaxPlayers'}) { print qq|<OPTION value=$GameValues{'MaxPlayers'} SELECTED>$GameValues{'MaxPlayers'}\n|; }
    else { print qq|<OPTION value=16 SELECTED>16\n|; }
   	foreach (my $i=1; $i <= 16; $i++) { print qq|<OPTION value=$i>$i\n|; }
   	print qq|</SELECT></td></tr><tr>\n|;
    # BUG doesn't display at game gen, and $Gamevalues is null at that point so errors
  }  
  
  # Type of Game options
  print qq|<TD>Type of Game:</TD>\n|;
	print qq|</TR><TR><TD>\n|;
	my ($daily, $hourly, $required, $allin);
	if    ($GameValues{'GameType'} == 1)  { $daily = 1; }
	elsif ( $GameValues{'GameType'} == 2) { $hourly = 1; }
	elsif ( $GameValues{'GameType'} == 3) { $required = 1; }
	elsif ( $GameValues{'GameType'} == 4) { $allin = 1; }
	elsif ($type eq 'create') { $daily = 1; }
  
	# Print out all of the hours of the day
	print qq|<table><tr><td align=left><INPUT name="GameType" type="radio" value=1 onFocus="Help( 'Daily' )" onMouseOver="Help( \'Daily\' )" onMouseOut="Help( \'blank\' )" $Checked[$daily]>Daily</td>\n|;
	print qq|<td><SELECT name=\"DailyTime\">\n|;
	for (my $i=0; $i < 24; $i++) {
		if ($i == $GameValues{'DailyTime'}) { 	print qq|<OPTION value=\"| . $i . qq|\" SELECTED>| . &fixdate($i) .  qq|:00</OPTION>\n|; }
		# default select 9 pm.
		elsif ($type eq 'create' && $i == 21) { print qq|<OPTION value=\"| . $i . qq|\" SELECTED>| . &fixdate($i) .  qq|:00</OPTION>\n|; }
		else { print qq|<OPTION value=\"| . $i . qq|\">| . &fixdate($i) .  qq|:00</OPTION>\n|; }
	}
  my $dt = DateTime->now(time_zone => 'America/New_York');
  $timezone_abbreviation = $dt->strftime('%Z');
  print qq|</SELECT> $timezone_abbreviation</td></tr>|;

	# print all the hourly options 
	print qq|<tr><td align=left><INPUT name="GameType" type="radio" value=2 | . &button_help("Hourly") . qq| $Checked[$hourly]>Hourly</td>\n|;
	print qq|<td><SELECT name="HourlyTime">\n|;
  my $key_minutes;
	foreach my $key (@HourlyTime) { 
  	if ($key == $GameValues{'HourlyTime'} && $key < 1 ) { 
      $key_minutes = int(($key * 60) +.5);
      print qq|<OPTION value=$key SELECTED>$key_minutes minutes\n|; 
    } elsif ($key == $GameValues{'HourlyTime'} && $key >= 1 ) { print qq|<OPTION value=$key SELECTED>$key hours\n|; 
  	} elsif ($type eq 'create' && $key == 48) { print qq|<OPTION value=$key SELECTED>$key hours\n|; 
  	} else { 
      # Display minutes or hours as appropriate
      if ($key >= 1) {
        print qq|<OPTION value=$key>$key hours\n|;
      } elsif ($key < 1) {
        $key_minutes = int(($key * 60) +.5);
        print qq|<OPTION value=$key>$key_minutes minutes\n|;
      }
    }
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
		print qq|<INPUT type="checkbox" name="$WeekDays[$i]" value="$pos" | . &button_help("DayFreq") . qq| $Checked[$pos]>$WeekDays[$i] |;
	}
	print qq|</TD>\n|;
	print qq|</TR></TABLE>\n|;
  
	# Select the hours on which a turn should generate
	if ($type eq 'create') { $GameValues{'HourFreq'} = $default_hourly;}
	if ($GameValues{'GameType'} == 2 || $type eq 'create') {
		print qq|<b><U>Hours Turns should Generate (ignored for daily games)</U></b><BR>\n|;
		print "<table><tr>\n";
		for (my $i = 0; $i <=23; $i++) {
			my $name = 'hour' . $i;
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
	print qq|<INPUT type="checkbox" name="GameDelay" | . &button_help("GameDelay") . qq| $Checked[$GameValues{'GameDelay'}]>Players can Delay turn\n|;
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
	# Default to Host can restore games from backup
	unless ($GameValues{'GameRestore'}) { if ($type eq 'create') { $GameValues{'GameRestore'} = 1; }}
	print qq|<TD><INPUT type="checkbox" name="GameRestore" | . &button_help("GameRestore") . qq| $Checked[$GameValues{'GameRestore'}]>Host can Restore Turns from Backup </TD>\n|;
	print qq|</TR><TR>\n|;
	# Default to Anonymous Players
	unless ($GameValues{'AnonPlayer'}) { if ($type eq 'create') { $GameValues{'AnonPlayer'} = 1; }}
	print qq|<TD><INPUT type="checkbox" name="AnonPlayer" | . &button_help("AnonPlayer") . qq| $Checked[$GameValues{'AnonPlayer'}]>Anonymous Players</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="GamePause" | . &button_help("GamePause") . qq| $Checked[$GameValues{'GamePause'}]>Players can always Pause</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="ObserveHoliday" | . &button_help("ObserveHoliday") . qq| $Checked[$GameValues{'ObserveHoliday'}]>Observe Holidays</TD>\n|;
	print qq|</TR><TR>\n|;
	print qq|<TD><INPUT type="checkbox" name="Newspaper" | . &button_help("NewsPaper") . qq| $Checked[$GameValues{'NewsPaper'}]>Galactic News	</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="SharedM" | . &button_help("SharedM") . qq| $Checked[$GameValues{'SharedM'}]>Shared M Files	</TD>\n|;
	print qq|<TD><INPUT type="checkbox" name="HostAccess" | . &button_help("HostAccess") . qq| $Checked[$GameValues{'HostAccess'}]>Host Access    </TD>\n|;
	print qq|</TR><TR>\n|;
  if (-f "$Dir_Games/$GameValues{'GameFile'}/fix")   { $GameValues{'Exploit'} = 1; }
  if (-f "$Dir_Games/$GameValues{'GameFile'}/clean") { $GameValues{'Sanitize'} = 1; }
  print qq|<TD><INPUT type="checkbox" name="Exploit" | . &button_help("Exploit") . qq| $Checked[$GameValues{'Exploit'}]>Exploit Detection</TD>\n|;
  print qq|<TD><INPUT type="checkbox" name="Sanitize" | . &button_help("Sanitize") . qq| $Checked[$GameValues{'Sanitize'}]>Sanitize Player Files</TD>\n|;
  print qq|<TD><INPUT type="checkbox" name="PublicMessages" | . &button_help("PublicMessages") . qq| $Checked[$GameValues{'PublicMessages'}]>Public Messages</TD>\n|;
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
	my %GameValues;
	print '<td>';
	$db = &DB_Open($dsn);
	$sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\' AND HostName = \'$userlogin\';|;
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) {  %GameValues = %{$row};  
    $sth->finish();
    }
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
	}
	&DB_Close($db);

  print qq|<H1>Delete Game: $GameValues{'GameName'}</H1>|;
	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|Confirm you want to delete \"$GameValues{'GameName'}\", Game ID: $GameFile\n|;
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
	if (my $sth = &DB_Call($db,$sql)) {
    while (my $row = $sth->fetchrow_hashref()) { %GameValues = %{$row};  
		#while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
    $sth->finish();
		}
	}
  # Confirm that the user logged in is the host, and that the game returns from the sql query 
  # matches the request
  if ($userlogin eq ($GameValues{'HostName'}) && ($GameValues{'GameFile'} eq $GameFile) && $GameFile) {
    # Delete the entries from the Games database
    #$sql = qq|DELETE Games.GameFile, Games.HostName FROM Games WHERE Games.GameFile=\'$GameValues{'GameFile'}\' AND Games.HostName=\'$userlogin\';|;
    $sql = qq|DELETE FROM Games WHERE Games.GameFile=\'$GameValues{'GameFile'}\' AND Games.HostName=\'$userlogin\';|;
  	my $sth = &DB_Call($db,$sql);
    $sth->finish(); 
    print qq|<P>Game database entries deleted for: $GameValues{'GameName'}.\n|;
    # Delete the entries from the GameUser database
    # (Shoulnd't be necessary, as the relationship should take them out
    #$sql = qq|DELETE GameUsers.GameFile, Games.HostName FROM GameUsers WHERE GameUsers.GameFile=\'$GameValues{'GameFile'}\';|;
    $sql = qq|DELETE FROM GameUsers WHERE GameUsers.GameFile=\'$GameValues{'GameFile'}\';|;
   	my $sth = &DB_Call($db,$sql);
    $sth->finish(); 

    print qq|<P>Game user database entries deleted for: $GameValues{'GameName'}.\n|;
  	my $sth = &DB_Close($db);
    # Delete the files, carefully using the database values, not the user input.
    $dir = $Dir_Games . '/' . $GameValues{'GameFile'};
    # Get the functions to remove a directory
    use File::Path 'rmtree';
    if(-d $dir && $GameValues{'GameFile'} && (length($GameValues{'GameFile'}) > 0)) { 
      rmtree(&clean($dir));
      print "<P>Game files deleted for: $GameValues{'GameName'}.";
    } else { 
      print "<P>Game Directory $GameValues{'GameFile'} does not exist."; 
      &LogOut(0,"Delete of Game Directory $GameValues{'GameFile'} by $userlogin failed as it does not exist.",$ErrorLog);
    }

    print qq|<P>Game \"$GameValues{'GameName'}\" Deleted!</H1>|;
    &LogOut(0,"$GameValues{'GameName'}, $GameValues{'GameFile'} Deleted by $userlogin",$LogFile);
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
  my $GameFile =  &clean($in{'GameFile'});
  # set boundaries on MaxPlayers
  if ($in{'MaxPlayers'} < 1 | $in{'MaxPlayers'} > 16) { $in{'MaxPlayers'} = 16;}
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
  my $AutoInactive = &clean($in{'AutoInactive'});   
  if ($AutoInactive =~ /^\d+\z/) {} else { $AutoInactive = 0; }; # Validate AutoInactive
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
  my $newsfile = "$Dir_Games/$in{'GameFile'}/$in{'GameFile'}.news";
  if ($NewsPaper) { # If there's no news file, create one. 
    if (!(-f $newsfile)) { &create_news($newsfile); }  # Create news file
  } else { if (-f $newsfile) { unlink ($newsfile); } # remove news file
  }
  
	my $SharedM = &checkboxnull($in{'SharedM'});
	my $HostAccess = &checkboxnull($in{'HostAccess'});
	$in{'Notes'} = &clean($in{'Notes'});
  # Enable/disable List functionality for Fix
 	my $Exploit = &checkboxnull($in{'Exploit'}); # Not a DB entry
  if (!($Exploit)) { 
    &updateList($in{'GameFile'}, 0); 
  } else {
    open (EXPLOIT, ">$Dir_Games/$in{'GameFile'}/fix") || &LogOut(0,"update_game: cannot open EXPLOIT $Dir_Games/$in{'GameFile'}/fix", $ErrorLog);
    print EXPLOIT time() . ": $in{'GameFile'}"; 
    close EXPLOIT; 
    umask 0002; 
    chmod 0660, "$Dir_Games/$in{'GameFile'}/fix";
    &updateList($in{'GameFile'}, 1);
  } 
  # Update the clean file for whether enabled or disabled
	my $Sanitize = &checkboxnull($in{'Sanitize'}); # Not a DB entry
  if (!($Sanitize)) { 
    my $clean = "$Dir_Games/$in{'GameFile'}/clean";
    if (-f $clean) { unlink $clean; } 
  } else {
    open (SANITIZE, ">$Dir_Games/$in{'GameFile'}/clean") || &LogOut(0,"update_game: cannot open SANITIZE $Dir_Games/$in{'GameFile'}/clean", $ErrorLog); 
    print SANITIZE time(). ": $in{'GameFile'}"; 
    close SANITIZE; 
    umask 0002; 
    chmod 0660, "$Dir_Games/$in{'GameFile'}/clean";

  }
  # If messages have been disabled, delete the .messages file
	my $PublicMessages = &checkboxnull($in{'PublicMessages'}); 
  if (!($PublicMessages)) { 
    my $messages = "$Dir_Games/$in{'GameFile'}/$in{'GameFile'}" . "/.messages";
    if (-f $messages) { unlink $messages; } 
  }

 	my $db = &DB_Open($dsn);
	if ($in{'type'} eq 'edit') {
    # in order to avoid a DB update
    my @Values;
   	my $sql = qq|UPDATE Games  SET 
								GameDescrip = '$in{'GameDescrip'}',
                HostName = '$in{'HostName'}',
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
								HostAccess = '$HostAccess',
								PublicMessages = '$PublicMessages',
								Notes = '$in{'Notes'}', 
								MaxPlayers = $MaxPlayers, 
								AutoInactive = $AutoInactive 
								WHERE GameFile = '$in{'GameFile'}' AND HostName = '$userlogin';|;
                
    # Store new game conditions
    if ($AsAvailable) { push @Values, "Generate if All Turns are In"};  
		if ($OnlyIfAvailable) { push @Values, "Only Generate if All Turns are In"};
    if ($HostMod) { push @Values, "Host can Modify Game"; }
    if ($HostForce) { push @Values, "Host can Force Generate"; }
    if ($NoDuplicates) { push @Values, "No Duplicate Players"; }
    if ($GameRestore) { push @Values, "Host can Restore from Backup"; }
    if ($AnonPlayer) { push @Values, "Anonymous Players"; }
    if ($GamePause) { push @Values, "Players can Pause"; }
    if ($GameDelay) { push @Values, "Players can Delay $NumDelay times (min $MinDelay)";  }
    if ($NewsPaper) { push @Values, "Galactic News"; }
    if ($SharedM) { push @Values, "Shared M Files"; }
    if ($HostAccess) { push @Values, "Host Access"; }
    if ($PublicMessages) { push @Values, "Public Messages"; }
    if ($Sanitize) { push @Values, "File Sanitize"; }
    if ($Exploit) { push @Values, "Exploit Detection"; }   
    
    if (my $sth = &DB_Call($db,$sql)) { 
      print "<P>Game Updated!\n"; 
		  &LogOut(50,"Game updated for $sql",$LogFile);
      #Get the game values for emailing edit information.
      # And email all the players that the game has changed.
      $sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\';|;
      if (my $sth = &DB_Call($db,$sql)) { 
        my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};
        $sth->finish();
      }
     	# Notify all players who want to be notified that the game status has changed. 
    	$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Game Parameters Edited|;
     	$GameValues{'Message'} = "Game Parameters have been edited for $GameValues{'GameName'} ($GameFile). Please review Game page for any changes.\n";
      # Append the current state
      $GameValues{'Message'} .= "\nCurrent Settings: \n";
      foreach my $setting (@Values) { $GameValues{'Message'} .= "$setting" . ',';  }
      chop $GameValues{'Message'}; # Get rid of the trailing comma
      
     	&Email_Turns($GameFile, \%GameValues, 0); # calls Read_CHK
      $sth->finish(); 
    } else { 
       print "Game Update failed\n"; 
       &LogOut(0,"$in{'GameName'} update $sql failed for $userlogin", $ErrorLog); 
    }
	} elsif ($in{'type'} eq 'create') {
		# Need to create a random gamefile name
		use Digest::SHA1  qw(sha1_hex);
		$CleanGameFile = substr(sha1_hex(time()), 5, 8); # Should be random enough
		&LogOut(50,"Creating random GameFile $CleanGameFile for $in{'GameName'}",$LogFile);
		my $sql = qq|INSERT INTO Games (GameFile,HostName,GameName,GameDescrip,DailyTime,HourlyTime,GameType,GameStatus,AsAvailable,OnlyIfAvailable,DayFreq,HourFreq,ForceGen,ForceGenTurns,ForceGenTimes,HostMod,HostForce,NoDuplicates,GameRestore,AnonPlayer,GamePause,GameDelay,NumDelay,MinDelay,ObserveHoliday,NewsPaper,SharedM,HostAccess,PublicMessages,Notes,MaxPlayers) VALUES ('$CleanGameFile','$userlogin','$in{'GameName'}','$in{'GameDescrip'}',$in{'DailyTime'},'$in{'HourlyTime'}',$in{'GameType'},6,'$AsAvailable','$OnlyIfAvailable','$DayFreq','$HourFreq','$ForceGen',$ForceGenTurns,$ForceGenTimes,'$HostMod','$HostForceGen','$NoDuplicates','$GameRestore','$AnonPlayer','$GamePause','$GameDelay',$NumDelay, $MinDelay,'$ObserveHoliday','$NewsPaper','$SharedM','$HostAccess','$PublicMessages','$in{'Notes'}',$MaxPlayers);|;
		if (my $sth = &DB_Call($db,$sql)) {
      $sth->finish(); 
    } 
		else { 
      print "Create failed. Did you forget to provide a Game Name?\n"; 
      &LogOut(0,"$in{'GameFile'} create failed with $sql for $userlogin", $ErrorLog);
      $CleanGameFile = 'CREATE FAILED';
    }
  }
  &DB_Close($db);
	return $CleanGameFile; 
}

sub create_game_size {
	my ($GameFile, $GameName) = @_;
	print <<eof;
<H2>Game Parameters For $GameName</H2>
<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>
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
	&optionloop(30,500,10,200);
	print qq|</SELECT>years must pass before a winner is declared.<BR>\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
#	print qq|<input type=hidden name="rp" value="my_games">\n|;
	print qq|<input type=hidden name="GameFile" value="$GameFile">\n|; 
  #Notify Email List
	print qq|<P><INPUT type="Checkbox" name="NotifyList" | . &button_help("NotifyList") . qq|>Notify Email List for New Game Notification\n|;
  #
	print qq|<P><BUTTON $host_style type="submit" name="cp" value="Create DEF File">Create DEF File</BUTTON>\n|; 
	print qq|</FORM>\n|;
}

sub create_game_def {
	my ($GameFile) = @_;
	my $GameDEF = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.def';
	my $GameXY = $Dir_WINE . "$WINE_Games\\$GameFile\\$GameFile.xy";
	my $GameDEFCreate = ">" . $GameDEF;

	# Write To file
	if (-f $GameDEF) { #if there is already a .def file error out
		&LogOut(0, "Failed to write $GameDEF for $userlogin",$ErrorLog); 
#		die ('There is already a $GameDEF file.'); 
	}
	else { #if not, make one
		# Create the directory
		my $HST_Location = $Dir_Games . '/' . $GameFile;
    my $call = "mkdir $HST_Location";
    my $exit_code = system($call);  # Where 0 is success
    if ($exit_code) { &LogOut(0, "Cannot create $HST_Location, $userlogin", $ErrorLog); }
		#mkdir $HST_Location || &LogOut(0, "Cannot create $HST_Location, $userlogin", $ErrorLog); 
	
		# Create the def file
		open (DEFOUT, $GameDEFCreate) || &LogOut(0, "create_game_def: Cannot create $GameDEF file $GameDEFCreate, $userlogin", $ErrorLog);
    $db = &DB_Open($dsn);
    # Get the name of the game
		$sql = qq|SELECT * FROM Games WHERE GameFile = \'$GameFile\' AND HostName ='$userlogin';|;
		if (my $sth = &DB_Call($db,$sql)) { 
      while (my $row = $sth->fetchrow_hashref()) { %GameValues = %{$row};  } 
      $sth->finish();
    }
 
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
    umask 0002; 
    chmod 0664, $GameDEF;

		# update the database to reflect that the def file is created for this game
		my $sql = qq|UPDATE Games SET GameStatus = 7 WHERE GameFile = \'$GameFile\' AND HostName ='$userlogin';|;
		my $sth = &DB_Call($db,$sql);
    $sth->finish(); 
    
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
      if (my $sth = &DB_Call($db,$sql)) {
        while (my $row = $sth->fetchrow_hashref()) { 
          %UserValues = %{$row};  
      #			while ( my ($key, $value) = each(%GameValues) ) { print "$key => $value\n"; }
          # Email all the players
          &LogOut(200,"Emailing player about new game $GameValues{'GameName'} $GameValues{'GameFile'}: $UserValues{'User_Login'}, $mail_from, $Subject, $Message",$LogFile);
          $smtp = &Mail_Open;
          &Mail_Send($smtp, $UserValues{'User_Email'}, $mail_from, $Subject, $Message);
          &Mail_Close($smtp);
        }
        $sth->finish();
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
  if ($DayFreq  == 0 ) { $DayFreq = '1000000'; } #default to Sunday if nothing is selected
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
	if ($HourFreq == 0 ) { $HourFreq = '000000001111111111111100'; } #default to not after 10
	return($HourFreq);
}

sub read_def {
	my ($GameFile) = @_;
	my @Universe;
  my @Victory;
	my @Universe_Size = qw(Tiny Small Medium Large Huge);
	my @Density = qw(Sparse Normal Dense Packed);
	my @Positions = qw(Close Moderate Farther Distant);
	my $def_file = "$Dir_Games/$GameFile/$GameFile.def"; 
	my @def_data = ();
	if (-f $def_file) { #Check to see if file is there.
		open (IN_FILE,$def_file) || &LogOut(0, "read_def: Cannot create $GameFile Def: $def_file, $userlogin", $ErrorLog);
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
	 	if ($univ_mins) { push (@Vals, 'Max Mins'); }
	 	if ($univ_slowtech) { push (@Vals, 'Slow Tech'); }
	 	if ($univ_bbs) { push (@Vals, 'Accel. BBS'); }
	 	if ($univ_norandom) { push (@Vals, 'No Random'); }
		if ($univ_alliance) { push (@Vals, 'AIs Ally'); }
		if ($univ_public) { push (@Vals, 'Public Scores'); }
		if ($univ_clumping) { push (@Vals, 'Galaxy Clump'); }

		if ($vc_planets) { push (@Vals, "Owns $vc_percent% of all planets"); }
		if ($vc_tech) { push (@Vals, "Attains Tech $vc_techlevel in $vc_techfields fields"); }
		if ($vc_score) { push (@Vals, "Exceeds a score of $vc_scoreamt"); }
		if ($vc_exceed) { push (@Vals, "Exceeds 2nd place score by $vc_exceed_percent%"); }
	 	if ($vc_prod) { push (@Vals, "Production capacity of $vc_prod,000"); }
		if ($vc_capital) { push (@Vals, "Owns $vc_capitalnum capital ships"); }
		if ($vc_turns) { push (@Vals, "Highest score after $vc_years years"); }
		push (@Vals, "Meet $vc_meet victory criteria after $vc_minyears years");
		my $c = 0;
		my $col=4;
		print "\n<P><B>Stars! Settings:</B>\n";
		print qq|<table border=1 width=100% style="font-size:0.8em;">|;
		print qq|<tr>|;
		foreach my $key (@Vals) {
			print "<td>$key</td>";$c++;
			if ($c/$col == int($c/$col)) { print qq|</tr><tr>|; }
		}	
		print qq|</tr></table>\n|;
	} else { 
		print "<P>Game Definition File $def_file not found!\n"; 
		&LogOut(0,"read_def: Game Definition File $def_file not found for $userlogin",$ErrorLog);
	}
  return ''; # Return blank to avoid getting values
}

sub read_game {
	# Read in the game paramenters and create a table
	my ($file_prefix) = @_;
	my $sql = qq|SELECT * FROM Games WHERE GameFile = \'$file_prefix\';|;
	my %GameValues;
	$db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref();  %GameValues = %{$row};  
    $sth->finish();
  }
	&DB_Close($db);
	my @Values = ();
	if     ($GameValues{'GameType'} == 1) { push(@Values, "Daily Turn Gen, $GameValues{'DailyTime'}:00"); }
	elsif ( $GameValues{'GameType'} == 2) { 
    # need to handle for the minutes interval
    my $hourly_result;
     if ($GameValues{'HourlyTime'} < 1) { $hourly_result =  int(($GameValues{'HourlyTime'} * 60)) . " minutes"; } # int for 10 minute 1.67
     else { $hourly_result =  $GameValues{'HourlyTime'} . " hours"; }
    push(@Values, "Hourly Turn Gen, $hourly_result");
  }
	elsif ( $GameValues{'GameType'} == 3) { push(@Values, "Turns Gen Only when All Turns are In"); }
	elsif ( $GameValues{'GameType'} == 4) { push(@Values, "Turns as Required"); }
	else { push(@Values, "Unknown Turn Gen"); }	
	if (&checkbox($GameValues{'ForceGen'})) { 
		my $str = "ForceGen $GameValues{'ForceGenTurns'} Turns at a Time $GameValues{'ForceGenTimes'} Time(s)";
		push (@Values, "$str");
	}
	if ($GameValues{'HostMod'}) { push (@Values, "Host can Modify Game Settings"); }
	if ($GameValues{'AsAvailable'}) { push (@Values, "Generate if All Turns are In"); }
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
	if ($GameValues{'HostAccess'}) { push (@Values, "Host Access"); }
	if ($GameValues{'PublicMessages'}) { push (@Values, "Public Messages"); }
	if ($GameValues{'AutoInactive'}) { push (@Values, "AutoInactive after $GameValues{'AutoInactive'} turns missed"); }
	if ($GameValues{'MaxPlayers'}) { push (@Values, "Max $GameValues{'MaxPlayers'} players allowed to join"); }
  if (-f "$Dir_Games/$GameValues{'GameFile'}/fix" ) {
    if ($fixFiles < 2) { push (@Values, "Exploit Detection configured"); }
    elsif ($fixFiles == 2) { push (@Values, "Exploit Detection enabled"); }
  }
  if (-f "$Dir_Games/$GameValues{'GameFile'}/clean") {
    if ($cleanFiles < 2) { push (@Values, "File Sanitization configured"); }
    elsif ($cleanFiles == 2) { push (@Values, "File Sanitization enabled"); }
  }  
	my $c = 0;
	my $col=4;
	print "<P><B>TotalHost Settings:</B>\n";
	print qq|<table border=1 width=100% style="font-size:0.8em;">|;
	print qq|<tr>|;
	foreach my $key (@Values) { 
		print "<td>$key</td>"; $c++;
		if ($c/$col == int($c/$col)) { print qq|</tr><tr>|; }
	}
	print qq|</tr></table>\n|;
  
# 	211028 return @Values;
  return ''; # Return blank to avoid getting values
}

sub show_restore {
	# Build the page for restoring a game
	my ($GameFile) = @_;
  my %GameValues;
	my $BackupDir = $Dir_Games . '/' . $GameFile;
	# Read in all the directories to build the options
	opendir(DIRS, $BackupDir) || die("Cannot open $BackupDir\n"); 
	@AllDirs = sort readdir(DIRS);
	closedir(DIRS);
	$db = &DB_Open($dsn);
  $sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};  
    $sth->finish();
  }
	&DB_Close($db);
  print qq|<h2>Restore Game for: $GameValues{'GameName'}</h2>\n|;
 	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
	print qq|<input type=hidden name="lp" value="profile_game">\n|;
	print qq|<table><tr>\n|;
	print qq|<td>Restore to Game Year</td>\n|;
 	print qq|<td><SELECT name="restore_year">\n|;
 	foreach $name (@AllDirs) {
 		if ($name =~ /\./) {  next; } # No need to display the .
 		if ($name =~ /^BACKUP.*/) {  next; }   # No need to display the singular Backup folder
 		if ($name =~ /^backup.*/) {  next; }   # No need to display the singular Backup folder
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
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};  
    $sth->finish();
  }
	&DB_Close($db);
  
	print "<br>Restoring Game Year $restore_year for: $GameValues{'GameName'}....\n";
	&LogOut(49, "Restoring Game Year $restore_year for $GameFile",$LogFile);
	my $Backup_Source        = $Dir_Games . '/' . $GameFile . '/' . $restore_year;
	my $Backup_Destination   = $Dir_Games . '/' . $GameFile;

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
		if ($file =~ /\.xy/) { next; } # Skip the things I don't want to process or the .x regex will remove it
		unless (-d "$Backup_Destination_File") {
			# It would be nice to narrow this down to only the range of .x files from 1-16
			# but my skills at regexp escape me
			if ($file =~ /^.*\.x.*/) {
				&LogOut(100,"Deleting File: $file: $Backup_Destination_File",$LogFile);
				if (-f $Backup_Destination_File) { unlink($Backup_Destination_File); }
			}
      # remove List files, as they might not exist on the old turn
      if ($file =~ /^.*\.hst\..*/) {
				&LogOut(100,"Deleting File: $file: $Backup_Destination_File",$LogFile);
			  if (-f $Backup_Destination_File) { unlink($Backup_Destination_File); }
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
  
  # Pause the restored game
  &process_game_status($in{'GameFile'}, 'Pause', $userlogin); 
  
	print "<P>Game restored!\n";
	# Notify all players who want to be notified that the game status has changed. 
	$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Restored from Backup|;
	$GameValues{'Message'} = "Game: $GameValues{'GameName'} restored to year $restore_year.\n";
	&Email_Turns($GameFile, \%GameValues, 0);
}

sub process_join_game {
	my ($GameFile, $RaceID) = @_;
	my %GameValues;
	my $countdupes = 0;
  my $playercount = 1; # used to determine MaxPlayers; first row is 0
	$db = &DB_Open($dsn);
	# Get the necessary game data to add the user
	$sql = qq|SELECT * FROM Games WHERE GameFile = '$GameFile';|;
	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row};  
    $sth->finish();
  }
	#	while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }

  #Count number of players signed up
	$sql = qq|SELECT  * FROM GameUsers WHERE GameFile = '$GameFile';|;
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my @row = $sth->fetchrow_array()) { $playercount++; }  
    $sth->finish();
  }
  # If the number of players is greater than permitted, don't allow it
  if ($playercount > $GameValues{'MaxPlayers'}) { 
    print "<P><font color=red>This game already has the Max Players signed up!</font>"; 
    &LogOut(0, "$userlogin Failed to join game $GameFile because the game was at MaxPlayers $GameValues{'MaxPlayers'}", $LogFile);
  } else {
  	# If the game only permits the user to be in the game once, check to be sure the
  	# user is only in the game once. 
  	if (&checkbox($GameValues{'NoDuplicates'})) {
  		$sql = qq|SELECT  * FROM GameUsers WHERE User_Login = '$userlogin' AND GameFile = '$GameFile';|;
  		if (my $sth = &DB_Call($db,$sql)) { 
        while (my @row = $sth->fetchrow_array()) { $countdupes++; } 
        $sth->finish();
      }
  	}
  	if ($countdupes) {
  		print "<P><font color=red>This game does not permit you to join more than once.</font>\n"; 
  		&LogOut(50,"$userlogin attempted to join $GameFile more than once", $ErrorLog);
  	} else {
  		# the player IDs must be unique. This number will be temporarily used to determine player order in
  		# the game when it's created, and will be reset to 1-16 then
  		my $random_number = rand(); $random_number = int($random_number*100000);
  		# Insert the user into the game 
      # Get race attributes
      $sql = qq|SELECT * from Races WHERE RaceID=$RaceID|;
      my %RaceValues;
      if (my $sth = &DB_Call($db,$sql)) { 
        my $row = $sth->fetchrow_hashref(); %RaceValues = %{$row}; 
        $sth->finish();
      }
  		my $now = time();
  		$sql = qq|INSERT INTO GameUsers (GameName, GameFile, RaceFile, RaceID, User_Login, DelaysLeft, PlayerID, PlayerStatus, JoinDate) VALUES ('$GameValues{'GameName'}','$GameFile','$RaceValues{'RaceFile'}',$RaceID,'$userlogin',$GameValues{'NumDelay'},$random_number,1, $now);|;
  		if (my $sth = &DB_Call($db,$sql)) { 
  			&LogOut(100,"$userlogin Joined Game $GameFile", $LogFile);
        # need to email the host that someone has joined. 
        # Get the host's email information
        my $sql = qq|SELECT * FROM User WHERE User_Login = '$GameValues{'HostName'}';|;
        if (my $sth = &DB_Call($db,$sql)) { 
          my $row = $sth->fetchrow_hashref(); %HostValues = %{$row}; 
          # Now email host to let them know
          $MailTo = $HostValues{'User_Email'};
          $MailFrom = $mail_from;
          $Subject = "$mail_prefix $GameValues{'GameName'} : User $userlogin Joined";
          $Message = "User $userlogin Joined your new game $GameValues{'GameName'} ($GameValues{'GameName'}).";
          $smtp = &Mail_Open;
          &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
  	      &Mail_Close($smtp);
          $sth->finish();
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
  my $unique_player_ids; # For storing if the smae player is in the game more than once. 
	my $pass = 0;
  
	# make sure the user actually has a delay available
	# probably need to know type of game? 
	$sql = qq|SELECT Games.GameName, Games.GameFile, Games.GameType, Games.LastTurn, Games.NextTurn, Games.DayFreq, Games.HourFreq, Games.HourlyTime, Games.DailyTime, Games.NumDelay, Games.AsAvailable, Games.MinDelay, Games.NewsPaper, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.DelaysLeft FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((Games.GameFile)='$GameFile') AND ((GameUsers.User_Login)='$userlogin') AND ((GameUsers.PlayerID) Is Not Null));|;
	# Provide an interface for the user to select their delay
	print "<td>";
	$db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) {
		while (my $row = $sth->fetchrow_hashref()) { 
      %GameValues = %{$row};
      # So we can track if there's more than one player ID.
      $unique_player_ids{$GameValues{'PlayerID'}} = 1;  # The value here is irrelevant, we just care about the key
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
      # We need to print a bunch of this only once if the same player is in the same game more than once
    	unless ($pass) { # Print this only once, even of the player is in the game more than once. 
        print "<H2>Submit a delay for: $GameValues{'GameName'}</H2>\n";
      	if ($GameValues{'GameType'} == 3) { print "Turns generated only when all turns are in.\n"; } 
        	elsif ($GameValues{'GameType'} == 4) { print " Turns generated manually.\n"; }
        	elsif ($GameValues{'GameType'} == 2) { 
            if ($GameValues{'HourlyTime'} >=1) {
        		  print " Turns generated every $GameValues{'HourlyTime'} hours"; 
            } elsif ($HourlyTime < 1) {
              my $minutes = int(($GameValues{'HourlyTime'} * 60) + .5);
              print " Turns generated every $minutes minutes";
            }
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
      		print "Hours Turns can Generate:\n";
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
        $pass++;
      }
      # Repeat this section for each player ID
      print "<hr>\n";
    	if ($GameValues{'DelaysLeft'} > 1 ) {print qq|<P>You have $GameValues{'DelaysLeft'} delays left for this game as Player $GameValues{'PlayerID'}. Your available delays will restore to $GameValues{'NumDelay'} if the sum across all players drops below $GameValues{'MinDelay'}.\n|; }
    	elsif ($GameValues{'DelaysLeft'} == 1 ) { print qq|<P>You have $GameValues{'DelaysLeft'} delay left in this game as Player $GameValues{'PlayerID'}. Use wisely!\n|; }
    	else { print qq|<P>You have no delays left in this game as Player $GameValues{'PlayerID'}. Hope that they reset soon!\n|; }
      # If the player has delays left, display the option to select them
      if ($GameValues{'DelaysLeft'} > 0) {
       	print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
      	print qq|<input type=hidden name="lp" value="profile_game">\n|;
      	if (&checkbox($GameValues{'NewsPaper'})) { print qq|<input type=hidden name="rp" value="show_news">\n|; }
       	print qq|<INPUT type=\"hidden\" name=\"GameFile\" value =\"$GameFile\">\n|;
       	print qq|<INPUT type=\"hidden\" name=\"PlayerID\" value =\"$GameValues{'PlayerID'}\">\n|;
      	print qq|<table><tr>\n|;
      	print qq|<td>Delay Turn</td>\n|;
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
    $sth->finish();
	}
	&DB_Close($db);
}

sub process_delay {
	# Edit the game turn and add a delay
	my ($GameFile, $delay_turns, $PlayerID) = @_;
	my ($sql, $NextTurn, $CurrentDateSecs, $SecOfDay);
	my ($FirstDayToAdd, $SecondDayToAdd, $NextDayOfWeek);
	my $ToDelay = 0;
	my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST);
	my %GameValues;
	my $db = &DB_Open($dsn);
	$sql = qq|SELECT Games.GameName, Games.GameFile, Games.DailyTime, Games.NextTurn, Games.LastTurn, Games.GameType, Games.NumDelay, Games.MinDelay, Games.DayFreq, Games.HourFreq, Games.HourlyTime, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.DelaysLeft FROM Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) WHERE (((Games.GameFile)='$GameFile') AND ((GameUsers.User_Login)='$userlogin') AND ((GameUsers.PlayerID)=$PlayerID));|;
	# make sure the user actually has a delay available, and get other game-related values
  if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); %GameValues = %{$row}; 	
    $sth->finish();
  }

  &LogOut(200, "process_delay: $GameFile, $delay_turns, $PlayerID DELAYSLEFT: $GameValues{'DelaysLeft'}",$LogFile);
	if ($GameValues{'DelaysLeft'} >= $delay_turns) {
		#decrement the user's number of delays
		if ( $delay_turns == 0) { $delay = 1; } else { $delay = $delay_turns; }
    # Note if all the same player, the delays will get reset, drop below the limit
    # and then get restored to full. 
	  #$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.DelaysLeft = [GameUsers.DelaysLeft]-$delay WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.User_Login)=\'$userlogin\') AND ((GameUsers.PlayerID)=$PlayerID));|;
    $sql = qq|UPDATE Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile SET GameUsers.DelaysLeft = GameUsers.DelaysLeft - $delay WHERE Games.GameFile = \'$GameFile\' AND GameUsers.User_Login = \'$userlogin\' AND GameUsers.PlayerID = $PlayerID;|;
		if (my $sth = &DB_Call($db,$sql)) { 
			&LogOut(100, "process_delay: $userlogin delays decreased by $delay for $GameValues{'GameFile'}.",$LogFile); 
      $sth->finish(); 
			#	Set Game Status to Player Delay [3] / Flag game as player timeout/delayed (so we can display it). 
			$sql = qq|UPDATE Games SET GameStatus = 3 WHERE GameFile = \'$GameFile\'|;
			if (my $sth = &DB_Call($db,$sql)) { 
        $sth->finish(); 
				&LogOut(200, "process_delay: Game Status set to Delayed for $GameFile by $userlogin.",$LogFile); 
				# Increment the number of delays for the game
				$sql = qq|UPDATE Games SET DelayCount = DelayCount + $delay WHERE GameFile = \'$GameFile\'|;
				if (my $sth = &DB_Call($db,$sql)) { 
          $ToDelay = 1; 
          &LogOut(200, "process_delay: Increase DelayCount + $delay for $GameFile by $userlogin.",$LogFile);
          $sth->finish(); 
        } else { &LogOut(200, "process_delay: Increase DelayCount failed for $GameFile by $userlogin.",$LogFile);}
			} else { &LogOut(0,"process_delay: Game Status failed to Delay for $delay_turns turns for $GameFile by $userLogin",$ErrorLog); }
		} else { &LogOut(0,"$userlogin delays failed to decrease for process_delays = $delay_turns  $delay for $GameFile by $userLogin", $ErrorLog); }
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

				# Check valid Turn Time here (holidays, etc)
				# Advance to the next valid day if $NewTurn isn't on a valid day
				while (&ValidTurnTime($NextTurn,'Day',$GameValues{'DayFreq'}, $GameValues{'HourFreq'}) ne 'True') { 
					($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = &CheckTime($NextTurn);
					($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameValues{'DayFreq'},$CWeekDay); 
					$NextTurn = $NextTurn + ($DaysToAdd * 86400); 
				}
			} elsif ( $GameValues{'GameType'} == 2) {
				my ($Second, $Minute, $Hour, $DayofMonth, $WrongMonth, $WrongYear, $WeekDay, $DayofYear, $IsDST) = localtime($NextTurn); 
				$NextTurn = $NextTurn + (($GameValues{'HourlyTime'} * 60 * 60) );
# 				while (&ValidTurnTime($NextTurn,'Hour',\%GameValues) ne 'True') { 
 				while (&ValidTurnTime($NextTurn,'Hour',$GameValues{'DayFreq'}, $GameValues{'HourFreq'}) ne 'True') { 
 					# Get the weekday of the new turn so we can see if it's ok
 					($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = localtime($NextTurn);
 					# Move to the next available hour
 					#print "New Weekday: $CWeekDay   timeFreq = $GameValues{'HourlyTime'}\n";
 					$NextTurn = $NextTurn + $GameValues{'HourlyTime'}*60*60;
 					print "<P>Next Turn" . localtime($NextTurn);
 				}
			} else { &LogOut(0,"Delay Failed for $GameFile wrong game type",$ErrorLog); }
		}
		# And then delay by that much
		if (&UpdateNextTurn($db,$NextTurn,$GameFile,$GameValues{'LastTurn'})) {
			my $log =  "process_delay: $userlogin delayed $GameFile $delay_turns turns from " . localtime($GameValues{'NextTurn'}) . " ($GameValues{'NextTurn'}) to " . localtime($NextTurn) . " ($NextTurn)";
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
		if (my $sth = &DB_Call($db,$sql)) { 
      my $row = $sth->fetchrow_hashref(); ($SumOfDelaysLeft, $MinDelay) = ($row->{'SumOfDelaysLeft'}, $row->{'MinDelay'}); 
      $sth->finish();
    }

    # If we're too low on delays, reset everyone
		if ($SumOfDelaysLeft < $MinDelay) { 
			$sql = qq|UPDATE Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile) SET GameUsers.DelaysLeft = $GameValues{'NumDelay'} WHERE (((Games.GameFile)=\'$GameFile\'));|;
			if (my $sth = &DB_Call($db,$sql)) { 
				$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Turn Delays reset|;
				$GameValues{'Message'} = qq|A recent player for the $GameValues{'GameName'} game has delayed the game, causing a reset of the number of player delays available. You can now delay the game $GameValues{'NumDelay'} times.|;
				&Email_Turns($GameFile, \%GameValues, 0);
				&LogOut(100, "process_delay: $GameFile delays reset to $GameValues{'NumDelay'} due to $userlogin request of $delay_turns",$LogFile);
        $sth->finish();  
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
	print qq|<FORM method="$FormMethod" action="$WWW_Scripts/upload.pl" name="my_form" enctype="multipart/form-data">\n|;
	print qq|<table>\n<tr>\n|;
	print qq|<td><INPUT type="file" name="File" size="30"></td>\n|;
	print qq|<td><INPUT type="submit" name="submit" value="Upload Turn" | . &button_help('SendFile') . qq|></td>\n|;
	print qq|</tr>\n</table>\n|;
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
	my @PlayerData;
  my @Status;
  my @TXT;
	# Read in all the player data
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
		while (my $row = $sth->fetchrow_hashref()) { 
      %PlayerValues = %{$row};  
#			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
			push (@PlayerData, { %PlayerValues });
		}
    $sth->finish();
	} 
	# Get the different player statuses
	$sql = qq|SELECT * FROM _PlayerStatus;|;
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) {
      ($Status, $TXT) =  ($row->{'PlayerStatus'}, $row->{'PlayerStatus_txt'});
			push (@Status, $Status);
			push (@TXT, $TXT);
		}
    $sth->finish();
	}
	&DB_Close($db);
	print "<H2>Update Player Status for: $PlayerData[0]{'GameName'}</H2>\n";
	print "<table>\n";
  	my $LoopPosition = 0; #Start with the first player in the array.
  	while ($LoopPosition <= ($#PlayerData)) { # work the way through the array
		print "<tr>\n";
 		print qq|<FORM action="$WWW_Scripts/page.pl" method=$FormMethod>\n|;
		print qq|<input type=hidden name="lp" value="profile_game">\n|;
		print qq|<input type=hidden name="rp" value="my_games">\n|;
		print qq|<input type=hidden name="User_File" value="$PlayerData[$LoopPosition]{'User_File'}">\n|;
		print qq|<input type=hidden name="GameFile" value="$GameFile">\n|;
		print qq|<input type=hidden name="PlayerStatus" value=$PlayerData[$LoopPosition]{'PlayerStatus'}>\n|;
		print qq|<input type=hidden name="PlayerID" value=$LoopPosition>\n|;
		#print "<td>User ID:</td>\n";
    # Display the player IDs unless the game has anonymous players.
    if (!($PlayerData[0]{'AnonPlayer'} )) { 
      print qq|<td>Player $PlayerData[$LoopPosition]{'PlayerID'}:</td><td>User ID: $PlayerData[$LoopPosition]{'User_Login'}</td>\n|;
    } else {
      print qq|<td>User ID: Player $PlayerData[$LoopPosition]{'PlayerID'}</td>\n|;
    }
    print qq|<td><SELECT name="NewPlayerStatus">\n|;
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
  print qq|<P>Idle ignores turn submission status for turn generation.|;
  print qq|<P>Inactive alters the HST status to "Human (Inactive)" and enables the housekeeping AI.|;
  print qq|<P>Banned prevents the player from downloading turns. |;
  print qq|<P><P>Setting a player to inactive (or active) changes the .hst file. A turn will have to pass before the .m file is updated.|; 
  print qq| If you want access to the .m file sooner, reset the password on the .m file.|;
}

sub process_player_status {
  # Process the results of a host changing a player status. 
  my ($GameFile, $UserFile, $NewPlayerStatus, $PlayerStatus, $PlayerID) = @_;
  my $updateStatus = 0;
  my $update = 0;
  my $db = &DB_Open($dsn);
  # Get the valid player statuses from the database for display
  $sql = qq|SELECT * FROM _PlayerStatus;|;
  if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) { 
      ($Status, $TXT) = ($row->{'PlayerStatus'}, $row->{'PlayerStatus_txt'});
      # Only run updates if it's something we can update to
      if ($TXT eq $NewPlayerStatus) { $update = $Status; }
    }
    $sth->finish();
  }
  # Validate the new player status matches an entry in the database
  if ($update) {
    # If updating to Inactive, need to run the StarsAI code
    # Or to Active if the player was Inactive
    # Or to Idle from Inactive could be a thing.
    if ($NewPlayerStatus eq 'Inactive' || $NewPlayerStatus eq 'Active' || $NewPlayerStatus eq 'Idle') {
      $updateStatus = &StarsAI($GameFile, $PlayerID, $NewPlayerStatus );
    } else { $updateStatus = 1; } # If setting to IDLE, we still need to update the SQL
    if ($updateStatus) {
      #  Update the database
      my $Player = $PlayerID+1;
      # Different SQL if we know the Player number (true for Admin, not for user)
      if ($Player) {
        $sql = qq|UPDATE User INNER JOIN (Games INNER JOIN (_PlayerStatus INNER JOIN GameUsers ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus) ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login SET GameUsers.PlayerStatus = $update WHERE (((Games.HostName)=\'$userlogin\') AND ((Games.GameFile)=\'$GameFile\') AND ((User.User_File)=\'$UserFile\') AND (GameUsers.PlayerID=$Player));|;
      } else {
        $sql = qq|UPDATE User INNER JOIN (Games INNER JOIN (_PlayerStatus INNER JOIN GameUsers ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus) ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login SET GameUsers.PlayerStatus = $update WHERE (((Games.HostName)=\'$userlogin\') AND ((Games.GameFile)=\'$GameFile\') AND ((User.User_File)=\'$UserFile\') );|;
      }
      if (my $sth = &DB_Call($db,$sql)) { 
        &LogOut(100, "StarsAI: Status updated to $NewPlayerStatus for $GameFile by $userlogin",$LogFile);
        # email affected player(s)
        # First, get the name and email address of all the players for this game. 
        $sql = qq|SELECT Games.GameFile, Games.GameName, User.User_Login, User.User_Email, GameUsers.PlayerID, GameUsers.PlayerStatus, _PlayerStatus.PlayerStatus_txt FROM User INNER JOIN (_PlayerStatus INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON _PlayerStatus.PlayerStatus = GameUsers.PlayerStatus) ON User.User_Login = GameUsers.User_Login WHERE (((Games.GameFile)=\'$GameFile\'));|;
        if (my $sth = &DB_Call($db,$sql)) { 
          #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
          while (my $row = $sth->fetchrow_hashref()) { 
            %PlayerValues = %{$row};   
            push (@PlayerData, { %PlayerValues });
          }
          $sth->finish();
          # Next, loop through the list to email all the players and let them know what's happened. 
          my $LoopPosition = 0; #Start with the first player in the array.
          $MailFrom = $mail_from;
          # Not displaying the player name solves several problems, not the least is 
          # not having that value, and revealing anonymous players
          $Subject = "$mail_prefix $PlayerData[0]{'GameName'} : Player Status Change";
          $Message = "Player $Player status changed to $NewPlayerStatus in $PlayerData[0]{'GameName'}.";
          while ($LoopPosition <= ($#PlayerData)) { # work the way through the array
            $MailTo = $PlayerData[$LoopPosition]{'User_Email'};
            $smtp = &Mail_Open;
            &Mail_Send($smtp, $MailTo, $MailFrom, $Subject, $Message);
            $LoopPosition++;
          }
          &Mail_Close($smtp); 
        } else { &LogOut(10,"StarsAI: player_status failed updating PlayerID: $PlayerID for User $User_Login in $GameFile",$ErrorLog);}
        $sth->finish();
      }
    } else { &LogOut(10,"StarsAI: Invalid attempt to update player_status=$update for $User_Login by $userlogin for $GameFile",$ErrorLog);}
  } else { &LogOut(10,"StarsAI: Invalid attempt(2) to update player_status=$update for $User_Login by $userlogin for $GameFile",$ErrorLog);}
  &DB_Close($db);
}
  
sub submit_forcegen {
# Display the interface to force generate turns. 
	my ($GameFile) = @_;
	my $sql = qq|SELECT Games.* FROM Games WHERE (((Games.GameFile)='$GameFile') AND ((Games.HostName)='$userlogin'));|;
	my $db = &DB_Open($dsn);
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) { %GameValues = %{$row};  } 
    $sth->finish();
  }
	&DB_Close($db);
	# Get the current gate status
	my $HSTFile = "$Dir_Games/$GameFile/$GameFile.hst";
	($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile); # need HST_Turn

	print "<H2>Force Generate Turns for: $GameValues{'GameName'}</H2>\n";
	print "<P>Current Year: $HST_Turn\n";
	print qq|<form method=$FormMethod action="$WWW_Scripts/page.pl">\n|;
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
    print qq|<tr><td>Decrement ForceGen Times:</td><td><INPUT type="checkbox" name="decrementforcegentimes" onFocus="Help( 'DecrementForceGen' )" onMouseOver="Help( \'DecrementForceGen\' )" onMouseOut="Help( \'blank\' )" CHECKED></td></tr>\n|;
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
	if (my $sth = &DB_Call($db,$sql)) { 
    while (my $row = $sth->fetchrow_hashref()) { %GameValues = %{$row};   } 
    $sth->finish();
  }
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
			if (my $sth = &DB_Call($db,$sql)) { 
        &LogOut(200,"Decremented ForceGenTimes for $GameValues{'GameFile'}",$LogFile); 
        $sth->finish(); 
      }
			else { &LogOut(200,"Failed to Decrement ForceGenTimes for $GameValues{'GameFile'}",$ErrorLog);}
			if ($NumberofTimes <= 0) { #If the game is no longer forced, unforce game
				$sql = "UPDATE Games SET ForceGen = 0 WHERE GameFile = \'$GameValues{'GameFile'}\'";
				if (my $sth = &DB_Call($db,$sql)) { 
          &LogOut(200,"Forcegen set to 0 for $GameValues{'GameFile'}",$LogFile);
          $sth->finish();  
        }
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
		my $HSTFile = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.hst';
		($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Force Generated to Year $HST_Turn|;
		$GameValues{'Message'} = "Host Manually Force Generated Turn for $GameValues{'GameName'} to $HST_Turn\n";
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
 	if (my $sth = &DB_Call($db,$sql)) { 
    my $row = $sth->fetchrow_hashref(); { %GameValues = %{$row};   } 
    $sth->finish();
  }
  # Backup the existing .m file
  my $Backup_Source_File      = $Dir_Games . '/' .  $GameValues{'GameFile'} . '/' . $GameValues{'GameFile'} . '.m' . $PlayerID;
  my $Backup_Destination_File = $Backup_Source_File . '.bak'; 
 	copy($Backup_Source_File, $Backup_Destination_File);
 	&LogOut(100,"Copy $Backup_Source_File to $Backup_Destination_File",$LogFile);
  # Remove the password
  my $File = $Dir_Games . '/' . $GameFile . '/' . $GameFile . '.m' . $PlayerID;
  my $PasswordRemove = &StarsPWD($File);
  if ($PasswordRemove) { 
    print  "Password removed"; 
  # Email the player and host the password has been reset
  # my $EmailPlayers = &checkboxnull($GameValues{'EmailPlayers'});
  # This is a big deal, so we always want to notify everyone.
 		print "<P>Emailing players...\n";
 		$GameValues{'Subject'} = qq|$mail_prefix $GameValues{'GameName'} : Password Reset for Player $PlayerID|;
 		$GameValues{'Message'} = "The Host has reset the password for Player $PlayerID in $GameValues{'GameName'}\n";
 		&Email_Turns($GameFile, \%GameValues, 0);
    &LogOut(100,"Password reset for $File, $GameFile, $PlayerID", $LogFile);
    print 'Password removed. Remember to Save and Submit with a new password.';
  } else {
    print "Password failed to remove (or was already blank)\n";
    &LogOut(100,"Password not reset for $File, $GameFile, $PlayerID", $ErrorLog);
  }
	&DB_Close($db);
}

sub show_movie {
	my ($sql) = @_;
  my %GameValues;
  
	$db = &DB_Open($dsn);
	# Get the values for the current game
	if (my $sth = &DB_Call($db,$sql)) {
    my $row = $sth->fetchrow_hashref();
    %GameValues = %{$row};  
    #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
    $sth->finish();
	}
  &DB_Close($db);
  
  print qq|<h3>$GameValues{'GameName'}</h3>\n|;
  
  my $GameFile = $GameValues{'GameFile'};
  my $movieFile = $Dir_Graphs . "/movies/movie_$GameFile.gif";
  if (-f $movieFile) {
    print "<img src=\"/Downloads/movies/movie_$GameFile.gif\">\n";
  } else {
  	print "<P>No Movie Found.\n";
  	&LogOut(0,"No Movie found for $GameFile", $ErrorLog);
  }
}

sub show_email {
# Display the interface to send email to all the players.
	my ($GameFile, $GameName) = @_;
print <<eof;
<td>
<H2>Send Email to all players in: $GameName  </H2>
<FORM method=$FormMethod action="$WWW_Scripts/page.pl" name="my_form">
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
	&LogOut(100, "Email sent to all players for $GameFile : $GameName: $Message",$LogFile); 
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
  my ($warning) = @_;
  my @warnings;
  if ($warning) {
#    print "<font color=red><ul>\n";
    print "<font color=red>\n";
    @warnings = split (',',$warning);
    foreach my $warned (@warnings) {
#      print "<li>$warned</li>\n";
      print "<P>$warned</P>\n";
    } 
#    print "</ul></font>\n";
    print "</font>\n";
  } else {
    print "<P><font color=red>Warning: Using the browser Page Refresh/Reload will repeat the last Action.</font></P>\n";
  }
}

sub button_check {
  my ($button_count) = @_;
  if  ( ($button_count / 5) == int ($button_count/5) ) {
    print "<br>\n";
  } 
  $button_count++;
  return $button_count;
}

sub process_switch_player {
# see sub process_player_status {
  my ($GameFile, $PlayerID, $ReplaceName) = @_;
  my %GameValues;
  
  my $db = &DB_Open($dsn);
  # Get the host information for the game in question
  $sql = qq|SELECT * from Games WHERE GameFile = '$GameFile';|;
	# Get the values for the current game
	if (my $sth = &DB_Call($db,$sql)) {
    my $row = $sth->fetchrow_hashref(); 
    %GameValues = %{$row};  
    #			while ( my ($key, $value) = each(%GameValues) ) { print "<br>$key => $value\n"; }
    $sth->finish();
	}
  # Make certain the person is the Game Host
  if ($GameValues{'HostName'} eq $session->param("userlogin")) {
    $sql = qq|UPDATE GameUsers SET User_Login = '$in{'ReplaceName'}' WHERE PlayerID = $PlayerID AND GameFile = '$GameFile';|;
    if (my $sth = &DB_Call($db,$sql)) { 
      &LogOut(50, qq|switch_player: Player $PlayerID updated to $ReplaceName by $session->param("userlogin")|, $LogFile);
      $sth->finish(); 
    }
    # Email all the players of the change
    $GameValues{'Subject'} = $mail_prefix . "$GameValues{'GameName'} Player Change";
    $GameValues{'Message'} = "\n\nIn $GameValues{'GameName'} ($GameValues{'GameFile'}), the host has replaced Player $PlayerID with $ReplaceName.\n";
    &Email_Turns($GameFile, \%GameValues, 0);
    # Log the events
   	&LogOut(200,qq|switch_player: $session->param("userlogin") swapped $PlayerID to $ReplaceName|,$LogFile);
  } else { &LogOut(50, qq|switch_player: $session->param("userlogin") attempted to swap $PlayerID to $ReplaceName|, $ErrorLog);}  
  &DB_Close($db);
}
