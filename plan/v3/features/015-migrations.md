# Feature 015: Migrations

## Identity and status

- Matrix identity: 15 - Migrations
- Audit state: decision-ready
- Audit note: measured 2026-08-08 (LOC/CC/MI + lab-verified baselines below); prose
  sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 3 adapter interface (connection, transaction, execute), Feature 4
  URL parser, Feature 5 write facade, the seven providers (008-014) for the actual DDL, and
  the CLI for the `migrate`/`rollback`/`status`/`create` commands
- Dependants: application startup (auto-migrate), the CLI migrate commands, the ORM (schema
  it reads must exist), and any scaffolder that generates a migration
- Existing ADRs: ADR-0041 (explicit directory beats default), ADR-0024 (no provider claims
  a rollback it did not perform), ADR-0002 (metrics engine used for the measurements)
- Shared fixtures: `migrations_contract.json` is required (14 cases below); it runs on
  SQLite locally and swaps providers on the .99 lab

## Why this feature exists

An engineer needs one migration surface that creates, applies, inspects and
rolls back database changes in the same order on every Tina4 language.

## Boundary

Feature 15 owns SQL and code migrations, discovery and ordering, the tracking
table, apply/status/rollback, startup auto-migration and the public `Migration`
surface. Database providers own connection and transaction mechanics.

The live feature matrix retired rows 21-26 into database-adapter group 4.
Feature 15 is therefore the next standalone migration feature.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Implementation | `migration/runner.py` | `Migration.php`, `MigrationBase.php` | `migration.rb` | `orm/src/migration.ts` |
| Size (LOC / fns / CC) | 801 / 38 / 192 | 881 / 43 / 200 | 457 / 38 / 131 | 989 / 63 / 249 |
| Kinds discovered | `.sql` + `.py` | `.sql` + code | `.sql` + code | `.sql` only runs; `.ts` created-but-invisible |
| migrate result shape | applied name list; raises | `{applied,skipped,errors}` | per-file `{name,status,error?}` | `{applied,skipped,failed}` |
| Rollback with no down | raises, RETAINS row | warns, REMOVES row | warns, REMOVES row | warns, REMOVES row (worst) |
| Lab baseline (green) | 93/0 skip (`12cc44bb`) | 105 tests 331 assert (`46f96429`) | 94/0 pending (`25ac783`) | 272 pass incl real PG (`96a5050e`) |

### Retained introductory record

Audited 2026-08-08. Part of `98-feature-audit.md`.

### Files

| | implementation | CLI |
| --- | --- | --- |
| python | `tina4-python/tina4_python/migration/runner.py` | `tina4-python/tina4_python/cli/__init__.py` |
| php | `tina4-php/Tina4/Migration.php`, `MigrationBase.php` | `tina4-php/bin/tina4php` |
| ruby | `tina4-ruby/lib/tina4/migration.rb` | `tina4-ruby/lib/tina4/cli.rb` |
| node | `tina4-nodejs/packages/orm/src/migration.ts` | `tina4-nodejs/packages/cli/src/commands/migrate*.ts` |

### Measurements

Measured with the native Tina4 metrics engine (ADR-0002). The installed
`/opt/homebrew/bin/tina4` lacks the native `metrics` command despite reporting
3.8.56, so the current tracked CLI binary at `tina4/target/debug/tina4` was put
first on PATH for the audit harness.

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |
| python | 801 | 38 | 192 | 5.05 | `_split_statements` (40) | 9.6 | 2 error, 5 warn |
| php | 881 | 43 | 200 | 4.65 | `Migration.splitStatements` (41) | 5.7 | 1 error, 9 warn |
| ruby | 457 | 38 | 131 | 3.45 | `split_sql_statements` (40) | 12.9 | 1 error, 2 warn |
| node | 989 | 63 | 249 | 3.95 | `splitStatements` (40) | 13.3 | 1 error, 10 warn |

Ruby is leanest and simplest per function. That does not settle the verdict:
correctness outranks size, and the public/wire contract currently diverges.

### Existing verification baseline

Focused real-SQLite runs at the audited HEADs:

