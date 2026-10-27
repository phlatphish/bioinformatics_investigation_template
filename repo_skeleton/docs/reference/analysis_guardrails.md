# Analysis guardrails

Read at the start of every session. These rules apply to every module and to every review, audit or subagent. Adopted as D-001. Sections 1 to 7 are general; section 8 holds the rules specific to this field and question. Terms are defined in `docs/reference/glossary.md`.

## 1. Failure scope

Safeguards and reviews address failures that could change a scientific result or stop a normal run.

**In scope:**

- misclassified evidence, or evidence assigned to the wrong unit;
- missing, duplicated or silently excluded records;
- malformed input, a nonzero exit, or truncated or incomplete tool output;
- accidental reruns, output collisions and ordinary concurrent launches;
- interrupted publication;
- stale inputs or code, and accidental changes to outputs;
- results that can't be reproduced in the documented environment.

**Out of scope** (not a blocker unless explicitly widened for a task):

- a malicious process running as the same Unix user;
- root, privileged-process, host or kernel compromise;
- deliberate changes to files after publication;
- adversarial filesystem manipulation between system calls.

Checksums and validation before use detect post-publication changes. They are not a claim that files can't be changed.

## 2. Required checks

- **Tool invocation.** The command matches the tool version installed on the target server, checked before the real run.
- **Complete input and output.** Assert the expected record count at input and at output. Empty, header-only or truncated output is an error, never an all-negative result. Explicit negative and unresolved states are kept.
- **Exact thresholds.** Apply published thresholds to unrounded values.
- **Evidence counted once.** One observation counts once, even with several labels. Keep observation counts and label counts distinct.
- **Raw kept beside derived.** Keep unmodified tool output next to derived tables, so any label can be traced to its evidence.
- **Provenance.** Record the commit of the scientific code, tool and database versions, the command and the inputs (`tools/new_run.sh` does most of this).
- **Identity.** For every downloaded sequence set, check that the organism or sample name matches what was intended. Record the accession, the name and a checksum.
- **Publication.** Build in a staging location, validate, publish without overwriting, record checksums, and revalidate before downstream use (`tools/finish_run.sh`).

## 3. Review limits

- **Budget.** One implementation, one independent audit, one remediation cycle, one focused re-audit. Going further needs a concrete finding that could change a conclusion; omit, duplicate or misassign evidence; corrupt an ordinary run; or break reproducibility.
- **Finding classes.** Each finding is a scientific defect, an ordinary operational defect, or a speculative risk. Only the first two are fixed before proceeding. Speculative risks are recorded as limitations and closed.
- **Stop rule.** If review produces repeated variants of the same theoretical issue, stop and report: the invariant, the realistic failure, whether it is in scope, whether results could change, the cost of further hardening, and whether approval is needed.

### Auditor brief

Every audit uses this boundary, word for word:

> Evaluate scientific correctness, reproducibility, ordinary operational failures, accidental concurrency, and integrity within the documented failure scope. Do not treat malicious same-user, privileged, or post-publication filesystem changes as a release blocker. Do not require an architectural redesign unless a realistic in-scope failure can alter scientific results or prevent normal operation.

Each finding names the affected invariant, gives a reproducible in-scope failure, assigns a severity, and recommends the smallest correction.

## 4. Approval gates

Ask before:

- any architectural change to a workflow, or a change to an established output format;
- adding a runtime dependency or a special system requirement;
- changing the scientific evidence model;
- expanding beyond the approved module (a defect in one module never triggers redesign of another);
- exceeding the review budget.

Each request states the realistic failure being prevented, whether it affects scientific validity, whether it is in scope, the expected cost, and the simpler alternative.

## 5. Red flags: pause and report

- Successive redesigns of the same mechanism with no analysis output.
- Review that has run longer than the analysis it protects.
- Complexity that reduces portability or clarity without a documented scientific gain.
- Work taking much longer or costing much more than expected. Report before continuing.
- Any deliverable that can't be traced to preserved raw evidence.

## 6. Claims

- Quote numbers only from verified rows of `docs/state/claims_ledger.tsv`.
- Every interpretation names its falsifier and the values it depends on.
- State gaps in the evidence. Don't fill them from memory or an earlier summary.
- A retraction is recorded, never deleted (`docs/state/dead_ends.md`).
- Selection must not presuppose the result it is used to test (no circular inference). Where two evidence lines are combined, they are generated independently.

## 7. Opening a module

One page before any code, in `docs/modules/mNN_<name>/contract.md` (copy `docs/reference/contract_template.md`): the question, the exact inputs, tools and versions, thresholds with citations, outputs and where they go, the checks that define success, and the stopping condition. Work proceeds one approved phase at a time.

## 8. Field-specific rules

TODO(customize): replace the examples below with the traps specific to this investigation, each with its reason and source. Add to this section as new traps are found.

- Example, RNA-seq: batch must not be confounded with condition; check the design matrix before fitting.
- Example, GWAS: correct for population structure; report the genomic inflation factor.
- Example, metagenomics: screen for contamination and reference bias before abundance claims.
- Example, comparative genomics: verify the identity of every downloaded proteome before orthology.
