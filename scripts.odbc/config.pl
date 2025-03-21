#!/usr/bin/perl
# Formerly a RallyPt File

$disableGenerate = 0; # Disable TurnMake

$debug=0;

$WWW_HomePage = 'http://beta.sinister.net:999';
$PerlLocation='c:/perl/bin/perl.exe'; # Local Path

# Logging
# The higher the value the more log values show
# 0 - Critical, log every time
# 100 - Warning, Core system functions. 
# 200 - Info. DB Calls
# 300 - overly detailed
# 400 - who cares really
$logging = 400; 

# Clean .m files before giving them to the player, removing non-player info (mines, MT, etc)
# Also requires a file named 'clean' in the individual game folder
$cleanFiles = 2; # 0, 1, 2: display, clean but don't write, write
# Fixing negates or warns for bug effects. 
# Also requires a file named 'fix' in the individual game folder
$fixFiles = 2; # 0, 1, 2: display, clean but don't write, write 

# Where the accounts logs go
$Dir_Log = 'd:/TH/logs';
$File_Log = '/th.log';
$LogFile = $Dir_Log . $File_Log;
$File_ErrorLog = '/Error.log';
$ErrorLog = $Dir_Log . $File_ErrorLog;
$file_SQLLog = '/sql.log';
$SQLLog = $Dir_Log . $file_SQLLog;

$ip = $ENV{'REMOTE_ADDR'};
$browser = $ENV{'HTTP_USER_AGENT'};

# User / Password Database as a flat file
$max_login_attempts = 6;
$max_users = 100;
$min_password_length = 6;

$max_inactivity = 14; # The longest a game can stay active, in days, with no turn submissions
$max_forcegen = 50; # The maximum number of turns that can be force generated. 

#Database
# ODBC (default)
$dsn = 'TotalHost';
# MYSQL/MariaDB
#$DB_NAME = 'totalhost';
#$DB_USER = 'totalhostdb';
#$DB_PASSWORD = '86poYcuCDcIsehW6apCt';
#$DB_HOST = 'localhost';
#$dsn = "DBI:mysql:database=$DB_NAME;host=$DB_HOST";


$executable= 'd:/th/stars!/stars26j/stars.exe';   
# Location of ImageMagic convert applications
$imagemagick = 'C:\Program Files\ImageMagick-6.8.3-Q16\convert';
# Location of the starmapper executable (Java)
$starmapper = 'd:\th\utils\starmapper\starmapper121\starmapper.bat';

$FormMethod = 'Post'; # Method used for forms, Post or Get
$Dir_Root = 'd:/TH';
$DirRoot = 'd:\TH';
$Dir_Upload    = $Dir_Root . '/Uploads';
$DirUpload     = $DirRoot . '\Uploads';
$DirRaces      = $DirRoot . '\Races';
$Dir_Games     = $Dir_Root .'/Games'; # Location of the actual game files used for turn gen
$DirGames      = $DirRoot . '\Games'; # Location of the actual game files used for turn gen
$Dir_Download  = $Dir_Root . '/Download'; #Location where zip files are downloaded
$DirDownload   = $DirRoot . '\Download'; #Location where zip files are downloaded
$DirGraphs     = $DirRoot . '\Downloads'; #Location of movies & Graphs
$File_Serials  = $Dir_Root .'/serials.txt'; # Text file of serial numbers
$Dir_WWWRoot   = $Dir_Root . '/html';
$Dir_Scripts   = $Dir_Root . '/scripts';
$DirScripts    = $DirRoot . '\scripts';
 
$WWW_Image = '/images/';
$WWW_Notes = '/Notes/';
$WWW_Scripts = '/scripts';
$Location_Index = $WWW_HomePage . $WWW_Scripts . '/index.pl';
# Email
$mail_present = 1;
$mail_server = 'glutton.home.sinister.net';
#$mail_user = 'ricks@nc.rr.com';
#$mail_password = '';
$mail_from = 'th@corwyn.net';
$mail_prefix = '[TH] ';

#Internet Detection
$internet_status_log = $Dir_Log  . '/internet_status.log';
$internet_threshold  = 5;
$internet_site       = 'google.com'; 

$min_players = 1; # The minimum number of players to create/launch a game
# Sessions
$Dir_Sessions = $Dir_Root . '/sessions/';
# Note if you change this all the current passwords will invalidate. 
$secret_key = 'secret_key_for_md5_hashing';
%TurnResult = ("turned in" => "In", "still out" => "Out", "right game" => "Wrong Game", "dead" => "Deceased", "right year" => "Wrong Year", "file corrupt" => "Corrupt");
%TurnBall = ("In" => "$WWW_Image"  . "greenball.gif", "Out" => "$WWW_Image"  . "yellowball.gif", "Wrong Game" => "$WWW_Image"  . "redball.gif", "Deceased" => "$WWW_Image"  . "blackball.gif", "Wrong Year" => "$WWW_Image"  . "redball.gif", "Corrupt" => "$WWW_Image"  . "redball.gif", "Error" => "$WWW_Image"  . "redball.gif", "Idle" => "$WWW_Image"  . "grayball.gif", "Abandoned" => "$WWW_Image"  . "grayball.gif");
%StatusBall = ("Finished" => "$WWW_Image"  . "blackball.gif", "Awaiting Players" => "$WWW_Image"  . "yellowball.gif", "In Progress" => "$WWW_Image"  . "greenball.gif", "Delayed" => "$WWW_Image"  . "blueball.gif", "Active" => "$WWW_Image"  . "greenball.gif", "Idle" => "$WWW_Image"  . "greyball.gif", "Creation in Progress" => "$WWW_Image"  . "yellowball.gif", "Pending Start" => "$WWW_Image"  . "yellowball.gif", "Paused" => "$WWW_Image"  . "yellowball.gif");
@WeekDays = qw(Sun. Mon. Tues. Wed. Thurs. Fri. Sat.);
@GameStatus = ('Pending Start', 'Pending Closed', 'Active','Delayed','Paused','Need Replacement','Creation in Progress','Awaiting Players','','Finished');
@HourlyTime = qw(.167 .25 .5 1 2 3 4 6 8 12 24 36 42 48 56 72 84 96 120 144 168 240 336);
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

my (@singularRaceName, @pluralRaceName);
$singularRaceName[0] = 'Everyone';
