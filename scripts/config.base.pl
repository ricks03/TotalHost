#!/usr/bin/perl

$debug=0;
$WWW_HomePage = 'http://totahost.domain.com:999';
# Local Path
$PerlLocation='c:/perl/bin/perl.exe';

# Logging
# The higher the value the more log values show
# 0 - Critical, log every time
# 100 - Warning, Core system functions
# 200 - Info
# 300 - overly detailed
# 400 - who cares really
$logging = 300; 

# Where the accounts logs go
$path_Log = 'C:/TH/logs';
$file_Log = '/th.log';
$LogFile = $path_Log . $file_Log;
$file_ErrorLog = '/Error.log';
$ErrorLog = $path_Log . $file_ErrorLog;
$file_SQLLog = '/sql.log';
$SQLLog = $path_Log . $file_SQLLog;

$ip = $ENV{'REMOTE_ADDR'};
$browser = $ENV{'HTTP_USER_AGENT'};

# User / Password Database as a flat file
$max_login_attempts = 6;
$max_users = 40;

$max_inactivity = 14; # The longest a game can stay active, in days, with no turn submissions
$max_forcegen = 50; # The maxumum number of turns that can be force generated. 

$dsn = 'TotalHost';
$executable= 'c:/TH/stars!/stars26j/';
$FormMethod = 'Post'; # Method used for forms, Post or Get
$File_Upload = 'c:/TH/Uploads';
$File_UploadRace = 'c:/TH/Uploads';
$File_UploadGame = 'c:/TH/Uploads';
$File_Races = 'c:/TH/Races';
$FileRaces = 'c:\TH\Races';
$File_HST = 'c:/TH/Games'; # Location of the actual game files used for turn gen
$FileHST = 'c:\TH\Games'; # Location of the actual game files used for turn gen
$File_Download = 'c:/TH/Download'; #Location where turns & .xy are downloaded
$FileDownload = 'c:\TH\Download'; #Location where turns & .xy are downloaded
$File_WWWRoot = 'c:/TH/html';
$WWW_Image = '/images/';
$WWW_Notes = '/Notes/';
$Location_Scripts = '/scripts';
$Location_Index = $WWW_HomePage . $Location_Scripts . '/index.pl';
# Email
$mail_present = 1;
$mail_server = 'smtp.domain.com';
#$mail_password = '';
$mail_from = 'th@domain.com';
$mail_prefix = '[TH]: ';

$min_players = 2; # The minimum number of players to create/launch a game
# Sessions
$session_dir = 'c:/th/sessions/';
# Note if you change this all the current passwords will invalidate. 
$secret_key = 'secret_key_for_md5_hashing';
%TurnResult = ("turned in" => "In", "still out" => "Out", "right game" => "Wrong Game", "dead" => "Deceased", "right year" => "Wrong Year", "file corrupt" => "Corrupt");
%TurnBall = ("In" => "$WWW_Image"  . "greenball.gif", "Out" => "$WWW_Image"  . "yellowball.gif", "Wrong Game" => "$WWW_Image"  . "redball.gif", "Deceased" => "$WWW_Image"  . "blackball.gif", "Wrong Year" => "$WWW_Image"  . "redball.gif", "Corrupt" => "$WWW_Image"  . "redball.gif", "Inactive" => "$WWW_Image"  . "grayball.gif", "Abandoned" => "$WWW_Image"  . "grayball.gif");
%StatusBall = ("Finished" => "$WWW_Image"  . "blackball.gif", "Awaiting Players" => "$WWW_Image"  . "yellowball.gif", "In Progress" => "$WWW_Image"  . "greenball.gif", "Delayed" => "$WWW_Image"  . "blueball.gif", "Active" => "$WWW_Image"  . "greenball.gif", "Inactive" => "$WWW_Image"  . "greyball.gif", "Creation in Progress" => "$WWW_Image"  . "yellowball.gif", "Pending Start" => "$WWW_Image"  . "yellowball.gif", "Paused" => "$WWW_Image"  . "yellowball.gif");
@WeekDays = qw(Sun. Mon. Tues. Wed. Thurs. Fri. Sat.);
@GameStatus = ('Pending Start', 'Pending Closed', 'Active','Delayed','Paused','Need Replacement','Creation in Progress','Awaiting Players','','Finished');
@HourlyTime = qw(.5 1 2 3 4 6 8 12 24 36 42 48 56 72 84 96 120 144 168 240 336);
# Defaults for new games
$default_daily = '0101010'; # Defaults for new daily games
$default_hourly = '000000001111111111111100'; # defaults for new hourly games
$default_numdelay = 2; 
$default_mindelay = 5; 

# Starstat data
@dt_verbose = ('Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File');
@dt = qw(XY Log Host Turn Hist Race Max);
@fDone = ('Turn Saved','Turn Saved/Submitted');
@fMulti = ('Single Turn', 'Multiple Turns');
@fGameOver = ('Game In Progress', 'Game Over'); 
@fShareware = ('Registered','Shareware'); 
@fInUse = ('Host instance not using file','Host instance using file'); # No idea what this value is.
# Permit displaying checkboxes or not depending on variable
@Checked = ('','CHECKED');
@Checked_Display = ('Disabled', 'Enabled');
@Selected = ('', 'SELECTED');
$lp_width=125;
$rp_width=200;
$height_help = 300;
$height_news = 500;
$width_news = 300;

# Add all the Host and game related buttons
$host_style = qq|style="color:red;width:120px;height:24;"|;
$user_style = qq|style="width:120px;height:24;"|;
