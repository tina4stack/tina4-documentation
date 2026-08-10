# Feature 020: Soft delete

## Identity and status

- Matrix identity: 20 — Soft delete
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

## Why this feature exists

The retained audit does not yet state the developer problem in one language-neutral sentence.

## Boundary

The retained audit does not yet separate what this feature owns, delegates, and excludes.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

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

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

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

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

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

### Parked

Not implemented. Sequenced after features 3 and 13 (both of which touch the
`create_table` path this fix lands in). Order: 6, 4, 5, 3, 13, 14, then 2, 1, 0.
