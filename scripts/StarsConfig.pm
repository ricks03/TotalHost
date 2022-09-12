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

sub isFeatureLive {
    my $self = shift;
    my ($feature) = @_;

    if($feature == 'database') {
        if($self->{isWindows}) {
            return 1;
        }

        return 0;
    }

    return 0;
}

sub locationHtmlRoot {
    my $self = shift;

    if($self->{isWindows}) {
        return "D:/TH/html";
    }

    return $ENV->{DOCUMENT_ROOT};
}

sub locationScriptsRoot {
    my $self = shift;

    return "/scripts";
}

1;
