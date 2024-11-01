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
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use Email::Valid;
use DBI;
do 'config.pl';
use TotalHost;

my %in; 

# The _new_ way (from like 10 years ago)
#foreach my $field (param()) { $in{$field} = param($field); }
foreach my $field (param()) {
   my $value = param($field);  # Get the values for the current parameter in list context
   $in{$field} = clean($value);  # Clean and assign to %in hash
}

#my $cgi = new CGI;      
#my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
#$cookie = $cgi->cookie(TotalHost);
# Doesn't need to validate, because everything in here doesn't require auth.
#&validate($cgi,$session);
#$id = $session->param("userid");

#print $cgi->header();

if ($in{'action'} eq 'login') { &login; die;
} elsif ($in{'action'} eq 'logout' || $in{'action'} eq 'logoutfull') { 
	my $cgi = new CGI;
	my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
	$sessionid = &get_cookie($cgi);
	$sessionid = $session->id unless $sessionid;
	if ($in{'action'} eq 'logout') { &logout($cgi,$session); die;}
	elsif ($in{'action'} eq 'logoutfull') { &logoutfull($cgi,$session); die;
	} else { &LogOut(10,"ERROR: How did we get here 1",$ErrorLog);
	}
}

my $cgi = new CGI;      
my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
$cookie = $cgi->cookie(TotalHost);
print $cgi->header();

&html_top($cgi, $session, $note);

if ($in{'action'} eq 'add_user' || $in{'action'} eq 'activate_user' ) {
	%menu_left = 	(
				"1About Us"			=> "$WWW_Scripts/index.pl?lp=home&cp=aboutus",
				"2FAQ"				=> "$WWW_Scripts/index.pl?lp=home&cp=faq",
				"3Strategy Guide"	=> "/Strategy/ssh.htm",
				"4Downloads"		=> "$WWW_Scripts/index.pl?lp=home&cp=downloads",
				"3Order of Events"	=> "$WWW_Scripts/index.pl?lp=home&cp=orderofevents",
				"3Game Defaults"	=> "$WWW_Scripts/index.pl?lp=home&cp=gamedefaults",
				"5Other Sites"	=> "$WWW_Scripts/index.pl?lp=home&cp=othersites",
				"3Game Policies"	=> "$WWW_Scripts/index.pl?lp=home&cp=policies",
 				"9Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
 				"9Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create"
				);
} else {
# %menu_left = 	(
#  				"1Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
#  				"2Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create",
#  				"3Reset Password" 	=> "$WWW_Scripts/index.pl?cp=reset_user",
#  				"4Logout" 			=> "$WWW_Scripts/index.pl?cp=logout",
#  				);
# # 				"5Erase" 			=> "$WWW_Scripts/index.pl?cp=logoutfull"
%menu_left = 	(
 				"1Log In" 			=> "$WWW_Scripts/index.pl?cp=login_page",
 				"2Sign Up" 			=> "$WWW_Scripts/index.pl?cp=create",
 				"4Logout" 			=> "$WWW_Scripts/index.pl?cp=logout",
 				);
# 				"5Erase" 			=> "$WWW_Scripts/index.pl?cp=logoutfull"
}

&html_left(\%menu_left);

# cp
print '<td>';
if ($in{'action'} eq 'add_user') { &add_user; 
#} elsif ($in{'action'} eq 'create_user') { &create_user; 
} elsif ($in{'action'} eq 'activate_user') { &activate_user; 
} elsif ($in{'action'} eq 'reset_user') { &reset_user; 
} elsif ($in{'action'} eq 'reset_password') { &reset_password; 
} elsif ($in{'action'} eq 'reset_password2') { &reset_password2; 
} elsif ($in{'action'} eq 'change_password') { &change_password; 
} elsif ($in{'action'} eq 'login_fail') { 
    print "<P>Login failed! (The User Name is case-sensitive, and the account must be activated.)"; 
    print qq|<P>Do you need to <a href=/scripts/index.pl?cp=reset_user>Reset your password</a>?|;
} elsif ($in{'action'} eq '') { print "No action specified\n"; 
} else { print "error with action: $in{'action'}\n"; }
print '</td>';

# RP
print qq|<td width="$rp_width"></td>\n|;

########################################

