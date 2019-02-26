#!/usr/bin/perl
# utils_host.pl
# Host utilities for TotalHost
# General collection of the host utilities
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
use TotalHost;

# Pause Game

# Force Generate Turn

# Set Game to Complete

# Restore from Backup

# Force Game Page Refresh

# Create Holidays data