| | result | qualification |
| --- | --- | --- |
| python | 76 passed, 2 skipped | live PostgreSQL cases did not run locally |
| php | 78 passed, 3 skipped | live-engine cases did not run locally |
| ruby | 86 passed, 3 pending | live PostgreSQL cases did not run locally |
| node | 249 standalone assertions + 4 Vitest cases passed | correct `tsx` runner used for standalone files |

The initial macOS runs were characterization only because service cases skipped.
The suites were then re-run as root on the lab host with
`TINA4_REQUIRE_SERVICES=1`, the isolated `lab-env-for.sh` namespace, all lab
services healthy, and each clone reset to the exact `origin/v3` HEAD below:

| | HEAD | lab result |
| --- | --- | --- |
| python | `12cc44bb` | 93 passed, 0 skipped |
| php | `46f96429` | 105 tests, 331 assertions, 0 skipped |
| ruby | `25ac783` | 94 examples, 0 pending |
| node | `96a5050e` | 272 assertions/tests passed, including real PostgreSQL |

Logs: `/root/tina4-lab/migration-audit-{python,php,ruby,node}.log` on the lab.
This proves the existing baseline, not the missing cases below: none of those
green suites asks Node to execute a generated `.ts` migration or asserts that a
failed/missing rollback retains its tracking row.

### Confirmed divergences

#### 1. Node creates code migrations that its runner cannot execute

`createMigration(..., {kind: "code"})` creates a `.ts` migration, but
`migrate()`, `status()`, and `Migration.getFiles()` scan only `.sql`. The CLI
successfully creates an artefact that is invisible to every execution/status
path. Python, PHP, and Ruby discover and execute their native code migrations.

#### 2. The public file/status surfaces omit runnable migrations

Python's `Migration.get_files()` and `_status()` scan only `.sql`, although
`_migrate()` runs `.py`. Node has the same split for `.ts`. A code migration can
run yet never appear in `getFiles()` or status (Python), or be created and never
run nor appear (Node).

#### 3. Rollback can erase history without reversing the schema

Python raises and retains the tracking row when neither a code migration nor a
`.down.sql` file exists. PHP, Ruby, and Node warn and remove the tracking row.
Node is worse on an actual rollback SQL error: it logs the error and still
removes the row. The observable state then says "pending" while the schema is
still applied, so the next migrate can replay DDL over live objects.

Canonical rule: a migration record is removed only after its down operation
completed successfully. Missing down code is a rollback failure, not a
successful no-op.

#### 4. The public outcomes are four contracts

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| migrate | applied filename list; raises | `{applied,skipped,errors}` | per-file `{name,status,error?}` | `{applied,skipped,failed}` |
| rollback | rolled-back filename list; raises | `{rolledBack,errors}` | per-file `{name,status,error?}` | filename list; logs errors |
| status.completed | record objects | record objects | filenames | filenames |
| create SQL | up-file path only | up-file path only | up-file path only | `{upPath,downPath}` |

This makes identical application/CLI code observe different success and failure
states. The result shape needs one contract before another implementation can
be written.

#### 5. Alias debt contradicts the standing no-alias rule

The migration surface carries `get_applied` plus `get_applied_migrations`, PHP
equivalents, Ruby `run` as an alias of `migrate`, and legacy function APIs beside
the object API. The audit must identify real external call sites, choose the
primary names, and remove redundant aliases with a Breaking migration note.

## Public surface contract

One `Migration` object, one name per concept, no aliases (the full idiomatic spelling table
is in Breaking changes below). The neutral surface is: construct with `(db, migrationsDir,
delimiter)`; `migrate()` applies pending migrations and returns `{applied, skipped, failed}`;
`rollback(steps=1)` reverses the last batch and returns `{rolledBack, failed}`; `status()`
returns `{completed, pending}` as filename strings; `create(description, kind="sql")` writes
a migration and returns the up-file path; and `getApplied()`, `getPending()`, `getFiles()`
return filename lists that include BOTH `.sql` and native-code migrations. A detailed-record
inspection (the tracking rows themselves) is a separately named method, never `status()`.

