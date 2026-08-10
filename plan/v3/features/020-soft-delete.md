# Feature 020: Soft delete

## Identity and status

- Matrix identity: 20 - Soft delete (is_deleted, restore, withTrashed) -- the matrix row
  title says `deleted_at`, which is WRONG in all four; the column is `is_deleted` (see D1)
- Audit state: decision-ready
- Audit note: measured 2026-07-28, all four verified by execution against real SQLite; prose
  sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (the verbs live there), Feature 15 migrations and
  Feature 7 SQL translator (where `create_table` emits the engine-aware column)
- Dependants: any model that declares soft delete and calls `delete()`/`restore()`/
  `with_trashed()`; the feature matrix, the docs site and the four skills (which carry the
  stale `deleted_at` name)
- Existing ADRs: the loud-failure rule (Feature 4/5 - never convert a raise into silent data
  loss); this feature's fix depends on the Feature 7 translator and the create_table split
- Shared fixtures: `soft_delete_contract.json` is required (real SQLite; the bug reproduces
  in a two-line model)

## Why this feature exists

A developer marks a row deleted without removing it, so it disappears from ordinary reads
but stays recoverable through `restore()` and visible through `with_trashed()`. Today the
column the flag requires is never created by `create_table()`, so the first `delete()` on a
soft-delete model raises in all four -- the feature is declared, documented, and dead on the
code-first path.

## Boundary

This feature owns the soft-delete flag, the emission of the `is_deleted` column from every
table-creating path, the `delete`/`force_delete`/`restore`/`with_trashed` verbs, and the
read-filtering that hides flagged rows. It DELEGATES the DDL emission to `create_table`
(Feature 15/16) and the engine-aware column type to the Feature 7 translator. It does NOT own
the raw delete SQL (Feature 5).

## Existing implementation evidence

| Evidence (verified by execution vs real SQLite) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `create_table()` emits `is_deleted` | NO | NO | NO | NO |
| First `delete()` on a soft-delete model | raises `no such column: is_deleted` | raises | raises | raises |
| Row after the failed delete | untouched (no data loss) | untouched | untouched | untouched |
| Schema-sync path (`syncModels`) adds it | - | - | - | YES (documented) |
| Column name | `is_deleted` (24 mentions) | `is_deleted` (19) | `is_deleted` via `soft_delete_field` | `is_deleted` (22) |
| `deleted_at` mentions | 0 | 0 | 0 | 0 |
| Configurable field name | no (hardcoded) | no | YES (`soft_delete_field`) | no |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 2. **Planning only.**

**Status: CLOSED. All four verified** by execution against real SQLite. The PHP
outstanding item is resolved - it fails the same way.

### The row's name in the matrix is wrong

`01-FEATURE-MATRIX.md` calls this "Soft delete (**deleted_at**, restore,
withTrashed)". There is no `deleted_at` column in any framework. Counted mentions
in the ORM source:

| | `is_deleted` | `deleted_at` |
| --- | --- | --- |
| python | 24 | 0 |
| php | 19 | 0 |
| ruby | 3 (+19 `soft_delete_field`) | 0 |
| node | 22 | 0 |

`tina4-python/CLAUDE.md` states it outright: "There is no `deleted_at` column - the
flag is `is_deleted`." So the canonical feature list carries a column name the
framework has never had. Fix the matrix row title as part of this plan.

### Files

Soft delete lives inside the ORM base class, so the measurements are feature 16's.
No separate file set.

## Public surface contract

A model enables soft delete with a flag (`soft_delete = true`) and optionally names the
column (`soft_delete_field`, default `is_deleted`, promoted to all four from Ruby). The
verbs are `delete()` (set the flag), `force_delete()` (remove the row), `restore()` (clear
the flag), and `with_trashed()` (include flagged rows in a read). All four already implement
these verbs; they simply have no column to write to.

## Inputs and outputs

- The stored column is `is_deleted`, `INTEGER NOT NULL DEFAULT 0`, emitted engine-aware via
  the translator (INTEGER 0/1 is not how every engine spells a boolean).
