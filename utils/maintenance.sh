#!/bin/bash
arg1="$1"
cd /var/www/totalhost/scripts
sudo -u www-data /usr/bin/env PERL5LIB=/var/www/totalhost/scripts perl /home/totalhost/utils/maintenance.pl
