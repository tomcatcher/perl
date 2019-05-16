#!/usr/bin/perl

use strict;
use warnings;
use Template;
use YAML ();
use utf8;
use Text::Trim;
use Scalar::MoreUtils qw(empty);
use File::stat;
use Sys::Syslog qw(:standard :macros);

my @files = </etc/postfix/disclaimer-YAML-data/*.cz>;

#Logging to syslog

my $program = "DISCLAIMER-deserialize.pl";

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "deserialize.pl loaded YAML data");
closelog();

foreach my $file (@files) {

	my $f_stats = stat($file);
	my $timestamp_mod = $f_stats->mtime;

	open my $fh, '<:encoding(UTF-8)', "$file" or die "Can't open YAML file: $!";

	my $hash = YAML::LoadFile($fh);

	my $displayname = $$hash{'displayname'}[0];
	if(not empty($displayname)) {
	utf8::encode($displayname);
	}
	my $mail = $$hash{'mail'}[0];
	my $telephonenumber = $$hash{'telephonenumber'}[0];
	my $title = $$hash{'title'}[0];
	if(not empty($title)) {
	utf8::encode($title);
	}

	#Removing leading and trailing whitespaces from all entries

	trim $displayname;
	trim $mail;
	trim $telephonenumber;
	trim $title;

	#Removing whitespaces from within $mail string

	$mail =~ tr/ //ds;

	#Preparing templating

	my $template_file_html = "template-html.tt";
	my $output_file_html = "/etc/postfix/disclaimers/disclaimer-html-${mail}_$mail.html";
	my $template_file_txt = "template-txt.tt";
	my $output_file_txt = "/etc/postfix/disclaimers/disclaimer-txt-${mail}_$mail.txt";

	my $timestamp_disclaimer_html_mod;

	if ( -e $output_file_html) {
		my $fd_stats = stat($output_file_html);
		$timestamp_disclaimer_html_mod = $fd_stats->mtime;
	}

	if ( ! -e $output_file_html) {
		$timestamp_disclaimer_html_mod = "10";
		openlog($program, 'cons,pid', 'user');
		syslog('mail|info', "deserialize.pl detected new YAML data $file");
		closelog();
	}

	my $template_html_for_stat = "/etc/postfix/disclaimer-templates/template-html.tt";
	my $template_txt_for_stat = "/etc/postfix/disclaimer-templates/template-txt.tt";

	my $fth_stats = stat($template_html_for_stat);
	my $timestamp_template_html_mod = $fth_stats->mtime;
	my $ftt_stats = stat($template_txt_for_stat);
	my $timestamp_template_txt_mod = $ftt_stats->mtime;

	if ($timestamp_template_html_mod > $timestamp_disclaimer_html_mod || $timestamp_template_txt_mod > $timestamp_disclaimer_html_mod) {
		$timestamp_disclaimer_html_mod = "5";

	}

	if ($timestamp_disclaimer_html_mod > $timestamp_mod) {

		openlog($program, 'cons,pid', 'user');
		syslog('mail|info', "deserialize.pl skipping existing entry $file");
		closelog();
		next;
	}

	my $config = {
		INCLUDE_PATH =>[ "/etc/postfix/disclaimer-templates/" ],
	};

	my $vars = {
		displayname     => $displayname,
		mail            => $mail,
		telephonenumber => $telephonenumber,
		title           => $title,
	};

	#Templating

	my $template = Template->new($config);

	$template->process($template_file_html, $vars, $output_file_html)
		|| die "Template process failed: ", $template->error(), "\n";

	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "deserialize.pl wrote new html template $output_file_html");
	closelog();

	my $template_txt = Template->new($config);

	$template_txt->process($template_file_txt, $vars, $output_file_txt)
		|| die "Template process failed: ", $template->error(), "\n";

	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "deserialize.pl wrote new txt template $output_file_txt");
	closelog();

}

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "deserialize.pl finished it's work");
closelog();
