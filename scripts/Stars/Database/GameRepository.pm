package GameRepository;

my $isWindows = ("$^O" =~ "MSWin32");

use if $isWindows,  Stars::Database::GameRepositoryAccess;
use if !$isWindows, Stars::Database::GameRepositoryPostgres;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $client;

    if($isWindows) {
        $client = new GameRepositoryAccess(@_);
    } else {
        $client = new GameRepositoryPostgres(@_);
    }
    my $self = {
        client => $client,
    };

    bless $self, $class;

    return $self;
}

sub FindGamesInProgress {
    my $self = shift;

    return $self->{client}->FindGamesInProgress();
}

1;
