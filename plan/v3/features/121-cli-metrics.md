# Feature 121: CLI metrics (native code-health engine)

## Identity and status

- Matrix identity: 121 - `tina4 metrics` (code-health offenders: complexity, MI, large files, untested,
  duplication)
- Audit state: decision-ready
- Audit note: NATIVE Rust engine (ADR-0002), not delegated. Scans SOURCE directly via tree-sitter for
  Python / PHP / Ruby / TypeScript+JS / Rust, with NO Tina4 project and NO running framework required.
  Measured 2026-08-11 from `tina4/src/metrics.rs` and the CLI `CLAUDE.md` (which documents it in depth),
  cross-referenced with the framework metrics engine (`tina4_python/dev_admin/metrics.py`, the formula
  master) and two known-open memories (the DRY fingerprint-collision bug; the PHP offender-cap gap).
- Dependencies: tree-sitter + the per-language grammar crates (~6MB in the release binary). No framework.
- Dependants: developers checking code health; CI gates (`--fail-on`).
- Existing ADRs: ADR-0002 (native, language-agnostic metrics).

- Catalog phase: CLI (native Rust engine)

## Why this feature exists

`tina4 metrics` reports the worst offenders in a codebase - high cyclomatic complexity, low
maintainability index, large files, untested code, and duplication - so a team can find the risky code
without a running app. It is native and language-agnostic: one Rust engine parses five languages through
tree-sitter, so the same numbers come out whatever the project is written in, and it can gate CI with
`--fail-on`.

## Boundary

This packet owns the native metrics engine: the per-file metrics (LOC, cyclomatic complexity,
maintainability index, coupling, function count), the offender ranking, the DRY duplicate detector, the
parse-health guard, and the flags. It shares its FORMULAS with the Python master (`metrics.py`) by design
(locked by a parity test) but is a separate implementation.

It does NOT own the framework's own `dev_admin/metrics.py` runtime (the in-app metrics), though it must
stay formula-compatible with it.

## Existing implementation evidence

- Dispatch: `main.rs:405` `Commands::Metrics { path, fail_on, json, top }` -> `metrics.rs`.
- Engine (per the CLI `CLAUDE.md`): scans source directly for Python/PHP/Ruby/TS+JS/Rust via tree-sitter;
  per-file LOC / CC / MI / coupling / function count; offenders with `--fail-on warn|error`.
- Formula parity: CC/MI/thresholds identical to the Python master `metrics.py`, locked by a real parity
  test.
- DRY detection: cross-file duplicate detection via AST-shape hashing (Baxter-style), language-agnostic;
  finds Type-1 (exact) clones plus consistent identifier and same-kind literal renaming. NOT full Type-2
  (comments are hashed, so adding a comment breaks the match - measured in all five languages, locked by a
  test). Type-3/4 are NOT detected.
- Parse-health guard: a file under 95% of lines parsing cleanly, or an AST nesting deeper than 800 levels
  (which used to abort the whole scan with a stack overflow), is REFUSED - excluded from every average,
  listed under `unparsed` in `--json`, counted as `files_refused`, and raised as a `warn` offender.
- No Pascal/Delphi grammar: the only crate (tree-sitter-pascal 0.10.2) leaves 51.5% of the real
  tina4delphi corpus unparsed, so `.pas` is NOT claimed rather than reported wrong.

## Public surface contract

`tina4 metrics [--top N] [--json] [--fail-on warn|error] [--path DIR|FILE]`. Human table by default;
`--json` for tooling (includes `unparsed` + `files_refused`). `--fail-on` gates CI (non-zero exit on a
warn/error offender, including a refused file).

## Inputs and outputs

- Input: a directory or file of source (any of the five supported languages). Output: ranked offenders
  (or JSON), and an exit code gated by `--fail-on`.
- A file the engine cannot parse cleanly is refused (not silently dropped, not reported with wrong
  numbers) - the honest failure mode.

## Lifecycle and operation graph

1. Walk the path (skipping node_modules/vendor/.git/target/dist/build/__pycache__).
2. Parse each file with the matching tree-sitter grammar; apply the parse-health guard (refuse < 95% /
   > 800 nesting).
3. Compute per-file metrics; hash AST shapes for DRY across files.
4. Rank offenders; print the table or JSON; set the exit code per `--fail-on`.

## Configuration and precedence

- Flags only (`--top`, `--json`, `--fail-on`, `--path`). No env. The thresholds match the Python master.

## Failures, side effects and security

