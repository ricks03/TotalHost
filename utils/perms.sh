#!/bin/bash
arg1="$1"
cd /var/www/beta/scripts
/usr/bin/env PERL5LIB=/var/www/beta/scripts perl /home/beta/utils/perms.pl "$arg1"
