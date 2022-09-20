package UserRepositoryAccess;

use strict;
use warnings;
use Win32::ODBC;

sub new {
    my $class = shift;
    my $self = {
        config => @_,
    };

    bless $self, $class;

    return $self;
}

sub CountUsers {
    my $self = shift;

    $err = 0;

    # confirm that there's not too many users
    $db = &DB_Open($self->{config});
    $sql = qq|SELECT Count(User.User_ID) AS CountOfUser_ID FROM [User];|;
    &LogOut(100,$sql,$LogFile);
    if (&DB_Call($db,$sql)) { 
        while ($db->FetchRow()) {
            ($count) = $db->Data("CountOfUser_ID");
        }
    } else {
        print STDERR "Unable to get user count\n";
    }
    &DB_Close($db);

    if($err) {
        exit 1;
    }

    return $count;
}

1;
