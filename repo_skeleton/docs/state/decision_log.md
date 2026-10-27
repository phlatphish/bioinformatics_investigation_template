# Decision log

Append only. Never edit an entry. To reverse an entry, add a new one that names the old entry under "Supersedes", and mark the old one as superseded in its Status line.

Who decided:
- `user`: the investigator stated it.
- `accepted`: an assistant proposal the investigator explicitly accepted.
- `assistant`: an assistant recommendation acted on without explicit approval in the record. These are candidates for review.

---

### D-001 Adopt the investigation record and guardrails
- Date: __DATE__. Who decided: user. Source: setup
- Decision: The record in this repository is authoritative. `docs/reference/analysis_guardrails.md` and `docs/reference/session_protocol.md` apply to every module and session. Every reported number is held in `docs/state/claims_ledger.tsv`.
- Reason: Results must be traceable to preserved evidence, and context must survive between sessions.

### D-002 Adopt the directory layout
- Date: __DATE__. Who decided: user. Source: setup
- Decision: Code and record in `repo/`; large data in `data/`, `work/`, `results/` and `scratch/` outside git; shared databases and references in `__ROOT__/shared/`. Rules in `docs/reference/layout.md`.
- Reason: Separates what git tracks from what must be backed up, regenerated or discarded, and keeps cited paths stable.
