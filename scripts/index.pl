#!/usr/bin/perl
# index.pl
# Formerly a RallyPt file
# Creates Base Pages for TotalHost
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
use StarsConfig;
my $config = new StarsConfig();

use CGI qw(:standard);
use CGI::Session;

my $dbEnabled = $config->isFeatureLive("database");
my $scriptsRoot = $config->scriptsRoot();
my $htmlRoot = $config->htmlRoot();

use if $dbEnabled, Win32::ODBC;

CGI::Session->name('TotalHost');

use TotalHost;

do 'config.pl';

#%in = &parse_input(*in);
foreach my $field (param()) { $in{$field} = &clean(param($field)); }

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
#$sessionid = $session->id unless $sessionid;
$sessionid = $session->id;
$cookie = $cgi->cookie(TotalHost);

# Doesn't need to validate, because everything in here doesn't require auth.
#&validate($cgi,$session);
$id = $session->param('userid');
$userlogin = $session->param('userlogin');


# BUG: This should be enabled and work, just didn't last I thinkered with it. 
# If the user happens to be logged in, redirect them to the first game page
# &LogOut(0,"ID = $id, Login = $userlogin",$ErrorLog); 
# if ($userlogin) {  
# 	$redirect =  $WWW_HomePage . $scriptsRoot . '/page.pl?lp=game&cp=show_first_game';
# 	print $cgi->redirect( -URL => "$redirect");
# #	&print_redirect($cgi,$sessionid,$redirect);
# 	&LogOut(0, "redirect: $redirect", $ErrorLog); 
# }

print $cgi->header();
&html_top($cgi, $session, $config);
print "<P>\n";

if ($id ) {
%menu_left = 	(
				"0About Us"			=> "$scriptsRoot/index.pl?lp=home&cp=aboutus",
 				"1Features" 		=> "$scriptsRoot/index.pl?cp=features",
				"2FAQ"				=> "$scriptsRoot/index.pl?lp=home&cp=faq",
				"3Order of Events"	=> "$scriptsRoot/index.pl?lp=home&cp=orderofevents",
				"3Game Defaults"	=> "$scriptsRoot/index.pl?lp=home&cp=gamedefaults",
				"3Game Policies"	=> "$scriptsRoot/index.pl?lp=home&cp=policies",
				"6Strategy Library"	=> "$scriptsRoot/index.pl?lp=home&cp=library",
				"8Other Sites"		=> "$scriptsRoot/index.pl?lp=home&cp=othersites",
				"9Recent Changes"	=> "$scriptsRoot/index.pl?lp=home&cp=recentchanges"
				);
} elsif ($in{'lp'} eq 'home') {
%menu_left = 	(
				"0About Us"			=> "$scriptsRoot/index.pl?lp=home&cp=aboutus",
 				"1Features" 		=> "$scriptsRoot/index.pl?cp=features",
				"2FAQ"				=> "$scriptsRoot/index.pl?lp=home&cp=faq",
				"3Order of Events"	=> "$scriptsRoot/index.pl?lp=home&cp=orderofevents",
				"6Strategy Library"	=> "$scriptsRoot/index.pl?lp=home&cp=library",
				"9Other Sites"		=> "$scriptsRoot/index.pl?lp=home&cp=othersites",
 				"9Log In" 			=> "$scriptsRoot/index.pl?cp=login_page",
 				"9Sign Up" 			=> "$scriptsRoot/index.pl?cp=create"
				);
} else {
%menu_left = 	(
 				"0Features" 		=> "$scriptsRoot/index.pl?cp=features",
 				"1Log In" 			=> "$scriptsRoot/index.pl?cp=login_page",
 				"2Sign Up" 			=> "$scriptsRoot/index.pl?cp=create",
 				"3Reset Password" 	=> "$scriptsRoot/index.pl?cp=reset_user",
 				"4Logout" 			=> "$scriptsRoot/index.pl?cp=logout",
 				);
# 				"5Erase" 			=> "$scriptsRoot/index.pl?cp=logoutfull"
}

&html_left(\%menu_left);

