# Feature 21: Declarative ORM relationships

## Identity and status

- Matrix identity: 21 - Declarative ORM relationships (`tina4_python/orm/__init__.py`;
  `tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, high parity with a Node lazy-load divergence. Measured 2026-08-11.
  Python `orm/model.py:97` (ORMMeta auto-wire) + `orm/fields.py:402` (descriptors) (`ebbab30`); PHP
  `Tina4/ORM.php:67` (`$hasOne/$hasMany/$belongsTo/$foreignKeys` arrays) (`6faabac5`); Ruby `lib/tina4/orm.rb:167`
  (`has_one/has_many/belongs_to` DSL) (`6d5b1de`); Node `packages/orm/src/baseModel.ts:102` (static arrays)
  (`27cf0f4`).
- Dependencies: the field system (feature 18, the FK field auto-wires), the base model (17), instance
  loading (26).
- Dependants: apps traversing relationships; AutoCrud `include`; serialization.
- Existing ADRs: none dedicated.

- Catalog phase: ORM

## Why this feature exists

Declarative relationships let a model say `posts = has_many("Post")` and then read `user.posts`. The design
questions are: how the two sides auto-wire, how forward references resolve, whether traversal avoids N+1, and
whether it enforces referential integrity.

## Existing implementation evidence

Universal: `has_one`/`has_many`/`belongs_to` declared (as descriptors / class arrays / DSL / static arrays);
a `ForeignKeyField` (feature 18) auto-wires `belongs_to` on the declaring model and `has_many` on the
referenced model (via a cross-model registry, so forward/string references resolve later). Traversal:

- Eager `include=` runs ONE batched `SELECT ... WHERE fk IN (?,...)` per relation and groups in memory (real
  N+1 avoidance), with nested dot-notation, in all four.
- LAZY load DIVERGES: Python/PHP/Ruby lazy-load on first attribute access (a descriptor / `__get__` /
  `define_method`), cached; NODE has NO lazy trigger - relationships are eager-only (`toDict` skips any
  relation not already eager-loaded).
- No engine-level referential action (see the register).

## Public surface contract

Declare relationships; read them as attributes (lazy in three languages) or eager-load via `include=`. The
contract is: the related rows are fetched correctly, without N+1 when eager-loaded.

## Inputs and outputs

- Input: relationship declarations + a loaded parent (and `include=` for eager). Output: the related
  instance(s), cached.

## Lifecycle and operation graph

1. Declare (or FK-auto-wire) the relationship; the cross-model registry resolves forward refs.
2. Access -> lazy-load (Python/PHP/Ruby) or eager `include=` -> batched `WHERE fk IN (...)`.

## Configuration and precedence

- `TINA4_ORM_PLURAL_TABLE_NAMES` (the has-many key/table pluralization). No other config.

## Failures, side effects and security

- No security surface. The risks are the missing cascade (integrity delegated to the DB), an unbounded IN
  list on eager-load (Ruby/Node), and the soft-delete blind spot (see the register).

## Wire and persistence contract

FK column = `<related>_id` (or declared). No DDL `REFERENCES`/`ON DELETE` (see the register).

## Providers and substitutability

No provider abstraction; the relationship types are fixed.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| REL-NO-CASCADE | UNIVERSAL: `on_delete`/cascade/dependent is NOT SUPPORTED in any language - the relationship config carries only `model`/`foreign_key`/`related_name`, and `create_table` emits NO `REFERENCES`/`ON DELETE` clause. Declaring `on_delete="CASCADE"` (Python's FK field accepts it) does NOTHING at the DB level; deleting a parent leaves orphaned children. Referential integrity is entirely delegated to hand-written DDL. | Decide: emit real FK constraints with `ON DELETE` from `create_table` (and honour Python's `on_delete`), or document clearly that relationships are read-side only and integrity is the DB's job. At minimum, stop Python's `on_delete` from silently doing nothing. |
| REL-NODE-AUTOWIRE-DEAD | Node-specific, VERIFIED on real SQLite (prior audit 2026-07-28): the DOCUMENTED declarative auto-wire (`type:"foreignKey"` + `references:"Model"` + `BaseModel.registerModel`, per `tina4-nodejs/CLAUDE.md`) produces NO accessors - both models registered and the FK declared, `post.author` and `author.posts` are MISSING as instance accessors, and passing `include` to `find()` does not populate them; calling `_processForeignKeys()`/`_applyFkRegistry()` explicitly changes nothing (so it is not a missed wiring call). Node also has NO lazy load (Python/PHP/Ruby lazy-load on attribute access), and `toDict` silently omits an un-loaded relation. So DECLARATIVE relationships are effectively NON-FUNCTIONAL in Node - only the imperative `belongsTo()`/`hasMany()` path works - and the CLAUDE.md documents an auto-wire that does not happen. | Make the documented declarative auto-wire actually attach `belongsTo`/`hasMany` (or delete the CLAUDE.md claim and require the imperative path), and add lazy loading (or document eager-only) - so Node matches the other three. |
| REL-SOFTDELETE-TRAVERSAL | Python's relationship queries do NOT append the `is_deleted` filter, so a soft-deleted child is still returned through `parent.children` (Node's imperative path DOES filter). Inconsistent with the finders' default exclusion. | Apply the soft-delete filter to relationship traversal in all four. |
| REL-EAGER-UNBOUNDED | Ruby/Node build one placeholder per parent PK in the eager `IN (...)` with NO cap; a very large parent set yields an unbounded IN list (a query-size/DB-parameter-limit risk). Python's lazy `has_many` conversely caps silently at 1000 (a parent with >1000 children loses the tail with no signal). | Chunk the eager IN list; make the lazy cap explicit/paged rather than a silent 1000-row truncation. |
| REL-PHP-EAGERLOAD-STATIC | PHP's public `ORM::eagerLoad($rows, $include)` (no `$db` arg) fatals - it calls the INSTANCE method `getDb()` in a static context. Latent (all internal callers pass `$db`), but a broken public API. | Resolve the DB via the static path (or require `$db`). |

## Owner decisions

- REL-DEC-01 (proposed): decide the cascade story (REL-NO-CASCADE) - emit real FK constraints or document
  read-side-only + stop Python's `on_delete` silently no-op'ing. This is the biggest relationship call.
- REL-DEC-02 (proposed): make Node's documented declarative auto-wire actually work + add lazy loading
  (REL-NODE-AUTOWIRE-DEAD) - Node declarative relationships are non-functional today; apply the soft-delete
  filter to traversal (REL-SOFTDELETE-TRAVERSAL); bound the eager IN list + make the lazy cap explicit
  (REL-EAGER-UNBOUNDED); fix PHP's static `eagerLoad` (REL-PHP-EAGERLOAD-STATIC).

## Proposed conformance fixture

A shared fixture (real SQLite + PG): eager `include=` runs ONE query per relation (no N+1); a soft-deleted
child is excluded from traversal; a parent with >N children pages rather than silently truncating;
lazy-access behaves the same in all four (after REL-DEC-02); and (after REL-DEC-01) a cascade-declared FK
actually cascades (or the docs say it does not).

## Integration map

- Consumers: relationship access, AutoCrud `include`, serialization (feature 26). Composes: the FK field
  (18), instance loading (26), soft delete (20).

## Breaking changes and migration

- Emitting FK constraints (if chosen) changes generated DDL and can reject orphan writes - a real behaviour
  change; version + migrate. Adding Node lazy loading is additive.

## Porting capsule

Declarative relationships need: `has_one`/`has_many`/`belongs_to` with FK auto-wire (both sides) and forward-
reference resolution via a cross-model registry; eager `include=` that batches ONE `WHERE fk IN (...)` per
relation (bounded/chunked) - never N+1; lazy load on attribute access (all languages, cached); the soft-
delete filter applied to traversal; and a DECIDED cascade story (real DB `ON DELETE`, or documented read-
side-only - not an `on_delete` option that silently does nothing).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (declare, auto-wire, lazy/eager).
- [x] Configuration, failure and security rules complete.
- [x] Wire (FK column, no cascade) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (no-cascade universal; Node eager-only; soft-delete).
- [x] Owner ambiguities decided (REL-DEC-01/02).
- [x] Conformance fixture (no-N+1, soft-delete, cascade) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
