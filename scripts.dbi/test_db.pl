#!/usr/bin/perl

do 'config.pl';
use TotalHost;

# Command to check the status of mariadb
my $status = `systemctl is-active mariadb 2>/dev/null`;
chomp $status;

# If the service is not active, create the output file
if ($status ne 'active') {
    my $file = $Dir_Log  . '/mariadb_down.txt';
    
    # Write to File
    open(my $fh, '>', $file) or die "Could not open file '$file' $!";
    print $fh "MariaDB service is down on TotalHost\n";
    close $fh;
    print "MariaDB is not running. Output file created: $file\n";
    
    # Send an email notification
    my $smtp = &Mail_Open;   
    my $Subject = 'MariaDB is down on TotalHost';
    my $Message = ''; 
    
    # Attempt to restart MariaDB
    my $restart_status = system("systemctl restart mariadb");
    if ($restart_status == 0) {
        print "MariaDB has been restarted successfully.\n";
        $Message .= "MariaDB has been restarted successfully.\n";
    } else {
        warn "Failed to restart MariaDB.\n";
        $Message .= "Failed to restart MariaDB\n";
    }
    
    &Mail_Send($smtp, $mail_from, $mail_from, $Subject, $Message); # notify site host
    &Mail_Close($smtp);
    
} else {
    print "MariaDB is running.\n";
}