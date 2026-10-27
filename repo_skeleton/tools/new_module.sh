#!/usr/bin/env bash
# new_module.sh -- create a module's contract, handoff and folders
#
#   tools/new_module.sh <mNN_name>     e.g. tools/new_module.sh m01_qc
#
# Creates docs/modules/<mNN_name>/{contract.md,handoff.md} from the templates in
# docs/reference/, plus scripts/<mNN_name>/ and results/<mNN_name>/. Refuses an
# existing module. Add the module to docs/state/current_status.md yourself.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# -eq 1 && $1 =~ ^m[0-9]{2}_[a-z0-9_]+$ ]] || { sed -n '2,9p' "$0" >&2; exit 2; }
m=$1; num=${m%%_*}; name=${m#*_}
d="$root/docs/modules/$m"
ls -d "$root/docs/modules/${num}_"* >/dev/null 2>&1 && { echo "module number $num already used" >&2; exit 1; }
mkdir -p "$d" "$root/scripts/$m" "$root/results/$m"
for t in contract handoff; do
    awk 'f; /^---$/ {f=1}' "$root/docs/reference/${t}_template.md" \
        | sed -e "1{/^$/d}" -e "s/mNN_<name>/$m/g" -e "s/mNN <module name>/$num $name/" > "$d/$t.md"
done
touch "$root/scripts/$m/.gitkeep" "$root/results/$m/.gitkeep"
echo "created $d (contract.md, handoff.md), scripts/$m/, results/$m/"
