# Feature 116: CLI console (delegated interactive console)

## Identity and status

- Matrix identity: 116 - `tina4 console` (interactive REPL / DB console)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. `console` is NOT a clap variant in the Rust binary (the enum has
  Doctor/Setup/Init/Serve/Scss/Ai/Build/Deploy/Env/Metrics/...); an unknown command falls through to
  `delegate_command`, so `tina4 console` runs the framework CLI's console. Measured 2026-08-11 from
  `tina4/src/main.rs` and the framework CLIs (PHP `bin/tina4php:1536` `case 'console'`; Python/Ruby/Node
  console entries). (`tina4/src/console.rs` is a UTILITY module - icons, `resolve_cmd`, `python_cmd` - not
  the console command.)
- Dependencies: `detect::detect_language`, the framework CLI, the framework runtime (a live app context).
- Dependants: developers exploring the ORM/DB interactively.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 console` opens an interactive session with the app booted - the ORM bound, models loaded, the
database connected - so a developer can query and manipulate data from a REPL instead of writing a
throwaway script. It forwards to the framework CLI, which starts the language's REPL with the app
context.

## Boundary

This packet owns the delegation and the parity question (does every framework offer a console, with the
same app context?). It does NOT own the REPL itself or the ORM/DB it exposes.

## Existing implementation evidence

- Rust side: no clap variant; `tina4 console` reaches `delegate_command` (`main.rs:1337`) ->
  `<framework-cli> console`, exit code propagated (PHP checks `vendor/`).
- Framework CLI: PHP `case 'console'` (`bin/tina4php:1536`); confirm the Python/Ruby/Node console entries
  and whether each boots the same app context (ORM bound).

## Public surface contract

`tina4 console` starts the REPL. No documented subcommands. The parity question (CLI-CONSOLE-PARITY): do
all four expose a console, does each pre-load the app (ORM/models/DB), and is the REPL flavour documented
(python -i / psysh / irb / node repl)?

## Inputs and outputs

- Input: the project's `.env` (for the DB) and the interactive session. Output: an interactive prompt;
  exit code propagated on quit.

## Lifecycle and operation graph

1. `tina4 console` -> detect language -> `<framework-cli> console`.
2. The framework boots the app context (binds the ORM/DB, loads models) and drops into the language REPL.

## Configuration and precedence

- DB via `.env` (framework-read). No CLI configuration.

## Failures, side effects and security

- A console has full app/DB access - it is a developer tool, run locally. There is no production guard,
  but the console is interactive (not a deploy surface). Note it can mutate data (the same
  developer-initiated risk as `seed`).
- The console imports the app, so module-level side effects run.

## Wire and persistence contract

No persisted state (beyond whatever the developer does interactively). No manifest.

## Providers and substitutability

The provider is the detected framework CLI and its REPL. Substitution is language detection.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-CONSOLE-PARITY | Confirm all four framework CLIs offer `console`, each pre-loading the app context (ORM bound, models loaded, DB connected) so `tina4 console` is consistent, and document the REPL flavour per language. A framework missing `console` is a blind-forward failure. | Ensure `console` exists in all four framework CLIs with a bound app context; add it to the CLI-command parity fixture (presence + "the ORM is usable at the prompt"). |

## Owner decisions

- CLI-CONSOLE-DEC-01 (proposed): confirm/standardize the console across the four (presence + app context).

## Proposed conformance fixture

Part of the CLI-command parity fixture (presence-level, since a REPL is interactive): assert
`<framework-cli> console` exists and, via a piped one-liner, that a model query works at the prompt in
each language (e.g. feed `User.count()` on stdin and assert a numeric result).

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI `console`.
- Protocol: `commands --json` (feature 122) advertises it.
- Runtime: the framework's app context (ORM/DB).

## Breaking changes and migration

- Adding `console` where missing is additive.

## Implementation backlog

1. Confirm `console` presence + app context across the four framework CLIs.
2. Add the presence/usability entry to the CLI-command parity fixture.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `console` command that boots the
app (binds the ORM/DB, loads models) and drops into the language REPL. The Rust forward detects the
language and propagates the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + console parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
