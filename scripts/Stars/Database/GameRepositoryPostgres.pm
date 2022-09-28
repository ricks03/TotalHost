package GameRepositoryPostgres;

use strict;
use warnings;

use DBI;
use JSON;
use CGI::Carp;
use Data::Dumper;

my @statuses = (
    'Pending Start',
    'Pending Closed',
    'Active',
    'Delayed',
    'Paused',
    'Need Replacement',
    'Creation in Progress',
    'Awaiting Players',
    '',
    'Finished'
);

sub new {
    my $class = shift;
    my $config = shift;

    my $self = {
        config => $config
    };

    bless $self, $class;

    return $self;
}

sub FindGamesInProgress {
    my $self = shift;

    my @games = ();

    my $db = DBI->connect("dbi:Pg:", "", "", {AutoCommit => 1, RaiseError => 1, ShowErrorStatement => 1});
    my $sth = $db->prepare('SELECT gamestatus, gamefile, gamename, gamedescrip, hostname from Games WHERE GameStatus = 2');

    $sth->execute();
    while(my $row = $sth->fetchrow_hashref()) {
        warn("got in flight game: " . Dumper($row));
        my $data = {
            Status      => $row->{gamestatus},
            StatusText  => $statuses[$row->{gamestatus}],
            File        => $row->{gamefile},
            Name        => $row->{gamename},
            Description => $row->{gamedescrip},
            HostName    => $row->{hostname}
        };
        push(@games, $data);
    }

    $sth->finish();
    $db->disconnect();

    return @games;
}

1;
