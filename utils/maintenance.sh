#!/bin/bash
arg1="$1"
cd /var/www/beta/scripts
sudo -u www-data /usr/bin/env PERL5LIB=/var/www/totalhost/scripts perl /var/www/totalhost/scripts/maintenance.pl
