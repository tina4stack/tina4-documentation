# Maintainability + Optimization Release (committed — next release)

## Why (owner directive, 2026-07-25)
Tina4 ships `tina4 metrics` and preaches one-concern-per-file + ~5000 LOC/language,
yet its own core carries 3,000-line modules at maintainability index 0.0 and the
framework average sits at 27.8 (floor 40). We cannot proclaim "helps you write
better code" with holes like this. The next release closes them. This is a
dedicated release program, not a side-quest.

## The credibility fix has THREE parts (all must ship)
1. **Split the monoliths by concern** (see maintainer skill "Second pass: split
   large modules by concern"). Behaviour-preserving, API-stable, one split/commit,
   full suite unchanged. Python master leads; PHP/Ruby/Node mirror the same shape.
2. **Optimise the hot paths while in there** — Carbonah before/after on render /
   serialise / query / dispatch (the Frond expr-cache work is the first of these).
3. **Wire `metrics --fail-on` as a CI GATE in all 4** — the actual root cause was
   NOT that metrics missed it (it flagged 166 offenders / MI 27.8 for months); it
   was that nothing ENFORCED it. Gate it so a NEW error-severity offender fails the
   build, like the test suite. Without this, the monoliths grow back. Set the
   thresholds at today's-worst-minus-epsilon and ratchet down each release (never
   let it regress; don't fail the build on day one for the existing debt — grandfather
   the current offenders, block NEW ones, and burn the grandfathered list down).

## Tool defects found while confirming metrics (fix as part of this)
- **Node `tina4 metrics` scans the built bundle** (`dist/bin.js`, files: 1) instead
  of `packages/*/src` — so per-source analysis is impossible via the CLI default.
  Fix the default scan root (or require `--path`) so Node matches Python's per-file
  report. Confirm PHP + Ruby scan real source too.
- **Complexity nested-function over-count** (minor, known): Python `ast.walk` folds a
  nested inner function's decision points into its parent's CC. Directionally fine,
  but fix for accurate absolute numbers (mirror the fix in the other 3 counters).

## Offender inventory (LOC, from wc -l — the accurate per-source picture)
RE-MEASURED 2026-07-26 (numbers stable vs first pass). Per-framework offender totals:
- Python : 98 src files, 24 >600 LOC, 9 >1000
- PHP    : 137 src files, 33 >600 LOC, 19 >1000  <- worst ratio
- Ruby   : 116 src files, 22 >600 LOC, 9 >1000
- Node   : 137 src files, 29 >600 LOC, 14 >1000
- tina4-js: 29 src files, 0 >600 LOC (largest rtc.ts 463) -> CLEAN. The frontend has NO
  oversized-module problem; the tina4-js reframe is a SKILL-WORDING change, not a source
  cleanup (still gated on the frontend eval arm).

SAME subsystems in every backend; Python master leads each split.
- dev-admin: Py 3556 / PHP 3867 / Ruby 2148 / Node 3008  <- worst everywhere
- frond engine: 2845 / 2928 / 2476 / 2977
- cli|generate: Py 3271 / Ruby 3252 / Node generate 1960
- server: Py 3018 / PHP 1907 / Node 1728
- mcp: Py 1084 / PHP 2187 / Ruby 1384 / Node 2202
- orm: Py 1389 / PHP 2661 / Ruby 1156 / Node 1655
- database: Py 1223 / PHP 1756 / Ruby 1363 / Node 1589
- migration: Py 1015 / PHP 1542 / Node 1356
- **metrics (the tool itself): PHP 1565 / Node 1390 / Ruby 1071 / Py dev_admin/metrics.py 796**
  — the module that flags bad code is itself an offender in all 4. Fix on principle.
- also >600 in most/all: cache, graphql, websocket, messenger, docs, api, router, seeder,
  swagger, mqtt, fakedata.

