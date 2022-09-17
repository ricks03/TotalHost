#!/usr/bin/perl -w

use strict;
use warnings 'all';

use Test::More tests => 2;  # or use Test::More 'no_plan';
use HTTP::Tiny;


my $response = HTTP::Tiny->new->get('http://totalhost:80/scripts/index.pl');

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
