use strict;
use Irssi 20021028;
use vars qw($VERSION %IRSSI);

# Usage:
# You must change your formats to include the $mode, for example:
# default format for part is:
#    {channick $0} {chanhost $1} has left {channel $2} {reason $3}
# to include the mode, do
#  /format part $mode{channick $0} {chanhost $1} has left {channel $2} {reason $3}
# for quits:
#  /format $mode{channick $0} {chanhost $1} has quit {reason $2}

$VERSION = "0.2";
%IRSSI = (
	authors         => "Wouter Coekaets",
	contact         => "wouter\@coekaerts.be",
	name            => "showmode",
	description     => "show modes in parts, quits, kicks, topic changes or actions, like show_nickmode does for public messages",
	license         => "GPL",
	changed         => "2003-08-30"
);

my @lastmode;

# $mode2 is 0 for $mode, 1 for $mode2 (only used for 'the kicker')
sub setlast {
	my ($mode2, $server, $channelname, $nickname) = @_;
	my @channels;
	@lastmode[$mode2] = {};
	if (defined($channelname)) {
		$channels[0] = $server->channel_find($channelname);
		if (!defined($channels[0])) {
			return;
		}
	} else {
		@channels = $server->channels();

	}

	foreach my $channel (@channels) {
		my $nick = $channel->nick_find($nickname);
		if (defined($nick)) {
			$lastmode[$mode2]->{$channel->{'name'}} = $nick->{'op'} ? '@' : $nick->{halfop} ? '%' : $nick->{voice} ? '+' : '' ;			
		}
	}
}

sub expando_mode {
	my ($server,$item,$mode2) = @_;
	if (!defined($item) || $item->{'type'} ne 'CHANNEL' ) {
		return '';
	}
	return $lastmode[$mode2]->{$item->{'name'}};
}

Irssi::signal_add_first('message part', sub {setlast(0,$_[0],$_[1],$_[2]);});
Irssi::signal_add_first('message quit', sub {setlast(0,$_[0],undef,$_[1]);});
Irssi::signal_add_first('message topic', sub {setlast(0,$_[0],$_[1],$_[2]);});
Irssi::signal_add_first('message kick', sub {setlast(0,$_[0],$_[1],$_[2]); setlast(1,$_[0],$_[1],$_[3]);});
Irssi::signal_add_first('message irc action', sub {setlast(0,$_[0],$_[4],$_[2]);});

Irssi::expando_create('mode', sub {expando_mode($_[0],$_[1],0)},{ 'message part' => 'None'});
Irssi::expando_create('mode2', sub {expando_mode($_[0],$_[1],1)},{ 'message part' => 'None'});
