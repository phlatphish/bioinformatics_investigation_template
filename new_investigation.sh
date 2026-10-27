#!/usr/bin/env bash
# new_investigation.sh -- create a bioinformatics investigation from this template
#
#   ./new_investigation.sh --root <dir> <name>
#   e.g. ./new_investigation.sh --root /home/projects/redgillite cjb_rnaseq_heat
#
# Creates, without touching anything that already exists:
#   <root>/shared/{databases,references,envs}/    (only what is missing)
#   <root>/<name>/{data/raw,data/external,work,results,scratch}/
#   <root>/<name>/repo/                            git repository with the record
# and writes repo/config/paths.tsv with absolute paths for this machine.
# Refuses if <root>/<name> exists. Makes the first commit if git has an
# author identity configured; otherwise leaves the files staged.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root=""; name=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --root) root=$2; shift 2 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        -*) echo "unknown option $1" >&2; exit 2 ;;
        *) name=$1; shift ;;
    esac
done
[[ -n $root && -n $name ]] || { sed -n '2,14p' "$0" >&2; exit 2; }
[[ $name =~ ^[a-z0-9_]+$ ]] || { echo "name: lowercase letters, digits and underscores only" >&2; exit 2; }
[[ -d $root ]] || { echo "root does not exist: $root" >&2; exit 2; }
root=$(cd "$root" && pwd)
inv="$root/$name"
[[ ! -e $inv ]] || { echo "already exists, not touching: $inv" >&2; exit 1; }
today=$(date +%Y-%m-%d)

# shared tier: create only what is missing
mkdir -p "$root/shared/databases" "$root/shared/references" "$root/shared/envs"
[[ -e $root/shared/readme.md ]] || cp "$here/shared_skeleton/readme.md" "$root/shared/readme.md"
[[ -e $root/shared/databases/readme_template.md ]] || cp "$here/shared_skeleton/databases/readme_template.md" "$root/shared/databases/"

# investigation tiers
mkdir -p "$inv"/{data/raw,data/external,work,results,scratch}
cp -r "$here/repo_skeleton" "$inv/repo"
: > "$inv/data/raw/md5sums.txt"
printf 'file\taccession\torganism_or_sample\tsource_url\tdownloaded_on\tsha256\tidentity_checked\n' > "$inv/data/external/manifest.tsv"
cat > "$inv/readme.md" <<TXT
# $name

Start at repo/00_start_here.md. Layout and data rules: repo/docs/reference/layout.md.
Backed up: repo (git remote), data/, results/. Not backed up: work/, scratch/.
TXT

# placeholders
find "$inv/repo" -type f \( -name '*.md' -o -name '*.tsv' \) -print0 \
    | xargs -0 sed -i -e "s|__NAME__|$name|g" -e "s|__ROOT__|$root|g" -e "s|__DATE__|$today|g"

# paths for this machine
{
    printf 'key\tpath\n'
    printf 'investigation\t%s\n' "$inv"
    printf 'repo\t%s\n' "$inv/repo"
    printf 'raw\t%s\n' "$inv/data/raw"
    printf 'external\t%s\n' "$inv/data/external"
    printf 'work\t%s\n' "$inv/work"
    printf 'results\t%s\n' "$inv/results"
    printf 'scratch\t%s\n' "$inv/scratch"
    printf 'shared_databases\t%s\n' "$root/shared/databases"
    printf 'shared_references\t%s\n' "$root/shared/references"
    printf 'shared_envs\t%s\n' "$root/shared/envs"
} > "$inv/repo/config/paths.tsv"

# git
cd "$inv/repo"
git init -q -b main
git add -A
if git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
    git commit -q -m "Create $name from bioinformatics investigation template"
    echo "first commit: $(git rev-parse --short HEAD)"
else
    echo "git has no author identity; files are staged but not committed" >&2
fi
( perl tools/check_claims.pl >/dev/null 2>&1 && prove -Q tools/test_check_claims.t >/dev/null 2>&1 ) \
    && echo "record tools: checks pass" || echo "warning: record tool checks failed; run prove -v tools/test_check_claims.t" >&2
echo "created $inv"
echo
echo "customize these before the first module (README, 'Customize a new project'):"
( cd "$inv/repo" && grep -rn --exclude-dir=.git 'TODO(customize)' . | sed 's|^\./|  |' | cut -c1-110 )
echo "check what is left with: grep -rn 'TODO(customize)' $inv/repo --exclude-dir=.git"
echo "then: tools/new_module.sh m01_<name>"
