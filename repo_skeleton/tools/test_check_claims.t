#!/usr/bin/env perl
# test_check_claims.t -- tests for tools/check_claims.pl
#
# Run from the repository root:
#   prove tools/test_check_claims.t
#
# Builds synthetic evidence files and ledgers in a temporary directory.
# Never touches docs/state/claims_ledger.tsv. KEEP_TEST_DIR=1 keeps the files.

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Digest::SHA;

my $dir = tempdir(CLEANUP => !$ENV{KEEP_TEST_DIR});
diag("test directory kept: $dir") if $ENV{KEEP_TEST_DIR};
my @COLS = qw(claim_id module kind claim stage denominator evidence_path
              evidence_sha256 locator expected depends_on falsifier status
              checked_on manuscript_location source_ref);

# ---- synthetic evidence ---------------------------------------------------
mkdir "$dir/ext" or die $!;
sub spit { my ($p, $t) = @_; open my $o, '>', $p or die "$p: $!"; print $o $t; close $o }
spit("$dir/qc.tsv", "# comment line\nsample\treads\tstatus\nS01\t1200\tpass\nS02\t800\tfail\nS03\t1500\tpass\n");
spit("$dir/run.log", "tool 1.2.3\nLog-likelihood: -1234.56\ndone\n");
spit("$dir/ext/big.tsv", "id\tvalue\nn1\t42\n");
spit("$dir/paths.tsv", "key\tpath\nresults\t$dir/ext\nmissing\t$dir/not_here\n");
my $QC = "$dir/qc.tsv"; my $LOG = "$dir/run.log";

