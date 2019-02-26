#!/usr/bin/perl
# account.pl
# Account management for TotalHost
# Formerly a RallyPt File
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
use CGI::Session qw/-ip-match/;
CGI::Session->name('TotalHost');
use Win32::ODBC;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use TotalHost;
do 'config.pl';

# The _new_ way (from like 10 years ago)
foreach my $field (param()) { $in{$field} = param($field); }

#my $cgi = new CGI;      
#my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
#$cookie = $cgi->cookie(TotalHost);
# Doesn't need to validate, because everything in here doesn't require auth.
#&validate($cgi,$session);
#$id = $session->param("userid");

#print $cgi->header();

if ($in{'action'} eq 'login') { &login; die;
} elsif ($in{'action'} eq 'logout' || $in{'action'} eq 'logoutfull') { 
	my $cgi = new CGI;
	my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
	$sessionid = &get_cookie($cgi);
	$sessionid = $session->id unless $sessionid;
	if ($in{'action'} eq 'logout') { &logout($cgi,$session); die;}
	elsif ($in{'action'} eq 'logoutfull') { &logoutfull($cgi,$session); die;
	} else { &LogOut(10,"ERROR: How did we get here 1",$ErrorLog);
	}
}

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
$cookie = $cgi->cookie(TotalHost);
print $cgi->header();

&html_top($cgi, $session, $note);

if ($in{'action'} eq 'add_user' || $in{'action'} eq 'activate_user' ) {
	%menu_left = 	(
				"1About Us"			=> "$Location_Scripts/index.pl?lp=home&cp=aboutus",
				"2FAQ"				=> "$Location_Scripts/index.pl?lp=home&cp=faq",
				"3Strategy Guide"	=> "$WWW_HomePage/Strategy/SSG.HTM",
				"4Downloads"		=> "$Location_Scripts/index.pl?lp=home&cp=downloads",
				"3Order of Events"	=> "$Location_Scripts/index.pl?lp=home&cp=orderofevents",
				"3Game Defaults"	=> "$Location_Scripts/index.pl?lp=home&cp=gamedefaults",
				"5Other Sites"	=> "$Location_Scripts/index.pl?lp=home&cp=othersites",
				"3Game Policies"	=> "$Location_Scripts/index.pl?lp=home&cp=policies",
 				"9Log In" 			=> "$Location_Scripts/index.pl?cp=login_page",
 				"9Sign Up" 			=> "$Location_Scripts/index.pl?cp=create"
				);
} else {
%menu_left = 	(
 				"1Log In" 			=> "$Location_Scripts/index.pl?cp=login_page",
 				"2Sign Up" 			=> "$Location_Scripts/index.pl?cp=create",
 				"3Reset Password" 	=> "$Location_Scripts/index.pl?cp=reset_user",
 				"4Logout" 			=> "$Location_Scripts/index.pl?cp=logout",
 				);
# 				"5Erase" 			=> "$Location_Scripts/index.pl?cp=logoutfull"
}

&html_left(\%menu_left);

# cp
print "<td>";
if ($in{'action'} eq 'add_user') { &add_user; 
} elsif ($in{'action'} eq 'create_user') { &create_user; 
} elsif ($in{'action'} eq 'activate_user') { &activate_user; 
} elsif ($in{'action'} eq 'reset_user') { &reset_user; 
} elsif ($in{'action'} eq 'reset_password') { &reset_password; 
} elsif ($in{'action'} eq 'reset_password2') { &reset_password2; 
} elsif ($in{'action'} eq 'change_password') { &change_password; 
} elsif ($in{'action'} eq 'login_fail') { print "Login failed! (The User Name is case-sensitive)"; 
} elsif ($in{'action'} eq '') { print "No action specified\n"; 
} else { print "error with action: $in{'action'}\n"; }
print "</td>";

# RP
print qq|<td width="$rp_width"></td>\n|;

########################################

