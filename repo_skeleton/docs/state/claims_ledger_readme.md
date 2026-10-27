# Claims ledger

`claims_ledger.tsv` holds one row per reportable claim. Check it with `perl tools/check_claims.pl` (read-only) or `--update` (records passes).

## Columns

| Column | Meaning |
|---|---|
| claim_id | `c001` onwards; never reused |
| module | `mNN` |
| kind | `value` (checkable number or string) or `interpretation` |
| claim | The claim in words |
| stage | Pipeline stage the value comes from |
| denominator | What it is a count or fraction of |
| evidence_path | File holding the value: repository-relative, absolute, or `{key}/...` resolved by `config/paths.tsv` |
| evidence_sha256 | Filled by `--update`; a later change gives CHANGED |
| locator | Where in the file (below) |
| expected | The value as quoted |
| depends_on | For interpretations: comma-separated claim IDs |
| falsifier | For interpretations: what result would contradict it |
| status | `unverified`, `verified`, `external_only`, `retired` or `superseded_by:cNNN` |
| checked_on | YYYY-MM-DD of the last pass |
| manuscript_location | Where it is quoted, if anywhere |
| source_ref | Decision, session or file that produced it |

## Locators

- `tsv:<key_column>=<key>:<value_column>`: the value in one row of a tab-separated file with a header.
- `tsvcount:<column>=<value>`: the number of rows where the column equals the value.
- `grep:<regex with one capture group>`: the first capture in the file.
- `line:<n>`: the whole of line n.

Lines starting with `#` are ignored in tab-separated files.

## Results

PASS, FAIL, CHANGED (value matches, file changed), BLOCKED (interpretation resting on an unreachable external row), NOTE (`external_only` row whose file isn't reachable from here), SKIP (retired or superseded). An `external_only` row is checked normally on a machine where its file is reachable.
