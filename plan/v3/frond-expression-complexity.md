# Task: Reduce Frond expression complexity at parity

**Outcome:** Frond expression parsing and evaluation become smaller, clearer,
API-stable routines across Python, PHP, Ruby, and Node.js, with byte-identical
rendering against the shared corpus and no Carbonah regression.

## Scope

- [x] Sweep open Tina4 organization issues and identify Frond-adjacent reports.
- [x] Read the governing Frond ADRs and feature audits.
- [x] Capture exact source, metrics, test, and Carbonah baselines at fresh v3 HEADs.
- [x] Reproduce PHP issues #170 and #171 across all four frameworks and classify their current status.
- [x] Confirm the shared 84-case corpus characterises the expression paths being moved.
- [x] Extract/refactor the Python expression evaluator without changing its public API.
- [x] Port the proven internal shape idiomatically to PHP, Ruby, and Node.js.
- [x] Re-run metrics and Carbonah; accept only a measured improvement with no regression.
- [x] Run every Frond suite and the full four-framework suite on the Linux lab as root.

## Parity

| Rule | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Existing expression corpus | ✅ 84 | ✅ 84 | ✅ 84 | ✅ 84 |
| Filter-before-concat precedence | ✅ | ✅ Already fixed | ✅ | ✅ |
| `number_format` separator arguments | ✅ | ✅ Already fixed | ✅ | ✅ |
| Expression evaluator decomposed | ✅ | ✅ | ✅ | ✅ |
| Full suite adds no failures vs v3 | ✅ | ✅ | ✅ | ✅ |

## Tests

- [x] Shared corpus bytes and expected outputs are identical in all four repositories.
- [x] Positive cases cover literals, lookup, arithmetic, comparison, boolean, ternary, filters, concat, calls, and grouping.
- [x] Negative cases cover undefined values, invalid operations, malformed calls, and unknown filters according to the accepted contract.
- [x] Characterisation net mutation-proved: swapping inline-if descriptor fields produced six named failures before restoration.
- [x] Existing interpreted and compiled rendering suites stay unchanged and green.
- [x] Full framework suites add no failure versus exact v3 controls on the Linux lab; infrastructure failures are named below.
- [x] Carbonah template-rendering result does not regress.

## Bugs

- [x] FROND-PRECEDENCE-171: already fixed and regression-covered in all four backends; upstream issue is stale.
- [x] FROND-NUMBER-FORMAT-170: already fixed and regression-covered in all four backends; upstream issue is stale.
- [ ] Any defect discovered while characterising the evaluator is reproduced, mutation-proved, and fixed at parity before closure.

## Commits

- Python `38e9248` — descriptor/evaluator helpers; CC average 4.55 → 3.98,
  offenders 25 → 24, duplicate lines 57 → 51.
- PHP `41568b1c` — expression scan stages; CC average 5.37 → 5.25,
  offenders 31 → 30.
- Ruby `b8935f5` — table-driven cached-form dispatch; CC average 3.72 → 3.66,
  offenders 28 → 27.
- Node.js `80f8e93` — focused evaluators plus a bounded form cache; CC average
  5.35 → 4.99, offenders 36 → 34, median template throughput approximately
  11.5k → 15.9k ops/sec in same-session controls.

## Verification

- Linux lab targeted Frond: Python 376, PHP 385 tests / 515 assertions,
  Ruby 379, Node.js 130 parity + 297 engine + 18 cache-bound; zero failures.
- Linux lab full suites at the changed SHAs: Python 5,340 passed / 67 skipped,
  PHP 5,443 tests / 18,772 assertions / 86 skipped, Ruby 5,440 examples /
  93 pending, and Node.js 8,261 passed / 57 skipped. Every failure was rerun
  against a fresh untouched `v3` clone on the same host and reproduced exactly:
  the lab native `tina4` binary lacks `has_referencing_test`; MySQL/MSSQL
  credentials are unavailable; Ruby's optional `mysql2`/`tiny_tds` drivers are
  not installed. The branch adds zero failures.
- Local Python full suite: 4,937 passed / 435 skipped, with one unrelated
  macOS socket-startup failure reproduced unchanged at the v3 baseline.
- Carbonah: no measured regression (all modelled APlus); Python within noise,
  PHP slightly faster, Ruby matched its same-session control, Node faster.

## Status: Complete
