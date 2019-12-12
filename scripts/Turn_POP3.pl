#!/usr/bin/perl
# Turn_POP3.pl
# Checks a POP3 account for email turns and downloads them appropriately
# Rick Steeves th@corwyn.net
# 120808
# This isn't totally working yet, but it's close
# http://disobey.com/d/code/ or contact morbus@disobey.com.

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

use MIME::Parser;
use Mail::POP3Client;
use TotalHost;
use StarStat;
do 'config.pl';

#Overwrite the default logs to craete new ones
$LogFile = 'd:/th/logs/pop3.log';
$ErrorLog = 'd:/th/logs/pop3_error.log';
$logging=200;

if ($pop = new Mail::POP3Client( USER => "$pop3_user",PASSWORD => "$pop3_password",HOST => "$pop3_server", USESSL => true )) { &LogOut(200,"connected to $pop3_server",$LogFile); } 

# mailbox stats
$msg_total = $pop->Count(); 
$mbox_size = $pop->Size();
#if ($msg_total eq 0 || $msg_total eq '0E0')  { print "No new emails are available ($msg_total).\n"; exit; }
if ($msg_total eq 0)  { &LogOut(100,"No new emails are available ($msg_total)",$LogFile); exit; }
else { print &LogOut(100,"You have $msg_total messages totalling $mbox_size k", $LogFile); }

# the list of valid file extensions. 
my $valid_exts = "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15 X16";
my %msg_ids; # used to keep track of seen emails.
my $msg_num = 1; 
my %msg;
my $validmsg = 0;
my ($msg_subj, $msg_reply, $msg_from, $msg_sender, $msg_id);

# begin looping through each msg.
while ($msg_num <= $msg_total) {
	# the size of the individual email.
	($msgnum, $msg_size) = split('\s+', $pop -> List( $msg_num ));
	# get the header of the message so we can check for duplicates.
	my @headers = $pop->Head($msg_num);
	foreach my $header (@headers) {
		if ($header =~ /^Subject: (.*)/) {
			$msg_subj = substr($1, 0, 50); # trim subject down a bit.
#			print "Subject: $msg_subj...\n";
			$msg{'msg_subj'} = $msg_subj;
		} elsif ($header =~ /^From: .*<(.*)>/i) {
			$msg_from = $1;
#			print "From: $msg_from\n";
			$msg{'msg_from'} = $msg_from;
# 		} elsif ($header =~ /^Reply-To: <(.*)>/i) {
# 			$msg_reply = $1;
# #			print "Reply-To: $msg_reply\n";
# 			$msg{'msg_reply'} = $msg_reply;
		} elsif ($header =~ /^Sender: .*<(.*)>/i) {
			$msg_sender = $1;
#			print "Sender: $msg_sender\n";
			$msg{'msg_sender'} = $msg_sender;
		# save message-id for duplicate comparison.
		} elsif ($header =~ /^Message-ID: <(.*)>/i) {
#			print "ID: $msg_id\n";
			$msg_id = $1; $msg_ids{$msg_id}++;
			$msg{'msg_id'} = $msg_id;
		}
		# move on to the filtering if everything has been answered
#		elsif ($msg_subj and $msg_id) { last; }
	}
	&LogOut(100,"$msg_num: ID: $msg_id, Sub: $msg_subj, From: $msg_from, Sender: $msg_sender",$LogFile);
	#if the message size is too big, then it could be something too big.
    if (defined($msg_size) and $msg_size > 100000) {
		&LogOut(0, "Skipping - message $msg_subject from $msg_from is larger than our threshold",$ErrorLog);
		$msg_num++; 
		next;
	}
	# check for matching Message-ID. If found, skip and delete this message. This will help
	# eliminate crossposting and duplicate downloads.
	if (defined($msg_id) and $msg_ids{$msg_id} >= 2) {
		&LogOut(0,"Skipping - we've already seen $msg_id",$ErrorLog);
		$msg_num++; 
		next;
	}
	# get the message to feed to MIME::Parser.
	my $msg = $pop->HeadAndBody($msg_num);
	# create a MIME::Parser object to extract any attachments found within.
	my $parser = new MIME::Parser;
	$parser->output_dir( $FileEmail );
	my $mime_parts = $parser->parse_data($msg);

	# extract our mime parts and go through each one.
	my @parts = $mime_parts->parts;
	foreach my $part (@parts) {
		# determine the path to the file in question.
		my $path = ($part->bodyhandle) ? $part->bodyhandle->path : undef;
		$log = $part->bodyhandle;
		&LogOut(200, "path = $path", $LogFile);
		# move on if it's not defined, else, figure out the extension.
		next unless $path; $path =~ /\w+\.([^.]+)$/;
		my $ext = $1; next unless $ext;
		# we only continue if our extension is correct.
#		my $continue; $continue++ if $valid_exts =~ /$ext/i;
		# delete if file doesn't have a valid extension
		unless ($valid_exts =~ /$ext/) {
			&LogOut(200,"  Removing unwanted filetype ($ext): $path", $LogFile);
			unlink $path or &LogOut(0," > Error removing file at $path: $!",$ErrorLog);
			next; # move on to the next attachment or message.
		}
		&LogOut(50, "Keeping valid file: $path",$LogFile);
		print "msg_path = $path\n";
		$msg{'msg_filepath'} = $path;
		my $file = $path; 
		$file =~ s/\Q$FileEmail\E//;
		$file =~ s/(^.*)\\(.*)//;
		$msg{'msg_path'} = $1;
		$msg{'msg_file'} = $2; 
		print "msg_filepath = $msg{'msg_filepath'}\n";
		print "msg_file = $msg{'msg_file'}\n";
		print "msg_path = $msg{'msg_path'}\n";
	}
	# Store all the valid message information
	@msgdata[$validmsg] = { %msg };
	while ( my ($key, $value) = each(%msg) ) { print "$key => $value\n"; }
	$validmsg++;
	undef %msg;
	$msg_num++;
}

