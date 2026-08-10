# Feature 026: ORM instance loading

## Identity and status

- Matrix identity: 26 - ORM instance loading
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the `load()` signatures). No
  framework code changed.
- Dependencies: Feature 17 ORM base class (`load()` lives there), Feature 6 query builder (the
  filtered read), Feature 21 relationships (the `include` eager-load)
- Dependants: any code that hydrates an existing model instance from a filter rather than
  constructing it with `find()`
- Existing ADRs: none specific; ADR-0051 (row-cap) applies to the underlying read
- Shared fixtures: `orm_load_contract.json` is required

## Why this feature exists

A developer holds a model instance and populates it from the database by a filter -
`user.load("email = ?", ["a@b.c"])` - learning from the return value whether a row matched.
It is the in-place counterpart to `find()`: same read, but it fills the instance the caller
already has instead of returning a new one.

## Boundary

This feature owns `load(filter, params, include)`: run a filtered single-row read, populate
THIS instance from the first match, optionally eager-load `include` relations, and return a
success boolean. It DELEGATES the query to Feature 6, the eager-load to Feature 21, and the
model itself to Feature 17. The relationship-fetch methods (`has_many`/`belongs_to`) are
Feature 22, a sibling, not this feature.

## Existing implementation evidence

| Evidence (measured signatures) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Signature | `load(filter=None, params=None, include=None)` | `load($filter=null, $params=[], $include=null)` | `load(arg=nil, params=nil)` | `async load(filter?, params?, include?)` |
| Returns | `bool` | `bool` | (loads into self) | `Promise<boolean>` |
| `include` (eager-load) param | yes | yes | NO | yes |
| First argument | `filter` | `filter` | `arg` (positional, unnamed) | `filter` |

Python, PHP and Node agree: `load(filter, params, include)` runs the filter, populates the
instance, and returns a boolean (true when a row matched). Ruby is the outlier -- its
`load(arg, params)` takes only two positional arguments, has NO `include` parameter (so it
cannot eager-load during a load), and names its first argument `arg` rather than `filter`.
This is the same shape gap Feature 22 recorded for Ruby's `load()` (IMP-03).

## Public surface contract

`load(filter=None, params=None, include=None)` returns a boolean: `true` when the filter
matched a row and this instance was populated from it, `false` when nothing matched. `include`
eager-loads the named relations onto the instance during the load. The instance is populated
in place; `load()` does not return a new model (that is `find()`).

## Inputs and outputs

- Input: a filter SQL fragment, its bound params, and an optional `include` list of relation
  names.
- Output: `true` and a populated instance on a match; `false` and an unchanged instance on no
  match.
- The instance is never left half-populated: either the match's columns are applied wholesale
  or nothing changes.
- `include` populates the named relations in the same call (Ruby currently cannot).

## Lifecycle and operation graph

1. `load(filter, params)` composes a single-row read (`WHERE filter LIMIT 1`) through Feature
   6, bound.
2. On a match, every column is applied to the instance and any `include` relations are
   eager-loaded (Feature 21); the method returns `true`.
3. On no match, the instance is untouched and the method returns `false` -- it does not raise
   and does not partially fill.

## Configuration and precedence

- `include` is honored in all four (Ruby gains it); an omitted `include` loads no relations.
- There is no environment variable; `load()` is a per-call read.
- The underlying read is bounded only by the single-row semantics, consistent with ADR-0051.

## Failures, side effects and security

- No match returns `false`, never a raise and never a half-populated instance, so a caller
  branches on the boolean.
- The filter fragment is developer-written and its params are bound, so a `load()` carries no
  injection.
- `load()` mutates only the instance it is called on; it has no other side effect.

## Wire and persistence contract

There is no new persistence; `load()` is a read that mutates an in-memory instance. The
contract is the boolean return and the wholesale population: the same filter over the same row
populates the same fields and returns the same boolean in all four.

## Providers and substitutability

`load()` composes a standard single-row `WHERE` read through Feature 6, so it is
engine-agnostic; any provider satisfies it. A future runtime implements the same
`load(filter, params, include) -> bool` and passes the same fixture.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| LOAD-01 | Ruby's `load(arg, params)` diverges: positional, no `include`, and the first arg is unnamed. It cannot eager-load during a load. | Align Ruby on `load(filter, params, include)`; add `include`. |
| LOAD-02 | The boolean return is not proven identical (Ruby's return value is unverified). | Gate `load()` returning true-on-match and false-on-miss in all four. |
| LOAD-03 | The no-match contract (false, no raise, no half-population) is not gated. | Gate that a no-match `load()` leaves the instance untouched and returns false in all four. |
| LOAD-04 | No shared fixture exists. | Add `orm_load_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. One signature in all four: `load(filter, params, include) -> bool`. Ruby gains the
   `include` parameter and names its first argument `filter`.
2. `load()` returns `true` on a match and `false` on no match; it never raises for a miss and
   never leaves the instance half-populated.
3. `include` eager-loads the named relations during the load, via Feature 21.
4. `load()` populates the instance in place; returning a new model is `find()`'s job, kept
   distinct.

## Proposed conformance fixture

Add `orm_load_contract.json` with stable ids for: `load(filter)` populating the instance and
returning true; a no-match `load()` returning false and leaving the instance untouched;
`load(filter, params, include)` eager-loading a relation; and Ruby signature parity once
aligned. Every behavioural case uses real SQLite; no mock can claim conformance.

## Integration map

- Feature 17's base model hosts `load()`; Feature 6 composes the read; Feature 21 eager-loads
  `include`; Feature 22 (relationship methods) is the sibling that fetches related rows.
- `find()` (Feature 17) is the return-a-new-model counterpart; the two stay distinct.
- Central fixtures, four runners, the CI matrix and the ORM docs update together.

## Breaking changes and migration

- Ruby's `load()` gains an `include` parameter and a named `filter` argument; a Ruby caller
  passing positional arguments keeps working, and one gains eager-loading.
- No change to the other three; this aligns Ruby to the existing three-way agreement.

## Implementation backlog

1. Add `orm_load_contract.json` and wire four runners against real SQLite.
2. Align Ruby's `load()` on `load(filter, params, include)` with the `include` eager-load.
3. Gate the boolean return and the no-match (false, no raise, no half-population) contract.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `load(filter, params, include) -> bool`: compose a bound single-row `WHERE filter
LIMIT 1` read, populate the instance wholesale on a match and eager-load any `include`
relations, and return `true`; on no match, leave the instance untouched and return `false`.
Keep it distinct from `find()`, which returns a new model. Prove the port against real SQLite,
including the no-match-returns-false case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (LOAD-01..04).
- [x] Owner ambiguities recorded (4 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
