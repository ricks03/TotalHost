cd /var/www/totalhost/scripts
export DISPLAY=":99"
export PERL5LIB=/var/www/totalhost/scripts:$PERL5LIB
export PATH="$PATH:/var/www/totalhost/scripts"
#export WINEDLLOVERRIDES="winex11.drv=b" # Disable wine clipboard. I don't seem to need this with xclip installed.
#export WINEDLLOVERRIDES="mscoree,mshtml=" #                      . I don't seem to need this with xclip installed.
#xhost +SI:localuser:www-data
sudo -u www-data PERL5LIB=/var/www/totalhost/scripts perl /var/www/totalhost/scripts/TurnMake.pl
