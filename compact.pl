use Irssi;
use strict;
use Irssi::TextUI;
use Data::Dumper;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.0";
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => 'wouter@coekaerts.be, coekie@#irssi',
	name => 'compact',
	description => 'combines multiple lines from same person into one',
	license => 'GPL v2 or later',
	url => 'http://wouter.coekaerts.be/irssi/',
);

my %last_public_check;

Irssi::signal_add_priority("message public", sub {
	my ($server, $msg, $nick, $address, $target) = @_;
	my $chan = $server->channel_find($target);
	return if (!$chan);

	my $win = $chan->window();
	my $view = $win->view;

	my $check = $server->{tag} . ' ' . $target . ' ' . $nick;

	if ($last_public_check{$win->{refnum}} eq $check) { # from same nick to same channel
		# get last lines (is there no better way?)
		$view->set_bookmark_bottom('bottom');
		my $last = $view->get_bookmark('bottom');

		#print Dumper($last);
		my $secondlast = $last->prev();

		my $lastpublic = $view->get_bookmark('lastpublic');
		if ($lastpublic && $secondlast->{'_irssi'} == $lastpublic->{'_irssi'}) { # no line between 2 previous publics, so we can combine
		
			my $secondlast_text = $secondlast->get_text(1);
		
			# remove them
			$view->remove_line($last);
			$view->remove_line($secondlast);

			# replace with a combined line  (which doesn't get logged)
			$win->print($secondlast_text . ' | ' . $msg, MSGLEVEL_NEVER);

			# removing lines needs redraw... unless we could somehow prevent the last message from being printed, but still get logged
			$view->redraw();
		}
	}

	$last_public_check{$win->{refnum}} = $check;
	$view->set_bookmark_bottom('lastpublic');
	
}, Irssi::SIGNAL_PRIORITY_LOW + 1);

