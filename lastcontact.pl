# Usage:
# Load the script and do /statusbar window add typednick
# When you type a nickname of someone who is in the current channel,
# info will be shown in your statusbar.
#
# TODO:
# - also use irssi's internal info
# - userhost reply has ip, not hostname on some ircds own host
# - 'flood' protection when saying/pasting a lot of nicks
# - update when changing window/windowitem
# - show when nick quits/parts/get kicked/rejoins
# - get info from friends-scripts
# - make better configureable
# - react to hilights

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::TextUI;
use Data::Dumper;
$VERSION = '0.0.0';
%IRSSI = (
	authors  	=> 'Wouter Coekaerts',
	contact  	=> 'wouter@coekaerts.be, coekie@#irssi',
	name    	=> 'typednicksb',
	description 	=> 'show info about a nick you talk to/about in the statusbar',
	license 	=> 'GPLv2',
	url     	=> 'http://wouter.coekaerts.be/irssi/',
	changed  	=> '25/01/04',
);

# after how many seconds should info of a nickname be thrown away
my $INFO_MAXAGE = 10;
my $INFO_MAX_QUEUE = 3;

my $sb_text = "hello"; # text in the statusbar
my $last_word; # last word typed
my $last_nick_typed; # nick last typed
#my $last_tag;  # tag of server active in window when last nick typed

# array of hashes with info about the last nicks typed
my @nick_infos;
# 'nick' => nickname
# 'tag' => servertag

Irssi::signal_add_last ('gui key pressed', sub {
	# get the prompt
	my $prompt = Irssi::parse_special('$L');
	
	# make statusbar empty again if prompt is empty
	if ($prompt eq '' && $last_nick_typed) {
		set_sb_text('');
		$last_nick_typed = $last_word = '';
		return;
	}
	
 	# last word is chars allowed in nick (\w[]{}`^|), followed by chars not allowed
	my ($word) = ($prompt =~ /([\w\[\]\{\}\\`\^\|]*)[^\w\[\]\{\}\\`\^\|]+$/);
	
	# stop if there isn't a new word
	if (!$word || $word eq $last_word) {
		return;
	}
	$last_word = $word;
	
	# get the channel object, or stop if there's no channel active 
	my $channel = Irssi::active_win->{'active'};
	if (!$channel || ref($channel) ne 'Irssi::Irc::Channel' || $channel->{'type'} ne 'CHANNEL' || !$channel->{'names_got'}) {
		return;
	}
	
	# get the nick object, or stop if the word is not a nick
	my $nick = $channel->nick_find($word);
	if (!$nick) {
		return;
	}
	
	# word typed is a nick in current chan, remember it and get info
	$last_nick_typed = $word;
	
	cleanup_infos();
	my $info = find_info($nick->{'nick'},$channel->{'server'}->{'tag'});
	if ($info && $info->{'last_check'}) {
		set_sb_info($info);
	} else {
		unshift @nick_infos, {
			'nick' => $nick->{'nick'},
			'tag' => $channel->{'server'}->{'tag'}
		};
		# $channel->print("sending userhost $nick->{'nick'}");
		$channel->{'server'}->redirect_event("userhost", 1, $nick->{'nick'}, 0, 'redir typednick_error',
			{"event 302" => "redir typednick_userhost"});
		$channel->{'server'}->send_raw('USERHOST ' . $word);
	}
});

####################
### MANAGE INFOS ###
####################

# if userhost failed, show error in statusbar
Irssi::signal_add('redir typednick_error', sub {
	set_sb_text("typednick: error from server");
});

# userhost answer received, store info and update statusbar
Irssi::signal_add('redir typednick_userhost', sub {
	my ($server, $data) = @_;
	my ($mynick, $reply) = split(/ +/, $data);
	my ($nick, $oper, $away, $user, $host) = $reply =~ /^:(.*?)(\*?)=([+-])(.*?)@(.*)/;
	my $info = find_info($nick,$server->{'tag'});
	if (!$info) {
		Irssi::print("typednicksb: warning: got userhost reply for $nick on ".$server->{'tag'}.", but no record for that");
		return;
	}
	$info->{'oper'} = $oper;
	$info->{'away'} = $away;
	$info->{'user'} = $user;
	$info->{'host'} = $host;
	$info->{'last_check'} = time();
	set_sb_info($info);
});

# finds the info hash for the given nick & tag
# returns undef if not found
sub find_info {
	my ($nick, $tag) = @_;
	foreach my $info (@nick_infos) {
		if ($info->{'nick'} eq $nick && $info->{'tag'} eq $tag) { # TODO compare nicks better...
			# print "found $nick on $tag";
			return $info;
		}
	}
	# print "can't find $nick on $tag";
	return undef;
}

# removes nick info hashes that are too old
sub cleanup_infos {
	# iterate over all infos from last to first
	for (my $i=@nick_infos - 1; $i >= 0; $i--) {
		if ($nick_infos[$i]->{'last_check'} && time() - $nick_infos[$i]->{'last_check'} > $INFO_MAXAGE) {
			# print 'cleanup '.$nick_infos[$i]->{'nick'};
			splice @nick_infos,$i,1;
		}
	}
}

#################
### STATUSBAR ###
#################

# changes the text in the statusbar to display the given nick info hash
sub set_sb_info {
	my ($info) = @_;
	my $away = ($info->{'away'} eq '-' ? ' %Yaway%n' : '');
	set_sb_text($info->{'nick'} . ($info->{'oper'} ? ' (oper)' : '') . ' is ' . $info->{'user'} . '@' . $info->{'host'} . $away);
}

# changes the text in the statusbar to $text
sub set_sb_text {
	my ($text) = @_;
	$sb_text = $text;
	Irssi::statusbar_items_redraw('lastcontact');
}

# function irssi calls to get statusbar text
sub sb_lastcontact {
	my ( $sbItem, $get_size_only ) = @_;
	#my $line = "hello";
	#my $format = "{sb ".$line."}";
	#$item->{min_size} = $item->{max_size} = length($line);
	#$item->default_handler($get_size_only, $format, 0, 1);
	$sbItem->default_handler ( $get_size_only, "{sb $sb_text}", undef, 1 );
}

############
### INIT ###
############

Irssi::statusbar_item_register('lastcontact', '{sb $0-}', 'sb_lastcontact');
Irssi::command_bind("tn", sub {print Data::Dumper->new([@nick_infos])->Dump});