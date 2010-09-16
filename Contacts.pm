package Contacts;

use strict;
use LWP::UserAgent;
use XML::Simple;
use Encode;
use Data::Dumper;

sub new {
	my $class = shift;
	my $args = shift;
	my $self = $args;
	my $ua = LWP::UserAgent->new;
	$ua->agent("Ajnasz Google Contacts Search/0.1");
	$self->{'ua'} = $ua;
	bless($self, $class);
	return $self;
}

sub get {
	my $self = shift;
	$self->_authenticate();
	$self->_getXML();
	$self->_parseEntries();
}

sub _authenticate {
	my $self = shift;
  my $req = HTTP::Request->new(POST => $self->{'LOGIN_URL'});
  $req->content_type('application/x-www-form-urlencoded');
  my $content = 'accountType=' . $self->{'ACCOUNT_TYPE'}
              . '&Email=' . $self->{'ACCOUNT_EMAIL'}
              . '&Passwd=' . $self->{'ACCOUNT_PASSWORD'}
              . '&service=' . $self->{'APPLICATION_SERVICE'}
              . '&source=' . $self->{'CLIENT_NAME'};

  $req->content($content);

# Pass request to the user agent and get a response back
  my $res = $self->{'ua'}->request($req);

	if($res->is_success) {
		my @responses = split(/\n/, $res->content);
		my @data;
		my $auths = {};
		foreach(@responses) {
			@data = split(/=/, $_);
			$self->{'auths'}->{$data[0]} = $data[1];
		}
	} else {
		print 'ERROR: ' . $res->status_line, "\n";
		exit 1;
	}
}

sub _getXML {
	my $self = shift;
  my $auths = $self->{'auths'};
  my $req = HTTP::Request->new(GET => $GOOGLE::CONTACTS_URL);
  $req->header('Authorization' => 'GoogleLogin auth=' . $auths->{'Auth'});
  my $res = $self->{'ua'}->request($req);
	$self->{'xml'} = $res->content;
}

sub _parseEntries {
	my $self = shift;
  my $xml = $self->{'xml'};
  my $parser = XML::Simple->new;

  my $xml = $parser->XMLin($xml);
  $self->{'entries'} = $xml->{'entry'};
}

sub mailMatch {
	my $self = shift;
  my ($entry, $searchterm, @mails) = @_;
  foreach(@mails) {
    if($_ =~ /$searchterm/){
      return $_;
    }
  }
  return 0;
}

sub _getMails {
	my $self = shift;
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

sub search {
	my $self = shift;
  my $searchterm = shift;
	$self->get() unless $self->{'entries'};
  my $entries = $self->{'entries'};
  my @results;
  my @mails;
  foreach my $key (keys (%$entries)){
    @mails = $self->_getMails($entries->{$key});
    if($entries->{$key}->{title}->{content} =~ /$searchterm/i
				or $entries->{$key}->{content}->{content} =~ /$searchterm/i
				or $self->mailMatch($entries->{$key}, $searchterm, @mails)) {
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


1;
