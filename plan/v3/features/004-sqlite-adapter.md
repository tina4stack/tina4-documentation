# Feature 4: SQLite adapter (and the write-path contract)

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

**Status: CLOSED.** All four frameworks verified by execution against real SQLite.

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

Ruby leads all three (leanest 132, simplest 2.15, best MI 29.3), 3.8x spread.

## The 3.8x spread is correct, not duplication (category 2: runtime tax)

PHP's two adapters are a deliberate **silent PDO fallback family**: `makeSqlite()`
prefers `ext-sqlite3` (the `\SQLite3` class), falls back to the `pdo_sqlite` driver
when it is absent, and raises a named error with install instructions when neither
is present. The same shape exists for Postgres and Firebird via `PdoAdapterTrait`,
with dedicated tests (`PdoFallbackFactoryTest.php`, `PdoFallbackParityTest.php`).

PHP needs it and the other three do not: a PHP install may ship either extension,
while Python has stdlib `sqlite3`, Node has `node:sqlite` in the runtime, and Ruby
has one canonical `sqlite3` gem. Those extra 163 lines buy portability the other
runtimes get free.

**DEFER, with the reason recorded** so a future reader does not "simplify" it back
into a bug. First row in this audit where a metric outlier is right.

## The real finding: one call, four semantics

Measuring the adapter's size found nothing. Probing its write contract found the
most serious divergence in the audit so far. Two rows in a table, then
`update(table, data)` with no explicit filter:

| framework | affected | rows changed | semantics |
| --- | --- | --- | --- |
| python | 1 | 1 | **keyed update** - takes `id` out of the data and uses it as the WHERE |
| php | 2 | **2** | **full-table update** |
| ruby | 2 | **2** | **full-table update** |
| node | 0 | **0** | **silent no-op** |

Three distinct behaviours, each dangerous in a different way:

- **PHP and Ruby silently overwrite every row.** `db.update('users', ['name' =>
  $name])` sets that name on the whole table and reports success. In my probe the
  PK-carrying variant only failed because SQLite raised a UNIQUE violation trying
  to set `id=1` on two rows - the constraint saved the test, not the framework.
- **Node silently does nothing.** `affected=0`, both rows untouched, no error. A
  caller who does not read `affectedRows` believes the write landed.
- **Python does what a developer expects** and is the only one of the four that
  does.

`delete()` splits differently:

| call | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `delete(table, {pk: 1})` | **RAISES** `unrecognized token: "{"` | ok, affected=1 | ok, affected=1 | ok, affected=1 |
| `delete(table, 'id = ?', [1])` | ok, affected=1 | ok | ok | ok |
| `delete(table)` no filter | - | **deletes every row**, silently | - | - |

Python's `delete` declares `filter_sql: str | dict | list` and raises on a dict -
the annotation promises what the code refuses, the dict lands in the SQL string
verbatim. Worse, `tina4-python/CLAUDE.md` documents `db.delete(table_name, data:
dict)` as THE calling form: the docs describe the broken path. First Principle
violation.

And Python's own two verbs disagree: `update(table, dict)` treats the dict as data
plus a keyed filter; `delete(table, dict)` raises.

**Why this matters more than its size.** A developer writing the same feature
twice, or a doc example written once for all four, produces silent data loss on
two frameworks and a silent no-op on a third. Nothing logs. Nothing raises. The
only signal is `affected_rows`, and the four do not agree on what it means.

## Verdict: SYNTHESISE, and it is a P1

Decided on **correctness**, decisively. No framework is right on all three points:
Python has the only correct `update` and the only broken `delete`; PHP and Ruby
have the correct `delete` and a destructive `update`; Node has the correct
`delete` and an `update` that does nothing.

Category 4 (genuine drift) on every point. Nothing here is a runtime limitation -
every framework can express a keyed WHERE and every framework can raise.

## Pattern

**A write with no filter is an error, not a full-table operation.**

That single rule kills the data-loss class outright. Three sub-rules:

