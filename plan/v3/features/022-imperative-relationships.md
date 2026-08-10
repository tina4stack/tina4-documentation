# Feature 022: Imperative ORM relationships

## Identity and status

- Matrix identity: 22 - Imperative ORM relationships
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (method signatures below). No
  framework code changed.
- Dependencies: Feature 17 ORM base class (the methods live there), Feature 6 query builder
  (they compose the read), Feature 21 declarative relationships (the other form of the same
  concept)
- Dependants: any application that fetches a relationship at runtime by naming the related
  class, or populates a model from a filter with `load()`
- Existing ADRs: the removed `QueryBuilder#get` `LIMIT 100` default (the same footgun the
  imperative `has_many` still carries); the 100-row cap is shared with Features 5, 21, 23
- Shared fixtures: `imperative_relationships_contract.json` is required

## Why this feature exists

A developer fetches a related row or set at runtime by naming the related class -
`author.has_many(Post, "author_id")` - without a prior class-level declaration, and populates
a model in place from a filter with `load()`. This is the imperative counterpart to Feature
21's declarative accessors: same relationships, called explicitly instead of auto-wired.

## Boundary

This feature owns the instance methods `has_one`/`has_many`/`belongs_to` (each taking a
related CLASS and an optional foreign key) and `load(filter, params, include)` (populate this
instance from a filter, optionally eager-loading relations). It DELEGATES the read to Feature
6, the model to Feature 17, and the declaration-time auto-wiring to Feature 21. The two
features are the two idioms for one concept; the owner decision is which idioms every language
must support.

## Existing implementation evidence

| Evidence (measured signatures) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `has_one` instance method | `has_one(related_class, fk=None)` | `hasOne($relatedClass, $fk=null)` | DSL only (`has_one :name`) | `async hasOne(...)` |
| `has_many` instance method | `has_many(related_class, fk=None, limit=100, offset=0)` | `hasMany($relatedClass, $fk=null, $limit=100, $offset=0)` | DSL only (no limit) | `async hasMany(...)` |
| `belongs_to` instance method | `belongs_to(related_class, fk=None)` | `belongsTo($relatedClass, $fk=null)` | DSL only | `async belongsTo(...)` |
| Imperative fetch-now form | YES | YES | NO (declarative only) | YES |
| `has_many` silent 100-cap | YES | YES | n/a (DSL) | YES (probed 120 -> 100) |
| `load()` signature | `load(filter, params, include)` | `load($filter, $params, $include)` | `load(arg=nil, params=nil)` (no include) | `async load(filter, params, include)` |
| Return shape | one-or-None / list | `?ORM` / array | via accessor | Promise one-or-null / list |

The imperative fetch-now methods (taking a related class at call time) exist in Python, PHP
and Node. Ruby's `has_one`/`has_many`/`belongs_to` are class-level DSL DECLARATIONS that take
a relationship NAME, not instance methods that take a class - so Ruby has no imperative
form; it reaches a relationship only through the declared accessor. Combined with Feature 21's
finding that PHP has no declarative accessors, the four scatter across which idioms they
support (Python: both; PHP: imperative only; Ruby: declarative only; Node: both, plus the
serialize-only quirk). `has_many` carries a silent `limit = 100` in every imperative
implementation, and Ruby's `load()` lacks the `include` parameter the other three share.

## Public surface contract

- `has_one(related_class, foreign_key=None)` returns one related model or null.
- `has_many(related_class, foreign_key=None, limit=..., offset=...)` returns a list of related
  models -- NOT silently capped at 100.
- `belongs_to(related_class, foreign_key=None)` returns the owning model or null.
- `load(filter=None, params=None, include=None)` populates THIS instance from the first
  matching row, optionally eager-loading `include` relations, and returns a success boolean.
- The foreign key is derived from the related class when omitted, by one deterministic rule in
  all four.

## Inputs and outputs

- Input: a related class (a real class reference where the language allows, a string only
  where it must) plus an optional foreign key; `load()` takes a filter and bound params.
- Output: `has_one`/`belongs_to` return one model or the language null; `has_many` returns a
  list; `load()` returns `true` when it populated the instance and `false` when no row matched
  (it does not raise on a miss).
- A missing foreign key is derived deterministically (for example `author_id` from `Author`),
  identically across the four.

## Lifecycle and operation graph

1. `has_many(Related, fk)` derives the foreign key if absent, composes a `SELECT ... WHERE fk
   = ?` through Feature 6, and returns the hydrated list.
2. `has_one`/`belongs_to` do the same for a single row, returning one-or-null.
3. `load(filter, params, include)` runs the filter, populates this instance from the first
   row, eager-loads any `include` relations, and returns whether it matched.
4. No result is cached implicitly; each call is an explicit read.

## Configuration and precedence

- An explicit `foreign_key` argument beats the derived name.
- `has_many`'s row limit is NOT a silent default 100; the cap is removed and settled jointly
  with Features 5, 21 and 23.
- `load()`'s `include` is honored in all four (Ruby gains it).

