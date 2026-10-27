#!/usr/bin/env bash
# finish_run.sh -- checksum, write-protect and optionally promote a run
#
#   tools/finish_run.sh <run_dir> [file ...]
#
# 1. Writes <run_dir>/outputs.sha256 for every file in the run, and records
#    'finished' in provenance.tsv. Refuses a run that is already finished.
# 2. Write-protects the run (chmod -R a-w). To delete it later on purpose:
#    chmod -R u+w <run_dir> && rm -r <run_dir>.
# 3. If files are listed (paths relative to the run directory), copies them to
#    results/<module>/<run_id>/ through a staging directory, verifies their
#    checksums, then renames into place. Never overwrites an existing
#    destination. Promoted files are write-protected too.
set -euo pipefail
source "$(dirname "$0")/paths_lookup.sh"

[[ $# -ge 1 ]] || { sed -n '2,14p' "$0" >&2; exit 2; }
run_dir=$(cd "$1" && pwd); shift
work=$(cd "$(path_for work)" && pwd)
[[ $run_dir == "$work"/*/* ]] || { echo "not a run directory under $work: $run_dir" >&2; exit 2; }
[[ -f $run_dir/provenance.tsv ]] || { echo "no provenance.tsv; was this made by new_run.sh?" >&2; exit 2; }
[[ ! -e $run_dir/outputs.sha256 ]] || { echo "already finished: $run_dir" >&2; exit 1; }
run_id=$(basename "$run_dir"); module=$(basename "$(dirname "$run_dir")")

for f in "$@"; do
    [[ -f $run_dir/$f ]] || { echo "not a file in the run: $f" >&2; exit 2; }
done

( cd "$run_dir"
  printf 'finished\t%s\n' "$(date -Iseconds)" >> provenance.tsv
  find . -type f ! -name outputs.sha256 -printf '%P\0' | sort -z | xargs -0 -r sha256sum > outputs.sha256.tmp
  [[ -s outputs.sha256.tmp ]] || { echo "run has no files" >&2; exit 1; }
  mv outputs.sha256.tmp outputs.sha256 )
chmod -R a-w "$run_dir"
echo "finished and write-protected: $run_dir ($(wc -l < "$run_dir/outputs.sha256") files)"

[[ $# -gt 0 ]] || exit 0
results=$(path_for results)
dest="$results/$module/$run_id"
[[ ! -e $dest ]] || { echo "destination exists, not overwriting: $dest" >&2; exit 1; }
mkdir -p "$results/$module"
stage=$(mktemp -d "$results/$module/.staging_${run_id}_XXXXXX")
trap 'chmod -R u+w "$stage" 2>/dev/null; rm -rf "$stage"' EXIT
( cd "$run_dir" && cp --parents -p -- "$@" "$stage"/ )
( cd "$run_dir" && for f in "$@"; do grep -F -- "  $f" outputs.sha256 | awk -v f="$f" 'substr($0, 67) == f'; done ) > "$stage/outputs.sha256"
[[ $(wc -l < "$stage/outputs.sha256") -eq $# ]] || { echo "checksum lookup failed" >&2; exit 1; }
( cd "$stage" && sha256sum --quiet -c outputs.sha256 ) || { echo "checksum mismatch after copy" >&2; exit 1; }
cp -p "$run_dir/provenance.tsv" "$stage/provenance.tsv"
chmod -R u+w "$stage"
mv -T "$stage" "$dest"
trap - EXIT
chmod -R a-w "$dest"
echo "promoted $# file(s) to $dest"
