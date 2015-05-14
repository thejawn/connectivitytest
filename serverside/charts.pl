#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use CGI;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use WWW::Shorten::TinyURL;

my $cgi = new CGI;
my $dbh = DBI->connect("dbi:mysql:database=connectivity;host=localhost",
        "connectivity",
        "connectivity",
        {'RaiseError' => 1 }
        ) or die;

my $id = $cgi->url_param('id');
my $interval = $cgi->url_param('interval');
my $distance = $cgi->url_param('distance');
my $action = $cgi->url_param('action');
my $authid = &authcheck();

my $tinyurl = makeashorterlink("https://automateeverything.ca/clients/connectivity/charts.pl?id=$id");

	my @time = localtime;
	$time[4] = $time[4] + 1;
	for (my $n =0; $n < @time; $n++) {
		$time[$n] = zeroadder($time[$n]);
	}

	my $year = $time[5] + 1900;






# Get the proper data first

my ($overall,$currentip,$starttime,$endtime) = &overallgetter('all');
my $remoteoutages = &realoutages('remote');
my $dnsoutages = &realoutages('dns');
my $othernodes = &othernodes();
our $html = <<'END';
	<html><head><title>Internet Connectivity Monitor</title>
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js"></script>
	<script src="chartjs/Chart.min.js"></script>
	<link href="semantic-ui/semantic.css" rel="stylesheet" type="text/css"/>
	<script src="semantic-ui/semantic.js"></script>
	
END
$html .= "
<h1 align=\"center\">Connectivity of $currentip starting $starttime and ending $endtime</h1>
<h3 align=\"center\"><a href=\"$tinyurl\">$tinyurl</a> (so you can easily pass on this information)</h3>
<br> <h4 align=\"center\" onClick=\"alert('You are looking at the results of a ping test running on a computer. Every few seconds the client program will ping four servers (DNS,Public (which is the Public IP address), The Router, and Google.com), if the ping is successful, the response time and result are uploaded to a server. If the pings are not successful, they are stored on a file on the client computer, and uploaded when the connection becomes available again. You are looking at the sorted result of that data.')\">What am I looking at!?</h4>
	</head>
	<body>

	<h1>$overall</h1>
	<h3 style=\"padding-left:20px\">Other Nodes</h3>
	$othernodes
	<h1 style=\"padding-left:20px\">All Remote outages over 10 seconds</h1><br>
	$remoteoutages<br>

	</body>
	<footer class=\"footer\"></footer>
	</html>";
print $html;


my $temp = "<h2 class=\"ui center aligned icon header\">
  <i class=\"circular signal icon\"></i>
  Charts
</h2>
<div class=\"4 fluid ui  buttons\">
  <div class=\"ui button\">Hour</div>
  <div class=\"ui button\">Day</div>
  <div class=\"ui button\">Week</div>
  <div class=\"ui button\">Month</div>
</div>";


