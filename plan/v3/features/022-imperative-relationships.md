# Feature 22: Imperative ORM relationships

## Identity and status

- Matrix identity: 22 - Imperative ORM relationships (`tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature; a distinct runtime API in three, collapsed in Ruby. Measured 2026-08-11.
  Python `orm/model.py:1220` (`ebbab30`); PHP `Tina4/ORM.php:1669` (`6faabac5`); Ruby `lib/tina4/orm.rb:167`
  (same class methods) (`6d5b1de`); Node `packages/orm/src/baseModel.ts:1415` (`27cf0f4`).
- Dependencies: the base model (17), the finders.
- Dependants: apps that traverse relationships without declaring them.
- Existing ADRs: none dedicated.

- Catalog phase: ORM

## Why this feature exists

Sometimes a relationship is needed once, at runtime, without a class declaration - `user.has_many(Post,
"user_id")`. This is the imperative counterpart to feature 21. The design question is whether it is a
genuinely separate mechanism or the same declaration invoked differently.

## Existing implementation evidence

- Python/PHP/Node: a DISTINCT imperative API - instance methods `has_one`/`has_many`/`belongs_to` that take a
  related CLASS (not a name string), run their OWN single per-call query (no batching, no `_rel_cache`), and
  return the result directly. Python defaults `has_many` `limit=100` (vs the lazy descriptor's 1000); PHP has
  a parallel private implementation for the declarative path; Node writes the result onto the instance and
  returns it.
- Ruby: NOT a separate API - `has_one`/`has_many`/`belongs_to` are the SAME class methods used declaratively,
  and Ruby lets them be called at runtime on the class object. There is no instance-level relationship
  builder.

## Public surface contract

`instance.has_many(RelatedClass, fk)` (Python/PHP/Node) returns the related rows immediately. Ruby's
imperative form is just the declarative class method invoked at runtime.

## Inputs and outputs

- Input: a related class + optional FK. Output: the related instance(s), fetched immediately (uncached).

## Lifecycle and operation graph

1. Call `has_many(RelatedClass, fk)` -> build `SELECT ... WHERE fk = ?` -> return instances.

## Configuration and precedence

- None.

## Failures, side effects and security

- No security surface. The risks are duplicated query logic (PHP), an orphaned serialization store (Node),
  and a different row cap than the lazy path (Python) - see the register.

## Wire and persistence contract

Same as feature 21's per-relation query, but per-call and uncached.

## Providers and substitutability

No abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| IMPREL-MODEL-DIVERGENCE | The very notion of "imperative relationships" differs: Python/PHP/Node expose a distinct instance-method API (class object, per-call, uncached); Ruby has NO separate API - it is the same class methods called at runtime. A cross-language port cannot assume "imperative relationships" means the same surface. | Decide whether imperative relationships are a required distinct API in all four (then add one to Ruby) or a per-language idiom (then document that Ruby's is the declarative method invoked at runtime). Do not score Ruby as a gap without deciding. |
| IMPREL-NODE-ORPHAN | Node's imperative methods write the loaded relation onto `this[tableName.toLowerCase()]` and return it, but NEVER populate `_relCache`; `toDict` reads only `_relCache` (or `this[model.toLowerCase()]`). So an imperatively-loaded relation - stored under the TABLE name - is orphaned from BOTH serialization paths whenever the table name differs from the lowercased model name (e.g. model `Post`, table `posts`). Only the method's return value is reliable. | Store the imperative result under the same key the serializer reads (populate `_relCache`), so an imperatively-loaded relation serializes. |
| IMPREL-PHP-PARALLEL | PHP has TWO parallel implementations of the same three relationship queries: the public imperative `has_one/has_many/belongs_to` (which call `ensureDb()`) and the private `hasOneMethod/hasManyMethod/belongsToMethod` used by the declarative path (which omit it). Duplicated logic that can drift, and the public imperative methods have NO direct test. | De-duplicate onto one implementation; add a test for the public imperative methods. |
| IMPREL-PY-CAP | Python's imperative `has_many` defaults `limit=100` while the lazy descriptor caps at 1000 - the same relationship returns a different number of rows depending on how it is accessed. | Unify the cap (or make it explicit/paged in both paths). |

## Owner decisions

- IMPREL-DEC-01 (proposed): decide whether imperative relationships are a required distinct API in all four
  (IMPREL-MODEL-DIVERGENCE) - the parity call for this feature.
- IMPREL-DEC-02 (proposed): fix Node's orphaned serialization (IMPREL-NODE-ORPHAN), de-duplicate PHP's
  parallel impl (IMPREL-PHP-PARALLEL), and unify Python's cap (IMPREL-PY-CAP).

## Proposed conformance fixture

A shared fixture: an imperatively-loaded relation SERIALIZES (catches IMPREL-NODE-ORPHAN); the imperative and
lazy paths return the same row count (catches IMPREL-PY-CAP); and (after IMPREL-DEC-01) the imperative surface
exists and behaves the same in all four.

## Integration map

- Consumers: runtime relationship traversal. Related: feature 21 (the declarative counterpart), serialization
  (26).

## Breaking changes and migration

- Fixing Node's serialization store changes what `toDict` includes (previously omitted) - a correctness fix.

## Porting capsule

Imperative relationships (if kept as a distinct API) need instance methods that take a related class, run one
per-call query, and store the result under the SAME key the serializer reads (so it serializes) - not a
parallel implementation that can drift from the declarative path, and not a different row cap than the lazy
path. Decide up front whether this is a required surface (all four) or the declarative method invoked at
runtime (Ruby's model).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire and provider contracts complete.
- [x] Four-language behaviour + the API-shape divergence recorded.
- [x] Owner ambiguities decided (IMPREL-DEC-01/02).
- [x] Conformance fixture (serialize + cap) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
