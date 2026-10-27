package Paths;
# Paths.pm -- read config/paths.tsv so scripts never hard-code absolute paths.
#
#   use FindBin; use lib "$FindBin::Bin/../lib";   # from scripts/<module>/
#   use Paths qw(path_for);
#   my $out = path_for('work', 'm01_qc', $run_id);  # .../work/m01_qc/<run_id>
#
# The table is found from $ENV{INVESTIGATION_PATHS}, or by walking up from the
# current directory to the first config/paths.tsv. Unknown keys are fatal.
# Core modules only.

use strict;
use warnings;
use Exporter 'import';
use Cwd qw(getcwd);
use File::Spec;
our @EXPORT_OK = qw(path_for paths_file);

my %P;
my $FILE;

sub paths_file {
    return $FILE if $FILE;
    if ($ENV{INVESTIGATION_PATHS}) { return $FILE = $ENV{INVESTIGATION_PATHS} }
    my $d = getcwd();
    while (1) {
        my $f = File::Spec->catfile($d, 'config', 'paths.tsv');
        return $FILE = $f if -f $f;
        my $up = File::Spec->catdir($d, File::Spec->updir);
        $up = Cwd::abs_path($up);
        die "config/paths.tsv not found above " . getcwd() . "; set INVESTIGATION_PATHS\n" if !$up || $up eq $d;
        $d = $up;
    }
}

sub _load {
    return if %P;
    my $f = paths_file();
    open my $fh, '<', $f or die "Cannot read $f: $!\n";
    while (my $l = <$fh>) {
        $l =~ s/\r?\n\z//;
        next if $l =~ /^\s*(#|$)/ || $l =~ /^key\t/;
        my ($k, $v) = split /\t/, $l, -1;
        $P{$k} = $v if defined $v;
    }
    close $fh;
}

sub path_for {
    my ($key, @rest) = @_;
    _load();
    die "Unknown path key '$key' in " . paths_file() . "\n" unless exists $P{$key};
    return File::Spec->catfile($P{$key}, @rest);
}

1;