1. **`update(table, data)` extracts the primary key from `data` and uses it as the
   filter** (Python's behaviour, promoted). If `data` carries no primary key AND no
   explicit filter is given, **raise** a named error: "update requires a filter or
   a primary key in the data; pass `filter` explicitly to update multiple rows."
2. **`delete(table)` with no filter raises** the same way. Deleting a whole table
   is a real thing to want; it must be spelled `delete(table, '1=1')` or a
   dedicated `truncate(table)`, never the accidental default.
3. **Every filter argument accepts both forms in all four**: a key/value map, or a
   string plus params. Python's dict support becomes real rather than declared.
   Half-support is the defect, and the annotation must not exceed the code.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| insert | `insert(table, data)` | `insert($table, $data)` | `insert(table, data)` | `insert(table, data)` |
| update | `update(table, data, filter=None, params=None)` | `update($table, $data, $filter = null, $params = [])` | `update(table, data, filter = nil, params = nil)` | `update(table, data, filter?, params?)` |
| delete | `delete(table, filter, params=None)` | `delete($table, $filter, $params = [])` | `delete(table, filter, params = nil)` | `delete(table, filter, params?)` |
| truncate | `truncate(table)` | `truncate($table)` | `truncate(table)` | `truncate(table)` |

Note `filter` is no longer defaulted to `''` on `delete` - it is required. That is
the breaking change that removes the footgun.

Write-result contract, to settle the remaining inconsistency: `insert` sets
`last_id`; `update` and `delete` do not (PHP already does this correctly via
`writeResult($adapter, withLastId: false)`; Python currently reports a `last_id` on
an UPDATE, which its own docs say is insert-only).

## Methodology

1. Write the tests below in all four. Confirm each framework fails the ones it
   should: PHP and Ruby on full-table update, Node on the no-op, Python on the
   dict delete and the UPDATE `last_id`.
2. **Python first.** It already has the correct `update` semantics, so it is the
   reference for rule 1; the work is fixing its `delete` to honour the declared
   dict, and dropping `last_id` from update/delete.
3. Ruby second (leanest adapter, fastest signal), then Node, then PHP.
4. Each framework: add the no-filter raise, make both filter forms work, add
   `truncate`.
5. Fix `tina4-python/CLAUDE.md` (documents the broken dict form) and audit the
   other three CLAUDE.md files plus the docs site for the same claim.
6. Re-run all four suites. A full-table update in an existing test is a caller
   relying on the footgun - each one is a finding, fix the caller.

## Tests to write

Real SQLite files in a temp directory; SQLite is free to stand up, so no mocks.

| pair | positive | negative |
| --- | --- | --- |
| keyed update | `update_with_a_primary_key_in_data_updates_only_that_row` | `update_without_a_filter_or_primary_key_raises` - kills the PHP/Ruby full-table path |
| no silent no-op | `update_reports_the_rows_it_changed` | `update_never_reports_zero_when_a_matching_row_exists` - kills the Node path |
| delete filter forms | `delete_accepts_a_key_value_filter`, `delete_accepts_a_string_filter_with_params` | `delete_does_not_raise_on_a_key_value_filter` - the exact Python reproduction |
| no accidental truncate | `truncate_removes_every_row` | `delete_without_a_filter_raises` |
| verb symmetry | `update_and_delete_accept_the_same_filter_shapes` | `no_verb_accepts_a_filter_shape_another_verb_rejects` |
| write result | `insert_reports_a_last_id` | `update_and_delete_do_not_report_a_last_id` |
| annotation truth | `every_declared_filter_type_is_accepted` - reads the declared types and exercises each | `no_declared_type_raises_when_passed` |
| error behaviour | `a_bad_statement_raises_and_records_the_cause` | `a_bad_statement_never_returns_false` |

The annotation-truth pair is the one that would have caught the Python bug the day
the type hint was widened. The no-filter pair is the one that matters in
production.

## Risks

- **Rules 1 and 2 are breaking in all four.** Any caller relying on a filterless
  `update` or `delete` starts raising. That is the point, and it needs a
  `Breaking:` changelog entry with the migration: pass an explicit filter, or call
  `truncate()`.
- **Existing tests may encode the footgun.** Expect red tests that are the bug, not
  the fix; each is a caller to correct.
- **Node's no-op is the quietest and likeliest to be depended on** by code that
  never checked `affectedRows`.

## Parked

Not implemented. Recommend P1 in the implementation queue, behind feature 6 only
because feature 6 is already sequenced first - this one is a silent data-loss
class and outranks everything else found so far.
