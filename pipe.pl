use Irssi;
use strict;
use Text::ParseWords; # for debugging
# these 2 are needed for bidirectional communication
use FileHandle;
use IPC::Open2;

use vars qw($VERSION %IRSSI);
$VERSION = "0.0.1";
%IRSSI = (
	authors	    => "Wouter Coekaerts",
	contact	    => "wouter\@coekaerts.be",
	name        => "pipe",
	description => "pipe stuff",
	license     => "GPLv2",
	url         => "http://wouter.coekaerts.be/irssi/",
	changed	    => "2003-09-13"
);

# see man perlipc, Bidirectional Communication with Another Process
#
# Strange things:
#  - /whois blah shows away-stuff and end-of-whois, /quote whois :blah doesn't
#  - when you do Irssi::signal_emit("server incoming", $server, $data); , $data is changed
#
# TODO:
# first:
# - try to do a whois command, not quote whois, so output is shown correctly
#
# - detect nested /pipe's (bad! mmkay?)
# - detect command errors
# - detect pipe end, close stuff
# - disable buffering somehow... or make it go faster or whatever
# - make it work with other cmdchars
# - use open3() to catch stderr of proccesses + errors for scripts to 'stderr'?
# - pipen naar 'commando' dat levels print zoals printlevels.pl
# - /here commando + /here -out (zoals by /exec)

#  from http://httpd.apache.org/docs/misc/rewriteguide.html :
#   #   disable buffered I/O which would lead 
#   #   to deadloops for the Apache server
#   $| = 1;


my $sig_text_binded=undef;
my $catch_text=0;

#$pipe = {'sub' => \&outputsub, 'output' => $outputpipe, ...}
#sub sendtopipe ($pipe, $text)
#sub start_pipe ($commandarray); returns $pipe
#
# eg: cmd_pipe("echo pom | cat > #stella")
#      => $pipe1 = start_pipe("cat > #stella"); pipe_command("echo pom",$pipe1)
#                  => $pipe2 = start_pipe("> #stella"); pipe_command("cat",$pipe2)


###########
## Stuff ##
###########

# if safeprint_level != 0, printed messages are not catched by sig_text
my $safeprint_level;
sub safeprint {
	my ($add) = @_;
	$safeprint_level += $add;
}

#####################
## Command parsing ##
#####################

sub cmd_pipe {
	my ($data,$server,$win) = @_;
	my @args = &shellwords($data);
	my ($arg, $command, @commands);

	while ($arg = shift(@args)) {
		$command = '';
		while ($arg && $arg ne '|') {
			$command .= $arg . ' ';
			$arg = shift(@args);
		}
		chop $command;
		push @commands, $command;
	}

	#foreach $command (@commands) {Irssi::print("command: $command");}

	start_pipe (\@commands);
}

Irssi::command_bind('pipe', 'cmd_pipe');


###############
## Pipe core ##
###############

# $all_commands = reference to array of all commands left in the pipe
# $irssi_command = bool, true if it is an irssi command (the first command)
sub start_pipe {
	my ($all_commands) = @_;

	#proccess the commands
	my @all_commands = @$all_commands;
	my $command = shift @all_commands;
	# $command is now the current command, @all_commands those after it in the pipe

	my $output_pipe;
	if (!@all_commands) { # end of pipe
		$output_pipe = {'sub' => \&pipelastsend_print};
	} else {
		# execute the next command(s) (recursive), and store the output-pipe
		$output_pipe = start_pipe(\@all_commands);
	}

	my $pipe = {'output' => $output_pipe};
	if ($command =~ /^\//) {
		# irssi command
		pipestart_irssi_command($command,$pipe);
	} elsif ($command =~ /^!/) {
		# shell command
		$command =~ s/^!//;
		$pipe->{'sub'} = \&pipesend_command;
		pipestart_command($command,$pipe);
	} elsif ($command =~ /^>/) {
		$command =~ s/^> ?//;
		$pipe->{'sub'} = \&pipelastsend_say;
		$pipe->{'tag'} = Irssi::active_win->{'active_server'}->{'tag'}; #FIXME: right server
		$pipe->{'channel'} = $command;
	} elsif ($command =~ /^grep /i) {
		$command =~ s/^grep //i;
		$pipe->{'sub'} = \&pipesend_grep;
		$pipe->{'grepsel'} = $command;
	}
	return $pipe;
}

####################
## Pipe functions ##
####################

### command ###
sub pipestart_command {
	my ($command,$pipe) = @_;
	my $pid = open2($pipe->{'reader'}, $pipe->{'writer'}, $command);
	$pipe->{'reader'}->blocking(0);
	$pipe->{'reader'}->autoflush(1);
	$pipe->{'writer'}->autoflush(1);
	#$pipe->{'reader'}->setvbuf(0,_IOLBF,1024);
	Irssi::pidwait_add($pid);
	Irssi::input_add(fileno($pipe->{'reader'}), INPUT_READ, \&commandpipe_read, $pipe);
}

sub commandpipe_read {
	my ($pipe) = @_;
	my $reader = $pipe->{'reader'};
	my $text = <$reader> ;
	$text =~ s/\n$//;
	if ($text =~ /^$/) {
		#Irssi::print("commandpipe_read: input empty, closing");
		close($reader);
		return;
	}
	#Irssi::print("commandpipe_read: $text");
	($pipe->{'output'}->{'sub'})->($pipe->{'output'},$text);
}

