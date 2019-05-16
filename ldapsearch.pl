#!/usr/bin/perl

use strict;
use warnings;
use Net::LDAP;
use YAML qw(Dump);
use File::stat;
use Date::Parse;
use DateTime::Format::Strptime;
use Sys::Syslog qw(:standard :macros);

#Setting LDAP connection parameters

my $userToAuthenticate = "ttudja1\@domain.terragroup.cz";
my $passwd = "#mKimg17";
my $searchString = '(&(objectClass=person)(mail=*))';
my $attrs = [ 'mail', 'displayName', 'telephoneNumber', 'title', 'whenchanged' ];
my $base = "DC=domain,DC=terragroup,DC=cz";
my $ldap = Net::LDAP->new ( "10.224.0.4" ) or die "$@";
my $mesg = $ldap->bind ( "$userToAuthenticate",
                      password => "$passwd",
                      version => 3 );          # use for changes/edits
  my $result = $ldap->search ( base    => "$base",
                               scope   => "sub",
                               filter  => "$searchString",
                               attrs   =>  $attrs
                             );
my $href = $result->as_struct;
my @arrayOfDNs  = keys %$href;        # use DN hashes

#Logging to syslog

my $program = "DISCLAIMER-ldapsearch.pl";

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "ldapsearch.pl connected to AD");
closelog();

#Iterating each entry

foreach ( @arrayOfDNs ) {
  my $valref = $$href{$_};

my $filename = "/etc/postfix/disclaimer-YAML-data/$$href{$_}{'mail'}[0]";

#Removing whitespaces from within the filename

$filename =~ tr/ //ds;

#Timestamping

my $timestamp_mod;

#If file does not exist, put 10 into $timestamp_mod so it will always look older than the AD entry

if ( ! -e $filename) {
	$timestamp_mod = "10";
	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "ldapsearch.pl detected a new AD entry: $filename");
	closelog();
}

#If file exists, take it's mtime and put it into $timestamp_mod for the comparison, which happens later

if ( -e $filename) {
	my $f_stats = stat($filename);
	$timestamp_mod = $f_stats->mtime;
}

#Getting AD timestamp of current AD entry in AD format and converting it to ISO8601 format

my $AD_whenchanged = $$href{$_}{'whenchanged'}[0];

my $strp = DateTime::Format::Strptime->new(
	pattern   => '%Y%m%d%H%M%S',
);
my $ISO8601time = $strp->parse_datetime( $AD_whenchanged );

#Constructing UNIX time from ISO-8601 time from above AD timestamping

my $UNIXtime = str2time($ISO8601time);

#Comparing timestamps. If AD timestamp is higher than file modification timestamp, jump to next file

if ($UNIXtime < $timestamp_mod) {
	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "ldapsearch.pl skipping: $filename");
	closelog();
	next;
}

#Open the file for writing

open my $fh2, '>', $filename;

#Writing AD entries to each file, in YAML format

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "ldapsearch.pl updating $filename");
closelog();

print $fh2 Dump($$href{$_});

#Closing file

close $fh2;
}

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "All files closed by ldapsearch.pl");
closelog();
