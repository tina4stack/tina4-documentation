# Task: tina4-python#93 - legacy NOT NULL migration_id wedges every migration

## Goal
A pending migration must apply on a `tina4_migration` table created by tina4-python
v3 <= 3.13.54, where `migration_id` is `NOT NULL UNIQUE` and the bookkeeping insert
never wrote it.

## Context
Reported 2026-07-16 by justin-k-bruce against 3.13.75, from a production app on
PostgreSQL 16. Severity HIGH: the migration's own SQL runs, the bookkeeping INSERT
dies on a not-null violation, the file's transaction rolls back, and NO further
migration can ever apply to that database. Fresh databases get the v3 shape (no
`migration_id`), which is why CI and new projects never saw it - it only bites
long-lived staging/production databases. Shipping since 3.13.55 (the rename).

The 3.13.55 rename added `migration_name` and deliberately left `migration_id` in
place, commented "harmless, ignored from now on". It is ignorable on READS but NOT
on WRITES - it is NOT NULL there.

## Reproduced live (me, real PostgreSQL 16, on shipped 3.13.75)
| legacy shape | stock 3.13.75 | with fix |
|---|---|---|
| old_v3 (migration_id NOT NULL, no migration_name) | FAIL not-null | PASS |
| old_v3_compat (both cols, migration_id still NOT NULL) | FAIL not-null | PASS |
| fresh_v3 (canonical) | PASS | PASS |
| v2 | PASS | PASS |
Matches the reporter's matrix exactly. Their analysis was correct on every point.

## Root cause / design
Fix must NOT live in the rename branch (`if migration_id in cols and migration_name
not in cols`) - that fires once, on a table the new runner has not touched. A database
that already ran the compat path has BOTH columns and still has the NOT NULL. That is
the real production case (old_v3_compat), and a fix there would never reach it.
`ALTER ... DROP NOT NULL` is wrong upstream: not portable (SQLite cannot drop it
without a table rebuild; MySQL spells it MODIFY). The insert-side fix needs no DDL.

## Parity finding (the reverse of usual)
PHP was ALREADY correct - `Migration::recordMigration()` builds the insert from the
columns actually present and populates legacy ones so their NOT NULL/PK constraints
stay satisfied. The reporter independently reinvented PHP's shipped design. So the
fix is to converge Python (master) onto PHP, not the other way around.

| framework | before | action |
|---|---|---|
| Python | BROKEN (proven live) - hardcoded insert + it created migration_id | FIXED: column-driven insert |
| PHP | CORRECT - column-driven, populates legacy cols | none (verified: 51 tests, 193 assertions OK) |
| Ruby | latent - hardcoded insert, never created migration_id | HARDENED (same design) |
| Node | latent - hardcoded insert, never created migration_id | HARDENED (same design) |

Ruby/Node exposure is only via a database whose tracking table came from
tina4-python. Only the BOTH-columns shape is reachable there: neither has a
python-legacy rename path, so a migration_id-only table fails on the READ
(`no such column: migration_name`) before bookkeeping. Adding that rename path is a
separate question, deliberately NOT done here.

## Why our tests missed it
`tests/test_issue_115_v2_upgrade.py::test_old_v3_migration_id_column_renamed_to_migration_name`
uses the EXACT broken shape but asserts `ran == []` - an already-applied migration
that must NOT re-run. So `_record_applied` is never called and the INSERT path is
never exercised on the legacy shape. It tested the READ side; the WRITE side (a
PENDING migration on a legacy table = the production case) was untested.
Same family as the 3.13.67 "registration-only test hid it" lesson.

## Scope
- [x] Reproduce live on real PostgreSQL 16 (all 4 legacy shapes)
- [x] Python master: column-driven `_record_applied` + honest comment on the rename path
- [x] Python: lock-in tests (pos + neg + control) - 3/4 FAIL against old code, control passes both
- [x] Ruby: harden + spec (real SQLite)
- [x] Node: harden + test (real SQLite)
- [x] PHP: verify already-correct (no change)
- [x] Independent verify: re-run each full suite myself
- [x] Release 3.13.76 + comment on #93 (commented, left open for the reporter to close)

## Bugs found while fixing
- [x] MY OWN: the Node helper first called `db.getColumns()` - the DatabaseAdapter
      contract is `columns()`. The hardening would have been a SILENT NO-OP. Caught
      only because the test hits a real SQLite adapter. (no-mock earns its keep)
- [x] MY OWN (test): assumed Ruby stores the migration stem like Python. Ruby stores
      the FILENAME (`000001_smoke.sql`); Python stores the stem (`000001_smoke`).
      Pre-existing cross-framework difference in the stored value - noted, not in scope.

## Verification (re-run by me, macOS)
- Python 3499 passed / 0 failed (was 3495 + 4 new) - pytest
- PHP 51 tests, 193 assertions OK - MigrationV3 + Issue115 + MigrationPassedColumn
- Ruby: migration_v3 specs 2/2; full rspec (see below)
- Node: migrationLegacyColumn 2/2 + typecheck clean; full run-all (see below)
- Live PostgreSQL 16 repro: 4/4 shapes PASS after fix

## Commits
- python  e6c12cd fix + tests, 0e6976d release
- ruby    2997ce0 fix + spec,  eb9479a release
- node    29242e6 fix + test,  8673e93 release
- php     56b66bd9 release only (code already correct)
- docs 24be81e / book 2cba841 / CLI fe2172e

## Status: SHIPPED 3.13.76 (2026-07-16) - all 4 registries live; #93 commented, left open

## Honest verification caveat
Node full suite: 5367 passed, 18 failed - ALL in sessionHandlers.test, which needs a
live Mongo/Redis/Valkey. Docker was down on this machine (no mongod on 27017). Proven
NOT mine: 18 failures both WITH and WITHOUT the fix, and sessionHandlers.test has zero
references to migration code. CI provisions those services. Qualified claim: verified on
macOS / PostgreSQL 16 / real SQLite; the session-backend paths were not exercised locally.
