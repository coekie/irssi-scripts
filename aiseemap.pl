# Usage:
# - Install aiSee: free version for non-commercial use at http://www.aisee.com/
# - Edit settings in the script
# - do /aiseemap on a server that supports the /map command
# For more info: http://wouter.coekaerts.be/irssi/

# Changelog:
# 0.1: first version
# 0.1+: added "use IO::File;" (thanks, PorCus)

use Irssi;
use Irssi::Irc;
use strict;
use IO::File;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1+";
%IRSSI = (
	authors => 'Wouter Coekaerts',
	contact => "coekie\@irssi.org, coekie@#irssi",
	name => 'aiseemap',
	description => 'makes a png image representing the serverlayout of an irc network, using aisee',
	license => 'GPL v2',
	url => 'http://wouter.coekaerts.be/irssi/',
);

### SETTINGS ###

my $aisee_exec = '/usr/local/bin/aisee -scale 100% -cmin 50';
my $outputdir = Irssi::get_irssi_dir() . '/aiseemap';
my $minfigsize = 10;
my $maxfigsize = 80;
my $gdl_head = 'graph: {
layoutalgorithm: forcedir
colorentry 1: 255 255 255
colorentry 2: 255 0 0
colorentry 3: 0 255 0
colorentry 4: 0 0 255
colorentry 5: 255 255 0
colorentry 6: 0 0 0
colorentry 7: 128 128 128
color: 1
node.fontname: "timR12"
port_sharing: yes
arrowmode:  free
orientation: lefttoright
node.textcolor: 6
node.color: 2
node.shape: circle
node.borderwidth: 0
node.width: 100
node.height: 100
xspace: 15
yspace: 15
edge.color: 7
edge.arrowstyle: none';

###############

Irssi::Irc::Server::redirect_register('aiseemap map', 0, 0,
	{  # start events
		"event 015" => 1, # Map line
		"event 018" => 1, # First line of map, not on all ircds
	},
	{ # stop events
		"event 017" => 1, # End of /MAP
		"event 481" => 1, # You can't do that, you're no deity (dancer)
	},
	undef # optional events
);

# for each tag, hash of servers(hashes): { 'name' => { 'users' => #users, 'linkto' => servername} }
my %servers;
# for each tag, array of the last server(name) with that #hops (needed to build links)
my %serverwithhops;

Irssi::command_bind('aiseemap', sub {
	my ($data, $server, $channel) = @_;
	if (!$server) {
		Irssi::print("no active server");
		return;
	}
	$server->redirect_event('aiseemap map', 1, '', 0,
		'aiseemap failed',
		{
			"event 015" => "redir mapline",
			"event 017" => "redir endofmap",
			"" => "event empty",
		}
	);
	$server->send_raw("MAP");
	$servers{$server->{tag}} = {};
	$serverwithhops{$server->{'tag'}} = [];
});

Irssi::signal_add("aiseemap failed", sub {
	my ($server, $data, $nick, $address) = @_;
	Irssi::print("ircmap failed for ".$server->{'tag'}.": $data");
});

Irssi::signal_add("redir mapline", sub {
	my ($server, $data, $nick, $address) = @_;
	my $tag = $server->{'tag'};
	my ($prefix, $servername, $users) = ($data =~ /.*?:([ `|-]*)([^ ]*)[^0-9]*([0-9]*)/);
	my $hops = length($prefix)/4;

	my $linkto = ($hops == 0) ? undef : $serverwithhops{$tag}->[$hops-1];
	$servers{$tag}->{$servername} = {'users' => $users, 'linkto' => $linkto};
	$serverwithhops{$tag}->[$hops] = $servername;
});

Irssi::signal_add("redir endofmap", sub {
	my ($server, $data, $nick, $address) = @_;
	my $tag = $server->{'tag'};

	# find max and min users
	my $max_users = 1;
	foreach my $servername (keys(%{$servers{$tag}})) {
		if ($servers{$tag}->{$servername}->{'users'} > $max_users) {
			$max_users = $servers{$tag}->{$servername}->{'users'};
		}
	}

	my ($gdl_nodes, $gdl_edges, $size, $label);
	foreach my $servername (keys(%{$servers{$tag}})) {
		$size = int($servers{$tag}->{$servername}->{'users'} * $maxfigsize / $max_users);
		if ($size < $minfigsize) { $size = $minfigsize; }
		$label = $servername;
		$label =~ s/^(irc\.)?([^\.]{0,5}\.)?([^.]*).*/\2\3/;
		#Irssi::print("$servername => $label");
		$gdl_nodes .= "node: { title: \"$servername\" label: \"$label\" color: 2 width: $size height: $size }\n";
		if ($servers{$tag}->{$servername}->{'linkto'}) {
			$gdl_edges .= "edge: { source: \"$servername\" target: \"" . $servers{$tag}->{$servername}->{'linkto'} . "\" }\n";
		}
	}

	my $gdlfile = new IO::File "$outputdir/$tag.gdl", "w";
	if (!$gdlfile) {
		Irssi::print("Couldn't open $outputdir/$tag.gdl for writing (does the dir exist?)");
		return;
	}
	$gdlfile->print($gdl_head . "\n" . $gdl_nodes . $gdl_edges . '}');
	$gdlfile->close();
	Irssi::print("$outputdir/$tag.gdl saved");
	Irssi::command("exec $aisee_exec -pngoutput $outputdir/$tag.png $outputdir/$tag.gdl");
});
