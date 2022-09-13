#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 3;  # or use Test::More 'no_plan';
use HTTP::Tiny;

subtest "HTML is available" => sub {
    plan tests => 2;

    my $response = HTTP::Tiny->new->get('http://totalhost:80/health.htm');
    is( $response->{status} => 200, 'Returns successful response');
    is( $response->{content} => '<html><body>healthy</body></html>', 'Response body is expected');
};

subtest "CGI scripts are available" => sub {
    plan tests => 2;

    my $response = HTTP::Tiny->new->get('http://totalhost:80/scripts/health.pl');
    is( $response->{status} => 200, 'Returns successful response');
    ok( grep($response->{content}, '<p>healthy</p>'), 'Returns correct body');
};

subtest "Images are available" => sub {
    plan tests => 1;

    my $response = HTTP::Tiny->new->get('http://totalhost:80/images/TotalHost.jpg');
    is( $response->{status} => 200, 'Returns successful response');
};