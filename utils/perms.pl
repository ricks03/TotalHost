#!/usr/bin/perl
# perms.pl
# set correct file permissions
# Rick Steeves th@corwyn.net
# 241026
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

use File::Find;
use File::stat;
do 'config.pl';

my $commandline = $ARGV[0];

# Set permissions
my $uid = getpwnam($apache_user);
my $gid = getgrnam($apache_user);
# Error handling in case user or group doesn't exist
die "User www-data not found" unless defined $uid;
die "Group www-data not found" unless defined $gid;

# Set permissons for Dir_Games
print "Settings permissions for $Dir_Games\n";
find(\&set_permissions, $Dir_Games);

# Set permissons for Dir_Races
print "Settings permissions for $Dir_Races\n";
find(\&set_permissions, $Dir_Races);
print "\n";

# Define the subroutine to process each file
# Define the subroutine to process each file and directory
sub set_permissions {
    my $file = $File::Find::name;
    
    # Set ownership to www-data:www-data
    chown $uid, $gid, $file or warn "Could not chown $file: $!";
    
    if (-f $file) {
        # Set permissions for files to 660
        chmod 0660, $file or warn "Could not chmod $file: $!";
    }
    elsif (-d $file) {
        # Set permissions for directories to 770
        chmod 0770, $file or warn "Could not chmod $file: $!";
    }
}
