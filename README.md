# Bioinformatics investigation template

A directory layout plus a git-tracked investigation record for any computational biology investigation that runs over weeks or months: RNA-seq, GWAS, metagenomics, comparative genomics, phylogenomics. Generalized from the Penicillago nodositata genome project record (October 2026), with everything specific to that project removed.

It records decisions, claims and provenance. It does not run analyses; use it alongside Snakemake or Nextflow if you use one.

## Quick start

```bash
./new_investigation.sh --root /home/projects/redgillite cjb_rnaseq_heat
cd /home/projects/redgillite/cjb_rnaseq_heat/repo
# edit 00_start_here.md and docs/reference/analysis_guardrails.md section 8
tools/new_module.sh m01_qc                       # contract.md + handoff.md
run=$(tools/new_run.sh m01_qc fastqc_all)        # immutable run dir with provenance
$EDITOR "$run/cmd.sh"; (cd "$run" && bash cmd.sh)
tools/finish_run.sh "$run" summary.tsv           # checksum, write-protect, promote
perl tools/check_claims.pl                       # after adding ledger rows
```

Test the template on any machine first (about two seconds; leaves nothing behind):

```bash
bash tests/test_template.sh
```

## Starting a new project

The template clone is only the tool that makes new projects. Each project gets its own git repository: `new_investigation.sh` runs `git init` inside the new `repo/` folder, so the project's history is separate from the template's. All that's left is to give it a GitHub remote.

### Once per machine

Clone the template somewhere outside your project folders and leave it there:

```bash
mkdir -p ~/tools && cd ~/tools
git clone git@github.com:<github_user>/bioinformatics_investigation_template.git
```

Set a git identity, or the first commit is skipped (the files are left staged):

```bash
git config --global user.name  "<github_user>"
git config --global user.email "<id>+<github_user>@users.noreply.github.com"
```

### For each new project

```bash
# 1. create the investigation (the first commit happens here)
~/tools/bioinformatics_investigation_template/new_investigation.sh \
    --root /home/projects/<group> <project_name>

# 2. give it its own private GitHub repository and push
cd /home/projects/<group>/<project_name>/repo
gh repo create <project_name> --private --source . --remote origin --push
```

Without `gh`, create an empty private repository called `<project_name>` on github.com (no README, licence or .gitignore), then:

```bash
git remote add origin git@github.com:<github_user>/<project_name>.git
git push -u origin main
```

From then on, the session protocol's `git pull`, `git commit` and `git push` work against that project's repository.

### Points to know

- **Only `repo/` goes to GitHub.** `data/`, `work/`, `results/` and `scratch/` sit beside it, outside git, so large data is never pushed. Back them up by the server's own means.
- **Projects are copies, not links.** Later improvements to the template don't reach existing projects. Pull the template (`git -C ~/tools/bioinformatics_investigation_template pull`) before creating a new project. To bring an updated tool into an existing project, copy the file across, commit it, and record the change in that project's decision log.
- **`config/paths.tsv` holds this machine's absolute paths.** That is harmless in a private repository. For a clone on another machine, use `INVESTIGATION_PATHS` (see `repo_skeleton/config/readme.md`).
- **Don't use GitHub's "template repository" button.** It copies the files without the setup script's name substitution, data folders or `paths.tsv`.

## What gets created

```
<root>/
├── shared/{databases,references,envs}/   created only if missing
└── <name>/
    ├── readme.md
    ├── repo/          git: 00_start_here.md, docs/, config/, scripts/, tools/, workflow/, envs/, tests/, results/
    ├── data/raw/      md5sums.txt
    ├── data/external/ manifest.tsv (accession, organism or sample, identity check)
    ├── work/          runs: <module>/<YYYYMMDD_description>/
    ├── results/       promoted outputs: <module>/<run_id>/
    └── scratch/
```

The rules are in `repo_skeleton/docs/reference/layout.md`, adopted as D-002 in each new investigation.

## The record (repo/docs/)

| File | Purpose |
|---|---|
| `00_start_here.md` | Entry point; reading order for every session |
| `reference/analysis_guardrails.md` | General rules (sections 1-7) plus field-specific rules (section 8, to fill in) |
| `reference/session_protocol.md` | How sessions open, work and close |
| `reference/layout.md` | Directory layout and data rules |
| `reference/contract_template.md`, `handoff_template.md` | One pair per module |
| `reference/glossary.md`, `session_index.md`, `external_locations.tsv` | Lookups |
| `state/current_status.md` | Living status |
| `state/decision_log.md` | Append-only decisions (D-001 and D-002 pre-filled) |
| `state/dead_ends.md`, `open_questions.md`, `known_pitfalls.md` | Retired approaches, open questions, traps |
| `state/claims_ledger.tsv` | One row per reportable claim (`claims_ledger_readme.md`) |

## Tools (repo/tools/)

| Tool | Does |
|---|---|
| `check_claims.pl` | Checks every ledger row against its evidence file; `--update` records passes |
| `test_check_claims.t` | 39 unit tests for the checker (`prove tools/test_check_claims.t`) |
| `make_data_inventory.pl` | Inventory of repository files with checksums; `--scan <key>` adds data tiers |
| `new_module.sh` | Contract and handoff from the templates |
| `new_run.sh` | Run directory with provenance, env export and `cmd.sh` |
| `finish_run.sh` | Checksums, write-protection, staged promotion to `results/` |
| `scripts/lib/Paths.pm`, `paths.R` | Read `config/paths.tsv` from Perl or R |

Perl and shell use core modules and coreutils only; R uses base R only.

## Light use

For a short investigation (a few weeks, one or two modules), keep these and leave the rest as stubs: `00_start_here.md`, the guardrails, `decision_log.md`, `dead_ends.md`, one contract and handoff per module, and ledger rows only for numbers that will be published. The layout and run tools are worth keeping at any size.

## Changes from the Penicillago record

- The record lives in `repo/docs/` inside the analysis repository, so one git history holds code and record. Tools live in `tools/` rather than `reference/`.
- Any module number `mNN`, not m01-m11.
- `gp02_only` became `external_only`. Such a row is checked wherever its file is reachable and reported as NOTE elsewhere; `--update` keeps the status.
- Ledger evidence paths can use `{key}/...` from `config/paths.tsv`, so large outputs outside git are checked on the server.
- Saving uses git (`git commit`, `git push`), not `pplx project files submit`; there is no Brain step.
- The guardrails keep sections 1-7 nearly unchanged, add a general rule against circular selection, and move field-specific traps to section 8.

## Known limits

- Locators read text files only (`tsv:`, `tsvcount:`, `grep:`, `line:`). Values in HDF5, AnnData or databases need an exported text table, or a new locator type.
- The approval steps assume one investigator. A team should name the approver in each decision.
- `paths.R` was written to the same contract as `Paths.pm` but has only been tested by `tests/test_template.sh` on a machine with R.
