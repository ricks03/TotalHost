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

use CGI qw(:standard);
$CGI::POST_MAX = 1024 * 100;  # Limit uploads to 100KB
use CGI::Session;
CGI::Session->name('TotalHost');
use CGI::Carp qw(fatalsToBrowser);
use DBI;
do 'config.pl';
use TotalHost;

#%in = &parse_input(*in);
#foreach my $field (param()) { $in{$field} = &clean(param($field)); }

# Another memory protecting choice
my @params = param();
if (scalar @params > 20) {  # Allow only up to 20 parameters
    &LogOut(100,"index.pl: Too many input parameters",$LogFile); 
    die "Too many input parameters";
}

foreach my $field (param()) {
   my $value = param($field);  # Get the values for the current parameter in list context
   
   # Limit input length to prevent excessive memory use
   if (length($value) > 255) {  
     &LogOut(100,"index.pl: Input too long for parameter: $field",$LogFile); 
     die "Input too long for parameter: $field";
   }
   
   $in{$field} = clean($value);  # Clean and assign to %in hash
}

my $cgi = CGI->new;      
my $cookie = $cgi->cookie('TotalHost');
# Limiting session duration
#my $session = CGI::Session->new("driver:File", $cookie, {Directory=>"$Dir_Sessions"});
my $session = CGI::Session->new("driver:File", $cookie, {Directory=>"$Dir_Sessions", expires=>"+4h"});
my $sessionid = $session->id unless $sessionid;
#$sessionid = $session->id;

# Doesn't need to validate, because everything in here doesn't require auth.
#&validate($cgi,$session);
$id = $session->param('userid');
$userlogin = $session->param('userlogin');

# If the user happens to be logged in, redirect them to the first game page
# &LogOut(0,"ID = $id, Login = $userlogin",$ErrorLog); 
# if ($userlogin) {  
# 	$redirect =  $WWW_HomePage . $WWW_Scripts . '/page.pl?lp=game&cp=show_first_game';
# 	#print $cgi->redirect( -URL => "$redirect");
# ##	&print_redirect($cgi,$sessionid,$redirect);
#   print "Location: $redirect\n\n";
#   exit;
# }

print $cgi->header();
&html_top($cgi, $session, $note);
print "<P>\n";

if ($id ) {
%menu_left = 	(
				"0About Us"			=> "$WWW_Scripts/index.pl?lp=home&cp=aboutus",
 				"1Features" 			=> "$WWW_Scripts/index.pl?cp=features",
				"2TH FAQ"				=> "$WWW_Scripts/index.pl?lp=home&cp=faq",
				"6Strategy Library"	=> "$WWW_Scripts/index.pl?lp=home&cp=library",
				"8Other Sites"	=> "$WWW_Scripts/index.pl?lp=home&cp=othersites",
				"9Recent Changes"	=> "$WWW_Scripts/index.pl?lp=home&cp=recentchanges"
				);
# "3Game Defaults"	=> "$WWW_Scripts/index.pl?lp=home&cp=gamedefaults",
# "3Game Policies"	=> "$WWW_Scripts/index.pl?lp=home&cp=policies",
} elsif ($in{'lp'} eq 'home') {
%menu_left = 	(
				"0About Us"			=> "$WWW_Scripts/index.pl?lp=home&cp=aboutus",
 				"1Features" 			=> "$WWW_Scripts/index.pl?lp=home&cp=features",
				"2TH FAQ"				=> "$WWW_Scripts/index.pl?lp=home&cp=faq",
				"6Strategy Library"	=> "$WWW_Scripts/index.pl?lp=home&cp=library",
				"7Other Sites"	=> "$WWW_Scripts/index.pl?lp=home&cp=othersites",
 				"8Sign Up" 			=> "$WWW_Scripts/index.pl?lp=home&cp=create",
 				"9Log In" 			=> "$WWW_Scripts/index.pl?lp=home&cp=login_page",
				);
} else {
# %menu_left = 	(
#  				"0Features" 			=> "$WWW_Scripts/index.pl?cp=features",
#  				"1Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
#  				"2Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create",
#  				"3Reset Password" 	=> "$WWW_Scripts/index.pl?cp=reset_user",
#  				"4Logout" 			=> "$WWW_Scripts/index.pl?cp=logout",
#  				);
# 				"5Erase" 			=> "$WWW_Scripts/index.pl?cp=logoutfull"
%menu_left = 	(
 				"1Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
 				"2Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create",
 				);
}

&html_left(\%menu_left);