sub add_user {
	$User_First = $in{'User_First'};
	$User_Last = $in{'User_Last'};
	$User_Login = $in{'User_Login'};
	$User_Email = $in{'User_Email'};
	$db = &DB_Open($dsn);
	$Date =&GetTimeString();
	$hash = $in{'User_Password'} . $secret_key;
	$passhash = sha1_hex($hash); 
	$sql = "INSERT INTO User ([User_Login], [User_Last], [User_First], [User_Password], [User_Email], [User_Status], [User_Creation], [User_Modified], [EmailTurn], [EmailList]) VALUES ('$User_Login','$User_Last','$User_First','$passhash', '$User_Email', '-5','$Date','$Date', 1, 1);";
	&LogOut(100,$sql,$SQLLog);
	if (&DB_Call($db,$sql)) { print "<P>Done!  Check your email to activate your account. \n"; }
	else { print "<P>Error creating account. Duplicate?"; &LogOut(10,"ERROR: Adding New User $in{'User_Login'} $in{'User_Email'}",$ErrorLog);}
	# add an entry in the temp file to expect the account to be activated
	&DB_Close($db);
	# email user to activate the account
	# Hash password before sending it back out
	$hash = $passhash . $secret_key;
	$tmphash = sha1_hex($hash); 
	
	$Subject = $mail_prefix . 'Account Creation';
	$Message = "\n\nA request was submitted to create an account $User_Login.\n";
	$Message .= "To activate your account, select the link below:\n";
	$Message .= "$WWW_HomePage$Location_Scripts" . '/account.pl?action=activate_user&user=' . $in{'User_Login'} . '&new=' . $tmphash;
	$smtp = &Mail_Open;
	&Mail_Send($smtp, $in{'User_Email'}, $mail_from, $Subject, $Message);
	&Mail_Close($smtp);
	&LogOut(100,"Add Mail sent to $in{'User_Email'}",$LogFile);
}

sub activate_user {
	$submit_hash = $in{'new'};
	$submit_user = $in{'user'};
	$db = &DB_Open($dsn);
	$sql = "SELECT User.User_ID, User.User_Login, User.User_Password, User.User_Email FROM User;";
	&LogOut(100,$sql,$SQLLog);
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
			($User_ID, $User_Login, $User_Password, $User_Email) = $db->Data("User_ID", "User_Login", "User_Password", "User_Email");
			$hash = $User_Password . $secret_key;
			$passhash = sha1_hex($hash); 
			&LogOut(200,"Attempting a match on  1: $User_Login 2: $User_Password 3: $passhash  4: $submit_hash",$LogFile);		
			if ($passhash eq $submit_hash && $submit_user eq $User_Login) {
				$id = $User_ID;
				&LogOut(200,"Activate user match success on $User_Login",$LogFile);
			} else { &LogOut(200,"Activate user match failed on $User_Login",$LogFile); }
			if ($id) { last; }  # no need to keep going if there's a hit
		}
	} else {  &LogOut(200,"Database call $sql failed",$LogFile);}
	if ($id) {
		my $cgi = new CGI;
		my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
		$sessionid = $session->id unless $sessionid;
		$session->param("logged-in", 1);
		$session->param("userid", $User_ID);
		$session->param("userlogin", $User_Login);
		$session->param("email", $User_Email);
		&LogOut(100,"Account Activated for $User_Login",$LogFile);
		$Date =&GetTimeString();
    $userfile = substr(sha1_hex(time()), 5, 8); 
		$sql = "UPDATE User SET User_Status='1', User_Modified='$Date', User_File='$userfile'  WHERE User_ID=$id;";
		&LogOut(100,$sql,$SQLLog);
		&DB_Call($db,$sql);
		$redirect = $WWW_HomePage . $Location_Scripts . '/page.pl';
# handy function - don't lose. 
#		&print_redirect($cgi,$sessionid,$redirect);
		print "Account Activated for $User_Login" . ". Please Log In.";
	} else {
		print "User not found.\n";
		&LogOut(100,"Attempt to Activate non-existent account $id",$ErrorLog);
	}
	&DB_Close($db);
}

