#!/usr/bin/perl -w
# $Id$

# Tests various signals using POE's stock signal handlers.  These are
# plain Perl signals, so mileage may vary.

use strict;
use lib qw(./lib ../lib);
use TestSetup;

# Skip if Event isn't here.
BEGIN {
  eval 'use Event';
  unless (exists $INC{'Event.pm'}) {
    &test_setup(0, 'the Event module is not installed');
  }
}

# Turn on all asserts.
sub POE::Kernel::ASSERT_DEFAULT () { 1 }
sub POE::Kernel::TRACE_DEFAULT  () { 1 }
use POE;

&test_setup(2);

# Everything past here should be identical to 11_signals_poe.t

# Use Time::HiRes, if it's available.  This will get us super accurate
# sleep times so all the child processes wake up close together.  The
# idea is to have CHLD signals overlap.

eval {
  require Time::HiRes;
  import Time::HiRes qw(time sleep);
};

my $fork_count = 1;

# Set up a signal catching session.  This test uses plain fork(2) and
# POE's $SIG{CHLD} handler.

POE::Session->create
  ( inline_states =>
    { _start =>
      sub {
        $_[HEAP]->{forked} = $_[HEAP]->{reaped} = 0;
        $_[KERNEL]->sig( CHLD => 'catch_sigchld' );

        my $wake_time = time() + 30;

        # Fork 16 child processes, all to exit at the same time.
        for (my $child = 0; $child < $fork_count; $child++) {
          my $child_pid = fork;

          if (defined $child_pid) {
            if ($child_pid) {
              $_[HEAP]->{forked}++;
            }
            else {
              sleep $wake_time - time();
warn "child $$ exits";
              dump;
            }
          }
          else {
            warn "fork error: $!";
          }
        }

        if ($_[HEAP]->{forked} == $fork_count) {
          print "ok 1\n";
        }
        else {
          print "not ok 1 # forked $_[HEAP]->{forked} out of $fork_count\n";
        }

        $_[KERNEL]->delay( time_is_up => 120 );
      },

      _stop =>
      sub {
        warn "stop";
        my $heap = $_[HEAP];
        if ($heap->{reaped} == $fork_count) {
          print "ok 2\n";
        }
        else {
          print "not ok 2 # reaped $heap->{reaped} out of $fork_count\n";
        }
      },

      catch_sigchld =>
      sub {
        warn "sigchld";
        $_[HEAP]->{reaped}++;
        $_[KERNEL]->delay( time_is_up => 15 );
      },

      time_is_up =>
      sub {
        warn "time is up";
        # do nothing, really
      },
    },
  );

# Run the tests.

$poe_kernel->run();

exit;
