#!/usr/bin/env perl
# check_claims.pl -- verify docs/state/claims_ledger.tsv against evidence files
#
# Run from the repository root:
#   perl tools/check_claims.pl                 # read-only check
#   perl tools/check_claims.pl --update        # also record passes
#   perl tools/check_claims.pl --update --accept-changed
#
# Options:
#   --ledger PATH       ledger to check (default docs/state/claims_ledger.tsv)
#   --log PATH          per-row log, overwritten each run
#                       (default docs/state/claims_check.log)
#   --paths PATH        key-to-path table for {key}/... evidence paths
#                       (default config/paths.tsv)
#   --update            for PASS rows: set status=verified (external_only rows
#                       keep their status), checked_on=today, and record
#                       evidence_sha256 where it was empty
#   --accept-changed    with --update, also record the new checksum for
#                       CHANGED rows (value still matches, file changed)
#
# Row results:
#   PASS     value found and equal to expected; or interpretation with a
#            falsifier whose dependencies all PASS
#   FAIL     anything else that should pass
#   CHANGED  value matches but evidence_sha256 differs (warning)
#   BLOCKED  interpretation depending on an unreachable external_only row
#   NOTE     external_only value row whose file is not reachable here
#            (on a machine where it is reachable, the row is checked)
#   SKIP     retired or superseded row
#
# Limits: ledger fields cannot contain tabs, so a line: locator only works
# on evidence lines without tabs; use tsv: for tabular files.
#
# Exit status: 0 if no FAIL and no schema error; 1 otherwise; 2 on usage error.
# Column and locator reference: docs/state/claims_ledger_readme.md.
# Core modules only.

use strict;
use warnings;
use Getopt::Long;
use Digest::SHA;
use POSIX qw(strftime);

my $ledger = 'docs/state/claims_ledger.tsv';
my $log    = 'docs/state/claims_check.log';
my $paths  = 'config/paths.tsv';
my ($update, $accept_changed) = (0, 0);
GetOptions('ledger=s' => \$ledger, 'log=s' => \$log, 'paths=s' => \$paths,
           'update' => \$update, 'accept-changed' => \$accept_changed)
    or exit 2;
if ($accept_changed && !$update) { warn "--accept-changed requires --update\n"; exit 2 }

my @COLS = qw(claim_id module kind claim stage denominator evidence_path
              evidence_sha256 locator expected depends_on falsifier status
              checked_on manuscript_location source_ref);