## Inputs and outputs

- A migration is a file on disk: either a `.sql` file (with a deterministic sibling
  `.down.sql`) or a native-code file (`.py`/`.php`/`.rb`/`.ts`) exposing an up and a down.
- Discovery orders by numeric prefix: `9_` applies before `10_` (numeric, not
  lexicographic); an unprefixed file sorts last and warns.
- The tracking row carries `id`, `migration_name`, `description`, `batch`, `executed_at`
  and `passed`; `passed = 1` is the only "applied" state.
- `migrate()` returns `{applied, skipped, failed}` where `failed` carries the migration name
  and the error; `rollback()` returns `{rolledBack, failed}`; `status()` returns
  `{completed, pending}` filename strings. These three shapes are the same in all four
  (the current four-way divergence in divergence 4 is what the contract closes).
- `create()` returns the up-file path; a caller derives the `.down.sql` sibling from it
  rather than receiving a second path (closing the Node-only `{upPath, downPath}` shape).

## Lifecycle and operation graph

1. Discovery scans the resolved migrations directory for `.sql` AND native-code files, and
   orders them by numeric prefix (divergences 1 and 2 close the current `.sql`-only scans).
2. `migrate()` applies each pending migration in order inside a transaction where the engine
   supports transactional DDL; a success writes exactly one `passed = 1` row; a second run
   skips an already-applied migration.
3. Apply stops at the FIRST failure; later files do not run, and a failed multi-statement
   file gains no applied row.
4. `status()`/`getApplied()`/`getPending()`/`getFiles()` inspect without mutating and
   include both kinds.
5. `rollback(steps=1)` runs a batch in reverse apply order; it removes a tracking row ONLY
   after that migration's down operation completes. A missing down is a failure, not a
   no-op; a failing down SQL is a failure. Either way the row is RETAINED (divergence 3).
6. Startup auto-migrate (`TINA4_AUTO_MIGRATE`, default on) runs `migrate()` during boot; a
   failure logs and still allows boot, whereas an explicit CLI migrate exits non-zero.

## Configuration and precedence

- Default directory: project-root `migrations/`.
- Explicit constructor/CLI directory beats every default (ADR-0041).
- Legacy `src/migrations/` is fallback-only when the default directory was not
  explicitly supplied and project-root `migrations/` does not exist.
- Default delimiter: `;`; `SET TERM` and line-boundary `//` blocks are parsed as
  syntax, never inferred from `//` inside a URL/string.
- `TINA4_AUTO_MIGRATE` defaults on; false/0/no/off disables it. Startup failure
  logs and allows boot; explicit CLI migration fails with a non-zero exit.

## Failures, side effects and security

- A failed apply stops the run at the first failure and writes NO applied row for the failed
  file; later files do not run.
- A rollback whose down is missing or errors is a FAILURE that retains the tracking row, so
  observable state never says "pending" while the schema is still applied (divergence 3, the
  replay-DDL-over-live-objects hazard).
- Tracking-table write and migration body share one transaction where the engine supports
  transactional DDL; no provider records a rollback it did not perform (ADR-0024).
- Startup auto-migrate degrades on failure (logs, boots); explicit CLI migrate exits
  non-zero, so a human-run migration cannot fail silently.
- Statement splitting parses `SET TERM` and line-boundary `//` blocks as syntax; a `//`
  inside a URL or string literal is NOT treated as a delimiter.
- Migration SQL is trusted developer input (it is DDL the team wrote), so the security
  boundary is directory resolution: an explicit directory beats the default (ADR-0041) and
  the legacy `src/migrations/` is fallback-only.

## Wire and persistence contract

### Persisted contract

The tracking table remains `tina4_migration` with canonical columns
`id`, `migration_name`, `description`, `batch`, `executed_at`, and `passed`.
A migration is applied iff one row with `passed = 1` exists for its canonical
filename/stem. A failed apply or rollback never writes a successful state.
Legacy tracking schemas upgrade in place before state is read.

## Providers and substitutability

