#!/usr/bin/perl

use strict;
use warnings;
use MIME::Signature;
use Getopt::Long;
use Sys::Syslog qw(:standard :macros);
use Data::Dumper qw(Dumper);

#Setting exit code constants

my $TEMP_FAIL = "75";

#Preparing logging to syslog

eval { openlog('altermail.pl', 'cons,pid', 'user') };

#Getting options

my ($sasl_username, $sasl_sender, $recipient);

GetOptions (
	"sasl_username=s" => \$sasl_username,
	"sasl_sender=s" => \$sasl_sender,
	"recipient=s" => \$recipient
) or exit $TEMP_FAIL;

#Putting disclaimer filenames into variables

my $html_disclaimer_filename = "/etc/postfix/disclaimers/disclaimer-html-${sasl_username}_$sasl_sender.html";
my $txt_disclaimer_filename = "/etc/postfix/disclaimers/disclaimer-txt-${sasl_username}_$sasl_sender.txt";

#Putting disclaimer texts into variables, one for html, one for txt

my $html_disclaimer_content;
my $txt_disclaimer_content;

my $fhh;
my $fht;

eval { open(my $fhh, "< :encoding(UTF-8)", $html_disclaimer_filename) or die "Can not open html disclaimer file $html_disclaimer_filename.\n";

{
	local $/;
	$html_disclaimer_content = <$fhh>;
}

close($fhh);
};

eval { open(my $fht, "< :encoding(UTF-8)", $txt_disclaimer_filename) or die "Can not open txt disclaimer file $txt_disclaimer_filename.\n";

{
        local $/;
        $txt_disclaimer_content = <$fht>;
}

close($fht);
};

#Appending disclaimer

if ($txt_disclaimer_content && $html_disclaimer_content) {

	my $output = MIME::Signature->new(
		plain => $txt_disclaimer_content,
		html => $html_disclaimer_content,
	);

	$output->parse( \*STDIN ) or exit $TEMP_FAIL;

	$output->append;

	my $final_msg = $output->entity();

	open(MAIL, "|/usr/sbin/sendmail -f $sasl_sender -- $recipient") or exit $TEMP_FAIL;
		print MAIL $final_msg->as_string() or close(MAIL);
	close(MAIL);

	syslog('mail|info', "Appended disclaimer for $sasl_sender");

}

else {

	my $msg = do { local $/; <> };

	open(MAIL, "|/usr/sbin/sendmail -f $sasl_sender -- $recipient") or exit $TEMP_FAIL;
        	print MAIL $msg or close(MAIL);
	close(MAIL);

	syslog('mail|info', "Could not append disclaimer, because the disclaimer file does not exist for $sasl_sender");

}

eval { closelog() };
