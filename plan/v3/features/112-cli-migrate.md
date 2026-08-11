# Feature 112: CLI migrate (delegated migration command)

## Identity and status

- Matrix identity: 112 - `tina4 migrate` (and `migrate:create` / `migrate:status` / `migrate:rollback`)
- Audit state: decision-ready
- Audit note: this is a DELEGATED CLI command. The `tina4` Rust binary is a thin forwarder; the actual
  migration CLI lives in each framework. Measured 2026-08-11 from `tina4/src/main.rs`
  (`delegate_command` :1337, `commands --json` via `manifest.rs`) and the four framework CLI registries
  (Python `cli/__init__.py:3258-3259`, Node `bin.ts:361-375`, PHP `bin/tina4php`, Ruby `lib/tina4/cli.rb`).
  The migration ENGINE (the runner, tracking table, transactional semantics) is a SEPARATE feature (the
  migrations subsystem, tracked separately); this packet audits only the CLI command surface + the
  delegation.
- Dependencies: `detect::detect_language`, the framework CLI, the `commands --json` protocol (feature 122).
- Dependants: developers running migrations; CI deploy steps.
- Existing ADRs: none dedicated to the command; the migration engine has its own decisions.
- Shared fixtures: NONE for the CLI surface (the engine has its own contract).

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 migrate` runs pending database migrations without the developer remembering each framework's
invocation (`tina4python migrate`, `php tina4php migrate`, `tina4ruby migrate`, `npx tina4nodejs
migrate`). The unified CLI detects the project language and forwards. `migrate:create` scaffolds a new
migration file; `migrate:status` and `migrate:rollback` (where present) report and undo.

## Boundary

This packet owns the DELEGATION: `tina4 migrate ...` -> detect language -> run the framework CLI with the
same arguments, propagating the exit code. It also owns the CLI-SURFACE parity question (does every
framework CLI expose the same migrate subcommands?).

It does NOT own the migration engine (runner, `tina4_migration` tracking table, per-file transaction,
idempotency, auto-migrate-on-startup) - that is the migrations subsystem feature. The CLI command is the
thin entry to that engine.

## Existing implementation evidence

- Rust forward: `main.rs` routes `migrate` (and unknown subcommands) through `delegate_command`
  (`main.rs:1337`): `detect_language` -> `resolve_cli(&info)` -> run `<framework-cli> migrate ...`,
  exiting with the child's code. For PHP it first checks `vendor/` exists (`main.rs:1341`).
- Blind forward: unknown/versioned subcommands (`migrate:create`, `migrate:status`) are forwarded blind;
  the framework rejects an unknown, so a `commands --json` manifest miss never breaks the command
  (`manifest.rs:9`).
- Framework CLI entries (the actual work): Python `migrate` + `migrate:create` (`cli/__init__.py:3258-
  3259`); Node `migrate` + `migrate:create` + `migrate:status` + `migrate:rollback` (`bin.ts:361-375`);
  PHP and Ruby expose `migrate` (and their own create/rollback) in `bin/tina4php` / `lib/tina4/cli.rb`.

## Public surface contract

`tina4 migrate` runs pending migrations. `tina4 migrate:create <desc>` scaffolds a migration file. Node
additionally documents `migrate:status` and `migrate:rollback`; Python documents `migrate:create`. The
subcommand SET is not identical across the four framework CLIs (CLI-MIGRATE-PARITY below) - the shared
core is `migrate` + `migrate:create`; `status`/`rollback` are present unevenly at the CLI layer even where
the engine supports rollback.

## Inputs and outputs

- Input: the subcommand and its args (a description for `migrate:create`), plus the project's `.env`
  database URL.
- Output: the framework CLI's output and exit code, forwarded verbatim. `tina4 migrate` is fail-fast (a
  failed migration returns non-zero) - the explicit CLI path, as opposed to the non-fatal
  auto-migrate-on-startup.

## Lifecycle and operation graph

1. `tina4 migrate` -> `delegate_command` detects the language (PHP checks `vendor/`).
2. It runs `<framework-cli> migrate ...` as a child and propagates the exit code.
3. The framework CLI invokes the migration engine (runs pending files in numeric order, each in its own
   transaction where the engine supports it, tracked in `tina4_migration`).

The CLI command is a pass-through; all migration semantics belong to the engine feature.

## Configuration and precedence

- The database is configured by the project's `.env` (`TINA4_DATABASE_URL`), read by the framework, not
  the CLI.
- `TINA4_AUTO_MIGRATE` (engine, default on) governs the SEPARATE startup auto-migration; the explicit
  `tina4 migrate` command is unaffected and stays fail-fast.
- The CLI adds no configuration of its own.

## Failures, side effects and security

- The forward propagates the framework's exit code, so `tina4 migrate` fails CI on a bad migration.
- PHP-only precondition: `delegate_command` refuses if `vendor/` is missing (composer not installed),
  with an actionable message - a good guard, but note it is PHP-specific (the other three do not
  pre-check their deps at the CLI layer).
- No CLI-level security surface; the engine owns SQL execution.

## Wire and persistence contract

The CLI persists nothing. The engine persists the `tina4_migration` tracking table (a separate feature's
contract). `migrate:create` writes a migration file under `migrations/`.

## Providers and substitutability

The provider is the detected framework CLI. The substitution is language detection; the same
`tina4 migrate` maps to four different CLI invocations. No other abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-MIGRATE-PARITY | The migrate SUBCOMMAND set differs across the framework CLIs: all expose `migrate`; Python documents `migrate:create`; Node documents `migrate:create`/`migrate:status`/`migrate:rollback`. `status`/`rollback` are unevenly exposed at the CLI even where the engine supports rollback. So `tina4 migrate:rollback` works on Node but may be a blind-forward miss on another framework. | OWNER DECISION: standardize the CLI-level migrate subcommand set across all four framework CLIs (`migrate`, `migrate:create`, `migrate:status`, `migrate:rollback`) so `tina4 migrate:<x>` behaves identically everywhere. This is a framework-CLI parity fix, not a Rust-CLI change. |
| CLI-DELEGATE-PHPGUARD | The `vendor/` pre-check is PHP-only; the other three do not pre-verify their dependencies at the CLI layer, so a missing dep surfaces as a raw framework-CLI error instead of an actionable message. | Low priority: either add an equivalent dep pre-check for the other three or document that the guard is PHP-specific. |

## Owner decisions

- CLI-MIGRATE-DEC-01 (proposed): unify the migrate subcommand set across the four framework CLIs.

## Proposed conformance fixture

Part of a CLI-command parity fixture (see feature 122): for a scaffolded project per language, assert
`tina4 migrate` and `tina4 migrate:create <desc>` run and produce the same shape (a migration file
created; pending migrations applied), and that `migrate:status`/`migrate:rollback` either exist
everywhere or are documented as unsupported. The engine's own contract fixture (transaction, tracking
table) is separate.

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI.
- Protocol: `commands --json` (feature 122) discovers/renders the subcommands.
- Engine: the migrations subsystem (separate feature) does the work.
- Documentation: the CLI `CLAUDE.md` `tina4 migrate` line; each framework's migration docs.

## Breaking changes and migration

- Unifying the subcommand set is additive per framework (adding missing `migrate:status`/`rollback`
  entries). No migration for existing projects.

## Implementation backlog

1. Standardize the migrate subcommand set across the four framework CLIs (CLI-MIGRATE-DEC-01).
2. Add the CLI-command parity fixture entry for migrate.
3. Decide the PHP-only `vendor/` guard (extend or document).

## Porting capsule

There is nothing to port in the Rust CLI (it forwards). The framework-CLI side needs, in each language:
a `migrate` command that runs the engine's pending migrations fail-fast, a `migrate:create <desc>` that
scaffolds a numbered migration file, and (for parity) `migrate:status` and `migrate:rollback`. The Rust
forward detects the language, checks the language's deps where cheap (the PHP `vendor/` lesson), and
propagates the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + CLI-surface parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
