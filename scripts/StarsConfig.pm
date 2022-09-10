use strict;
use warnings;

package StarsConfig;

sub new{
    my $class = shift;
    my $self = {
        debug => "$ENV{debug}",
    };

    bless $self, $class;

    return $self;
}

1;
