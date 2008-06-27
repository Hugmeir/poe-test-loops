# $Id$

package POE::Test::Loops;

use strict;
use vars qw($VERSION);

use vars qw($VERSION $REVISION);
$VERSION = '0.99'; # NOTE - Should be #.## (two decimal places)
$REVISION = do {my($r)=(q$Revision$=~/(\d+)/);sprintf"0.%04d",$r};

use File::Spec;
use File::Path;
use File::Find;

### Find the test libraries.

use lib qw(./lib ../lib);
use POE::Test::DondeEstan;
my $source_base = POE::Test::DondeEstan->marco();

### Generate loop tests.

sub generate {
  my ($dir_base, $loops, $flag_verbose) = @_;

  foreach my $loop (@$loops) {
    my $loop_dir = lc($loop);
    $loop_dir =~ s/::/_/g;

    my $fqmn = find_event_loop_file($loop);
    unless ($fqmn) {
      $flag_verbose and print "Couldn't find a loop for $loop ...\n";
      next;
    }

    $flag_verbose and print "Found $fqmn\n";

    my $loop_cfg = get_loop_cfg($fqmn);
    unless (defined $loop_cfg and length $loop_cfg) {
      $loop_cfg = (
	  "sub skip_tests { return }"
	  );
    }

    my $source = (
	"#!/usr/bin/perl -w\n" .
	"# \$Id\$\n" .
	"\n" .
	"use strict;\n" .
	"\n" .
	"use lib qw(--base_lib--);\n" .
	"use Test::More;\n" .
	"use POSIX qw(_exit);\n" .
	"\n" .
	"--loop_cfg--\n" .
	"\n" .
	"BEGIN {\n" .
	"  if (my \$why = skip_tests('--test_name--')) {\n" .
	"    plan skip_all => \$why\n" .
	"  }\n" .
	"}\n" .
	"\n" .
	"# Run the tests themselves.\n" .
	"require '--base_file--';\n" .
	"\n" .
	"_exit 0 if \$^O eq 'MSWin32';\n" .
	"CORE::exit 0;\n"
	);

# Full directory where source files are found.

    my $dir_src = File::Spec->catfile($source_base, "Loops");
    my $dir_dst = File::Spec->catfile($dir_base, $loop_dir);

# Gather the list of source files.
# Each will be used to generate a real test file.

    opendir BASE, $dir_src or die $!;
    my @base_files = grep /\.pm$/, readdir(BASE);
    closedir BASE;

# Initialize the destination directory.  Clear or create as needed.

    $dir_dst =~ tr[/][/]s;
    $dir_dst =~ s{/+$}{};

    rmtree($dir_dst);
    mkpath($dir_dst, 0, 0755);

# For each source file, generate a corresponding one in the
# configured destination directory.  Expand various bits to
# customize the test.

    foreach my $base_file (@base_files) {
      my $test_name = $base_file;
      $test_name =~ s/\.pm$//;

      my $full_file = File::Spec->catfile($dir_dst, $base_file);
      $full_file =~ s/\.pm$/.t/;

# These hardcoded expansions are for the base file to be required,
# and the base library directory where it'll be found.

      my $expanded_src = $source;
      $expanded_src =~ s/--base_file--/$base_file/g;
      $expanded_src =~ s/--base_lib--/$dir_src/g;
      $expanded_src =~ s/--loop_cfg--/$loop_cfg/g;
      $expanded_src =~ s/--test_name--/$test_name/g;

# Write with lots of error checking.

      open EXPANDED, ">$full_file" or die $!;
      print EXPANDED $expanded_src;
      close EXPANDED or die $!;
    }
  }
}

sub find_event_loop_file {
  my $loop_name = shift;

  my $loop_module;
  if ($loop_name =~ /^POE::/) {
    $loop_module = File::Spec->catfile(split(/::/, $loop_name)) . ".pm";
  }
  else {
    $loop_name =~ s/::/_/g;
    $loop_module = File::Spec->catfile("POE", "Loop", $loop_name) .  ".pm";
  }

  foreach my $inc (@INC) {
    my $fqmn = File::Spec->catfile($inc, $loop_module);
    next unless -f $fqmn;
    return $fqmn;
  }

  return;
}

sub get_loop_cfg {
  my $fqmn = shift;

  my ($in_test_block, @test_source);

  open SOURCE, "<$fqmn" or die $!;
  while (<SOURCE>) {
    if ($in_test_block) {
      $in_test_block = 0, next if /^=cut\s*$/;
      push @test_source, $_;
      next;
    }

    next unless /^=for\s+poe_tests\s*/;
    $in_test_block = 1;
  }

  shift @test_source while @test_source and $test_source[0] =~ /^\s*$/;
  pop @test_source while @test_source and $test_source[-1] =~ /^\s*$/;

  return join "", @test_source;
}


1;

__END__

=head1 NAME

POE::Test::Loops - Reusable tests for POE::Loop authors

=head1 SYNOPSIS

See L<poe-gen-tests>.

=head1 DESCRIPTION

See L<poe-gen-tests>, which is a utility to generate the actual tests
for your POE::Loop subclass.

=head1 SEE ALSO

L<POE::Loop> and L<poe-gen-tests>.

=head1 AUTHOR & COPYRIGHT

See L<poe-gen-tests>.

=cut
