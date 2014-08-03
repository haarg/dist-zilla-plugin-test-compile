use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings 0.009 ':no_end_test', ':all';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';
use Test::Deep;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ ExecDir => ],
                [ 'Test::Compile' => { fail_on_warning => 'none' } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            path(qw(source bin foo)) => <<'EXECUTABLE',
#!/usr/bin/perl -w
my $foo = 1;
print "oh noes\n" if $foo = 2;
EXECUTABLE
            path(qw(source bin bar)) => <<'EXECUTABLE',
#!/usr/bin/perl
my $bar = 1;
print "oh noes\n" if $bar = 2;
EXECUTABLE
        },
    },
);

$tzil->build;

my $build_dir = path($tzil->tempdir)->child('build');
my $file = $build_dir->child(qw(t 00-compile.t));
ok( -e $file, 'test created');

my @warnings = warnings {
    subtest 'run the generated test' => sub
    {
        my $wd = pushd $build_dir;
        $tzil->plugin_named('MakeMaker')->build;

        do $file;
        note 'ran tests successfully' if not $@;
        fail($@) if $@;
    };
};

my $re = '^' .  quotemeta("Found = in conditional, should be == at bin\/foo line 3. at $file line ");
cmp_deeply(
    \@warnings,
    [
        re(qr/^$re/),
    ],
    'got warnings from compiling an executable using -w, not from the one without it',
)
    or diag 'got warning(s): ', explain(\@warnings);

had_no_warnings if $ENV{AUTHOR_TESTING};
done_testing;
