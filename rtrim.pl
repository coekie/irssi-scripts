use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20021117;
$VERSION = '0.2';
%IRSSI = (
	authors  	=> 'Wouter Coekaerts',
	contact  	=> 'wouter@coekaerts.be, coekie@#irssi',
	name    	=> 'rtrim',
	description 	=> 'removes whitespace at the end of every line you type',
	license 	=> 'GPLv2',
	url     	=> 'http://wouter.coekaerts.be/irssi/',
	changed  	=> '03/06/03',
);

Irssi::signal_add_first('send command', \&rtrim);
Irssi::signal_add_first('send text', \&rtrim);

sub rtrim {
	if ($_[0] =~ s/\s+$//) { 
		Irssi::signal_continue(@_);
	}
};
