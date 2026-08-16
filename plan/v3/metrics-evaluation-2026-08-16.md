# Tina4 Metrics Evaluation

**Outcome:** Establish whether the released native `tina4 metrics` engine produces a fair, actionable, cross-language worklist for the Tina4 framework family, with dev-admin excluded and test presence reported honestly.

## Scope

- [x] Sweep current Tina4 organization issues for metrics-adjacent defects.
- [x] Read the native engine's thresholds, exclusions, parse-health rules, and test-detection behavior.
- [x] Run the published Tina4 `v3.8.75` client against Python, PHP, Ruby, Node.js, and tina4-js source.
- [x] Exclude dev-admin, galleries, generated assets, declarations, and test sources from the core comparison.
- [x] Rank error/warn offenders separately from informational missing-test signals.
- [x] Reproduce false positives, blind spots, and cross-language scope differences.
- [x] Produce a remediation order without changing framework code.

## Parity dashboard

| Evaluation | Python | PHP | Ruby | Node.js | tina4-js |
| --- | --- | --- | --- | --- | --- |
| Released engine scan | ✅ | ✅ | ✅ | ✅ | ✅ |
| Core-only comparison | ✅ | ✅ | ✅ | ✅ | ✅ |
| Test-reference signal checked | ⚠️ false negatives | ⚠️ false negatives | ⚠️ false positive | ⚠️ checked | ⚠️ false negatives |
| Offenders reviewed | ✅ | ✅ | ✅ | ✅ | ✅ |
| Parse refusals | 0 | 0 | 0 | 0 | 0 |

## Core-only results

These figures exclude dev-admin and known non-core sources. `Test ref.` is the engine's lexical reference signal, not execution or coverage, and is demonstrably unreliable.

| Framework | Files | Functions | Avg CC | Avg MI | Error | Warn | Info | Test ref. yes/no |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Python | 95 | 2,412 | 3.91 | 24.9 | 51 | 256 | 1 | 94 / 1 |
| PHP | 151 | 2,556 | 4.01 | 33.6 | 57 | 334 | 16 | 135 / 16 |
| Ruby | 113 | 2,543 | 3.66 | 28.2 | 37 | 209 | 0 | 113 / 0 |
| Node.js | 125 | 3,201 | 3.37 | 27.3 | 42 | 306 | 19 | 106 / 19 |
| tina4-js | 29 | 275 | 2.69 | 47.9 | 1 | 19 | 10 | 19 / 10 |

Ruby's 113/0 result is a false positive caused by the shared `module Tina4` namespace. The missing-test totals in other languages include proven false negatives, so none of these ratios should be used as coverage.

## Highest-density core offenders

The rank is the count of distinct error/warning signals per file, not a claim that all findings require refactoring.

| Framework | Highest-density files, in order |
| --- | --- |
| Python | `frond/engine.py`; `core/server.py`; `orm/model.py`; `seeder/__init__.py`; `frond/parser.py` |
| PHP | `Frond.php`; `ORM.php`; `Docs.php`; `Swagger.php`; `Server.php` |
| Ruby | `frond.rb`; `orm.rb`; `template.rb`; `database.rb`; `docs.rb` |
| Node.js | `packages/frond/src/engine.ts`; `packages/core/src/docs.ts`; `packages/orm/src/baseModel.ts`; `packages/core/src/projectIndex.ts`; `packages/cli/src/commands/generate.ts` |
| tina4-js | `storage/persist.ts`; `sse/sse.ts`; `core/html.ts`; `rtc/rtc.ts`; `i18n/i18n.ts` |

## Engine self-check

The Tina4 client itself reports 19 Rust files, 796 functions, average CC 4.67, average MI 12.1, and 180 offenders: 34 errors, 140 warnings, and 6 informational findings. Its highest-density files are `agent.rs`, `doctor.rs`, `init.rs`, `main.rs`, `setup.rs`, and `metrics.rs`. This is a separate native-client worklist, not framework parity data.

## Verification

- [x] Published `v3.8.75` binary reports its expected version and emits valid JSON.
- [x] A source file with a real referencing test reports `has_tests: true`.
- [x] The same source without a test reports `has_tests: false` plus informational `untested`.
- [x] Every framework scan completed with zero refused files.
- [x] `--top 1` changes presentation only; full totals and file metrics remain intact.
- [x] An untested-only fixture exits zero under `--fail-on warn`.
- [x] A real error exits non-zero under `--fail-on error`.
- [x] A Ruby shared namespace produces a false positive.
- [x] A TypeScript multiline import produces a false negative.
- [x] Equivalent nested callables produce different PHP/Ruby and TypeScript function boundaries.

## Confirmed engine defects

1. No `--exclude` option means core-only comparisons require external filtering.
2. Test presence is only a lexical reference heuristic and is wrong in both directions.
3. Nested callable scope differs by language: TypeScript arrows are separate functions, while PHP anonymous functions and Ruby blocks/lambdas contribute decisions to the parent.
4. Comment-sensitive duplicate hashes detect less than users may expect from Type-2 duplication.

## Recommended remediation order

1. Add repeatable `--exclude GLOB` and safe production-source defaults.
2. Rename `has_tests` to `has_referencing_test` and use parsed imports, dynamic imports, and exported symbols.
3. Measure nested PHP and Ruby callables separately to align with TypeScript and the conceptual function boundary.
4. Decide whether Type-2 duplication should ignore comments.
5. Lock all framework corpora and focused cross-language fixtures into the native metrics test suite.

## Commits

- `fffb85c` - re-audit the native metrics feature, correct stale claims, and record the measured framework evaluation.

## Status: Evaluation complete; owner decisions pending
