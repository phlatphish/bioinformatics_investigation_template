# paths_lookup.sh -- sourced by the shell tools; defines path_for KEY
# Reads config/paths.tsv from the repository root (or $INVESTIGATION_PATHS).
_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_paths_tsv="${INVESTIGATION_PATHS:-$_repo_root/config/paths.tsv}"
path_for() {
    local v
    v=$(awk -F'\t' -v k="$1" '$1==k {print $2; n++} END {exit n==1?0:1}' "$_paths_tsv") \
        || { echo "path key '$1' missing or duplicated in $_paths_tsv" >&2; return 1; }
    printf '%s\n' "$v"
}
