# Usage: just load the script, and it should work.

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => 'wouter@coekaerts.be, coekie@#irssi',
	name => 'netsplit_show_servers',
	description => 'shows real servers in netsplits (not *.net <-> *.split) on ircu if you are an oper',
	license => 'GPL v2',
	url => 'http://wouter.coekaerts.be/irssi/',
);

# hash with key = tag, value = ":server1 server2"
my %split;

# timestamp of when they split, to avoid old stuff hanging around
my %splittime;

Irssi::signal_add_first('event quit', sub {
	my ($server, $data, $nick, $address) = @_;
	if ($data eq ':*.net *.split' && $split{$server->{'tag'}} && $splittime{$server->{'tag'}} + 300 > time()) {
		$_[1] = $split{$server->{'tag'}};
		Irssi::signal_continue(@_);
	}
});

Irssi::signal_add_first('message irc notice', sub {
	my ($server, $msg, $nick, $address, $target) = @_;
	if (index($msg, '*** Notice -- Net break:') == 0) {
		$msg =~ /^\*\*\* Notice -- Net break: (\S* \S*)/;
		$split{$server->{'tag'}} = ':' . $1;
		$splittime{$server->{'tag'}} = time();
	}
});
