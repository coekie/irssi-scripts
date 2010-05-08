# Test for trigger.pl - this is for testing purposes only

# Copyright (C) 2010  Wouter Coekaerts <wouter@coekaerts.be>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use Irssi;

# 2=debug 1=info 0=error
my $verbosity = 1;
# silence messages printed by irssi (or trigger.pl) we expected
my $silence_expected = 1;


# array of strings we are expected to be printed
my @expected_prints;
# if enabled, fail if anything unexpected is printed
my $expect_prints_strict = 0;
# flag signaling we had a failure
my $fail_expect;

my $ignore_print = 0;
Irssi::signal_add("print text", \&sig_print_text);

sub sig_print_text {
	my ($dest, $text, $stripped) = @_;
	return if $ignore_print;
	$ignore_print++;
	
	my $matched = 0;
	for (my $i = 0; $i < scalar(@expected_prints); $i++) {
		my $expected_print = $expected_prints[$i];
		if ($stripped =~ /$expected_print/) {
			debug("Matched $expected_print:");
			splice (@expected_prints, $i, 1);
			$matched = 1;
			if ($silence_expected) {
				Irssi::signal_stop();
			}
			last;
		}
	}
	if (!$matched && $expect_prints_strict && !$fail_expect) {
		print("Unexpected line printed: $stripped");
		dump_expecting();
		$fail_expect = 1; # if we would die here, irssi might crash :/
	}
	$ignore_print--;
}

# print current list of expected events
sub dump_expecting {
	print "Expecting: ";
	foreach my $expected_print (@expected_prints) {
		print "     $expected_print";
	}
	print "--";
}

# register that we expect $regex to be printed by Irssi
sub expect_print($) {
	my ($regex) = @_;
	push @expected_prints, $regex;
}

# check that we didn't encounter a failure, and everything that we expected did happen
sub assert_expect_done() {
	if ($fail_expect) {
		die("failure (see above for details)");
	}
	if (scalar(@expected_prints)) {
		die ("not all expected texts printed");
		dump_expecting()
	}
}

# return a server to use for testing. assumes we are already connected to one
sub get_server() {
	my $server = Irssi::active_win->{active_server};
	die "not connected" unless $server;
	return $server;
}

# pretend the server has sent us the given string
sub fake_raw($) {
	my ($raw) = @_;
	Irssi::signal_emit('server incoming', get_server(), $raw);
}

# add a trigger. $trigger must be in exactly the same format as trigger.pl outputs it
sub add_trigger {
	my ($trigger) = @_;
	expect_print("Trigger \\d+ added: \Q$trigger\E");
	Irssi::command("trigger add $trigger");
}

sub remove_triggers {
	my ($count) = @_;
	for (my $i = 0; $i < $count; $i++) {
		expect_print("Deleted 1:");
		Irssi::command("trigger delete 1");
		assert_expect_done();
	}
}

# output at debug level
sub debug($) {
	my ($text) = @_;
	do_print("%KTEST DEBUG%n $text") if ($verbosity >= 2);
}

# output at info level
sub info($) {
	my ($text) = @_;
	do_print("%KTEST INFO%n $text") if ($verbosity >= 1);
}

# output at error level
sub error($) {
	my ($text) = @_;
	do_print("%rTEST ERROR%n $text");
}

# safely print without interfering with expected messages
sub do_print($) {
	my ($text) = @_;
	$ignore_print++;
	print ($text);
	$ignore_print--;
}

# run the tests
sub run_all_tests {
	my ($data, $server, $item) = @_;
	$expect_prints_strict = 1;
	
	my @tests = qw(test_triggers_empty test_public_channel test_public_not_channel);
	foreach my $test (@tests) {
		info('Starting test %_' . $test);
		eval "$test()";
		if ($@) {
			error("FAILED: $test");
			last;
		}
	}
	do_print("%GTests successful");
	
	$expect_prints_strict = 0;
	
};


# test that list of triggers is empty when we start
sub test_triggers_empty {
	expect_print("Triggers:");
	Irssi::command("trigger list");
	assert_expect_done();
}

# test trigger for public message, with channels filter
sub test_public_channel {
	# add trigger
	add_trigger("-publics -channels '#foo' -command 'echo matched \$M'");
	
	# test match
	expect_print('someone:#foo> test');
	expect_print('matched test');
	fake_raw(":someone PRIVMSG #foo :test");
	assert_expect_done();
	
	# test non-match
	expect_print('someone:#bar> test');
	fake_raw(":someone PRIVMSG #bar :test");
	assert_expect_done();
	
	remove_triggers(1);
}

# test trigger for public message, with not_channels filter
sub test_public_not_channel {
	# add trigger
	add_trigger("-publics -not_channels '#foo' -command 'echo matched \$M'");
	
	# test match
	expect_print('someone:#bar> test');
	expect_print('matched test');
	fake_raw(":someone PRIVMSG #bar :test");
	assert_expect_done();
	
	# test non-match
	expect_print('someone:#foo> test');
	fake_raw(":someone PRIVMSG #foo :test");
	assert_expect_done();
	
	remove_triggers(1);
}

run_all_tests();