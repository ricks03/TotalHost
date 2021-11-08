#!/usr/bin/perl
# TurnMake.pl
# Master Turn Generation Program for TotalHost
# Rick Steeves th@corwyn.net
# 120808, 121016

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

use Win32::ODBC;
require 'cgi-lib.pl';
use CGI qw(:standard);
use Net::SMTP;
use TotalHost;
use StarStat;
use StarsBlock;
do 'config.pl';

my %hullType; 
$hullType{'0'} = [ 15,1,"Small Freighter",0,0,0,0,0,0,0,25,20,12,0,17,0,70,130,25,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,85,51,49,55,53,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'1'} = [ 15,2,"Medium Freighter",1,0,0,0,3,0,0,60,40,20,0,19,4,210,450,50,1,1,6146,1,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,86,50,48,56,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'2'} = [ 15,3,"Large Freighter",2,0,0,0,8,0,0,125,100,35,0,21,8,1200,2600,150,1,2,6146,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,4,102,34,48,38,70,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'3'} = [ 15,4,"Super Freighter",3,0,0,0,13,0,0,175,125,45,0,21,12,3000,8000,400,1,3,6146,3,12,5,2048,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,136,34,64,40,72,104,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'4'} = [ 15,5,"Scout",4,0,0,0,0,0,0,8,10,4,2,4,16,0,50,20,1,1,2,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,65,8,255,255,50,54,52,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'5'} = [ 15,6,"Frigate",5,0,0,0,6,0,0,8,12,4,2,4,20,0,125,45,1,1,2,2,6462,3,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,68,8,255,255,49,55,53,51,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'6'} = [ 15,7,"Destroyer",6,0,0,0,3,0,0,30,35,15,3,5,24,0,280,200,1,1,48,1,48,1,6462,1,8,2,4096,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,67,8,255,255,66,21,117,70,68,35,99,0,0,0,0,0,0,0,0,0 ];
$hullType{'7'} = [ 15,8,"Cruiser",7,0,0,0,9,0,0,90,85,40,5,8,28,0,600,700,1,2,6148,1,6148,1,48,2,48,2,6462,2,12,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
$hullType{'8'} = [ 15,9,"Battle Cruiser",8,0,0,0,10,0,0,120,120,55,8,12,32,0,1400,1000,1,2,6148,2,6148,2,48,3,48,3,6462,3,12,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,133,12,255,255,49,35,67,21,85,55,53,0,0,0,0,0,0,0,0,0 ];
$hullType{'9'} = [ 15,10,"Battleship",9,0,0,0,13,0,0,222,225,120,25,20,36,0,2800,2000,1,4,6146,1,4,8,48,6,48,6,48,2,48,2,48,4,8,6,2048,3,2048,3,0,0,0,0,0,0,0,0,0,0,11,138,12,255,255,48,56,38,20,84,2,98,70,52,34,66,0,0,0,0,0 ];
$hullType{'10'} = [ 15,11,"Dreadnought",10,0,0,0,16,0,0,250,275,140,30,25,40,0,4500,4500,1,5,12,4,12,4,48,6,48,6,2048,4,2048,4,48,8,48,8,8,8,52,5,52,5,6462,2,0,0,0,0,0,0,13,138,12,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
$hullType{'11'} = [ 15,12,"Privateer",11,0,0,0,4,0,0,65,50,50,3,2,44,250,650,150,1,1,12,2,6146,1,6462,1,6462,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,67,16,103,67,65,55,87,37,101,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'12'} = [ 15,13,"Rogue",12,0,0,0,8,0,0,75,60,80,5,5,48,500,2250,450,1,2,12,3,6400,2,2,1,6462,2,6462,2,6400,2,2048,1,2048,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,132,16,118,51,65,70,102,72,20,116,38,18,114,0,0,0,0,0,0,0 ];
$hullType{'13'} = [ 15,14,"Galleon",13,0,0,0,11,0,0,125,105,70,5,5,52,1000,2500,900,1,4,12,2,12,2,6462,3,6462,3,6400,2,6144,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,132,16,118,50,64,19,115,21,117,54,86,72,0,0,0,0,0,0,0,0 ];
$hullType{'14'} = [ 15,15,"Mini-Colony Ship",14,0,0,0,0,0,0,8,3,2,0,2,56,10,150,10,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'15'} = [ 15,16,"Colony Ship",15,0,0,0,0,0,0,20,20,10,0,15,60,25,200,20,1,1,4096,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,86,52,50,54,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'16'} = [ 15,17,"Mini Bomber",16,0,0,0,1,0,0,28,35,20,5,10,64,0,120,50,1,1,64,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,192,20,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'17'} = [ 15,18,"B-17 Bomber",17,0,0,0,6,0,0,69,150,55,10,10,68,0,400,175,1,2,64,4,64,4,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,192,20,255,255,49,51,53,55,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'18'} = [ 15,19,"Stealth Bomber",18,0,0,0,8,0,0,70,175,55,10,15,72,0,750,225,1,2,64,4,64,4,6146,1,2048,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,192,20,255,255,50,36,68,38,70,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'19'} = [ 15,20,"B-52 Bomber",19,0,0,0,15,0,0,110,280,90,15,10,76,0,750,450,1,3,64,4,64,4,64,4,64,4,6146,2,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,192,20,255,255,49,19,83,37,69,55,51,0,0,0,0,0,0,0,0,0 ];
$hullType{'20'} = [ 15,21,"Midget Miner",20,0,0,0,0,0,0,10,20,10,0,3,80,0,210,100,1,1,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,24,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'21'} = [ 15,22,"Mini-Miner",21,0,0,0,2,0,0,80,50,25,0,6,84,0,210,130,1,1,6146,1,128,1,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,24,255,255,50,54,36,68,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'22'} = [ 15,23,"Miner",22,0,0,0,6,0,0,110,110,32,0,6,88,0,500,475,1,2,6154,2,128,2,128,1,128,2,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'23'} = [ 15,24,"Maxi-Miner",23,0,0,0,11,0,0,110,140,32,0,6,92,0,850,1400,1,3,6154,2,128,4,128,1,128,4,128,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'24'} = [ 15,25,"Ultra-Miner",24,0,0,0,14,0,0,100,130,30,0,6,96,0,1300,1500,1,2,6154,3,128,4,128,2,128,4,128,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,24,255,255,49,55,35,37,67,69,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'25'} = [ 15,26,"Fuel Transport",25,0,0,0,4,0,0,12,50,10,0,5,100,0,750,5,1,1,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,28,255,255,51,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'26'} = [ 15,27,"Super-Fuel Xport",26,0,0,0,7,0,0,111,70,20,0,8,104,0,2250,12,1,2,4,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,28,255,255,50,52,54,0,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'27'} = [ 15,28,"Mini Mine Layer",27,0,0,0,0,0,0,10,20,8,2,5,108,0,400,60,1,1,256,2,256,2,6146,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,16,255,255,50,36,68,54,0,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'28'} = [ 15,29,"Super Mine Layer",28,0,0,0,15,0,0,30,30,20,3,9,112,0,2200,1200,1,3,256,8,256,8,12,3,6146,3,6400,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,0,16,255,255,49,35,67,53,39,71,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'29'} = [ 15,30,"Nubian",29,0,0,0,26,0,0,100,150,75,12,12,124,0,5000,5000,1,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,6462,3,0,0,0,0,0,0,13,130,16,255,255,64,32,96,18,114,50,82,36,100,68,54,86,72,0,0,0 ];
$hullType{'30'} = [ 15,31,"Mini Morph",30,0,0,0,8,0,0,70,100,30,8,8,120,150,400,250,1,2,6462,3,6462,1,6462,1,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
$hullType{'31'} = [ 15,32,"Meta Morph",31,0,0,0,10,0,0,85,120,50,12,12,116,300,700,500,1,3,6462,8,6462,2,6462,2,6462,1,6462,2,6462,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,130,16,102,36,48,50,38,70,56,18,82,0,0,0,0,0,0,0,0,0 ];
$hullType{'32'} = [ 16,1,"Orbital Fort",32,0,0,0,0,0,0,0,80,24,0,34,128,0,0,100,2560,1,48,12,12,12,48,12,12,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,5,138,0,255,255,68,36,70,100,66,0,0,0,0,0,0,0,0,0,0,0 ];
$hullType{'33'} = [ 16,2,"Space Dock",33,0,0,0,4,0,0,0,200,40,10,50,132,200,0,250,2560,1,48,16,12,24,48,16,4,24,2048,2,2048,2,48,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,140,0,102,68,34,20,65,71,116,38,102,98,0,0,0,0,0,0,0,0 ];
$hullType{'34'} = [ 16,3,"Space Station",34,0,0,0,0,0,0,0,1200,240,160,500,136,-1,0,500,2560,1,48,16,4,16,48,16,12,16,4,16,2048,3,48,16,2048,3,48,16,2560,1,12,16,0,0,0,0,0,0,0,0,12,142,0,102,68,66,5,3,88,80,133,100,131,36,48,70,56,0,0,0,0 ];
$hullType{'35'} = [ 16,4,"Ultra Station",35,0,0,0,12,0,0,0,1200,240,160,600,140,-1,0,1000,2560,1,48,16,2048,3,48,16,4,20,4,20,2048,3,48,16,2048,3,48,16,2560,1,12,20,48,16,12,20,2048,3,48,16,16,144,0,102,68,36,80,66,88,98,38,70,3,131,56,100,102,48,34,5,133 ];
$hullType{'36'} = [ 16,5,"Death Star",36,0,0,0,17,0,0,0,1500,240,160,700,144,-1,0,1500,2560,1,48,32,2048,4,2048,4,4,30,4,30,2048,4,48,32,2048,4,48,32,2560,1,12,20,2048,4,12,20,2048,4,48,32,16,146,0,102,68,20,96,65,104,98,38,71,2,130,40,116,102,32,34,6,134 ];

#use strict;
#use warnings;
# Usable from the command line for a single game. Just give it the gamefile.
my $commandline = $ARGV[0];

# Get Time Information
($Second, $Minute, $Hour, $DayofMonth, $Month, $Year, $WeekDay, $WeekofMonth, $DayofYear, $IsDST, $CurrentDateSecs) = &GetTime; #So we have the time when we do the HTML
$CurrentEpoch = time();

# Open the database
$db = &DB_Open($dsn);

# Only load the holiday infromation once, so we can reuse it.
#@Holiday = &LoadHolidays($db); #Load the dates for the holidays

# If a single game is specified, process only that game
if ($commandline) {
  # Execute for a single GameFile
  $GameData = &LoadGamesInProgress($db,'SELECT * FROM Games WHERE ((GameFile=\'$GameFile\') AND (GameStatus=2 or GameStatus=3)) ORDER BY GameFile');
} else {
  # Check all Games
  $GameData = &LoadGamesInProgress($db,'SELECT * FROM Games WHERE GameStatus=2 or GameStatus = 3 ORDER BY GameFile');
}
my @GameData = @$GameData;
&CheckandUpdate;  
&DB_Close($db);

#####################################################################################

# Handy code reference for how variables work tho.
# sub Initialize { #Recreate all of the HTML pages for all of the games
# 	my $LoopPosition = 1;
# 	while ($LoopPosition <= $#GameData) { # For every game in progress
# 		print 'Initializing ' . $GameData[$LoopPosition]{'GameName'}. " Game\n";
# 		print "Values: Game Name: $GameData[$LoopPosition]{'GameName'}, Game File: $GameData[$LoopPosition]{'GameFile'}, Next Turn: $GameData[$LoopPosition]{'NextTurn'}, Status: $GameData[$LoopPosition]{'GameStatus'}\n";
# 		$LoopPosition++;
# 	}
# }

sub CheckandUpdate {
  # BUG: Doesn't this always skip the first game? ? ? 
	my $LoopPosition = 1; #Start with the first game in the array.
  print "Starting to check games\n";
  # This would be massively more clear if I read all of this in as a hash, instead
  # of an array. If I just moved $LoopPosition out, and instead performed this
  # as I walked thorugh the database. 
  # Heck, even if I read all the data in from the database, and then called this function one line/row
  # at a time. 
	while ($LoopPosition <= ($#GameData)) { # work the way through the array
		print 'Checking whether to generate for ' . $GameData[$LoopPosition]{'GameName'} . ":$GameData[$LoopPosition]{'GameFile'}...\n";
		my($TurnReady) = 'False'; #Is it time to generate
		my($NewTurn) = 0; #Localize the value for Next Turn. the next turn won't change unless told to
#		if ($GameData[$LoopPosition]{'ObserveHoliday'} ) { &CheckHolidays($GameData[$LoopPosition]{'NextTurn'}); }
		#check to see if you should be checking, and don't do anything at an invalid time. 
# 		if ((substr($GameData[$LoopPosition]{'DayFreq'},$WeekDay,1) == 0) && ($GameData[$LoopPosition]{'GameType'} == 1)) {
# 			print $WeekDay . " is not a good day\n"
# 		} elsif ((substr($GameData[$LoopPosition]{'HourFreq'},$Hour,1) == 0) && ($GameData[$LoopPosition]{'GameType'} == 2)) {
# 			print $WeekDay . " is not a good hour\n"
		#else {
		#	print $WeekDay . " is a good day\n";
		#}
    
    # Don't bother checking if the game is no longer active. BUG: Shouldn't this be filtered out by SQL?
		if (($GameData[$LoopPosition]{'GameStatus'} != 9) && (&inactive_game($GameData[$LoopPosition]{'GameFile'}))) {  
	  } elsif ($GameData[$LoopPosition]{'GameStatus'} == 2 || $GameData[$LoopPosition]{'GameStatus'} == 3) { # if it's an active game 		
	    #Game Type = Daily
			if ($GameData[$LoopPosition]{'GameType'} == 1 && $CurrentEpoch > $GameData[$LoopPosition]{'NextTurn'}) { # GameType: turn set to daily
				&LogOut(200,"\t$GameData[$LoopPosition]{'GameName'} is a daily game $CurrentEpoch  $GameData[$LoopPosition]{'NextTurn'}",$LogFile);	
				# Generate the next turn = midnight today +  days + hours (fixed)
				# Which makes the time stay constant
				($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$WeekDay);
				$NewTurn = $CurrentDateSecs + $DaysToAdd*86400 + ($GameData[$LoopPosition]{'DailyTime'} *60*60); 			
				# If the $newturn will be on an invalid day, add more days
				while (&ValidTurnTime($NewTurn,'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { 
					# Get the weekday of the new turn so we can see if it's ok
					my ($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST) = localtime($NewTurn);
					# Move to the next available day
					($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$CWeekDay);
					$NewTurn = $NewTurn + &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$CWeekDay);
					$NewTurn = $NewTurn + $DaysToAdd * 86400;
				}
				# and just to be sure, make sure today is ok to generate before we approve everything
        # BUG: Why are we checking to confirm it's a valid day? What if we miss the valid day?  ? ?  
#				if (&ValidTurnTime($CurrentEpoch, 'Day', $GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) eq 'True') { $TurnReady = 'True'; }
				$TurnReady = 'True';
				&LogOut(100,"#####New Turn : $NewTurn  TurnReady = $TurnReady",$LogFile);
				# If there are any delays set, then we need to clear them out, and reset the game status
				# since if we're generating with a turn missing we've clearly hit the window past the delays.
				if ($GameData[$LoopPosition]{'DelayCount'} > 0) {
					$sql = "UPDATE Games SET DelayCount = 0 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
					if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: Delay reset to 0 for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
					$sql = "UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
					if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: GameStatus reset to 2 for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
				}

	    #Game Type = Hourly
			} elsif ($GameData[$LoopPosition]{'GameType'} == 2 && $CurrentEpoch > $GameData[$LoopPosition]{'NextTurn'}) { # GameType: set time to generate hourly
				print "   " . $GameData[$LoopPosition]{'GameName'} . " is an hourly game\n";
				# Generate the next turn now + number of hours (sliding)
				$NewTurn = $CurrentEpoch + ($GameData[$LoopPosition]{'HourlyTime'} *60 *60); 
				# Make sure we're generating on a valid day
				while (&ValidTurnTime($NewTurn,'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + ($GameData[$LoopPosition]{'HourlyTime'} *60*60); }
				# Make sure we're generating on a valid hour
				while (&ValidTurnTime($NewTurn,'Hour',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + 3600; } 
				# and just to be sure, make sure today is ok to generate before we approve everything
				if (&ValidTurnTime($CurrentEpoch, 'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) eq 'True') { $TurnReady = 'True'; } 
				&LogOut(100,"#####Checkandupdate: New Turn : $NewTurn  TurnReady = $TurnReady",$LogFile);
				# If there are any delays set, then we need to clear them out, and reset the game status
				# since if we're generating with a turn missing we've clearly hit the window past the delays.
				if ($GameData[$LoopPosition]{'DelayCount'} > 0) {
					$sql = "UPDATE Games SET DelayCount = 0 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
					if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: Delay reset to 0 for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
					$sql = "UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
					if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: GameStatus reset to 2 for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
				}

	    #Game Type = All In
			} elsif ($GameData[$LoopPosition]{'GameType'} == 3) { #Turns only generated when all turns are in
				print $GameData[$LoopPosition]{'GameName'} . " is an All turns required game\n";
				$TurnReady = &Eval_CHK($GameData[$LoopPosition]{'GameFile'});
				if ($TurnReady eq 'True') { &LogOut(50,"   Checkandupdate: All turns are in for $GameData[$LoopPosition]{'GameName'}", $LogFile);	}
				else { &LogOut(100,"   All turns are not in for $GameData[$LoopPosition]{'GameName'}",$LogFile); }
        # No need to check for delays
        
	    # Generate as Available (assumes nothing else generated!)
      # BUG: Needs to decrement delay? 
			} elsif ($GameData[$LoopPosition]{'AsAvailable'} == 1 && (!(&Turns_Missing($GameData[$LoopPosition]{'GameFile'})))) { # only check Generate As Available ongoing game status if necessary, if not, then return false
				$TurnReady = 'True';
				# If the game is in a delay state, decrement the delay 
					if ($GameData[$LoopPosition]{'DelayCount'} > 0 ) {
						$sql = "UPDATE Games SET DelayCount = DelayCount -1 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
						if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: Delay decremented for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
					}
          # And reset the game to active if it's time
          if ( $GameData[$LoopPosition]{'DelayCount'} == 1 ) { # which is now really 0
  					$sql = "UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\';";
  					if (&DB_Call($db,$sql)) { &LogOut(50, "Checkandupdate: GameStatus reset to 2 for $GameData[$LoopPosition]{'GameFile'}", $LogFile); }
          }

					# Recalculate when the next turn is due
					# Next turn is incremented by the correct amount
          #Daily Game
					if ($GameData[$LoopPosition]{'GameType'} == 1) { #New Turn time = This turn time for today + X days
						# Determine when the next turn would NORMALLY be from right now. 
						($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$WeekDay,$GameData[$LoopPosition]{'DailyTime'},$SecOfDay);
						my $NormalNextTurn = $CurrentDateSecs + ($DaysToAdd * 86400) + ($GameData[$LoopPosition]{'DailyTime'} *60*60); 			
						($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$NextDayOfWeek);
						$NormalNextTurn = $NormalNextTurn + ($DaysToAdd * 86400);
						# Advance to the next valid day if $NormalNextTurn isn't on a valid day
						while (&ValidTurnTime($NormalNextTurn,'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { 
							($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = &CheckTime($NormalNextTurn);
							($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$CWeekDay); 
							$NormalNextTurn = $NormalNextTurn + ($DaysToAdd * 86400); 
						}
						print "NormalNextTurn = " . localtime($NormalNextTurn) . "\n";

						# Determine when the next turn would be based on NextTurn
						# This is generating from NextTurn, so should only increment in days, not Days + hours like you
						# do when calculating from SecOfDay
						($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = &CheckTime($GameData[$LoopPosition]{'NextTurn'});
						($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$CWeekDay,$GameData[$LoopPosition]{'DailyTime'},$CSecOfDay);
						$NewTurn = $GameData[$LoopPosition]{'NextTurn'} + ($DaysToAdd * 86400); 
						print "1: New Turn = " . localtime($NewTurn) . " DaysToAdd = $DaysToAdd\n";
						# Advance to the next valid day if $NewTurn isn't on a valid day
						while (&ValidTurnTime($NewTurn,'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { 
							($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = &CheckTime($NewTurn);
							($DaysToAdd, $NextDayOfWeek) = &DaysToAdd($GameData[$LoopPosition]{'DayFreq'},$CWeekDay); 
							$NewTurn = $NewTurn + ($DaysToAdd * 86400); 
						}
						print "2: New Turn Adjusted = " . localtime($NewTurn) . "\n";

            # Right here we have three date variables: $NewTurn, $NormalNextTurn, $GameData[$LoopPosition]{'NextTurn'}
            # $NewTurn - next turn based on  $GameData[$LoopPosition]{'NextTurn'}
            # $NormalNewTurn - next turn based on "now"
            # $GameData[$LoopPosition]{'NextTurn'} - Next turn from last time
            #
            # If the game is delayed, pick the larger of $NormalNewTurn and $GameData[$LoopPosition]{'NextTurn'}
            # Otherwise pick the larger of $NormalNewTurn and $NewTurn
            #If the turn based on NextTurn is more than the normal next turn date, 
            # and the game is delayed, don't decrease when the turn is due
            # Now we need to "protect" next turn in case a delayed game is even farther out  
            # but only for games that are (still) delayed
            if ($GameData[$LoopPosition]{'DelayCount'} > 1 && $GameData[$LoopPosition]{'GameStatus'} == 3)	{
              if ( $GameData[$LoopPosition]{'NextTurn'} > $NormalNewTurn ) { 
                $NewTurn = $GameData[$LoopPosition]{'NextTurn'}; 	
                &LogOut(200,"checkandupdate: NewTurn: $NewTurn > DB: $GameData[$LoopPosition]{'NextTurn'}. Protecting.",$LogFile); 
              } else { 
                $NewTurn = $NormalNewTurn; 
              } 
            } else { 
              # For a game that isn't currently delayed
  						if ($NewTurn > $NormalNextTurn) {  
  							&LogOut(200,"checkandupdate: NewTurn: $NewTurn > NormalNewTurn: $NormalNextTurn",$LogFile); 
  							# Don't increase the turn if it's already far enough in the future. 
   							$NewTurn = $NormalNextTurn;
  							print "3: New Turn True = " . localtime($NewTurn) . "\n";
#   						} else {
#   							&LogOut(200,"checkandupdate: NewTurn: $NewTurn <= NormalNewTurn: $NormalNextTurn",$LogFile); 
#                 $NewTurn = $NewTurn;
  						}
            }
  					print "4: New Turn Final = " . localtime($NewTurn) . "\n";
					}
          # Hourly
					# Next turn is generated Now + Game Interval
					elsif ($GameData[$LoopPosition]{'GameType'} == 2) { #
						# Determine when the next turn would normally be. 
						my $NormalNextTurn = $CurrentEpoch + (($GameData[$LoopPosition]{'HourlyTime'} *60 *60) * 2); 
						while (&ValidTurnTime($NormalNextTurn, 'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NormalNextTurn = $NormalNextTurn + ($GameData[$LoopPosition]{'HourlyTime'}*60*60); }
						while (&ValidTurnTime($NormalNextTurn,'Hour',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NormalNextTurn = $NormalNextTurn + 3600; }
						$NewTurn = $CurrentEpoch + ($GameData[$LoopPosition]{'HourlyTime'}*60*60); 
						while (&ValidTurnTime($NewTurn, 'Day',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + ($GameData[$LoopPosition]{'HourlyTime'}*60*60); }
						while (&ValidTurnTime($NewTurn,'Hour',$GameData[$LoopPosition]{'DayFreq'}, $GameData[$LoopPosition]{'HourFreq'}) ne 'True') { $NewTurn = $NewTurn + 3600; }
						if ($NewTurn > $NormalNextTurn) {  
							&LogOut(200,"checkandupdate: $NewTurn > $NormalNextTurn",$LogFile); 
							# Don't increase the turn if it's already far enough in the future. 
							$NewTurn = $GameData[$LoopPosition]{'NextTurn'};
			      }
            # Now we need to "protect" next turn in case a delayed game is even farther out
            # but only for games that are (still) delayed
            if ($GameData[$LoopPosition]{'DelayCount'} > 1 && $GameData[$LoopPosition]{'GameStatus'} == 3)	{
              if ( $GameData[$LoopPosition]{'NextTurn'} > $NewTurn) { 
                $NewTurn = $GameData[$LoopPosition]{'NextTurn'}; 	
                &LogOut(200,"checkandupdate: $NewTurn > $GameData[$LoopPosition]{'NextTurn'}. Protecting.",$LogFile); 
              }
            }
          }	
#        }	
      }
      
	    # If a turn is ready, generate it and process it through. 
			if ($TurnReady eq 'True') {
				&UpdateNextTurn($db,$NewTurn, $GameData[$LoopPosition]{'GameFile'}, $GameData[$LoopPosition]{'LastTurn'});		
				&UpdateLastTurn($db,time(), $GameData[$LoopPosition]{'GameFile'});		
				&LogOut(100,"Turn READY for $GameData[$LoopPosition]{'GameFile'}",$LogFile);
				my $HSTFile = $File_HST . '/' . $GameData[$LoopPosition]{'GameFile'} . '/' . $GameData[$LoopPosition]{'GameFile'} . '.hst';
				# Get the current turn and don't force generate on the first two turns, regardless. 
				($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
				# Check to see if it's a force gen game, and if so increase the number of times the game will generate unless first two turns
				my($NumberofTurns) = 1;
				if ($GameData[$LoopPosition]{'ForceGen'} == 1 && $HST_Turn ne '2400' && $HST_Turn ne '2401') {
					$NumberofTurns = $GameData[$LoopPosition]{'ForceGenTurns'};
					$NumberofTimes = $GameData[$LoopPosition]{'ForceGenTimes'} -1;
					# Update NumberofTimes
					$sql = "UPDATE Games SET ForceGenTimes = $NumberofTimes WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\'";
					if (&DB_Call($db,$sql)) { &LogOut(200,"Decremented ForceGenTimes for $GameData[$LoopPosition]{'GameFile'}",$LogFile); }
					else { &LogOut(200,"Failed to Decrement ForceGenTimes for $GameData[$LoopPosition]{'GameFile'}",$ErrorLog);}
					if ($NumberofTimes <= 0) { #If the game is no longer forced, unforce game
						$sql = "UPDATE Games SET ForceGen = 0 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\'";
						if (&DB_Call($db,$sql)) { &LogOut(200,"Forcegen set to 0 for $GameData[$LoopPosition]{'GameFile'}",$LogFile) }
						else { &LogOut(0,"Failed to set forcegen to 0 for $GameData[$LoopPosition]{'GameFile'}",$ErrorLog); }
					}
				}
#				&GenerateTurn($NumberofTurns, $GameData[$LoopPosition]{'GameFile'});
				# If Game was flagged as Delayed, once we generate it's not anymore
				if ($GameData[$LoopPosition]{'GameStatus'} == 3 && $GameData[$LoopPosition]{'DelayCount'} <= 0) { 
					$sql = "UPDATE Games SET GameStatus = 2 WHERE GameFile = \'$GameData[$LoopPosition]{'GameFile'}\'";
					if (&DB_Call($db,$sql)) { &LogOut(100, "TurnMake: Resetting Game Status for $GameData[$LoopPosition]{'GameFile'} to Active", $LogFile);  }
					else { &LogOut(0, "TurnMake: Failed to Reset Game Status for $GameData[$LoopPosition]{'GameFile'} to Active", $ErrorLog); }
				}
 
				# Update the .chk file so it's current for the new turn
				my @CHK = &Read_CHK($GameData[$LoopPosition]{'GameFile'});
        
				# get the current turn so you can put it in the email, can vary based on force gen.
				($Magic, $lidGame, $ver, $HST_Turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($HSTFile);
				$GameData[$LoopPosition]{'NextTurn'} = $NewTurn;
        
        # Generate an updated .queue file for the Cheap Starbase exploit detection
        # Also generate a fleet file for Mineral Upload detection 
        my $fixFile = $FileHST  . '\\' . $GameData[$LoopPosition]{'GameFile'} . '\\' . 'fix';
        if ($fixFiles && -e $fixFile) {
          # Get rid of the old queueFile
          my $lastYear = $HST_Turn -1;
          #my $oldQueueFile = $GameDir . '\\' . $GameFile . '.HST' . ".$lastYear" . '.queue';
          my $oldQueueFile = $GameDir . '\\' . $GameFile . ".$lastYear" . '.queue';
          if (-e $oldQueueFile) { unlink $oldQueueFile; }
          # Create the queue file
          # Game Dir, Game File, Year
          my $GameDir = $FileHST  . '\\' . $GameData[$LoopPosition]{'GameFile'};
          &StarsQueue($GameDir, $GameData[$LoopPosition]{'GameFile'}, $HST_Turn);
        }
        # Decide whether to set player to Idle
        # Read in the game and player information from the CHK File
        # BUG: Not going to work quite right if the player is in the game more than once. 
    		my($IdlePosition) = 3;
        my $IdleMessage = '';
        &LogOut(300, 'STARTING AUTOIDLE', $LogFile);
        while ($CHK[$IdlePosition]) {  #read .m file lines
    			my ($CHK_Status, $CHK_Player) = &Eval_CHKLine($CHK[$IdlePosition]);
    			my($Player) = $IdlePosition -2;
     			my $MFile = $File_HST . '/' . $GameData[$LoopPosition]{'GameFile'} . '/' . $GameData[$LoopPosition]{'GameFile'} . '.m' . $Player;
          &LogOut(300, ".m File: $MFile", $LogFile);
          # Get the Turn Year information for the player
    			($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &starstat($MFile);
    			$TurnYears = $HST_Turn -$turn +1; 
          &LogOut(299, "Player: $Player Status: $CHK_Status  TurnYears: $TurnYears Player: $CHK_Player", $LogFile);
    			# Get the Player Status values for the current player
          $GameFile = $GameData[$LoopPosition]{'GameFile'};
    			$sql = qq|SELECT Games.GameFile, GameUsers.User_Login, GameUsers.PlayerID, GameUsers.PlayerStatus, [_PlayerStatus].PlayerStatus_txt FROM _PlayerStatus INNER JOIN ([User] INNER JOIN (Games INNER JOIN GameUsers ON (Games.GameFile = GameUsers.GameFile) AND (Games.GameFile = GameUsers.GameFile)) ON User.User_Login = GameUsers.User_Login) ON [_PlayerStatus].PlayerStatus = GameUsers.PlayerStatus WHERE (((Games.GameFile)=\'$GameFile\') AND ((GameUsers.PlayerID)=$Player));|;
    			if (&DB_Call($db,$sql)) { while ($db->FetchRow()) { %PlayerValues = $db->DataHash(); } }
    			# If the player is active, AND the number of turns missed is greater than AutoIdle, set the player to Idle
          &LogOut(300, "Player Status: $PlayerValues{'PlayerStatus'}   AutoIdle: $GameData[$LoopPosition]{'AutoIdle'}  TurnYears: $TurnYears ", $LogFile); 
    			if (($PlayerValues{'PlayerStatus'} == 1) && ($GameData[$LoopPosition]{'AutoIdle'}) && ($TurnYears >= $GameData[$LoopPosition]{'AutoIdle'})) {
            &LogOut(300, "Need to set Player $Player to Idle", $LogFile);  
            $sql = qq|UPDATE GameUsers SET PlayerStatus=4 WHERE PlayerID = $Player AND GameFile = '$GameFile';|;
            &LogOut(300, "SQL= $sql", $LogFile);
          	if (&DB_Call($db,$sql)) { 
              &LogOut(100,"Player $Player Status updated to Idle for $GameFile having missed $TurnYears turns", $LogFile); 
              # Create the message for the email
              $IdleMessage .= $IdleMessage . "Player $Player Status changed to Idle. No turns submitted for $TurnYears turn(s).\n";
            } else { &LogOut(0, "Player $Player Status failed to update to Idle for $GameFile", $ErrorLog); }
          } else { }  # no need to do anything otherwise 
   			  undef %PlayerValues; # Need to clear array to be ready for the next player
    			$IdlePosition++;
    		}
        &LogOut(300, 'ENDING AUTOIDLE', $LogFile);
       
				# Get the array into a format I can pass to the subroutine, which involves converting it to a direct hash.
				# If you're confused about why you use an '@' there on a hash slice instead of a '%', think of it like this. 
				# The type of bracket (square or curly) governs whether it's an array or a hash being looked at. 
				# On the other hand, the leading symbol ('$' or '@') on the array or hash indicates whether you are getting back 
				# a singular value (a scalar) or a plural one (a list).
				my $GameValues = $GameData[$LoopPosition];
				%GameValues = %$GameValues;
				$GameValues{'Message'} = "New turn available at $WWW_HomePage\n\n";
        # If any player(s) were set idle, add that to the email notification
        $GameValues{'Message'} .= $IdleMessage; 
				$GameValues{'HST_Turn'} = $HST_Turn;
				# Adjust the value of next turn in case there's DST
				# Since we've updated last turn, we need to use the original
				$GameValues{'NextTurn'} = &FixNextTurnDST($GameValues{'NextTurn'}, $GameData[$LoopPosition]{'LastTurn'},1);
        
				&Email_Turns($GameData[$LoopPosition]{'GameFile'}, \%GameValues, 1);
			}
			#Print when the next turn will be generated.
			if ($NewTurn) { print "1:Next turn for $GameData[$LoopPosition]{'GameFile'} gen on/after $NewTurn: " . localtime($NewTurn); }
			else { print "2:Next turn for $GameData[$LoopPosition]{'GameFile'} gen on/after $GameData[$LoopPosition]{'NextTurn'}: " . localtime($GameData[$LoopPosition]{'NextTurn'}); }
			if ($GameData[$LoopPosition]{'AsAvailable'} == 1) {	print ' or when all turns are in'; }		
			print ".\n";
		}
		$LoopPosition++;	#Now increment to check the next game
  	}
	# Give the system a moment between each game, Stars! is slow. 
	sleep 2;
}

# Check to see if all the turns are in taking everything into account
# Stars reported status, host-defined player status
sub Turns_Missing {
	my ($GameFile) = @_;
	my $TurnsMissing = 0;
	my @Status;
  my @CHK;
	my %Values;
 	my $CHKFile = $FileHST . '\\' . $GameFile . '\\' . $GameFile . '.chk';
  &Make_CHK($GameFile);
	# Determine the number of players in the CHK File
	if (-e $CHKFile) { #Check to see if .chk file is there.
		&LogOut(200,"Turns_Missing: Reading CHK File $CHKFile",$LogFile);
		open (IN_CHK,$CHKFile) || &LogOut(0,"Cannot open .chk file $CHKFile", $ErrorLog);
		chomp((@CHK) = <IN_CHK>);
	 	close(IN_CHK);
		for (my $i=3; $i <= @CHK - 1; $i++) { # Skip over starting lines
			my $id = $i - 2;
			$Status[$id] = $CHK[$i];
		}
	} else { &LogOut(0,'Turns_Missing: Cannot open .chk file - die die die ',$ErrorLog); die; }
	# Run through all the players in the database and check status	
	$sql = qq|SELECT GameUsers.PlayerID, GameUsers.PlayerStatus FROM Games INNER JOIN GameUsers ON Games.GameFile = GameUsers.GameFile WHERE GameUsers.GameFile = '$GameFile' AND GameUsers.PlayerStatus=1;|;
	if (&DB_Call($db,$sql)) { 
		while ($db->FetchRow()) { 
			%Values = $db->DataHash(); 
			if ((index($Status[$Values{'PlayerID'}], 'turned in') == -1) && (index($Status[$Values{'PlayerID'}], 'dead') == -1)) { &LogOut(300,"OUT $Values{'PlayerID'}: $Status[$Values{'PlayerID'}]",$LogFile); $TurnsMissing = 1; }
			else { &LogOut(300,"IN $Values{'PlayerID'}: $Status[$Values{'PlayerID'}]",$LogFile);  }
		} 
	}
	if ($TurnsMissing) { &LogOut(200,"Turns_Missing: .x files are missing for $GameFile",$LogFile) } else { &LogOut(200,"All .x files are in for $GameFile",$LogFile); }
	return $TurnsMissing;
}

sub inactive_game {
	my ($GameFile) = @_;
	# Determine when the last game turn was submitted
	my $UserCounter = 0;
	my $sql = qq|SELECT * FROM GameUsers WHERE GameFile = \'$GameFile\';|;
	my %UserValues;
	my $LastSubmitted = -1;

	my $db = &DB_Open($dsn);
	# Read in all the user data for the game.
	if (&DB_Call($db,$sql)) { 	while ($db->FetchRow()) { 
		my %UserValues = $db->DataHash(); 
		$UserCounter++;
		$UserData[$UserCounter] = { %UserValues };
		# Get the largest/ most recent Last Generated value
		if ($UserData[$UserCounter]{'LastSubmitted'} > $LastSubmitted ) { $LastSubmitted = $UserData[$UserCounter]{'LastSubmitted'}; }
	} }
	#while ( my ($key, $value) = each(%UserValues) ) { print "$key => $value\n"; }

	my $currenttime = time();
	# Check to see if it's been too long since a turn was generated
	# Can't use .x[n] file date because it gets removed when turns gen.
  # BUG: If no one has ever submitted a turn, don't deactivate game
	if ((($currenttime - $LastSubmitted) > ($max_inactivity * 86400)) && ($LastSubmitted > 0)) {
		my $log = "inactive_game: $GameFile Inactive, last submitted on " . localtime($LastSubmitted); 
		&LogOut(50,$log, $ErrorLog);
		# End/Pause the game
		$sql = qq|UPDATE Games SET GameStatus = 4 WHERE GameFile = \'$GameFile\'|;
		if (&DB_Call($db,$sql)) {
			&LogOut(100, "inactive_game: $GameFile Ended/Paused for lack of activity", $LogFile);
		} else {
			&LogOut(0, "inactive_game: $GameFile Failed to end for lack of activity", $ErrorFile);
		}
		return 1; 
	} else { return 0; }
	&DB_Close($db); 
}

sub StarsQueue {
# Generate a queue file (used by Fix for Cheap Starbase detection)
# Generate a fleet file (used by Fix for Mineral Upload detection)
  my ($GameDir, $GameFile, $turn) = @_;
  # Read in the .HST File
  my $filename = $GameDir . '\\' . $GameFile . '.HST';
  open(StarFile, "<$filename");
  binmode(StarFile);
  while (read(StarFile, $FileValues, 1)) {
    push @fileBytes, $FileValues; 
  }
  close(StarFile);
  # Decrypt the data, block by block
  my ($queueList,$fleetList) = &decryptQueue(@fileBytes);
  my %queueList = %$queueList;
  my %fleetList = %$fleetList;
  $GameFile = uc($GameFile);
  if (-d $GameDir) { # Check to make sure we're putting the .queue in the right place
    # write out the unmodified queue list
#    my $fleetFile = $GameDir . '\\' . $GameFile . '.HST' . ".$turn" . '.queue';
    my $queueFile = $GameDir . '\\' . $GameFile . ".$turn" . '.queue';
    &writeQueueFile($queueFile, \%queueList);
    
    # write out the unmodified fleet list
#    my $fleetFile = $GameDir . '\\' . $GameFile . '.HST' . ".$turn" . '.fleet';
    my $fleetFile = $GameDir . '\\' . $GameFile . '.HST' . '.fleet';
    &writeFleetFile($fleetFile, \%fleetList);
    &PLogOut(100, "Done writing out $fleetFile", $LogFile)
  } else { &PLogOut (0,"TurnMake: Directory $GameDir Missing for $queueDir", $ErrorLog); }
}

sub decryptQueue {
  my (@fileBytes) = @_;
  my @block;
  my @data;
  my ($decryptedData, $encryptedBlock, $padding);
  my @decryptedData;
  my ($binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti);
  my ($random, $seedA, $seedB, $seedX, $seedY);
  my ( $FileValues, $typeId, $size );
  my $offset = 0; #Start at the beginning of the file
  my ($planetId, $ownerId); 
  my %queueList;
  my $queueCounter=0;
  my %fleetList;
  my $fleetCounter=0;
  my @designCargo; # Cargo capacity for a design
  my @shipDesigns; # As the design block doesn't include player information 
  my @starbaseDesigns; # As the design block doesn't include player information 
  my $playerCounterShip = 0; # Start with the first player, and increment as we pass designs
  my $playerCounterStarbase = 0; # Start with the first player, and increment as we pass designs
  my $shipDesignCounter = 0; 
  my $starbaseDesignCounter = 0; 
  while ($offset < @fileBytes) {
    # Get block info and data
    $FileValues = $fileBytes[$offset + 1] . $fileBytes[$offset];
    ( $typeId, $size ) = &parseBlock($FileValues, $offset);
    @data =   @fileBytes[$offset+2 .. $offset+(2+$size)-1]; # The non-header portion of the block
    @block =  @fileBytes[$offset .. $offset+(2+$size)-1]; # The entire block in question

   # FileHeaderBlock, never encrypted
    if ($typeId == 8) { # File Header Block
      # We always have this data before getting to block 6, because block 8 is first
      # If there are two (or more) block 8s, the seeds reset for each block 8
      ( $binSeed, $fShareware, $Player, $turn, $lidGame, $Magic, $fMulti) = &getFileHeaderBlock(\@block);
      ( $seedA, $seedB) = &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
      $seedX = $seedA; # Used to reverse the decryption
      $seedY = $seedB; # Used to reverse the decryption
      push @outBytes, @block;
    } elsif ($typeId == 0) { # FileFooterBlock, not encrypted 
      push @outBytes, @block;
    } else {
      # Everything else needs to be decrypted
      ($decryptedData, $seedA, $seedB, $padding) = &decryptBytes(\@data, $seedA, $seedB); 
      @decryptedData = @{ $decryptedData };
      # WHERE THE MAGIC HAPPENS
      if ($typeId == 6) { # Player Block
        # Partial player block; see StarsRace.pl
        my $playerId = $decryptedData[0] & 0xFF; 
        my $shipDesigns = $decryptedData[1] & 0xFF;
        my $fleets = ($decryptedData[4] & 0xFF) + (($decryptedData[5] & 0x03) << 8);
        my $starbaseDesigns = (($decryptedData[5] & 0xF0) >> 4);
        $shipDesigns[$playerId] = $shipDesigns;
        $starbaseDesigns[$playerId] = $starbaseDesigns;
      }
      elsif ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .M and .HST file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
      } 
      elsif ($typeId == 16 ) { # Fleet block and partial fleet block
        # don't care about a partial fleet block (17), as that would be a different
        # player's fleet.
        my %fleet; # To store the values in a hash
        my ($byte5);
        my ($fleetId, $ownerId, $hull);
        my ($byte2, $byte3); # who knows
        my $kindByte; # 3 for most partial, 4 for robber baron, 7 for full
        my $positionObjectId;
        my $index;
        my $fileLength;
        my ($iLength, $bLength, $gLength, $popLength, $fuelLength);
        my $contentsLengths;
        my ($ironium, $boranium, $germanium, $population, $fuel);
        my ($x, $y);
        my ($deltaX, $deltaY);  # partial fleet data
        my ($shipTypes);
        my $damagedShipTypes; # full fleet data
        my @damagedShipInfo;    # full fleet data
        my @shipCount;
        my $mask;
        my ($warp, $waypointCount);
        my ($unknownBitsWithWarp); # partial fleet data
        my $battlePlan; # full fleet data
        my $fleetCargo = 0; # fleet cargo capacity
        
        $fleetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 1) << 8);
        $ownerId = $decryptedData[1] >> 1;
        $byte2 = $decryptedData[2];
	      $byte3 = $decryptedData[3];
        $kindByte = $decryptedData[4];
        $byte5 = $decryptedData[5];
        my $shipCountTwoBytes;
        if (($byte5 & 8) == 0) { $shipCountTwoBytes = 1; 
        } else  {$shipCountTwoBytes = 0; }
        $positionObjectId = &read16(\@decryptedData, 6);
        $x = &read16(\@decryptedData, 8);
        $y = &read16(\@decryptedData, 10);
        $shipTypes = &read16(\@decryptedData, 12); # counted from the right side
        $index = 14;
        $mask = 1;
        for (my $bit = 0; $bit < 16; $bit++) {
          if (($shipTypes & $mask) != 0) {
            if ($shipCountTwoBytes) {
              $shipCount[$bit] = &read16(\@decryptedData, $index);
              $index += 2;
            } else {
              $shipCount[$bit] = &read8($decryptedData[$index]);
              $index += 1;
            }
          } else { $shipCount[$bit] =0; } # Pad out the array
          $mask <<= 1;
        }
        my $shipct = 0;
        foreach my $val (@shipCount) {
          if ( $val ) { 
            $fleetCargo += $designCargo[$shipct] * $val;
#             print "designSlot: $shipct shipCount: $val fleetCargo: $fleetCargo\n";
          }
          else { 
            $fleetCargo += 0;
#             print "designSlot: $shipct shipCount: 0 fleetCargo: $fleetCargo\n";
          }
          $shipct++;
        }
        # PARTIAL_KIND = 3, PICK_POCKET_KIND = 4, FULL_KIND = 7;
        #if ($kindByte != 7 && $kindByte != 4 && $kindByte != 3) {
        if ($kindByte == 7 || $kindByte == 4) {
          $contentsLengths = &read16(\@decryptedData, $index);
          $iLength = $contentsLengths & 0x03;
          $iLength = 4 >> (3 - $iLength);
          $bLength = ($contentsLengths & 0x0C) >> 2;
          $bLength = 4 >> (3 - $bLength);
          $gLength = ($contentsLengths & 0x30) >> 4;
          $gLength = 4 >> (3 - $gLength);
          $popLength = ($contentsLengths & 0xC0) >> 6;
          $popLength = 4 >> (3 - $popLength);
          $fuelLength = $contentsLengths >> 8;
          $fuelLength = 4 >> (3 - $fuelLength);
          $index += 2;
          $ironium = &readN(\@decryptedData, $index, $iLength);
          $index += $iLength;
          $boranium = &readN(\@decryptedData, $index, $bLength);
          $index += $bLength;
          $germanium = &readN(\@decryptedData, $index, $gLength);
          $index += $gLength;
          $population = &readN(\@decryptedData, $index, $popLength);
          $index += $popLength;
          $fuel = &readN(\@decryptedData, $index, $fuelLength);
          $index += $fuelLength;
        } 
        if ($kindByte == 7) {
          $damagedShipTypes = &read16(\@decryptedData, $index);
          $index += 2;
          $mask = 1;
          for (my $bit = 0; $bit < 16; $bit++) {
            if (($damagedShipTypes & $mask) != 0) {
              $damagedShipInfo[$bit] = \&read16(\@decryptedData, $index);
              $index += 2;
            }
            $mask <<= 1;
          }
          $battlePlan = &read8($decryptedData[$index++]);
          $waypointCount = &read8($decryptedData[$index++]);
        } else {
          $deltaX = &read8($decryptedData[$index++]);
          $deltaY = &read8($decryptedData[$index++]);
          $warp = $decryptedData[$index] & 15;
          $unknownBitsWithWarp = $decryptedData[$index] & 0xF0;
          $index++;
          $index++;
          $mass = &read32(\@decryptedData, $index);
          $index += 4;
        }
        $x = &read16(\@decryptedData, 8);  # Correct (likely only in full block?)
        $y = &read16(\@decryptedData, 10); # Correct (likely only in full block?)
        print "Fleet: ownerId: $ownerId, fleetId: $fleetId, x: $x, y: $y, battlePlan: $battlePlan,  Cargo: $fleetCargo, shipTypes:" . &dec2bin($shipTypes) . "\n";
        $fleetCounter++;
        $fleet{'ownerId'} = $ownerId;
        $fleet{'fleetId'} = $fleetId;
        $fleet{'x'} = $x;
        $fleet{'y'} = $y;
        $fleet{'battlePlan'} = $battlePlan;
        $fleet{'shipTypes'}  = &dec2bin($shipTypes);
        $fleet{'shipCount'}  = \@shipCount; # This array doesn't have counts for any design after the last one with a number.
        $fleet{'fleetCargo'} = $fleetCargo;
        $fleet{'shipTypes'}  = &dec2bin($shipTypes);
        $fleet{'shipCount'}  = \@shipCount; # This array doesn't have counts for any design after the last one with a number.
        $fleetList{$fleetCounter} = { %fleet };
      } 
      # Detect the Cheap Starbase in the producton queue
      elsif ( $typeId == 28 && $ownerId >= 0 ) { # ProductionQueueBlock from owned planets
        # if not a .x file, we get the player Id from the most recent planet info
        # because the player info isn't in the ProductionQueueBlock 
        my ($chunk1, $chunk2, $itemId, $count, $completePercent, $itemType, $queueSize);
        $Player = $ownerId; 
        for (my $i=0; $i <= scalar(@decryptedData) -4; $i=$i+4) {
          $chunk1 = &read16(\@decryptedData, $i);
          $chunk2 = &read16(\@decryptedData, $i+2);
          $itemId = $chunk1 >> 10;  # Top 6 bits - but only uses 4
          $count = $chunk1 & 0x3FF; # Bottom 10 bits
          $completePercent = $chunk2 >> 4; #Top 12 bits
          $itemType = $chunk2 & 0xF; # bottom 4 bits
          $queueCounter++;
          $queueList{$queueCounter}{Player} = $Player;
          $queueList{$queueCounter}{planetId} = $planetId;
          $queueList{$queueCounter}{itemId} = $itemId;
          $queueList{$queueCounter}{count} = $count;
          $queueList{$queueCounter}{completePercent} = $completePercent;
          $queueList{$queueCounter}{itemType} = $itemType;
          $queueList{$queueCounter}{queueSize} = $size;
        }
      } 
      # Need to get all the ship designs to be able to calculate cargo
      elsif ($typeId == 26 || $typeId == 27) { # Design & Design Change block
      print "\nBLOCK 26 Turn: " . ($turn+2400) . "\n";
        my $hullId;
        my $index = 0;
        my $err = ''; # reset error for each time we check a hull, because it could be fixed in a later change.
        $deleteDesign = $decryptedData[0] % 16;
        if ($deleteDesign == 0) { 
          $designNumber = $decryptedData[1] % 16; 
          print "Delete designNumber: $designNumber\n";
          $isStarbase = ($decryptedData[1] >> 4) % 2; 
          print "isStarbase: $isStarbase\n";  
        }
        if ( $typeId == 27 ) { $index = 2; } # for the two extra bytes in a .x file  
        # If the order is to delete a design, the rest of the data isn't there.  Don't expect it to be.
        if ($deleteDesign) { 
          $isFullDesign =  ($decryptedData[$index] & 0x04); 
#          print "isFullDesign: $isFullDesign\n";
          $isTransferred = ($decryptedData[$index+1] & 0x80); 
#          print "isTransferred: $isTransferred\n";
          $isStarbase = ($decryptedData[$index+1] & 0x40);  
          print "isStarbase: $isStarbase\n";
          $designNumber = ($decryptedData[$index+1] & 0x3C) >> 2; 
          print "designNumber: $designNumber\n";
          $hullId = $decryptedData[$index+2] & 0xFF; 
          unless ($isStarbase) { $cargoCapacity = $hullType{$hullId}[16]; }
          unless ($isStarbase) { $fuelCapacity = $hullType{$hullId}[17]; }
          $pic = $decryptedData[$index+3] & 0xFF; 
#          print "pic: $pic\n";  
          if ($hullId == 29) { $pic = 4*31; }  # No idea why these pics are swapped
          elsif ($hullId == 31) { $pic = 4*29; }
          if ($isFullDesign) {
            # Since there can be a ship and base with the same hullId, 
            # need to be able to keep them separate
            if ($isStarbase) { $warnId = "base" . $designNumber; }
            else { $warnId = "ship" . $designNumber; }
            $armor = &read16(\@decryptedData, $index+4);  
#            print "armor: $armor\n";
            $armorIndex = $index +4; # used to fix the Space Dock overflow
            $slotCount = $decryptedData[$index+6] & 0xFF; 
#            print "slotCount: $slotCount\n";  # Actual number of slots
            $turnDesigned = &read16(\@decryptedData, $index+7); 
#            print "turnDesigned: " . $turnDesigned . "\n";
            $totalBuilt = &read16(\@decryptedData, $index+9); 
#            print "totalBuilt: $totalBuilt\n";
            $totalRemaining = &read16(\@decryptedData, $index+13); 
#            print "totalRemaining: $totalRemaining\n";
            $slotEnd = $index+17+($slotCount*4); 
#            print "slotEnd: $slotEnd\n";
            $shipNameLength = $decryptedData[$slotEnd];          
#            print "shipNameLength: $shipNameLength  (using nibbles as characters, not bytes)\n";
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
            $index = 17;  
            if ($typeId == 27) { $index += 2; } # x files have 2 more bytes
            # Loop through once for each slot
            for (my $itemSlot = 0; $itemSlot < $slotCount; $itemSlot++) {
              $itemCategory = &read16(\@decryptedData, $index);  # Where index is 17 or 19 depending on whether this is a .x file or .m file
              $index += 2;
              $itemId = &read8($decryptedData[$index++]); # Use current value of index, and increment by 1
              $itemCountIndex = $index; # used for the Space Dock overflow. 
              $itemCount = &read8($decryptedData[$index++]);
              my ( $category_str,$item_str ) = &showCategory($itemCategory, $itemId);
              if ( $category_str && $item_str ) { 
#                print "slot: $itemSlot, category: $category_str($itemCategory), item: $item_str($itemId), count: $itemCount\n"; 
              }
              else { 
#                print "slot: $itemSlot, category: <unknown>($itemCategory), item: <unknown>($itemId), count: $itemCount\n";
              }

              # Calculate actual fuel and cargo in hull (just because, in theory, I can)
              if ( $itemCount > 0 && !$isStarbase){
#                 my $key =  ($itemCategory << 8) | ( $itemId & 0xFF);
#                 mass += slot.count * Items.itemMasses.get(key); 
#                 if (itemCategory == Items.TechCategory.Mechanical.getMask()) 
                if ( &getMask($itemCategory, 12) ) {
                  if ($itemId == 2) { $cargoCapacity += $itemCount * 50;  }
                  if ($itemId == 3) { $cargoCapacity += $itemCount * 100;  }
                  if ($itemId == 4) { $cargoCapacity += $itemCount * 250;  }
                  if ($itemId == 5) { $fuelCapacity += $itemCount * 250;  }
                  if ($itemId == 6) { $fuelCapacity += $itemCount * 500;  }
                }
#                if ($itemCategory == Items.TechCategory.Electrical.getMask()) {
                if ( &getMask($itemCategory, 11) ) {
                  if ($itemId == 16) { $fuelCapacity += $itemCount * 200; }
                }
              }
            }
          } else { # If it's not a full design
            $mass = &read16(\@decryptedData, 4); 
            $slotEnd = 6; 
            $shipNameLength = $decryptedData[$slotEnd]; 
            $shipName = &decodeBytesForStarsString(@decryptedData[$slotEnd..$slotEnd+$shipNameLength]);
          }
          # Since the starbases have their own slots
          if (!$isStarbase && $isFullDesign) { print "cargoCapacity(Ship): $cargoCapacity\n"; }
#          if (!$isStarbase && $isFullDesign) { print "fuelCapacity(Ship): $fuelCapacity\n"; }
          print "shipName: $shipName\n";
          if (!$isStarbase) { 
            $designCargo[$designNumber] = $cargoCapacity; 
          }
        }
        # As this block doesn't have playerId, you have to calculate playerId
        # based on the values in Block 6
        if (!$isStarbase) {
          while (  $shipDesigns[$playerCounterShip] == 0 && $playerCounterShip < 16 ) {
            $shipDesignCounter = $shipDesigns[$playerCounterShip];
            $playerCounterShip++;
            }
          $shipDesignCounter = $shipDesigns[$playerCounterShip];
          $shipDesigns[$playerCounterShip]--;
          print "Block 26: Player Id (Ship): $playerCounterShip\n";
        }
        else {  # starbase
          while (  $starbaseDesigns[$playerCounterStarbase] == 0 && $playerCounterStarbase < 16 ) {
            $starbaseDesignCounter = $starbaseDesigns[$playerCounterStarbase];
            $playerCounterStarbase++;
          }
          $starbaseDesignCounter = $starbaseDesigns[$playerCounterStarbase];
          $starbaseDesigns[$playerCounterStarbase]--;
          print "Block 26: Player Id (Base): $playerCounterStarbase\n";
        }
      } 
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \%queueList,\%fleetList;
}



# # Returns CSecofDay along with everything else
# sub CheckTime { #Determine information for a specified time in seconds of a day
# 	my($TimetoCheck) = @_;  # Pass in Epoch Time
# 	($CSecond, $CMinute, $CHour, $CDayofMonth, $CWrongMonth, $CWrongYear, $CWeekDay, $CDayofYear, $CIsDST) = localtime($TimetoCheck); 
# 	$CMonth = $CWrongMonth + 1; 
# 	$CYear = $CWrongYear + 1900;
# 	$CSecOfDay = ($CMinute * 60) + ($CHour*60*60) + $CSecond;
# 	return ($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay);
# }

# In th.pm sorta
# sub ValidTurnTime { #Determine whether submitted time is valid to generate a turn
#   # BUG: (remarked out functon): $loopposition is used to determine array location 
#   # That's the real difference between this and the &ValidTurnTime in TurnMake
#   # Better to just pass the relevant array values and merge the two functions
# 	my($ValidTurnTimeTest, $WhentoTestFor, $LoopPosition) = @_;	
# 	my($ValidTurnTimeTest, $WhentoTestFor, $Day, $Hour) = @_;	
#   
# 	&LogOut(100,"ValidTurnTimeTest: $ValidTurnTimeTest, WhentoTestfor: $WhentoTestFor",$LogFile);
# 	my($Valid) = 'True';
# 	#Check to see if it's a holiday
# # 	if ($GameData[$LoopPosition]{'ObserveHoliday'}){ 
# # 			local($Holiday) = &CheckHolidays($ValidTurnTimeTest,$db);  #BUG: How are we passing $db here? We don't have it.
# # 			if ($Holiday eq 'True') { $Valid = 'False'; }
# # 	}
# 	my ($CSecond, $CMinute, $CHour, $CDayofMonth, $CMonth, $CYear, $CWeekDay, $CDayofYear, $CIsDST, $CSecOfDay) = &CheckTime($ValidTurnTimeTest);
# 	#Check to see if it's a valid Day
# #	my($DayFreq) = &ValidFreq($GameData[$LoopPosition]{'DayFreq'},$CWeekDay);
# 	my($DayFreq) = &ValidFreq($Day,$CWeekDay);
# 	if ($DayFreq eq 'False') { $Valid = 'False'; }
# 	#Check to see if it's a valid hour
# 	if (($WhentoTestFor) eq 'Hour') {
# #		my($HourlyTime) = &ValidFreq($GameData[$LoopPosition]{'HourFreq'},$CHour);
# 		my($HourlyTime) = &ValidFreq($Hour,$CHour);
# 		if ($HourlyTime eq 'False') { $Valid = 'False'; }
# 	}
# 	&LogOut(200,"   Valid = $Valid ",$LogFile);
# 	return($Valid);
# }

