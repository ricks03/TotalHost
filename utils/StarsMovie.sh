#!/bin/bash
arg1="$1"
cd /var/www/beta/scripts
sudo -u www-data /usr/bin/env PERL5LIB=/var/www/beta/scripts perl /var/www/beta/scripts/movie_starmapper.pl "$arg1"
