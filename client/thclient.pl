#!/usr/bin/perl
# thclient.pl
# Local TotalHost client: poll game status, download new turns, upload submitted turns

use strict;
use warnings;
use FindBin;
use LWP::UserAgent;
use HTTP::Cookies;
use Digest::SHA qw(sha1_hex);
use File::Path qw(make_path);
use HTTP::Request::Common qw(POST);
use URI;
use Getopt::Long;
use POSIX qw(strftime);
use Cwd qw(getcwd);
use File::Copy qw(copy);

# Usage: thclient.pl [--config file] [--once] [--play GameFile[.mN]]
#   --once  run a single pass and exit (for Task Scheduler / cron)
#   --play  open the current turn for a game in Stars! and exit
my $ConfigFile = "$FindBin::Bin/thclient.conf";
my $Once = 0;
my $Play = '';

# If THClient stops with an error, keep the window open so the message can be read
# (a double-clicked thclient.exe would otherwise close at once). Not for --once, so
# scheduled runs never sit waiting for a key press.
END {
  if ($? && !$Once && -t STDIN) {
    print "Press Enter to close...";
    my $key = <STDIN>;
  }
}

GetOptions('config=s' => \$ConfigFile, 'once' => \$Once, 'play=s' => \$Play)
  or die "Usage: $0 [--config file] [--once] [--play GameFile[.mN]]\n";

our %Config;
unless (-f $ConfigFile) {
  die "Cannot load $ConfigFile: file not found. Copy thclient.conf.example to thclient.conf and fill it in.\n";
}
unless (do $ConfigFile) { die "Cannot load $ConfigFile: " . ($@ || $!) . "\n"; }
my $PollMinutes   = $Config{PollMinutes}   || 10;   # how often to ask the server for new turns
my $UploadSeconds = $Config{UploadSeconds} || 15;   # how often to look for a changed .x file

# Set when a login fails; cleared at the next server poll so a bad password isn't retried every request
my $LoginFailed = 0;

# Timestamped message to the console, and to LogFile if one is configured
sub note {
  my ($msg) = @_;
  my $line = strftime('%Y-%m-%d %H:%M:%S', localtime) . " $msg\n";
  print $line;
  if ($Config{LogFile} && open(my $log, '>>', $Config{LogFile})) { print $log $line; close($log); }
}

my $ua = LWP::UserAgent->new(
  agent        => 'THClient/0.1',
  cookie_jar   => HTTP::Cookies->new,
  max_redirect => 0,   # upload.pl reports errors in the redirect URL
  timeout      => 30,
);
# Proxy from the config, otherwise from the http_proxy / https_proxy environment variables
if ($Config{Proxy}) { $ua->proxy(['http', 'https'], $Config{Proxy}); }
else { $ua->env_proxy; }

# Fetch and parse page.pl?client=java for one game
sub get_status {
  my ($GameFile) = @_;
  my $res = $ua->get("$Config{Server}/scripts/page.pl?client=java&GameFile=$GameFile");
  return (error => 'HTTP ' . $res->status_line) unless $res->is_success;
  my $body = $res->decoded_content;
  # A truncated page means the script died partway through
  return (error => 'Incomplete response') unless $body =~ m|</body>|i;
  $body =~ s/<br>/\n/gi;
  $body =~ s/<[^>]+>//g;
  my %status;
  foreach my $line (split /\r?\n/, $body) {
    next unless $line =~ /^\s*([\w-]+)=(.*?)\s*$/;
    $status{$1} = $2;
  }
  return %status;
}

