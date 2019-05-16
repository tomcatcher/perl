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

my @files = </etc/postfix/disclaimer-shared-YAML-data/*.cz>;

#Logging to syslog

my $program = "DISCLAIMER-deserialize-shared.pl";

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "deserialize-shared.pl loaded YAML data");
closelog();

foreach my $file (@files) {

	my $f_stats = stat($file);
	my $timestamp_mod = $f_stats->mtime;

	open my $fh, '<:encoding(UTF-8)', "$file" or die "Can't open YAML file: $!";

	my @array = YAML::LoadFile($fh);

	my $sharedmail = $array[0];
	my $mail = $array[1];

	my $template_file_html = "template-shared-html.tt";
	my $output_file_html = "/etc/postfix/disclaimers/disclaimer-html-${mail}_$sharedmail.html";
	my $template_file_txt = "template-shared-txt.tt";
	my $output_file_txt = "/etc/postfix/disclaimers/disclaimer-txt-${mail}_$sharedmail.txt";

	my $timestamp_disclaimer_html_mod;

	if ( -e $output_file_html) {
		my $fd_stats = stat($output_file_html);
		$timestamp_disclaimer_html_mod = $fd_stats->mtime;

		openlog($program, 'cons,pid', 'user');
		syslog('mail|info', "deserialize-shared.pl skipping existing entry $output_file_html");
		closelog();
	}

	if ( ! -e $output_file_html) {
		$timestamp_disclaimer_html_mod = "10";

		openlog($program, 'cons,pid', 'user');
		syslog('mail|info', "deserialize-shared.pl detected new shared disclaimer $output_file_html");
		closelog();
	}

	my $template_html_for_stat = "/etc/postfix/disclaimer-templates/template-shared-html.tt";
	my $template_txt_for_stat = "/etc/postfix/disclaimer-templates/template-shared-txt.tt";

	my $fth_stats = stat($template_html_for_stat);
	my $timestamp_template_html_mod = $fth_stats->mtime;
	my $ftt_stats = stat($template_txt_for_stat);
	my $timestamp_template_txt_mod = $ftt_stats->mtime;

	if ($timestamp_template_html_mod > $timestamp_disclaimer_html_mod || $timestamp_template_txt_mod > $timestamp_disclaimer_html_mod) {
		$timestamp_disclaimer_html_mod = "5";
	}

	if ($timestamp_disclaimer_html_mod > $timestamp_mod) {
		next;
	}

	my $config = {
		INCLUDE_PATH =>[ "/etc/postfix/disclaimer-templates/" ],
	};

	my $vars = {
        	mail            => $mail,
	        sharedmail => $sharedmail,
	};

	my $template = Template->new($config);

	$template->process($template_file_html, $vars, $output_file_html)
		|| die "Template process failed: ", $template->error(), "\n";

	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "deserialize-shared.pl wrote shared html disclaimer $output_file_html");
	closelog();

	my $template_txt = Template->new($config);

	$template_txt->process($template_file_txt, $vars, $output_file_txt)
		|| die "Template process failed: ", $template->error(), "\n";

	openlog($program, 'cons,pid', 'user');
	syslog('mail|info', "deserialize-shared.pl wrote shared txt disclaimer $output_file_txt");
	closelog();
}

openlog($program, 'cons,pid', 'user');
syslog('mail|info', "deserialize-shared.pl finished it's work");
closelog();
