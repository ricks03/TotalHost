# Stars Movie Creator
# For Starmap
# 120611
# Rick Steeves
# th@corwyn.net
# version .01

# Creates all of the .map and .pla files to generate "movies" from starmap (or XtremeBorders)
# And then creates batch files to create the starmap .pcx files, 
# convert the .pcx files to .jpg with ImageMagick, and then display the .jpg files
# with polyview

# Note starmap doesn't appear to work on modern machines without applying the fix 
# from http://www.pcmicro.com/elebbs/faq/rte200.html

# Assumes that the stars turn files are available in some structure 
# (currently <whatever>\<year>)
# tho modifying that within the code is fairly simple.

# Builds a number of batch files to be run in order:
# starmap_<gamefile>.bat - to run starmap for each year and create the .pcx file
# image_<gamefile>.bat  - to use imagemagick to convert the .pcx files to .jpg

# It also creates a <gamefile>.pvs file to use with polyview. Copy of polyview required, 
# available at http://www.polybytes.com/


# Name of the Game (the prefix for the .xy file)
$GameFile = "dark";  

# Stars EXE
$executable= "E:\\Stars!\\stars26j\\stars.exe";

# Location of ImageMagic convert applications
$image = "E:\\Program Files\\ImageMagick-6.4.1-Q16\\convert";

# Path of the game backups
# Assumes a structure of <path>\<turn year>
$path = "W:\\Games\\$GameFile";

# Location of the starmap executable
$starmap = "d:\\stars\\utils\\starmap\\starmap2\\starmap.exe";

# Where to output the .ini, .pcx, and .bat files
$outputpath = "c:\\temp\\";

# Determine the players to provide output
@numbers = (1,2,3,4);
@passwords = ('','','','quack');
@names = ('Eladrin','Posleen','Kobold','Mallard');

# Get a listing of all of the backup directories
$BackupDir = $path;
opendir(DIRS, $BackupDir) || die("Cannot open $BackupDir\n"); 
@AllDirs = readdir(DIRS);
closedir(DIRS);

# Create the Starmap, Polyview, and Image command file
$DataOutFile = $outputpath . "starmap_" . $GameFile . ".bat";
open (MAPFILE, ">$DataOutFile");
$DataOutFile = $outputpath . "image_" . $GameFile . ".bat";
open (IMGFILE, ">$DataOutFile");
$DataOutFile = $outputpath . $GameFile . ".pvs";
open (POLYFILE, ">$DataOutFile");

foreach $name (@AllDirs) {
	if ($name =~ /\./) {  next; }
	if ($name =~ /BACKUP/) {  next; }

	print MAPFILE $starmap . " -I " . $outputpath . "$name.ini\n";
	print IMGFILE "\"" . $image . "\"" . " $outputpath$name.PCX $outputpath$name.jpg\n";
	print POLYFILE "\"$name.jpg\" /t1\n";
}
close MAPFILE;
close IMGFILE;
close POLYFILE;

# Generate all the .map files
#   Stars! -dm mygame.m1    <-- Dump the universe definition and exit
# Generate all of the .pla files
#   Stars! -dp mygame.m1    <-- Dump player 1's planets and exit

foreach $name (@AllDirs) {
	if ($name =~ /\./) {  next; }
	if ($name =~ /BACKUP/) {  next; }

	# generate the MAP file
	$map = $executable;
	if ($passwords[$count]) { $map .= ' -p ' . $passwords[$count]; }
	$map .= ' -dm ' . $path . "\\" . $name . "\\" . $GameFile . ".m" . $numbers[0];
	print "map: $map\n";
	system ($map);

	# Generate the PLA files
	$count = 0;
	foreach $number (@numbers) {
		$pla = $executable;
		if ($passwords[$count]) { $pla .= ' -p ' . $passwords[$count]; }
		$pla .= ' -dp ' . $path . "\\" . $name . "\\" . $GameFile . ".m" . $number;
		print "pla: $pla\n";
		system ($pla);
		$count++;
		# Wait patiently, stars doesn't like to be launched over and over.
		sleep 1;
	}

	# Generate the starmap2 ini files
	$DataOutFile = $outputpath . "\\" . $name . ".ini";
	open (INIFILE, ">$DataOutFile");
	print INIFILE "[FILES]\n";
	print INIFILE "Map " . $path . "\\" . $name . "\\" . $GameFile . ".map\n";
	foreach $number (@numbers) {
		print INIFILE "Pla " . $path . "\\" . $name . "\\" . $GameFile . ".P" . $number . "\n";
	}
	print INIFILE "Gfx " . $outputpath . $name . ".PCX\n";

	# Print names to try to get the colors to stay consistent
# 	$ctr = 1;
# 	print INIFILE "\n";
# 	print INIFILE "[NAMES]\n";
# 	foreach $name (@names) {
# 		print INIFILE "$ctr \"$name\"\n";
# 		$ctr++;
# 	}

	# Print color selection
	print INIFILE "\n";
	print INIFILE "[COLORS]\n";
	foreach $number (@numbers) {
		$color = $number * 4;
		print INIFILE $number . " " . $color . "\n";
	}
	
	close INIFILE;

}