sub pipesend_command {
	my ($pipe, $text) = @_;
	my $writer = $pipe->{'writer'};
	print $writer $text . "\n";
}

### grep ###
sub pipesend_grep {
	my ($pipe, $text) = @_;
	if ($text =~ /$pipe->{'grepsel'}/) {
		($pipe->{'output'}->{'sub'})->($pipe->{'output'},$text);
	}
}

### irssi commands ###
sub sig_text {
	my ($dest, $text, $stripped_text) = @_;
	if (!$catch_text || $safeprint_level != 0) {
		return;
	}
	($sig_text_binded->{'sub'})->($sig_text_binded,$text);
	Irssi::signal_stop();
}


#Usage: $old = bind_sig_text; do_some_stuff(); $restore_bind_sig_text($old);
sub bind_sig_text {
	my ($output) = @_;
	my $old_sig_text_binded = $sig_text_binded;
	if (!$sig_text_binded) {
		Irssi::signal_add_first('print text', \&sig_text);
		$catch_text=1;
	}
	$sig_text_binded = $output;
	return $old_sig_text_binded;
}

sub restore_bind_sig_text {
	my ($old_sig_text_binded) = @_;
	$sig_text_binded = $old_sig_text_binded;
	if (!$sig_text_binded) {
		$catch_text=0;
		Irssi::signal_remove('print text', \&sig_text);
	}
}

#FIXME: alleen opvangen indien nodig
my $last_raw;
Irssi::signal_add_first("server incoming", sub {
	$last_raw = $_[1];
});

#FIXME: 2 whoissen vlak na elkaar, juiste redir (juiste server, juiste nickname/volgorde)
my $redir_output_pipe;
my $raw_output_lines;
Irssi::signal_add("redir pipe_data", \&redir_pipe_data);
sub redir_pipe_data {
	my ($server, $data, $nick, $address) = @_;	
	safeprint(+1);Irssi::print("redir pipe_data!: $last_raw");safeprint(-1);
	push @$raw_output_lines, $last_raw;
	#($redir_output_pipe->{'sub'})->($redir_output_pipe,$last_raw);
	#my $oldbind = bind_sig_text($redir_output_pipe);
	#Irssi::signal_emit("server incoming", $server, $last_raw);
	#restore_bind_sig_text($oldbind);
}

Irssi::signal_add("redir pipe_end", \&redir_pipe_end);
sub redir_pipe_end {
	 # first proces the last line
	redir_pipe_data @_;

	# resend the events, let irssi proces it and generate the output (that we send thru the pipe)
	my ($server, $data, $nick, $address) = @_; 
	safeprint(+1);Irssi::print("redir pipe_end, repeating events");safeprint(-1);
	my $oldbind = bind_sig_text($redir_output_pipe);
	foreach my $raw_line (@$raw_output_lines) {
		#FIXME: correct server
		safeprint(+1);Irssi::print("repeat: $raw_line");safeprint(-1);
		Irssi::signal_emit("server incoming", Irssi::active_win->{'active_server'},$raw_line);
	}
	restore_bind_sig_text($oldbind);
}

# executes an irssi command and redirects output to the given pipe
sub pipestart_irssi_command {
	my ($command,$pipe) = @_;
	my $output = $pipe->{'output'};

	# set new binding for text output
	#safeprint(+1);
	my $old_sig_text_binded = bind_sig_text($output);
	#safeprint(-1);

	# execute the command
	if ($command =~ /^[\/]?whois/i) {
		safeprint(+1); Irssi::print("redirecting whois"); safeprint(-1);
		$raw_output_lines = undef;
		$redir_output_pipe = $output;
		#FIXME: juiste server
		#FIXME: juiste nick,remote of niet,...
		#Irssi::active_win->command($command);	
		Irssi::active_win->{'active_server'}->redirect_event("whois", 1, undef, 0, undef, {
			"event 401" => "redir pipe_end", # No such nick
			"event 318" => "redir pipe_end", # End of WHOIS
			"event 402" => "redir pipe_end", # No such server
			"" => "redir pipe_data",
		});
		#$command =~ s/^[\/]?/QUOTE /i;
		Irssi::active_win->command($command);	
	} else { 
		Irssi::command($command);
	}

	# restore binding for text output
	#safeprint(+1);
	restore_bind_sig_text ($old_sig_text_binded);
	#safeprint(-1);
}

### say ###
# msg the incomming text to a channel or nick
sub pipelastsend_say {
	my ($pipe, $text) = @_;
	my $tag = $pipe->{'tag'};
	my $channel = $pipe->{'channel'};

#	safeprint(+1);
#	Irssi::print("pipe_say: $tag/$channel: $text");
	my $server = Irssi::server_find_tag( $tag );
	safeprint(+1);
	if (!$server) {
		print CLIENTERROR "Error in pipe: not connected to $tag anymore";
		safeprint(-1);
		return;
	}
	foreach my $line (split(/\n/,$text)) {
		$server->command("MSG $channel $line");
	}
	safeprint(-1);
#	safeprint(-1);
}

### print ###
sub pipelastsend_print {
	my ($pipe, $text) = @_;
	safeprint(+1);
	print CLIENTCRAP $text;
	safeprint(-1);
}
