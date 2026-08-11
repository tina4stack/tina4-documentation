# Feature 23: ORM scopes

## Identity and status

- Matrix identity: 23 - ORM scopes (`tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, consistent design with a PHP cross-model collision bug. Measured
  2026-08-11. Python `orm/model.py:1349` (`ebbab30`); PHP `Tina4/ORM.php:1639` (`6faabac5`); Ruby
  `lib/tina4/orm.rb:572` (`6d5b1de`); Node `packages/orm/src/baseModel.ts:1401` (`27cf0f4`). Reconciles the
  prior audit (2026-07-28): the two Ruby findings it raised - a scope silently DISCARDING `limit:`/`offset:`,
  and an unbounded default row cap - are now FIXED (Ruby passes `limit`/`offset` through and defaults to the
  `DEFAULT_ROW_CAP`, 3.13.95); this re-measurement confirms that and surfaces the PHP collision instead.
- Dependencies: the base model `where()` (the finders), soft delete (20).
- Dependants: apps that reuse a named query filter.
- Existing ADRs: none dedicated.

- Catalog phase: ORM

## Why this feature exists

A scope is a named, reusable query filter - `User.active()` instead of repeating `where("active = 1")`. The
design questions are whether scopes are chainable, whether the parameters can be rebound per call, and whether
scopes are isolated per model.

## Existing implementation evidence

Universal: `scope(name, filter_sql, params)` registers a named method that calls `where(filter_sql, params,
limit, offset)` and returns a MATERIALIZED list/array of hydrated instances. The scope respects the
soft-delete filter (via `where`), and `limit`/`offset` push down to the DB (Ruby fixed a prior
accept-and-discard bug in 3.13.95). Params are FIXED at registration (only `limit`/`offset` are call-time
args). No global/default scopes exist (the only always-on filter is soft-delete, hard-coded in the finders).

Isolation diverges: Python/Ruby/Node register the scope as a per-CLASS method; PHP uses ONE shared registry
(see the register).

## Public surface contract

`Model.scope("active", "active = ?", [1])` then `Model.active(limit, offset)`. Contract: a named reusable
filter that returns instances, respecting soft-delete.

## Inputs and outputs

- Input: a name, a filter SQL, params. Output: an injected method returning a list of instances.

## Lifecycle and operation graph

1. `scope(name, sql, params)` registers a method.
2. `Model.name(limit, offset)` -> `where(sql, params, limit, offset)` -> a materialized list.

## Configuration and precedence

- `DEFAULT_ROW_CAP`/`limit=100` default. No env.

## Failures, side effects and security

- No security surface. The risks are the PHP cross-model collision and the lack of composition/rebinding (see
  the register).

## Wire and persistence contract

A scope is `where(...)` with a fixed filter; no persisted state.

## Providers and substitutability

No abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SCOPE-PHP-COLLISION | PHP-SPECIFIC BUG: scopes share ONE GLOBAL registry across ALL models. `$_scopes` is declared only on the abstract base and `scope()`/`__callStatic` use `static::$_scopes`, so - because no subclass redeclares the property - every model resolves to the SAME parent-owned array keyed only by name. `User::scope("active", "active=1")` and `Product::scope("active", "discontinued=0")` COLLIDE: the last registration wins the filter for both (each still queries its own table, but with the wrong WHERE). Python/Ruby/Node register per-class (no collision). Untested. | Make `$_scopes` per-class (a late-static-bound property, or a `[class][name]` key), so scopes are isolated per model - matching the other three. |
| SCOPE-NO-COMPOSE | UNIVERSAL: a scope returns a materialized list/array, not a chainable query builder, so `Model.active().recent()` is impossible and two scopes cannot be combined (the fluent path is the separate QueryBuilder). | Optionally return a chainable builder so scopes compose (an ActiveRecord-style improvement); or document that scopes are terminal and QueryBuilder is the composition path. |
| SCOPE-NO-REBIND | UNIVERSAL: params are fixed at registration; a scope takes only `limit`/`offset` at call time, so `Model.by_status(status)` cannot rebind the filter value. | Optionally support call-time params (`scope("by_status", "status = ?")` then `Model.by_status("active")`). |
| SCOPE-NO-GLOBAL | UNIVERSAL: no global/default scope mechanism beyond the hard-coded soft-delete filter; there is no `unscoped`/`default_scope`. | Optional: add a global-scope registry (or document that soft-delete is the only always-on filter). |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- SCOPE-DEC-01 (proposed): fix the PHP global-registry collision (SCOPE-PHP-COLLISION) - a real correctness
  bug (one model's scope silently rewrites another's).
- SCOPE-DEC-02 (proposed, optional): decide whether scopes should compose (SCOPE-NO-COMPOSE) and accept
  call-time params (SCOPE-NO-REBIND), and whether to add global scopes (SCOPE-NO-GLOBAL) - or document the
  terminal-list design.

## Proposed conformance fixture

A shared fixture: two models each register a scope named `active` with DIFFERENT filters and both return the
correct rows (catches SCOPE-PHP-COLLISION); a scope respects the soft-delete filter and honours `limit`/
`offset`.

## Integration map

- Consumers: apps reusing a filter. Composes: `where()` (the finders), soft delete (20).

## Breaking changes and migration

- Fixing the PHP collision changes behaviour only for the buggy same-name-across-models case - a correctness
  fix. Composition/rebinding (if added) is additive.

## Porting capsule

A scope needs: a PER-CLASS named method (never a shared global registry - the PHP collision bug) that runs a
filtered query respecting the soft-delete filter and pushing `limit`/`offset` to the DB. Decide whether scopes
compose (return a chainable builder) and accept call-time params, or are terminal lists - and keep it
consistent across the four.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire and provider contracts complete.
- [x] Four-language behaviour + the PHP collision recorded.
- [x] Owner ambiguities decided (SCOPE-DEC-01/02).
- [x] Conformance fixture (two-model collision) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
