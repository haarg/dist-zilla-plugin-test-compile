use strict;
use warnings;

package Dist::Zilla::Plugin::CompileTests;
# ABSTRACT: common tests to check syntax of your modules

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with    'Dist::Zilla::Role::FileMunger';


# -- attributes

# skiplist - a regex
has skip => ( is=>'ro', predicate=>'has_skip' );


# -- public methods

# called by the filemunger role
sub munge_file {
    my ($self, $file) = @_;

    return unless $file->name eq 't/00-compile.t';

    my $replacement = ( $self->has_skip && $self->skip )
        ? sprintf( 'next if $module =~ /%s/;', $self->skip )
        : '# nothing to skip';

    # replace the string in the file
    my $content = $file->content;
    $content =~ s/COMPILETESTS_SKIP/$replacement/;
    $file->content( $content );
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;

=begin Pod::Coverage

munge_file

=end Pod::Coverage


=head1 SYNOPSIS

In your dist.ini:

    [CompileTests]


=head1 DESCRIPTION

This is an extension of L<Dist::Zilla::Plugin::InlineFiles>, providing
the following files:

=over 4

=item * t/00-compile.t - a standard test to check syntax of bundled modules

=back

This test will find all modules and scripts in your dist, and try to
compile them one by one. This means it's a bit slower than loading them
all at once, but it will catch more errors.

This plugin does not accept any option.

=cut

__DATA__
___[ t/00-compile.t ]___
#!perl

use strict;
use warnings;

use Test::More;
use File::Find;

my @modules;
find(
  sub {
    return if $File::Find::name !~ /\.pm\z/;
    push @modules, $File::Find::name;
  },
  'lib',
);
my @scripts = glob "bin/*";

plan tests => scalar(@modules) + scalar(@scripts);
    
foreach my $file ( @modules ) {
    my $module = $file;
    $module =~ s{^lib/}{};
    $module =~ s{[/\\]}{::}g;
    $module =~ s/\.pm$//;
    COMPILETESTS_SKIP;
    is( qx{ $^X -Ilib -M$module -e "print '$module ok'" }, "$module ok", "$module loaded ok" );
}
    
SKIP: {
    eval "use Test::Script; 1;";
    skip "Test::Script needed to test script compilation", scalar(@scripts) if $@;
    foreach my $file ( @scripts ) {
        my $script = $file;
        $script =~ s!.*/!!;
        script_compiles_ok( $file, "$script script compiles" );
    }
}