if ($in{'cp'} eq 'login_page') { &login_page; 
} elsif ($in{'cp'} eq 'reset_user') { &reset_user; 
} elsif ($in{'cp'} eq 'create') { &account_create; 
} elsif ($in{'cp'} eq 'max') { &max_users; 
} elsif ($in{'cp'} eq 'orderofevents') { &show_html("$Dir_WWWRoot/THOrder.htm"); 
} elsif ($in{'cp'} eq 'tips') { &show_html("$Dir_WWWRoot/THTips.htm"); 
} elsif ($in{'cp'} eq 'faq') { &show_html("$Dir_WWWRoot/THFAQ.htm"); 
} elsif ($in{'cp'} eq 'hfile') { &show_html("$Dir_WWWRoot/THHFile.htm"); 
} elsif ($in{'cp'} eq 'score') { &show_html("$Dir_WWWRoot/THScore.htm"); 
} elsif ($in{'cp'} eq 'holidays') { 
		&show_html("$Dir_WWWRoot/THHolidays.htm"); 
		print "<td width=$rp_width>";
		&ShowHolidays; 
		print "</td>";
} elsif ($in{'cp'} eq 'policies') { &show_html("$Dir_WWWRoot/THPolicies.htm"); 
} elsif ($in{'cp'} eq 'bugs') { &show_html("$Dir_WWWRoot/THBugs.htm"); 
} elsif ($in{'cp'} eq 'features') { &show_html("$Dir_WWWRoot/THFeatures.htm"); 
} elsif ($in{'cp'} eq 'hidden') { &show_html("$Dir_WWWRoot/THHidden.htm"); 
} elsif ($in{'cp'} eq 'alliance') { &show_html("$Dir_WWWRoot/THAlliance.htm"); 
} elsif ($in{'cp'} eq 'deception') { &show_html("$Dir_WWWRoot/THDeception.htm"); 
} elsif ($in{'cp'} eq 'intel') { &show_html("$Dir_WWWRoot/THIntel.htm"); 
} elsif ($in{'cp'} eq 'library') { &show_html("$Dir_WWWRoot/THLibrary.htm"); 
} elsif ($in{'cp'} eq 'turngeneration') { &show_html("$Dir_WWWRoot/THTurnGeneration.htm"); 
} elsif ($in{'cp'} eq 'downloads') { &show_html("$Dir_WWWRoot/THDownloads.htm"); 
} elsif ($in{'cp'} eq 'gamedefaults') { &show_html("$Dir_WWWRoot/THDefault.htm"); 
} elsif ($in{'cp'} eq 'othersites') { &show_html("$Dir_WWWRoot/THOtherSites.htm"); 
} elsif ($in{'cp'} eq 'recentchanges') { &show_html("$Dir_WWWRoot/THRecentChanges.htm"); 
} elsif ($in{'cp'} eq 'aboutus') { &show_html("$Dir_WWWRoot/THAboutUs.htm"); 
} elsif ($in{'cp'} eq 'privacypolicy') { &show_html("$Dir_WWWRoot/privacy_policy.html"); 
} elsif ($in{'cp'} eq 'termsofuse') { &show_html("$Dir_WWWRoot/terms_of_use.html"); 
} elsif ($in{'cp'} eq 'install') { &show_html("$Dir_WWWRoot/THInstall.htm"); 
} elsif ($in{'cp'} eq 'started') { &show_html("$Dir_WWWRoot/THStarted.htm"); 
} elsif ($in{'cp'} eq 'starsfiles') { &show_html("$Dir_WWWRoot/THStarsFiles.htm"); 
} elsif ($in{'cp'} eq 'notes') { &show_notes; 
#} elsif ($in{'cp'} eq 'ssg') { &show_html("$Dir_WWWRoot/SSG/SSG.HTM"); 
} else { 
	my $welcome = $Dir_WWWRoot . '/' . 'welcome.htm';
	&show_html($welcome);
}

if ($in{'rp'} eq 'something') {
	$sql = 'SELECT * from Games WHERE GameStatus = 2;';
	print qq|<td width="$rp_width">\n|;
	&list_games($sql, 'Games in Progress');
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
	print qq|<FORM name="login" method="$FormMethod" action="$WWW_Scripts/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">\n|;
	print qq|<input type="hidden" name="action" value="login">\n|;
	print qq|<table>\n|;
	print qq|<tr><td>User ID: </td><td><input type=text name="User_Login" value="$id" size=10 maxlength=32></td></tr>\n|;
	print qq|<tr><td>Password: </td><td><input type=password id="pass_temp" size=10></td><input type="hidden" name="User_Password" id="User_Password"></tr>\n|;
	print qq|<tr><td>\n|;
	print qq|</td></tr>\n|;
	print qq|<tr><td><input type=submit name="Submit" value="Log In"></td></tr>\n|;
	print qq|</table></FORM></td>\n|;
}

sub reset_user {
print <<eof;
<td>
<h2>Reset Password</h2>
<FORM method="$FormMethod" action="$WWW_Scripts/account.pl">
<input type="hidden" name="action" value="reset_user">
<table>
<tr><td>User ID: </td><td><input type=text name="User_Login" value=""></td></tr>
<tr><td>Email: </td><td><input type=text name="User_Email" value=""></td></tr>
<tr><td><input type=submit name="Submit" value="Reset Password"></td></tr>
</table>
</FORM>
</td>
eof
}

sub account_create {
	# confirm that there's not too many users
	$db = &DB_Open($dsn);
	$sql = qq|SELECT Count(User.User_ID) AS CountOfUser_ID FROM `User`;|;
	if (my $sth = &DB_Call($db,$sql)) { 
  	($User_Count) = $sth->fetchrow_array();
    $sth->finish();
  }
  &DB_Close($db);
  if ($User_Count > $max_users ) {
  	#print $cgi->redirect( -URL => "$WWW_HomePage$WWW_Scripts/index.pl?cp=max");
    &max_users;	
  	exit;
  } 

print <<eof;
<td>
<h2>Create Account</h2>
<FORM name="login" method=POST action="$WWW_Scripts/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
<input type="hidden" name="action" value="add_user">
<table>
<tr><td>First Name: </td><td><input type=text name="User_First" value="" size=32 maxlength=32></td></tr>
<tr><td>Last Name: </td><td><input type=text name="User_Last" value="" size=32 maxlength=32></td></tr>
<tr><td>User ID: </td><td><input type=text name="User_Login" value="" size=32 maxlength=32></td></tr>
<tr><td>Email Address: </td><td><input type=text name="User_Email" value="" size=32 maxlength=32></td></tr>
<tr><td>Password: </td><td><input type=password name="pass_temp" id="pass_temp"></td></tr>
<tr><td><input type="hidden" name="User_Password" id="User_Password"><input type=submit name="Submit" value="add"></td></tr>
</table>
<input type="hidden" name="cp" value="">
</FORM>
</td>
eof
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
