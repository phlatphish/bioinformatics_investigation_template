#!/usr/bin/env perl
# make_data_inventory.pl -- regenerate docs/reference/data_inventory.tsv
#
# Run from the repository root:
#   perl tools/make_data_inventory.pl                    # repository files only
#   perl tools/make_data_inventory.pl --scan raw --scan results
#   perl tools/make_data_inventory.pl --scan results --no-sha
#
# Writes one row per file in the repository (excluding .git), then one row per
# file under each --scan key of config/paths.tsv (location = this host), then
# the hand-maintained rows in docs/reference/external_locations.tsv.
#
# --no-sha leaves sha256 empty for scanned files (repository files are always
# checksummed); use it for very large data, and rely on md5sums.txt and
# outputs.sha256 kept beside the data.
#
# For Git LFS pointer files, sha256 holds the LFS object id and bytes the real
# size; lfs_pointer=yes flags these rows. Output is written to a temporary file
# and renamed, so an interrupted run never leaves a partial inventory.
# Core modules only.

use strict;
use warnings;
use File::Find;
use Digest::SHA;
use Getopt::Long;
use POSIX qw(strftime);
use Sys::Hostname;

my $out      = 'docs/reference/data_inventory.tsv';
my $external = 'docs/reference/external_locations.tsv';
my $paths    = 'config/paths.tsv';
my (@scan, $nosha);
GetOptions('scan=s' => \@scan, 'no-sha' => \$nosha) or exit 2;
my @cols = qw(path location kind bytes sha256 lfs_pointer authoritative notes);

die "Run from the repository root (docs/reference/ not found)\n" unless -d 'docs/reference';

sub kind_of {
    my ($p) = @_;
    return 'contract'  if $p =~ m{^docs/modules/};
    return 'state'     if $p =~ m{^docs/state/};
    return 'reference' if $p =~ m{^docs/reference/};
    return 'session'   if $p =~ m{^docs/sessions/};
    return 'config'    if $p =~ m{^config/};
    return 'env'       if $p =~ m{^envs/};
    return 'test'      if $p =~ m{^tests/};
    return 'result'    if $p =~ m{^results/};
    return 'script'    if $p =~ m{\.(pl|pm|sh|R|py|smk|nf)$} || $p =~ m{^(scripts|tools|workflow)/};
    return 'other';
}

sub file_row {
    my ($p, $loc, $kind, $want_sha) = @_;
    my ($sha, $bytes, $lfs) = ('', -s $p, 'no');
    open my $in, '<:raw', $p or die "Cannot read $p: $!\n";
    my $head = '';
    read $in, $head, 200;
    close $in;
    if ($head =~ /^version https:\/\/git-lfs/ && $bytes < 1024) {
        open my $ptr, '<', $p or die "Cannot read $p: $!\n";
        local $/; my $txt = <$ptr>; close $ptr;
        ($sha)   = $txt =~ /^oid sha256:([0-9a-f]{64})/m;
        ($bytes) = $txt =~ /^size (\d+)/m;
        die "Malformed LFS pointer: $p\n" unless $sha && defined $bytes;
        $lfs = 'yes';
    } elsif ($want_sha) {
        $sha = Digest::SHA->new(256)->addfile($p, 'b')->hexdigest;
    }
    return join("\t", $p, $loc, $kind, $bytes, $sha, $lfs, 'yes', '');
}

# repository files
my @files;
find({ no_chdir => 1, wanted => sub {
    if (-d $_ && m{^\./\.git$}) { $File::Find::prune = 1; return }
    return unless -f $_;
    (my $p = $_) =~ s{^\./}{};
    return if $p eq $out || $p =~ /\.tmp\.\d+$/;
    push @files, $p;
}}, '.');
@files = sort @files;

# paths table for --scan
my %PATH;
if (@scan) {
    open my $pf, '<', $paths or die "Cannot read $paths: $!\n";
    while (my $l = <$pf>) {
        $l =~ s/\r?\n\z//;
        next if $l =~ /^\s*(#|$)/ || $l =~ /^key\t/;
        my ($k, $v) = split /\t/, $l, -1;
        $PATH{$k} = $v;
    }
    close $pf;
    for my $k (@scan) { die "--scan $k: key not in $paths\n" unless defined $PATH{$k} }
}

my $tmp = "$out.tmp.$$";
open my $fh, '>', $tmp or die "Cannot write $tmp: $!\n";
print $fh "# generated ", strftime('%Y-%m-%d', localtime), " by tools/make_data_inventory.pl\n";
print $fh join("\t", @cols), "\n";

my $n = 0;
for my $p (@files) { print $fh file_row($p, 'repository', kind_of($p), 1), "\n"; $n++ }

my $s = 0;
my $host = (split /\./, hostname())[0];
for my $k (@scan) {
    my $root = $PATH{$k};
    unless (-d $root) { warn "--scan $k: $root not found; skipped\n"; next }
    my @ext;
    find({ no_chdir => 1, wanted => sub { push @ext, $_ if -f $_ } }, $root);
    for my $p (sort @ext) { print $fh file_row($p, $host, $k, !$nosha), "\n"; $s++ }
}

my $m = 0;
if (-f $external) {
    open my $ex, '<', $external or die "Cannot read $external: $!\n";
    my $hdr = <$ex>;
    $hdr =~ s/\r?\n\z//;
    die "$external header must be: @cols\n" unless $hdr eq join("\t", @cols);
    while (my $line = <$ex>) {
        next if $line =~ /^\s*(#|$)/;
        $line =~ s/\r?\n\z//;
        my @f = split /\t/, $line, -1;
        die "$external line $.: expected ", scalar @cols, " columns, got ", scalar @f, "\n" unless @f == @cols;
        print $fh "$line\n";
        $m++;
    }
    close $ex;
}

close $fh or die "Cannot close $tmp: $!\n";
die "No files inventoried; refusing to write an empty inventory\n" unless $n;
rename $tmp, $out or die "Cannot rename $tmp to $out: $!\n";
print STDERR "Wrote $out: $n repository rows, $s scanned rows, $m external rows\n";
