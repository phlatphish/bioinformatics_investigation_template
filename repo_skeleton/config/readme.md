# Config

- `paths.tsv`: the only place absolute paths are written. Scripts read it through `scripts/lib/Paths.pm` (Perl) or `scripts/lib/paths.R` (R). Moving data means editing this file.
- Specs and manifests for each module, as tab-separated files named `<module>_<what>.tsv`.

`paths.tsv` is written for the machine where the investigation was created (e.g. the analysis server). On another machine (e.g. a laptop clone), point the tools at a local copy without editing the tracked file: `INVESTIGATION_PATHS=~/demo_paths.tsv perl tools/check_claims.pl`, or `--paths` for the checker. Ledger rows marked `external_only` then report NOTE instead of FAIL where their data isn't present.
