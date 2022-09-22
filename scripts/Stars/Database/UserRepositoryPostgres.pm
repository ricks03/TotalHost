package UserRepositoryPostgres;

use strict;
use warnings;

use DBI;


sub new {
    my $class = shift;
    my $config = shift;

    my $self = {
        config => $config
    };

    bless $self, $class;

    return $self;
}

sub CountUsers {
    my $self = shift;

    my $db = DBI->connect("dbi:Pg:", "", "", {AutoCommit => 1, RaiseError => 1});
    my $sth = $db->prepare('SELECT COUNT(*) FROM "user"');
    $sth->execute();
    my $count = $sth->fetch()->[0];
    $sth->finish();
    $db->disconnect();

    return $count;
}

1;
