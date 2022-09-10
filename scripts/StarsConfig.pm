use strict;
use warnings;

package StarsConfig;

sub new{
    my $class = shift;
    my $self = {
    };

    bless $self, $class;

    return $self;
}

sub isFeatureLive {
    my ($self, $feature) = @_;

    if($feature == 'database') {
        if("$^O" =~ /Win/) {
            return 1;
        }
        
        return 0;
    }

    return 0;
}

1;
