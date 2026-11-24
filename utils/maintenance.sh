#!/bin/bash
arg1="$1"
cd /var/www/beta/scripts
sudo -u www-data /usr/bin/env PERL5LIB=/var/www/beta/scripts perl /home/beta/utils/maintenance.pl "$arg1"
