# Task: make write_path_contract.json drive all four write-path runners

## Goal

Turn `write_path_contract.json` from an orphaned file nothing read into the single
source of truth every write-path runner executes, so all four frameworks run the
SAME case list against the SAME answer key.

## Context

`write_path_contract.json` shipped in all four repos and **nothing loaded it**
(`grep -rl write_path_contract` returned zero non-JSON consumers in python, php and
node; ruby matched only on its own filename string). Its two sibling fixtures ARE
consumed by their runners in all four -- `adapter_contract.json` and
`batch_write_contract.json` -- so this one had drifted from an established pattern.

Because the four write-path runners were hand-written independently they had
DIFFERENT case counts (Python 17, Ruby 16, PHP 15, Node 14) and divergent names.
That is not cosmetic: the fixture declared a case
`a_string_filter_with_params_works_the_same_as_a_hash_filter` that NO runner
executed, and that is exactly how a shipped bug survived -- Node's
postgres/mysql/mssql/firebird adapters walked a string filter with `Object.keys()`,
so `Object.keys("1 = 1")` yielded `["0","1",...]` and `db.truncate()` was broken
outright on all four engines. It was found via truncate, not via the contract case
written to cover it.

## Scope

- [x] Extend the fixture with everything the hand-written runners covered but the
      fixture did not (rather than dropping those cases)
- [x] Put the table DDL in the fixture so all four create literally the same tables
- [x] Rewrite the Python runner as a fixture interpreter
- [x] Rewrite the PHP runner as a fixture interpreter
- [x] Rewrite the Ruby runner as a fixture interpreter
- [x] Rewrite the Node runner as a fixture interpreter
- [x] Add an ORPHAN GUARD to each runner: a case naming an unimplemented op FAILS,
      never silently skips (silent skipping is how the fixture went unread)
- [x] Verify against LIVE PostgreSQL, MySQL and MSSQL -- not SQLite alone
- [x] Fix every bug the newly-executed cases exposed

## Fixture growth: 15 -> 22 cases

Nothing was dropped. Cases added to cover what only the hand-written runners had,
plus what the newly-live composite table exposed:

| Added case | Why |
|---|---|
| `a_string_filter_with_params_updates_the_same_rows_as_a_hash_filter` | the fixture only had the string form for DELETE |
| `truncate_removes_every_row` | only in hand-written runners; it is the method that walks a raw string filter |
| `the_primary_key_is_introspected_rather_than_assumed` | only in PHP/Ruby/Node |
| `a_composite_primary_key_reports_every_key_column` | only in hand-written runners |
| `delete_accepts_a_full_composite_key` | only in Python/Ruby |
| `delete_with_a_blank_string_filter_raises` | found during this work (see Bugs) |
| `update_with_a_blank_string_filter_and_no_primary_key_raises` | the update half of the same property |
| `last_id_is_null` on existing update/delete cases | replaced a near-duplicate hand-written case |
| `rows_after` + `unchanged` on the error cases | proves the failed write wrote NOTHING -- the data-loss property |

Composite-key cases previously ran on a hardcoded SQLite file in ALL FOUR runners.
They now run on whatever engine the run targets.

## Parity

| Runner | SQLite | PostgreSQL | MySQL | MSSQL |
|---|---|---|---|---|
| Python `tests/test_write_path_contract.py` | ✅ | ✅ | ✅ | ✅ |
| PHP `tests/WritePathContractTest.php` | ✅ | ✅ | ✅ | ✅ |
| Ruby `spec/write_path_contract_spec.rb` | ✅ | ✅ | ✅ | ✅ |
| Node `test/writePathContract.test.ts` | ✅ | ✅ | ✅ | ✅ |

All four execute the same 22 cases. Counts differ only by each runner's own meta
tests (Python 24 local / 46 when a live engine is added to the SQLite baseline,
PHP 24, Ruby 24, Node 23).

## Bugs found by making the fixture executable

- [x] **Python MSSQL: a committed transaction never released its locks.**
      `MSSQLAdapter.start_transaction()` issued a raw `BEGIN TRANSACTION` on a
      pymssql connection already opened with `autocommit=False`, so `@@TRANCOUNT`
      became 2; `commit()` calls the driver's commit, which emits ONE `COMMIT`,
      taking it 2 -> 1. The transaction stayed open, holding its exclusive lock,
      while the connection went idle. Proof: a sleeping session with
      `open_transaction_count = 2` blocking a second connection's SELECT on
      `LCK_M_S` indefinitely. The write is visible on its OWN connection, so
      nothing looks wrong locally -- it only shows up when another connection
      reads. PHP (`sqlsrv_begin_transaction`/PDO), Ruby (balanced raw
      BEGIN/COMMIT on an autocommit TinyTDS connection) and Node (tedious'
      native `beginTransaction`, with a comment warning about exactly this) were
      all correct; Python was the sole outlier. Fixed by removing the raw BEGIN --
      suppressing the per-statement autocommit is what makes the statements one
      transaction.
- [x] **Node: `CachedDatabaseAdapter.update()`/`delete()` dropped `params`.**
      This wrapper sits in front of EVERY adapter, so a string filter arrived
      unbound: `delete(t, "id = ?", [2])` reached the adapter as
      `delete(t, "id = ?")`, ran `DELETE ... WHERE id = ?` with nothing bound,
      matched no row, and returned `{ success: true, affectedRows: 0 }` -- a
      SILENT no-op on a documented calling form. The async variants had the same
      hole in their sync-adapter fallback.
- [x] **Node: the SQLite adapter's `update()` had no string-filter branch.**
      Its own `delete()` had one, and 3.13.94 added one to postgres/mysql/mssql/
      firebird `update()`, but SQLite -- the DEFAULT engine -- was missed.
      `Object.keys("id = ?")` produced `WHERE "0" = ? AND "1" = ?`.
- [x] **Node: a blank string filter bypassed the filterless-delete guard.**
      The guard skipped its emptiness test for anything typed string, so
      `delete(t, "")` fell through to the adapter, which renders an empty WHERE
      as `DELETE FROM t` -- a silent whole-table delete through the one method
      that exists to make that impossible. Python, PHP and Ruby already raised.
- [x] **Node: `update`/`delete` public types forbade the documented string
      filter.** The bodies and adapters handled strings; the TypeScript
      signatures said `Record<string, unknown>` only, so the form documented in
      all four was not expressible in TS.

## Known drift (not fixed here)

- The `CLAUDE.md` for Python and Ruby documents `primary_key(table) -> str | None`.
  It actually returns a LIST in all four (PHP and Node already say `array` /
  `string[]`), and the composite-key contract depends on the list. Doc-only fix,
  separate change.
- `tests/test_batch_insert.py` reads `TINA4_TEST_MSSQL_USER` / `_PASS` while every
  other Python suite reads `_USERNAME` / `_PASSWORD`. Pre-existing env-name
  inconsistency; unrelated to this work.

## Status: Complete