if ($in{'cp'} eq 'login_page')          { &login_page; 
} elsif ($in{'cp'} eq 'reset_user')     { &reset_user; 
} elsif ($in{'cp'} eq 'create')         { &account_create; 
} elsif ($in{'cp'} eq 'max')            { &max_users; 
} elsif ($in{'cp'} eq 'orderofevents')  { &show_html("$htmlRoot/THOrder.htm"); 
} elsif ($in{'cp'} eq 'tips')           { &show_html("$htmlRoot/THTips.htm"); 
} elsif ($in{'cp'} eq 'faq')            { &show_html("$htmlRoot/THFAQ.htm"); 
} elsif ($in{'cp'} eq 'hfile')          { &show_html("$htmlRoot/THHFile.htm"); 
} elsif ($in{'cp'} eq 'score')          { &show_html("$htmlRoot/THScore.htm"); 
} elsif ($in{'cp'} eq 'holidays') { 
		&show_html("$htmlRoot/THHolidays.htm"); 
		print "<td width=$rp_width>";
		&ShowHolidays; 
		print "</td>";
} elsif ($in{'cp'} eq 'policies')       { &show_html("$htmlRoot/THPolicies.htm"); 
} elsif ($in{'cp'} eq 'bugs')           { &show_html("$htmlRoot/THBugs.htm"); 
} elsif ($in{'cp'} eq 'features')       { &show_html("$htmlRoot/THFeatures.htm"); 
} elsif ($in{'cp'} eq 'hidden')         { &show_html("$htmlRoot/THHidden.htm"); 
} elsif ($in{'cp'} eq 'alliance')       { &show_html("$htmlRoot/THAlliance.htm"); 
} elsif ($in{'cp'} eq 'deception')      { &show_html("$htmlRoot/THDeception.htm"); 
} elsif ($in{'cp'} eq 'intel')          { &show_html("$htmlRoot/THIntel.htm"); 
} elsif ($in{'cp'} eq 'library')        { &show_html("$htmlRoot/THLibrary.htm"); 
} elsif ($in{'cp'} eq 'turngeneration') { &show_html("$htmlRoot/THTurnGeneration.htm"); 
} elsif ($in{'cp'} eq 'downloads')      { &show_html("$htmlRoot/THDownloads.htm"); 
} elsif ($in{'cp'} eq 'gamedefaults')   { &show_html("$htmlRoot/THDefault.htm"); 
} elsif ($in{'cp'} eq 'othersites')     { &show_html("$htmlRoot/THOtherSites.htm"); 
} elsif ($in{'cp'} eq 'recentchanges')  { &show_html("$htmlRoot/THRecentChanges.htm"); 
} elsif ($in{'cp'} eq 'aboutus')        { &show_html("$htmlRoot/THAboutUs.htm"); 
} elsif ($in{'cp'} eq 'privacypolicy')  { &show_html("$htmlRoot/privacy_policy.html"); 
} elsif ($in{'cp'} eq 'termsofuse')     { &show_html("$htmlRoot/terms_of_use.html"); 
} elsif ($in{'cp'} eq 'install')        { &show_html("$htmlRoot/THInstall.htm"); 
} elsif ($in{'cp'} eq 'started')        { &show_html("$htmlRoot/THStarted.htm"); 
} elsif ($in{'cp'} eq 'starsfiles')     { &show_html("$htmlRoot/THStarsFiles.htm"); 
#} elsif ($in{'cp'} eq 'ssg') { &show_html("$htmlRoot/SSG/SSG.HTM"); 
} else { 
	my $welcome = $htmlRoot . '/' . 'welcome.htm';
	&show_html($welcome);
}

if ($in{'rp'} eq 'something') {
	$sql = 'SELECT * from Games WHERE GameStatus = 2;';
	print qq|<td width="$rp_width">\n|;
	if($dbEnabled) {
		&list_games($sql, 'Games in Progress');
	}
	print "</td>\n";

} elsif  (!($in{'rp'})) { print qq|<td width="$rp_width"></td>\n|;
} else { print qq|<td width="$rp_width"></td>\n|;
}

#&html_right;
print "</tr></table>\n";
&html_bottom;

##############################################################################
sub login_page {
# duplicate since base value set at beginning.
#	$id = $session->param('userid');
	print qq|<td>\n|;
#	print qq|<h2>Log In</h2>\n|;
	print qq|<form name="login" method=POST action="$scriptsRoot/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">\n|;
	print qq|<input type=hidden name="action" value="login">\n|;
	print qq|<table>\n|;
	print qq|<tr><td>User ID: </td><td><input type=text name="User_Login" value="$id" size=10 maxlength=32></td></tr>\n|;
	print qq|<tr><td>Password: </td><td><input type=password id="pass_temp" size=10></td><input type=hidden name="User_Password" id="User_Password"></tr>\n|;
	print qq|<tr><td>\n|;
	print qq|</td></tr>\n|;
	print qq|<tr><td><input type=submit name="Submit" value="Log In"></td></tr>\n|;
	print qq|</table></form></td>\n|;
}

sub reset_user {
print <<eof;
<td>
<h2>Reset Password</h2>
<form method=POST action="$scriptsRoot/account.pl">
<input type=hidden name="action" value="reset_user">
<table>
<tr><td>User ID: </td><td><input type=text name="User_Login" value=""></td></tr>
<tr><td>Email: </td><td><input type=text name="User_Email" value=""></td></tr>
<tr><td><input type=submit name="Submit" value="Reset Password"></td></tr>
</table>
</form>
</td>
eof
}

sub account_create {
	if($dbEnabled) {
		# confirm that there's not too many users
		$db = &DB_Open($dsn);
		$sql = qq|SELECT Count(User.User_ID) AS CountOfUser_ID FROM [User];|;
		&LogOut(100,$sql,$LogFile);
		if (&DB_Call($db,$sql)) { 
			while ($db->FetchRow()) {
				($User_Count) = $db->Data("CountOfUser_ID");
			}
		} else { &LogOut(10,'ERROR: account_create confirming user account',$LogFile);}
		&DB_Close($db);
		if ($User_Count > $max_users ) {
			#print $cgi->redirect( -URL => "$WWW_HomePage$scriptsRoot/index.pl?cp=max");
		&max_users;	
			exit;
		} 

	print <<eof;
<td>
<h2>Create Account</h2>
<form name="login" method=POST action="$scriptsRoot/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
<input type=hidden name="action" value="add_user">
<table>
<tr><td>First Name: </td><td><input type=text name="User_First" value="" size=32 maxlength=32></td></tr>
<tr><td>Last Name: </td><td><input type=text name="User_Last" value="" size=32 maxlength=32></td></tr>
<tr><td>User ID: </td><td><input type=text name="User_Login" value="" size=32 maxlength=32></td></tr>
<tr><td>Email Address: </td><td><input type=text name="User_Email" value="" size=32 maxlength=32></td></tr>
<tr><td>Password: </td><td><input type=password id="pass_temp"></td></tr>
<tr><td><input type=hidden name="User_Password" id="User_Password"><input type=submit name="Submit" value="add"></td></tr>
</table>
<input type=hidden name="cp" value="">
</form>
</td>
eof
	}
}

sub max_users {
print <<eof;
<td>
<h2>Maxxed Users</h2>

<P>Hard as it is to believe, the site has maxxed out on $max_users
which is the current configured maximum. Please contact $mail_from if you'd like there to be more!
</td>
eof
}