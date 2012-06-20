#!/usr/bin/perl
#
# Google Contacts for Mutt
#
# A simple perl script which helps you to integrate your
# Google Contact list with mutt email client.
# For more details view README
#
# license: http://www.gnu.org/licenses/gpl-2.0.html
# author: Lajos Koszti <ajnasz@ajnasz.hu>

use strict;
use LWP::UserAgent;
use XML::Simple;
use Encode;
use Config::Simple;
use Data::Dumper;
use File::Basename;
use lib dirname($0) . '/lib/';
use Contacts;

my $userconf = $ENV{'HOME'} . '/.google.ini';
my $defaultconf = (dirname($0)) . '/google.default.ini';


# user configuration file exists
unless (-e $userconf) {
  print "user configuration file does not exists\n";
  exit;
}

chmod 0600, $userconf;

my $cfg_default = new Config::Simple($defaultconf);
my $cfg_user = new Config::Simple($userconf);

unless ($cfg_default) {
  print "default configuration file not found\n";
  print $defaultconf . "\n";
  exit;
}
unless ($cfg_user) {
  print "please set up you account in $userconf:\n\n";
  print "[account]\n";
  print "email = 'example\@gmail.com'\n";
  print "password = 'yourPassword'\n";
  exit;
}

$cfg_default->import_names('GOOGLE');
$cfg_user->import_names('GOOGLE');

my $conf = {};

Config::Simple->import_from($defaultconf, $conf);
Config::Simple->import_from($userconf, $conf);

my $searchterm = $ARGV[0];
if(!$searchterm) {
  $searchterm = '';
}
my $decode_searchterm=decode('utf-8', $searchterm);
$searchterm=$decode_searchterm;
my $account_email;
my $account_password;
my $contacts;

my $login_url = $conf->{'login.url'};
my $account_type  = $conf->{'account.type'};
my $application_service = $conf->{'application.service'};
my $client_name => $conf->{'client.name'};
my @found;


if($conf->{'account.email'} && $conf->{'account.password'}) {
	@found = (@found, getContactsForAccount($conf->{'account.email'}, $conf->{'account.password'}, $searchterm));
}

my $i = 1;
while($conf->{'account' . $i . '.email' && 'account' . $i . '.password'}) {
	@found = (@found, getContactsForAccount($conf->{'account' . $i . '.email'}, $conf->{'account' . $i . '.password'}, $searchterm));
	$i++;
}

printResults(uniq(@found));






sub getContactsForAccount {
	my $account_email = shift;
	my $account_password = shift;
	my $searchterm = shift;
	$contacts = Contacts->new({
		'LOGIN_URL' => $login_url,
		'ACCOUNT_TYPE' => $account_type,
		'APPLICATION_SERVICE' => $application_service,
		'CLIENT_NAME' => $client_name,
		'ACCOUNT_EMAIL' =>  $account_email,
		'ACCOUNT_PASSWORD' => $account_password,
	});
	return $contacts->search($searchterm);
}
sub uniq {
	return keys %{{map { $_ => 1} @_ }}
}
sub printResults {
  my @results = @_;
	# print 'results: ' . @results, "\n";
  foreach(@results) {
    print encode('utf-8', $_), "\n";
  }
  return 1;
}
