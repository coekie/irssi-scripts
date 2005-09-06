# Usage: 
#  Do /escape (or /esc) just like you would use /lastlog
#  this then prints the lines, which you can use in /eval.
#  see /help lastlog for options
#
# For example:
#  <someone> Hey! join #fooX (where X is some char you can't copy-paste)
#  then you do /esc #foo
#  and you'll get something like 19:50 \x048/<\x04g \x04gsomeone\x04g\x048/>\x04g \x04ehey! join #foo\x12
#  ignore the stuff in the first part of the message, that's irssi's internal color format for the line printed.
#  doing /eval join #foo\x12 will make you join the right channel
#  /esc -clear makes your scrollback clean again

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '1.0';
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => 'wouter@coekaerts.be, coekie@#irssi',
	name => 'escape',
	description => 'displays lines in your scrollback in escaped form, so you can copy and paste them including colors and special characters',
	license => 'GPL v2',
	url => 'http://wouter.coekaerts.be/irssi/',
);

sub escape {
	my ($text) = @_;
	$text =~ s/(.)/escape_char($1)/eg;
	return $text;
}

sub escape_char {
	my ($char) = @_;
	my $ord = ord($char);
	if ($char eq '\\' || $char eq '$' || $char eq ';') {
		return "\\$char";
	} elsif ($ord < 32 || $ord > 126) {
		return '\\x' . sprintf("%02x", ord($char));
	} else {
		return $char;
	}
}

Irssi::command_bind("escape", sub {
	my ($data, $server, $item) = @_;
	my $context = $item ? $item : Irssi::active_win;

	Irssi::signal_add_first('print text', 'sig_print_text');
	$context->command("lastlog $data");
	Irssi::signal_remove('print text', 'sig_print_text');
});

sub sig_print_text {
	my ($dest, $text, $stripped_text) = @_;
	$_[1] = escape($text);
	Irssi::signal_continue(@_);
}
