#!/usr/bin/perl

use strict;

#use Win32::HideConsole;
use File::Slurp;
use Cwd;
use LWP::UserAgent;
use Digest::MD5  qw(md5 md5_hex md5_base64);

print "Starting up The Connectivity Test Service, You're welcome!\n";
#hide_console();


my $cwd = getcwd();
my $datafile = $cwd . '/rawdata.txt';
my $configfile =  $cwd . '/config.txt';
my ($configdata,$sites) = &configreader;


my %sites = %$sites;

my %configdata = %$configdata;
my $increment = $configdata{increment};
my $serverurl = $configdata{serverurl};



while (1) {

	my $ip = &ipgiver();
		$sites{'public'} = $ip;
	my @localtime = localtime();
	$localtime[4] = $localtime[4] + 1;
	for (my $n =0; $n < @localtime; $n++) {
		$localtime[$n] = zeroadder($localtime[$n]);
	}
	
	my $date = $localtime[4] . "/$localtime[3]/". (1900 + $localtime[5]);

	my $time = "$localtime[2]:$localtime[1]:$localtime[0]";
	my $count = keys %sites;

	while (my ($keys,$values) = each(%sites)) {

		my $pinger = pinger($values);
		my @value = @$pinger;
		
		
		my $data =  {
			type => $keys, 
			url => $values,
			response_time => $value[1],
			date => $date,
			time => $time,

			};



			open my $fh, '>>', $datafile;
		
		if ($value[2] =~ /Reply/g ) {

			print $fh "$time-$date-$keys-$values-$value[1]-$increment-$ip??" or die $!;
			print "$time\t$date\t$keys\t$values\t$value[1]\n";


			
		}
		else {
			print $fh "$time-$date-$keys-$values-none-$increment??";
			print "No Connection!";
		}
			close $fh;
	sleep($increment / $count);

	}
	if ($ip ne 'NULL') {
		&dataposter();
		$ip = undef;
	}

}

sub pinger() {
	my $site = shift;
	my $ping = `ping $site -n 1 -w 200`;
	
	my @ping = split('\n',$ping);
	$ping = $ping[2];

	@ping = split(' ',$ping);
	my $host = $ping[2];
	my $status = $ping[0];
	$host =~ s/://g;
	my $time = $ping[4];
	my @time = split(/=|</,$time);
	$time = $time[1];
	
	my $returner = [$host, $time, $status];
	
	return $returner;
}

sub ipgiver() {
	my $ua = LWP::UserAgent->new();
	$ua->timeout(2);
	my $server = $serverurl . 'ipgiver.php';
	my $page = $ua->get($server);
	my $ip = $page->content;
	if ($page->is_success) {
	return $ip;
	}
	else { return "NULL"; }
}


sub zeroadder() {
	my $data = shift;
	if ($data =~ /^[0-9]$/g) {
		$data = '0' . $data;
	}
	return $data;
}


sub idsetter() {
	my $id = `wmic csproduct get uuid`;
	my @id = split('\n', $id);
	return $id[1];

}


sub dataposter() {

	my $raw_text = read_file( $datafile );
		my @datarows = split('\?\?', $raw_text);
	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new();
	$ua->timeout(2);
	my $server = $serverurl . 'receiver.pl';

	my $id = &idsetter();

	# Now that we have the data, let's break it apart for easier handling
	# We need to send the raw data first so the server can process it and
	# put it into proper categories.



	my $page = $ua->post($server,
			{"data" => $raw_text,
			"auth" => $id,
			"postalcode" => $configdata{PostalCode}
			 });
			 
		my $digest = md5_base64($id,$raw_text);

		if ($page->is_success) {
			if ($page->content eq $digest) {
				unlink $datafile;

				return 0;	
				}
		}
		else {
			print $page->message;
			return 1;
			}
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
	return (\%configdata,\%hosts);
}
