# Task: Unify db.insert/update/delete write-result contract on DatabaseResult

## Goal
Make `db.insert()`, `db.update()`, `db.delete()` return a `DatabaseResult` in all
four frameworks (canonical = Python master). Breaking change; owner-approved.

## Decision (owner)
- Canonical return = **DatabaseResult** (Python master). NOT bool.
- Rationale: Python is master and already returns it; Node already returns it
  (aliased `DatabaseWriteResult`); a rich result is strictly more useful
  (last_id + affected_rows + error) and stays TRUTHY so `if (insert)` still works.
- This session implements. Spawned session task_ca02d5a4 must be discarded.

## Current state (verified against source)
| FW | insert/update/delete returns | Action |
|----|------------------------------|--------|
| Python (master) | DatabaseResult (records,count,affected_rows,last_id,error,sql) | none |
| Node | DatabaseResult (imported as alias DatabaseWriteResult) | none (verify + doc) |
| PHP | bool (always; never DatabaseResult in history) | CHANGE |
| Ruby | Hash {success,last_id} single / DatabaseResult batch / {success} upd+del | CHANGE |

Key facts:
- PHP `Tina4\Database\DatabaseResult` has records/columns/count/limit/offset but
  NO affected_rows/last_id/error fields -> add them (parity with Python).
- PHP `affectedRows()` is on 5 core adapters (SQLite3/Postgres/MySQL/MSSQL/Firebird)
  but NOT on the interface nor on PdoSqlite/PdoPostgres/PdoFirebird/ODBC/Mongo ->
  wrapper reads it best-effort (`method_exists`), 0 when unavailable.
- PHP `ORM::save()` calls `$this->insert()` (ORM method), NOT `$db->insert()` — so
  the wrapper change does NOT affect ORM.save. Direct `$db->insert()` callers only.
- Ruby `Tina4::DatabaseResult.new(records, affected_rows:, last_id:)` already exists.
  Ruby `ORM.save` reads `db.get_last_id` separately (line ~780), NOT insert's return.

## Scope
### PHP
- [ ] Add `affectedRows:int`, `lastId:int|string|null`, `error:?string` fields +
      ctor params to `Tina4\Database\DatabaseResult` (additive; keep existing).
- [ ] Widen `DatabaseAdapter` insert/update/delete return to `bool|DatabaseResult`.
- [ ] `Database::insert/insertBatch/update/delete` build + return DatabaseResult
      (lastId via getLastId on insert; affectedRows best-effort from adapter).
- [ ] `CachedDatabase` insert/update/delete return type widen + pass through.
- [ ] Sweep tests for `=== true/false` / assertSame(true,...) on these (truthy
      object still passes assertTrue()); fix only real breakage.
- [ ] Lock-in test (pos+neg): returns DatabaseResult; ->lastId set on insert;
      truthy; raises (not falsy) on bad SQL.
- [ ] Update tina4-php/CLAUDE.md.
- [ ] Full phpunit green (real SQLite; no mocks).

### Ruby
- [ ] `database.rb` insert (single + PG driver path) / update / delete return
      `Tina4::DatabaseResult` (affected_rows + last_id). Batch already does.
- [ ] Confirm ORM.save unaffected (uses get_last_id).
- [ ] Sweep specs for `[:success]`/`[:last_id]` Hash access on these returns.
- [ ] Lock-in spec (pos+neg).
- [ ] Update tina4-ruby/CLAUDE.md (revert the "Hash" doc I just added -> DatabaseResult).
- [ ] Full rspec green.

### Node
- [ ] Verify DatabaseResult (alias) already carries affected_rows/last_id; doc note only.

### Docs + release
- [ ] tina4-documentation + book: db write returns DatabaseResult (all 4).
- [ ] "Breaking:" changelog entry + migration note (bool/Hash -> DatabaseResult;
      still truthy; read ->lastId / .last_id instead of the old shape).
- [ ] Cross-framework live parity check.

## Bugs
- Ruby ORM.save read result[:last_id] (Hash) to set the auto-inc PK — the ONE
  internal consumer of the insert return; broke when insert became DatabaseResult
  (PK never set -> auto_crud/seeder/realtime spec cascade). Fixed: result.last_id.

## Commits (all on v3, local, not pushed)
- PHP  81e0104c  foundation: DatabaseResult write fields + widened adapter contract
- PHP  476747b7  insert/update/delete -> DatabaseResult (Breaking); full phpunit green (3990)
- Ruby e4f636b   insert/update/delete -> DatabaseResult (Breaking) + orm.rb PK fix; full rspec green (4136)
- (Python master + Node already returned DatabaseResult — no code change)

## Docs + changelog (local commits, not pushed)
- tina4-documentation 722df7c: 05-database.md "What they return" note (PHP/Ruby/Node)
  + Python troubleshooting tighten; 36-releases.md Unreleased entry x4 (PHP/Ruby
  Breaking + migration; Python/Node consistency note). pnpm docs:build GREEN (61.7s).
- tina4-book 16d6d0d: Unreleased entry x4 books (mirror).
- Owner assigns the version (heading "Unreleased") + pushes docs main at release.

## RESOLVED parity gap (Node field-name divergence):
## Node returned a result OBJECT but its two fields were rowsAffected / lastInsertId,
## diverging from Python/PHP/Ruby (affected_rows|affectedRows / last_id|lastId).
## Owner chose RENAME over accept (2026-07-24). Landed:
## - Node code c19abd7 (v3): rowsAffected -> affectedRows, lastInsertId -> lastId
##   (DatabaseResult field + executeMany return field). Driver-native lastInsertRowid
##   / insertId, the lastInsertId() METHOD, and _lastInsertId private var UNCHANGED.
##   ORM baseModel.save() reads db.lastInsertId() (method), id path unaffected.
##   Full test/run-all.ts green 5711/0 + typecheck.
## - Docs: tina4-documentation e41b157 + tina4-book 4a16a08 (Breaking rename entry).
## All four now agree on BOTH the object return and the field names.

## Status: CODE + DOCS + CHANGELOG DONE for all 4 (all local, not pushed).
## Remaining: version assignment + push docs main at release (owner); optional
## cross-framework live parity check.
