#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 2;  # or use Test::More 'no_plan';
use HTTP::Tiny;

my $response = HTTP::Tiny->new->get('http://totalhost:80/scripts/index.pl');

is( $response->{status} => 200, 'Returns successful response');
ok( $response->{content} =~ 'Welcome to Stars! Total Hosting', 'Returns correct body');


subtest "Index pages loads correctly" => sub {
    plan tests => 3;

    my $response = HTTP::Tiny->new->get("http://totalhost:80/scripts/index.pl");

    is( $response->{status} => 200, 'Returns successful response');
    like( $response->{content}, qr"/scripts/index.pl\?cp=login_page", 'Returns login page link');
    like( $response->{content}, qr"Welcome to Stars! Total Hosting", 'Returns welcome message');
}
