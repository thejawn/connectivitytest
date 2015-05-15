#!/usr/bin/perl

# This program reads the config data, gets the right site, and then opens chrome with the
# right link for your computer. After running once, you could just bookmark the page and
# never use this script again. 

use strict;
use warnings;
use Cwd;
use File::Slurp;
use Digest::MD5  qw(md5 md5_hex md5_base64);

my $cwd = getcwd();
my $configfile =  $cwd . '/config.txt';

my ($configdata) = &configreader;

my %configdata = %$configdata;
my $url = $configdata{serverurl};

my $server = $url . "receiver.pl";
my $charts = $url . "charts.pl?id=" . &idsetter();


my $exec = system("start chrome $charts");


sub idsetter() {
	my $id = `wmic csproduct get uuid`;
	my @id = split('\n', $id);
	my $digest = md5_base64("BALLS!" . $id[1] . " EVERYWHERE!");
	return $digest;

}


sub configreader() {
	my (%configdata, %hosts);
	my $data = read_file($configfile);
	my @data = split('\n', $data);

		foreach my $line (@data) {
			my @linesplit = split('=',$line);
			$linesplit[0] =~ s/^\s+|\s+$//g;
			$linesplit[1] =~ s/^\s+|\s+$//g;
			
			my $header = $linesplit[0];
			my $value = $linesplit[1];
			
			if ($value =~ /\>/) {
				$value =~ s/>//g;
				$value =~ s/^\s+|\s+$//g;
				# It is a host, goes in the host hash
				$hosts{$header} = $value;
				
			}
			else {
				$configdata{$header} = $value;
			}
		}
	return (\%configdata);
}
