# Feature 113: CLI seed (delegated seeder command)

## Identity and status

- Matrix identity: 113 - `tina4 seed` (run the project's database seeders)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. The `tina4` Rust binary forwards to the framework CLI; the seeder
  ENGINE (FakeData / seed_table, discovery of `src/seeds/`) is a SEPARATE feature. Measured 2026-08-11
  from `tina4/src/main.rs` (`delegate_command`) and the four framework CLIs (Python
  `cli/__init__.py:3263` `seed`; PHP `bin/tina4php:1401` `case 'seed'`; Node `bin.ts:405` `seed`; Ruby
  `lib/tina4/cli.rb` seed entry).
- Dependencies: `detect::detect_language`, the framework CLI, the seeder engine.
- Dependants: developers populating a dev database; demo/gallery setup.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 seed` fills the database with fake/sample data so a fresh project has something to show. It
forwards to the detected framework CLI, which discovers and runs the seeder files under `src/seeds/`.

## Boundary

This packet owns the delegation (`tina4 seed` -> framework CLI `seed`, exit code propagated) and the
CLI-surface parity question. It does NOT own the seeder engine (FakeData generators, `seed_table`, seed
discovery) - that is the seeder subsystem feature.

## Existing implementation evidence

- Rust forward: `main.rs` `delegate_command` (`:1337`) detects the language and runs `<framework-cli>
  seed`, propagating the exit code (PHP checks `vendor/` first).
- Framework CLI entries: Python `seed` (`cli/__init__.py:3263`), PHP `case 'seed'` (`bin/tina4php:1401`),
  Node `seed` (`bin.ts:405`), Ruby seed entry (`lib/tina4/cli.rb`). All four expose the command.

## Public surface contract

`tina4 seed` runs every seeder the framework discovers under `src/seeds/`. There are no documented
subcommands or flags at the CLI layer (unlike `migrate`), so the seed surface is uniform: one verb,
forwarded. Any per-language seeder options belong to the engine.

## Inputs and outputs

- Input: the project's seed files and its `.env` database URL. Output: the framework CLI's output and
  exit code, forwarded verbatim.

## Lifecycle and operation graph

1. `tina4 seed` -> `delegate_command` detects the language.
2. Runs `<framework-cli> seed` as a child, propagating the exit code.
3. The framework discovers `src/seeds/` and runs each seeder against the bound database.

## Configuration and precedence

- Database via the project's `.env` (framework-read). The CLI adds no configuration.

## Failures, side effects and security

- The forward propagates the framework's exit code, so a failed seeder fails `tina4 seed`.
- Seeding WRITES to the configured database - a side effect the developer initiates. There is no
  production guard at the CLI layer; running `tina4 seed` against a production `.env` would seed
  production. Consider whether the engine or CLI should refuse to seed when not in debug/dev.
- PHP-only `vendor/` pre-check (shared delegation behaviour).

## Wire and persistence contract

The CLI persists nothing; the engine writes seed rows. No manifest.

## Providers and substitutability

The provider is the detected framework CLI; substitution is language detection. No other abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-SEED-PRODGUARD | `tina4 seed` writes to whatever database the `.env` points at, with NO dev/production guard at the CLI OR the engine - measured 2026-08-11, confirmed ABSENT in both in all four (no `TINA4_DEBUG`/production/`--force` check in any seeder or seed CLI command: Python `cli/__init__.py:927` `_seed`, Node `packages/cli/src/commands/seed.ts`, PHP/Ruby seed commands). Seeding a production database is a foot-gun. | OWNER DECISION: add a guard that refuses to seed unless `TINA4_DEBUG` is truthy (or a `--force`/`--production` is passed), in the ENGINE so all four inherit it (the guard is absent everywhere today). |
| CLI-SEED-PARITY | Confirm all four framework CLIs discover the SAME seed directory (`src/seeds/`) and run seeders in the same order, so `tina4 seed` is identical everywhere. | Fold into the CLI-command parity fixture (feature 122) and the seeder subsystem's own contract. |

## Owner decisions

- CLI-SEED-DEC-01 (proposed): decide the production-seed guard (refuse unless debug/forced).

## Proposed conformance fixture

Part of the CLI-command parity fixture: for a scaffolded project per language with a known seeder, assert
`tina4 seed` runs it and the expected rows land, identically across the four; assert the production guard
(once decided) refuses without debug/force. The seeder engine's fake-data contract is separate.

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI `seed`.
- Protocol: `commands --json` (feature 122).
- Engine: the seeder subsystem (separate feature).

## Breaking changes and migration

- A production-seed guard would change behaviour for anyone relying on seeding a non-debug database;
  document the `--force` escape hatch.

## Implementation backlog

1. Decide and implement the production-seed guard (CLI-SEED-DEC-01) in the engine.
2. Add the seed entry to the CLI-command parity fixture; confirm same directory + order across four.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `seed` command that discovers
`src/seeds/` and runs each seeder against the bound database, ideally with a dev-only guard. The Rust
forward detects the language and propagates the exit code.

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