my %IDX; @IDX{@COLS} = (0 .. $#COLS);
my $today = strftime('%Y-%m-%d', localtime);

# ---- read paths table (optional) ----------------------------------------
my %PATH;
if (-f $paths) {
    open my $pf, '<', $paths or die "Cannot read $paths: $!\n";
    while (my $l = <$pf>) {
        $l =~ s/\r?\n\z//;
        next if $l =~ /^\s*(#|$)/ || $l =~ /^key\t/;
        my ($k, $v) = split /\t/, $l, -1;
        $PATH{$k} = $v if defined $v && $k ne '';
    }
    close $pf;
}

# ---- read ledger --------------------------------------------------------
open my $lf, '<', $ledger or die "Cannot read $ledger: $!\n";
my $hdr = <$lf>;
die "$ledger is empty\n" unless defined $hdr;
$hdr =~ s/\r?\n\z//;
die "$ledger header does not match the approved 16 columns\n"
    unless $hdr eq join("\t", @COLS);
my (@rows, @schema_errors, %by_id);
while (my $line = <$lf>) {
    $line =~ s/\r?\n\z//;
    next if $line =~ /^\s*$/;
    my @f = split /\t/, $line, -1;
    if (@f != @COLS) {
        push @schema_errors, "line $.: expected 16 fields, got " . scalar(@f);
        next;
    }
    my %r; @r{@COLS} = @f; $r{_line} = $.;
    push @rows, \%r;
}
close $lf;

# ---- schema checks ------------------------------------------------------
my %STATUS = map { $_ => 1 } qw(verified unverified external_only retired);
for my $r (@rows) {
    my $id = $r->{claim_id};
    my $at = "line $r->{_line} ($id)";
    push @schema_errors, "$at: bad claim_id" unless $id =~ /^c\d{3,}$/;
    push @schema_errors, "$at: duplicate claim_id" if $by_id{$id}++;
    push @schema_errors, "$at: bad module" unless $r->{module} =~ /^m\d{2}$/;
    push @schema_errors, "$at: kind must be value or interpretation"
        unless $r->{kind} =~ /^(value|interpretation)$/;
    push @schema_errors, "$at: claim is empty" if $r->{claim} eq '';
    push @schema_errors, "$at: source_ref is empty" if $r->{source_ref} eq '';
    push @schema_errors, "$at: bad status '$r->{status}'"
        unless $STATUS{$r->{status}} || $r->{status} =~ /^superseded_by:c\d{3,}$/;
    push @schema_errors, "$at: checked_on must be YYYY-MM-DD"
        if $r->{checked_on} ne '' && $r->{checked_on} !~ /^\d{4}-\d\d-\d\d$/;
    push @schema_errors, "$at: evidence_sha256 must be 64 hex characters"
        if $r->{evidence_sha256} ne '' && $r->{evidence_sha256} !~ /^[0-9a-f]{64}$/;
    if ($r->{kind} eq 'value') {
        for my $c (qw(stage denominator evidence_path locator expected)) {
            push @schema_errors, "$at: value row needs $c" if $r->{$c} eq '';
        }
        if ($r->{evidence_path} =~ /^\{([^}]+)\}/ && !exists $PATH{$1}) {
            push @schema_errors, "$at: path key {$1} not in $paths";
        }
    }
}
%by_id = map { $_->{claim_id} => $_ } @rows;
for my $r (@rows) {
    my $at = "line $r->{_line} ($r->{claim_id})";
    if ($r->{status} =~ /^superseded_by:(c\d+)$/) {
        push @schema_errors, "$at: superseded_by target $1 does not exist" unless $by_id{$1};
        push @schema_errors, "$at: superseded by itself" if $1 eq $r->{claim_id};
    }
    for my $d (deps($r)) {
        push @schema_errors, "$at: depends_on target $d does not exist" unless $by_id{$d};
    }
}

# ---- evaluate rows ------------------------------------------------------
my (%result, %detail, %newsha, %visiting);
evaluate($_->{claim_id}) for @rows;

# ---- report -------------------------------------------------------------
my %count;
$count{$result{$_->{claim_id}}}++ for @rows;
my $lsha = Digest::SHA->new(256)->addfile($ledger, 'b')->hexdigest;
my $tmplog = "$log.tmp.$$";
open my $lo, '>', $tmplog or die "Cannot write $tmplog: $!\n";
print $lo "# check_claims.pl run $today; ledger $ledger sha256 $lsha\n";
print $lo "# schema error: $_\n" for @schema_errors;
print $lo join("\t", qw(claim_id kind status result detail)), "\n";
print $lo join("\t", $_->{claim_id}, $_->{kind}, $_->{status},
               $result{$_->{claim_id}}, $detail{$_->{claim_id}}), "\n" for @rows;
close $lo or die "Cannot close $tmplog: $!\n";
rename $tmplog, $log or die "Cannot rename $tmplog to $log: $!\n";

my $summary = join(', ', map { "$_ " . ($count{$_} // 0) }
                   qw(PASS FAIL CHANGED BLOCKED NOTE SKIP));
print STDERR scalar(@rows), " rows: $summary; schema errors " . scalar(@schema_errors) . "\n";
print STDERR "  schema error: $_\n" for @schema_errors;
for my $r (@rows) {
    my $res = $result{$r->{claim_id}};
    print STDERR "  $res $r->{claim_id}: $detail{$r->{claim_id}}\n"
        if $res =~ /^(FAIL|CHANGED|BLOCKED)$/;
}
print STDERR "Log: $log\n";

# ---- optional update ----------------------------------------------------
if ($update) {
    if (@schema_errors) {
        print STDERR "Not updating: fix schema errors first\n";
    } else {
        my $n = 0;
        for my $r (@rows) {
            my $res = $result{$r->{claim_id}};
            next unless $res eq 'PASS' || ($res eq 'CHANGED' && $accept_changed);
            $r->{status}     = 'verified' unless $r->{status} eq 'external_only';
            $r->{checked_on} = $today;
            $r->{evidence_sha256} = $newsha{$r->{claim_id}}
                if $r->{kind} eq 'value'
                && ($r->{evidence_sha256} eq '' || $res eq 'CHANGED');
            $n++;
        }
        my $tmp = "$ledger.tmp.$$";
        open my $o, '>', $tmp or die "Cannot write $tmp: $!\n";
        print $o join("\t", @COLS), "\n";
        print $o join("\t", @{$_}{@COLS}), "\n" for @rows;
        close $o or die "Cannot close $tmp: $!\n";
        rename $tmp, $ledger or die "Cannot rename $tmp to $ledger: $!\n";
        print STDERR "Updated $n rows in $ledger\n";
    }
}

exit((@schema_errors || $count{FAIL}) ? 1 : 0);

# ---- subroutines --------------------------------------------------------
sub deps {
    my ($r) = @_;
    return grep { $_ ne '' } map { s/^\s+|\s+$//gr } split /,/, $r->{depends_on};
}

sub resolve {
    my ($p) = @_;
    return $p unless $p =~ /^\{([^}]+)\}(.*)$/s;
    return exists $PATH{$1} ? "$PATH{$1}$2" : $p;
}

sub set { my ($id, $res, $msg) = @_; $result{$id} = $res; $detail{$id} = $msg; return $res }

sub evaluate {
    my ($id) = @_;
    return $result{$id} if exists $result{$id};
    my $r = $by_id{$id} or return 'FAIL';
    return set($id, 'FAIL', 'dependency cycle') if $visiting{$id}++;
    my $res;
    if ($r->{status} eq 'retired' || $r->{status} =~ /^superseded_by:/) {
        $res = set($id, 'SKIP', $r->{status});
    } elsif ($r->{kind} eq 'value') {
        $res = ($r->{status} eq 'external_only' && !-f resolve($r->{evidence_path}))
             ? set($id, 'NOTE', "external_only, not reachable here: " . resolve($r->{evidence_path}))
             : check_value($r);
    } elsif ($r->{kind} eq 'interpretation') {
        $res = check_interpretation($r);
    } else {
        $res = set($id, 'FAIL', 'unknown kind');
    }
    delete $visiting{$id};
    return $res;
}

sub check_interpretation {
    my ($r) = @_;
    my $id = $r->{claim_id};
    return set($id, 'FAIL', 'no falsifier') if $r->{falsifier} eq '';
    my @d = deps($r);
    return set($id, 'FAIL', 'interpretation has no depends_on') unless @d;
    my (@failed, @blocked);
    for my $d (@d) {
        unless ($by_id{$d}) { push @failed, "$d (missing)"; next }
        my $dr = evaluate($d);
        if    ($dr eq 'PASS' || $dr eq 'CHANGED') { }
        elsif ($dr eq 'NOTE' || $dr eq 'BLOCKED') { push @blocked, $d }
        else                                      { push @failed, "$d ($dr)" }
    }
    return set($id, 'FAIL', 'depends on ' . join(', ', @failed)) if @failed;
    return set($id, 'BLOCKED', 'depends on unreachable external_only ' . join(', ', @blocked)) if @blocked;
    return set($id, 'PASS', 'falsifier present; dependencies pass: ' . join(', ', @d));
}

sub check_value {
    my ($r) = @_;
    my $id   = $r->{claim_id};
    my $path = resolve($r->{evidence_path});
    return set($id, 'FAIL', "evidence not found: $path") unless -f $path;
    my $sha = Digest::SHA->new(256)->addfile($path, 'b')->hexdigest;
    $newsha{$id} = $sha;
    my ($got, $err) = locate($path, $r->{locator});
    return set($id, 'FAIL', "locator $r->{locator}: $err") if defined $err;
    return set($id, 'FAIL', "expected '$r->{expected}', found '$got' at $r->{locator}")
        unless $got eq $r->{expected};
    return set($id, 'CHANGED', "value matches but evidence checksum changed (was "
                   . substr($r->{evidence_sha256}, 0, 12) . ", now " . substr($sha, 0, 12) . ")")
        if $r->{evidence_sha256} ne '' && $r->{evidence_sha256} ne $sha;
    return set($id, 'PASS', "found '$got' at $r->{locator}");
}

sub read_tsv {
    my ($path) = @_;
    open my $fh, '<', $path or return (undef, undef, "cannot read: $!");
    my ($head, @data);
    while (my $l = <$fh>) {
        $l =~ s/\r?\n\z//;
        next if $l =~ /^#/;
        if (!$head) { $head = [split /\t/, $l, -1]; next }
        push @data, [split /\t/, $l, -1];
    }
    close $fh;
    return (undef, undef, 'no header row') unless $head;
    return ($head, \@data, undef);
}

sub col_index {
    my ($head, $name) = @_;
    my @i = grep { $head->[$_] eq $name } 0 .. $#$head;
    return @i == 1 ? $i[0] : undef;
}

sub locate {
    my ($path, $loc) = @_;
    if ($loc =~ /^tsv:([^=]+)=(.*):([^:]+)$/) {
        my ($kc, $key, $col) = ($1, $2, $3);
        my ($head, $data, $err) = read_tsv($path);
        return (undef, $err) if $err;
        my $ki = col_index($head, $kc);  return (undef, "no unique column '$kc'") unless defined $ki;
        my $ci = col_index($head, $col); return (undef, "no unique column '$col'") unless defined $ci;
        my @hit = grep { defined $_->[$ki] && $_->[$ki] eq $key } @$data;
        return (undef, "no row with $kc=$key") unless @hit;
        return (undef, scalar(@hit) . " rows with $kc=$key") if @hit > 1;
        return ($hit[0][$ci] // '', undef);
    }
    if ($loc =~ /^tsvcount:([^=]+)=(.*)$/) {
        my ($col, $val) = ($1, $2);
        my ($head, $data, $err) = read_tsv($path);
        return (undef, $err) if $err;
        my $ci = col_index($head, $col); return (undef, "no unique column '$col'") unless defined $ci;
        my $n = grep { defined $_->[$ci] && $_->[$ci] eq $val } @$data;
        return ("$n", undef);
    }
    if ($loc =~ /^grep:(.+)$/s) {
        my $re = eval { qr/$1/m };
        return (undef, "bad regex: $@") unless $re;
        "" =~ /|$re/;
        return (undef, 'regex must have exactly one capture group') unless $#+ == 1;
        open my $fh, '<', $path or return (undef, "cannot read: $!");
        local $/; my $txt = <$fh>; close $fh;
        return $txt =~ $re ? ($1, undef) : (undef, 'no match');
    }
    if ($loc =~ /^line:(\d+)$/) {
        my $n = $1;
        open my $fh, '<', $path or return (undef, "cannot read: $!");
        while (my $l = <$fh>) {
            next unless $. == $n;
            $l =~ s/\r?\n\z//; close $fh; return ($l, undef);
        }
        close $fh;
        return (undef, "file has fewer than $n lines");
    }
    return (undef, 'unrecognized locator form');
}
