#!/usr/bin/perl

# use strict;
# use warnings;

package StarsConfig;

sub new {
    my $class = shift;
    my $self = {
        isWindows => ("$^O" == "MSWin32")
    };

    bless $self, $class;

    return $self;
}

sub isWindows() {
    return $self->{isWindows} || 0;
}

sub isFeatureLive {
    my $self = shift;
    my ($feature) = @_;

    if($feature == 'database') {
        if($self->isWindows()) {
            return 1;
        }

        return 0;
    }

    return 0;
}

sub htmlRoot {
    my $self = shift;

    if($self->isWindows()) {
        return "D:/TH/html";
    }

    return $ENV{DOCUMENT_ROOT};
}

sub scriptsRoot {
    my $self = shift;

    return "/scripts";
}

sub imagesRoot {
    my $self = shift;

    return "/images/";
}

1;
