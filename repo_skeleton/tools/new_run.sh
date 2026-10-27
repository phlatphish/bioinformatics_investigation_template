#!/usr/bin/env bash
# new_run.sh -- create an immutable run directory with provenance
#
#   tools/new_run.sh <module> <description> [YYYYMMDD]
#   e.g. tools/new_run.sh m01_qc fastqc_all_samples
#
# Creates work/<module>/<YYYYMMDD>_<description>/ (refuses an existing one) with:
#   provenance.tsv   run_id, created, host, user, repo commit, dirty flag, conda env
#   git_status.txt   uncommitted changes at creation, if any
#   env.yml          conda env export of the active environment, if any
#   cmd.sh           the run's command script (edit, then run it from the run dir)
#   run.log          written by cmd.sh
# Prints the run directory path.
set -euo pipefail
source "$(dirname "$0")/paths_lookup.sh"

[[ $# -ge 2 && $# -le 3 ]] || { sed -n '2,13p' "$0" >&2; exit 2; }
module=$1; desc=$2; day=${3:-$(date +%Y%m%d)}
[[ $module =~ ^m[0-9]{2}_[a-z0-9_]+$ ]] || { echo "module must look like m01_qc" >&2; exit 2; }
[[ $desc =~ ^[a-z0-9_]+$ ]] || { echo "description: lowercase letters, digits and underscores only" >&2; exit 2; }
[[ $day =~ ^[0-9]{8}$ ]] || { echo "date must be YYYYMMDD" >&2; exit 2; }

run_id="${day}_${desc}"
work=$(path_for work)
mkdir -p "$work/$module"
run_dir="$work/$module/$run_id"
mkdir "$run_dir" 2>/dev/null || { echo "run directory exists, refusing to reuse: $run_dir" >&2; exit 1; }

commit=$(git -C "$_repo_root" rev-parse HEAD 2>/dev/null || echo none)
dirty=no
if [[ -n "$(git -C "$_repo_root" status --porcelain 2>/dev/null)" ]]; then
    dirty=yes
    git -C "$_repo_root" status --porcelain > "$run_dir/git_status.txt"
fi
env_name=${CONDA_DEFAULT_ENV:-none}
if [[ $env_name != none ]] && command -v conda >/dev/null 2>&1; then
    conda env export --no-builds > "$run_dir/env.yml" 2> "$run_dir/env_export.log" \
        || echo "conda env export failed; see env_export.log" >&2
fi

{
    printf 'field\tvalue\n'
    printf 'run_id\t%s\n' "$run_id"
    printf 'module\t%s\n' "$module"
    printf 'created\t%s\n' "$(date -Iseconds)"
    printf 'host\t%s\n' "$(hostname -s)"
    printf 'user\t%s\n' "$(id -un)"
    printf 'repo\t%s\n' "$_repo_root"
    printf 'repo_commit\t%s\n' "$commit"
    printf 'repo_dirty\t%s\n' "$dirty"
    printf 'conda_env\t%s\n' "$env_name"
} > "$run_dir/provenance.tsv"

cat > "$run_dir/cmd.sh" <<CMD
#!/usr/bin/env bash
# $module $run_id -- run from this directory: bash cmd.sh
set -euo pipefail
exec > >(tee -a run.log) 2>&1
echo "start \$(date -Iseconds)"
# record tool versions first, e.g.:
# fastqc --version
# then the commands, reading inputs via config/paths.tsv keys:
# perl $_repo_root/scripts/$module/<script>.pl ...
echo "end \$(date -Iseconds)"
CMD
touch "$run_dir/run.log"
[[ $dirty == yes ]] && echo "warning: repository has uncommitted changes (see git_status.txt)" >&2
echo "$run_dir"
