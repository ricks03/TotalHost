#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Stars::UI;

use Test::More tests => 2;

subtest "Displays correctly with no games" => sub {
    plan tests => 3;

    my @games = ();
    my $result = UI::display_games('Some title', \@games);
    like( $result, qr"<h2>Some title</h2>", 'Displays games table title');
    like( $result, qr"No Games Found", 'Shows that there are no games for empty array');
    unlike( $result, qr"<td>&nbsp&nbsp<a href=/scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile", 'No game rows displayed');
};

subtest "Displays correctly with some games" => sub {
    plan tests => 3;
    my @games = (
        {
            Name        => 'Game 1',
            File        => 'game-file.txt',
            Status      => 2,
            StatusText  => 'In Progress',
            Description => 'This is a wonderful game.',
            HostName    => 'totalhost.com'
        },
        {
            Name        => 'Game 2',
            File        => 'other-file.txt',
            Status      => 3,
            StatusText  => 'Delayed',
            Description => 'This is a late game.',
            HostName    => 'another-host.com'
        },
        {
            Name        => 'Game 3',
            File        => 'other-file.txt',
            Status      => 6,
            StatusText  => 'Creation in Progress',
            Description => 'This is a late game.',
            HostName    => 'another-host.com'
        },
        {
            Name        => 'Game 4',
            File        => 'other-file.txt',
            Status      => 7,
            StatusText  => 'Awaiting Players',
            Description => 'This is a late game.',
            HostName    => 'another-host.com'
        }
    );
    my $result = UI::display_games('Another title', \@games);

    unlike( $result, qr"No Games Found", 'Does not say there are no games');
    like( $result, qr"<h2>Another title</h2>", 'Displays different games table title');
    my @found = $result =~ /href=\/scripts\/page.pl\?lp=game&cp=show_game&rp=show_news&GameFile/g;
    is( $#found, 3, "Correct number of games is displayed");
};
