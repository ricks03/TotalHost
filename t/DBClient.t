#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 3;
use HTTP::Tiny;

use Stars::Database::DBClient;
use Stars::Database::AccessDBClient;
use Stars::Database::PostgresDBClient;

my @dbClientMethods = (
    'Open',
    'Close',
    'Call',
    'FetchRow'
);

subtest "Check agnostic client matches interface" => sub {
    plan tests => scalar @dbClientMethods;

    my $db = new DBClient();

    foreach(@dbClientMethods) {
        ok( $db->can($_), "DBClient has method $_");
    }
};

subtest "Check Access client matches interface" => sub {
    plan tests => scalar @dbClientMethods;

    my $db = new AccessDBClient();

    foreach(@dbClientMethods) {
        ok( $db->can($_), "AccessDBClient has method $_");
    }
};

subtest "Check Postgres client matches interface" => sub {
    plan tests => scalar @dbClientMethods;

    my $db = new PostgresDBClient();

    foreach(@dbClientMethods) {
        ok( $db->can($_), "PostgresDBClient has method $_");
    }
};
