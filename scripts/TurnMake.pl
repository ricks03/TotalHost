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
#require ('timelocal.pl');
use Net::SMTP;
use TotalHost;
use StarStat;
do 'config.pl';

#use strict;
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
				&GenerateTurn($NumberofTurns, $GameData[$LoopPosition]{'GameFile'});
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
        my $fixFile = $FileHST  . '\\' . $GameData[$LoopPosition]{'GameFile'} . '\\' . 'fix';
        if ($fixFiles && -e $fixFile) {
          # Get rid of the old queueFile
          my $lastYear = $HST_Turn -1;
          my $oldQueueFile = $GameDir . '\\' . $GameFile . '.HST' . ".$lastYear" . '.queue';
          if (-e $oldQueueFile) { unlink $oldQueueFile; }
          # Create the queue file
          # Game Dir, Game File, Year
          my $GameDir = $FileHST  . '\\' . $GameData[$LoopPosition]{'GameFile'};
          &StarsQueue($GameDir, $GameData[$LoopPosition]{'GameFile'}, $HST_Turn);
        }
        # Decide whether to set player to inactive
        # Read in the game and player information from the CHK File
        # BUG: Not going to work quite right if the player is in the game more than once. 
    		my($InactivePosition) = 3;
        my $InactiveMessage = '';
        &LogOut(300, 'STARTING AUTOINACTIVE', $LogFile);
        while (@CHK[$InactivePosition]) {  #read .m file lines
    			my ($CHK_Status, $CHK_Player) = &Eval_CHKLine(@CHK[$InactivePosition]);
    			my($Player) = $InactivePosition -2;
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
    			# If the player is active, AND the number of turns missed is greater than AutoInactive, set the player to Inactive
          &LogOut(300, "Player Status: $PlayerValues{'PlayerStatus'}   AutoInactive: $GameData[$LoopPosition]{'AutoInactive'}  TurnYears: $TurnYears ", $LogFile); 
    			if (($PlayerValues{'PlayerStatus'} == 1) && ($GameData[$LoopPosition]{'AutoInactive'}) && ($TurnYears >= $GameData[$LoopPosition]{'AutoInactive'})) {
            &LogOut(300, "Need to set Player $Player to Inactive", $LogFile);  
            $sql = qq|UPDATE GameUsers SET PlayerStatus=2 WHERE PlayerID = $Player AND GameFile = '$GameFile';|;
            &LogOut(300, "SQL= $sql", $LogFile);
          	if (&DB_Call($db,$sql)) { 
              &LogOut(100,"Player $Player Status updated to Inactive for $GameFile having missed $TurnYears turns", $LogFile); 
              # Create the message for the email
              $InactiveMessage .= $InactiveMessage . "Player $Player Status changed to Inactive. No turns submitted for $TurnYears turn(s).\n";
            } else { &LogOut(0, "Player $Player Status failed to update to Inactive for $GameFile", $ErrorLog); }
          } else { }  # no need to do anything otherwise 
   			  undef %PlayerValues; # Need to clear array to be ready for the next player
    			$InactivePosition++;
    		}
        &LogOut(300, 'ENDING AUTOINACTIVE', $LogFile);
       
				# Get the array into a format I can pass to the subroutine, which involves converting it to a direct hash.
				# If you're confused about why you use an '@' there on a hash slice instead of a '%', think of it like this. 
				# The type of bracket (square or curly) governs whether it's an array or a hash being looked at. 
				# On the other hand, the leading symbol ('$' or '@') on the array or hash indicates whether you are getting back 
				# a singular value (a scalar) or a plural one (a list).
				my $GameValues = $GameData[$LoopPosition];
				%GameValues = %$GameValues;
				$GameValues{'Message'} = "New turn available at $WWW_HomePage\n\n";
        # If any player(s) were set inactive, add that to the email notification
        $GameValues{'Message'} .= $InactiveMessage; 
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
	my @Status, @CHK;
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
			$Status[$id] = @CHK[$i];
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
		@UserData[$UserCounter] = { %UserValues };
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
  my $queueList = &decryptQueue(@fileBytes);
  #my $queueList = &decryptQueue();
  my %queueList = %$queueList;
  # write out the unmodified queue list
  my $queueFile = $GameDir . '\\' . $GameFile . '.HST' . ".$turn" . '.queue';
  if (-d $GameDir) { # Check to make sure we're putting the .queue in the right place
    open (QUEUEFILE, ">$queueFile");
    foreach my $queueCounter (keys %queueList) {
      print QUEUEFILE "$queueList{$queueCounter}{Player},$queueList{$queueCounter}{planetId},$queueList{$queueCounter}{itemId},$queueList{$queueCounter}{count},$queueList{$queueCounter}{completePercent},$queueList{$queueCounter}{itemType},$queueList{$queueCounter}{queueSize}\n";
    }
    close QUEUEFILE;
    &PLogOut(100, "Done writing out $queueFile", $LogFile)
  } else { &PLogOut (0,"StarsQueue: Directory $GameDir Missing for $queueDir", $ErrorLog); }
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
      if ( $typeId == 13) { # Planet Block to get Player ID for ProductionQueue
        # This always precedes the Production Queue in the .M and .HST file
        $planetId = ($decryptedData[0] & 0xFF) + (($decryptedData[1] & 7) << 8);
        $ownerId = ($decryptedData[1] & 0xF8) >> 3;
        if ($ownerId == 31) { $ownerId = -1; }
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
      # END OF MAGIC
    }
    $offset = $offset + (2 + $size); 
  }
  return \%queueList;
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

