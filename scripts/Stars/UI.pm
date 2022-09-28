package UI;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( 
    display_games
);

%StatusBall = (
    "Finished"             => "/images/"  . "blackball.gif",
    "Awaiting Players"     => "/images/"  . "yellowball.gif",
    "In Progress"          => "/images/"  . "greenball.gif",
    "Delayed"              => "/images/"  . "blueball.gif",
    "Active"               => "/images/"  . "greenball.gif",
    "Idle"                 => "/images/"  . "greyball.gif",
    "Creation in Progress" => "/images/"  . "yellowball.gif",
    "Pending Start"        => "/images/"  . "yellowball.gif",
    "Paused"               => "/images/"  . "yellowball.gif"
);


sub display_games {
	my $type = shift;
	my @games = @{$_[0]};

	my $result =  qq|<h2>$type</h2>\n|;
	$result = "$result<table border=1>\n";

	if(!@games) {
		$result = "$result<tr><td>&nbsp&nbsp No Games Found</td></tr>";
	} else {
		$result = "$result<tr><th></th><th>Name</th><th>Status</th><th>Host</th><th>Description</th></tr>\n";
        foreach (@games) {
            my $status = $_->{Status};
            my $statusText = $_->{StatusText};
            my $ball = $StatusBall{$statusText};
            my $file = $_->{File};
            my $name = $_->{Name};
            my $host = $_->{Description};
            my $desc = $_->{HostName};
			$result = qq|$result<tr>|;
			# Display Game Status
			$result = qq|$result<td><img src="$ball" alt='$status' border="0"></a></td>\n|;
			# change the links for new games and running games, since their results should be different
			if ($status == 6 || $status == 7) {
				#Display Game Name
				$result = qq|$result<td>&nbsp&nbsp<a href=/scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$file>$name</a></td>|;
			} else {
				#Display Game Name
				$result = qq|$result<td>&nbsp&nbsp<a href=/scripts/page.pl?lp=game&cp=show_game&rp=show_news&GameFile=$file>$name</a></td>|;
			}
			# Display Game Status
			$result = qq|$result<td>$status</td>\n|;
			# Display Game Host
			$result = qq|$result<td>$host</td>\n|;
			# Display Game Description
			$result = qq|$result<td>$desc</td>\n|;
			$result = qq|$result</tr>\n|;
		}
	}
	$result = "$result</table>\n";

	return $result;
}