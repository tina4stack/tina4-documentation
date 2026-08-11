# Feature 15: Migrations

## Identity and status

- Matrix identity: 15 - Migrations (`tina4_python/migration/__init__.py`; `tina4_python/migration/runner.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, strong shared design with real per-language footguns. Measured
  2026-08-11. Python `migration/runner.py` (`ebbab30`); PHP `Tina4/Migration.php` (1573 lines, `6faabac5`);
  Ruby `lib/tina4/migration.rb` (`6d5b1de`); Node `packages/orm/src/migration.ts` + `packages/cli/src/
  commands/migrate.ts` (`27cf0f4`).
- Dependencies: the database facade + adapters (transactions, execute), the CLI, the auto-migrate boot hook.
- Dependants: every app that evolves its schema; the server boot path (auto-migrate).
- Existing ADRs: none dedicated; the "auto-migrate + footgun overhaul" memory.

- Catalog phase: database

## Why this feature exists

Migrations evolve a schema forward reproducibly: numbered/timestamped files applied once, in order, recorded
in a ledger so they never re-run. The hard parts are crash-safety (the ledger row must land atomically with
the DDL), cross-engine idempotency (engines without `IF NOT EXISTS`), and the boot-time convenience of
auto-applying pending migrations without turning it into a production footgun.

## Existing implementation evidence

Strong shared design in all four: a `tina4_migration` ledger (`migration_name UNIQUE, batch, executed_at,
passed`, applied = `passed = 1`), numeric-aware ordering (`9_` before `10_`, both `NNNNNN_` and timestamp
prefixes; unprefixed files warn and sort last), a `migrations/` dir (+ legacy `src/migrations/`), `.sql` +
code migrations, a quote/comment/proc-block-aware statement splitter, delete-before-insert recording (at most
one row per name), per-file transactions, and Firebird/MSSQL `CREATE`/`ADD` idempotency skips. Universal
behaviours confirmed:

- LEDGER ROW WRITTEN IN THE SAME TRANSACTION AS THE DDL (the crash-safety design) - `start_transaction` ->
  statements -> `record_applied` -> `commit`, on the ORM path in all four.
- ATOMICITY is truly atomic only on transactional-DDL engines (PostgreSQL). MySQL/Firebird implicit-commit
  DDL, so a multi-statement file that fails midway leaves earlier statements applied while the ledger row is
  not written (re-run). All four document this; the idempotency skips cover Firebird/MSSQL, not MySQL.
- AUTO-MIGRATE-ON-STARTUP is DEFAULT ON in all four (`TINA4_AUTO_MIGRATE`, applies pending `.sql` at every
  boot), non-breaking (a failure is logged and the service still boots), with the multi-instance concurrent-
  first-apply race documented as the reason to disable it.
- Migrations do NOT route their SQL through the feature-7 SQL translator - the author writes engine-specific
  DDL ("one logical change per file").

## Public surface contract

`migrate()` / `rollback(steps)` / `status()` / `create()` and the `tina4 migrate[:create|:rollback|:status]`
CLI. Contract: pending migrations apply once in order, each recorded atomically with its DDL; `rollback` runs
the `.down` and removes the ledger row; auto-migrate applies pending at boot unless disabled.

## Inputs and outputs

- Input: migration files in `migrations/`, the DB, `TINA4_AUTO_MIGRATE`. Output: applied DDL + ledger rows,
  or a halted run with an error (fail-fast on the CLI), or a swallowed boot-time failure.

## Lifecycle and operation graph

1. Ensure the `tina4_migration` ledger (engine-aware, v2->v3 auto-upgrade).
2. List pending files (numeric-aware sort), skipping applied (`passed = 1`).
3. Per file: `start_transaction` -> split + execute statements (Firebird/MSSQL idempotency skips) ->
   `record_applied` -> `commit`; on error `rollback` + halt.
4. Boot: auto-migrate runs the same path if enabled.

## Configuration and precedence

- `TINA4_AUTO_MIGRATE` (default on) gates the boot hook. The migrations dir defaults to `migrations/` (legacy
  `src/migrations/`). No SQL-translation config.

## Failures, side effects and security

- Side effect: applies DDL (schema change) - at boot by default. The failure mode is a partial apply on
  non-transactional-DDL engines and the boot-time footgun (destructive DDL auto-applied). See the register
  for the broken `migrate:status`, the divergent Node CLI path, and the rollback-drops-ledger footgun.

## Wire and persistence contract

The `tina4_migration` ledger is the persistence contract (name/batch/executed_at/passed). The crash-safety
contract is "ledger row in the same transaction as the DDL" (honoured on transactional-DDL engines).

## Providers and substitutability

Engine-aware only in the bookkeeping DDL and the idempotency skips; the migration bodies are engine-specific
author SQL.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| MIG-CLI-STATUS-BROKEN | `tina4 migrate:status` is broken in TWO of four, each differently and untested: Python raises `KeyError` (`_migrate_status` prints `m['migration_id']` but the dicts are keyed `migration_name` - crashes the moment there is >=1 migration); PHP raises `TypeError` at construction (`new Migration($migrationsDir)` passes the dir STRING into the `?DatabaseAdapter $db` ctor param, and status never resolves a `$db`). Ruby/Node not flagged. No test exercises the CLI status print path in Python/PHP. | Fix the key/argument bug in Python and PHP; add a CLI-level `migrate:status` test (run it against a real migrated DB and assert the printed output) in all four. |
| MIG-NODE-CLI-DIVERGENT | Node has TWO migration code paths, and the CLI one is unsafe. `tina4 migrate` (`migrate.ts` `runMigrations`) does NOT use the ORM `migrate()`: it uses naive `sql.split(";")` (breaks a `;` inside a string/comment/proc block that the ORM splitter handles), has NO per-file transaction (a mid-file failure leaves earlier statements applied on ALL engines including PostgreSQL, with no rollback), has NO Firebird/MSSQL idempotency skips, and records the ledger AFTER the loop (not in-transaction). All untested. | Make the Node CLI call the ORM `migrate()` (one code path), so the CLI gets the transactional, robust-split, idempotent behaviour the ORM path already has. |
| MIG-ROLLBACK-DROPS-LEDGER | In Ruby, PHP, and Node, `rollback` REMOVES the ledger row even when the schema was not successfully reversed - a missing `.down.sql` (Ruby/PHP) or a failed down script (Node) logs a warning but still deletes the tracking row, leaving the schema in place and untracked. Python is the fail-safe outlier (it RAISES on a missing down artifact). | Do not remove the ledger row unless the down actually succeeded; on a missing/failed down, RAISE (Python's behaviour) rather than silently drop tracking. Align all four on fail-safe rollback. |
| MIG-FBMSSQL-MOCK | Firebird/MSSQL migration idempotency is verified against FAKES in TWO of four: Ruby's `migration_footguns_spec` uses a hand-rolled `FakeDB`; Node's `migrationFootguns.test` uses fake adapters with a spoofed `constructor.name`. PHP converted its fakes to a REAL-engine test (`MigrationFootgunsLiveEngineTest`, "NO DOUBLES"). This violates the no-mock rule for those engine-specific paths (the real MySQL/MSSQL/Firebird migration path is unproven in Ruby/Node). | Convert the Ruby/Node Firebird+MSSQL migration idempotency tests to real engines (PHP's live-engine test is the model), gated in the require-services CI. |
| MIG-AUTO-DEFAULT-ON | Auto-migrate-on-startup is DEFAULT ON in all four, applying pending DDL at every boot - a footgun in production (destructive DDL auto-applied; multi-instance first-apply race). It is non-breaking (swallowed) which HIDES a failed migration behind a running server. | Consider defaulting `TINA4_AUTO_MIGRATE` OFF in production (or requiring an explicit opt-in), and surfacing a swallowed auto-migrate failure more loudly (a health-check degradation, not just a log line). Owner call. |
| MIG-SQLITE-DOC-DRIFT | Python's CLAUDE.md and Ruby's docstring state SQLite auto-commits DDL and leaves partial applies - but Python's shipped test proves SQLite ROLLS BACK (SQLite has transactional DDL and Tina4 autocommit is off). The doc is wrong for SQLite (accurate for MySQL/Firebird). | Correct the SQLite atomicity claim in the Python/Ruby docs (First Principle: docs match code). |
| MIG-NO-TRANSLATOR | Migrations bypass the SQL translator in all four (author writes engine-specific DDL). Documented design, not a bug, but it means a migration is not portable across engines unless the author makes it so. | Document prominently; optionally offer a portable-DDL helper. No code change required. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- MIG-DEC-01 (proposed): fix the broken `migrate:status` (Python + PHP) and add a CLI-status test
  (MIG-CLI-STATUS-BROKEN); unify Node's CLI onto the ORM `migrate()` (MIG-NODE-CLI-DIVERGENT). These are real
  broken/unsafe CLI paths.
- MIG-DEC-02 (proposed): make rollback fail-safe (never drop the ledger row without a successful reverse -
  Python's behaviour) across all four (MIG-ROLLBACK-DROPS-LEDGER).
- MIG-DEC-03 (proposed): convert the Ruby/Node Firebird+MSSQL migration tests to real engines
  (MIG-FBMSSQL-MOCK); decide the auto-migrate default + failure visibility (MIG-AUTO-DEFAULT-ON); fix the
  SQLite doc drift (MIG-SQLITE-DOC-DRIFT).

## Proposed conformance fixture

A shared fixture against real engines (no mocks): a multi-statement file rolls back cleanly on a
transactional-DDL engine (PostgreSQL) on a mid-file failure; the ledger row commits atomically with the DDL;
`migrate:status` prints without crashing on a migrated DB; a missing/failed `down` does NOT drop the ledger
row; Firebird/MSSQL `CREATE`/`ADD` idempotency is proven against REAL Firebird 5 + SQL Server; and the CLI
and ORM paths produce identical results (Node). Gate the real-engine parts in the require-services CI.

## Integration map

- Consumers: the CLI (`tina4 migrate*`), the server boot hook (auto-migrate), apps. Related: feature 5 (the
  Database facade / transactions), feature 7 (NOT used - migrations bypass the translator), the DB providers
  (9-14) whose idempotency skips this relies on.

## Breaking changes and migration

- Fixing rollback to be fail-safe changes behaviour (a missing/failed down now raises instead of dropping
  tracking) - document it. Unifying Node's CLI path changes CLI behaviour (safer) - document it. Defaulting
  auto-migrate off in production is a behaviour change - document + migrate.

## Implementation backlog

1. MIG-DEC-01: fix `migrate:status` (Python/PHP) + a CLI-status test; unify Node CLI onto ORM `migrate()`.
2. MIG-DEC-02: fail-safe rollback (all four).
3. MIG-DEC-03: real-engine Firebird/MSSQL migration tests (Ruby/Node); auto-migrate default/visibility; SQLite
   doc fix.

## Porting capsule

A migrations engine needs: a `tina4_migration` ledger (name UNIQUE, batch, executed_at, passed) with the row
written IN THE SAME TRANSACTION as the DDL (crash-safe on transactional-DDL engines); numeric-aware ordering;
a quote/comment/proc-block-aware statement splitter (never a naive `split(";")`); per-file transactions with
Firebird/MSSQL idempotency skips; delete-before-insert recording; a `migrate:status` that actually runs; a
FAIL-SAFE rollback that never drops the ledger row without a successful reverse; ONE code path for CLI and
programmatic use (not a weaker CLI re-implementation); and real-engine tests for the Firebird/MSSQL idempotency
(never fakes). Auto-migrate-on-startup should be opt-in-safe (consider off-by-default in production) and must
not hide a failed migration behind a running server.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (ledger, per-file txn, boot hook).
- [x] Configuration, failure (partial apply, boot footgun) and security rules complete.
- [x] Wire/persistence (the ledger) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (broken status, Node CLI, rollback footgun, FB/MSSQL
  mocks).
- [x] Owner ambiguities decided (MIG-DEC-01..03).
- [x] Conformance fixture (real-engine, crash-safety, status, rollback) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
