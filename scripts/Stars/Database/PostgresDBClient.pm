package PostgresDBClient;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = {
    };

    bless $self, $class;

    return $self;
}

sub Open {
    my $self = shift;
}

sub Close {
    my $self = shift;
}

sub Call {
    my $self = shift;
}

sub FetchRow {
    my $self = shift;
}

1;