The same SQL migration fixture runs with the same outcome on SQLite, PostgreSQL, MySQL,
MSSQL and Firebird. Where an engine cannot offer transactional DDL (MySQL commits DDL
implicitly, so a mid-migration failure cannot roll back), the public contract NARROWS to
what every engine can guarantee rather than becoming a per-provider caveat (ADR-0024): a
multi-statement migration on a non-transactional-DDL engine is documented as
non-atomic, and the recommendation is one DDL statement per migration there. No provider
claims a rollback it did not perform. The tracking table (`tina4_migration`) is identical
across providers; a legacy tracking schema upgrades in place before state is read.

## Contradictions and defects

### Provisional verdict

**SYNTHESISE, decided on correctness.** Promote Ruby's smaller orchestration
structure, Python's fail-safe rollback rule, and the PHP/Node summary-object
idea. Do not promote any implementation wholesale: each one has either a
contract hole or a materially larger mechanism.

## Owner decisions

Proposed for owner ratification (the measured divergences force each call):

1. One result shape per operation across all four (closing divergence 4): `migrate() ->
   {applied, skipped, failed}`, `rollback() -> {rolledBack, failed}`, `status() ->
   {completed, pending}` as filename strings. This is the breaking change with the widest
   blast radius, because application and CLI code currently observes four shapes.
2. A tracking row is removed ONLY after its down operation succeeds; a missing or failing
   down is a rollback failure that retains the row (Python's fail-safe rule, closing
   divergence 3). This is a correctness decision, not a preference.
3. SQL and native-code migrations participate in identical discovery, numeric ordering,
   status, apply and rollback (closing divergences 1 and 2); Node's created-but-invisible
   `.ts` and Python's `.py`-runs-but-hidden-from-status are bugs, not design.
4. `create()` returns the up-file path only; the caller derives the `.down.sql` sibling
   (closing the Node-only two-path shape).
5. One public name per concept, no aliases (closing divergence 5): remove
   `get_applied_migrations`, the Ruby `run` alias and the legacy function APIs, with a
   Breaking migration note.
6. Overall verdict SYNTHESISE, decided on correctness: adopt Ruby's leaner orchestration
   structure, Python's fail-safe rollback rule and the PHP/Node summary-object result. No
   implementation is promoted wholesale, because each has either a contract hole or a
   materially larger mechanism.

## Proposed conformance fixture

### Contract cases to encode as data

1. SQL create writes an up/down pair and returns the up path.
2. Code create writes one native file which discovery, status, migrate, and
   rollback all recognize.
3. Numeric prefixes apply `9_` before `10_`; unprefixed files sort last and warn.
4. A successful apply records exactly one passed row and a second run skips it.
5. Apply stops at the first failure and does not run later files.
6. A failed multi-statement file does not gain an applied row.
7. Rollback runs a batch in reverse apply order.
8. Missing down fails and retains the applied row.
9. Failing down SQL fails and retains the applied row.
10. Successful down removes the row only after schema reversal succeeds.
11. `status`, `get_applied`, `get_pending`, and `get_files` include SQL and code
    migrations with the same filename semantics.
12. An unknown migration kind raises; `code` and the runtime's documented legacy
    spelling are the only non-SQL values during the breaking transition.
13. Startup auto-migrate degrades on failure; explicit CLI migrate exits non-zero.
14. The same SQL fixture runs with the same outcome on SQLite, PostgreSQL,
    MySQL, MSSQL, and Firebird; any impossible DDL guarantee narrows the public
    contract rather than becoming a provider caveat (ADR-0024).

### Tests to write first

- `a generated code migration is discovered and applied` / `an unknown kind raises`
- `status includes every runnable migration` / `a down file is never pending`
- `rollback removes history after down succeeds` / `missing down retains history`
- `rollback failure retains history` / `later rollbacks do not run after failure`
- `apply stops at the first failure` / `a failed file is never marked applied`
- `startup failure degrades` / `explicit CLI failure exits non-zero`

Each case is mutation-proved and run from one shared
`fixtures/migrations_contract.json` in all four frameworks. SQLite cases run
locally; provider-swap cases run on the .99 lab with zero skips.

## Integration map

