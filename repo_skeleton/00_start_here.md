# Start here

__NAME__: TODO(customize): one sentence on the investigation and its intended outcome, e.g. a publication.
Investigation root: `__ROOT__/__NAME__`. Created __DATE__ from the bioinformatics investigation template.

## Read at the start of every session, in this order

1. This file.
2. `docs/reference/analysis_guardrails.md`: rules for every module, review and audit.
3. `docs/state/current_status.md`: where every module stands and what can be claimed now.
4. The handoff of the module you will work in: `docs/modules/mNN_<name>/handoff.md`.
5. The latest close record in `docs/sessions/`.

Then follow `docs/reference/session_protocol.md` for opening, working and closing.

## The record

- **Authoritative:** this repository. Assistant memory, wikis and summaries of earlier sessions are for orientation only. Where they disagree with these files, the files are right; report the conflict.
- **Numbers:** quote only verified rows of `docs/state/claims_ledger.tsv`. Check with `perl tools/check_claims.pl`.
- **Gaps:** if the record doesn't answer a question, say so. Don't fill it from memory.

## Look up as needed

| File | Holds |
|---|---|
| `docs/reference/layout.md` | Directory layout and data-handling rules |
| `docs/reference/glossary.md` | Investigation-specific terms |
| `docs/state/decision_log.md` | Decisions, D-001 onwards (append only) |
| `docs/state/dead_ends.md` | Retired approaches (X-) and retractions (R-); don't retry these |
| `docs/state/open_questions.md` | Open questions, Q-001 onwards, each tied to a module |
| `docs/state/known_pitfalls.md` | Technical traps that have already cost time |
| `docs/reference/data_inventory.tsv` | Every repository file with checksum, plus external data |
| `docs/reference/external_locations.tsv` | Data held outside the repository, and the authoritative copy |
| `docs/reference/session_index.md` | Past sessions |

## Where things live

| Folder | Contents |
|---|---|
| `docs/modules/` | One folder per module: contract and handoff |
| `config/` | `paths.tsv`, specs, manifests |
| `scripts/<module>/` | Analysis code, one folder per module |
| `tools/` | Record tools: claims checker, inventory, run helpers |
| `results/<module>/` | Small result tables the ledger cites |
| `../data`, `../work`, `../results` | Large data outside git (see `docs/reference/layout.md`) |

## Working conventions

- One approved module and one approved phase at a time. Ask at every approval gate.
- TODO(customize): language conventions, e.g. Perl for pipelines, R for statistics and figures, Python for specialized libraries.
- File names in lowercase with underscores.
- Log diagnostics; don't discard them.
- Report early when work takes longer or costs more than expected.
