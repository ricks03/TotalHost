#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 1;
use HTTP::Tiny;

use Stars::Database::GameRepository;

my @repoMethods = (
    'FindGamesInProgress',
);

subtest "Check agnostic client matches interface" => sub {
    plan tests => scalar @repoMethods;

    my $repo = new GameRepository();

    foreach(@repoMethods) {
        ok( $repo->can($_), "Repository has method $_");
    }
};
