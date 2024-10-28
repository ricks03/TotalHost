#!/usr/bin/perl
# maintenance.pl
# validate current file status
# Rick Steeves th@corwyn.net
# 241026

##################################################################
# File Filter    Version 1.0                                     #
# Created 04/15/2010 by Rick Steeves    Last Modified 01/22/10   #
# Used to provide file access while authenticating users         #
# used notes from 															                 #
# http://bytes.com/topic/perl/insights/857373-how-make-file-download-script-perl
##################################################################

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

use DBI;
use File::Find;
do 'config.pl';
use TotalHost;

my $sql;
my $dh;
# Get the data from the database;
my $db = &DB_Open($dsn);

# Compares Games in the DB and file system
print "Games Compare:\n";
$sql = qq|SELECT GameFile FROM Games;|;
$db_ref = get_db($sql);
$fs_folders_ref = get_fs_folders("$Dir_Games");
compare_folders($db_ref, $fs_folders_ref, $Dir_Games);
print "\n";

# Compare race folders in the DB and file system
print "Race Folders Compare:\n";
$sql = qq|SELECT User_File FROM Races;|;
$db_ref = get_db($sql);
$fs_folders_ref = get_fs_folders("$Dir_Races");
compare_folders($db_ref, $fs_folders_ref, $Dir_Races);
print "\n";

# Compare the race files themselves between the DB and file system
print "Race Files Compare:\n";
$sql = qq|SELECT RaceFile FROM Races;|;
$db_ref = get_db($sql); # This is files not folders
$fs_files_ref = get_fs_files("$Dir_Races");
compare_files($db_ref, $fs_files_ref, $Dir_Races);
print "\n";

#find . -name "filename" -type f -exec rm -f {} \;

&DB_Close($db);
#############################################################

sub compare_folders {
  my ($db_ref, $fs_folders_ref, $dir) = @_;

  # Convert array references to arrays
  my @fs_folders = @$fs_folders_ref;
  my @db = @$db_ref;  # Now this is directly an array

  # Convert the arrays into hashes for quick lookup
  my %db = map { $_ => 1 } @db;  # Database folders
  my %fs_folders = map { $_ => 1 } @fs_folders;  # Filesystem folders

  # Folders in the file system but not in the database
  my @missing_on_fs = grep { !$db{$_} } keys %fs_folders;  # Check existence in @db
  # Folders in the database but not on the file system
  my @missing_in_db = grep { !$fs_folders{$_} } keys %db;  # Check existence in @fs_folders

  # Output the comparison results
  if (@missing_on_fs) {
      print "Folders in $dir but not in the database:";
      print "$_," for @missing_on_fs;
  } else {
      print "All $dir folders are in the database.";
  }
  print "\n";

  if (@missing_in_db) {
      print "Folders in the database but not in $dir:";
      print "$_," for @missing_in_db;
  } else {
      print "All database folders are in $dir.";
  }
  print "\n";
}

# Compare files in a directory and subdirectories with the DB
sub compare_files {
    my ($db_ref, $fs_files_ref, $dir) = @_;

    # Convert array references to arrays
    my @fs_files = @$fs_files_ref;
    my @db_files = @$db_ref;
    # Extract only the base file names from the filesystem paths for comparison
    my @fs_base_files = map { $_ =~ s|.*/||r } @fs_files;  # Remove path, keep only filename
    # Elements on one array but not the other
    my @missing_in_db = grep { my $val = $_; !grep { $_ eq $val } @db_files } @fs_base_files;
    my @missing_on_fs = grep { my $val = $_; !grep { $_ eq $val } @fs_base_files } @db_files;
    
    # Output the comparison results
    if (@missing_in_db) {
        print "Files in $dir but not in the database:";
        print "$_," for @missing_in_db;
    } else {
        print "All files in $dir are in the database.";
    }
    print "\n";

    if (@missing_on_fs) {
        print "Files in the database but not in $dir:";
        print "$_," for @missing_on_fs;
    } else {
        print "All database files are in $dir.";
    }
    print "\n";
}

sub get_db {
    my ($sql) = @_;
    my @names;  # Initialize an array to hold folder names

    # Query to get fields from the DB
    if (my $sth = &DB_Call($db, $sql)) {
        # Store the results in the array
        while (my ($name) = $sth->fetchrow_array) {
            next if !defined $name || $name eq '';  # Skip undefined or empty names/folders
            push @names, $name;  # Push folder name into the array
        }
        $sth->finish;
    }
    return \@names;  # Return a reference to the array
}

# Subroutine to get folder names from the file system
sub get_fs_folders {
    my ($base_dir) = @_;
    opendir(my $dh, $base_dir) or die "Cannot open directory $base_dir: $!";
    my @folders = grep { -d "$base_dir/$_" && !/^\./ } readdir($dh);
    closedir($dh);
    return \@folders;
}

# Subroutine to get file names from the file system incl. subdirs
sub get_fs_files {
    my ($base_dir) = @_;
    my @all_files;

    find(sub {
        return unless -f;  # Only process files
        $file =  $File::Find::name;
        push @all_files, $file;  # Store full path of the file
    }, $base_dir);

    return \@all_files;  # Return an array reference of all file paths
}
