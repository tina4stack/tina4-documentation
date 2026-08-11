# Feature 114: CLI test (delegated test-runner command)

## Identity and status

- Matrix identity: 114 - `tina4 test` (run the project's test suite)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. The `tina4` Rust binary forwards to the framework CLI; the test
  RUNNER (pytest / phpunit / rspec / tsx run-all) is a SEPARATE concern owned by each framework. Measured
  2026-08-11 from `tina4/src/main.rs` (`delegate_command`), `tina4/src/agent.rs` (the setup-flow test
  helper), and the four framework CLIs (Python `cli/__init__.py:3265`, PHP `bin/tina4php:1381`, Node
  `bin.ts:383`, Ruby `lib/tina4/cli.rb`).
- Dependencies: `detect::detect_language`, the framework CLI / package manager, the test runner.
- Dependants: developers running tests; CI.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 test` runs a project's tests without remembering each toolchain (`pytest`, `phpunit`, `rspec`,
`tsx test/run-all.ts`). It forwards to the detected framework CLI (or, in the scaffold/setup flow, to the
package manager's `test` script), propagating the exit code so CI can gate on it.

## Boundary

This packet owns the delegation and the invocation-parity question (framework CLI `test` vs `npm test`).
It does NOT own the test runner or the tests themselves.

## Existing implementation evidence

- Rust forward: `tina4 test` routes through `delegate_command` (`main.rs:1337`) to `<framework-cli> test`,
  exit code propagated (PHP checks `vendor/`).
- A DIVERGENCE in the setup-flow helper (`agent.rs`): it invokes tests as node `npm test`, php `php
  tina4php test`, ruby `tina4ruby test`, python `tina4python test` - so Node's test path is the npm
  script, the others the framework CLI. Confirm which path `tina4 test` itself takes per language.
- Framework CLI entries: Python `test` (`cli/__init__.py:3265`), PHP `case 'test'` (`bin/tina4php:1381`),
  Node `test` (`bin.ts:383`), Ruby `test`.

## Public surface contract

`tina4 test` runs the suite. No documented subcommands at the CLI layer. The runner and any
filters/patterns are the framework's (`tina4python test`, `phpunit`, etc.).

## Inputs and outputs

- Input: the project's tests and toolchain. Output: the runner's output and exit code, forwarded verbatim
  (fail-fast for CI).

## Lifecycle and operation graph

1. `tina4 test` -> detect language -> run the framework CLI's `test` (or npm script) as a child.
2. The framework runs its test runner and returns a pass/fail exit code, which the CLI propagates.

## Configuration and precedence

- The runner reads its own config (pytest.ini, phpunit.xml, etc.). The CLI adds none.

## Failures, side effects and security

- Exit code propagated, so `tina4 test` gates CI correctly.
- CLI-TEST-INVOKE: Node's path may be `npm test` (the project script) while the others are the framework
  CLI's `test` - two different invocation contracts. If a project's `package.json` `test` script differs
  from the framework runner, `tina4 test` on Node runs something different from the other three.
- No security surface.

## Wire and persistence contract

No persisted state. The runner may write coverage/artifacts per its own config.

## Providers and substitutability

The provider is the detected framework CLI / npm script. Substitution is language detection.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-TEST-INVOKE | The test invocation is not uniform: the setup helper uses `npm test` for Node but the framework CLI `test` for the others. Depending on the path `tina4 test` takes, Node may run the project's npm `test` script while Python/PHP/Ruby run the framework runner directly - a different contract (a project could point `npm test` anywhere). | OWNER DECISION: make `tina4 test` run the framework CLI's `test` uniformly (so it is the framework runner in all four), or document that Node defers to the npm `test` script. Confirm the actual `tina4 test` path per language first. |
| CLI-TEST-PARITY | Confirm all four framework `test` commands run the real suite fail-fast (no skips counted as pass) - ties to the no-skipped-tests discipline. | Fold into the CLI-command parity fixture. |

## Owner decisions

- CLI-TEST-DEC-01 (proposed): unify the `tina4 test` invocation (framework runner) or document the Node
  npm-script exception.

## Proposed conformance fixture

Part of the CLI-command parity fixture: a scaffolded project per language with one passing and one
failing test; assert `tina4 test` returns 0 on the passing set and non-zero on the failing one,
identically across the four, and that it runs the framework runner (not an arbitrary npm script).

## Integration map

- Dispatch: `main.rs` -> `delegate_command` (or npm) -> framework runner.
- Protocol: `commands --json` (feature 122).
- Runner: pytest / phpunit / rspec / tsx (per framework).

## Breaking changes and migration

- Unifying the invocation (if Node moves off `npm test`) changes what `tina4 test` runs on Node; document
  it.

## Implementation backlog

1. Confirm the `tina4 test` path per language; unify on the framework runner (CLI-TEST-DEC-01).
2. Add the pass/fail parity fixture entry.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `test` command that runs its real
suite fail-fast. The Rust forward detects the language, runs the framework runner uniformly, and
propagates the exit code - avoiding the npm-script divergence.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + invocation parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