sub reset_user {
  my $id;
	print "<P>Reset of User Password......\n"; 
	&LogOut(100,"Password Reset for $in{'User_Login'}",$LogFile);
	$db = &DB_Open($dsn);
	$sql = "SELECT User.User_Login, User.User_ID, User.User_Email FROM User;";
	&LogOut(100,$sql,$SQLLog);
	# Check to be sure the account exists
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	    ($User_Login, $User_ID, $User_Email) = $db->Data("User_Login", "User_ID", "User_Email");
			if ($User_Login eq $in{'User_Login'} && lc($User_Email) eq lc($in{'User_Email'}) ) {
				$id = $User_ID;
			}
			if ($id) { last; } 
		}
	} 

  if ($id) { 
  	# Create new temporary password
  	$temp = $id . $secretkey;
  	$new_password = sha1_hex($temp);
  	$Date =&GetTimeString();
  	# add new temporary password to database
  	$sql = "UPDATE User SET User_Password='$new_password', User_Status='2', User_Modified='$Date' WHERE User_ID=$id;";
  	&LogOut(100,$sql,$SQLLog);
  	&DB_Call($db,$sql);
  	&DB_Close($db);
  	# Email new temporary password
  	$Subject = $mail_prefix . 'Password Reset Request';
  	$Message = "\n\nA request was submitted to reset your password for User ID: $in{'User_Login'}.\n";
  	$Message .= "To reset your password, select the link below:\n";
  	$Message .= "$WWW_HomePage$Location_Scripts" . '/account.pl?action=reset_password&new=' . $new_password . '&user=' . $in{'User_Login'};
  	print "Sending email with a link to reset the password\n";
  	$smtp = &Mail_Open;
  	&Mail_Send($smtp, $User_Email, $mail_from, $Subject, $Message);
  	&Mail_Close($smtp);
  	&LogOut(100,"Password Reset sent to $User_Email",$LogFile);
  	# set account to require a reset
  } else { print "$in{'User_Login'} does not exist\n"; 	&LogOut(100,"ERROR: $in{'User_Login'} does not exist",$ErrorLog);  }
}

sub reset_password {
	# need to not be able to get here without being logged in. 
  # Except that reset_user redirects to here after resetting a lost password
	$submit_hash = $in{'new'};
	$submit_user = $in{'user'};
	$db = &DB_Open($dsn);
	$sql = "SELECT User.User_Login, User.User_ID, User.User_Password, User.User_Email FROM User;";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	      	($User_Login, $User_ID, $User_Password, $User_Email) = $db->Data("User_Login", "User_ID", "User_Password", "User_Email");
			$temp = $User_ID . $secretkey;
			$new_password = sha1_hex($temp);
			if ($User_Login eq "$in{'user'}" &&  $User_Password eq "$new_password") {
				$id = $User_ID;
			}
			if ($id) { last; } 
		}
	}
	&DB_Close($db);
	if ($id) {
print <<eof;
<td>
<form name="login" method=POST action="$Location_Scripts/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
<input type=hidden name="action" value="reset_password2">
<input type=hidden name="User_Login" value="$User_Login">
<br>Enter new password: <input type=text id="pass_temp">
<input type=hidden name="User_Password" id="User_Password">
<input type=hidden name="Old_Password" value="$User_Password">
<input type=submit name="Submit" value="Reset Password">
</form>
</td>
eof
	} else {
		print "<td>Account does not exist. How did that happen?</td>\n";
		&LogOut (100,"Invalid attempt to reset password $in{'user'}",$LogFile);
	}
}

sub reset_password2 {
	$db = &DB_Open($dsn);
	$sql = "SELECT User.User_Login, User.User_Password, User.User_ID, User.User_Email FROM User;";
	if (&DB_Call($db,$sql)) {
		while ($db->FetchRow()) {
	      	($User_Login, $User_ID, $User_Password, $User_Email) = $db->Data("User_Login", "User_ID", "User_Password", "User_Email");
			if ($User_Login eq $in{'User_Login'} && $User_Password eq $in{'Old_Password'} ) {
				$id = $User_ID;
			}
			if ($id) { last; } 
		}
	}
	if ($id) {
		$new_password = $in{'User_Password'};
		$hash = $new_password . $secret_key;
		$userhash = sha1_hex($hash); 
		$Date = &GetTimeString();
		$sql = "UPDATE User SET User_Password='$userhash', User_Status='1', User_Modified='$Date' WHERE User_ID=$id;";
		&LogOut(100,$sql,$SQLLog);
		&DB_Call($db,$sql);
		print "Password Updated for $in{'User_Login'}.";		
	} else {
		$log = "Failure to update password for $in{'User_Login'}";
		print $log;
		&LogOut(10,$log,$LogFile);
	}
	&DB_Close($db);	
}

