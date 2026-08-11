# Feature 20: Soft delete

## Identity and status

- Matrix identity: 20 - Soft delete (`tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, high parity, force-delete now correct in all four. Measured 2026-08-11.
  Python `orm/model.py:602` (`ebbab30`); PHP `Tina4/ORM.php:870` (`6faabac5`); Ruby `lib/tina4/orm.rb:944`
  (`6d5b1de`); Node `packages/orm/src/baseModel.ts:917` (`27cf0f4`).
- Dependencies: the base model (17), the finders (default exclusion).
- Dependants: apps that keep deleted rows; audit/undo flows.
- Existing ADRs: none dedicated; the ORM-force-delete task (3.13.97).

- Catalog phase: ORM

## Why this feature exists

Soft delete marks a row deleted (a flag) instead of removing it, so the row is excluded from normal reads but
recoverable. The correctness-critical parts are: every finder must exclude soft-deleted rows by default,
`force_delete` must ACTUALLY hard-remove (a bug that shipped once), and `restore`/`with_trashed` must round-
trip.

## Existing implementation evidence

Universal in all four: a `soft_delete` flag + an `is_deleted` INTEGER 0/1 column (NOT a `deleted_at`
timestamp). `delete()` sets `is_deleted = 1` when soft-delete is on (else hard delete); every high-level
finder appends `is_deleted = 0` (Python also `OR is_deleted IS NULL`); `force_delete()` ALWAYS hard-removes
(transaction-wrapped, raises on a missing PK); `restore()` sets `is_deleted = 0` (requires soft-delete);
`with_trashed()` omits the filter. Divergence: Ruby's soft-delete column is CONFIGURABLE
(`soft_delete_field`, default `:is_deleted`); Python/PHP/Node hard-code `is_deleted`.

The "force-delete broken in 3.13.97" history, resolved: the actual code bug (force_delete threw instead of
deleting because of an undefined `$whereParams`) was PHP-ONLY. Python's release note reads literally "(PHP)"
and the release commit did not touch `model.py`; Ruby's 3.13.97 change was a TEST-ONLY lock-in ("force_delete
was already correct... proven a gate by mutation"); Node's fix + a related composite-PK hardening landed at
HEAD. At HEAD, force_delete WORKS and is regression-tested (real hard-remove) in all four.

## Public surface contract

`delete()` (soft when enabled), `force_delete()` (always hard), `restore()`, `with_trashed()`. Contract: a
soft-deleted row is excluded from finders, still in the DB, recoverable via `restore`, and hard-removable via
`force_delete`.

## Inputs and outputs

- Input: `soft_delete = true` on the model, a row. Output: `is_deleted = 1` (soft) or a removed row (force);
  filtered finder results; a restored row.

## Lifecycle and operation graph

1. `delete()`: soft-delete sets `is_deleted = 1`; else hard delete.
2. Finders append `is_deleted = 0` (default exclusion).
3. `force_delete()` hard-removes; `restore()` clears the flag; `with_trashed()` includes deleted rows.

## Configuration and precedence

- `soft_delete` class flag; Ruby `soft_delete_field` (configurable column). The `is_deleted` column must
  exist (Node's `syncModels` adds it; `create_table` does NOT in Python/PHP/Node - the save DX hint tells the
  developer to declare it).

## Failures, side effects and security

- `force_delete` is irreversible. The main risk is a finder that forgets the exclusion, or a schema without
  the `is_deleted` column (see the register). No security surface.

## Wire and persistence contract

`is_deleted` INTEGER 0/1 is the persistence contract; the finder filter `is_deleted = 0` is the read
contract.

## Providers and substitutability

No provider abstraction; the column name is fixed (Ruby configurable).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SOFTDEL-FORCE-WAS-PHP | The "ORM force-delete broken, fixed in 3.13.97 across all four" record is OVERSTATED: the actual throw-instead-of-delete bug was PHP-ONLY (undefined `$whereParams`). Python and Ruby were already correct - their 3.13.97 changes were test-only lock-ins - and Node's fix + a composite-PK hardening landed. At HEAD, force_delete works and is regression-tested in all four. | Correct the record (don't carry "Python/Ruby force-delete was broken" forward). No code change - all four are correct now. |
| SOFTDEL-CREATETABLE-COLUMN | `create_table()` never injects the `is_deleted` column (Python/PHP/Node), so a `soft_delete = true` model that doesn't declare `is_deleted` produces a table with no such column, and every soft-delete read/write then errors on a missing column. The save DX hint exists (evidence the footgun is known), but the DDL gap is unaddressed and untested. | Have `create_table()` inject `is_deleted` for a soft-delete model (or require the field and fail at declaration), so the schema always matches the behaviour. |
| SOFTDEL-PY-FILTER-MAPPING | Python's soft-delete filter hard-codes the literal `is_deleted` column and is NOT `field_mapping`-aware (the write side uses `field_mapping`), so a model that remaps `is_deleted` would filter on the wrong column. Unlikely but real. | Route the soft-delete filter through `field_mapping` like the write side. |
| SOFTDEL-PHP-RESTORE-UNTESTED | PHP's `restore()` and `with_trashed()` have NO tests (soft-delete write, read-exclusion, and force_delete are covered; the un-delete and trashed-inclusive read are not). | Add real tests for PHP `restore()` and `with_trashed()`. |

## Owner decisions

- SOFTDEL-DEC-01 (proposed): correct the force-delete record (SOFTDEL-FORCE-WAS-PHP - no code change) and add
  the missing PHP restore/with_trashed tests (SOFTDEL-PHP-RESTORE-UNTESTED).
- SOFTDEL-DEC-02 (proposed): make `create_table()` inject `is_deleted` for soft-delete models
  (SOFTDEL-CREATETABLE-COLUMN) and route the Python filter through `field_mapping`
  (SOFTDEL-PY-FILTER-MAPPING).

## Proposed conformance fixture

A shared fixture (real SQLite + PG): a soft-delete flags-not-removes; the row is excluded from every finder
but present in the DB and in `with_trashed`; `restore()` un-deletes; `force_delete()` hard-removes (gone even
from `with_trashed`) - the real hard-remove regression that catches the PHP-class bug. Assert a
`soft_delete` model with `create_table()` produces a usable `is_deleted` column (after SOFTDEL-DEC-02).

## Integration map

- Consumers: `delete`/finders/`restore`/`with_trashed`, the base model (17). Related: `create_table` (the
  column gap), migrations (15).

## Breaking changes and migration

- Injecting `is_deleted` into `create_table` changes generated DDL for soft-delete models - document it.

## Implementation backlog

1. SOFTDEL-DEC-01: PHP restore/with_trashed tests; correct the force-delete record.
2. SOFTDEL-DEC-02: `create_table` injects `is_deleted`; Python filter via `field_mapping`.

## Porting capsule

Soft delete needs: a `soft_delete` flag + an `is_deleted` 0/1 column (the schema must guarantee the column
exists - inject it in `create_table`); every high-level finder appending `is_deleted = 0` (route it through
`field_mapping`); a `force_delete` that ALWAYS hard-removes (transaction-wrapped, real hard-remove regression
test - this is the bug that shipped once); `restore()` and `with_trashed()` both tested; and raising on a
missing PK. Consider whether a `deleted_at` timestamp is wanted (all four use a boolean flag today).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (delete, finder exclusion, restore, force).
- [x] Configuration, failure and security rules complete.
- [x] Wire/persistence (`is_deleted`) and provider contracts complete.
- [x] Four-language behaviour recorded (force-delete-was-PHP corrected; column/config divergences).
- [x] Owner ambiguities decided (SOFTDEL-DEC-01/02).
- [x] Conformance fixture (real hard-remove + column) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
