#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 2;  # or use Test::More 'no_plan';
use HTTP::Tiny;

my $response = HTTP::Tiny->new->get('http://totalhost:80/scripts/health.pl');

is( $response->{status} => 200, 'Returns successful response');
is( $response->{content} => '<p>healthy</p>', 'Returns correct body');