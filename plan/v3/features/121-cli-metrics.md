# Feature 121: CLI code metrics

## Identity and status

- Matrix identity: 121 — CLI code metrics
- Audit state: implementation-ready; approved decisions are implemented and awaiting release integration
- Audit note: remeasured 2026-08-16 with a rebuilt native client against Python, PHP, Ruby, Node.js, and tina4-js. Every corpus completed with zero parse refusals.
- Dependencies: tree-sitter and supported grammar crates compiled into the Tina4 client. Language runtimes and extensions are not dependencies.
- Dependants: developers, CI gates, dev-admin, and tools that consume JSON.
- Decisions: ADR-0002, ADR-0054, and ADR-0055.
- Shared fixture: `fixtures/metrics_contract.json`.

## Why this feature exists

`tina4 metrics` turns source into one comparable code-health report. It needs no
running application and no framework runtime. One native engine gives every
supported language the same formulas, thresholds, JSON, and CI gate.

## Boundary

The Rust client owns source discovery, parsing, metrics, offender ranking,
duplicate detection, parse-health reporting, test-reference evidence, output,
and exit codes. Python, PHP, Ruby, and Node.js expose thin dev-admin adapters.
Those adapters run `tina4 metrics --json`; they never calculate a second answer.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node.js | tina4-js |
| --- | --- | --- | --- | --- | --- |
| Production files measured | 107 | 158 | 122 | 146 | 29 |
| Parse refusals | 0 | 0 | 0 | 0 | 0 |
| Files with reference evidence | 99 | 136 | 109 | 111 | 23 |
| Native JSON handoff test | 10 pass | 3 pass | 3 pass | 12 pass | direct native consumer |
| Legacy `has_tests` present | no | no | no | no | no |

The corpus counts describe the checked-out source on 2026-08-16. They are a
regression baseline, not fixed framework quotas.

## Public surface contract

```text
tina4 metrics [--path DIR|FILE] [--top N] [--json]
              [--fail-on warn|error] [--exclude GLOB]...
              [--include-non-production]
```

Human output is the default. `--json` emits the complete machine contract.
`--top` trims displayed offenders only; it does not change totals or exit gates.
`--fail-on` exits non-zero when a finding reaches the chosen severity.

## Inputs and outputs

- Input: one supported source file or directory, or automatic project discovery.
- Supported source: Python, PHP, Ruby, TypeScript/JavaScript, and Rust.
- Output: file metrics, function metrics, offenders, dependencies, duplicate groups,
  parse refusals, summary totals, and a severity-gated process exit code.
- Default discovery checks `src`, then `packages/*/src`, then the current directory.
- Default ignored paths include dependency, build, cache, VCS, test, and spec trees.
- Default ignored files include conventional test/spec files, `conftest.py`,
  TypeScript declarations, generated bundles, and minified assets.
- `--include-non-production` restores tests, specs, and declarations.
- Repeatable `--exclude` globs support `*`, `**`, and `?` with portable separators.

## Lifecycle and operation graph

1. Resolve the scan root and apply default and explicit exclusions.
2. Index conventional tests once. Parse their imports and retain their text for
   whole-symbol reference checks.
3. Parse each production source file and refuse unsafe parse trees.
4. Calculate LOC, cyclomatic complexity, maintainability, coupling, function
   count, and Type-2 duplicate fingerprints.
5. Match dedicated test filenames, parsed imports, and public symbols. Record
   the result as `has_referencing_test`.
6. Rank the full offender set, emit human or JSON output, then apply the gate.

## Metric rules

- Function CC above 10 warns and above 20 errors.
- File LOC above 500 and function count above 20 warn.
- MI below 40 warns only when average CC is at least 5; MI below 20 errors.
- Each nested callable owns its own decisions in all supported languages.
- Type-2 fingerprints ignore comments and normalize consistent identifier and
  same-kind literal renaming. Python docstrings remain significant syntax.
- Type-3 and Type-4 semantic clones are outside this feature.
- A file below 95% clean parsing or above 800 AST levels is refused and excluded
  from aggregates. The refusal stays visible and may fail a warning gate.

## Test-reference contract

`has_referencing_test` reports evidence. It does not report execution or coverage.
Evidence may come from a dedicated test filename, a parsed static or dynamic
import, a require/use statement, or a whole public symbol referenced in a test.
A Ruby namespace wrapper is not a public subject by itself.

No evidence produces `no_test_reference` at `info`. The finding cannot fail a
`warn` or `error` gate. The old `has_tests` field and `untested` kind are removed.

## Configuration and precedence

The command uses arguments only. `--path`, `--top`, `--json`, `--fail-on`, each
`--exclude`, and `--include-non-production` have no environment aliases.
Explicit exclusions add to the defaults. The include flag disables only the
default non-production exclusions; explicit globs still win.

## Failures, side effects and security

- The engine reads source and creates no project state.
- Unsupported extensions are ignored.
- Missing paths return a clear error response.
- Parse refusals stay visible instead of receiving misleading partial scores.
- JSON never upgrades reference evidence into a coverage claim.

