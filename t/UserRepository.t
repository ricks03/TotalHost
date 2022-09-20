#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 1;
use HTTP::Tiny;

use Stars::Database::UserRepository;

my @dbClientMethods = (
    'CountUsers',
);

subtest "Check agnostic client matches interface" => sub {
    plan tests => scalar @dbClientMethods;

    my $db = new UserRepository();

    foreach(@dbClientMethods) {
        ok( $db->can($_), "UserRepository has method $_");
    }
};
