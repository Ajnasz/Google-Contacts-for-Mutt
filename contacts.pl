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
# copyright: Copyright 2009, Lajos Koszti

use strict;
use LWP::UserAgent;
use XML::Simple;
use Encode;
use Config::Simple;
use Data::Dumper;

my $userconf = $ENV{'HOME'} . '/.google.ini';

# user configuration file exists
unless (-e $userconf) {
  print "users configuration file does not exists\n";
  exit;
}

chmod 0600, $userconf;

my $cfg_default = new Config::Simple('google.default.ini');
my $cfg_user = new Config::Simple($userconf);

unless ($cfg_user) {
  print "please set up you account in $userconf:\n\n";
  print "[account]\n";
  print "email = 'example\@gmail.com'\n";
  print "password = 'yourPassword'\n";
  exit;
}

$cfg_default->import_names('GOOGLE');
$cfg_user->import_names('GOOGLE');

my $searchterm = $ARGV[0];
if(!$searchterm) {
  $searchterm = '';
}


# Create a user agent object
my $ua = LWP::UserAgent->new;
$ua->agent("Ajnasz Google Contacts Search/0.1");

# Create a request
my $res = authenticate($ua);

# Check the outcome of the response
if($res->is_success) {
  my @responses = split(/\n/, $res->content);
  my @data;
  my $auths = {};
  foreach(@responses) {
    @data = split(/=/, $_);
    $auths->{$data[0]} = $data[1];
  }

  my $xml = getXML($auths, $ua);

  my $entries = parseEntries($xml);
  my @found = search($searchterm, $entries);
  printResults(@found);
} else {
  print $res->status_line, "\n";
}

sub authenticate {
  $ua = shift;
  my $req = HTTP::Request->new(POST => $GOOGLE::LOGIN_URL);
  $req->content_type('application/x-www-form-urlencoded');
  my $content = 'accountType=' . $GOOGLE::ACCOUNT_TYPE . '&Email=' . $GOOGLE::ACCOUNT_EMAIL . '&Passwd=' . $GOOGLE::ACCOUNT_PASSWORD . '&service=' . $GOOGLE::APPLICATION_SERVICE . '&source=' . $GOOGLE::CLIENT_NAME;
  $req->content($content);

# Pass request to the user agent and get a response back
  my $res = $ua->request($req);

}
sub getXML {
  my $auths = shift;
  my $ua = shift;
  my $req = HTTP::Request->new(GET => $GOOGLE::CONTACTS_URL);
  $req->header('Authorization' => 'GoogleLogin auth=' . $auths->{'Auth'});
  my $res = $ua->request($req);
  return $res->content;
}
sub parseEntries {
  my $xml = shift;
  my $parser = XML::Simple->new;

  my $xml = $parser->XMLin($xml);
  my $entries = $xml->{'entry'};
}
sub search {
  my $searchterm = shift;
  my $entries = shift;
  my @results;
  my @mails;
  foreach my $key (keys (%$entries)){
    @mails = getMails($entries->{$key});
    if($entries->{$key}->{title}->{content} =~ /$searchterm/i or $entries->{$key}->{content}->{content} =~ /$searchterm/i or mailMatch($entries->{$key}, $searchterm, @mails)) {
      if(@mails) {
        foreach(@mails) {
          push(@results, $_ . "\t". $entries->{$key}->{'title'}->{'content'});
        }
      } else {
        push(@results, "\t" . $entries->{$key}->{'title'}->{'content'});
      }
    }
  }
  return @results;
}
sub mailMatch {
  my ($entry, $searchterm, @mails) = @_;
  foreach(@mails) {
    if($_ =~ /$searchterm/){
      return $_;
    }
  }
  return 0;
}
sub getMails {
  my $entry = shift;
  my @out;
  if(defined $entry->{'gd:email'}) {
    if(ref($entry->{'gd:email'}) eq 'ARRAY') {
      foreach my $email(@{$entry->{'gd:email'}}) {
        push(@out, $email->{'address'});
      }
    } else {
      push(@out, $entry->{'gd:email'}->{'address'});
    }
  }
  return @out;
}
sub printResults {
  my @results = @_;
  print 'results: ' . @results, "\n";
  foreach(@results) {
    print encode('utf-8', $_), "\n";
  }
  return 1;
}
