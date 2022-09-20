package UserRepository;

my $isWindows = ("$^O" =~ "MSWin32");

use if $isWindows,  Stars::Database::UserRepositoryAccess;
use if !$isWindows, Stars::Database::UserRepositoryPostgres;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $client;

    if($isWindows) {
        $client = new UserRepositoryAccess(@_);
    } else {
        $client = new UserRepositoryPostgres(@_);
    }
    my $self = {
        client => $client,
    };

    bless $self, $class;

    return $self;
}

sub CountUsers {
    my $self = shift;

    return $self->{client}->CountUsers();
}

1;