sub add_user {
	my $User_First = $in{'User_First'};
	my $User_Last = $in{'User_Last'};
	my $User_Login = $in{'User_Login'};
	my $User_Email = $in{'User_Email'};
  my $valid_email = Email::Valid->address($User_Email);
	my $pass_temp = $in{'pass_temp'};
	my $User_Password = $in{'User_Password'};
  
  # Check to see that fields were filled out
  if ($User_First && $User_Last && $User_Login && $User_Email && $valid_email && $pass_temp && (length($pass_temp) > $min_pass_length)) {
  
  	my $db = &DB_Open($dsn);
  	my $Date =&GetTimeString();
  	my $hash = $in{'User_Password'} . $secret_key;
  	my $passhash = sha1_hex($hash); 
  	my $sql = qq|INSERT INTO User (`User_Login`, `User_Last`, `User_First`, `User_Password`, `User_Email`, `User_Status`, `User_Creation`, `User_Modified`, `EmailTurn`, `EmailList`) VALUES ('$User_Login','$User_Last','$User_First','$passhash', '$User_Email', -5,'$Date','$Date', 1, 1);|;
  	if (my $sth = &DB_Call($db,$sql)) { 
      print "<P>Done!  Check your email to activate your account. \n";
      $sth->finish();
    }
  	else { 
      print '<P>Error creating account. Duplicate User ID?'; 
      &LogOut(10,"ERROR: Adding New User $in{'User_Login'} $in{'User_Email'}",$ErrorLog);
    }
  	# add an entry in the temp file to expect the account to be activated
  	&DB_Close($db);
  	# email user to activate the account
  	# Hash password before sending it back out
  	$hash = $passhash . $secret_key;
  	$tmphash = sha1_hex($hash); 
  	
  	$Subject = $mail_prefix . 'Account Creation';
  	$Message = "\n\nA request was submitted to create an account $User_Login.\n";
  	$Message .= "To activate your account, select the link below:\n";
  	$Message .= $WWW_HomePage . $WWW_Scripts . '/account.pl?action=activate_user&user=' . $in{'User_Login'} . '&new=' . $tmphash;
  	$smtp = &Mail_Open;
  	&Mail_Send($smtp, $in{'User_Email'}, $mail_from, $Subject, $Message); # email user
  	&Mail_Send($smtp, $mail_from, $mail_from, $Subject, $Message); # notify site host
  	&Mail_Close($smtp);
  	&LogOut(100,"Add Mail sent to $in{'User_Email'}",$LogFile);
  
  } else {
    # tell the user they screwed up
    print "<P>Sorry, but there was a problem with your submission:\n";
    print "<ul>\n";
    unless ($User_First) { print "<li>First Name is a required field.</li>\n"; }
    unless ($User_Last)  { print "<li>Last Name is a required field.</li>\n"; }
    unless ($User_Login) { print "<li>User ID is a required field.</li>\n"; }
    unless ($User_Email) { print "<li>Email Address is a required field.</li>\n";}
    unless ($pass_temp && (length($pass_temp) > $min_password_length))  { print "<li>Password is a required field and at least $min_password_length characters.</li>\n";}
    if ($User_Email && !$valid_email) { print "<li>The email address you entered ( $User_Email ) does not detect as valid.</li>\n";  }
    print "</ul>\n";
    print "<P>Please try again!\n";
    &LogOut(100,"Account: User1: $User_First, User2: $User_Last, Login: $User_Login, Email: $User_Email, Pass: $pass_temp",$ErrorLog);
  }
}

