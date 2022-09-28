#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 6;  # or use Test::More 'no_plan';
use HTTP::Tiny;
use DBI;

my $db = DBI->connect("dbi:Pg:", "", "", {AutoCommit => 1, RaiseError => 1});

subtest "Index pages loads correctly" => sub {
    plan tests => 2;

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl");

    like( $response->{content}, qr"/scripts/index.pl\?cp=login_page", 'Contains login page link');
    like( $response->{content}, qr"Welcome to Stars! Total Hosting", 'Contains welcome message');
};

subtest "Header loads correctly" => sub {
    plan tests => 3;

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl");

    like( $response->{content}, qr"<img src=/images/TotalHost.jpg", 'Links to TotalHost image');
    unlike( $response->{content}, qr"href=\"/index.pl", 'All home page links go to "scripts"');
    unlike( $response->{content}, qr"href=\"/page.pl", 'All "page" links go to "scripts"');
};

subtest "Allows user creation below user limit" => sub {
    plan tests => 1;

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl?cp=create");

    like( $response->{content}, qr"<h2>Create Account</h2>", 'Displays user creation form');
};

subtest "Disables user creation below above limit" => sub {
    plan tests => 1;

    for(my $i = 0 ; $i < 100 ; $i++) {
        $db->do("INSERT INTO \"user\" (user_email, user_login, creategame, emailturn, emaillist) VALUES ('user$i', 'login$i', FALSE, FALSE, FALSE);");
    }

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl?cp=create");

    like( $response->{content}, qr"<h2>Maxxed Users</h2>", 'Displays max user error');

    $db->do('DELETE FROM "user";');
};

subtest "Displays in-progress games" => sub {
    plan tests => 4;

    my $user=<<'end_sql';
INSERT INTO "user"
    (
        user_email,
        user_login,
        creategame,
        emailturn,
        emaillist
    )
VALUES
    ( 'host-user1', 'host-login1', FALSE, FALSE, FALSE )
;
end_sql

    my $game=<<'end_sql';
INSERT INTO "games"
    (
        "gamename", "gamefile", "gamedescrip", "hostname", "gametype", "dailytime", "hourlytime", "lastturn",
        "nextturn", "gamestatus", "delaycount", "asavailable", "onlyifavailable", "dayfreq", "hourfreq",
        "forcegen", "forcegenturns", "forcegentimes", "hostmod", "hostforce", "noduplicates", "gamerestore",
        "anonplayer", "gamepause", "gamedelay", "numdelay", "mindelay", "autoinactive", "observeholiday",
        "newspaper", "sharedm", "notes", "maxplayers"
    )
VALUES
    (
        'game 1', 'somefile', 'the first game', 'host-login1', '1', '22:00', '', '9', '10', '2', '0', 'true',
        'false', '', '', 'true', '1', '1','true', 'true', 'true', 'true', 'false', 'false', 'false', '1', '1',
        '999', 'false', 'false', 'false', 'some notes', '4' 
    )
;
end_sql
    $db->do($user);
    $db->do($game);

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl?rp=something");

    is( $response->{status}, 200, 'Page is displayed successfully');
    like( $response->{content}, qr"<h2>Games in Progress</h2>", 'Displays table of games');
    unlike( $response->{content}, qr"No Games Found", 'Shows that there are no games');
    like(
        $response->{content},
        qr"<a href=/scripts/page.pl\?lp=game&cp=show_game&rp=show_news&GameFile=somefile>game 1</a>",
        "Finds game row"
    );

    $db->do('DELETE FROM "games";');
    $db->do('DELETE FROM "user";');
};

subtest "Displays no in-progress games" => sub {
    plan tests => 3;

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl?rp=something");

    is( $response->{status}, 200, 'Page is displayed successfully');
    like( $response->{content}, qr"<h2>Games in Progress</h2>", 'Displays table of games');
    like( $response->{content}, qr"No Games Found", 'Shows that there are no games');
};

$db->disconnect();
