use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION="1.2";
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => 'wouter@coekaerts.be, coekie@#irssi',
	name => 'lock',
	description => "locks irssi so the user can't do 'evil' things",
	license => 'GPL v2',
	url => 'http://wouter.coekaerts.be/irssi/',
);

Irssi::signal_add("send command", sub {
	if ($_[0] =~ /^[\/\^]*(exec|script|set|upgrade|reload|eval|load)/i) {
		Irssi::print("You're not allowed to use that command");
		Irssi::signal_stop();
	}
});
