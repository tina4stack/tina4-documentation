# Feature 17: ORM base class

## Identity and status

- Matrix identity: 17 - ORM base class (`tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, STRONG parity in the core lifecycle. Measured 2026-08-11. Python
  `orm/model.py:157` (`ebbab30`); PHP `Tina4/ORM.php:28` (`6faabac5`); Ruby `lib/tina4/orm.rb:36` (`6d5b1de`);
  Node `packages/orm/src/baseModel.ts:97` (`27cf0f4`).
- Dependencies: the Database facade + adapters, the field system (feature 18), validation (feature 19), the
  SQL translator (feature 7, for identifier quoting / limits).
- Dependants: every model; AutoCrud (feature 27); relationships (21/22); soft delete (20).
- Existing ADRs: none dedicated; the ORM-fix-pass + orm-gaps memories.

- Catalog phase: ORM

## Why this feature exists

The base model is the active-record heart: an instance maps to a table row, `save()` inserts or updates,
finders return hydrated instances. The hard parts are getting insert-vs-update right (especially for natural
keys), failing LOUD without crashing the caller, and keeping the same contract across four languages.

## Existing implementation evidence

Strong parity in all four: `save()` / `delete()` / `force_delete()` / `restore()` / `load()` and the
finders (`find`/`find_by_id`/`all`/`where`/`select`/`count`/`create`). Universal behaviours:

- TABLE NAME = the lowercase class name by default (opt-in pluralization via
  `TINA4_ORM_PLURAL_TABLE_NAMES`); `table_name` overrides. (Node requires an explicit `tableName`.)
- INSERT-vs-UPDATE by ROW EXISTENCE for a natural key (a `SELECT`/`exists` probe), not by PK presence - the
  fix for the old silent no-op (v3.13.11). Auto-increment PK: null -> INSERT, set -> UPDATE. Composite keys
  address the WHOLE key.
- save() is LOUD but does NOT raise: it returns `self`/`this` on success and `false` on failure, capturing
  the real cause on `last_error` (preferring the driver's `get_error()`), logging via `Log.error`, and
  rolling back; it appends DX hints for the two commonest footguns (missing table, missing `is_deleted`
  column). Validation runs first, so an invalid model never reaches the driver (feature 19). `create()`
  returns `false` (not an unsaved instance) on failure.
- `delete`/`force_delete`/`restore` raise on a missing PK (a loud contract).

## Public surface contract

`Model(data)` -> instance; `save() -> self|false`; `find*/all/where/select/count`; `delete/force_delete/
restore`. The contract is: save is loud-but-non-throwing, natural keys are existence-checked, and finders
return fully hydrated instances (feature 26).

## Inputs and outputs

- Input: a dict/object (or a JSON-object string; an array is rejected with a clear error), field assignments.
  Output: a persisted row + `self`, or `false` + `last_error`; or hydrated instances from a finder.

## Lifecycle and operation graph

1. Construct: seed field defaults (callable defaults resolved per-instance - feature 18), track caller
   assignments.
2. `save()`: validate -> pick insert/update by existence probe -> execute in a transaction -> on error
   rollback + capture cause + `false`.
3. Finders build instances through the constructor/`_populate` (feature 26).

## Configuration and precedence

- `TINA4_DATABASE_URL`/`_USERNAME`/`_PASSWORD` (auto-bind), `TINA4_ORM_PLURAL_TABLE_NAMES`, class attrs
  (`table_name`, `soft_delete`, `field_mapping`, `auto_crud`, `_db`). A default read cap of 100 rows is
  shared across the finders.

## Failures, side effects and security

- save/delete apply DDL/DML in transactions. Failure is loud-but-non-throwing (returns false + logged
  cause). Parameters are bound (no injection). No security surface of its own beyond the adapters.

## Wire and persistence contract

The active-record mapping: instance fields <-> table columns (via `field_mapping`/autoMap, feature 18). The
write path returns a `DatabaseResult` (feature 5); the last-id feeds an auto-increment PK.

## Providers and substitutability

The engine is the bound adapter (default or a named registry). No other abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| ORM-VESTIGIAL-STATE | Node's `_exists` flag is WRITTEN at three sites (`find`/`load`/`save`) but NEVER READ (grep-confirmed) and set inconsistently (finder-loaded instances via `findById`/`select`/`where`/`all` don't get it) - so any future "is this persisted?" logic keyed on it would be wrong. PHP's `tableFilter` is READ in `count()` but UNDECLARED on the base class (routes through `__get` -> null -> silently skipped), so a typo'd subclass property is silently ignored rather than erroring. Python/PHP/Node also carry dead unused locals in `delete/force_delete/restore` (leftovers from the `_pk_where` refactor). | Remove or correctly wire Node's `_exists` (set it on ALL finder paths and read it, or delete it); declare PHP's `tableFilter` on the base class; delete the dead locals. Cosmetic but they mislead. |
| ORM-RAW-SELECT-SOFTDELETE | Node's raw `select()`/`selectOne()` do NOT inject `is_deleted = 0` (they run caller SQL verbatim), so `Model.select("SELECT * FROM articles")` returns soft-deleted rows - the default exclusion is a property of the high-level finders only. (Expected for raw SQL, but a footgun.) | Document that raw `select` bypasses the soft-delete filter; callers must add it. |

The core lifecycle (save-loud, insert-vs-update, natural-key existence probe, composite-key safety) is
well-implemented and regression-tested in all four - the register is limited to vestigial state and the raw-
select soft-delete note.

## Owner decisions

- ORM17-DEC-01 (proposed): clean up the vestigial state (Node `_exists`, PHP `tableFilter`, dead locals) and
  document the raw-select soft-delete bypass (ORM-VESTIGIAL-STATE + ORM-RAW-SELECT-SOFTDELETE). Low risk.

## Proposed conformance fixture

The shared ORM contract fixture (real SQLite + real PG, already strong): save loud-but-non-throwing on a DB
error (false + cause + logged + rolled back); `create()` propagates failure; a natural-key insert then update
(not a silent no-op); a composite key updates/deletes only the whole-key row. Keep it; add a raw-select-
returns-soft-deleted assertion (to lock the documented behaviour).

## Integration map

- Consumers: every model, AutoCrud (27), the finders. Composes: fields (18), validation (19), soft delete
  (20), instance loading (26), the Database facade (5), the SQL translator (7).

## Breaking changes and migration

- None proposed (cleanups are internal).

## Porting capsule

A base model needs: table-name = lowercase class name (opt-in plural); PK derivation (first PK field, else
`id`) with composite-key-safe addressing; INSERT-vs-UPDATE by ROW EXISTENCE for natural keys (never PK
presence alone - that was the silent-no-op bug); a LOUD-but-non-throwing `save()` returning `self`/`false`
with the driver's real cause captured and rolled back, plus DX hints for missing-table/missing-`is_deleted`;
`create()` returning false on failure; and `delete`/`force_delete`/`restore` that raise on a missing PK. No
vestigial "exists" flags.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (save, finders, insert-vs-update).
- [x] Configuration, failure (loud-non-throwing) and security rules complete.
- [x] Wire/persistence (active-record mapping) and provider contracts complete.
- [x] Four-language behaviour recorded (strong parity; vestigial state divergences).
- [x] Owner ambiguities decided (ORM17-DEC-01).
- [x] Conformance fixture (the shared ORM contract) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