- The `Migration` class is exported from each framework's public API and constructed with a
  live database adapter (Feature 3).
- Startup boot calls `migrate()` when `TINA4_AUTO_MIGRATE` is on; the CLI exposes
  `migrate`, `rollback`, `status` and `create` (Python `cli/__init__.py`, PHP `bin/tina4php`,
  Ruby `cli.rb`, Node `packages/cli/src/commands/migrate*.ts`).
- The scaffolder writes migration files into the resolved directory; discovery and the
  numeric-prefix ordering consume them.
- The providers (008-014) execute the DDL and own transaction mechanics; the ORM depends on
  the migrated schema existing.
- Central fixtures, four runners, the CI matrix, release notes and the migrations docs
  update together when the contract lands.

## Breaking changes and migration

### Surface naming rule

Concept names are verb-first. Snake-case languages use `get_applied` and
`get_pending`; camel-case languages use `getApplied` and `getPending`.
`Migration` is PascalCase. There is one public name per concept, with no aliases.

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| construct | `Migration(db, migrations_dir, delimiter)` | `new Migration(db, migrationsDir, delimiter)` | `Migration.new(db, migrations_dir:)` | `new Migration(db, {migrationsDir, delimiter})` |
| apply | `migrate()` | `migrate()` | `migrate()` | `migrate()` |
| rollback | `rollback(steps=1)` | `rollback(steps=1)` | `rollback(steps=1)` | `rollback(steps=1)` |
| status | `status()` | `status()` | `status()` | `status()` |
| create | `create(description, kind="sql")` | `create(description, kind="sql")` | `create(description, kind="sql")` | `create(description, kind="sql")` |
| applied names | `get_applied()` | `getApplied()` | `get_applied()` | `getApplied()` |
| pending names | `get_pending()` | `getPending()` | `get_pending()` | `getPending()` |
| discovered files | `get_files()` | `getFiles()` | `get_files()` | `getFiles()` |

## Implementation backlog

1. Materialize `fixtures/migrations_contract.json` from the 14 cases above and wire four
   fail-closed runners (SQLite locally, provider-swap on the .99 lab, zero skips).
2. Converge the result shapes (decision 1) in all four; update every application/CLI caller.
3. Make code and SQL migrations share one discovery/status/apply/rollback path (decisions 3)
   -- fix Node's invisible `.ts` and Python's `.py`-hidden-from-status.
4. Enforce the fail-safe rollback rule (decision 2) in PHP, Ruby and Node (Python already
   retains the row); prove missing-down and failing-down both retain history.
5. Remove the aliases (decision 5) with the Breaking migration note.
6. Prove the provider-narrowing rule (non-transactional-DDL engines) on the lab across
   SQLite, PostgreSQL, MySQL, MSSQL and Firebird.
7. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit; the above is the build phase.

## Porting capsule

### Canonical pattern to implement

- `migrate()` returns `{applied, skipped, failed}`; `failed` carries migration
  name plus the error, and processing stops at the first failure.
- `rollback(steps=1)` returns `{rolled_back, failed}` and stops at the first
  failure. A missing down implementation is a failure. The tracking row remains
  until down completes.
- `status()` returns `{completed, pending}` using filename strings; detailed
  tracking rows belong to an explicitly named inspection method, not `status`.
- SQL and native-code migrations participate in identical discovery, numeric
  ordering, status, apply, and rollback paths.
- `create(description, kind="sql")` returns the created up path. SQL also
  creates the deterministic sibling `.down.sql`; callers derive it from the up
  path rather than receiving a Node-only second return shape.
- Tracking-table writes and the migration body share the same transaction where
  the engine supports transactional DDL. No provider may claim a rollback it did
  not perform (ADR-0024).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (5 divergences).
- [x] Owner ambiguities recorded (6 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (14 cases).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready: measured (LOC/CC + lab baselines), all contract sections written, 5
divergences recorded, 6 decisions proposed. The IMPLEMENTATION and the shared fixture are
the build phase (backlog above) and are NOT done: this feature is not "shipped" until all
14 cases are proven in all four on the .99 lab with zero skips. Decision-ready is not
built.
