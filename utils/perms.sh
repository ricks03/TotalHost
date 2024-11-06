#!/bin/bash
arg1="$1"
cd /var/www/totalhost/scripts
/usr/bin/env PERL5LIB=/var/www/totalhost/scripts perl /var/www/totalhost/scripts/perms.pl "$arg1"
