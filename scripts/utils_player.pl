#!/usr/bin/perl
# utils_player.pl
# General collection of the player utilities
# Rick Steeves th@corwyn.net
# 120808

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
require ('timelocal.pl');
use Net::SMTP;

# Pause Game

# Sign up for Game

# Upload Race

sub DelayTurn {
	($GameFile) = @_; 
	# Get the information for the relevant game
	my $sql = "SELECT * FROM Games WHERE GameFile = $GameFile ORDER BY GameFile";
	my $GameData = &LoadGamesInProgress($db,$sql); #Load all games
	my @GameData = @$GameData;
	# Determine when it's currently supposed to generate
	# Extend when it's going to generate by one interval
	# Flag the game as delayed
	# Decrement the user's number of delays FOR THIS GAME
	# Report success

}

