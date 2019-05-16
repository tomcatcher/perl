#!/usr/bin/perl

use DBI;
use strict;
use YAML qw(Dump);
use File::stat;
use Sys::Syslog qw(:standard :macros);

my $driver  = "Pg"; 
my $database = "app_mail";
my $dsn = "DBI:$driver:dbname = $database;host = 127.0.0.1;port = 5432";
my $userid = "c_disclaimer";
my $password = "heslo";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) 
	or die $DBI::errstr;

my $statement = qq(SELECT share_name, user_name from public.view_shares);
my $sth = $dbh->prepare( $statement );
my $rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
	print $DBI::errstr;
}

#Logging to syslog

my $program = "DISCLAIMER-pgfetch.pl";

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "pgfetch.pl connected to PGSQL");
closelog();

while(my @row = $sth->fetchrow_array()) {

	my $YAMLfilename = "/etc/postfix/disclaimer-shared-YAML-data/$row[1]_$row[0]";

	if ( ! -e $YAMLfilename) {

		open my $fh, '>', $YAMLfilename;

		print $fh Dump(@row);

		close $fh;

		openlog($program, 'cons,pid', 'user');
		syslog('mail|info', "pgfetch.pl detected new shared disclaimer");
		closelog();

	}

}

$dbh->disconnect();

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "pgfetch.pl disconnected from PGSQL");
closelog();
