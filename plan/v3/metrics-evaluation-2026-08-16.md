# Tina4 Metrics Evaluation

**Outcome:** The released engine exposed four correctness gaps. ADR-0055 resolves
them in the rebuilt engine: production-source controls, an honest test-reference
signal, equal callable scopes, and comment-insensitive Type-2 matching. The
3.13.104 post-release scan now records the framework worklist produced by the
corrected 3.8.76 client.

## Scope

- [x] Sweep current Tina4 organization issues for metrics-adjacent defects.
- [x] Read the native engine's thresholds, exclusions, parse-health rules, and test-detection behavior.
- [x] Run the published Tina4 `v3.8.75` client against Python, PHP, Ruby, Node.js, and tina4-js source.
- [x] Exclude dev-admin, galleries, generated assets, declarations, and test sources from the core comparison.
- [x] Rank error/warn offenders separately from informational missing-test signals.
- [x] Reproduce false positives, blind spots, and cross-language scope differences.
- [x] Produce a remediation order without changing framework code.
- [x] Rebaseline all four released 3.13.104 backends on the Linux lab with Tina4 client 3.8.76.
- [x] Record finding counts, affected files, scan roots, exclusions, and leading offenders.

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

All four findings above describe the published `v3.8.75` baseline. The corrected
engine closes them and retains this section as the before-state evidence.

## Implemented remediation

1. Added repeatable `--exclude GLOB`, safe production defaults, and
   `--include-non-production`.
2. Renamed `has_tests` to `has_referencing_test`; parsed imports, dynamic imports,
   and public symbols now supply evidence.
3. Assigned nested Python, PHP, Ruby, TypeScript/JavaScript, and Rust callables
   their own decision scopes.
4. Made Type-2 fingerprints ignore comments while retaining executable Python
   docstrings.
5. Added `metrics_contract.json`, 84 focused native checks, real framework
   handoff tests, and five production-corpus scans with zero refusals.

## Corrected-engine dashboard

| Check | Python | PHP | Ruby | Node.js | tina4-js |
| --- | ---: | ---: | ---: | ---: | ---: |
| Production files measured | 107 | 158 | 122 | 146 | 29 |
| Reference evidence | 99 | 136 | 109 | 111 | 23 |
| Parse refusals | 0 | 0 | 0 | 0 | 0 |
| Legacy `has_tests` field | 0 | 0 | 0 | 0 | 0 |

The framework adapters pass against the rebuilt binary: Python 10 tests, PHP 3,
Ruby 3, and Node.js 12. Node.js also passes its typecheck.

Warm tina4-js scans move from 0.10s on the released binary to 0.15–0.16s on the
corrected engine. The Python corpus moves from 1.71s to 2.04s. The added work
parses conventional tests once and reuses their import index; it does not repeat
that parse for every production file.

## 3.13.104 post-release baseline

The Linux lab scan ran as root on 2026-08-17 with the signed Tina4 client
3.8.76. It measured the released 3.13.104 source copied under
`/home/andre/release-3.13.104/`.

Each scan targeted the framework source root: `tina4_python`, `Tina4`, `lib`, or
`packages`. The client's production defaults excluded tests, specs, declaration
files, generated bundles, minified assets, dependencies, caches, and build
output. Explicit globs excluded Python `dev_admin`, PHP `DevAdmin.php` and its
security middleware, Ruby `dev_admin.rb`, Node.js `devAdmin.ts`, and synced
dev-admin browser assets. Node.js galleries stayed in the scan because they ship
inside the production package tree.

| Framework | Files measured | Functions | Avg CC | Avg MI | Error | Warn | Info | Findings | Files with findings |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Python | 105 | 2,623 | 3.77 | 26.9 | 49 | 262 | 8 | 319 | 73 |
| PHP | 160 | 2,915 | 3.71 | 34.6 | 51 | 345 | 20 | 416 | 105 |
| Ruby | 125 | 4,098 | 2.73 | 29.9 | 24 | 216 | 14 | 254 | 90 |
| Node.js | 147 | 3,389 | 3.34 | 31.1 | 41 | 324 | 35 | 400 | 119 |
| **Total** | **537** | **13,025** | - | - | **165** | **1,147** | **77** | **1,389** | **387** |

The worklist contains 1,312 warning or error findings. A finding is not a file:
one file can raise several signals. The 77 informational findings are
`no_test_reference` evidence gaps. They do not claim missing execution or
coverage, and they do not fail a warning or error gate. Every scan completed
with zero refused files.

### Findings by rule

| Rule | Python | PHP | Ruby | Node.js | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Function complexity | 166 | 190 | 112 | 189 | 657 |
| Duplication | 61 | 114 | 38 | 90 | 303 |
| Too many functions | 45 | 49 | 68 | 51 | 213 |
| Large file | 27 | 24 | 19 | 22 | 92 |
| Low maintainability | 12 | 19 | 3 | 13 | 47 |
| No test reference | 8 | 20 | 14 | 35 | 77 |

Complexity supplies 657 of the 1,389 findings. Duplication comes next with 303.
These two rules own 69% of the worklist, so the remediation pass should start
there instead of splitting files to satisfy line counts alone.

### Highest-ranked released findings

| Framework | First priority | Next priority |
| --- | --- | --- |
| Python | `session_handlers/redis_handler.py`: 210 duplicated lines across two files | `swagger/__init__.py`: `Swagger.generate` CC 64 |
| PHP | `Session/RedisSessionHandler.php`: 287 duplicated lines across two files | `AITools.php`: 50 duplicated lines within the file |
| Ruby | `tina4/webserver.rb`: 79 duplicated lines within the file | `tina4/frond.rb`: 22 duplicated lines across three copies |
| Node.js | `core/src/sessionHandlers/mongoClient.ts`: 229 duplicated lines across two files | `core/gallery/auth/src/routes/gallery/auth/get.ts`: 98 duplicated lines across two files |

The ranking is a work order, not permission to delete repeated code without
reading it. Shared protocol and adapter shapes may need duplication to stay
clear. Each change still needs characterisation tests, a before/after metric,
and the full framework suite.

### Reproduction commands

Use the matching source root and repeat the framework's dev-admin exclusions:

```bash
tina4 metrics --path tina4_python --exclude '**/dev_admin/**' --json --top 100000
tina4 metrics --path Tina4 --exclude '**/DevAdmin.php' --exclude '**/DevAdminSecurityMiddleware.php' --json --top 100000
tina4 metrics --path lib --exclude '**/dev_admin.rb' --json --top 100000
tina4 metrics --path packages --exclude '**/devAdmin.ts' --json --top 100000
```

Add the synced `tina4-dev-admin.min.js` exclusion when the source root contains
that asset. The default production filter already ignores minified files, but
the explicit exclusion makes the audit boundary visible.

## Commits

- `fffb85c` - re-audit the native metrics feature, correct stale claims, and record the measured framework evaluation.
- `67ff8be` - record the released 3.13.104 metrics baseline and publish the current CLI contract.

## Status: Evaluation complete; corrected engine and 3.13.104 baseline verified on the Linux lab as root
