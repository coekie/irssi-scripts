# Fixes irssi misinterpreting channelmodes on dancer by faking the CHANMODES isupport dancer should have sent
# Only works on Irssi versions newer then 20/01/2004, and isn't really necessary for older versions
# Just load the script and it should work.
# It's best loaded before connecting to the server, but works for already connected servers too.
# If Irssi already has wrong modes for a channel you're in when you load it, /cycle to fix

use Irssi 20040120;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION="0.1";
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => 'coekie@irssi.org',
	name => 'dancer_chanmodes',
	description => 'Fixes irssi misinterpreting channelmodes on dancer by faking the CHANMODES isupport dancer should have sent',
	license => 'GPL v2',
	url => 'http://wouter.coekaerts.be/irssi/',
);

# 251 is sent right after 005, so that's when we want to fake our 005
Irssi::signal_add("event 251", sub {
	my ($server, $data, $servername) = @_;
	check_chanmodes($server);	
});

sub check_chanmodes {
	my ($server) = @_;
	# if chanmodes is still at default, on dancer
	if ($server->{'version'} =~ /dancer/ && $server->isupport("CHANMODES") eq 'beI,k,l,imnpst') {
		Irssi::print("dancer_chanmodes faking CHANMODES isupport");
		# fake a chanmodes isupport
		Irssi::signal_emit("event 005", $server, $server->{nick} . " CHANMODES=beIdq,k,fJl,cgijmnPQRrstz");
	}
}

# on start check all servers we're already connected to
{
	foreach my $server (Irssi::servers()) {
		check_chanmodes($server);
	}
}
	
