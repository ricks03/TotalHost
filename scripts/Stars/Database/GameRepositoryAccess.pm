package GameRepositoryAccess;

use strict;
use warnings;

use Win32::ODBC;
use CGI::Carp;

@statuses = (
    'Pending Start',
    'Pending Closed',
    'Active','Delayed',
    'Paused',
    'Need Replacement',
    'Creation in Progress',
    'Awaiting Players',
    '',
    'Finished'
);

sub new {
    my $class = shift;
    my $self = {
        config => shift,
    };

    bless $self, $class;

    return $self;
}

sub FindGamesInProgress {
    my $self = shift;

    $db = new Win32::ODBC($self->{config});
    if(!$db) {
        confess("could not create DB connection: " . Win32::ODBC::Error());
    }

    $db->Sql("SELECT * from Games WHERE GameStatus = 2");
    ($ErrNum, $ErrText, $ErrConn) = $db->Error();
    if($ErrNum) {
        confess("error reading in-progress games" . $ErrNum . " * " . $ErrText . "*" . $ErrConn . "\n")
    }

	if (!$failed) {
		while ($db->FetchRow()) {
 	    ($GameName, $GameFile, $GameStatus, $GameDescrip, $HostName) = $db->Data("GameName", "GameFile", "GameStatus", "GameDescrip", "HostName");
        push(@games, %(
            Status      => $GameStatus,
            StatusText  => $statuses[$GameStatus],
            File        => $FetchRow,
            Name        => $GameName,
            Description => $GameDescrip,
            HostName    => $HostName
        ));
	} else {
        confess("database error finding games in progress: $failed");
    }
    
	$db->Close();

    return @games;
}

1;