## Wire and persistence contract

JSON is the machine contract. Per-file records contain
`has_referencing_test`; `has_tests` is absent. The report includes `unparsed`
records and `files_refused`. No result is persisted.

Framework adapters must reject a missing or stale native binary with a clear
503. They may reshape the payload for the dashboard, but they may not recompute
metrics or restore legacy fields.

## Providers and substitutability

Each language provider consists of a reliable tree-sitter grammar plus mappings
for files, declarations, imports, callables, decisions, and nested scopes. Every
provider uses the shared formulas, thresholds, clone rules, JSON, and refusals.

Delphi remains unsupported. The available grammar does not parse the Tina4
Delphi corpus well enough to produce honest numbers.

## Contradictions and defects

| ID | Resolution |
| --- | --- |
| METRICS-SCAN-SCOPE | Added repeatable `--exclude`, production defaults, and an explicit include override. |
| METRICS-TEST-FALSE-NEGATIVE | Tests now use parsed multiline/dynamic imports plus public symbols. |
| METRICS-TEST-FALSE-POSITIVE | Ruby namespace wrappers no longer count; JSON now says `has_referencing_test`. |
| METRICS-SCOPE-PARITY | Nested callables own decisions in all five supported languages. |
| METRICS-DRY-TYPE2 | Comments no longer alter Type-2 fingerprints; executable docstrings remain significant. |
| METRICS-PARITY-GHOST | The retired Python adapter no longer acts as a false oracle; a static native calibration locks the accepted formula. |

## Owner decisions

ADR-0055 records every owner choice from the audit: production-only defaults,
repeatable exclusions, the explicit include override, failure of stale JSON
consumers, equal nested-callable scopes, comment-insensitive Type-2 matching,
and evidence-only test language. No owner ambiguity remains.

## Proposed conformance fixture

The proposal is now the accepted `metrics_contract.json` fixture. Its six
invariants bind production scan scope, honest JSON, parsed references, callable
scope, Type-2 comment handling, and formula calibration to named native tests.

### Conformance proof

- Native metrics suite: 84 passing focused tests.
- Full native client suite: 317 passing checks; five environment-dependent tests ignored.
- Production corpus: five language trees, zero refused files, zero legacy fields.
- Framework handoffs: Python 10, PHP 3, Ruby 3, and Node.js 12 passing.
- Node.js typecheck: passing.
- Linux lab root gate: native 84, Python 10, PHP 3, Ruby 3, Node.js 12,
  contract ledger 288/288; five production corpora completed with zero refusals.
- Warm tina4-js benchmark: released `v3.8.75` 0.10s; corrected engine 0.15–0.16s.
- Python corpus benchmark: released engine 1.71s; corrected engine 2.04s.

The engine parses each test once per language and reuses the index. This removed
the first implementation's per-source reparsing regression.

## Integration map

- Formula and implementation owner: `tina4/src/metrics.rs`.
- Dispatch and flags: `tina4/src/main.rs`.
- Thin consumers: Python `dev_admin/metrics.py`, PHP `Metrics.php`, Ruby
  `metrics.rb`, and Node.js `metrics.ts`.
- Browser consumer: tina4-dev-admin `Metrics.ts` and the synced framework asset.
- Contract: `fixtures/metrics_contract.json`, checked by
  `scripts/audit-contract-fixtures.py`.

## Breaking changes and migration

- Replace every `has_tests` read with `has_referencing_test`.
- Replace any `untested` offender handling with `no_test_reference`.
- Rebaseline historical file, function, duplicate, and offender counts.
- Add `--include-non-production` only when test and declaration metrics are wanted.
- Use repeatable `--exclude` flags for galleries, generated project areas, or
  other repository-specific non-production source.

These breaks are intentional before 3.14.0. No temporary JSON alias is required.

## Implementation backlog

No engine or adapter work remains for the approved audit decisions. Release
integration must preserve the green focused handoffs and contract checker.
Delphi support remains a separate language-provider task until a grammar
passes representative corpus fixtures.

## Porting capsule

To add another language:

1. Add a reliable grammar and source extensions to the native client.
2. Map imports, declarations, callables, decisions, comments, and nested scopes.
3. Prove healthy and broken parse fixtures, including the refusal threshold.
4. Port the shared nested-callable, Type-2, import, symbol, and negative controls.
5. Run a representative production corpus with zero silent omissions.
6. Confirm the existing formulas, thresholds, JSON keys, exclusions, and gates
   remain unchanged.
7. Add the language to the released-binary corpus evaluation.

Never copy the engine into the framework runtime. Another language extends the
one engine; it does not create another answer.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure, side-effect, and security rules complete.
- [x] Wire and provider contracts complete.
- [x] Owner decisions recorded in ADR-0055.
- [x] Shared fixture and mutation witnesses complete.
- [x] Existing-language contradictions resolved.
- [x] Breaking migration recorded.
- [x] Porting capsule is clean-room sufficient.