sub activate_user {
  my $id;
  my ($User_ID, $User_Login, $User_Password, $User_Email);
  $submit_hash = $in{'new'};
  $submit_user = $in{'user'};
  $db = &DB_Open($dsn);
  # 240923
  #$sql = "SELECT User.User_ID, User.User_Login, User.User_Password, User.User_Email FROM User;";
  # Can only activate users that aren't active
  $sql = "SELECT User.User_ID, User.User_Login, User.User_Password, User.User_Email FROM User WHERE User_Status=-5;";
  if (my $sth = &DB_Call($db, $sql)) {
    while (my @row = $sth->fetchrow_array()) {
    	($User_ID, $User_Login, $User_Password, $User_Email) = @row;
       
    	# Hashing password with secret key
    	my $hash = $User_Password . $secret_key;
    	my $passhash = sha1_hex($hash);
    	&LogOut(200, "Attempting a match on A: $User_Login 2: $User_Password 3: $passhash 4: $submit_hash", $LogFile);
        
    	if ($passhash eq $submit_hash && $submit_user eq $User_Login) {
        $id = $User_ID;
       	&LogOut(200, "Activate user match success on $User_Login $id $User_ID", $LogFile);
      # Stop looping if a match is found
      } else { &LogOut(200, "Activate user match failed on $User_Login $id $User_ID", $LogFile); }
      if ($id) { last; }  # no need to keep going if there's a hit
    }
  }
	
  if ($id ne '') {
    my $cgi = new CGI;
    my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
    $sessionid = $session->id unless $sessionid;
    $session->param("logged-in", 1);
    $session->param("userid", $User_ID);
    $session->param("userlogin", $User_Login);
    $session->param("email", $User_Email);
    $session->param("timezone", $User_Timezone);
    &LogOut(100,"Account Activated for $User_Login",$LogFile);
    # Get the serial number for this user
    # which will be the serial number of the line of the corresponding User ID. 
    # We lose some this way, but we have 7 million so I think it will be ok. 
    my $user_serial;
    if (-f $File_Serials) { # If the serial file exists
      open (IN_FILE,$File_Serials) || &LogOut(0,"Can\'t open Serials File $File_Serials",$ErrorLog);
      chomp(my @serials = <IN_FILE>);
		  close(IN_FILE);
      my $id_update = $User_ID + 1; 
      $user_serial = $serials[$id_update]; # to match line number of serial file
    } else { $user_serial="ERROR"; &LogOut(0,"Missing Serials File $File_Serials",$ErrorLog);}
    $Date =&GetTimeString();
    $userfile = substr(sha1_hex(time()), 5, 8); 
    $sql = "UPDATE User SET User_Status=1, User_Modified='$Date', User_File='$userfile', User_Serial='$user_serial', CreateGame=1 WHERE User_ID=$id;";
    my $sth = &DB_Call($db,$sql);
    $sth->finish();
    $redirect = $WWW_Scripts . '/page.pl';
    # handy function - don't lose. 
    #	&print_redirect($cgi,$sessionid,$redirect);
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
  # updated to only be active accounts
	$sql = "SELECT User_Login, User_ID, User_Email FROM User WHERE User_Status > 0;";
	# Check to be sure the account exists
  if (my $sth = &DB_Call($db, $sql)) {
    while (my @row = $sth->fetchrow_array()) {
        ($User_Login, $User_ID, $User_Email) = @row;
        if ($User_Login eq $in{'User_Login'} && lc($User_Email) eq lc($in{'User_Email'})) {
            $id = $User_ID;
        }
        if ($id) { last; }
    }
    $sth->finish();
  }
  if ($id) { 
  	# Create new temporary password
  	$temp = $id . $secretkey;
  	$new_password = sha1_hex($temp);
  	$Date =&GetTimeString();
  	# add new temporary password to database
  	$sql = "UPDATE User SET User_Password='$new_password', User_Status=2, User_Modified='$Date' WHERE User_ID=$id;";
  	my $sth = &DB_Call($db,$sql);
    $sth->finish();
  	# Email new temporary password
  	$Subject = $mail_prefix . 'Password Reset Request';
  	$Message = "\n\nA request was submitted to reset your password for User ID: $in{'User_Login'}.\n";
  	$Message .= "To reset your password, select the link below:\n";
  	$Message .= "$WWW_HomePage$WWW_Scripts" . '/account.pl?action=reset_password&new=' . $new_password . '&user=' . $in{'User_Login'};
  	print "Sending email with a link to reset the password\n";
  	$smtp = &Mail_Open;
  	&Mail_Send($smtp, $User_Email, $mail_from, $Subject, $Message);
  	&Mail_Close($smtp);
  	&LogOut(100,"Password Reset sent to $User_Email",$LogFile);
  	# set account to require a reset
  } else { print "$in{'User_Login'} does not exist or is not activated.\n"; 	&LogOut(100,"ERROR: $in{'User_Login'} does not exist or is not activated",$ErrorLog);  }
  &DB_Close($db);
}

sub reset_password {
	# need to not be able to get here without being logged in. 
  # Except that reset_user redirects to here after resetting a lost password
	$submit_hash = $in{'new'};
	$submit_user = $in{'user'};
	$db = &DB_Open($dsn);
	$sql = "SELECT User.User_Login, User.User_ID, User.User_Password, User.User_Email FROM User;";
	if (my $sth = &DB_Call($db, $sql)) {
    while (my @row = $sth->fetchrow_array()) {
      ($User_Login, $User_ID, $User_Password, $User_Email) = @row;

      # Create the new password hash
      $temp = $User_ID . $secretkey;
      $new_password = sha1_hex($temp);

      # Check if the user login and password match
      if ($User_Login eq $in{'user'} && $User_Password eq $new_password) {
        $id = $User_ID;
      }
      if ($id) { last; }  # Exit the loop if a match is found
    }
    $sth->finish();
  }
	&DB_Close($db);
	if ($id) {
print <<eof;
<td>
<form name="login" method=POST action="$WWW_Scripts/account.pl" onsubmit="document.getElementById('User_Password').value = hex_sha1(document.getElementById('pass_temp').value)">
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
	$sql = "SELECT User_Login, User_Password, User_ID, User_Email FROM User;";
	if (my $sth = &DB_Call($db, $sql)) {
    while (my @row = $sth->fetchrow_array()) {
        ($User_Login, $User_Password, $User_ID, $User_Email) = @row;
        # Check if the user login and old password match
        if ($User_Login eq $in{'User_Login'} && $User_Password eq $in{'Old_Password'}) {
            $id = $User_ID;
        }
        if ($id) { last; }  # Exit the loop if a match is found
    }
    $sth->finish();
  }

	if ($id) {
		$new_password = $in{'User_Password'};
		$hash = $new_password . $secret_key;
		$userhash = sha1_hex($hash); 
		$Date = &GetTimeString();
		$sql = "UPDATE User SET User_Password='$userhash', User_Status=1, User_Modified='$Date' WHERE User_ID=$id;";
		my $sth = &DB_Call($db,$sql);
    $sth->finish(); 
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
	my $sth = &DB_Call($db,$sql);
  $sth->finish();
	print "Password changed for $userid\n";
  &DB_Close($db);
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
  #240923
  # Can only log in fron an active account
  #$sql = "SELECT * FROM User;";
  $db = &DB_Open($dsn);
  $sql = "SELECT User_ID, User_Login, User_Password, User_Email, User_Timezone FROM User WHERE User_Status > 0;";
  if (my $sth = &DB_Call($db, $sql)) {
  	while (my @row = $sth->fetchrow_array()) {
  	  ($User_ID, $User_Login, $User_Password, $User_Email, $User_Timezone) = @row;
      # Hashing the submitted password with the secret key
      $hash = $submit_hash . $secret_key;
      $passhash = sha1_hex($hash);
      &LogOut(300, "Attempting a match on B: $User_Login 2: $User_Password 3: $passhash 4: $submit_hash 5: $passhash", $LogFile);
      # Check for a match
      if ($User_Password eq $passhash && $submit_user eq $User_Login) {
        $id = $User_ID;
        &LogOut(200, "Login user match success on $User_Login", $LogFile);
      } else {
        &LogOut(400, "Login user match failed on $User_Login", $LogFile);
      }
      if ($id) { last; }  # Exit the loop if a match is found
    }
    $sth->finish();
  }

  &DB_Close($db);	
  if ($id) {
    &LogOut(100,"$submit_user Logged In",$LogFile);
      my $cgi = new CGI;
      my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
      $sessionid = $session->id unless $sessionid;
      $session->param("logged-in", 1);
      $session->param("userid", $User_ID);
      $session->param("userlogin", $User_Login);
      $session->param("email", $User_Email);
      $session->param("timezone", $User_Timezone);
#			$redirect =$WWW_Scripts . '/page.pl';
#			$redirect = $WWW_HomePage . $WWW_Scripts . '/index.pl?lp=home';
			$redirect = $WWW_Scripts . '/page.pl?lp=profile_game&cp=show_first_game';
			&print_redirect($cgi,$sessionid,$redirect);
  } else {
    &LogOut(100,"$submit_user failed to Log In",$LogFile);
    my $cgi = new CGI;
#			my $session = new CGI::Session("driver:File", $cgi, {Directory=>"$Dir_Sessions"});
#			$sessionid = $session->id unless $sessionid;
#			$session->param("logged-in", 1);
#			$session->param("userid", $User_ID);
#			$session->param("userlogin", $User_Login);
#			$session->param("email", $User_Email);
    print $cgi->redirect( -URL => "$WWW_Scripts/account.pl?action=login_fail");
#			$redirect = $WWW_Scripts . '/index.pl';
#			&print_redirect($cgi,$sessionid,$redirect);
  }
#    }
}

sub logout { 
	my ($cgi, $session) = @_; # receive two args
    $session->clear(`"logged-in"`);
    $cookie = $cgi->cookie
       (-NAME	=>	'TotalHost', 
	    -VALUE	=>	"", 
        -PATH => '/',
	    -EXPIRES=>	"+3M",
	   );
    print $cgi->redirect( -URL => "$WWW_Scripts/index.pl", -cookie=> `$cookie`);
}

sub logoutfull { 
	my ($cgi, $session) = @_; # receive two args
    $session->clear(`"logged-in"`);
	$session->delete();
    $cookie = $cgi->cookie
       (-NAME	=>	'TotalHost', 
	    -VALUE	=>	"", 
        -PATH => '/',
	    -EXPIRES=>	"-1M",
	   );
    print $cgi->redirect( -URL => "$WWW_Scripts/index.pl", -cookie=> `$cookie`);
}