# cleanup and delete.
$pop->Close();

# now, jump into our savedir and remove all msg-* files which are message bodies saved by MIME::Parser.
chdir ($FileEmail); opendir(SAVE, "./") or die $!;
my @dir_files = grep !/^\.\.?$/, readdir(SAVE); closedir(SAVE);
foreach (@dir_files) { unlink if $_ =~ /^msg-/; }

# Validate each file in the folder as a valid Stars! file
my $LoopPosition = 0; #Start with the first game in the array.
while ($LoopPosition <= ($#msgdata)) { # work the way through the array
#while ( my ($key, $value) = each(%msg) ) { 
#	print "$key => $value\n"; 
	my $game_file = $msgdata[$LoopPosition]{'msg_file'};
# 	print "gamefile1: $game_file\n";
# 	$game_file =~ s/^(.*)\-.+(\.x.*)/$1$2/i;
# 	print "gamefile2: $game_file";
	my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($game_file,$msgdata[$LoopPosition]{'msg_path'});
	print qq|	my ($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($game_file,$msgdata[$LoopPosition]{'msg_path'});\n|;
	# Check to see if it's a valid file
	if ($Magic eq 'J3J3') {
		print "Its $Magic\n";
		# Check to see if it was sent by a valid player
		print "Clean: $game_file\n";

	 		my($X_Source)= $FileEmail . '/' . $file;  
	 		my($X_Destination)= $File_HST . '/' . $game_file . '/' . $file;  

	}
	$LoopPosition++;
}

#BUG: 
# Validate each file in the folder is from a valid sender

die;

# move the file to the appropriate game folder. 
# Read in all of the .x files in the directory
opendir(DIR, $FileEmail) or &LogOut(0,"Cannot opendir $FileEmail",$ErrorLog); 
while (defined($file = readdir(DIR))) {
	next unless (-f "$FileEmail/$file");
	# If it's actually a .x file cuz we don't care about any others
	if ((($file =~ /\.X/i)) && (!($file =~ /\.XY/i))) {
		# Clean up the file name just in case. 
		$clean_file = &clean($file);
		($game_file, $file_player, $file_type, $file_ext) = &FileData($clean_file);
		print qq|($game_file, $file_player, $file_type, $file_ext) = &FileData($clean_file);\n|;
		# If it's a valid stars file and a .x file
		($Magic, $lidGame, $ver, $turn, $iPlayer, $dt, $fDone, $fInUse, $fMulti, $fGameOver, $fShareware) = &ValidateFile($clean_file, $FileEmail);
		if ($Magic eq 'J3J3') {
	 		my($X_Source)= $FileEmail . '/' . $file;  
	 		my($X_Destination)= $File_HST . '/' . $game_file . '/' . $file;  
			&LogOut(200,"copy $X_Source > $X_Destination",$LogFile);
	 		if (copy($X_Source, $X_Destination)) { &LogOut(200,"copy $Game_Source > $Game_Destination",$LogFile); }
			else { &LogOut(0, "Copy: $X_Source > $X_Destination failed",$ErrorLog);}
		} else {
			&LogOut(0, "Invalid file $file emailed", $ErrorLog);
		}
	} 
}
closedir(DIR);

die;
# Email a response to the player saying their turn has been uploaded. 