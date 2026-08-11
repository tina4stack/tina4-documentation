# Feature 26: ORM instance loading

## Identity and status

- Matrix identity: 26 - ORM instance loading (`tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature; minimal coercion, with a Python read-time footgun and a Ruby two-path
  asymmetry. Measured 2026-08-11. Python `orm/model.py:241` `_populate` (`ebbab30`); PHP `Tina4/ORM.php:501`
  `fill` (`6faabac5`); Ruby `lib/tina4/orm.rb:578` `from_hash` + `:1013` `load` (`6d5b1de`); Node
  `packages/orm/src/baseModel.ts:144` constructor (`27cf0f4`).
- Dependencies: the field system (feature 18), the DB facade (`fetch`), relationships (21).
- Dependants: every finder result; serialization (`to_dict`/`to_json`).
- Existing ADRs: none dedicated.

- Catalog phase: ORM

## Why this feature exists

Hydration turns a DB row into a model instance: map columns to fields, coerce types, parse JSON, and set up
relationships. It is the read half of the ORM's type contract - and where the four frameworks differ on how
much they coerce and how consistently.

## Existing implementation evidence

Universal: a finder runs `fetch`, then builds an instance per row through the constructor/`_populate`/`fill`/
`from_hash`, mapping columns to fields (via `field_mapping`/autoMap; Node maps case-insensitively so
uppercase Firebird columns work). Coercion:

- JSON is parsed on read in all four (a JSON string -> a native object; native-JSON engines' already-parsed
  values normalized).
- Scalar coercion diverges: PHP/Ruby/Node coerce ONLY JSON on read (booleans hydrate as numbers, datetimes
  as the driver's strings - no `Date`/`bool` reconstitution). Python runs the FULL `Field.validate()` on read
  - the same method as the write path (which is powerful but has a footgun - see the register).
- Relationships are LAZY in Python/PHP/Ruby (a descriptor / `__get__` triggers the load on first access,
  cached); Node's relationships are explicit async methods + eager `include` (batched, no N+1), not lazy.

## Public surface contract

A finder returns fully hydrated instances; `load()` reloads an instance from its PK. Contract: columns map to
fields, JSON becomes a native object, and a partial `select` yields a partial instance (absent fields keep
their defaults).

## Inputs and outputs

- Input: a DB row (dict). Output: a model instance with fields set (JSON parsed), relationships resolvable.

## Lifecycle and operation graph

1. `fetch` the rows.
2. Per row: construct the instance, map columns -> fields, parse JSON, set `_persisted`.
3. On relationship access: lazy-load (Python/PHP/Ruby) or via `include` (Node).

## Configuration and precedence

- `field_mapping` / autoMap; `TINA4_ORM_PLURAL_TABLE_NAMES` (relation-key matching).

## Failures, side effects and security

- The main risks are read-time (Python's re-validation aborting a whole page; Ruby's two-path coercion
  asymmetry). No security surface.

## Wire and persistence contract

Column -> field mapping + JSON parse is the read contract; it should be symmetric with the write coercion
(feature 18).

## Providers and substitutability

No provider abstraction; the driver's row shape is the input (feature 3 guarantees a plain dict).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| LOAD-PY-REVALIDATE | Python's hydration reuses `Field.validate()`, so it RE-ENFORCES write-path constraints on READ: a stored row that violates `required`/length/range/`regex`/`choices`/a custom validator (or a constraint TIGHTENED later, or one corrupt JSON cell) raises `ValueError` out of `cls(row)` and ABORTS THE ENTIRE `select()` - not just the offending row. So tightening a constraint can make existing rows unreadable, and a single bad cell breaks a whole page. Unguarded (no test reads a constraint-violating stored row). Type COERCION on read is desirable; re-running required/length/range/choices is the questionable part. | On read, apply type coercion + JSON parse but DO NOT re-enforce business constraints (required/length/range/choices) - those belong to the write path. Add a test that a constraint-violating stored row still hydrates. |
| LOAD-RUBY-ASYMMETRY | Ruby has TWO read paths with different coercion: `from_hash` (the primary finder path) JSON-decodes json columns, but the instance `load()` does NOT (it feeds the raw driver value to the setter). So `Model.find(id).payload` returns a parsed Hash while `model.load(id).payload` stays a raw JSON String - the same row, different type, by read path. Unguarded (no spec calls `load()` with a json field). | Route `load()` through the same coercion as `from_hash` (one hydration path), and add a `load()`+json regression. |
| LOAD-JSON-ONLY | PHP/Ruby/Node coerce ONLY JSON on read - booleans hydrate as numbers and datetimes as driver strings (no `Date`/`bool` reconstitution); the round-trip type of a boolean/datetime is engine-dependent. Consistent within a language but a cross-engine surprise, and asymmetric with Python (which coerces scalars too). | Decide the read-coercion contract: coerce scalars to native types (matching Python) or document that non-JSON scalars are driver-typed. Make it consistent across the four. |
| LOAD-NODE-SERIALIZE-OMIT | Node's `to_dict()`/`to_json()` silently OMIT any relation not previously eager-loaded (they cannot lazy-load - a sync serializer), with no error at serialize time (the warning fires only at eager-load). A developer who forgets `include` gets a serialized object missing the relation and no signal. | Warn (or error) at serialize time when a declared relation is omitted because it was not loaded, so the omission is not silent. |
| LOAD-RUBY-SIGNATURE | Ruby's `load(arg, params)` diverges from the other three's `load(filter, params, include)`: it is positional, names the first argument generically, and takes NO `include` - so Ruby alone cannot eager-load relations during a `load()` (Python/PHP/Node can). A parity gap on the public signature, not just the coercion (LOAD-RUBY-ASYMMETRY). | Align Ruby on `load(filter, params, include)` and add the `include` eager-load, matching the other three. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- LOAD-DEC-01 (proposed): stop re-enforcing business constraints on read in Python (LOAD-PY-REVALIDATE) -
  the highest-value fix (it can make existing data unreadable) - and unify Ruby's two read paths
  (LOAD-RUBY-ASYMMETRY).
- LOAD-DEC-02 (proposed): decide the scalar read-coercion contract (LOAD-JSON-ONLY); make Node's
  serialize-omit non-silent (LOAD-NODE-SERIALIZE-OMIT); align Ruby's `load()` signature + add `include`
  (LOAD-RUBY-SIGNATURE).

## Proposed conformance fixture

A shared fixture: a JSON column round-trips to a native object via EVERY read path (finder AND `load` -
catches LOAD-RUBY-ASYMMETRY); a stored row that violates a (later-tightened) constraint still hydrates
(catches LOAD-PY-REVALIDATE); a partial `select` yields a partial instance; and (after LOAD-DEC-02) a
boolean/datetime hydrates to the agreed type consistently across engines.

## Integration map

- Consumers: every finder, `load`, serialization. Composes: fields (18), the DB facade `fetch` (feature 3's
  plain-dict guarantee), relationships (21).

## Breaking changes and migration

- Dropping read-time constraint re-enforcement (Python) changes behaviour (previously-unreadable rows now
  load) - a correctness/robustness fix. Coercing scalars on read (if chosen) changes hydrated types -
  document it.

## Porting capsule

Hydration needs: column -> field mapping (case-insensitive for uppercase-column engines); type COERCION +
JSON parse on read (but NOT re-enforcement of write-path business constraints - that makes existing/tightened
data unreadable, the Python footgun); ONE read path (a finder and `load()` must coerce identically - the Ruby
asymmetry); a decided scalar-coercion contract (native `Date`/`bool` or documented driver-typed); partial-
load support; and a serializer that does not SILENTLY omit an unloaded relation.

## Audit closure checklist

- [x] Boundary and public surface complete (hydration paths x four).
- [x] Lifecycle and producer/consumer edges complete (fetch -> construct -> map -> coerce -> relations).
- [x] Configuration, failure (read-time footguns) and security rules complete.
- [x] Wire (column<->field, JSON) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (Python re-validate, Ruby two-path, JSON-only, Node
  serialize-omit).
- [x] Owner ambiguities decided (LOAD-DEC-01/02).
- [x] Conformance fixture (every-read-path + constraint-violating row) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
