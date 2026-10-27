#!/usr/bin/env bash
# test_template.sh -- end-to-end test of the template in a temporary root
#   bash tests/test_template.sh        (from the template directory)
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(mktemp -d); trap 'chmod -R u+w "$tmp"; rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { echo "ok   $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
refuse() { local d=$1; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
check "create investigation" "$here/new_investigation.sh" --root "$tmp" demo_rnaseq
inv="$tmp/demo_rnaseq"; repo="$inv/repo"
refuse "refuse existing investigation" "$here/new_investigation.sh" --root "$tmp" demo_rnaseq
check "second investigation shares shared/" "$here/new_investigation.sh" --root "$tmp" demo_two
for d in data/raw data/external work results scratch repo/docs/state repo/tools; do check "dir $d" test -d "$inv/$d"; done
check "no placeholders left" bash -c "! grep -rl '__NAME__\|__ROOT__\|__DATE__' '$repo' --exclude-dir=.git"
check "paths.tsv work key" grep -q "^work	$inv/work$" "$repo/config/paths.tsv"
check "first commit made" git -C "$repo" rev-parse HEAD
check "exactly five customize tags" bash -c "[ \$(grep -rn --exclude-dir=.git 'TODO(customize)' '$repo' | wc -l) -eq 5 ]"
check "setup script lists the tags" bash -c "'$here/new_investigation.sh' --root '$tmp' demo_three 2>&1 | grep -c 'TODO(customize)' | grep -qx 6"
check "tags in the five expected files" bash -c "[ \"\$(cd '$repo' && grep -rl --exclude-dir=.git 'TODO(customize)' . | sort | tr '\n' ' ')\" = './00_start_here.md ./docs/reference/analysis_guardrails.md ./docs/state/current_status.md ./docs/state/open_questions.md ' ]"

cd "$repo"
check "new module" tools/new_module.sh m01_qc
refuse "refuse reused module number" tools/new_module.sh m01_other
check "contract created" grep -q '^# m01 qc: contract' docs/modules/m01_qc/contract.md
git add -A && git commit -qm "open m01_qc"

run_dir=$(tools/new_run.sh m01_qc read_counts 20261101)
check "run dir created" test -f "$run_dir/provenance.tsv"
check "run records commit" grep -q "^repo_commit	$(git rev-parse HEAD)$" "$run_dir/provenance.tsv"
refuse "refuse reused run" tools/new_run.sh m01_qc read_counts 20261101
refuse "refuse bad module name" tools/new_run.sh qc read_counts
printf 'sample\treads\tstatus\nS01\t1200\tpass\nS02\t800\tfail\n' > "$run_dir/counts.tsv"
mkdir "$run_dir/sub"; echo big > "$run_dir/sub/big.txt"
( cd "$run_dir" && bash cmd.sh >/dev/null )
check "cmd.sh logs" grep -q '^start' "$run_dir/run.log"
check "finish and promote" tools/finish_run.sh "$run_dir" counts.tsv sub/big.txt
check "run write-protected" bash -c "! touch '$run_dir/x' 2>/dev/null"
refuse "refuse finishing twice" tools/finish_run.sh "$run_dir"
dest="$inv/results/m01_qc/20261101_read_counts"
check "promoted files present" test -f "$dest/counts.tsv" -a -f "$dest/sub/big.txt"
check "promoted checksums verify" bash -c "cd '$dest' && sha256sum --quiet -c outputs.sha256"
check "no staging left" bash -c "! ls -d '$inv/results/m01_qc/'.staging_* 2>/dev/null"
run2=$(tools/new_run.sh m01_qc read_counts 20261102); echo x > "$run2/counts.tsv"
mkdir -p "$inv/results/m01_qc/20261102_read_counts"
refuse "refuse overwriting promoted results" tools/finish_run.sh "$run2" counts.tsv

# cite the promoted file in the ledger, as an external_only {results} path
printf 'c001\tm01\tvalue\tOne of two samples fails QC\tread counting\t2 samples\t{results}/m01_qc/20261101_read_counts/counts.tsv\t\ttsvcount:status=fail\t1\t\t\texternal_only\t\t\tD-001\n' >> docs/state/claims_ledger.tsv
printf 'c002\tm01\tinterpretation\tS02 is unusable\t\t\t\t\t\t\tc001\tS02 passes QC on resequencing\tunverified\t\t\tD-001\n' >> docs/state/claims_ledger.tsv
check "ledger checks pass" perl tools/check_claims.pl --update
check "ledger row keeps external_only and is checked" grep -qP "^c001.*\texternal_only\t\d{4}-" docs/state/claims_ledger.tsv
printf 'key\tpath\nresults\t/nonexistent\n' > "$tmp/elsewhere.tsv"
check "external row is NOTE where unreachable" bash -c "perl tools/check_claims.pl --paths '$tmp/elsewhere.tsv' --log '$tmp/x.log' 2>&1 | grep -q 'NOTE 1'"
check "interpretation BLOCKED where unreachable" grep -qP "^c002\tinterpretation\t\w+\tBLOCKED" "$tmp/x.log"
refuse "unknown path key is an error" perl tools/check_claims.pl --paths /dev/null --log "$tmp/y.log"
check "checker tests" prove -Q tools/test_check_claims.t
check "inventory with scan" perl tools/make_data_inventory.pl --scan results
check "inventory lists promoted file" grep -q "$dest/counts.tsv" docs/reference/data_inventory.tsv

# Perl and R path readers
check "Paths.pm" bash -c "cd scripts && perl -Ilib -MPaths=path_for -e 'print path_for(q(work), q(m01_qc))' | grep -q '$inv/work/m01_qc'"
if command -v Rscript >/dev/null; then
    check "paths.R" bash -c "cd scripts && Rscript -e 'source(\"lib/paths.R\"); cat(path_for(\"results\", \"m01_qc\"))' | grep -q '$inv/results/m01_qc'"
else echo "skip paths.R (no Rscript)"; fi

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