- Read-only over source; no side effects, no security surface.
- Parse-health guard is the safety mechanism: it turned a whole-scan stack-overflow abort (deep nesting)
  into a per-file refusal - a good robustness fix.
- METRICS-DRY-COLLISION (known open): the shipped DRY detector has a fingerprint-collision bug (per the
  design memory) - distinct code can share a fingerprint and be reported as a clone (a false positive), or
  the reverse. This is a real accuracy defect in the duplicate detector.
- METRICS-OFFENDER-CAP (known open): the offender cap was fixed in four languages but PHP is pending -
  so PHP metrics may over- or under-report offenders relative to the others.

## Wire and persistence contract

`--json` is the machine contract: per-file metrics plus `unparsed` (refused files) and `files_refused` in
the summary. No persisted state. The formula constants (CC/MI thresholds) are the shared contract with
`metrics.py`.

## Providers and substitutability

The provider is the tree-sitter grammar per language (Python/PHP/Ruby/TS+JS/Rust). Delphi is deliberately
absent (the grammar is inadequate). Adding a language means adding a grammar + a metrics mapping.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| METRICS-DRY-COLLISION | The DRY duplicate detector has a known fingerprint-collision bug (AST-shape hashing can collide distinct code, or miss a real clone). This produces false clone reports (or misses), undermining the duplication metric. | FIX per the design memory: strengthen the fingerprint (include a discriminator that distinguishes colliding shapes) and add a regression with the known colliding pair. This is the highest-value metrics fix. |
| METRICS-OFFENDER-CAP | The offender cap (limit on reported offenders) was fixed in four languages but PHP is pending, so PHP output can differ from the others. | Finish the PHP offender-cap fix so all five languages cap identically. |
| METRICS-DRY-TYPE2 | DRY is Type-1 + renaming only; adding a COMMENT breaks the match (comments are hashed), and Type-3/4 are not detected. This is documented and locked by a test, but a user may expect comment-insensitive matching. | No code change required (it is honest and tested); consider hashing code tokens only (ignore comments) so a comment does not defeat clone detection - an accuracy improvement, owner call. |
| METRICS-NO-DELPHI | `.pas`/Delphi is not measured (the grammar is inadequate). Documented and correct (better than reporting wrong numbers), but leaves tina4delphi uncovered. | No action; revisit if a capable Delphi grammar appears. |

## Owner decisions

- METRICS-DEC-01 (proposed): fix the DRY fingerprint collision (highest value) and finish the PHP
  offender-cap; decide whether to make DRY comment-insensitive.

## Proposed conformance fixture

Native Rust tests (they already exist for the formula parity and the DRY comment-break): add the DRY
collision regression (a known colliding pair that must NOT be reported as a clone, and a real clone that
MUST be), the PHP offender-cap parity (same cap as the other four), and a parse-health case (a > 800-deep
file is refused, not crashed, and appears under `files_refused`).

## Integration map

- Dispatch: `main.rs` `Commands::Metrics` -> `metrics.rs`.
- Formula master: `tina4_python/dev_admin/metrics.py` (parity-locked).
- Grammars: tree-sitter Python/PHP/Ruby/TypeScript/Rust.
- Consumers: CI (`--fail-on`), tooling (`--json`).

## Breaking changes and migration

- Fixing the DRY collision changes some duplicate reports (fewer false positives / more true positives) -
  an accuracy improvement, document it.
- The PHP offender-cap fix aligns PHP output with the others.

## Implementation backlog

1. Fix METRICS-DRY-COLLISION with the colliding-pair regression.
2. Finish the PHP offender-cap (METRICS-OFFENDER-CAP).
3. Decide DRY comment-insensitivity (METRICS-DRY-TYPE2).

## Porting capsule

`tina4 metrics` is one native Rust engine; there is nothing to port across the frameworks (it replaces
per-language metrics for the CLI). A clean-room reimplementation needs: tree-sitter parsing for the five
languages, per-file CC/MI/LOC/coupling matching the `metrics.py` formulas, AST-shape DRY hashing with a
collision-resistant fingerprint, a parse-health guard (refuse < 95% clean or > 800 nesting, never crash
the scan), offender ranking with a consistent cap, and `--top`/`--json`/`--fail-on`/`--path`. Do not
claim a language whose grammar cannot parse it (the Delphi lesson).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage (JSON) and grammar contracts complete.
- [x] Native single-implementation + known defects recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases (DRY collision, PHP cap, parse-health) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
