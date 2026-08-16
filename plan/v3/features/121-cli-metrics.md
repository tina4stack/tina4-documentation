# Feature 121: CLI code metrics

## Identity and status

- Matrix identity: 121 — CLI code metrics
- Audit state: auditing
- Audit note: remeasured 2026-08-16 with the published Tina4 `v3.8.75` binary against the active Python, PHP, Ruby, Node.js, and tina4-js source trees. Focused fixtures and the native Rust source were also inspected. Framework metrics modules are thin dev-admin adapters; they do not calculate metrics.
- Dependencies: tree-sitter and the supported language grammar crates in the Tina4 client binary. Language runtimes and extensions are not dependencies.
- Dependants: developers, CI gates using `--fail-on`, and the framework dev-admin adapters.
- Existing ADRs: ADR-0002 (native engine), ADR-0054 (framework adapter boundary).
- Shared fixtures: native Rust metric fixtures plus released-binary framework corpus evaluation.

## Why this feature exists

`tina4 metrics` finds code-health risks without starting an application. One native engine gives every supported language the same command, thresholds, JSON contract, and CI gate.

## Boundary

This packet owns source discovery, parsing, metrics, offender ranking, duplicate detection, parse-health reporting, test-reference detection, and CLI flags. The engine is implemented once in `tina4/src/metrics.rs`.

Framework dev-admin modules only run the native client in JSON mode and adapt its response for the existing chart. Framework CLIs do not own another metrics implementation.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | Native `tina4 metrics`; thin dev-admin JSON adapter | Native `tina4 metrics`; thin dev-admin JSON adapter | Native `tina4 metrics`; thin dev-admin JSON adapter | Native `tina4 metrics`; thin dev-admin JSON adapter |
| Startup/CLI integration | Rust client scans source directly | Rust client scans source directly | Rust client scans source directly | Rust client scans `packages/*/src` directly |
| Stored/wire format | Shared JSON response | Shared JSON response | Shared JSON response | Shared JSON response |
| Existing focused tests | Native formula and parser fixtures | Native formula and parser fixtures | Native formula and parser fixtures | Native formula and parser fixtures |
| Existing lab baseline | 95 core files; 0 refused | 151 core files; 0 refused | 113 core files; 0 refused | 125 core files; 0 refused |

tina4-js uses the same TypeScript/JavaScript parser and JSON contract; its baseline is 29 core files with zero refusals.

- Dispatch: `main.rs` `Commands::Metrics { path, fail_on, json, top }` calls `metrics.rs`.
- Supported source: Python, PHP, Ruby, TypeScript/JavaScript, and Rust through tree-sitter.
- Metrics: LOC, cyclomatic complexity (CC), maintainability index (MI), coupling, and function count.
- Thresholds: function CC above 10 is a warning and above 20 is an error; file LOC above 500 and function count above 20 are warnings; MI below 40 warns only when average CC is at least 5, and MI below 20 errors.
- DRY detection: AST-shape Type-1 clones plus consistent identifier and same-kind literal renaming. Comments affect the hash; Type-3 and Type-4 clones are not detected.
- Parse health: files below 95% clean parsing or above 800 AST nesting levels are refused, reported in JSON, and excluded from averages.
- `--top` limits displayed offenders only. Summary totals, file metrics, and exit gating still use the complete result.
- Test presence is a lexical reference heuristic over `tests`, `test`, and `spec`; it is not test execution or coverage.
- No Pascal/Delphi grammar is claimed because the available grammar does not parse the corpus reliably.

## Public surface contract

`tina4 metrics [--top N] [--json] [--fail-on warn|error] [--path DIR|FILE]`

Human-readable output is the default. JSON includes file metrics, offenders, parse refusals, and summary totals. `--fail-on` returns a non-zero exit when an offender at the selected severity exists. An `untested` signal is informational and does not fail `warn` or `error` gates.

## Inputs and outputs

- Input: one source file or directory, or automatic project source discovery when `--path` is omitted.
- Output: ranked offenders or JSON plus a severity-gated process exit code.
- Default discovery checks `src`, then `packages/*/src`, then the current directory.
- Default ignored directories include `node_modules`, `vendor`, `.git`, `target`, `dist`, `build`, `__pycache__`, and virtual environments.
- Generated minified and bundle assets are ignored. Declaration files, test files, galleries, and dev-admin source are not generally excluded.

## Lifecycle and operation graph

1. Discover source and skip known dependency, build, cache, and minified-asset paths.
2. Parse each supported file and refuse files that fail the parse-health rule.
3. Calculate file and function metrics and AST-shape duplicate fingerprints.
4. Search conventional test directories for lexical references to each source file.
5. Rank all offenders, truncate presentation only when `--top` is supplied, emit human or JSON output, and apply the exit gate.

## Configuration and precedence

The public controls are `--top`, `--json`, `--fail-on`, and `--path`. There is no environment configuration and no repeatable exclusion flag.

## Failures, side effects and security

