package UserRepositoryPostgres;

use strict;
use warnings;

use DBI;


sub new {
    my $class = shift;
    my $config = shift;

    my $self = {
        db => DBI->connect("dbi:Pg:", '', '', {AutoCommit => 0}),
    };

    bless $self, $class;

    return $self;
}

sub CountUsers {
    my $self = shift;

    return 0;
}

1;
