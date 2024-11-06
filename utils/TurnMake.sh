#!/bin/bash
cd /var/www/totalhost/scripts
export DISPLAY=':99'
export PERL5LIB="/var/www/totalhost/scripts:$PERL5LIB"
export PATH="$PATH:/var/www/totalhost/scripts"
export WINEPREFIX='/var/www/.wine'
sudo -u www-data /usr/bin/env PERL5LIB=/var/www/totalhost/scripts perl /var/www/totalhost/scripts/TurnMake.pl
