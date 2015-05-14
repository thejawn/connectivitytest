#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use DBI;
use Digest::MD5  qw(md5 md5_hex md5_base64);
use File::Slurp;


my $cgi = new CGI;




my $dbh = DBI->connect("dbi:mysql:database=connectivity;host=localhost",
        "connectivity",
        "connectivity",
        {'RaiseError' => 1 }
        ) or die;


my $auth = $cgi->param('auth');

my $postalcode;
if ($cgi->param('postalcode')) {
	$postalcode = $cgi->param('postalcode');
}
else {
	$postalcode = "N0N1J4";
}
my $authid = &authinserter($auth);

my $data = $cgi->param('data');

&datainserter($data,$authid);

sub datainserter() {
	my $data = shift;
	my $authid = shift;

	my @datarows = split('\?\?', $data);

	foreach my $datarow (@datarows) {


		my @split = split('-',$datarow);
		
		my $time = $split[0];
		my $date = $split[1];
		my $type = $split[2];
		my $url = $split[3];
		my $increment = $split[5];
		my $originalincrement = $increment;
		my $ip = $split[6];
		my ($response);
		if ($split[-1] eq "none") {
			$response = $split[-1];
		}
		else {
			$split[4] =~ s/ms//g;
			$response = $split[4];
		}

		if ($authid eq '2' and $type eq 'remote') {
			my $query = "select * from temp";
			my $selsth = $dbh->prepare($query);
			$selsth->execute();
			my $count;
			while (my @balls = $selsth->fetchrow_array) {
				$count = $balls[1];
				$count = $count + $increment;
			}
			my $insquery = "update temp set increment=? where id='1'";
			my $insth = $dbh->prepare($insquery);
			$insth->execute($count);

		}



		if ($response) {
		# To avoid using ridiculous amounts of storage, if we can add to the last entry, lets do it.
			my $denied;
			my $selquery = "Select * from pings where authid=? and type=?";
			my $selsth = $dbh->prepare($selquery);
			$selsth->execute($authid,$type);
			my $rowcount = $selsth->rows;
			my $count = 0;
			while (my @selrows = $selsth->fetchrow_array) {
				$count++;
				if ($count == $rowcount) {
					my $oldid = $selrows[0];
					my $oldresponse = $selrows[3];
					my $oldincrement = $selrows[7];
					if ($response ne 'none' && $oldresponse eq $response) {
						my ($upper,$lower) = $oldresponse + 2, $oldresponse - 2;
						if ($response < $upper && $response > $lower) {
							$increment = $oldincrement + $increment;
							my $alterquery = "UPDATE pings SET increment=?, response=? where id=?";
							my $altsth = $dbh->prepare($alterquery);
							$altsth->execute($increment,$response,$oldid);
						}
					}
					elsif ($response eq 'none' && $oldresponse eq $response) {
						$increment = $oldincrement + $increment;
						my $alterquery = "UPDATE pings SET increment=?, response=? where id=?";
						my $altsth = $dbh->prepare($alterquery);
						$altsth->execute($increment,$response,$oldid);
					
					}
					else { $denied = 'ya'; }
				}
				
				
			}

			if ($rowcount == 0 || $denied eq 'ya') {
				my $insquery = "insert into pings (type,url,response,date,time,authid,ipaddress,increment) values (?,?,?,?,?,?,?,?)";
				my $inssth = $dbh->prepare($insquery);
				$inssth->execute($type,$url,$response,$date,$time,$authid,$ip,$originalincrement);
			}
		}
	}


	# To delete the previous content, we make sure we were sent the right stuff, and all of it.
	my $digest = md5_base64($auth,$data);
	print $digest;
}



sub authinserter() {



	# First, see if the auth already exists?
	my $query = "Select * from users where authcode=?";

	my $selsth = $dbh->prepare($query);

	$selsth->execute($auth);

	my $authid;
	if ($selsth->rows > 0) {
		while (my @authid = $selsth->fetchrow_array) {
			$authid = $authid[0];

			return $authid;
		}
	}
	else {
		my $insauth = "insert into users (authcode,postalcode) values(?,?)";
		my $insth = $dbh->prepare($insauth);
		$insth->execute($auth,$postalcode);

		&authinserter();
	}
	


}
