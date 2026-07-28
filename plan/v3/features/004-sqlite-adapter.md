# Feature 4: SQLite adapter

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

**Status: IN PROGRESS.** Python and Ruby verified by execution; PHP and Node not
yet. Written up now because the Python probe found a real bug and the finding
should not sit in a scratch buffer. Do not treat the verdict as final until the
Outstanding section is closed.

## Files

| | path | count |
| --- | --- | --- |
| python | `tina4_python/database/sqlite.py` | 1 |
| php | `Tina4/Database/SQLite3Adapter.php` (541), `PdoSqliteAdapter.php` (163) | 2 |
| ruby | `lib/tina4/drivers/sqlite_driver.rb` | 1 |
| node | `packages/orm/src/adapters/sqlite.ts` | 1 |

## Measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 214 | 20 | 78 | 3.9 | `execute_many` (13) | 23.8 | 4 warn |
| php | 495 | 39 | 114 | 2.92 | - | 19.6 | 1 error, 2 warn |
| ruby | 132 | 20 | 43 | 2.15 | - | 29.3 | 1 warn |
| node | 290 | 38 | 110 | 2.89 | `createTable` (11) | 18.2 | 1 error, 2 warn |

Ruby leads on all three (leanest 132, simplest 2.15, best MI 29.3) at a 3.8x LOC
spread against PHP.

## The 3.8x spread is NOT duplication

The first read of those numbers says PHP has a DRY problem. It does not. PHP's two
adapters are a deliberate **silent PDO fallback family**: `makeSqlite()` prefers
`ext-sqlite3` (the `\SQLite3` class) and falls back to the `pdo_sqlite` driver
when it is absent, raising a named error with install instructions when neither is
there. The same pattern exists for Postgres and Firebird, sharing
`PdoAdapterTrait`, and it has dedicated tests (`PdoFallbackFactoryTest.php`,
`PdoFallbackParityTest.php`).

PHP needs this and the other three do not: a PHP install may ship either
extension, while Python has `sqlite3` in the stdlib, Node has `node:sqlite` built
into the runtime, and Ruby has one canonical `sqlite3` gem. So the extra 163 lines
buy portability that the other runtimes get for free.

Recorded as **DEFER on the size question**, with the reason, so a future reader
does not "simplify" it back into a bug. It is the first row in this audit where a
metric outlier is correct.

## What differs: the write-result contract

Probing the real contract instead of the file size found something else.

**BUG (Python). `db.delete()` declares dict support and raises on it.** Verified
against real SQLite:

```
delete signature: (table: str, filter_sql: str | dict | list = '', params: list = None)

db.delete('t', 'id = ?', [1])   -> ok, affected_rows=1, row gone
db.delete('t', {'id': 2})       -> RAISES OperationalError: unrecognized token: "{"
db.update('t', {'id': 2, ...})  -> ok, affected_rows=1     <- update accepts a dict
```

Three defects in one:

1. The type hint says `str | dict | list`. Passing a dict raises, so the
   annotation is a promise the code does not keep - the dict is interpolated into
   the SQL string rather than translated into a WHERE clause.
2. `update` accepts a dict and `delete` does not, though both take the same shape.
   A caller who learns `update(table, dict)` and reaches for `delete(table, dict)`
   gets a SQL syntax error.
3. `tina4-python/CLAUDE.md` documents `db.delete(table_name, data: dict) ->
   DatabaseResult` - the broken form, as the primary form. First Principle
   violation: the docs describe something the code does not do.

**Ruby does not have it.** `db.delete("t", {"id" => 1})` returns
`affected_rows=1` and the row is gone. So this is drift, not a shared design.

## Outstanding before this row closes

- [ ] PHP: run the same dict-filter delete. First probe failed on `Tina4\Database`
      not being the class name - a probe error of mine, not a finding. Find the
      right entry point and re-run.
- [ ] Node: run the same dict-filter delete.
- [ ] Confirm the `DatabaseResult` write-result shape (`affected_rows` / `last_id`)
      for insert, update and delete in all four. Python returns `DatabaseResult`
      with `affected=1, last_id=1` on insert and `affected=1, last_id=1` on update
      - a `last_id` on an UPDATE is itself worth a look, since the docs say
      `last_id` is set on insert only.
- [ ] Decide whether the dict filter form should exist at all, or whether the
      string-plus-params form is the only one and the annotation plus the doc are
      what is wrong. Both are defensible; the audit must pick one.

## Verdict: PROVISIONAL - PROMOTE ruby on shape, GAP on the delete contract

Decided on **correctness** for the delete contract and **LOC/CC** for the shape.
Ruby's adapter is the leanest and most maintainable of the four and has no
above-threshold function; it is the shape to copy. PHP's two-file count is
correct and stays. Python has a real bug that must be fixed either in the code or
in the annotation-plus-doc, and that decision is the point of the pattern below
once the Outstanding list is closed.

## Pattern (draft, pending the Outstanding decisions)

Surface table for the write path, which is the part in dispute:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| insert | `insert(table, data)` | `insert($table, $data)` | `insert(table, data)` | `insert(table, data)` |
| update | `update(table, data, filter=..., params=...)` | `update($table, $data, $filter, $params)` | `update(table, data, filter, params)` | `update(table, data, filter?, params?)` |
| delete | `delete(table, filter, params=...)` | `delete($table, $filter, $params)` | `delete(table, filter, params)` | `delete(table, filter?, params?)` |

One rule to settle, and it settles the bug: **either every filter argument accepts
both a string-plus-params and a key/value map in all four, or none of them do and
the annotations and docs say so.** Half-support in one framework is the defect.

## Tests to write

Real SQLite files in a temp directory. No mocks; SQLite is the dependency and it
is free to stand up.

| pair | positive | negative |
| --- | --- | --- |
| delete filter forms | `delete_accepts_a_string_filter_with_params` | `delete_does_not_raise_on_the_documented_filter_form` - the exact Python reproduction |
| update/delete symmetry | `update_and_delete_accept_the_same_filter_shapes` | `no_framework_accepts_a_filter_shape_in_update_that_delete_rejects` |
| write result | `insert_returns_a_write_result_with_affected_rows_and_last_id` | `update_does_not_report_a_last_id` (pending the Outstanding check) |
| error behaviour | `a_bad_statement_raises_and_records_the_cause` | `a_bad_statement_never_returns_false` |
| annotation truth | `every_declared_filter_type_is_accepted` - drives off the signature itself | `no_declared_type_raises_when_passed` |

The last pair is the interesting one: it reads the declared parameter types and
asserts each one actually works. That is the test class that would have caught
this bug the day the annotation was widened.

## Parked

Not implemented. Blocked on the Outstanding cross-checks (PHP, Node) and the
owner's decision on the filter-form question.
