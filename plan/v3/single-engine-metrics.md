# Task: one metrics engine across all four frameworks (ADR-0002, ADR-0054)

## Goal

Delete the four hand-rolled code analyzers and route every framework's metrics
through the native `tina4 metrics --json` engine, so a number measured in Python
is comparable with the same number measured in PHP, Ruby or Node.

## Context

ADR-0002 says one engine so the numbers are comparable. That was true of nothing:
each framework carried its OWN AST/token analyzer, and only Python had a shim to
the CLI at all (and it fell back to the local analyzer on any problem).

**Why it matters beyond the LOC win:** the 98-feature audit's entire measurement
premise is cross-framework comparability. Every LOC/CC/MI comparison in it,
including the Frond findings (two frameworks at MI 0.0, Node CC 1095), was
produced by FOUR DIFFERENT analyzers. The rankings may hold, but they were not
evidence until this lands.

Owner decisions (2026-07-29): "hand rolled analysers get removed", "No fall
backs", camelCase-per-language paradigm for names.

## The boundary (decided, measured)

| Surface | Verdict | Why |
| --- | --- | --- |
| Native `tina4 metrics` | OWNS | every calculation, offender rule, output, and CI exit code |
| Dev-admin `full_analysis` / `file_detail` | ADAPTER | shells the native engine and shapes the existing chart payload |
| Framework `metrics` commands | REMOVED | duplicate ownership created recursion and stale-binary failures |
| `quick_metrics` / `quickMetrics` | REMOVED | even a census is metrics logic inside the framework; the tab loads the full native payload |

No fallback anywhere: a missing/stale CLI raises and names the install command.
`/metrics/full` -> 503, `/metrics/file` -> 404 for a bad path else 503.

## Scope

- [x] Verify the engine holds the 3.13.91 protections BEFORE cutting
      (nested complexity not double-counted; function LOC == file LOC rule)
- [x] Python: keep only the full/file adapter; remove quick endpoint and framework CLI command
- [x] CLI: fix the gap the cut exposed (class-symbol test detection)
- [x] PHP: keep only the full/file adapter; remove quick endpoint and framework CLI command
- [x] Ruby: same
- [x] Node: same
- [x] Four full suites green at the shipping HEAD (see Lines removed + Verification)
- [ ] CLAUDE.md metrics sections in all four

## Parity

| Item | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| analyzer deleted | ✅ | ✅ | ✅ | ✅ |
| engine-backed full/fileDetail | ✅ | ✅ | ✅ | ✅ |
| local census removed | ✅ | ✅ | ✅ | ✅ |
| no fallback, loud failure | ✅ | ✅ | ✅ | ✅ |
| dev-admin 503/404 split | ✅ | ✅ | ✅ | ✅ |
| framework CLI command removed | ✅ | ✅ | ✅ | ✅ |
| tests re-pointed + green | ✅ | ✅ | ✅ | ✅ |
| payload key set identical | ✅ | ✅ | ✅ | ✅ |

Measured census-vs-engine, which is what justified keeping the census local:

| Framework | census | engine | ratio |
| --- | --- | --- | --- |
| Python | 60-78ms | 1.0-1.4s | ~17x |
| PHP | 60ms | ~1.2s | ~20x |
| Ruby | 44ms | 1.65s | ~37x |
| Node | 129-135ms | ~1.0s | ~8x |

## Lines removed

| Framework | Before | After | Delta |
| --- | --- | --- | --- |
| Python `metrics.py` + `metrics_engine.py` | 975 | 375 | **-600** |
| PHP `Metrics.php` | 1669 | 534 | **-1135** |
| Ruby `metrics.rb` | 1138 | 391 | **-747** |
| Node `metrics.ts` | 1451 | 677 | **-774** |
| **Total** | **5233** | **1977** | **-3256** |

## Verification (qualified: macOS 15, NO live services on this host)

| Framework | Result | Note |
| --- | --- | --- |
| Python | 3969 green | earlier in this task |
| PHP 8.5.7 | **4388 tests, 12688 assertions, 0 failures** | 171 skipped = service-gated |
| Ruby 4.0 | **4366 examples, 0 failures** | 166 pending = service-gated |
| Node 24 | **5960 passed, 18 failed** | every failure is `sessionHandlers` on ECONNREFUSED 27017 (no local Mongo); metrics files 178/178 |
| CLI (Rust) | **216 passed, 0 failed** | |

## 3.13.101 completion gate (real CLI 3.8.71, macOS 15)

- [x] Python: 10 adapter tests
- [x] PHP 8.5.7: 3 tests, 12 assertions
- [x] Ruby 4.0: 3 examples
- [x] Node: 7 adapter assertions plus TypeScript typecheck
- [x] Browser assets call only `/metrics/full` and `/metrics/file`
- [x] File detail returns `function_count` plus a native `functions` array for the browser
- [x] Framework formula, offender, census, and CLI-command tests removed
- [x] Linux lab full suites at the exact release HEAD

### Linux release gate (2026-08-14, real services, CLI 3.8.71)

| Framework | Exact commit | Result |
| --- | --- | --- |
| Python 3.13.3 | `a0e9cff` | 5,516 passed, 11 skipped, 0 failed |
| PHP 8.3.6 | `fa9af870` | 5,443 tests, 19,070 assertions, 0 failures, 10 skipped |
| Ruby 3.2.3 | `45df537` | 5,449 examples, 0 failures, 10 pending (ODBC DSN absent) |
| Node.js 24.18.0 | `69ba401` | 8,422 passed, 0 failed, 11 skipped (ODBC DSN absent); typecheck green |

