# Feature 014: Migrations

## Identity and status

- Matrix identity: 14 — Migrations
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

## Why this feature exists

An engineer needs one migration surface that creates, applies, inspects and
rolls back database changes in the same order on every Tina4 language.

## Boundary

Feature 14 owns SQL and code migrations, discovery and ordering, the tracking
table, apply/status/rollback, startup auto-migration and the public `Migration`
surface. Database providers own connection and transaction mechanics.

The live feature matrix retired rows 21-26 into database-adapter group 4.
Feature 14 is therefore the next standalone migration feature.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

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

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

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

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

### Persisted contract

The tracking table remains `tina4_migration` with canonical columns
`id`, `migration_name`, `description`, `batch`, `executed_at`, and `passed`.
A migration is applied iff one row with `passed = 1` exists for its canonical
filename/stem. A failed apply or rollback never writes a successful state.
Legacy tracking schemas upgrade in place before state is read.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

### Provisional verdict

**SYNTHESISE, decided on correctness.** Promote Ruby's smaller orchestration
structure, Python's fail-safe rollback rule, and the PHP/Node summary-object
idea. Do not promote any implementation wholesale: each one has either a
contract hole or a materially larger mechanism.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

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

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

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

The audit has not yet produced a dependency-ordered backlog for all current languages and future ports.

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

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

### State

Audit measured and provisional contract written. Implementation and the shared
fixture are not yet complete; this row must not be marked closed until all
cases are proven in all four on the lab.