sub overallgetter() {
	my $timeperiod = shift;
	my ($returner,$currentip,$starttime,$endtime);
	my %periods = (
		all => "select * from pings where authid=?",
		day => "select * from pings where authid=?",
		week => "select * from pings where authid=?",
		month => "select * from pings where authid=?",
		year => "select * from pings where authid=?"
		);

	my @periods = qw/all /;#day week month year/;
	my $count = 0;

		my $overquery;
		my $header = ucfirst($timeperiod);

		$overquery = $periods{$timeperiod};

		my $oversth = $dbh->prepare($overquery);
		$oversth->execute($authid);
		my (%totals,%down,%url);
		my $nodecount = &usercounter() - 1;
		while (my @values = $oversth->fetchrow_array) {
			$count++;
			my $type = $values[1];
			$url{$type} = $values[2];
			my $response = $values[3];
			my $date = $values[4];
			my $time = $values[5];

			if ($count == 1) {
				$starttime = "$time $date";
			}
			if ($count == $oversth->rows) {
				$endtime = "$time $date";
			}

			my $ipaddress = $values[6];
			if ($ipaddress) {
				$currentip = $ipaddress;
			}
			my $increment = $values[7];

			if ($response eq 'none') {
				$totals{$type} = $totals{$type} + $increment;
				$down{$type} = $down{$type} + $increment;
			}
			else {
				$totals{$type} = $totals{$type} + $increment;
			}
		}
		$returner .= "<h1 style=\"padding-left:20px\"> $header</h1><br><table class=\"ui padded striped table\"><tr><th>Type</th><th>Url Pinged</th><th>Downtime (S)</th><th>Total Logged Time (S)</th>
			<th>Downtime Percentage<div onClick=\"alert('Out of all the recorded time, this was the amount of time that the pings were unsuccessful, sometimes they are a fluke, if any of these are significantly higher than the others, there is likely something wrong with the connection to that node');\">?</div></th><th>Average Downtime Percentage (based on $nodecount others)<div onClick=\"alert('The program is running on other devices as well, this is the average of all of the other $nodecount nodes results. This node is not included in the average.');\">?</div></th></tr>"; 
		my $scriptmaker = "<script>
				\$(document).ready(function() {";

		while (my ($keys,$values) = each %totals ) {
			my $url = $url{$keys};
			my $downtime = $down{$keys};
			my $downpercent = sprintf("%.6f", $downtime / $values);
			$downpercent = &percentageprogressbar($downpercent,$keys);
			my $averagepercent = &averagemaker($keys);
			my $morekeys = 'more' . $keys;
			$averagepercent = &percentageprogressbar($averagepercent,$morekeys);


		$scriptmaker .= "
			\$('#$keys').progress();
			\$('#more$keys').progress();";
			$keys = ucfirst($keys);
			$returner .= "<tr><td class=\"center aligned\">$keys</td><td class=\"center aligned\">$url</td><td class=\"center aligned\">$downtime</td><td class=\"center aligned\">$values</td><td  class=\"center aligned\">$downpercent</td><td  class=\"center aligned\">$averagepercent</td></tr>";


		}
		$scriptmaker .= "});</script>";
		$returner .= "</table>$scriptmaker<br>";
	
	return ($returner,$currentip,$starttime,$endtime);
}


sub averagemaker() {
	my $type = shift;
	my $query = "select * from pings where type=? and NOT authid=?";
	my $avsth = $dbh->prepare($query);
	$avsth->execute($type,$authid);
		my (%totals,%down,%url);
		while (my @values = $avsth->fetchrow_array) {

			my $datatype = $values[1];
			$url{$type} = $values[2];
			my $response = $values[3];
			my $date = $values[4];
			my $time = $values[5];
			my $ipaddress = $values[6];
			my $increment = $values[7];
			if ($datatype eq $type) {
				if ($response eq 'none') {
					$totals{$type} = $totals{$type} + $increment;
					$down{$type} = $down{$type} + $increment;
				}
				else {
					$totals{$type} = $totals{$type} + $increment;
				}
			}
		}
	return (sprintf("%.6f", $down{$type}/$totals{$type}));
}


sub percentageprogressbar() {
	my $downpercent = shift;

	my $type = shift;

	my $returner = "<div class=\"ui striped red progress\" data-percent=\"$downpercent\" id=\"$type\">
  		<div class=\"bar\"></div>";
	$downpercent = $downpercent * 100 ;
	$returner .= "
		  <div class=\"label\">$downpercent %</div>
		</div>";

	return $returner;
}

sub authcheck() {
my $authquery = "select * from users";
my $authsth = $dbh->prepare($authquery);
$authsth->execute();
while (my @authcheck = $authsth->fetchrow_array) {
	my $idcheck = $authcheck[0];
	my $authcheck = $authcheck[1];

	my $digest = md5_base64("BALLS!" . $authcheck . " EVERYWHERE!");

	if ($digest eq $id) {
		return $idcheck;
	}
}

}

sub realoutages() {
	my $type = shift;
	my $realquery = "select * from pings where authid=? and type=? and response='none' and increment > '10' ORDER BY id DESC";
	my $realsth = $dbh->prepare($realquery);
	$realsth->execute($authid,$type);
	my $response = "<table class=\"ui padded striped table\"><tr><th>Time</th><th>Date</th><th>Length of Outage in Seconds</th></tr>";
	while (my @values = $realsth->fetchrow_array) {
			my $type = $values[1];
			my $url = $values[2];

			my $date = $values[4];
			my $time = $values[5];
			my $ipaddress = $values[6];
			my $increment = $values[7];

			$response .= "<tr><td class=\"center aligned\">$time</td><td class=\"center aligned\">$date</td><td class=\"center aligned\">$increment</td></tr>";
	}

	return $response . "</table>";
}

sub zeroadder() {
	my $data = shift;
	if ($data =~ /^[0-9]$/g) {
		$data = '0' . $data;
	}
	return $data;
}


sub othernodes() {
	my $authquery = "select * from users";
	my $authsth = $dbh->prepare($authquery);
	$authsth->execute();
	my $returner = "<div style=\"padding-left:20px\" class=\"ui align centered horizontal list\">";
	my $domain = "https://automateeverything.ca/clients/connectivity/charts.pl?id=";
	my $count;
	while (my @authcheck = $authsth->fetchrow_array) {
		my $idcheck = $authcheck[0];
		my $authcheck = $authcheck[1];
		unless ($idcheck == $authid) {
			$count++;
			my $digest = md5_base64("BALLS!" . $authcheck . " EVERYWHERE!");
			my $domain = $domain . $digest;
			$returner .= "<div class=\"item\"><a href=\"$domain\"><i class=\"circular sitemap icon\"></i>Other $count</a></div>";
		}
	}
	return $returner . "</div>";

}


sub usercounter() {

	my $query = "select * from users;";
	my $sth = $dbh->prepare($query);
	$sth->execute();

	return $sth->rows;

}
