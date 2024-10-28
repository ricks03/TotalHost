#!/usr/bin/perl

my $path = '/home/totalhost/games';
my $gamefile = 'qwerty';

my $game = "$path/$gamefile/$gamefile\.txt";

print $game. "\n";


if (-e $path) { print "-e $path exists\n"; } else { print "-e $path does not exist\n";}
if (-f $path) { print "-f $path exists\n "; } else { print "-f $path does not exist\n";}

if (-e $game) { print "-e $game exists\n"; } else { print "-e $game does not exist\n";}
if (-f $game) { print "-f $game exists\n "; } else { print "-f $game does not exist\n";}