our @EXTRA = ();
sub row {
    my %r = (evidence_sha256 => '', depends_on => '', falsifier => '', status => 'unverified',
             checked_on => '', manuscript_location => '', source_ref => 'test',
             stage => '', denominator => '', evidence_path => '', locator => '', expected => '', @_);
    return join("\t", map { $r{$_} // '' } @COLS);
}
sub val {
    my ($id, $path, $loc, $exp, %o) = @_;
    row(claim_id => $id, module => 'm01', kind => 'value', claim => "test $id",
        stage => 'test', denominator => 'NA', evidence_path => $path,
        locator => $loc, expected => $exp, %o);
}
sub interp {
    my ($id, $deps, $fals, %o) = @_;
    row(claim_id => $id, module => 'm01', kind => 'interpretation', claim => "test $id",
        depends_on => $deps, falsifier => $fals, %o);
}
sub run {
    my ($name, @lines) = @_;
    my $l = "$dir/$name.tsv";
    spit($l, join("\t", @COLS) . "\n" . join('', map { "$_\n" } @lines));
    my $log = "$dir/$name.log";
    open my $save, '>&', \*STDERR or die $!;
    open STDERR, '>', "$dir/$name.stderr" or die $!;
    my $rc = system('perl', 'tools/check_claims.pl', '--ledger', $l, '--log', $log,
                    '--paths', "$dir/paths.tsv", @EXTRA) >> 8;
    open STDERR, '>&', $save or die $!;
    my %res;
    if (open my $i, '<', $log) {
        while (<$i>) { next if /^#|^claim_id/; my @f = split /\t/; $res{$f[0]} = $f[3] }
    }
    return ($rc, \%res, $l);
}

# 1. Each locator form passes on correct values.
my ($rc, $r) = run('locators',
    val('c001', $QC, 'tsv:sample=S02:reads', '800'),
    val('c002', $QC, 'tsvcount:status=pass', '2'),
    val('c003', $LOG, 'grep:^Log-likelihood: (\S+)', '-1234.56'),
    val('c004', $LOG, 'line:1', 'tool 1.2.3'),
    interp('c005', 'c001, c002', 'S02 passes QC on rerun'));
is($rc, 0, 'correct ledger exits 0');
is($r->{$_}, 'PASS', "$_ passes") for qw(c001 c002 c003 c004 c005);

# 2. Wrong values, missing files, missing rows and bad locators fail.
($rc, $r) = run('failures',
    val('c010', $QC, 'tsv:sample=S02:reads', '1200'),
    val('c011', "$dir/absent.tsv", 'line:1', 'x'),
    val('c012', $QC, 'tsv:sample=S09:reads', '1'),
    val('c013', $LOG, 'grep:^(Log)-(likelihood)', 'x'),
    val('c014', $LOG, 'line:99', 'x'),
    val('c015', $QC, 'bogus:1', 'x'),
    interp('c016', 'c010', 'f'));
is($rc, 1, 'failures exit 1');
is($r->{$_}, 'FAIL', "$_ fails") for qw(c010 c011 c012 c013 c014 c015 c016);

# 3. Interpretations need a falsifier and dependencies.
($rc, $r) = run('interp',
    val('c020', $QC, 'tsvcount:status=fail', '1'),
    interp('c021', 'c020', ''),
    interp('c022', '', 'f'));
is($r->{c021}, 'FAIL', 'missing falsifier fails');
is($r->{c022}, 'FAIL', 'missing depends_on fails');

# 4. Paths table: {key} resolution and external_only handling.
($rc, $r) = run('external',
    val('c030', '{results}/big.tsv', 'tsv:id=n1:value', '42'),
    val('c031', '{results}/big.tsv', 'tsv:id=n1:value', '42', status => 'external_only'),
    val('c032', '{missing}/big.tsv', 'tsv:id=n1:value', '42', status => 'external_only'),
    interp('c033', 'c032', 'f'),
    val('c034', '{results}/big.tsv', 'tsv:id=n1:value', '41', status => 'external_only'));
is($r->{c030}, 'PASS', '{key} path resolves and passes');
is($r->{c031}, 'PASS', 'reachable external_only row is checked and passes');
is($r->{c032}, 'NOTE', 'unreachable external_only row is a NOTE');
is($r->{c033}, 'BLOCKED', 'interpretation on unreachable external_only is BLOCKED');
is($r->{c034}, 'FAIL', 'reachable external_only row with wrong value fails');
($rc, $r) = run('badkey', val('c035', '{nokey}/big.tsv', 'line:1', 'x'));
is($rc, 1, 'unknown path key is a schema error');

# 5. Retired and superseded rows.
($rc, $r) = run('statuses',
    val('c040', $QC, 'tsvcount:status=pass', '9', status => 'retired'),
    val('c041', $QC, 'tsvcount:status=pass', '9', status => 'superseded_by:c042'),
    val('c042', $QC, 'tsvcount:status=pass', '2'),
    interp('c043', 'c040', 'f'));
is($r->{c040}, 'SKIP', 'retired is skipped');
is($r->{c041}, 'SKIP', 'superseded is skipped');
is($r->{c043}, 'FAIL', 'interpretation resting on a retired value fails');

# 6. Checksum change gives CHANGED, not FAIL.
($rc, $r) = run('changed', val('c050', $QC, 'tsvcount:status=pass', '2', evidence_sha256 => 'a' x 64));
is($r->{c050}, 'CHANGED', 'checksum mismatch with matching value is CHANGED');
is($rc, 0, 'CHANGED alone exits 0');

# 7. Schema errors: duplicate ID, bad module, bad status, dangling depends_on, cycle.
($rc, $r) = run('dup', val('c060', $QC, 'line:2', 'x'), val('c060', $QC, 'line:2', 'x'));
is($rc, 1, 'duplicate claim_id exits 1');
($rc, $r) = run('module', row(claim_id => 'c061', module => 'mod1', kind => 'value', claim => 'x',
    stage => 's', denominator => 'd', evidence_path => $QC, locator => 'line:2', expected => 'sample'));
is($rc, 1, 'bad module exits 1');
($rc, $r) = run('status', val('c062', $QC, 'tsvcount:status=pass', '2', status => 'accepted'));
is($rc, 1, 'bad status exits 1');
($rc, $r) = run('dangling', interp('c063', 'c999', 'f'));
is($rc, 1, 'dangling depends_on exits 1');
($rc, $r) = run('cycle', interp('c064', 'c065', 'f'), interp('c065', 'c064', 'f'));
is($r->{c064}, 'FAIL', 'dependency cycle fails');

# 8. --update records passes only.
{
    local @EXTRA = ('--update');
    my ($rc2, $r2, $l) = run('update',
        val('c070', $QC, 'tsvcount:status=pass', '2'),
        val('c071', $QC, 'tsvcount:status=pass', '3'),
        val('c072', '{results}/big.tsv', 'tsv:id=n1:value', '42', status => 'external_only'));
    open my $i, '<', $l or die $!; <$i>;
    my %st = map { chomp; my @f = split /\t/, $_, -1; ($f[0] => \@f) } <$i>;
    close $i;
    my $sha = Digest::SHA->new(256)->addfile($QC, 'b')->hexdigest;
    is($st{c070}[12], 'verified', 'passing row set to verified');
    is($st{c070}[7], $sha, 'passing row records the evidence checksum');
    like($st{c070}[13], qr/^\d{4}-\d\d-\d\d$/, 'passing row records checked_on');
    is($st{c071}[12], 'unverified', 'failing row left unverified');
    is($st{c071}[7], '', 'failing row records no checksum');
    is($st{c072}[12], 'external_only', 'passing external_only row keeps its status');
    like($st{c072}[13], qr/^\d{4}-\d\d-\d\d$/, 'passing external_only row records checked_on');
}

done_testing();