RANKING CAVEAT: LOC is the trigger-to-look; the maintainability index is the real signal
(per [[feedback_maintainability_means_less_code]]). We cannot yet rank framework source by
MI because `tina4 metrics` mis-targets it (Node bundle-scan) — Phase 0b below fixes that,
then we re-rank by MI. The reframe wording is being proven before propagation via the A/B
eval (plan/../evaluate-skills/maintainability/PLAN.md).

## Quality-ranking pass (ADR-0004 — audits rank, not just detect)
Presence-based parity ("does framework X have feature Y?") is structurally blind to "which
of the four does it BEST" — it reports "Frond: yes / Frond: yes" while one engine has an AST
and another re-derives structure from tokens. So EVERY audit of a shared subsystem must also:
1. Compare all four implementations of that subsystem side by side.
2. Name the BEST one with EVIDENCE — perf numbers (best-of-N, not a single sample),
   complexity/MI, bounded-vs-unbounded resources, compiler/feature fallback coverage, test
   depth.
3. Adopt it everywhere (Python master adopts first, per ADR-0004, even when the winner came
   from a mirror), or record why not.

Found this way already (neither visible to a presence audit):
- **PHP Frond has an AST layer; Python does not** -> Python adopts parse-to-AST (removes the
  compiler/engine token-grouping duplication; should shrink the extends/block/include/macro
  fallback set). Winner: PHP.
  **LANDED 2026-07-26, python v3 d5a9373.** New `frond/parser.py` (745 lines) owns parse +
  whitespace control + if/for/body collection; `engine.py` 2899 -> 2532, `compiler.py` 431 -> 235
  (its duplicate `_collect_if`/`_collect_for` are gone). Verified independently, not on the
  worker's word:
    - 26-construct differential corpus renders BYTE-IDENTICAL to v3.
    - Full suite re-run by me AT THE MERGE COMMIT: 3801 passed / 114 skipped (unchanged).
    - frond avg cyclomatic complexity 8.38 -> 7.08 (-15.5%); violations 33 -> 29.
    - Maintainability index essentially FLAT: 18.7 -> 18.9. Reported as-is. `engine.py` is
      STILL MI 0.0 at 1909 lines, so extracting an AST did not by itself fix the monolith --
      engine.py stays on the Phase C split list. Splitting is necessary, not sufficient.
    - Render throughput unchanged: -1.8% best-of-6 INTERLEAVED across processes. Do not trust
      a single sample here; the v3 arm's own spread was 226% and a naive first measurement
      read -12% purely from noise.
  METHOD NOTE (cost us real time, worth keeping): the first differential run showed DIFFERENT
  md5s on identical byte-length output. Cause was not the refactor -- one corpus case renders a
  `<MacroNamespace object at 0x...>` memory address, which varies per process. Normalise
  addresses before hashing any render corpus, or the gate cries wolf every run.
- **Python bounds its expression caches (`lru_cache(1024)`); PHP's are unbounded instance
  arrays** -> unbounded memory growth on dynamic expression strings. Winner: Python. The PHP
  expr-cache port must bound them, NOT copy the unbounded pattern.

## Method (per module, per language)
Characterise (suite is the net) -> measure (`tina4 metrics` + Carbonah baseline) ->
split by concern behind the SAME barrel/public API -> re-measure (MI up, CC down,
LOC/file down; energy same-or-better) -> full suite GREEN unchanged -> commit (one
split per commit) -> mirror to the other 3 to the same shape. NO behaviour change in
a split commit. Independent verification before merge (re-run suite + re-read diff).

## Sequencing / constraints
- One worker per tree (feedback_no_parallel_workers_one_tree). A Frond expr-cache
  optimisation worker is in tina4-python engine.py NOW — do not split Frond there
  until it lands + merges.
- Suggested order (biggest credibility + most-duplicated first): (1) dev-admin,
  (2) frond engine, (3) server + cli, (4) mcp, (5) orm, then the tail. Each is its
  own scoped sub-plan; owner approves scope before the fleet runs.
- Ties to / supersedes the vague #352 (code-size + perf audit).

## Status: COMMITTED to next release — planning; execution gated per module + per owner go-ahead