## Failures, side effects and security

- `has_many` must NOT silently truncate at 100: an owner with 150 children returns 150. Silent
  truncation is data loss by omission (the same footgun removed from `QueryBuilder#get`).
- `load()` returns `false` on no match rather than raising, so a caller branches on the
  boolean; it never leaves the instance half-populated.
- The foreign key and related class come from trusted model metadata, and the filter's values
  are bound, so there is no injection through the imperative call.
- These are read-only methods with no persistence side effect.

## Wire and persistence contract

There is no new persistence; the foreign-key column is ordinary. The contract is the return
SHAPE and the derived foreign-key NAME: `has_one`/`belongs_to` return one-or-null, `has_many`
returns a list, and the derived key is identical across the four so the same call reaches the
same rows everywhere.

## Providers and substitutability

The imperative methods compose standard `WHERE fk = ?` reads through Feature 6, so they are
engine-agnostic; any provider satisfies them. Eager loading through `load(include=...)` issues
a bounded number of query sets regardless of engine.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| IMP-01 | Ruby has NO imperative fetch-now methods; `has_many`/`has_one`/`belongs_to` are declarative DSL declarations. An app cannot call `author.has_many(Post, :author_id)` in Ruby. | Decide: add the imperative form to Ruby, or declare Ruby declarative-only by design. Given PHP is imperative-only (Feature 21), the coherent call is BOTH forms in all four. |
| IMP-02 | `has_many` silently caps at 100 in Python, PHP and Node (Ruby's DSL has no limit). Same footgun as Features 5, 21, 23. | Remove the silent cap; settle the 100-row question ONCE across all four surfaces. |
| IMP-03 | Ruby's `load()` lacks the `include` parameter the other three carry, so it cannot eager-load. | Add `include` to Ruby's `load()`; one signature in all four. |
| IMP-04 | Foreign-key derivation rule is not proven identical across the four. | Gate the derived key (for example `author_id` from `Author`) in all four. |
| IMP-05 | No shared fixture exists. | Add `imperative_relationships_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. BOTH the imperative (Feature 22) and declarative (Feature 21) forms exist in all four:
   Ruby gains the imperative methods, PHP gains the declarative accessors, so an application
   can use either idiom portably. This is the joint call across Features 21 and 22.
2. Remove the silent `has_many` 100-cap; settle the 100-row question once across `has_many`
   (21/22), the query builder (5) and pagination (23). Ruby's no-limit is the reference.
3. `load()` has one signature in all four, `load(filter, params, include)`, so Ruby gains
   eager loading through it.
4. The foreign key is derived by one deterministic rule when omitted, identical across the
   four, and an explicit argument overrides it.
5. Return shapes are fixed: `has_one`/`belongs_to` one-or-null, `has_many` a list, `load()` a
   boolean.

## Proposed conformance fixture

Add `imperative_relationships_contract.json` with stable ids for: `has_many` returning ALL
children (not a capped 100) on a >100-row set; `has_one`/`belongs_to` returning one-or-null;
`load(filter)` populating the instance and returning true, and returning false on no match;
foreign-key auto-derivation matching the explicit key; `load(include=...)` eager-loading a
relation; and Ruby imperative-method parity once added. Every behavioural case uses real
SQLite; no mock can claim conformance.

## Integration map

- Feature 17's base model hosts these methods; Feature 6 composes their reads; Feature 21 is
  the declarative counterpart and shares the both-forms decision.
- The 100-row cap decision spans Features 5, 21, 22 and 23 and is settled once.
- Central fixtures, four runners, the CI matrix, release notes and the ORM docs update
  together.

## Breaking changes and migration

- Removing the `has_many` 100-cap changes result size; a caller that relied on the cap sees
  more rows and should use explicit `limit`/pagination for a bounded read.
- Ruby gaining the imperative methods and the `load(include=...)` parameter is additive.
- PHP gaining declarative accessors (Feature 21) is additive; no imperative caller breaks.

## Implementation backlog

1. Add `imperative_relationships_contract.json` and wire four runners against real SQLite.
2. Add the imperative `has_one`/`has_many`/`belongs_to` methods to Ruby (IMP-01).
3. Remove the `has_many` 100-cap in Python, PHP and Node; settle the joint cap decision.
4. Add `include` to Ruby's `load()` (IMP-03); unify the signature.
5. Gate foreign-key derivation parity (IMP-04).
6. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `has_one(related_class, fk=None)`, `has_many(related_class, fk=None, limit, offset)`
and `belongs_to(related_class, fk=None)` as INSTANCE methods that derive the foreign key when
omitted, compose a bound `WHERE fk = ?` read, and return one-or-null or a list -- with NO
silent row cap. Implement `load(filter, params, include)` to populate the instance from the
first match, eager-load `include`, and return a success boolean. Derive the foreign key by the
same deterministic rule everywhere. Prove the port against real SQLite, especially that
`has_many` returns more than 100 rows when they exist.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (IMP-01..05).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