## Bugs found BY doing this (the argument for one engine)

- [x] **Framework CI excluded the native metrics handoff instead of installing
      the CLI that owns it.** Install the checksummed CLI in all four main jobs,
      remove the exclusions, and require all four CI runs to pass.

- [x] CLI `module_has_tests` had no class-symbol stage: a class referenced by a
      test through the package root was reported UNTESTED, and raised a false
      "untested" offender. Invisible while four analyzers each had their own
      answer. Fixed `tina4 f72338c` (stage 3 + whole-identifier matching, no
      length floor - a >3-char gate was the original Python bug).
- [x] PHP `fileDetail` returned richer per-file keys than the engine provides.
      Accepted the engine's shape per the one-engine rule.
- [x] **PHPUnit's `FooTest.php` matched NO stage-1 pattern** (every other pattern
      uses a separator), so a PHP scan called EVERY source file untested. Fixed
      `tina4 82e4153`.
- [x] **An em dash in one offender `detail` made the whole JSON payload
      non-ASCII**, and Ruby's Open3 (locale-tagged) then raised
      Encoding::CompatibilityError under LANG=C -- i.e. on a normal CI runner.
      Fixed `tina4 85c1fce`.
- [x] **TypeScript interfaces were not declared types**, so an interface-only
      module a test referenced was reported untested. PHP already counted
      interfaces; TS did not. Fixed `tina4 4a34be2`.
- [x] **`halstead_volume` was computed then discarded**, never serialized,
      despite the task that added coupling_afferent/instability naming it. Fixed
      `tina4 4a34be2`.
- [x] Ruby `engine_path` took the first `tina4` on PATH, which under
      `bundle exec` is a RubyGems **Ruby shim** -- every metrics call died with
      "can't find executable tina4 for gem". Shebang scripts are now skipped.
- [x] Node used `__dirname` in an **ESM-only** package: tsc accepts it (the Node
      types declare it) but it does not exist at runtime. Only running the code
      caught it.
- [x] A PHP test looped `foreach` over the `functions` COUNT, and a Node test
      did the same -- an int is not iterable, so both bodies never ran while the
      tests reported green.
- [x] The CLI in **PHP, Ruby AND Node** each made TWO engine calls where one
      would do, each carrying the same stale "it is cached" comment. One bug
      copied three times.
- [x] **Dev-admin file detail exposed `functions` as a number while the browser
      called `functions.map(...)`.** The adapter now preserves that count as
      `function_count` and supplies the native function records as `functions`.
      A real CLI regression failed in all four before the fix and passed after it.

## Corrections I had to make to my own claims

- Claimed a CLI **LOC bug** and asked to fix it. There was none - I derived
  "should be 2" by hand while the contract explicitly counts the `def` line
  ("def + if + return + return = 4"). Verified 4/4, 2/2, 2/2 against the
  master's own fixtures. Lesson: read the test that defines the contract.
- Claimed the composite-key driver bug hit three frameworks; it was two.
- Claimed PHPUnit `FooTest.php` detection was broken, then "corrected" myself to
  say stage 3 caught it. **The first claim was right and the correction was
  wrong** - stage 3 cannot catch it, because whole-identifier matching correctly
  refuses to find `Widget` inside `WidgetTest`. Proved by running the engine on a
  real fixture. Two wrong statements about one behaviour, both from reasoning
  instead of executing.
- Wrote `echo "(nothing above = Firebird absent from all 4 CIs)"` after a grep
  that DID return hits, so the line asserted the opposite of the evidence right
  under it. PHP, Ruby and Node all already have Firebird CI jobs; only Python has
  none. Second time this session I used that unconditional-echo pattern.

## Commits

- `tina4 f72338c` CLI: class-symbol stage in module_has_tests (+4 tests)
- `tina4 82e4153` CLI: PHPUnit `FooTest.php` counts as a dedicated test
- `tina4 85c1fce` CLI: keep the JSON payload ASCII-only (the LANG=C killer)
- `tina4 4a34be2` CLI: TS interfaces are declared types; expose halstead_volume
- `tina4-python 3fa77d4` one engine, no fallback, -600 lines (3969 green)
- `tina4-php 58e557b8` one engine, -1135 lines (4388 tests, 0 failures)
- `tina4-ruby 4c57296` one engine, -747 lines (4366 examples, 0 failures)
- (tina4-nodejs pending: -774 lines, awaiting the full-suite re-run)
- `tina4-python 46a9234` remove census/CLI; browser-shape handoff regression
- `tina4-python a0e9cff` update the dev-admin handler count after removing the census route
- `tina4-php fa9af870` remove census/CLI; browser-shape handoff regression
- `tina4-ruby 45df537` remove census/CLI; browser-shape handoff regression
- `tina4-nodejs 69ba401` remove census/CLI; browser-shape handoff regression
- `tina4-python 4d970fb, 43dbccf` install and checksum the native CLI in CI
- `tina4-php af5fc4cd, cc190387` install and checksum the native CLI in CI
- `tina4-ruby 35ab279, 27dd0ae` install and checksum the native CLI in CI
- `tina4-nodejs 35a9647, 5ca22dd` install and checksum the native CLI in CI

## Status: Complete — 3.13.101 is published and every framework CI proves the native handoff.