# Log in to TotalHost; the TotalHost session cookie lands in the cookie jar
# The login page's JavaScript sends sha1_hex(password) as User_Password, so we do the same
sub login {
  my $res = $ua->post("$Config{Server}/scripts/account.pl", {
    action        => 'login',
    User_Login    => $Config{User_Login},
    User_Password => sha1_hex($Config{Password} // ''),
  });
  # account.pl answers with a redirect: page.pl on success, action=login_fail on failure
  my $location = $res->header('Location') // '';
  if ($res->is_redirect && $location !~ /login_fail/) { return 1; }
  note("Login failed for $Config{User_Login}: " . ($location || $res->status_line));
  $LoginFailed = 1;
  return 0;
}

# True if an authenticated script turned us away (validate() in TotalHost.pm)
sub needs_login {
  my ($res) = @_;
  return ($res->decoded_content // '') =~ /You are not authorized to perform this function/;
}

# Send an authenticated request, logging in again once if the session has expired
sub auth_request {
  my ($request) = @_;
  my $res = $ua->request($request);
  if (needs_login($res)) {
    return $res if $LoginFailed || !login();
    $res = $ua->request($request);
  }
  return $res;
}

# Read the turn year from a Stars! file header (same layout as starstat in StarStat.pm)
sub file_year {
  my ($filename) = @_;
  open(my $fh, '<:raw', $filename) or return 0;
  read($fh, my $header, 22);
  close($fh);
  return 0 unless length($header) == 22;
  my ($Header, $Magic, $lidGame, $ver, $turn) = unpack('SA4LSS', $header);
  return $turn + 2400;
}

# Download one file through download.pl into $Dir, replacing any existing copy
sub download_file {
  my ($file, $Dir) = @_;
  my $res = auth_request(HTTP::Request->new(GET => "$Config{Server}/scripts/download.pl?file=$file"));
  # download.pl sends files as application/x-download; anything else is its HTML error page
  unless ($res->is_success && $res->content_type eq 'application/x-download') {
    my $err = $res->decoded_content // $res->status_line;
    $err =~ s/<[^>]+>//g; $err =~ s/\s+/ /g;
    note("Download of $file failed: $err");
    return 0;
  }
  # Write to a temp file first so Stars! never sees a partial file
  my $target = "$Dir/$file";
  open(my $fh, '>:raw', "$target.tmp") or do { note("Cannot write $target.tmp: $!"); return 0; };
  print $fh $res->content;
  close($fh);
  my $Backup = "$Dir/backup";
  make_path($Backup) unless -d $Backup;
  # Keep the previous turn as backup/GameFile.mN.YEAR
  if ($file =~ /\.m\d+$/i && -f $target) {
    my $OldYear = file_year($target);
    rename($target, "$Backup/$file.$OldYear") or note("Cannot back up $target: $!");
  }
  unless (rename("$target.tmp", $target)) { note("Cannot replace $target: $!"); return 0; }
  note("Downloaded $file");
  return 1;
}

# Run stars.exe from the game folder; $wait = 0 starts it without waiting (to play a turn)
sub run_stars {
  my ($Dir, $wait, @args) = @_;
  unless ($Config{StarsExe} && -f $Config{StarsExe}) { note("StarsExe is not set or not found"); return 0; }
  my $cwd = getcwd();
  chdir($Dir) or do { note("Cannot change to $Dir: $!"); return 0; };
  # On Windows, system(1, ...) starts the program and returns at once
  my $rc = $wait ? system($Config{StarsExe}, @args) : system(1, $Config{StarsExe}, @args);
  chdir($cwd);
  return $rc != -1;
}

# Race password for a game's turn file, as Stars! command-line arguments (none if not set)
sub stars_password {
  my ($game) = @_;
  return $game->{StarsPassword} ? ('-p', $game->{StarsPassword}) : ();
}

# Have Stars! write the planet (.pN), fleet (.fN) and map (.map) dump files for a turn,
# then keep a copy of the .pN/.fN in backup/ by year (same as the AutoHost client's -dpfm)
sub dump_turn {
  my ($game) = @_;
  my ($GameFile, $Player, $Dir) = @{$game}{qw(GameFile Player Dir)};
  my $MFile = "$GameFile.m$Player";
  run_stars($Dir, 1, '-dpfm', $MFile, stars_password($game)) or return;
  my $Year = file_year("$Dir/$MFile");
  foreach my $dump ("$GameFile.p$Player", "$GameFile.f$Player") {
    copy("$Dir/$dump", "$Dir/backup/$dump.$Year") if -f "$Dir/$dump";
  }
  note("Created planet, fleet and map dumps for $MFile");
}

# Open a game's turn in Stars!
sub play_turn {
  my ($game) = @_;
  my $MFile = "$game->{GameFile}.m$game->{Player}";
  note("Opening $MFile in Stars!") if run_stars($game->{Dir}, 0, $MFile, stars_password($game));
}

# Download the .xy if missing, and the .m if the server has a newer year than the local copy
sub check_download {
  my ($game, $status) = @_;
  my ($GameFile, $Player, $Dir) = @{$game}{qw(GameFile Player Dir)};
  my $ServerYear = $status->{'game-year'} or return;
  make_path($Dir) unless -d $Dir;
  download_file("$GameFile.xy", $Dir) unless -f "$Dir/$GameFile.xy";
  my $LocalYear = file_year("$Dir/$GameFile.m$Player");
  if ($LocalYear < $ServerYear) {
    note("$GameFile: server is at $ServerYear, local .m$Player is " . ($LocalYear || 'missing'));
    if (download_file("$GameFile.m$Player", $Dir)) {
      dump_turn($game) if $Config{DumpFiles};
      play_turn($game) if $Config{PlayOnNewTurn};
    }
  }
}

# One line per game: year, status, who is still out, and when the next turn generates
# Only printed when it changes, so a quiet game doesn't fill the console
my %LastSummary;
sub show_summary {
  my ($game, $status) = @_;
  my ($GameFile, $Player) = @{$game}{qw(GameFile Player)};
  my (@waiting, $mine);
  foreach my $key (sort { ($a =~ /(\d+)/)[0] <=> ($b =~ /(\d+)/)[0] } grep { /^player\d+-turn$/ } keys %$status) {
    my ($n) = $key =~ /(\d+)/;
    my $in = $status->{$key} !~ /Not Submitted/;
    # Player number and race name, e.g. "2 The WM"
    my $who = $n . ($status->{"player$n-race"} ? " $status->{\"player$n-race\"}" : '');
    push @waiting, $who unless $in;
    $mine = "($who) is " . ($in ? 'in' : 'NOT in') if $n == $Player;
  }
  my $summary = "$GameFile ($status->{'game-name'}) $status->{'game-year'} $status->{status}: "
    . 'your turn ' . ($mine // 'is unknown') . '; '
    . (@waiting ? 'waiting on ' . join(', ', @waiting) : 'all turns in')
    . ($status->{'next-gen-time'} ? "; next gen $status->{'next-gen-time'}" : '');
  note($summary) unless ($LastSummary{"$GameFile.$Player"} // '') eq $summary;
  $LastSummary{"$GameFile.$Player"} = $summary;
}

# Upload the .x file if it has changed since the last upload
# A stamp file carries the .x modification time of the last upload attempt
sub check_upload {
  my ($game) = @_;
  my ($GameFile, $Player, $Dir) = @{$game}{qw(GameFile Player Dir)};
  my $XFile = "$Dir/$GameFile.x$Player";
  my $Stamp = "$Dir/.thclient.$GameFile.x$Player";
  return if $LoginFailed || !-f $XFile;
  return if defined $game->{Upload} && !$game->{Upload};   # player set to download only
  my $xtime = (stat($XFile))[9];
  return if -f $Stamp && (stat($Stamp))[9] == $xtime;   # already sent this version
  return if time() - $xtime < 5;                        # Stars! may still be writing it

  my $res = auth_request(POST "$Config{Server}/scripts/upload.pl",
    Content_Type => 'form-data',
    Content      => [
      File     => [$XFile],
      GameFile => $GameFile,
      submit   => 'Upload Turn',
      lp => 'profile_game', cp => 'show_game', rp => 'show_news',
    ]);
  # upload.pl redirects to page.pl with any errors or warnings in the status parameter
  unless ($res->is_redirect) {
    note("Upload of $GameFile.x$Player failed: " . $res->status_line);
    return;
  }
  my %query = URI->new($res->header('Location'))->query_form;
  note("Uploaded $GameFile.x$Player" . ($query{status} ? ": $query{status}" : ''));

  # Record this version as sent, even if rejected, so an unchanged bad file isn't resent every poll
  if (open(my $fh, '>', $Stamp)) { close($fh); }
  utime($xtime, $xtime, $Stamp);

  # Confirm with the server that the turn is in
  my %status = get_status($GameFile);
  my $turn = $status{"player$Player-turn"} // '';
  note("$GameFile: server now shows player $Player turn: $turn");
}

# Ask the server about each game and download any new turns
sub poll_server {
  $LoginFailed = 0;
  foreach my $game (@{ $Config{Games} }) {
    my %status = get_status($game->{GameFile});
    if ($status{error}) { note("$game->{GameFile}: $status{error}"); next; }
    check_download($game, \%status);
    show_summary($game, \%status);
  }
}

# Look for changed .x files to upload; this is local only, so it can run often
sub poll_uploads {
  check_upload($_) foreach @{ $Config{Games} };
}

# --play GameFile or GameFile.mN: open that turn in Stars! and exit
if ($Play) {
  my ($GameFile, $Player) = $Play =~ /^([\w-]+)(?:\.m(\d+))?$/i or die "--play expects GameFile or GameFile.mN\n";
  my ($game) = grep { $_->{GameFile} eq $GameFile && (!$Player || $_->{Player} == $Player) } @{ $Config{Games} };
  die "$Play is not in $ConfigFile\n" unless $game;
  play_turn($game);
  exit;
}

note("THClient started for $Config{User_Login} on $Config{Server}: " . scalar(@{ $Config{Games} }) . ' game(s)');
poll_server();
poll_uploads();
exit if $Once;

my $NextServerPoll = time() + $PollMinutes * 60;
while (1) {
  sleep($UploadSeconds);
  poll_uploads();
  if (time() >= $NextServerPoll) {
    poll_server();
    $NextServerPoll = time() + $PollMinutes * 60;
  }
}