- `delete()` sets `is_deleted = 1` and leaves the row in place; the row count is unchanged.
- An ordinary read excludes rows where `is_deleted = 1`; `with_trashed()` includes them.
- `restore()` sets `is_deleted = 0`; `force_delete()` issues a real DELETE.
- A model WITHOUT the flag gets no soft-delete column and `delete()` removes the row.

## Lifecycle and operation graph

1. A model declares `soft_delete = true`; `create_table()` (and the schema-sync path) MUST
   emit the `is_deleted` column -- this is the fix, and the two paths must share one DDL
   builder so they cannot drift again.
2. `delete()` sets the flag; the row survives.
3. An ordinary read filters out flagged rows; `with_trashed()` opts back in.
4. `restore()` clears the flag; `force_delete()` removes the row.
5. If the column is missing at runtime, the framework raises a NAMED error (below), never
   the raw engine message.

## Configuration and precedence

- `soft_delete_field` defaults to `is_deleted` and is overridable per model (Ruby's
  capability, promoted). The default is `is_deleted`, never `deleted_at`.
- The flag is declared on the model; there is no environment variable.

## Failures, side effects and security

- A missing `is_deleted` column raises a NAMED framework error that says what to do ("Model
  declares soft_delete but the table has no is_deleted column; run a migration or call
  create_table() after upgrading"), not the raw `no such column: is_deleted`.
- `delete()` NEVER falls back to a hard delete when the column is missing: converting a loud
  failure into silent data loss is forbidden (the Feature 4 mistake in reverse).
- A soft delete preserves the row, so nothing is lost; the security property is that a
  "deleted" record remains auditable and recoverable.
- Read-filtering must be applied consistently, so a soft-deleted row cannot leak through an
  ordinary read.

## Wire and persistence contract

The persisted shape is one `is_deleted` INTEGER column per soft-delete table, `0` for live
and `1` for deleted, emitted engine-aware by the translator. The two table-creating paths
(`create_table` and the schema-sync `syncModels`) must produce the SAME columns; today only
the sync path adds it, which is why the feature works in a running app and dies in a
test/script/REPL.

## Providers and substitutability

The column type is engine-aware through the Feature 7 translator, because "INTEGER 0/1" is
not universal. The soft-delete verbs and read-filtering are engine-agnostic above that. The
real substitutability requirement is internal: the two table-creating paths share one DDL
builder so a new engine or a new creation path cannot reintroduce the drift.

## Contradictions and defects

### What differs: nothing. That is the finding.

**D1. `create_table()` does not create the `is_deleted` column, so `delete()` fails
on a soft-delete model. Confirmed identical in ALL FOUR.**

Same model in each - soft delete enabled, two fields, create the table, save a row,
delete it:

| | columns after `create_table()` | `delete()` | row afterwards |
| --- | --- | --- | --- |
| python | `['id', 'name']` | **raises** `OperationalError: no such column: is_deleted` | untouched |
| ruby | `["id", "name"]` | **raises** `SQLite3::SQLException: no such column: is_deleted` | untouched |
| node | `['id', 'name']` | **raises** `no such column: is_deleted` | untouched |
| php | `["id","name"]` | **raises** `no such column: is_deleted` | untouched |

**All four frameworks, one failure, same cause.** The model declares `soft_delete = true`,
the framework builds the table without the column the flag requires, and the first
`delete()` throws. The row is left in place, so nothing is lost - it simply does not
work.

**Why this matters more than a normal parity bug.** Every other row in this audit
found divergence. This one found **convergence on broken**. That is worse in two
ways: it cannot be caught by comparing frameworks (they agree), and it survives
precisely because it agrees - a cross-framework test would pass on all four while
the feature is dead in all four.

**And the docs only half-admit it.** `tina4-nodejs/CLAUDE.md` does say: "Server boot
(`syncModels()`) adds the `is_deleted` INTEGER column (0/1) - but
`Model.createTable()` does not, so declare it there yourself." So Node documents the
gap. Python's CLAUDE.md documents soft delete with no such warning, and Python is
where `ORM.create_table()` is presented as the code-first path ("Code-first database
design -> `ORM.create_table()`"). A developer following the Python docs hits a raise.

The workaround (`syncModels()` / server boot adds the column) means the feature works
in a running app and fails in a test, a script, or a REPL - which is exactly where
`create_table()` gets used.

**D2. Ruby's soft-delete column is configurable; the other three hardcode it.**
Ruby has `soft_delete_field` (19 mentions) as an indirection, so a model can point
soft delete at a different column. Python, PHP and Node hardcode `is_deleted`. A
capability difference, not a bug - but it needs a decision: promote the indirection
to all four, or drop it from Ruby. Recommendation below.

### Verdict: GAP (present in all four, confirmed)

Decided on **correctness**. The feature is declared, documented, and non-functional
on the documented code-first path in all four frameworks. Nothing to promote from -
this is a build, not a reconciliation.

Category 4 for the missing column (nothing runtime-related prevents any of them from
adding it). Category 3 for D2's naming (a configurable field name is a design choice,
not a language one).

### Risks

- **Adding a column changes DDL for anyone who calls `create_table()`.** Existing
  tables are unaffected (nothing migrates them), so a running app sees no change -
  but a test suite that snapshots DDL will go red, correctly.
- **This is a feature nobody can currently be relying on**, because it raises on
  first use through this path. That makes the fix unusually safe.
- **Do not fix it by making `delete()` fall back to a hard delete.** That converts a
  loud failure into silent data loss, which is the feature-4 mistake in reverse.

## Owner decisions

Proposed for owner ratification (the execution evidence forces each):

1. `create_table()` reads the soft-delete flag and emits the `is_deleted` column; the fix is
   a BUILD in all four (GAP, no reference to port from).
2. The two table-creating paths (`create_table` and the schema-sync `syncModels`) share ONE
   DDL builder, so they cannot drift again. That shared builder is the real fix; the column
   is the symptom. This sequences behind Feature 7 (the translator) and the create_table
   split.
3. A missing column at runtime raises a NAMED framework error, never the raw engine message;
   `delete()` never falls back to a hard delete.
4. `soft_delete_field` (Ruby's configurable column name) is promoted to all four; the default
   is `is_deleted`.
5. Fix the matrix row title: `Soft delete (deleted_at, ...)` -> `is_deleted`, and sweep the
   docs site and the four skills for the same stale name. No framework has ever had a
   `deleted_at` column.

### Outstanding: resolved

The earlier PHP probe failed because I declared the model with nullable typed
properties (`public ?int $id = null`). PHP's ORM infers columns from
**non-nullable typed properties with defaults** (`public int $id = 0;`), the shape
used throughout `tina4-php/tests`. Re-run with the correct shape:

```
createTable() -> true
COLS: ["id","name"]
delete() -> RAISED SQLite3 execute() failed: Unable to prepare statement:
            no such column: is_deleted
row after: {"id":1,"name":"a"}
```

So PHP fails identically. This is **4 of 4**, and there is no reference
implementation to port from - the fix is a build in every framework.

## Proposed conformance fixture

### Tests to write

Real SQLite. The bug reproduces in a two-line model, so these are cheap and fast.

| pair | positive | negative |
| --- | --- | --- |
| the column exists | `create_table_adds_the_soft_delete_column_when_the_flag_is_set` | `create_table_does_not_omit_the_column_a_declared_flag_requires` - the exact three-framework reproduction |
| both paths agree | `create_table_and_schema_sync_produce_the_same_columns` | `no_table_creating_path_omits_a_column_another_path_adds` |
| lifecycle | `delete_flags_the_row_and_leaves_it_in_place`, `restore_clears_the_flag` | `delete_does_not_remove_the_row`, `force_delete_does_remove_it` |
| read filtering | `with_trashed_includes_a_soft_deleted_row` | `an_ordinary_read_excludes_a_soft_deleted_row` |
| named error | `a_missing_soft_delete_column_raises_a_named_framework_error` | `the_error_is_not_the_raw_engine_message` |
| configurable field | `a_custom_soft_delete_field_name_is_honoured` | `the_default_field_name_is_is_deleted_not_deleted_at` - locks the matrix fix in code |
| no flag, no column | `a_model_without_the_flag_gets_no_soft_delete_column` | `delete_on_a_normal_model_removes_the_row` |

The last pair matters because the fix must not add the column to every table.

## Integration map

- `create_table()` (Feature 15/16) and the schema-sync path both emit the column through the
  one shared DDL builder; the Feature 7 translator gives it the engine-aware type.
- Feature 17's base model hosts the `delete`/`force_delete`/`restore`/`with_trashed` verbs
  and the read-filtering.
- The feature matrix, the docs site and the four skills carry the stale `deleted_at` name and
  update together with the fix.
- Central fixtures, four runners and the CI matrix update together; the CI must run the
  code-first `create_table()` path, because the schema-sync path hides the bug.

## Breaking changes and migration

- Adding the `is_deleted` column changes the DDL that `create_table()` emits for a
  soft-delete model. Existing tables are unaffected (nothing migrates them), so a running app
  sees no change; a test that snapshots DDL goes red, correctly.
- Nobody can currently rely on the feature through this path, because it raises on first use,
  which makes the fix unusually safe.
- The matrix/docs title correction (`deleted_at` -> `is_deleted`) is a documentation fix, not
  a code break.

## Implementation backlog

### Methodology

1. Write the tests below in all four. Expect red in all four on the first two
   pairs - there is no reference implementation, so nothing goes green for free.
2. Fix `create_table()` to emit the column. This depends on **feature 16** (the
   `create_table` split) and therefore on **feature 3** (the translator), so it
   sequences behind both.
3. Make the two table-creating paths share one DDL builder, so `create_table()` and
   the schema-sync path cannot drift again. That shared builder is the real fix; the
   column is the symptom.
4. Add the named runtime error (pattern point 4).
5. Promote `soft_delete_field` from Ruby to the other three.
6. Fix the matrix row title (`deleted_at` -> the correct verbs) and audit the docs
   site plus the four skills for the same stale name.

## Porting capsule

### Pattern

**A model that declares soft delete gets its column, from every path that creates
the table.**

1. `create_table()` reads the soft-delete flag and includes the column in the DDL it
   emits. Same for the schema-sync path (`syncModels()` and its equivalents), which
   already does this in Node - so the two paths stop disagreeing.
2. The column is `is_deleted`, `INTEGER NOT NULL DEFAULT 0`, engine-aware via the
   `SQLTranslator` (feature 3), because "INTEGER 0/1" is not how every engine spells
   a boolean - and feature 16's `create_table` split is where this lands.
3. `delete()` on a soft-delete model sets the flag; `force_delete()` removes the row;
   `restore()` clears the flag; ordinary reads exclude flagged rows; `with_trashed()`
   includes them. All four already implement these verbs - they just have no column
   to write to.
4. **If the column is missing at runtime, raise a named framework error, not the
   engine's.** `no such column: is_deleted` tells the developer nothing about what to
   do. "Model Doc declares soft_delete but the table has no is_deleted column; run a
   migration or call create_table() after upgrading" is actionable.
5. **D2: promote Ruby's configurable field name to all four.** It costs one class
   attribute, it is already built and tested in Ruby, and the alternative is deleting
   working capability to achieve symmetry - which the language-specific rule
   explicitly warns against.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| enable | `soft_delete = True` | `$softDelete = true` | `self.soft_delete = true` | `static softDelete = true` |
| column name | `soft_delete_field = "is_deleted"` | `$softDeleteField` | `soft_delete_field` | `static softDeleteField` |
| soft delete | `delete()` | `delete()` | `delete` | `delete()` |
| hard delete | `force_delete()` | `forceDelete()` | `force_delete` | `forceDelete()` |
| restore | `restore()` | `restore()` | `restore` | `restore()` |
| include deleted | `with_trashed()` | `withTrashed()` | `with_trashed` | `withTrashed()` |

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (convergence-on-broken, D1/D2).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. This is a GAP verdict: soft delete is declared, documented and
NON-FUNCTIONAL on the code-first `create_table()` path in all four (verified by execution --
"convergence on broken"). The IMPLEMENTATION is a build in every framework and sequences
behind Feature 7 (the translator) and the create_table split, because that is where the
column emission lands. The matrix/docs title correction (`deleted_at` -> `is_deleted`) is a
standalone documentation fix that can happen immediately. Decision-ready is not built.
