# Directory layout and data rules

Adopted as D-002. Paths are read from `config/paths.tsv`; scripts never hard-code an absolute path.

## Layout

```
__ROOT__/
├── shared/                          # used by many investigations
│   ├── databases/<name>/<version>/  # readme.md: source, date, md5, command
│   ├── references/<organism>/<accession>/
│   └── envs/                        # exported conda env .yml files
└── __NAME__/
    ├── repo/                        # this git repository
    │   ├── 00_start_here.md
    │   ├── docs/                    # reference/, state/, modules/, sessions/
    │   ├── config/                  # paths.tsv, specs, manifests
    │   ├── scripts/<module>/        # e.g. m01_qc/; shared code in scripts/lib/
    │   ├── tools/                   # record tools
    │   ├── workflow/                # Snakefile or Nextflow, if used
    │   ├── envs/                    # env .yml per module
    │   ├── tests/
    │   └── results/<module>/        # small tables cited by the ledger
    ├── data/
    │   ├── raw/                     # read-only; md5sums.txt; never edited
    │   └── external/                # downloaded inputs; manifest.tsv
    ├── work/<module>/<run_id>/      # intermediates; regenerable; not backed up
    ├── results/<module>/<run_id>/   # large outputs worth keeping
    └── scratch/                     # temporary; purge freely
```

## Rules

1. **Folders are named by module, not tool:** `m03_differential_expression/`, not `deseq2/`. Folder names match contracts and handoffs.
2. **Runs are immutable.** `run_id` is `YYYYMMDD_short_description`. Start every run with `tools/new_run.sh <module> <description>`, which refuses to reuse a directory and records provenance (`provenance.tsv`: host, user, repo commit, dirty flag, conda env; `env.yml`; `cmd.sh`; `run.log`). A rerun gets a new run directory.
3. **Finish runs explicitly.** `tools/finish_run.sh <run_dir> [file ...]` writes `outputs.sha256`, write-protects the run, and copies any listed files to `results/<module>/<run_id>/` through a staging directory, verifying checksums and never overwriting.
4. **Cite exact runs.** The claims ledger and `external_locations.tsv` cite an exact run path, never a `latest` symlink. Use `{key}/...` in ledger evidence paths for data outside the repository, e.g. `{results}/m03_differential_expression/20261101_deseq2/de_summary.tsv`.
5. **Raw data is protected.** After deposit: `md5sum` into `data/raw/md5sums.txt`, then `chmod -R a-w data/raw`. Downloaded inputs are listed in `data/external/manifest.tsv` with accession, organism name, date and checksum.
6. **Shared databases are versioned.** One directory per version, each with a `readme.md` from `shared/databases/readme_template.md`. A database is never updated in place.
7. **Backup by tier:** `repo/` on the git remote; `data/` and `results/` backed up; `work/` and `scratch/` not backed up. When space runs short, delete from `scratch/`, then from `work/` runs whose outputs are finished.
8. **Retractions stay in place.** A retracted run is recorded in `docs/state/dead_ends.md`, not moved, so cited paths keep working. Deleting data needs an explicit decision.
