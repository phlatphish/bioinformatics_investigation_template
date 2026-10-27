# Contract template

Copy to `docs/modules/mNN_<name>/contract.md` (or run `tools/new_module.sh mNN_<name>`). One page, written and approved before any code (guardrails section 7).

---

# mNN <module name>: contract

**Status:** draft, approved YYYY-MM-DD, or superseded. **Approved by:** <name>, decision D-NNN.

## Question

One sentence: the scientific or operational question this module answers.

## Why now

What depends on it, and which open questions (Q-NNN) it addresses.

## Exact inputs

| Input | Path or accession | Checksum or version | Count asserted at input |
|---|---|---|---|

## Tools and versions

| Tool | Version | Environment (`envs/<file>.yml`) | Invocation checked on target server |
|---|---|---|---|

## Thresholds

| Parameter | Value | Citation or reason |
|---|---|---|

## Outputs

| Output | Location | Ledger rows |
|---|---|---|
| e.g. summary table | `results/mNN_<name>/` | cNNN |
| e.g. large alignment set | `{results}/mNN_<name>/<run_id>/` | — |

## Phases

1. Phase A: <what>, ends with <check>. Approval needed before phase B.
2. Phase B: ...

## Checks that define success

1. ...

## Falsifiers

What result would contradict the expected interpretation.

## Stopping condition

When the module is complete, and what happens if a check fails.

## Out of scope

What this module will not do.
