use CGI qw(:standard);
use CGI::Session;
CGI::Session->name('TotalHost');
$CGI::POST_MAX=1024 * 25;  # max 25K posts
use Win32::ODBC;
use TotalHost;
use StarStat; 
do 'config.pl';


&decryptClean;
&StarsClean;
&show_race_block("IFE.R1","rsteeves");