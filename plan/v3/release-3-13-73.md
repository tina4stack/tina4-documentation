# Release 3.13.73 - migration re-runnable fix (b)

## Goal

Make a previously-failed migration re-apply cleanly on the next `migrate()`, at
full cross-framework parity, with real (no-mock) lock-in tests. One coordinated
all-4 release. Owner directive: "Do b, then release."

## Context

The `tina4_migration` bookkeeping table has canonical columns
`id, migration_name (NOT NULL UNIQUE), description, batch, executed_at,
passed (INTEGER NOT NULL DEFAULT 1)`. "Applied" == a row with `passed = 1`.
`migrate()` writes only `passed = 1`; a failure rolls the file's txn back and
writes no row. But the public record-migration API can write a `passed = 0` row,
and the v2->v3 upgrade can carry one over.

THE BUG (identical in all 4): re-running a migration that has a leftover
`passed = 0` row for the same `migration_name` collided on the UNIQUE
`migration_name` when the success path INSERTed the fresh `passed = 1` row -
the previously-failed migration WEDGED (raised) instead of re-applying. The
migration workers empirically found and characterized this in the Python master
too, which surfaced the (a)/(b) design question the owner decided with "Do b".

THE FIX (b) - delete-before-insert: the record-applied path DELETEs any existing
row for the `migration_name` before writing the fresh `passed = 1` row, so a
stale `passed = 0` row (a prior failure or a v2 carry-over) is superseded instead
of colliding. DELETE + INSERT is portable across every engine (no UPSERT dialect
variance). Invariant: the bookkeeping table holds at most one row per
`migration_name` with its latest state. Python is master; PHP/Ruby/Node mirror.

---

## A. Source fix - delete-before-insert (ALL 4, Python master)

- [x] Python master: `runner.py` new `_record_applied()` helper (DELETE then
      engine-aware INSERT); both `_migrate()` success path and
      `Migration.record_migration()` route through it. v2->v3 warning reworded
      ("will re-apply on the next migrate").
- [x] PHP: single INSERT site is `recordMigration()` (Migration.php); added
      delete-before-insert at the top; Firebird GEN_ID path intact; v2->v3 note reworded.
- [x] Ruby: `_record_migration` calls `_remove_migration_record(name)` before the
      INSERT (both paths route through it); txn-pinned so delete+insert commit as one.
- [x] Node: single `recordApplied(db, name, batch, passed=1)` helper (DELETE then
      awaited INSERT, Firebird branch preserved); both `recordMigration()` and the
      `migrate()` success path route through it inside the open transaction.

## B. Lock-in test flip - scenario 3 (ALL 4, real SQLite, no mocks)

Flip the (a) wedge-characterization ("re-run RAISES on the UNIQUE collision")
to a POSITIVE clean-re-run assertion: record passed=0 for a file on disk; assert
NOT applied / pending; run migrate(); assert it applies cleanly (table created,
reported ran); assert exactly ONE row remains with passed=1 (stale superseded);
assert now applied and no longer pending.

- [x] Python: `tests/test_migration_passed_column.py` scenario 3 flipped. 4/4 pass.
- [x] PHP: `tests/MigrationPassedColumnTest.php` scenario 3 flipped. 4 tests/40 assertions.
- [x] Ruby: `spec/migration_passed_column_spec.rb` scenario 3 flipped. 3 examples/0 fail.
- [x] Node: `test/migrationPassedColumn.test.ts` case 3 flipped. 45 passed.

## C. Docs (b) revision

- [x] Python package CLAUDE.md migration section: "must be cleared" -> "re-applies
      cleanly (delete-before-insert supersedes)".
- [x] PHP/Ruby/Node CLAUDE.md migration section (workers, mirror).
- [x] docs-site `docs/python/37-upgrading-from-v2.md` + `docs/php/37-upgrading-from-v2.md`:
      passed=0 carry-over re-applies cleanly (was "review before relying").
- [x] docs-site `docs/{python,php,ruby,nodejs}/05-database.md`: (a)-work `passed=1`
      semantics accurate under (b), no change needed. README churn reverted.

## Parity
| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| source fix | master | mirror | mirror | mirror |
| test flip | done | done | done | done |
| CLAUDE.md | done | done | done | done |

## Verified test counts (independent re-run at HEAD, no mocks)
- Python: full 3510 passed / 111 skipped; migration subset 100 passed (my run).
- PHP: full 2878 tests / 0 failures (worker); targeted 4 tests / 40 assertions (my re-run).
- Ruby: full 3882 / 0 fail / 84 pending PG-MSSQL-gated (worker); targeted 3 (my re-run).
- Node: full 5422 passed / 9 Valkey-infra-gated (worker); targeted 45 (my re-run).

## Also riding this release
- [x] nodejs#32 (ORM /orm subpath): gallery specifiers `@tina4/core`->`tina4-nodejs`,
      `@tina4/orm`->`tina4-nodejs/orm`, missing `await initDatabase` in 3 db-gallery
      files, `test/packInstall.test.ts` lock-in. Committed 3209403 (unpushed).

## Out of scope (flagged separately, NOT in 3.13.73)
- DevAdmin.php connection-tester `getDatabase()`->`getTables()` (PHP-only dev-admin
  0-tables bug, sibling of #164). Needs its own lock-in test. Spawned as a task.

## Cross-cutting / release mechanics (WAVE at the end)
- [ ] Version bump 3.13.73 (Python pyproject + CLAUDE count/version, Ruby version.rb,
      Node 6x package.json; PHP tag-driven + CLAUDE header/footer consistency).
- [ ] Release notes: docs/<lang>/36-releases.md x4 + book x4 (content-writer, ASCII, no em dash).
- [ ] Independent verification: re-run full suites myself at HEAD (no mocks); re-read diffs.
- [ ] Consolidated commit per repo (exclude Python mailbox/log junk + README case-collision).
- [ ] Merge local to v3 x4 (already on v3), tag 3.13.73, publish, verify registries live.
- [ ] pnpm docs:build + audit-truth --strict GREEN before push docs + book.
- [ ] Comment on #129 / #172 / nodejs#32 (reporters close). install-skills NOT bumped (no skill change).

## Commits (all pushed)
- tina4-python  v3 7911ce5 + tag 3.13.73
- tina4-php     v3 6748b8ef + tag 3.13.73
- tina4-ruby    v3 74d6239 + tag 3.13.73
- tina4-nodejs  v3 6185768 (atop 3209403 #32) + tag 3.13.73
- tina4-documentation main 77fa95e (docs build + audit-truth --strict green)
- tina4-book    main e8aaf13

## Status: SHIPPED 3.13.73 (2026-07-13)
Tag pushed on all 4; CI publishing. Registry check #1: npm 3.13.73 LIVE, RubyGems
3.13.73 LIVE, PyPI + Packagist still 3.13.72 (async lag - re-verify). Docs + book
pushed to main (Jenkins deploys tina4.com). tina4-js + CLI: NO release (backend-only
fix). install-skills: NOT bumped (no skill change). Comment on php#129 / php#172 /
nodejs#32 (reporters close). DevAdmin getTables fix flagged as separate task (out of scope).