- The engine is read-only over source and creates no project state.
- Parse failures are surfaced instead of silently producing misleading numbers.
- A refused file is a warning and can fail a warning-level CI gate.
- The test-reference heuristic produces both false positives and false negatives; it must not be presented as coverage.

## Wire and persistence contract

JSON is the machine contract. It contains per-file metrics, offender details, `has_tests`, `unparsed`, and `files_refused`. No state is persisted. `has_tests` currently means that a conventional test file appears to reference the source, not that a test executed or covered it.

## Providers and substitutability

Each supported language is provided by a tree-sitter grammar plus the engine's node mapping. Adding another language requires a reliable grammar, callable/decision mappings, representative fixtures, parse-health checks, and comparison against the existing thresholds and output contract.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| METRICS-SCAN-SCOPE | There is no `--exclude`. Dev-admin, galleries, declarations, and test sources can contaminate a project score. The audit required post-processing to compare core framework source fairly. | Add a repeatable `--exclude GLOB`; exclude declarations and conventional test/spec files from production scoring by default, while allowing an explicit override. |
| METRICS-TEST-FALSE-NEGATIVE | Real tests can be missed. Examples include tina4-js multiline and dynamic imports and PHP tests whose generic filename references exported classes rather than the module stem. | Parse imports/requires and exported symbols instead of relying on line and filename substrings. Include dynamic imports. |
| METRICS-TEST-FALSE-POSITIVE | Ruby files that only share `module Tina4` are all reported as tested when one unrelated test references `Tina4`. | Ignore namespace wrappers as evidence and rename the field to `has_referencing_test` so the contract remains honest. |
| METRICS-SCOPE-PARITY | TypeScript arrow functions are separate callable scopes, while PHP anonymous functions and Ruby blocks/lambdas roll their decisions into the parent. Equivalent code therefore receives different function counts and offender thresholds. | Define one nested-callable rule and implement it consistently. Measuring PHP and Ruby closures separately best matches TypeScript and developer expectations. |
| METRICS-DRY-TYPE2 | Comments affect duplicate hashes, so otherwise identical code separated only by comments is not detected. Type-3/4 duplication is also outside the stated capability. | Keep the limitation explicit; decide whether Type-2 should become comment-insensitive. |
| METRICS-NO-DELPHI | Delphi is not measured because the available grammar is not sufficiently reliable. | Keep the language unsupported until a grammar passes representative corpus fixtures. |

The earlier audit's claimed DRY fingerprint collision and language-specific PHP offender-cap defect were not reproduced and do not match the single native-engine architecture. They are removed from the backlog unless a concrete fixture is supplied.

## Owner decisions

1. Add repeatable exclusions and safe production-source defaults.
2. Rename the heuristic result to `has_referencing_test` and repair its parser-based detection.
3. Measure nested PHP and Ruby callables separately to align scope across languages.
4. Decide whether comments should be ignored for Type-2 duplicate matching.

## Proposed conformance fixture

- Scan-scope fixtures prove repeatable exclusions and the default treatment of declaration and test files.
- Positive and negative test-reference fixtures cover single-line, multiline, aliased, and dynamic imports plus generic test filenames.
- A shared Ruby namespace without a source reference must remain untested.
- Equivalent nested-callable fixtures in Python, PHP, Ruby, TypeScript, JavaScript, and Rust must produce the same callable boundaries and decision allocation.
- `--top 1` must retain complete totals and gating.
- An informational missing-test result must not fail `--fail-on warn`; a real error must fail `--fail-on error`.
- Every framework corpus must complete with zero silent parse omissions.

## Integration map

- Formula and implementation owner: `tina4/src/metrics.rs`.
- Dispatch: `tina4/src/main.rs`.
- Thin consumers only: Python `dev_admin/metrics.py`, PHP `Metrics.php`, Ruby `metrics.rb`, and Node.js `metrics.ts`.
- Other consumers: CI through exit codes and tooling through JSON.

## Breaking changes and migration

- Renaming `has_tests` is a JSON breaking change, acceptable before the 3.14.0 stable contract. A temporary alias may be emitted only if external consumers require migration time.
- Correct nested-callable scopes and exclusions will change historical totals and offender ranks. Release notes must identify this as an accuracy correction.
- The dev-admin adapters must pass exclusions through and accept the corrected JSON field without recreating metric logic.

## Implementation backlog

1. Add `--exclude` and production-source defaults.
2. Correct and rename the test-reference signal.
3. Normalize nested-callable scope across languages.
4. Decide and, if approved, implement comment-insensitive Type-2 matching.
5. Lock the released framework corpus and focused fixtures into parity tests.

## Porting capsule

Keep metrics as one native engine rather than porting calculations into each framework. To add another language: add and validate its grammar; map files, imports, declarations, callables, decisions, and nested callable boundaries; apply the shared thresholds and JSON schema; prove parse health on a representative corpus; run positive/negative test-reference and duplicate fixtures; compare equivalent callable fixtures across every supported language; and add it to the released-binary framework evaluation. Never claim support when the grammar or scope mapping makes the result misleading.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
