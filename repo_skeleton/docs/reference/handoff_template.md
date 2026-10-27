# Handoff template

Copy to `docs/modules/mNN_<name>/handoff.md`. A handoff tells a new session, in under a page, what a module has established and what to do next. Update it at the close of any session that changed the module. It holds pointers, not new results: every number cites a verified ledger row, and every statement cites a file, decision, question or dead end.

---

# mNN <module name>: handoff

**Status:** open, in progress, complete or paused. **Updated:** YYYY-MM-DD, session <id>.

**Question:** one sentence. Contract: `docs/modules/mNN_<name>/contract.md`.

## Established

- One line per result, citing ledger rows, e.g. "Sample S07 fails QC (c012)".

## Not established

- What the evidence doesn't support, and why.

## Evidence

| What | Path | Authoritative copy |
|---|---|---|
| e.g. stage 2 outputs | `{results}/mNN_<name>/<run_id>/` | server results tier |

## Retired, don't retry

- X-NN or R-NN, one line each, with the reason.

## Open

- Q-NNN, one line each.

## Decisions that bind this module

- D-NNN, one line each.

## Traps

- Module-specific pitfalls, or "see `docs/state/known_pitfalls.md`".

## Next action

- One concrete step, and whether it needs approval.