sub change_password {
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

	print "Password changed for $userid\n";
}

sub login {
#	use Captcha::reCAPTCHA;
#	my $c = Captcha::reCAPTCHA->new;
#	$challenge = $in{'recaptcha_challenge_field'};
#	$response = $in{'recaptcha_response_field'};
# 	my $result = $c->check_answer(
#        '6LcjY7oSAAAAAEA5jB6e9Ku4z64SISeDVXSRjXmA ', $ENV{'REMOTE_ADDR'},
#        $challenge, $response
#	);
#     if (!( $result->{is_valid} )) {
#         # Error
#         $error = $result->{error};
# 		&LogOut(200,"Login user reCaptcha failed on $User_Login: $error",$LogFile);
# 		die;
#     }
#    else {
		$submit_hash = $in{'User_Password'};
		$submit_user = $in{'User_Login'};
		$sql = "SELECT * FROM User;";
		&LogOut(200,$sql,$SQLLog);
		$db = &DB_Open($dsn);
		if (&DB_Call($db,$sql)) {
			while ($db->FetchRow()) {
				($User_ID, $User_Login, $User_Password, $User_Email) = $db->Data("User_ID", "User_Login", "User_Password", "User_Email");
				$hash = $submit_hash . $secret_key;
				$passhash = sha1_hex($hash); 
				&LogOut(200,"Attempting a match on  1: $User_Login 2: $User_Password 3: $passhash  4: $submit_hash",$LogFile);		
				if ($User_Password eq $passhash && $submit_user eq $User_Login) {
					$id = $User_ID;
					&LogOut(200,"Login user match success on $User_Login",$LogFile);
				} else { &LogOut(200,"Login user match failed on $User_Login",$LogFile); }
				if ($id) { last; }  # no need to keep going if there's a hit
			}
		} else {  &LogOut(100,"Login Database call failed for $submit_user",$LogFile);}
		&DB_Close($db);	
		if ($id) {
			&LogOut(100,"$submit_user Logged In",$LogFile);
			my $cgi = new CGI;
			my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
			$sessionid = $session->id unless $sessionid;
			$session->param("logged-in", 1);
			$session->param("userid", $User_ID);
			$session->param("userlogin", $User_Login);
			$session->param("email", $User_Email);
#			$redirect = $WWW_HomePage . $Location_Scripts . '/page.pl';
#			$redirect = $WWW_HomePage . $Location_Scripts . '/index.pl?lp=home';
			$redirect = $WWW_HomePage . $Location_Scripts . '/page.pl?lp=profile_game&cp=show_first_game';
			&print_redirect($cgi,$sessionid,$redirect);
		} else {
			&LogOut(100,"$submit_user failed to Log In",$LogFile);
			my $cgi = new CGI;
#			my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$session_dir"});
#			$sessionid = $session->id unless $sessionid;
#			$session->param("logged-in", 1);
#			$session->param("userid", $User_ID);
#			$session->param("userlogin", $User_Login);
#			$session->param("email", $User_Email);
			print $cgi->redirect( -URL => "$Location_Scripts/account.pl?action=login_fail");
#			$redirect = $WWW_HomePage . $Location_Scripts . '/index.pl';
#			&print_redirect($cgi,$sessionid,$redirect);
		}
#    }
}

sub logout { 
	my ($cgi, $session) = @_; # receive two args
    $session->clear(["logged-in"]);
    $cookie = $cgi->cookie
       (-NAME	=>	'TotalHost', 
	    -VALUE	=>	"", 
        -PATH => '/',
	    -EXPIRES=>	"+3M",
	   );
    print $cgi->redirect( -URL => "$Location_Scripts/index.pl", -cookie=> [$cookie]);
}

sub logoutfull { 
	my ($cgi, $session) = @_; # receive two args
    $session->clear(["logged-in"]);
	$session->delete();
    $cookie = $cgi->cookie
       (-NAME	=>	'TotalHost', 
	    -VALUE	=>	"", 
        -PATH => '/',
	    -EXPIRES=>	"-1M",
	   );
    print $cgi->redirect( -URL => "$Location_Scripts/index.pl", -cookie=> [$cookie]);
}