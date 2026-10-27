# Session protocol

How every working session opens, works and closes, whether you work alone or with an AI assistant. Context summaries and memory lose history; this repository is the memory.

## Open

1. **Sync.** `git pull`, and confirm the working tree is clean (`git status`).
2. **Read.** `00_start_here.md`, `docs/reference/analysis_guardrails.md`, `docs/state/current_status.md`, the handoff of the module in hand, and the latest record in `docs/sessions/`.
3. **Check.** `perl tools/check_claims.pl`. If any row is not PASS, report it before anything else.
4. **Report.** In three sentences or fewer: the module, the phase, the next action from the handoff, and any blocker. Wait for approval before starting a phase.

## Work

- **Scope.** Work only within the approved phase. Stop at approval gates and red flags (guardrails sections 4 and 5).
- **Numbers.** Quote only verified ledger rows. A new value enters the ledger before it is used in notes, a manuscript or a grant.
- **Runs.** Start with `tools/new_run.sh`; finish with `tools/finish_run.sh` (`docs/reference/layout.md`).
- **Record as you go.** Add each decision, dead end, retraction and open question to `docs/state/` when it happens. A session can be cut off at any point.
- **Save often.** Commit after each completed unit of work, not only at close.
- **After a break or a resumed session.** Reread the module handoff and `docs/state/current_status.md` before acting. A summary of earlier work is a lead to check, not evidence.
- **Cost and time.** Warn before an expensive step. Report early when work runs longer than expected.
- **Memory conflicts.** If assistant memory or a wiki disagrees with the files, the files are right. Report the conflict; don't silently choose.

## Close

Close when the session ends or pauses, or when a phase completes.

1. **Handoff.** Update the handoff of every module the session changed.
2. **Status.** Update `docs/state/current_status.md`: the module table and "what can be claimed now".
3. **Close record.** Write `docs/sessions/YYYY-MM-DD_<topic>.md` in the format below.
4. **Index.** Add a row to `docs/reference/session_index.md`.
5. **Checks.** `perl tools/check_claims.pl`, `prove tools/test_check_claims.t`, `perl tools/make_data_inventory.pl`.
6. **Save.** Commit and push; report the commit hash. If the record is mirrored elsewhere, mirror it and confirm with `cmp`.

## Close record format

```
# YYYY-MM-DD <topic>

Session: <session or conversation ID, if any>. Modules: mNN, mNN.

## Changed
- What changed, with commit hashes.

## Recorded
- Decisions D-NNN; dead ends X-NN or R-NN; questions Q-NNN; ledger rows cNNN.

## Unresolved
- What was left open, and why.

## Next
- The next action, matching the module handoff.
```
