#!/bin/bash
arg1="$1"
cd /var/www/totalhost/scripts
/usr/bin/env PERL5LIB=/var/www/totalhost/scripts perl /home/totalhost/utils/perms.pl "$arg1"
